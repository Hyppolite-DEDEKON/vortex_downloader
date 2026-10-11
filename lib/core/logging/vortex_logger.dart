import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

/// Journalisation centralisée (terminal / `flutter logs`, DevTools Logging).
abstract final class VortexLog {
  static final resolve = Logger('vortex.resolve');
  static final download = Logger('vortex.download');
  static final ytdlp = Logger('vortex.ytdlp');
  static final app = Logger('vortex.app');

  static bool _initialized = false;

  static void init() {
    if (_initialized) return;
    _initialized = true;

    Logger.root.level = kDebugMode ? Level.FINE : Level.INFO;
    Logger.root.onRecord.listen((record) {
      final header = '[${record.level.name}] ${record.loggerName}';
      final text = record.message;
      developer.log(
        text,
        name: header,
        level: _toDeveloperLevel(record.level),
        error: record.error,
        stackTrace: record.stackTrace,
      );

      final buffer = StringBuffer('$header: $text');
      if (record.error != null) {
        buffer.writeln();
        buffer.write('  ${record.error}');
      }
      if (record.stackTrace != null) {
        buffer.writeln();
        buffer.write(record.stackTrace);
      }
      debugPrint(buffer.toString());
    });

    app.info('Journalisation Vortex initialisée (niveau ${Logger.root.level.name})');
  }

  static int _toDeveloperLevel(Level level) {
    if (level >= Level.SEVERE) return 1000;
    if (level >= Level.WARNING) return 900;
    if (level >= Level.INFO) return 800;
    return 500;
  }
}
