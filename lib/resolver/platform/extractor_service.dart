import 'dart:async';
import 'dart:io';

import 'package:extractor/extractor.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../../core/errors/app_exception.dart';
import '../../core/logging/vortex_logger.dart';
import '../../core/utils/file_name_utils.dart';
import '../../core/utils/format_utils.dart';
import '../../downloads/extractor_download_headers.dart';
import '../analyzed_resource.dart';
import '../resolve_result.dart';
import 'ytdlp_format_pick.dart';

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
        enableFFmpeg: true,
        enableAria2c: false,
      );
      _ready = result.success;
      if (_ready) {
        VortexLog.ytdlp.info('extractor prêt (FFmpeg activé)');
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
      final format = await _pickResolvableFormat(pageUrl, info);
      final title = (info.title ?? 'video').trim();

      if (format != null) {
        final mediaUrl = format.url?.trim();
        if (mediaUrl == null || !mediaUrl.startsWith('http')) {
          return const ResolveFailure('URL média invalide renvoyée par yt-dlp.');
        }

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
      }

      VortexLog.ytdlp.info(
        'Fusion audio/vidéo requise (extractor) : $pageUrl',
      );
      final ext = (info.ext ?? 'mp4').replaceAll('.', '');
      final fileName = FileNameUtils.sanitize(
        title.endsWith('.$ext') ? title : '$title.$ext',
      );
      return ResolveSuccess(
        AnalyzedResource(
          finalUrl: pageUrl,
          fileName: fileName,
          mimeType: 'video/mp4',
          supportsResume: false,
          resolverName: 'yt-dlp',
          contentKind: ContentKind.video,
          thumbnailUrl: normalizeThumbnailUrl(info.thumbnail),
          downloadHeaders: ExtractorDownloadHeaders.merged(),
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

  static Future<VideoFormat?> _pickResolvableFormat(
    String pageUrl,
    VideoInfo initial,
  ) async {
    var format = YtdlpFormatPick.bestMuxed(initial);
    if (format != null) return format;

    for (final selector in [
      YtdlpFormatPick.mergedFormatSelector,
      YtdlpFormatPick.mergedFormatSelectorCompat,
    ]) {
      final info = await YoutubeDLFlutter.instance.getVideoInfoWithOptions(
        pageUrl,
        {'--format': selector},
      );
      format = YtdlpFormatPick.bestMuxed(info);
      if (format != null) return format;
      format = YtdlpFormatPick.selectedMuxedFromInfo(info);
      if (format != null) return format;
    }
    return null;
  }

  /// Télécharge et fusionne via yt-dlp + FFmpeg vers [targetPath].
  static Future<void> downloadMergedToFile({
    required String pageUrl,
    required String targetPath,
    required String processId,
    required String formatSelector,
  }) async {
    if (!await ensureReady()) {
      throw const DownloadException(
        'yt-dlp indisponible sur cet appareil.',
      );
    }

    final dir = p.dirname(targetPath);
    final stem = _mergeStemFromPartPath(targetPath);
    final request = DownloadRequest(
      url: pageUrl,
      outputPath: dir,
      outputTemplate: '$stem.%(ext)s',
      format: formatSelector,
      noPlaylist: true,
      embedThumbnail: false,
      embedMetadata: false,
      customOptions: YtdlpFormatPick.mergeDownloadOptions,
      processId: processId,
    );

    VortexLog.ytdlp.info('Téléchargement fusionné → $targetPath');
    final result = await YoutubeDLFlutter.instance.download(request);
    if (result.status != OperationStatus.success) {
      final msg = result.errorMessage?.trim();
      throw DownloadException(
        msg == null || msg.isEmpty
            ? 'Échec de la fusion audio/vidéo.'
            : msg,
      );
    }

    final produced = await _resolveMergedOutputFile(
      dir: dir,
      stem: stem,
      reportedPath: result.outputPath?.trim(),
    );
    if (produced == null) {
      VortexLog.ytdlp.warning(
        'Fichier fusionné introuvable (rapporté : ${result.outputPath})',
      );
      throw const DownloadException('Fichier fusionné absent sur le disque.');
    }

    final producedFile = File(produced);
    final size = await producedFile.length();
    VortexLog.ytdlp.info(
      'Fusion produite : $produced (${FormatUtils.formatBytes(size)})',
    );
    if (size < 48 * 1024) {
      throw const DownloadException(
        'Fichier trop petit — la fusion audio/vidéo a probablement échoué.',
      );
    }

    await _deleteMergeFragments(dir, stem, keepPath: produced);

    final target = File(targetPath);
    if (p.normalize(produced) != p.normalize(targetPath)) {
      if (await target.exists()) await target.delete();
      await producedFile.rename(targetPath);
    }
  }

  /// `…/fichier.mp4.part` → `fichier` (sans `.part` ni extension finale).
  static String _mergeStemFromPartPath(String partPath) {
    var name = p.basename(partPath);
    if (name.endsWith('.part')) {
      name = name.substring(0, name.length - '.part'.length);
    }
    return p.basenameWithoutExtension(name);
  }

  /// Le plugin Android renvoie souvent le modèle `-o` avec `%(ext)s` non résolu.
  static Future<String?> _resolveMergedOutputFile({
    required String dir,
    required String stem,
    required String? reportedPath,
  }) async {
    final candidates = <File>[];

    void addIfMedia(File file) {
      if (!_isMergeOutputCandidate(file.path)) return;
      candidates.add(file);
    }

    if (reportedPath != null && reportedPath.isNotEmpty) {
      if (reportedPath.contains('%(ext)s')) {
        for (final ext in ['mp4', 'mkv', 'webm']) {
          addIfMedia(File(reportedPath.replaceAll('%(ext)s', ext)));
        }
      } else {
        addIfMedia(File(reportedPath));
      }
    }

    for (final ext in ['mp4', 'mkv', 'webm']) {
      addIfMedia(File(p.join(dir, '$stem.$ext')));
    }

    final directory = Directory(dir);
    if (await directory.exists()) {
      await for (final entity in directory.list()) {
        if (entity is! File) continue;
        final name = p.basename(entity.path);
        if (!name.startsWith(stem)) continue;
        addIfMedia(entity);
      }
    }

    if (candidates.isEmpty) return null;

    final existing = <File>[];
    for (final f in candidates) {
      if (await f.exists()) existing.add(f);
    }
    if (existing.isEmpty) return null;

    existing.sort((a, b) => b.lengthSync().compareTo(a.lengthSync()));
    return existing.first.path;
  }

  /// Exclut fragments DASH (`fichier.f1234.mp4`) et pistes audio seules.
  static bool _isMergeOutputCandidate(String path) {
    final name = p.basename(path).toLowerCase();
    if (name.endsWith('.part') || name.endsWith('.m4a')) return false;
    if (RegExp(r'\.f\d+\.').hasMatch(name)) return false;
    return name.endsWith('.mp4') ||
        name.endsWith('.mkv') ||
        name.endsWith('.webm');
  }

  static Future<void> _deleteMergeFragments(
    String dir,
    String stem, {
    required String keepPath,
  }) async {
    final keep = p.normalize(keepPath);
    final directory = Directory(dir);
    if (!await directory.exists()) return;
    await for (final entity in directory.list()) {
      if (entity is! File) continue;
      if (p.normalize(entity.path) == keep) continue;
      final name = p.basename(entity.path);
      if (!name.startsWith(stem)) continue;
      if (name.endsWith('.part')) continue;
      if (RegExp(r'\.f\d+\.').hasMatch(name.toLowerCase()) ||
          name.toLowerCase().endsWith('.m4a')) {
        try {
          await entity.delete();
        } catch (e) {
          VortexLog.ytdlp.fine('Nettoyage fragment : $e');
        }
      }
    }
  }

  static Future<void> cancelDownload(String processId) async {
    if (!isPlatform || !_ready) return;
    try {
      await YoutubeDLFlutter.instance.cancelDownload(processId);
    } catch (e) {
      VortexLog.ytdlp.fine('Annulation extractor $processId : $e');
    }
  }
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
