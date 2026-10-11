import 'package:extractor/extractor.dart';

/// Sélection des formats yt-dlp (vidéo + audio dans le même fichier).
abstract final class YtdlpFormatPick {
  /// Fusion DASH — pas de repli sur `best` vidéo seule (sinon fichier sans son).
  static const mergedFormatSelector = 'bv*+ba/b[acodec!=none][vcodec!=none]';

  static const mergedFormatSelectorCompat = 'bestvideo+bestaudio/b[acodec!=none][vcodec!=none]';

  /// Options yt-dlp pour forcer le mux en MP4 (via FFmpeg embarqué).
  static Map<String?, String?> get mergeDownloadOptions => {
        '--merge-output-format': 'mp4',
      };

  /// Fusion DASH plafonnée à [maxHeight] (YouTube HD, etc.).
  static String formatMergeMaxHeight(int maxHeight) =>
      'bv*[height<=$maxHeight]+ba/b[height<=$maxHeight]';

  static VideoFormat? bestMuxed(VideoInfo info) {
    final direct = info.url?.trim();
    if (direct != null && direct.startsWith('http')) {
      final v = info.vcodec ?? '';
      final a = info.acodec ?? '';
      if (_hasTrack(v) && _hasTrack(a)) {
        return VideoFormat(
          url: direct,
          ext: info.ext,
          filesize: null,
          vcodec: v,
          acodec: a,
          width: info.width,
          height: info.height,
          formatId: 'default',
        );
      }
    }

    final formats = info.formats;
    if (formats == null || formats.isEmpty) return null;

    VideoFormat? best;
    for (final f in formats) {
      if (f == null) continue;
      final url = f.url?.trim();
      if (url == null || !url.startsWith('http')) continue;
      if (!_hasTrack(f.vcodec) || !_hasTrack(f.acodec)) continue;
      final h = f.height ?? 0;
      final bestH = best?.height ?? 0;
      if (best == null || h > bestH) best = f;
    }
    return best;
  }

  static VideoFormat? bestMuxedFromJson(Map<String, dynamic> json) {
    final direct = (json['url'] as String?)?.trim();
    if (direct != null && direct.startsWith('http')) {
      final v = json['vcodec'] as String? ?? 'none';
      final a = json['acodec'] as String? ?? 'none';
      if (_hasTrack(v) && _hasTrack(a)) {
        return VideoFormat(
          url: direct,
          ext: json['ext'] as String?,
          filesize: json['filesize'] as int?,
          vcodec: v,
          acodec: a,
          height: json['height'] as int?,
          formatId: 'default',
        );
      }
    }

    final formats = json['formats'] as List<dynamic>? ?? [];
    VideoFormat? best;
    for (final raw in formats) {
      if (raw is! Map<String, dynamic>) continue;
      final url = (raw['url'] as String?)?.trim();
      if (url == null || !url.startsWith('http')) continue;
      final vcodec = raw['vcodec'] as String? ?? 'none';
      final acodec = raw['acodec'] as String? ?? 'none';
      if (!_hasTrack(vcodec) || !_hasTrack(acodec)) continue;
      final height = raw['height'] as int?;
      final h = height ?? 0;
      final bestH = best?.height ?? 0;
      if (best == null || h > bestH) {
        best = VideoFormat(
          url: url,
          ext: raw['ext'] as String?,
          filesize: raw['filesize'] as int? ?? raw['filesize_approx'] as int?,
          vcodec: vcodec,
          acodec: acodec,
          height: height,
          formatNote: raw['format_note'] as String?,
          formatId: raw['format_id']?.toString(),
        );
      }
    }
    return best;
  }

  /// Format déjà sélectionné par yt-dlp (`-f`) avec piste vidéo et audio.
  static VideoFormat? selectedMuxedFromInfo(VideoInfo info) {
    final url = info.url?.trim();
    if (url == null || !url.startsWith('http')) return null;
    final v = info.vcodec ?? 'none';
    final a = info.acodec ?? 'none';
    if (!_hasTrack(v) || !_hasTrack(a)) return null;
    return VideoFormat(
      url: url,
      ext: info.ext,
      filesize: null,
      vcodec: v,
      acodec: a,
      width: info.width,
      height: info.height,
      formatId: 'selected',
    );
  }

  static bool _hasTrack(String? codec) =>
      codec != null && codec.isNotEmpty && codec != 'none';
}
