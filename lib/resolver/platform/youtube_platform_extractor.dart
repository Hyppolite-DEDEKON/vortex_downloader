import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../../core/logging/vortex_logger.dart';
import '../../core/utils/file_name_utils.dart';
import '../../core/utils/format_utils.dart';
import '../../downloads/extractor_download_headers.dart';
import 'extractor_service.dart';
import 'ytdlp_format_pick.dart';
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
          resolverName: 'YouTube',
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

      void addMuxed(MuxedStreamInfo stream) {
        final ext = stream.container.name;
        final fileName = base.endsWith('.$ext') ? base : '$base.$ext';
        final mime = ext == 'webm' ? 'video/webm' : 'video/mp4';
        final size = stream.size.totalBytes > 0 ? stream.size.totalBytes : null;
        final label = [
          stream.qualityLabel,
          ext,
          if (size != null) FormatUtils.formatBytes(size),
        ].join(' · ');
        out.add(
          MediaVariant(
            id: stream.tag.toString(),
            label: label,
            sortKey: stream.videoResolution.height,
            resource: AnalyzedResource(
              finalUrl: stream.url.toString(),
              fileName: fileName,
              mimeType: mime,
              totalBytes: size,
              supportsResume: false,
              resolverName: 'YouTube',
              contentKind: ContentKind.video,
              thumbnailUrl: thumb,
            ),
          ),
        );
      }

      void addAudioOnly(AudioOnlyStreamInfo stream) {
        final ext = stream.container.name;
        final fileName = base.endsWith('.$ext') ? base : '$base.$ext';
        final mime = ext == 'webm' ? 'audio/webm' : 'audio/mp4';
        final size = stream.size.totalBytes > 0 ? stream.size.totalBytes : null;
        final label = [
          stream.qualityLabel,
          ext,
          if (size != null) FormatUtils.formatBytes(size),
          'audio seul',
        ].join(' · ');
        out.add(
          MediaVariant(
            id: 'audio_${stream.tag}',
            label: label,
            sortKey: stream.bitrate.bitsPerSecond,
            resource: AnalyzedResource(
              finalUrl: stream.url.toString(),
              fileName: fileName,
              mimeType: mime,
              totalBytes: size,
              supportsResume: false,
              resolverName: 'YouTube',
              contentKind: ContentKind.audio,
              thumbnailUrl: thumb,
            ),
          ),
        );
      }

      final muxed =
          manifest.muxed.where((s) => s.container.name != 'm3u8').toList();
      for (final s in muxed) {
        addMuxed(s);
      }

      if (muxed.isNotEmpty) {
        final audios = manifest.audioOnly
            .where((s) => s.container.name != 'm3u8')
            .toList();
        if (audios.isNotEmpty) {
          addAudioOnly(audios.withHighestBitrate());
        }
      }

      _appendHdMergeVariants(
        out,
        pageUrl: pageUrl,
        manifest: manifest,
        base: base,
        thumb: thumb,
      );

      out.sort((a, b) => b.sortKey.compareTo(a.sortKey));
      return out;
    } catch (e, st) {
      VortexLog.resolve.warning('YouTube variantes : $e', e, st);
      return const [];
    } finally {
      yt.close();
    }
  }

  /// 1080p+ : flux DASH fusionnés via yt-dlp (Android).
  static void _appendHdMergeVariants(
    List<MediaVariant> out, {
    required Uri pageUrl,
    required StreamManifest manifest,
    required String base,
    required String thumb,
  }) {
    if (!ExtractorService.isPlatform) return;

    final muxed =
        manifest.muxed.where((s) => s.container.name != 'm3u8').toList();
    final videoOnly =
        manifest.videoOnly.where((s) => s.container.name != 'm3u8').toList();
    if (videoOnly.isEmpty) return;

    final maxMuxed = muxed.isEmpty
        ? 0
        : muxed
            .map((m) => m.videoResolution.height)
            .fold(0, (a, b) => a > b ? a : b);

    final heights = videoOnly
        .map((s) => s.videoResolution.height)
        .where((h) => h > maxMuxed)
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a));

    if (heights.isEmpty) return;

    const ext = 'mp4';
    final fileName = base.endsWith('.$ext') ? base : '$base.$ext';

    for (final h in heights) {
      out.add(
        MediaVariant(
          id: 'yt_hd_merge_$h',
          label: '${h}p · $ext · HD',
          sortKey: h,
          resource: AnalyzedResource(
            finalUrl: pageUrl.toString(),
            fileName: fileName,
            mimeType: 'video/mp4',
            supportsResume: false,
            resolverName: 'YouTube',
            contentKind: ContentKind.video,
            thumbnailUrl: thumb,
            downloadHeaders: ExtractorDownloadHeaders.merged(
              YtdlpFormatPick.formatMergeMaxHeight(h),
            ),
          ),
        ),
      );
    }
  }

  StreamInfo? _pickDownloadStream(StreamManifest manifest) {
    final muxed = manifest.muxed
        .where((s) => s.container.name != 'm3u8')
        .toList();
    if (muxed.isNotEmpty) {
      return muxed.withHighestBitrate();
    }
    return null;
  }
}
