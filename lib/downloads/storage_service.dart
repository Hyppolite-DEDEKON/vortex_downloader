import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class StorageService {
  StorageService({String? overridePath}) : _override = overridePath;

  final String? _override;
  Directory? _dir;

  Future<Directory> downloadsDirectory() async {
    if (_override != null) {
      final d = Directory(_override);
      if (!await d.exists()) await d.create(recursive: true);
      return d;
    }
    if (_dir != null) return _dir!;
    final base = await getApplicationDocumentsDirectory();
    final d = Directory(p.join(base.path, 'vortex_downloads'));
    if (!await d.exists()) await d.create(recursive: true);
    return _dir = d;
  }

  Future<int> totalBytes() async {
    final dir = await downloadsDirectory();
    var n = 0;
    await for (final e in dir.list(recursive: true)) {
      if (e is File) n += await e.length();
    }
    return n;
  }

  Future<void> clearAll() async {
    final dir = await downloadsDirectory();
    if (await dir.exists()) {
      await for (final e in dir.list()) {
        await e.delete(recursive: true);
      }
    }
  }
}
