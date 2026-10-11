import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../../core/logging/vortex_logger.dart';
import '../../core/utils/file_name_utils.dart';
import '../../core/utils/format_utils.dart';
import '../analyzed_resource.dart';
import '../media_variant.dart';
import '../resolve_result.dart';

class YoutubePlatformExtractor {
  static bool matchesHost(String host) {
    final h = host.toLowerCase();
    return h == 'youtu.be' ||
        h == 'youtube.com' ||
        h.endsWith('.youtube.com') ||
        h == 'youtube-nocookie.com' ||
        h.endsWith('.youtube-nocookie.com');
  }

  Future<ResolveResult> resolve(Uri pageUrl) async {
    VortexLog.resolve.info('YouTube (explode) : $pageUrl');
    final yt = YoutubeExplode();
    try {
      final videoId = VideoId(pageUrl.toString());
      final video = await yt.videos.get(videoId);
      if (video.isLive) {
        return const ResolveFailure(
          'Les diffusions en direct ne peuvent pas être téléchargées.',
        );
      }
      final manifest = await yt.videos.streams.getManifest(videoId);
      final stream = _pickDownloadStream(manifest);
      if (stream == null) {
        return const ResolveFailure(
          'Aucun flux MP4/WebM téléchargeable pour cette vidéo.',
        );
      }
      final ext = stream.container.name;
      final base = FileNameUtils.sanitize(video.title);
      final fileName = base.endsWith('.$ext') ? base : '$base.$ext';
      final mime = ext == 'webm' ? 'video/webm' : 'video/mp4';

      final thumb = video.thumbnails.highResUrl;
      VortexLog.resolve.info('YouTube OK → $fileName');
      return ResolveSuccess(
        AnalyzedResource(
          finalUrl: stream.url.toString(),
          fileName: fileName,
          mimeType: mime,
          totalBytes:
              stream.size.totalBytes > 0 ? stream.size.totalBytes : null,
          supportsResume: false,
          resolverName: stream is VideoOnlyStreamInfo ? 'YouTube (vidéo)' : 'YouTube',
          contentKind: ContentKind.video,
          thumbnailUrl: thumb,
        ),
      );
    } on ArgumentError {
      VortexLog.resolve.warning('YouTube : URL invalide');
      return const ResolveFailure('Lien YouTube invalide.');
    } on VideoUnavailableException {
      VortexLog.resolve.warning('YouTube : vidéo indisponible');
      return const ResolveFailure('Vidéo YouTube indisponible ou supprimée.');
    } on YoutubeExplodeException catch (e) {
      VortexLog.resolve.warning('YouTube explode : ${e.message}');
      return ResolveFailure(
        'Extraction YouTube impossible : ${e.message}',
      );
    } catch (e, st) {
      VortexLog.resolve.warning('YouTube : $e', e, st);
      return ResolveFailure('Extraction YouTube impossible : $e');
    } finally {
      yt.close();
    }
  }

  Future<List<MediaVariant>> listVariants(Uri pageUrl) async {
    final yt = YoutubeExplode();
    try {
      final videoId = VideoId(pageUrl.toString());
      final video = await yt.videos.get(videoId);
      if (video.isLive) return const [];
      final manifest = await yt.videos.streams.getManifest(videoId);
      final base = FileNameUtils.sanitize(video.title);
      final thumb = video.thumbnails.highResUrl;
      final out = <MediaVariant>[];

      void addStream(StreamInfo stream, {required bool videoOnly}) {
        final ext = stream.container.name;
        final fileName = base.endsWith('.$ext') ? base : '$base.$ext';
        final mime = ext == 'webm' ? 'video/webm' : 'video/mp4';
        final size = stream.size.totalBytes > 0 ? stream.size.totalBytes : null;
        final height = stream is VideoStreamInfo
            ? stream.videoResolution.height
            : 0;
        final label = [
          stream.qualityLabel,
          ext,
          if (size != null) FormatUtils.formatBytes(size),
          if (videoOnly) 'vidéo seule',
        ].join(' · ');
        out.add(
          MediaVariant(
            id: stream.tag.toString(),
            label: label,
            sortKey: height,
            resource: AnalyzedResource(
              finalUrl: stream.url.toString(),
              fileName: fileName,
              mimeType: mime,
              totalBytes: size,
              supportsResume: false,
              resolverName: videoOnly ? 'YouTube (vidéo)' : 'YouTube',
              contentKind: ContentKind.video,
              thumbnailUrl: thumb,
            ),
          ),
        );
      }

      final muxed =
          manifest.muxed.where((s) => s.container.name != 'm3u8').toList();
      for (final s in muxed) {
        addStream(s, videoOnly: false);
      }
      final videoOnly =
          manifest.videoOnly.where((s) => s.container.name != 'm3u8').toList();
      for (final s in videoOnly) {
        addStream(s, videoOnly: true);
      }
      out.sort((a, b) => b.sortKey.compareTo(a.sortKey));
      return out;
    } catch (_) {
      return const [];
    } finally {
      yt.close();
    }
  }

  StreamInfo? _pickDownloadStream(StreamManifest manifest) {
    final muxed = manifest.muxed
        .where((s) => s.container.name != 'm3u8')
        .toList();
    if (muxed.isNotEmpty) {
      return muxed.withHighestBitrate();
    }
    final videoOnly = manifest.videoOnly
        .where((s) => s.container.name != 'm3u8')
        .toList();
    if (videoOnly.isNotEmpty) {
      return videoOnly.withHighestBitrate();
    }
    return null;
  }
}
