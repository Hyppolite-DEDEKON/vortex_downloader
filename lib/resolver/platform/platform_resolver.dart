import '../../core/logging/vortex_logger.dart';
import '../resolver_contract.dart';
import '../resolve_result.dart';
import 'streaming_hosts.dart';
import 'tiktok_platform_extractor.dart';
import 'youtube_platform_extractor.dart';
import 'ytdlp_platform_extractor.dart';
import 'ytdlp_locator.dart';

class PlatformResolver implements SourceResolver {
  PlatformResolver({
    required YtdlpLocator ytdlpLocator,
    YoutubePlatformExtractor? youtube,
    YtdlpPlatformExtractor? ytdlp,
    TiktokPlatformExtractor? tiktok,
  })  : _youtube = youtube ?? YoutubePlatformExtractor(),
        _ytdlp = ytdlp ?? YtdlpPlatformExtractor(ytdlpLocator),
        _tiktok = tiktok ?? TiktokPlatformExtractor();

  final YoutubePlatformExtractor _youtube;
  final YtdlpPlatformExtractor _ytdlp;
  final TiktokPlatformExtractor _tiktok;

  @override
  String get name => 'Platform';

  @override
  Future<ResolveResult> resolve(Uri uri, ProbeContext ctx) async {
    final url = uri.toString();

    if (YoutubePlatformExtractor.matchesHost(uri.host)) {
      VortexLog.resolve.fine('Hôte YouTube détecté');
      final native = await _youtube.resolve(uri);
      if (native is ResolveSuccess) return native;
      VortexLog.resolve.fine('Repli YouTube via yt-dlp');
      final viaYtdlp = await _ytdlp.resolveOrUnsupported(url);
      if (viaYtdlp is ResolveSuccess) return viaYtdlp;
      if (viaYtdlp is ResolveFailure) return viaYtdlp;
      if (native is ResolveFailure) return native;
    }

    if (StreamingHosts.matches(uri.host)) {
      VortexLog.resolve.fine('Hôte streaming : ${uri.host}');
      if (TiktokPlatformExtractor.matchesHost(uri.host)) {
        final tiktok = await _tiktok.resolve(url);
        if (tiktok is ResolveSuccess) return tiktok;
        if (tiktok is ResolveFailure &&
            tiktok.message.contains('TikTok photo')) {
          VortexLog.resolve.fine(
            'Pas de repli yt-dlp pour carrousel TikTok photo',
          );
          return tiktok;
        }
        VortexLog.resolve.fine(
          'Repli TikTok via yt-dlp (${tiktok is ResolveFailure ? tiktok.message : 'échec scraper'})',
        );
      }
      return _ytdlp.resolve(url);
    }

    return const ResolveUnsupported('Pas d’extracteur plateforme pour cet hôte.');
  }
}

class YtdlpResolver implements SourceResolver {
  YtdlpResolver(YtdlpLocator locator)
      : _ytdlp = YtdlpPlatformExtractor(locator);

  final YtdlpPlatformExtractor _ytdlp;

  @override
  String get name => 'yt-dlp';

  @override
  Future<ResolveResult> resolve(Uri uri, ProbeContext ctx) async {
    return _ytdlp.resolveOrUnsupported(uri.toString());
  }
}
