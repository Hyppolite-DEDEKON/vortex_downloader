import 'dart:io';

import 'package:path/path.dart' as p;

class FileNameUtils {
  FileNameUtils._();
  static final _invalid = RegExp(r'[<>:"/\\|?*\x00-\x1f]');

  static String sanitize(String name) {
    var cleaned = name.trim().replaceAll(_invalid, '_');
    cleaned = cleaned.replaceAll('@', '_');
    cleaned = cleaned.replaceAll('#', '_');
    cleaned = cleaned.replaceAll(RegExp(r'[\u{1F000}-\u{1FAFF}]', unicode: true), '');
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ');
    cleaned = cleaned.replaceAll(RegExp(r'\s+\.'), '.');
    cleaned = cleaned.trim();
    if (cleaned.isEmpty || cleaned == '.' || cleaned == '..') {
      cleaned = 'fichier';
    }
    if (cleaned.length > 180) {
      final ext = p.extension(cleaned);
      final base = p.basenameWithoutExtension(cleaned);
      cleaned = '${base.substring(0, 170 - ext.length)}$ext';
    }
    return cleaned;
  }

  /// Nom sûr pour le stockage local (évite @, espaces avant l’extension, etc.).
  static String forStorage(String fileName, {String defaultExt = '.mp4'}) {
    var safe = sanitize(fileName);
    final ext = p.extension(safe);
    if (ext.isEmpty) {
      safe = '$safe$defaultExt';
    }
    return safe;
  }

  /// Nom physique sur disque (ASCII, sans @/# — requis pour video_compress sur Android).
  static String diskNameForTask(
    String taskId, {
    required bool reduced420p,
    String ext = '.mp4',
  }) {
    final slug = taskId.replaceAll('-', '').substring(0, 12);
    final normalizedExt = ext.startsWith('.') ? ext : '.$ext';
    if (reduced420p) return 'vortex_${slug}_420p$normalizedExt';
    return 'vortex_$slug$normalizedExt';
  }

  static String uniqueName(String directory, String fileName) {
    final safe = sanitize(fileName);
    var candidate = safe;
    var i = 1;
    while (File(p.join(directory, candidate)).existsSync()) {
      final ext = p.extension(safe);
      final base = p.basenameWithoutExtension(safe);
      candidate = ext.isEmpty ? '${base}_$i' : '${base}_$i$ext';
      i++;
    }
    return candidate;
  }
}
