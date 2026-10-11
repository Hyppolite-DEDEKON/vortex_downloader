import 'dart:convert';
import 'dart:io';

import 'package:extractor/extractor.dart';

import '../../downloads/extractor_download_headers.dart';
import '../../core/utils/file_name_utils.dart';
import '../../core/utils/format_utils.dart';
import '../analyzed_resource.dart';
import '../media_variant.dart';
import 'extractor_service.dart' show ExtractorService, YtdlpMime;
import 'ytdlp_format_pick.dart';
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
    final staged = <_StagedVariant>[];
    for (final f in info.formats ?? const <VideoFormat?>[]) {
      final format = f;
      if (format == null) continue;
      final url = format.url?.trim();
      if (url == null || !url.startsWith('http')) continue;
      final vcodec = format.vcodec ?? 'none';
      final acodec = format.acodec ?? 'none';
      if (!_hasTrack(vcodec) && !_hasTrack(acodec)) continue;
      if (_hasTrack(vcodec) && !_hasTrack(acodec)) continue;
      final ext = (format.ext ?? info.ext ?? 'mp4').replaceAll('.', '');
      final fileName = title.endsWith('.$ext') ? title : '$title.$ext';
      final mime = YtdlpMime.fromCodecs(ext, vcodec: vcodec, acodec: acodec);
      final kind = YtdlpMime.contentKind(vcodec, acodec, mime);
      final label = _label(
        formatNote: format.formatNote,
        height: format.height,
        ext: ext,
        filesize: format.filesize,
      );
      staged.add(
        _StagedVariant(
          vcodec: vcodec,
          acodec: acodec,
          variant: MediaVariant(
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
        ),
      );
    }
    final fallback = _variantFromVideoFormat(
      YtdlpFormatPick.bestMuxed(info),
      title: title,
      thumb: thumb,
      defaultExt: info.ext,
      idPrefix: 'muxed_best',
    );
    var out = _completeFilesOnly(staged, fallback: fallback);
    out = _ensureMergedVideoOption(
      out,
      pageUrl: pageUrl,
      title: title,
      thumb: thumb,
      staged: staged,
    );
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
    final staged = <_StagedVariant>[];
    for (final raw in formats) {
      if (raw is! Map<String, dynamic>) continue;
      final url = (raw['url'] as String?)?.trim();
      if (url == null || !url.startsWith('http')) continue;
      final vcodec = raw['vcodec'] as String? ?? 'none';
      final acodec = raw['acodec'] as String? ?? 'none';
      if (!_hasTrack(vcodec) && !_hasTrack(acodec)) continue;
      if (_hasTrack(vcodec) && !_hasTrack(acodec)) continue;
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
      );
      staged.add(
        _StagedVariant(
          vcodec: vcodec,
          acodec: acodec,
          variant: MediaVariant(
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
        ),
      );
    }
    final fallback = _variantFromVideoFormat(
      YtdlpFormatPick.bestMuxedFromJson(json),
      title: title,
      thumb: thumb,
      defaultExt: json['ext'] as String?,
      idPrefix: 'muxed_best',
    );
    var out = _completeFilesOnly(staged, fallback: fallback);
    out = _ensureMergedVideoOption(
      out,
      pageUrl: pageUrl,
      title: title,
      thumb: thumb,
      staged: staged,
    );
    out.sort((a, b) => b.sortKey.compareTo(a.sortKey));
    return _dedupeByUrl(out);
  }

  /// Vidéo+son (+ audio seul en option), jamais vidéo sans son seule.
  static List<MediaVariant> _completeFilesOnly(
    List<_StagedVariant> staged, {
    MediaVariant? fallback,
  }) {
    if (staged.isEmpty && fallback == null) return const [];

    final out = <MediaVariant>[];
    final seen = <String>{};

    void add(MediaVariant v) {
      if (seen.add(v.resource.finalUrl)) out.add(v);
    }

    for (final s in staged) {
      if (_isMuxed(s.vcodec, s.acodec)) add(s.variant);
    }
    if (fallback != null) add(fallback);

    final hasCompleteVideo = out.any(
      (v) => v.resource.contentKind == ContentKind.video,
    );

    if (!hasCompleteVideo) {
      if (!staged.any((s) => _hasTrack(s.vcodec))) {
        for (final s in staged) {
          if (_isAudioOnly(s)) add(s.variant);
        }
      }
      return out;
    }

    for (final s in staged) {
      if (!_isAudioOnly(s)) continue;
      add(
        MediaVariant(
          id: s.variant.id,
          label: '${s.variant.label} · audio seul',
          resource: s.variant.resource,
          sortKey: s.variant.sortKey,
        ),
      );
    }
    return out;
  }

  static MediaVariant? _variantFromVideoFormat(
    VideoFormat? format, {
    required String title,
    required String? thumb,
    required String? defaultExt,
    required String idPrefix,
  }) {
    if (format == null) return null;
    final url = format.url?.trim();
    if (url == null || !url.startsWith('http')) return null;
    final vcodec = format.vcodec ?? 'none';
    final acodec = format.acodec ?? 'none';
    if (!_isMuxed(vcodec, acodec)) return null;
    final ext = (format.ext ?? defaultExt ?? 'mp4').replaceAll('.', '');
    final fileName = title.endsWith('.$ext') ? title : '$title.$ext';
    final mime = YtdlpMime.fromCodecs(ext, vcodec: vcodec, acodec: acodec);
    final kind = YtdlpMime.contentKind(vcodec, acodec, mime);
    return MediaVariant(
      id: '${idPrefix}_${format.formatId ?? url.hashCode}',
      label: _label(
        formatNote: format.formatNote,
        height: format.height,
        ext: ext,
        filesize: format.filesize,
      ),
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
    );
  }

  static bool _isAudioOnly(_StagedVariant s) =>
      _hasTrack(s.acodec) && !_hasTrack(s.vcodec);

  static bool _hasTrack(String? codec) =>
      codec != null && codec.isNotEmpty && codec != 'none';

  static bool _isMuxed(String vcodec, String acodec) =>
      _hasTrack(vcodec) && _hasTrack(acodec);

  static String _label({
    String? formatNote,
    int? height,
    required String ext,
    int? filesize,
  }) {
    final parts = <String>[];
    if (height != null && height > 0) {
      parts.add('${height}p');
    } else if (formatNote != null && formatNote.isNotEmpty) {
      parts.add(formatNote);
    }
    parts.add(ext);
    if (filesize != null) parts.add(FormatUtils.formatBytes(filesize));
    return parts.join(' · ');
  }

  static List<MediaVariant> _dedupeByUrl(List<MediaVariant> list) {
    final seen = <String>{};
    return list.where((v) => seen.add(v.resource.finalUrl)).toList();
  }

  /// Option « meilleure qualité » via fusion yt-dlp (Facebook, etc.).
  static List<MediaVariant> _ensureMergedVideoOption(
    List<MediaVariant> out, {
    required String pageUrl,
    required String title,
    required String? thumb,
    required List<_StagedVariant> staged,
  }) {
    if (!ExtractorService.isPlatform) return out;
    final hasVideo = out.any(
      (v) => v.resource.contentKind == ContentKind.video,
    );
    if (hasVideo) return out;
    if (!staged.any((s) => _hasTrack(s.vcodec))) return out;

    final fileName = title.endsWith('.mp4') ? title : '$title.mp4';
    return [
      MediaVariant(
        id: 'merged_best',
        label: 'Meilleure qualité · mp4',
        sortKey: 1_000_000,
        resource: AnalyzedResource(
          finalUrl: pageUrl,
          fileName: fileName,
          mimeType: 'video/mp4',
          supportsResume: false,
          resolverName: 'yt-dlp',
          contentKind: ContentKind.video,
          thumbnailUrl: thumb,
          downloadHeaders: ExtractorDownloadHeaders.merged(),
        ),
      ),
      ...out,
    ];
  }
}

class _StagedVariant {
  const _StagedVariant({
    required this.vcodec,
    required this.acodec,
    required this.variant,
  });

  final String vcodec;
  final String acodec;
  final MediaVariant variant;
}
