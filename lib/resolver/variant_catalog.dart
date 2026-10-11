import 'platform/streaming_hosts.dart';
import 'platform/tiktok_platform_extractor.dart';
import 'platform/tiktok_session.dart';
import 'platform/youtube_platform_extractor.dart';
import 'platform/ytdlp_locator.dart';
import 'platform/ytdlp_variant_list.dart';
import 'media_variant.dart';

/// Liste les qualités disponibles pour une URL déjà reconnue.
abstract final class VariantCatalog {
  static Future<List<MediaVariant>> list(
    Uri uri,
    YtdlpLocator locator,
  ) async {
    final url = uri.toString();
    if (YoutubePlatformExtractor.matchesHost(uri.host)) {
      return YoutubePlatformExtractor().listVariants(uri);
    }
    if (TiktokPlatformExtractor.matchesHost(uri.host)) {
      return _tiktokVariants(url);
    }
    if (StreamingHosts.matches(uri.host)) {
      return YtdlpVariantList.list(url, locator);
    }
    return const [];
  }

  static Future<List<MediaVariant>> _tiktokVariants(String pageUrl) async {
    try {
      final session = await TiktokSession.resolve(pageUrl);
      return session.toVariants();
    } catch (_) {
      return const [];
    }
  }
}
