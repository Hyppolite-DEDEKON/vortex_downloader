import 'package:flutter_test/flutter_test.dart';
import 'package:vortex/core/design/vortex_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('thèmes Vortex instanciables', () {
    expect(VortexTheme.dark(), isNotNull);
    expect(VortexTheme.light(), isNotNull);
  });
}
