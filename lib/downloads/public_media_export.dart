import 'dart:io';

import 'package:gal/gal.dart';
import 'package:media_store_plus/media_store_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/logging/vortex_logger.dart';
import '../core/utils/file_name_utils.dart';
import '../resolver/analyzed_resource.dart';

/// Copie un fichier terminé vers la galerie (médias) ou le dossier Téléchargements.
abstract final class PublicMediaExport {
  static const _album = 'Vortex';

  static Future<void> export({
    required String localPath,
    required String displayFileName,
    String? mimeType,
  }) async {
    final source = File(localPath);
    if (!await source.exists()) return;

    final kind = kindFromMime(mimeType);
    final staged = await _stagedCopy(source, displayFileName);

    try {
      switch (kind) {
        case ContentKind.image:
          await _exportImage(staged.path);
        case ContentKind.video:
          await _exportVideo(staged.path);
        case ContentKind.audio:
          await _exportDownload(staged.path, DirType.audio, DirName.music);
        default:
          await _exportDownload(staged.path, DirType.download, DirName.download);
      }
      VortexLog.download.info(
        'Export public OK → $displayFileName (${kind.name})',
      );
    } finally {
      if (staged.path != localPath) {
        try {
          await staged.delete();
        } catch (_) {}
      }
    }
  }

  static Future<File> _stagedCopy(File source, String displayFileName) async {
    final tempDir = await getTemporaryDirectory();
    final safe = FileNameUtils.forStorage(
      displayFileName,
      defaultExt: p.extension(source.path).isEmpty ? '.bin' : p.extension(source.path),
    );
    final targetPath = p.join(
      tempDir.path,
      'vortex_export_${DateTime.now().microsecondsSinceEpoch}_$safe',
    );
    return source.copy(targetPath);
  }

  static Future<void> _exportImage(String path) async {
    if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
      await _ensureGalAccess();
      await Gal.putImage(path, album: _album);
      return;
    }
    await _copyToDesktopDownloads(path);
  }

  static Future<void> _exportVideo(String path) async {
    if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
      await _ensureGalAccess();
      await Gal.putVideo(path, album: _album);
      return;
    }
    await _copyToDesktopDownloads(path);
  }

  static Future<void> _exportDownload(
    String path,
    DirType dirType,
    DirName dirName,
  ) async {
    if (Platform.isAndroid) {
      await MediaStore.ensureInitialized();
      final info = await MediaStore().saveFile(
        tempFilePath: path,
        dirType: dirType,
        dirName: dirName,
      );
      if (info == null) {
        throw StateError('MediaStore.saveFile a renvoyé null');
      }
      return;
    }
    await _copyToDesktopDownloads(path);
  }

  static Future<void> _ensureGalAccess() async {
    if (!await Gal.hasAccess(toAlbum: true)) {
      await Gal.requestAccess(toAlbum: true);
    }
    if (!await Gal.hasAccess(toAlbum: true)) {
      throw StateError('Accès galerie refusé');
    }
  }

  static Future<void> _copyToDesktopDownloads(String path) async {
    final downloads = await getDownloadsDirectory();
    if (downloads == null) {
      throw StateError('Dossier Téléchargements indisponible');
    }
    final name = p.basename(path);
    final dest = p.join(downloads.path, FileNameUtils.uniqueName(downloads.path, name));
    await File(path).copy(dest);
  }
}
