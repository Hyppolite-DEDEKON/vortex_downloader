import 'package:flutter/services.dart';

import '../core/utils/url_security.dart';

class ClipboardService {
  Future<String?> readUrl() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text == null || text.isEmpty) return null;
    return UrlSecurity.parseAndValidate(text)?.toString();
  }

  Future<void> pasteToController(void Function(String url) onUrl) async {
    final url = await readUrl();
    if (url != null) onUrl(url);
  }
}
