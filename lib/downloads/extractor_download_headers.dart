import '../resolver/platform/ytdlp_format_pick.dart';

/// Marqueurs pour télécharger via yt-dlp + FFmpeg (fusion DASH) sur Android.
abstract final class ExtractorDownloadHeaders {
  static const merge = 'x-vortex-ytdlp-merge';
  static const format = 'x-vortex-ytdlp-format';

  static bool isMergedDownload(Map<String, String>? headers) =>
      headers?[merge] == '1';

  static String formatSelector(Map<String, String>? headers) =>
      headers?[format] ?? YtdlpFormatPick.mergedFormatSelector;

  static Map<String, String> merged([
    String formatSelector = YtdlpFormatPick.mergedFormatSelector,
  ]) =>
      {
        merge: '1',
        format: formatSelector,
      };
}
