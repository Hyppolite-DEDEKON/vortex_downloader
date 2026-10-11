import 'dart:io';

import '../errors/app_exception.dart';

class UrlSecurity {
  UrlSecurity._();
  static const maxRedirectDepth = 10;

  static Uri? parseAndValidate(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    Uri uri;
    try {
      uri = Uri.parse(trimmed);
    } catch (_) {
      return null;
    }
    if (uri.scheme != 'http' && uri.scheme != 'https') return null;
    if (uri.host.isEmpty || uri.userInfo.isNotEmpty) return null;
    assertSafeHost(uri.host);
    return uri;
  }

  static Uri normalize(Uri uri) {
    return uri.replace(path: uri.path.isEmpty ? '/' : uri.path);
  }

  static void assertSafeHost(String host) {
    final lower = host.toLowerCase();
    if (lower == 'localhost' ||
        lower.endsWith('.localhost') ||
        lower.endsWith('.local')) {
      throw const SecurityBlockedException(
        'Les adresses locales ne sont pas autorisées.',
      );
    }
    if (lower == '0.0.0.0' || lower == '::1') {
      throw const SecurityBlockedException(
        'Adresse loopback non autorisée.',
      );
    }
    final ip = InternetAddress.tryParse(lower);
    if (ip != null && _isPrivateOrReservedIp(ip)) {
      throw const SecurityBlockedException(
        'Les adresses IP privées ou réservées ne sont pas autorisées.',
      );
    }
  }

  static bool _isPrivateOrReservedIp(InternetAddress ip) {
    if (ip.isLoopback || ip.isLinkLocal) return true;
    final b = ip.rawAddress;
    if (ip.type == InternetAddressType.IPv4 && b.length == 4) {
      if (b[0] == 10 || b[0] == 127 || b[0] == 0) return true;
      if (b[0] == 169 && b[1] == 254) return true;
      if (b[0] == 172 && b[1] >= 16 && b[1] <= 31) return true;
      if (b[0] == 192 && b[1] == 168) return true;
      if (b[0] >= 224) return true;
    }
    if (ip.type == InternetAddressType.IPv6 && b.isNotEmpty) {
      if ((b[0] & 0xfe) == 0xfc) return true;
    }
    return false;
  }

  static String domainFromUrl(String url) {
    final uri = parseAndValidate(url);
    return uri?.host ?? url;
  }
}
