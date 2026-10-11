import 'dart:convert';
import 'dart:io';

import 'package:extractor/extractor.dart';

import '../../core/utils/file_name_utils.dart';
import '../../core/utils/format_utils.dart';
import '../analyzed_resource.dart';
import '../media_variant.dart';
import 'extractor_service.dart' show ExtractorService, YtdlpMime;
import 'ytdlp_locator.dart';

abstract final class YtdlpVariantList {
  static Future<List<MediaVariant>> list(
    String pageUrl,
    YtdlpLocator locator,
  ) async {
    if (ExtractorService.isPlatform) {
      return _fromExtractor(pageUrl);
    }
    final bin = await locator.binary();
    if (bin == null) return const [];
    return _fromProcess(bin, pageUrl);
  }

  static Future<List<MediaVariant>> _fromExtractor(String pageUrl) async {
    if (!await ExtractorService.ensureReady()) return const [];
    final info = await YoutubeDLFlutter.instance.getVideoInfo(pageUrl);
    final title = FileNameUtils.sanitize((info.title ?? 'video').trim());
    final thumb = normalizeThumbnailUrl(info.thumbnail);
    final out = <MediaVariant>[];
    for (final f in info.formats ?? const <VideoFormat?>[]) {
      final format = f;
      if (format == null) continue;
      final url = format.url?.trim();
      if (url == null || !url.startsWith('http')) continue;
      if (!_isMuxedOrSingle(format.vcodec, format.acodec)) continue;
      final ext = (format.ext ?? info.ext ?? 'mp4').replaceAll('.', '');
      final fileName = title.endsWith('.$ext') ? title : '$title.$ext';
      final vcodec = format.vcodec ?? '';
      final acodec = format.acodec ?? '';
      final mime = YtdlpMime.fromCodecs(ext, vcodec: vcodec, acodec: acodec);
      final kind = YtdlpMime.contentKind(vcodec, acodec, mime);
      final label = _label(
        formatNote: format.formatNote,
        height: format.height,
        ext: ext,
        filesize: format.filesize,
        videoOnly: _videoOnly(vcodec, acodec),
      );
      out.add(
        MediaVariant(
          id: '${format.formatId ?? url.hashCode}',
          label: label,
          sortKey: format.height ?? format.tbr ?? 0,
          resource: AnalyzedResource(
            finalUrl: url,
            fileName: fileName,
            mimeType: mime,
            totalBytes: format.filesize,
            supportsResume: false,
            resolverName: 'yt-dlp',
            contentKind: kind,
            thumbnailUrl: thumb,
          ),
        ),
      );
    }
    out.sort((a, b) => b.sortKey.compareTo(a.sortKey));
    return _dedupeByUrl(out);
  }

  static Future<List<MediaVariant>> _fromProcess(
    String bin,
    String pageUrl,
  ) async {
    final result = await Process.run(
      bin,
      ['--no-playlist', '--no-warnings', '-J', pageUrl],
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
    );
    if (result.exitCode != 0) return const [];
    final json = jsonDecode(result.stdout as String) as Map<String, dynamic>;
    final title = FileNameUtils.sanitize(
      (json['title'] as String? ?? 'video').trim(),
    );
    final thumb = normalizeThumbnailUrl(json['thumbnail'] as String?);
    final formats = json['formats'] as List<dynamic>? ?? [];
    final out = <MediaVariant>[];
    for (final raw in formats) {
      if (raw is! Map<String, dynamic>) continue;
      final url = (raw['url'] as String?)?.trim();
      if (url == null || !url.startsWith('http')) continue;
      final vcodec = raw['vcodec'] as String? ?? 'none';
      final acodec = raw['acodec'] as String? ?? 'none';
      if (!_isMuxedOrSingle(vcodec, acodec)) continue;
      final ext = (raw['ext'] as String? ?? 'mp4').replaceAll('.', '');
      final fileName = title.endsWith('.$ext') ? title : '$title.$ext';
      final mime = YtdlpMime.fromCodecs(ext, vcodec: vcodec, acodec: acodec);
      final kind = YtdlpMime.contentKind(vcodec, acodec, mime);
      final height = raw['height'] as int?;
      final filesize = raw['filesize'] as int? ?? raw['filesize_approx'] as int?;
      final label = _label(
        formatNote: raw['format_note'] as String?,
        height: height,
        ext: ext,
        filesize: filesize,
        videoOnly: _videoOnly(vcodec, acodec),
      );
      out.add(
        MediaVariant(
          id: '${raw['format_id'] ?? url.hashCode}',
          label: label,
          sortKey: height ?? raw['tbr'] as int? ?? 0,
          resource: AnalyzedResource(
            finalUrl: url,
            fileName: fileName,
            mimeType: mime,
            totalBytes: filesize,
            supportsResume: false,
            resolverName: 'yt-dlp',
            contentKind: kind,
            thumbnailUrl: thumb,
          ),
        ),
      );
    }
    out.sort((a, b) => b.sortKey.compareTo(a.sortKey));
    return _dedupeByUrl(out);
  }

  static bool _isMuxedOrSingle(String? vcodec, String? acodec) {
    final hasV = vcodec != null && vcodec != 'none';
    final hasA = acodec != null && acodec != 'none';
    return hasV && hasA || hasV || hasA;
  }

  static bool _videoOnly(String? vcodec, String? acodec) {
    final hasV = vcodec != null && vcodec != 'none';
    final hasA = acodec != null && acodec != 'none';
    return hasV && !hasA;
  }

  static String _label({
    String? formatNote,
    int? height,
    required String ext,
    int? filesize,
    required bool videoOnly,
  }) {
    final parts = <String>[];
    if (height != null && height > 0) {
      parts.add('${height}p');
    } else if (formatNote != null && formatNote.isNotEmpty) {
      parts.add(formatNote);
    }
    parts.add(ext);
    if (filesize != null) parts.add(FormatUtils.formatBytes(filesize));
    if (videoOnly) parts.add('vidéo seule');
    return parts.join(' · ');
  }

  static List<MediaVariant> _dedupeByUrl(List<MediaVariant> list) {
    final seen = <String>{};
    return list.where((v) => seen.add(v.resource.finalUrl)).toList();
  }
}
