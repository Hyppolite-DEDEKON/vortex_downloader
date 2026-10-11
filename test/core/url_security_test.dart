import 'package:flutter_test/flutter_test.dart';
import 'package:vortex/core/errors/app_exception.dart';
import 'package:vortex/core/utils/url_security.dart';

void main() {
  test('accepte https', () {
    expect(UrlSecurity.parseAndValidate('https://ex.com/a.pdf'), isNotNull);
  });

  test('normalize conserve la query sans conflit Uri', () {
    final raw = Uri.parse('https://ex.com/file?name=a&b=2');
    final n = UrlSecurity.normalize(raw);
    expect(n.query, 'name=a&b=2');
    expect(n.path, '/file');
  });

  test('rejette localhost', () {
    expect(
      () => UrlSecurity.parseAndValidate('http://localhost/x'),
      throwsA(isA<SecurityBlockedException>()),
    );
  });
}
