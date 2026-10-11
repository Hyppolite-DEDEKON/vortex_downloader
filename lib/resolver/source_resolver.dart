import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart' as html;
import 'package:path/path.dart' as p;

import '../core/errors/app_exception.dart';
import '../core/logging/vortex_logger.dart';
import '../core/networking/http_client_factory.dart';
import '../core/utils/file_name_utils.dart';
import '../core/utils/format_utils.dart';
import '../core/utils/link_access_messages.dart';
import '../core/utils/http_header_utils.dart';
import '../core/utils/url_security.dart';
import 'analyzed_resource.dart';
import 'platform/platform_resolver.dart';
import 'platform/streaming_hosts.dart';
import 'platform/ytdlp_locator.dart';
import 'resolve_result.dart';
import 'media_variant.dart';
import 'resolver_contract.dart';
import 'variant_catalog.dart';

class SourceResolverChain {
  factory SourceResolverChain({
    List<SourceResolver>? resolvers,
    Dio? dio,
    String? ytdlpPath,
  }) {
    final locator = YtdlpLocator(ytdlpPath);
    return SourceResolverChain._(
      locator,
      resolvers ?? _defaultResolvers(locator),
      dio ?? createProbeDio(),
    );
  }

  SourceResolverChain._(this._locator, this._resolvers, this._dio);

  static List<SourceResolver> _defaultResolvers(YtdlpLocator locator) => [
        DirectFileResolver(),
        PlatformResolver(ytdlpLocator: locator),
        WebPageResolver(),
        YtdlpResolver(locator),
      ];

  final YtdlpLocator _locator;
  final List<SourceResolver> _resolvers;
  final Dio _dio;

  Future<List<MediaVariant>> listMediaVariants(Uri uri) =>
      VariantCatalog.list(uri, _locator);

  Future<ResolveResult> resolve(Uri uri) async {
    VortexLog.resolve.info('Analyse de $uri');
    final ctx = ProbeContext(_dio);
    String? lastUnsupportedMessage;
    final streaming = StreamingHosts.matches(uri.host);
    for (final r in _resolvers) {
      if (streaming && (r is DirectFileResolver || r is WebPageResolver)) {
        VortexLog.resolve.fine('${r.name} ignoré (hôte streaming)');
        continue;
      }
      VortexLog.resolve.fine('Résolveur ${r.name}…');
      final out = await r.resolve(uri, ctx);
      switch (out) {
        case ResolveSuccess(:final resource):
          VortexLog.resolve.info(
            '${r.name} → ${resource.fileName} (${resource.resolverName})',
          );
          return out;
        case ResolveFailure(:final message):
          VortexLog.resolve.warning('${r.name} : $message');
          return out;
        case ResolveUnsupported(:final message):
          VortexLog.resolve.fine('${r.name} ignoré : $message');
          lastUnsupportedMessage = message;
          continue;
      }
    }
    final hasYtdlp = await _locator.binary() != null;
    if (!hasYtdlp) {
      VortexLog.resolve.warning('yt-dlp indisponible après toute la chaîne');
      return const ResolveFailure(
        'Ce lien nécessite yt-dlp, qui n’a pas pu être installé automatiquement. '
        'Réessayez avec une connexion internet, ou définissez un chemin dans Paramètres.',
      );
    }
    final msg =
        lastUnsupportedMessage ?? 'Aucun média téléchargeable trouvé pour ce lien.';
    VortexLog.resolve.warning('Échec final : $msg');
    return ResolveFailure(msg);
  }
}

class DirectFileResolver implements SourceResolver {
  @override
  String get name => 'Direct';

  @override
  Future<ResolveResult> resolve(Uri start, ProbeContext ctx) async {
    try {
      final probe = await _probe(start, ctx);
      if (probe.code >= 400) {
        return ResolveFailure(
          LinkAccessMessages.resolveFailureForHttpStatus(probe.code),
        );
      }
      final mime = probe.mime?.split(';').first.trim().toLowerCase();
      if (mime == 'text/html') {
        return const ResolveUnsupported('Page HTML — analyse web.');
      }
      var fileName = HttpHeaderUtils.fileNameFromContentDisposition(
            probe.disposition,
          ) ??
          HttpHeaderUtils.fileNameFromUrl(probe.uri);
      final ext = guessExt(mime, fileName);
      if (p.extension(fileName).isEmpty && ext.isNotEmpty) {
        fileName = '$fileName$ext';
      }
      return ResolveSuccess(
        AnalyzedResource(
          finalUrl: probe.uri.toString(),
          fileName: FileNameUtils.sanitize(fileName),
          mimeType: mime,
          totalBytes: probe.length,
          supportsResume: probe.ranges?.contains('bytes') ?? false,
          resolverName: name,
          contentKind: kindFromMime(mime),
        ),
      );
    } on SecurityBlockedException catch (e) {
      return ResolveFailure(e.message);
    } on DioException catch (e) {
      return ResolveFailure(e.message ?? 'Erreur réseau.');
    }
  }

  Future<_Probe> _probe(Uri start, ProbeContext ctx) async {
    var current = UrlSecurity.normalize(start);
    for (var i = 0; i <= UrlSecurity.maxRedirectDepth; i++) {
      UrlSecurity.assertSafeHost(current.host);
      final res = await ctx.dio.get<String>(
        current.toString(),
        options: Options(
          followRedirects: false,
          validateStatus: (s) => s != null && s < 600,
          responseType: ResponseType.plain,
          headers: const {'Range': 'bytes=0-0'},
        ),
      );
      if (_redirect(res.statusCode)) {
        final loc = res.headers.value('location');
        if (loc == null) throw const NetworkException('Redirection invalide.');
        current = UrlSecurity.normalize(current.resolve(loc));
        continue;
      }
      return _Probe(
        uri: current,
        code: res.statusCode ?? 0,
        mime: res.headers.value('content-type'),
        length: FormatUtils.parseContentLength(
          res.headers.value('content-length'),
        ),
        disposition: res.headers.value('content-disposition'),
        ranges: res.headers.value('accept-ranges'),
      );
    }
    throw const NetworkException('Trop de redirections.');
  }

  bool _redirect(int? c) =>
      c == 301 || c == 302 || c == 303 || c == 307 || c == 308;
}

class _Probe {
  _Probe({
    required this.uri,
    required this.code,
    this.mime,
    this.length,
    this.disposition,
    this.ranges,
  });
  final Uri uri;
  final int code;
  final String? mime;
  final int? length;
  final String? disposition;
  final String? ranges;
}

class WebPageResolver implements SourceResolver {
  @override
  String get name => 'WebPage';

  @override
  Future<ResolveResult> resolve(Uri start, ProbeContext ctx) async {
    try {
      var current = UrlSecurity.normalize(start);
      final res = await ctx.dio.get<String>(
        current.toString(),
        options: Options(
          followRedirects: true,
          validateStatus: (s) => s != null && s < 600,
        ),
      );
      if (res.statusCode != null && res.statusCode! >= 400) {
        return ResolveFailure('Page inaccessible (${res.statusCode}).');
      }
      final body = res.data ?? '';
      if (!RegExp(r'<html', caseSensitive: false).hasMatch(body)) {
        return const ResolveUnsupported('Pas une page web.');
      }
      final doc = html.parse(body.length > 400000 ? body.substring(0, 400000) : body);
      final candidates = _collectMediaCandidates(doc, current, body);
      if (candidates.isEmpty) {
        return ResolveFailure(_noDirectFileMessage(current.host));
      }
      final direct = DirectFileResolver();
      ResolveResult? imageFallback;
      for (final url in candidates) {
        final out = await direct.resolve(Uri.parse(url), ctx);
        switch (out) {
          case ResolveSuccess(:final resource):
            if (resource.contentKind == ContentKind.video ||
                resource.contentKind == ContentKind.audio) {
              return out;
            }
            if (resource.contentKind == ContentKind.image &&
                imageFallback == null) {
              imageFallback = out;
            }
            if (resource.contentKind != ContentKind.image) {
              return out;
            }
          case ResolveFailure():
            continue;
          case ResolveUnsupported():
            continue;
        }
      }
      if (imageFallback != null) return imageFallback;
      return ResolveFailure(
        '${_noDirectFileMessage(current.host)} '
        'Des liens ont été détectés mais le serveur ne les livre pas en fichier direct.',
      );
    } on SecurityBlockedException catch (e) {
      return ResolveFailure(e.message);
    } on DioException catch (e) {
      return ResolveFailure(e.message ?? 'Erreur réseau.');
    }
  }
}

final _mediaPath = RegExp(
  r'\.(mp4|webm|mkv|mov|m4v|m3u8|mp3|m4a|wav|flac|ogg|pdf|zip|rar|7z)(?:\?|#|$)',
  caseSensitive: false,
);

final _embeddedMediaUrl = RegExp(
  r'''https?://[^\s"'<>)\]]+\.(?:mp4|webm|mkv|mov|m4v|m3u8|mp3|m4a|wav|flac|ogg)(?:\?[^\s"'<>)\]]*)?''',
  caseSensitive: false,
);

String _noDirectFileMessage(String host) {
  return 'Aucun fichier direct dans la page ($host). '
      'Vortex tentera yt-dlp si installé.';
}

bool _looksLikeDirectMediaUrl(String url) => _mediaPath.hasMatch(url);

/// URLs candidates dans l’ordre de priorité (vidéo / téléchargement avant aperçu).
List<String> _collectMediaCandidates(Document doc, Uri page, String rawHtml) {
  final seen = <String>{};
  final out = <String>[];

  void add(String? raw) {
    if (raw == null || raw.isEmpty) return;
    final trimmed = raw.trim();
    final resolved = trimmed.startsWith('http')
        ? trimmed
        : page.resolve(trimmed).toString();
    if (!resolved.startsWith('http')) return;
    if (seen.add(resolved)) out.add(resolved);
  }

  for (final a in doc.querySelectorAll('a[href]')) {
    final href = a.attributes['href'];
    if (a.attributes['download'] != null) {
      add(href);
    } else if (href != null && _looksLikeDirectMediaUrl(href)) {
      add(href);
    }
  }

  for (final link in doc.querySelectorAll('link[href]')) {
    final type = link.attributes['type']?.toLowerCase() ?? '';
    final href = link.attributes['href'];
    if (href == null) continue;
    if (type.startsWith('video/') ||
        type.startsWith('audio/') ||
        _looksLikeDirectMediaUrl(href)) {
      add(href);
    }
  }

  const videoMetaKeys = [
    'og:video:url',
    'og:video:secure_url',
    'og:video',
    'twitter:player:stream',
  ];
  for (final key in videoMetaKeys) {
    for (final m in doc.querySelectorAll('meta')) {
      final prop = m.attributes['property'] ?? m.attributes['name'];
      if (prop != key) continue;
      add(m.attributes['content']);
    }
  }

  for (final m in doc.querySelectorAll('meta')) {
    final prop = m.attributes['property'] ?? m.attributes['name'];
    if (prop != null && prop.startsWith('og:video')) {
      add(m.attributes['content']);
    }
  }

  for (final v in doc.querySelectorAll('video[src]')) {
    add(v.attributes['src']);
  }
  for (final s in doc.querySelectorAll('video source[src], source[src]')) {
    final type = s.attributes['type']?.toLowerCase() ?? '';
    if (type.isEmpty || type.startsWith('video/') || type.startsWith('audio/')) {
      add(s.attributes['src']);
    }
  }

  for (final script in doc.querySelectorAll('script[type="application/ld+json"]')) {
    final text = script.text.trim();
    if (text.isEmpty) continue;
    try {
      _walkJsonLd(jsonDecode(text), add);
    } catch (_) {}
  }

  for (final match in _embeddedMediaUrl.allMatches(rawHtml)) {
    add(match.group(0));
  }

  for (final m in doc.querySelectorAll('meta')) {
    final prop = m.attributes['property'] ?? m.attributes['name'];
    if (prop == 'og:image' || prop == 'og:image:url') {
      add(m.attributes['content']);
    }
  }

  return out;
}

void _walkJsonLd(dynamic node, void Function(String? url) add) {
  if (node is Map) {
    for (final e in node.entries) {
      final key = e.key.toString().toLowerCase();
      final v = e.value;
      if (v is String &&
          (key == 'contenturl' ||
              key == 'embedurl' ||
              key == 'downloadurl' ||
              key == 'contentlocation') &&
          _looksLikeDirectMediaUrl(v)) {
        add(v);
      }
      _walkJsonLd(v, add);
    }
  } else if (node is List) {
    for (final item in node) {
      _walkJsonLd(item, add);
    }
  }
}

List<String> collectMediaCandidatesForTest(Document doc, Uri page) =>
    _collectMediaCandidates(doc, page, doc.outerHtml);
