import 'dart:async';
import 'dart:io';

import 'package:extractor/extractor.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../core/logging/vortex_logger.dart';
import '../../core/utils/file_name_utils.dart';
import '../analyzed_resource.dart';
import '../resolve_result.dart';

/// yt-dlp embarqué sur Android via le plugin [extractor].
abstract final class ExtractorService {
  static const bundledMarker = '@vortex/extractor';

  static bool get isPlatform => !kIsWeb && Platform.isAndroid;

  static bool _ready = false;
  static Future<void>? _initFuture;

  static bool get isReady => _ready;

  static Future<bool> ensureReady() async {
    if (!isPlatform) return false;
    _initFuture ??= _initialize();
    await _initFuture;
    return _ready;
  }

  static Future<void> _maybeUpdateYtdlp() async {
    try {
      final update = await YoutubeDLFlutter.instance.updateYoutubeDL();
      if (update.status == OperationStatus.success) {
        VortexLog.ytdlp.fine('yt-dlp Android mis à jour : ${update.version}');
      }
    } catch (e) {
      VortexLog.ytdlp.fine('Mise à jour yt-dlp Android ignorée : $e');
    }
  }

  static Future<void> _initialize() async {
    try {
      VortexLog.ytdlp.info('Initialisation extractor (Android)…');
      final result = await YoutubeDLFlutter.instance.initialize(
        enableFFmpeg: false,
        enableAria2c: false,
      );
      _ready = result.success;
      if (_ready) {
        VortexLog.ytdlp.info('extractor prêt');
        unawaited(_maybeUpdateYtdlp());
      } else {
        VortexLog.ytdlp.warning(
          'extractor indisponible : ${result.errorMessage ?? 'erreur inconnue'}',
        );
      }
    } catch (e, st) {
      _ready = false;
      VortexLog.ytdlp.warning('extractor init échouée', e, st);
    }
  }

  static Future<ResolveResult> resolve(String pageUrl) async {
    if (!await ensureReady()) {
      return const ResolveFailure(
        'Impossible de préparer yt-dlp sur cet appareil. '
        'Réessayez après redémarrage de l’application.',
      );
    }

    try {
      VortexLog.ytdlp.info('Extraction extractor : $pageUrl');
      final info = await YoutubeDLFlutter.instance.getVideoInfo(pageUrl);
      final format = _pickFormat(info);
      if (format == null) {
        return const ResolveFailure(
          'Format nécessitant une fusion audio/vidéo non géré. '
          'Réessayez une autre qualité ou mettez à jour yt-dlp.',
        );
      }

      final mediaUrl = format.url?.trim();
      if (mediaUrl == null || !mediaUrl.startsWith('http')) {
        return const ResolveFailure('URL média invalide renvoyée par yt-dlp.');
      }

      final title = (info.title ?? 'video').trim();
      final ext = (format.ext ?? info.ext ?? 'mp4').replaceAll('.', '');
      final fileName = FileNameUtils.sanitize(
        title.endsWith('.$ext') ? title : '$title.$ext',
      );
      final vcodec = format.vcodec ?? info.vcodec ?? '';
      final acodec = format.acodec ?? info.acodec ?? '';
      final mime = YtdlpMime.fromCodecs(ext, vcodec: vcodec, acodec: acodec);
      final kind = YtdlpMime.contentKind(vcodec, acodec, mime);

      VortexLog.ytdlp.info('extractor OK → $fileName');
      return ResolveSuccess(
        AnalyzedResource(
          finalUrl: mediaUrl,
          fileName: fileName,
          mimeType: mime,
          totalBytes: format.filesize,
          supportsResume: false,
          resolverName: 'yt-dlp',
          contentKind: kind,
          thumbnailUrl: normalizeThumbnailUrl(info.thumbnail),
        ),
      );
    } on PlatformException catch (e) {
      VortexLog.ytdlp.warning('extractor : ${e.message}');
      final msg = e.message?.trim();
      if (msg == null || msg.isEmpty) {
        return const ResolveFailure('yt-dlp n’a pas pu extraire ce lien.');
      }
      final short = msg.length > 280 ? '${msg.substring(0, 280)}…' : msg;
      return ResolveFailure(short);
    } catch (e, st) {
      VortexLog.ytdlp.warning('extractor erreur', e, st);
      return ResolveFailure('yt-dlp : $e');
    }
  }

  static VideoFormat? _pickFormat(VideoInfo info) {
    final direct = info.url?.trim();
    if (direct != null && direct.startsWith('http')) {
      return VideoFormat(
        url: direct,
        ext: info.ext,
        filesize: null,
        vcodec: info.vcodec,
        acodec: info.acodec,
        width: info.width,
        height: info.height,
      );
    }

    final formats = info.formats;
    if (formats == null || formats.isEmpty) return null;

    VideoFormat? bestCombined;
    for (final f in formats) {
      if (f == null) continue;
      final url = f.url?.trim();
      if (url == null || !url.startsWith('http')) continue;

      final hasVideo = _hasTrack(f.vcodec);
      final hasAudio = _hasTrack(f.acodec);
      if (hasVideo && hasAudio) {
        final h = f.height ?? 0;
        final bestH = bestCombined?.height ?? 0;
        if (bestCombined == null || h > bestH) bestCombined = f;
      }
    }
    return bestCombined;
  }

  static bool _hasTrack(String? codec) =>
      codec != null && codec.isNotEmpty && codec != 'none';
}

/// MIME / type dérivés des codecs (partagé desktop + Android).
abstract final class YtdlpMime {
  static String? fromCodecs(
    String ext, {
    required String vcodec,
    required String acodec,
  }) {
    switch (ext.toLowerCase()) {
      case 'mp4':
      case 'm4v':
        return 'video/mp4';
      case 'webm':
        return vcodec == 'none' ? 'audio/webm' : 'video/webm';
      case 'mp3':
        return 'audio/mpeg';
      case 'm4a':
        return 'audio/mp4';
      case 'wav':
        return 'audio/wav';
      case 'flac':
        return 'audio/flac';
      case 'ogg':
        return 'audio/ogg';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      default:
        if (vcodec != 'none' && vcodec.isNotEmpty) return 'video/mp4';
        if (acodec != 'none' && acodec.isNotEmpty) return 'audio/mpeg';
        return null;
    }
  }

  static ContentKind contentKind(String vcodec, String acodec, String? mime) {
    if (mime != null) return kindFromMime(mime);
    final hasVideo = vcodec.isNotEmpty && vcodec != 'none';
    final hasAudio = acodec.isNotEmpty && acodec != 'none';
    if (hasVideo) return ContentKind.video;
    if (hasAudio) return ContentKind.audio;
    return ContentKind.unknown;
  }
}
