import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:video_compress/video_compress.dart';
import 'package:uuid/uuid.dart';

import '../core/logging/vortex_logger.dart';

/// Conversion vidéo locale (≈420p) après téléchargement.
abstract final class VideoTranscoder {
  static const targetHeight = 420;

  static bool isVideoMime(String? mime) =>
      mime != null && mime.startsWith('video/');

  /// Vérifie les signatures MP4/WebM (évite de transcoder HTML ou une image).
  static Future<bool> looksLikeVideoFile(String path) async {
    final file = File(path);
    if (!file.existsSync()) return false;
    final len = await file.length();
    if (len < 12) return false;
    final raf = await file.open();
    final head = await raf.read(12);
    await raf.close();
    if (head.length < 4) return false;
    // MP4 / MOV : .... ftyp
    if (head.length >= 8 &&
        head[4] == 0x66 &&
        head[5] == 0x74 &&
        head[6] == 0x79 &&
        head[7] == 0x70) {
      return true;
    }
    // WebM
    if (head[0] == 0x1A &&
        head[1] == 0x45 &&
        head[2] == 0xDF &&
        head[3] == 0xA3) {
      return true;
    }
    return false;
  }

  static Future<int> transcodeTo420p({
    required String inputPath,
    required String outputPath,
  }) async {
    if (kIsWeb) {
      throw UnsupportedError('Conversion vidéo non disponible sur le web.');
    }
    if (Platform.isAndroid || Platform.isIOS) {
      return _transcodeWithVideoCompress(inputPath, outputPath);
    }
    return _transcodeWithProcessFfmpeg(inputPath, outputPath);
  }

  static Future<int> _transcodeWithVideoCompress(
    String inputPath,
    String outputPath,
  ) async {
    final source = File(inputPath);
    if (!await source.exists()) {
      throw Exception('Fichier source introuvable : $inputPath');
    }
    final staged = await _stageForNativeTranscode(source);
    try {
      if (!await looksLikeVideoFile(staged.path)) {
        throw Exception(
          'Fichier invalide pour la conversion (pas une vidéo lisible).',
        );
      }
      final compressUri = Uri.file(staged.absolute.path).toString();
      VortexLog.download.fine('Conversion depuis $compressUri');
      VortexLog.download.info('Conversion mobile (≈480p / qualité réduite)');
      final info = await VideoCompress.compressVideo(
        compressUri,
        quality: VideoQuality.Res640x480Quality,
        deleteOrigin: false,
        includeAudio: true,
      );
      final src = info?.path;
      if (src == null || src.isEmpty) {
        throw Exception('Compression vidéo échouée.');
      }
      final compressed = File(src);
      if (!compressed.existsSync()) {
        throw Exception('Fichier compressé introuvable.');
      }
      final out = File(outputPath);
      if (out.existsSync()) await out.delete();
      await compressed.copy(outputPath);
      if (src != staged.path && compressed.path != outputPath) {
        try {
          await compressed.delete();
        } catch (_) {}
      }
      return out.lengthSync();
    } finally {
      if (staged.path != source.path) {
        try {
          await File(staged.path).delete();
        } catch (_) {}
      }
    }
  }

  /// Chemin ASCII simple : video_compress / MediaExtractor cassent sur @ ou espaces.
  static Future<File> _stageForNativeTranscode(File source) async {
    final tmp = await getTemporaryDirectory();
    final stagedPath = p.join(
      tmp.path,
      'vortex_transcode_in_${const Uuid().v4()}.mp4',
    );
    final staged = File(stagedPath);
    if (p.equals(source.absolute.path, stagedPath)) return source;
    await source.copy(stagedPath);
    return staged;
  }

  static Future<int> _transcodeWithProcessFfmpeg(
    String inputPath,
    String outputPath,
  ) async {
    VortexLog.download.info('FFmpeg (bureau) : conversion 420p');
    final result = await Process.run('ffmpeg', [
      '-y',
      '-i',
      inputPath,
      '-vf',
      'scale=-2:$targetHeight',
      '-c:v',
      'libx264',
      '-preset',
      'fast',
      '-crf',
      '28',
      '-c:a',
      'aac',
      '-b:a',
      '128k',
      '-movflags',
      '+faststart',
      outputPath,
    ]);
    if (result.exitCode != 0) {
      final err = '${result.stderr}';
      throw Exception(
        err.contains('not found') || err.isEmpty
            ? 'Installez ffmpeg sur ce poste pour la qualité 420p.'
            : 'ffmpeg : $err',
      );
    }
    return File(outputPath).lengthSync();
  }

  static String outputPathFor420p(String downloadedPath) {
    final dir = p.dirname(downloadedPath);
    final base = p.basenameWithoutExtension(downloadedPath);
    return p.join(dir, '${base}_tmp_420p.mp4');
  }
}
