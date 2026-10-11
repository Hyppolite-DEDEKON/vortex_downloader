import 'dart:io';

import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';

class MediaOpener {
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
