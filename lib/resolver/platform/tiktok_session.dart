import 'dart:convert';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:tiktok_scraper/tiktok_scraper.dart';

import '../../downloads/platform_download_headers.dart';
import '../../core/logging/vortex_logger.dart';
import '../../core/utils/file_name_utils.dart';
import '../analyzed_resource.dart';
import '../media_variant.dart';

/// Résolution TikTok dans une même session HTTP (cookies → CDN).
class TiktokSession {
  TiktokSession({
    required this.mediaUrl,
    required this.pageReferer,
    required this.video,
    required this.downloadHeaders,
    required this.entries,
  });

  final String mediaUrl;
  final String pageReferer;
  final TiktokVideo video;
  final Map<String, String> downloadHeaders;

  /// Tous les médias téléchargeables (1 vidéo ou N images d’un carrousel).
  final List<TiktokMediaEntry> entries;

  bool get isPhotoPost =>
      entries.isNotEmpty && entries.every((e) => e.kind == ContentKind.image);

  List<MediaVariant> toVariants() {
    return entries
        .map(
          (e) => MediaVariant(
            id: e.id,
            label: e.label,
            sortKey: e.sortKey,
            resource: AnalyzedResource(
              finalUrl: e.url,
              fileName: e.fileName,
              mimeType: e.mimeType,
              supportsResume: false,
              resolverName: 'TikTok',
              contentKind: e.kind,
              downloadHeaders: downloadHeaders,
              thumbnailUrl: e.kind == ContentKind.image
                  ? normalizeThumbnailUrl(e.url)
                  : normalizeThumbnailUrl(video.thumbnail),
            ),
          ),
        )
        .toList();
  }

  static Future<TiktokSession> resolve(String pageUrl) async {
    final jar = CookieJar();
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 25),
        receiveTimeout: const Duration(seconds: 45),
        followRedirects: true,
        maxRedirects: 10,
        validateStatus: (s) => s != null && s < 500,
        headers: PlatformDownloadHeaders.tiktok(
          pageReferer: 'https://www.tiktok.com/',
        ),
      ),
    );
    dio.interceptors.add(CookieManager(jar));

    VortexLog.resolve.fine('TikTok session : chargement page');
    final pageRes = await dio.get<String>(
      pageUrl,
      options: Options(responseType: ResponseType.plain),
    );
    if (pageRes.statusCode != null && pageRes.statusCode! >= 400) {
      throw TikTokException(
        'Page TikTok inaccessible (${pageRes.statusCode}).',
      );
    }
    final finalPageUrl = pageRes.realUri.toString();
    if (finalPageUrl != pageUrl) {
      VortexLog.resolve.fine('TikTok redirection → $finalPageUrl');
    }

    var html = pageRes.data ?? '';
    var item = tryParseItemStruct(html);

    if (item == null && _isPhotoPageUrl(finalPageUrl)) {
      final canonical = _canonicalPageUrl(finalPageUrl);
      VortexLog.resolve.fine(
        'TikTok session : rechargement page photo ($canonical)',
      );
      final photoRes = await dio.get<String>(
        canonical,
        options: Options(
          headers: PlatformDownloadHeaders.tiktok(pageReferer: canonical),
          responseType: ResponseType.plain,
        ),
      );
      html = photoRes.data ?? html;
      item = tryParseItemStruct(html);
    }

    if (item == null) {
      _logParseDiagnostics(html);
      if (_isPhotoPageUrl(finalPageUrl)) {
        throw TikTokException(
          'Publication TikTok photo non reconnue (page protégée ou structure modifiée).',
        );
      }
      throw TikTokException(
        'Publication TikTok non reconnue (lien vidéo/photo invalide ou page protégée).',
      );
    }
    final videoData = item['video'] as Map<String, dynamic>?;
    final streamUrls = videoData != null ? _collectStreamUrls(videoData) : <String>[];
    final playableVideo = TiktokPlatformExtractorPick.pickUrl(streamUrls);

    final imageUrls = _imageUrlsFromItem(item);
    if (imageUrls.isNotEmpty && playableVideo == null) {
      return _buildPhotoSession(item, imageUrls, jar);
    }

    if (playableVideo == null) {
      throw TikTokException(
        'Impossible d’obtenir le média TikTok (vidéo ou photo). Réessayez plus tard.',
      );
    }

    final video = _videoFromItem(item);
    final mediaUrl = playableVideo;

    final pageReferer = _pageRefererVideo(video);
    final headers = await _headersForMedia(jar, pageReferer, mediaUrl);
    final baseName = _baseNameFromItem(item, video);
    final fileName = FileNameUtils.sanitize('$baseName.mp4');

    return TiktokSession(
      mediaUrl: mediaUrl,
      pageReferer: pageReferer,
      video: video,
      downloadHeaders: headers,
      entries: [
        TiktokMediaEntry(
          id: video.id,
          url: mediaUrl,
          fileName: fileName,
          mimeType: 'video/mp4',
          kind: ContentKind.video,
          label: 'Vidéo · mp4',
          sortKey: video.height,
        ),
      ],
    );
  }

  static Future<TiktokSession> _buildPhotoSession(
    Map<String, dynamic> item,
    List<String> imageUrls,
    CookieJar jar,
  ) async {
    final video = _videoMetaFromItem(item, imageUrls);
    final pageReferer = _pageRefererPhoto(video);
    final headers = await _headersForMedia(jar, pageReferer, imageUrls.first);
    final baseName = _baseNameFromItem(item, video);
    final entries = <TiktokMediaEntry>[];
    for (var i = 0; i < imageUrls.length; i++) {
      final n = i + 1;
      final suffix = imageUrls.length > 1 ? '_$n' : '';
      entries.add(
        TiktokMediaEntry(
          id: '${video.id}_img_$n',
          url: imageUrls[i],
          fileName: FileNameUtils.sanitize('$baseName$suffix.jpg'),
          mimeType: 'image/jpeg',
          kind: ContentKind.image,
          label: imageUrls.length > 1
              ? 'Photo $n / ${imageUrls.length}'
              : 'Photo · jpg',
          sortKey: n,
        ),
      );
    }

    return TiktokSession(
      mediaUrl: imageUrls.first,
      pageReferer: pageReferer,
      video: video,
      downloadHeaders: headers,
      entries: entries,
    );
  }

  static Future<Map<String, String>> _headersForMedia(
    CookieJar jar,
    String pageReferer,
    String mediaUrl,
  ) async {
    final headers = PlatformDownloadHeaders.tiktok(pageReferer: pageReferer);
    final mediaUri = Uri.parse(mediaUrl);
    final cookies = await jar.loadForRequest(mediaUri);
    if (cookies.isNotEmpty) {
      headers['Cookie'] = cookies.map((c) => '${c.name}=${c.value}').join('; ');
      VortexLog.resolve.fine('TikTok session : ${cookies.length} cookie(s) CDN');
    }
    return headers;
  }

  /// Télécharge le média (vidéo : session fraîche ; image : URL choisie).
  static Future<void> downloadToFile({
    required String sourceUrl,
    required String tempPath,
    required CancelToken cancelToken,
    String? mediaUrl,
    Map<String, String>? headers,
    void Function(int received, int? total)? onProgress,
  }) async {
    late final String url;
    late final Map<String, String> h;
    final hasDirect = mediaUrl != null &&
        mediaUrl.isNotEmpty &&
        headers != null &&
        headers.isNotEmpty;
    if (hasDirect) {
      url = mediaUrl;
      h = headers;
      VortexLog.download.fine('TikTok CDN (URL déjà résolue)');
    } else {
      final session = await resolve(sourceUrl);
      url = mediaUrl ?? session.mediaUrl;
      h = headers ?? session.downloadHeaders;
    }
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: Duration.zero,
        followRedirects: true,
        maxRedirects: 10,
        headers: h,
      ),
    );
    VortexLog.download.fine('TikTok CDN : ${Uri.parse(url).host}');
    await dio.download(
      url,
      tempPath,
      cancelToken: cancelToken,
      onReceiveProgress: (r, t) => onProgress?.call(r, t > 0 ? t : null),
    );
  }

  /// Extrait [itemStruct] sans lever (pour essais / rechargement page).
  static Map<String, dynamic>? tryParseItemStruct(String html) {
    if (html.isEmpty) return null;

    final fromApi = _itemStructFromApiData(html);
    if (fromApi != null) return fromApi;

    var jsonString = _extractUniversalJson(html);
    if (jsonString == null || jsonString.isEmpty) {
      final document = html_parser.parse(html);
      jsonString =
          document.getElementById('__UNIVERSAL_DATA_FOR_REHYDRATION__')?.text;
    }
    if (jsonString == null || jsonString.isEmpty) return null;

    try {
      final data = jsonDecode(jsonString) as Map<String, dynamic>;
      final scope = data['__DEFAULT_SCOPE__'] as Map<String, dynamic>?;
      if (scope != null) {
        final struct =
            _findItemStruct(scope) ?? _findItemStructDeep(scope, depth: 0);
        if (struct != null) return struct;
      }
      final fromTree = _findItemStructDeep(data, depth: 0);
      if (fromTree != null) return fromTree;
    } catch (e, st) {
      VortexLog.resolve.fine('TikTok universal JSON illisible', e, st);
    }

    return _itemStructFromApiData(html);
  }

  static void _logParseDiagnostics(String html) {
    VortexLog.resolve.fine(
      'TikTok parse échec : ${html.length} o, '
      'api-data=${html.contains('id="api-data"')}, '
      'universal=${html.contains('__UNIVERSAL_DATA_FOR_REHYDRATION__')}, '
      'itemStruct=${html.contains('itemStruct')}',
    );
  }

  static bool _isPhotoPageUrl(String url) {
    final path = Uri.tryParse(url)?.path.toLowerCase() ?? '';
    return path.contains('/photo/');
  }

  static String _canonicalPageUrl(String url) {
    final uri = Uri.parse(url);
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.length >= 3 &&
        segments[1] == 'photo' &&
        segments[2].isNotEmpty) {
      final user = segments[0].replaceFirst(RegExp(r'^@'), '');
      return Uri(
        scheme: uri.scheme,
        host: uri.host,
        path: '/@$user/photo/${segments[2]}',
      ).toString();
    }
    return uri.replace(queryParameters: {}).toString();
  }

  /// Pages `/photo/` : souvent `&lt;script id="api-data"&gt;` au lieu du bloc reflow.
  static Map<String, dynamic>? _itemStructFromApiData(String html) {
    final jsonString =
        _extractApiDataJson(html) ?? _extractScriptJsonById(html, 'api-data');
    if (jsonString == null || jsonString.isEmpty) return null;
    try {
      final data = jsonDecode(jsonString) as Map<String, dynamic>;
      for (final key in [
        'videoDetail',
        'photoDetail',
        'imageDetail',
        'itemDetail',
      ]) {
        final struct = _itemStructFromDetail(data[key]);
        if (struct != null) {
          VortexLog.resolve.fine('TikTok session : itemStruct via api-data ($key)');
          return struct;
        }
      }
      return _findItemStructDeep(data);
    } catch (e, st) {
      VortexLog.resolve.fine('TikTok api-data illisible', e, st);
      return null;
    }
  }

  static String? _extractApiDataJson(String html) {
    const markers = ['id="api-data"', "id='api-data'"];
    for (final marker in markers) {
      final idPos = html.indexOf(marker);
      if (idPos < 0) continue;
      final open = html.indexOf('{', idPos);
      if (open < 0) continue;
      final close = html.indexOf('</script>', open);
      if (close < 0 || close <= open) continue;
      final raw = html.substring(open, close).trim();
      if (raw.isNotEmpty) return raw;
    }
    return null;
  }

  static String? _extractScriptJsonById(String html, String scriptId) {
    final marker = 'id="$scriptId"';
    final tagStart = html.indexOf(marker);
    if (tagStart < 0) return null;
    final jsonStart = html.indexOf('>', tagStart);
    if (jsonStart < 0) return null;
    final contentStart = jsonStart + 1;
    final endTag = html.indexOf('</script>', contentStart);
    if (endTag < 0) return null;
    final raw = html.substring(contentStart, endTag).trim();
    return raw.isEmpty ? null : raw;
  }

  static String? _extractUniversalJson(String html) {
    const marker = '__UNIVERSAL_DATA_FOR_REHYDRATION__';
    final tagStart = html.indexOf(marker);
    if (tagStart < 0) return null;
    final jsonStart = html.indexOf('>', tagStart);
    if (jsonStart < 0) return null;
    final contentStart = jsonStart + 1;
    final endTag = html.indexOf('</script>', contentStart);
    if (endTag < 0) return null;
    final raw = html.substring(contentStart, endTag).trim();
    return raw.isEmpty ? null : raw;
  }

  static Map<String, dynamic>? _findItemStructDeep(
    Object? node, {
    int depth = 0,
  }) {
    if (depth > 24) return null;
    if (node is Map<String, dynamic>) {
      final fromInfo = _itemStructFromDetail(node);
      if (fromInfo != null) return fromInfo;

      final direct = node['itemStruct'];
      if (direct is Map<String, dynamic> &&
          direct.isNotEmpty &&
          direct['id'] != null) {
        return direct;
      }

      for (final value in node.values) {
        final found = _findItemStructDeep(value, depth: depth + 1);
        if (found != null) return found;
      }
    } else if (node is List) {
      for (final value in node) {
        final found = _findItemStructDeep(value, depth: depth + 1);
        if (found != null) return found;
      }
    }
    return null;
  }

  static Map<String, dynamic>? _findItemStruct(Map<String, dynamic> scope) {
    const preferredKeys = [
      'webapp.video-detail',
      'webapp.photo-detail',
      'webapp.reflow.video.detail',
    ];
    for (final key in preferredKeys) {
      final struct = _itemStructFromDetail(scope[key]);
      if (struct != null) return struct;
    }
    for (final entry in scope.entries) {
      final k = entry.key.toLowerCase();
      if (!k.contains('detail')) continue;
      final struct = _itemStructFromDetail(entry.value);
      if (struct != null) return struct;
    }
    return null;
  }

  static Map<String, dynamic>? _itemStructFromDetail(Object? detail) {
    if (detail is! Map<String, dynamic>) return null;
    final code = detail['statusCode'] ?? detail['status_code'];
    if (code is int && code != 0 && code != 200) return null;
    final itemInfo = detail['itemInfo'] as Map<String, dynamic>?;
    final struct = itemInfo?['itemStruct'] as Map<String, dynamic>?;
    if (struct == null || struct.isEmpty) return null;
    return struct;
  }

  static List<String> _imageUrlsFromItem(Map<String, dynamic> mainData) {
    final imagePost = mainData['imagePost'] as Map<String, dynamic>?;
    if (imagePost == null) return [];
    final images = imagePost['images'] as List<dynamic>? ?? [];
    final out = <String>[];
    for (final raw in images) {
      if (raw is! Map<String, dynamic>) continue;
      final url = _imageUrlFromNode(raw);
      if (url != null) out.add(url);
    }
    return out;
  }

  static String? _imageUrlFromNode(Map<String, dynamic> img) {
    final imageURL = img['imageURL'] as Map<String, dynamic>?;
    if (imageURL != null) {
      final list = imageURL['urlList'] as List<dynamic>?;
      if (list != null && list.isNotEmpty) {
        final u = list.first?.toString().trim();
        if (u != null && u.startsWith('http')) return u;
      }
    }
    final direct = img['displayImage']?.toString().trim();
    if (direct != null && direct.startsWith('http')) return direct;
    return null;
  }

  static TiktokVideo _videoFromItem(Map<String, dynamic> mainData) {
    final videoData = mainData['video'] as Map<String, dynamic>?;
    final authorData = mainData['author'] as Map<String, dynamic>?;
    final authorStats = mainData['authorStats'] as Map<String, dynamic>?;
    if (videoData == null || authorData == null || authorStats == null) {
      throw TikTokException('Métadonnées TikTok incomplètes.');
    }
    final downloadUrls = _collectStreamUrls(videoData);
    return TiktokVideo.fromJson({
      'id': mainData['id'].toString(),
      'description': mainData['desc'].toString(),
      'createTime': mainData['createTime'].toString(),
      'height': videoData['height'],
      'width': videoData['width'],
      'duration': videoData['duration'],
      'defaultResolution': videoData['ratio'],
      'thumbnail': videoData['cover'].toString(),
      'downloadUrls': downloadUrls,
      'audioUrl': (mainData['music']?['playUrl']).toString(),
      'author': <String, dynamic>{
        'id': authorData['id'].toString(),
        'username': authorData['uniqueId'].toString(),
        'name': authorData['nickname'].toString(),
        'avatar': authorData['avatarLarger'].toString(),
        ...authorStats,
      },
    });
  }

  /// Métadonnées auteur + couverture pour les posts photo (sans flux vidéo).
  static TiktokVideo _videoMetaFromItem(
    Map<String, dynamic> mainData,
    List<String> imageUrls,
  ) {
    final authorData = mainData['author'] as Map<String, dynamic>?;
    final authorStats = mainData['authorStats'] as Map<String, dynamic>?;
    if (authorData == null || authorStats == null) {
      throw TikTokException('Métadonnées TikTok incomplètes.');
    }
    final thumb = imageUrls.isNotEmpty ? imageUrls.first : '';
    return TiktokVideo.fromJson({
      'id': mainData['id'].toString(),
      'description': mainData['desc'].toString(),
      'createTime': mainData['createTime'].toString(),
      'height': 0,
      'width': 0,
      'duration': 0,
      'defaultResolution': '',
      'thumbnail': thumb,
      'downloadUrls': <String>[],
      'audioUrl': (mainData['music']?['playUrl']).toString(),
      'author': <String, dynamic>{
        'id': authorData['id'].toString(),
        'username': authorData['uniqueId'].toString(),
        'name': authorData['nickname'].toString(),
        'avatar': authorData['avatarLarger'].toString(),
        ...authorStats,
      },
    });
  }

  static String _baseNameFromItem(Map<String, dynamic> item, TiktokVideo video) {
    final desc = video.description.trim();
    if (desc.isNotEmpty) {
      return desc.length > 80 ? '${desc.substring(0, 80)}…' : desc;
    }
    final user = video.author.username;
    return 'tiktok_${user}_${video.id}';
  }

  static String _pageRefererVideo(TiktokVideo video) {
    final user = video.author.username.replaceAll('@', '');
    return 'https://www.tiktok.com/@$user/video/${video.id}';
  }

  static String _pageRefererPhoto(TiktokVideo video) {
    final user = video.author.username.replaceAll('@', '');
    return 'https://www.tiktok.com/@$user/photo/${video.id}';
  }

  static List<String> _collectStreamUrls(Map<String, dynamic> videoData) {
    final ordered = <String>[];

    void add(String? raw) {
      final u = raw?.trim();
      if (u == null || u.isEmpty || u == 'null' || !u.startsWith('http')) {
        return;
      }
      if (!ordered.contains(u)) ordered.add(u);
    }

    final bitrateInfo = videoData['bitrateInfo'];
    if (bitrateInfo is List) {
      final renditions = <({int bitrate, String url})>[];
      for (final info in bitrateInfo) {
        if (info is! Map<String, dynamic>) continue;
        final play = info['PlayAddr'];
        if (play is! Map<String, dynamic>) continue;
        final urlList = play['UrlList'];
        if (urlList is! List || urlList.isEmpty) continue;
        final url = urlList.first?.toString();
        final bitrate = info['Bitrate'] as int? ?? 0;
        if (url != null && url.startsWith('http')) {
          renditions.add((bitrate: bitrate, url: url));
        }
      }
      renditions.sort((a, b) => b.bitrate.compareTo(a.bitrate));
      for (final r in renditions) {
        add(r.url);
      }
    }

    add(videoData['playAddr']?.toString());
    add(videoData['downloadAddr']?.toString());
    return ordered;
  }
}

class TiktokMediaEntry {
  const TiktokMediaEntry({
    required this.id,
    required this.url,
    required this.fileName,
    required this.mimeType,
    required this.kind,
    required this.label,
    required this.sortKey,
  });

  final String id;
  final String url;
  final String fileName;
  final String mimeType;
  final ContentKind kind;
  final String label;
  final int sortKey;
}

/// Sélection d’URL partagée (évite import circulaire).
abstract final class TiktokPlatformExtractorPick {
  static String? pickUrl(List<String> urls) {
    String? best;
    var bestScore = -1;
    for (final raw in urls) {
      final u = raw.trim();
      if (u.isEmpty || u == 'null' || !u.startsWith('http')) continue;
      final score = _watermarkFreeScore(u);
      if (score > bestScore) {
        bestScore = score;
        best = u;
      }
    }
    return best;
  }

  static int _watermarkFreeScore(String url) {
    final lower = url.toLowerCase();
    if (lower.contains('unwatermarked') || lower.contains('lr=unwatermarked')) {
      return 100;
    }
    if (lower.contains('watermark') || lower.contains('lr=tiktok')) {
      return 5;
    }
    if (!lower.contains('download')) return 85;
    return 15;
  }
}
