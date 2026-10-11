/// En-têtes HTTP pour les CDN qui refusent le client par défaut (ex. TikTok → 403).
abstract final class PlatformDownloadHeaders {
  static const _browserUa =
      'Mozilla/5.0 (Linux; Android 14; Pixel 7) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36';

  static Map<String, String> tiktok({required String pageReferer}) => {
        'User-Agent': _browserUa,
        'Referer': pageReferer,
        'Origin': 'https://www.tiktok.com',
        'Accept':
            'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'fr-FR,fr;q=0.9,en-US;q=0.8,en;q=0.7',
      };

  static Map<String, String>? forSource({
    required String sourceUrl,
    String? pageReferer,
    String? downloadUrl,
  }) {
    final sourceHost = Uri.tryParse(sourceUrl)?.host;
    final mediaHost = Uri.tryParse(downloadUrl ?? '')?.host;
    final tiktokSource = sourceHost != null && _isTiktokPageHost(sourceHost);
    final tiktokCdn = mediaHost != null && _isTiktokCdnHost(mediaHost);
    if (!tiktokSource && !tiktokCdn) return null;

    final referer = pageReferer ??
        (tiktokSource ? _canonicalReferer(sourceUrl) : 'https://www.tiktok.com/');
    return tiktok(pageReferer: referer);
  }

  static bool _isTiktokPageHost(String host) {
    final h = host.toLowerCase();
    return h == 'tiktok.com' || h.endsWith('.tiktok.com');
  }

  static bool _isTiktokCdnHost(String host) {
    final h = host.toLowerCase();
    if (_isTiktokPageHost(h)) return true;
    return h.contains('tiktokcdn') ||
        h.contains('tiktokv') ||
        h.contains('byteoversea') ||
        h.contains('muscdn');
  }

  static String _canonicalReferer(String sourceUrl) {
    final u = Uri.tryParse(sourceUrl);
    if (u == null) return 'https://www.tiktok.com/';
    if (u.path.contains('/video/')) return sourceUrl;
    return 'https://www.tiktok.com/';
  }
}
