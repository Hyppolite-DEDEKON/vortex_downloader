import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/logging/vortex_logger.dart';

/// Télécharge yt-dlp dans le dossier de l’app (desktop) pour éviter toute config manuelle.
abstract final class YtdlpBootstrap {
  static const _minBytes = 500_000;

  static Future<String?> ensureBinary() async {
    if (!_supportsAutoInstall) return null;

    try {
      final support = await getApplicationSupportDirectory();
      final dir = Directory(p.join(support.path, 'tools'));
      await dir.create(recursive: true);

      final fileName = Platform.isWindows ? 'yt-dlp.exe' : 'yt-dlp';
      final dest = File(p.join(dir.path, fileName));

      if (await dest.exists() && await dest.length() > _minBytes) {
        VortexLog.ytdlp.fine('yt-dlp local : ${dest.path}');
        return dest.path;
      }

      final url = _releaseUrl;
      if (url == null) return null;

      VortexLog.ytdlp.info('Téléchargement yt-dlp depuis $url');
      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(minutes: 3),
          followRedirects: true,
        ),
      );
      await dio.download(url, dest.path);

      if (!await dest.exists() || await dest.length() < _minBytes) {
        await dest.delete();
        return null;
      }

      if (!Platform.isWindows) {
        await Process.run('chmod', ['+x', dest.path]);
      }
      VortexLog.ytdlp.info('yt-dlp installé : ${dest.path}');
      return dest.path;
    } catch (e, st) {
      VortexLog.ytdlp.warning('Installation yt-dlp impossible', e, st);
      return null;
    }
  }

  static bool get _supportsAutoInstall =>
      Platform.isLinux || Platform.isMacOS || Platform.isWindows;

  static String? get _releaseUrl {
    if (Platform.isLinux) {
      return 'https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_linux';
    }
    if (Platform.isMacOS) {
      return 'https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_macos';
    }
    if (Platform.isWindows) {
      return 'https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp.exe';
    }
    return null;
  }
}
