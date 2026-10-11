/// Hôtes pour lesquels on tente yt-dlp avant l’analyse HTML lourde.
abstract final class StreamingHosts {
  static const _suffixes = [
    'youtube.com',
    'youtu.be',
    'tiktok.com',
    'instagram.com',
    'facebook.com',
    'fb.watch',
    'twitter.com',
    'x.com',
    'vimeo.com',
    'dailymotion.com',
    'twitch.tv',
    'reddit.com',
    'pinterest.com',
    'soundcloud.com',
    'bilibili.com',
    'snapchat.com',
    'linkedin.com',
    'rumble.com',
    'kick.com',
  ];

  static bool matches(String host) {
    final h = host.toLowerCase();
    for (final s in _suffixes) {
      if (h == s || h.endsWith('.$s')) return true;
    }
    return false;
  }
}
