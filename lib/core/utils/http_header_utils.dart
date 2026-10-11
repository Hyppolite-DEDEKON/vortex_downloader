import 'package:path/path.dart' as p;

import 'file_name_utils.dart';

class HttpHeaderUtils {
  HttpHeaderUtils._();

  static String? fileNameFromContentDisposition(String? header) {
    if (header == null) return null;
    final utf8 = RegExp(r"filename\*=UTF-8''([^;]+)", caseSensitive: false)
        .firstMatch(header);
    if (utf8 != null) {
      return FileNameUtils.sanitize(Uri.decodeComponent(utf8.group(1)!));
    }
    final q = RegExp(r'filename="([^"]+)"', caseSensitive: false)
        .firstMatch(header);
    if (q != null) return FileNameUtils.sanitize(q.group(1)!);
    final plain = RegExp(r'filename=([^;]+)', caseSensitive: false)
        .firstMatch(header);
    if (plain != null) return FileNameUtils.sanitize(plain.group(1)!);
    return null;
  }

  static String fileNameFromUrl(Uri uri) {
    final seg = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : '';
    if (seg.contains('.')) return FileNameUtils.sanitize(seg);
    return 'fichier';
  }
}

String guessExt(String? mime, String name) {
  if (p.extension(name).isNotEmpty) return p.extension(name);
  return switch (mime) {
    'application/pdf' => '.pdf',
    'image/jpeg' => '.jpg',
    'image/png' => '.png',
    'video/mp4' => '.mp4',
    'application/zip' => '.zip',
    _ => '',
  };
}
