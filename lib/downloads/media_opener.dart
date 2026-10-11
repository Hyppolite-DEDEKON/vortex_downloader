import 'dart:io';

import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';

import '../features/downloads/domain/download_task.dart';

enum OpenDownloadResult { success, missing, noApp, failed }

class MediaOpener {
  Future<OpenDownloadResult> openDownload(DownloadTask task) async {
    final path = task.localPath;
    if (path == null || path.isEmpty) return OpenDownloadResult.missing;
    if (!await File(path).exists()) return OpenDownloadResult.missing;

    final result = await OpenFilex.open(path, type: task.mimeType);
    switch (result.type) {
      case ResultType.done:
        return OpenDownloadResult.success;
      case ResultType.noAppToOpen:
        return OpenDownloadResult.noApp;
      case ResultType.fileNotFound:
        return OpenDownloadResult.missing;
      default:
        return OpenDownloadResult.failed;
    }
  }

  Future<void> open(String path) => OpenFilex.open(path);

  Future<void> share(String path, {String? subject}) =>
      SharePlus.instance.share(
        ShareParams(files: [XFile(path)], subject: subject),
      );

  Future<void> deleteFile(String path) async {
    final f = File(path);
    if (await f.exists()) await f.delete();
  }
}

String openDownloadMessage(OpenDownloadResult result) => switch (result) {
      OpenDownloadResult.success => '',
      OpenDownloadResult.missing => 'Fichier introuvable sur l’appareil.',
      OpenDownloadResult.noApp =>
        'Aucune application pour ouvrir ce type de fichier.',
      OpenDownloadResult.failed => 'Impossible d’ouvrir le fichier.',
    };
