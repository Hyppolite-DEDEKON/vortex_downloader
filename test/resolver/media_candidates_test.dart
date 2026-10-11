import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html;
import 'package:vortex/resolver/source_resolver.dart';

void main() {
  test('priorise og:video avant og:image', () {
    final doc = html.parse('''
      <html><head>
        <meta property="og:image" content="https://cdn.example/thumb.jpg" />
        <meta property="og:video:url" content="https://cdn.example/clip.mp4" />
      </head></html>
    ''');
    final urls = collectMediaCandidatesForTest(
      doc,
      Uri.parse('https://example.com/v/1'),
    );
    expect(urls.first, 'https://cdn.example/clip.mp4');
    expect(urls.last, 'https://cdn.example/thumb.jpg');
  });

  test('détecte un lien direct .mp4 dans la page', () {
    final doc = html.parse('''
      <html><body>
        <a href="https://cdn.example/media/episode.mp4">Voir</a>
      </body></html>
    ''');
    final urls = collectMediaCandidatesForTest(
      doc,
      Uri.parse('https://example.com/watch'),
    );
    expect(urls, contains('https://cdn.example/media/episode.mp4'));
  });
}
