import 'package:tiktok_scraper/tiktok_scraper.dart';

import '../../core/logging/vortex_logger.dart';
import '../analyzed_resource.dart';
import '../resolve_result.dart';
import 'tiktok_session.dart';

/// TikTok via scraping HTML (sans curl_cffi / yt-dlp).
///
/// Nécessaire sur Android où yt-dlp ne peut pas faire l’impersonation TLS TikTok.
/// Les flux sont choisis sans filigrane (bitrateInfo / playAddr, pas downloadAddr).
class TiktokPlatformExtractor {
  static bool matchesHost(String host) {
    final h = host.toLowerCase();
    return h == 'tiktok.com' || h.endsWith('.tiktok.com');
  }

  Future<ResolveResult> resolve(String pageUrl) async {
    VortexLog.resolve.info('TikTok (scraper) : $pageUrl');
    try {
      final session = await TiktokSession.resolve(pageUrl);
      final primary = session.entries.first;
      VortexLog.resolve.info(
        session.isPhotoPost
            ? 'TikTok photo OK → ${primary.fileName} (${session.entries.length} image(s))'
            : 'TikTok OK → ${primary.fileName}',
      );
      return ResolveSuccess(
        AnalyzedResource(
          finalUrl: primary.url,
          fileName: primary.fileName,
          mimeType: primary.mimeType,
          totalBytes: null,
          supportsResume: false,
          resolverName: 'TikTok',
          contentKind: primary.kind,
          downloadHeaders: session.downloadHeaders,
          thumbnailUrl: normalizeThumbnailUrl(session.video.thumbnail),
        ),
        variants: session.toVariants(),
      );
    } on TikTokException catch (e) {
      VortexLog.resolve.warning('TikTok scraper : ${e.message}');
      return ResolveFailure(e.message);
    } catch (e, st) {
      VortexLog.resolve.warning('TikTok scraper erreur', e, st);
      return ResolveFailure('TikTok : $e');
    }
  }

}
