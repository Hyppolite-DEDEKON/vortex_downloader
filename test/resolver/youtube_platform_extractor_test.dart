import 'package:flutter_test/flutter_test.dart';
import 'package:vortex/resolver/platform/youtube_platform_extractor.dart';

void main() {
  test('reconnaît les hôtes YouTube', () {
    expect(YoutubePlatformExtractor.matchesHost('www.youtube.com'), isTrue);
    expect(YoutubePlatformExtractor.matchesHost('youtu.be'), isTrue);
    expect(YoutubePlatformExtractor.matchesHost('m.youtube.com'), isTrue);
    expect(YoutubePlatformExtractor.matchesHost('tiktok.com'), isFalse);
  });
}
