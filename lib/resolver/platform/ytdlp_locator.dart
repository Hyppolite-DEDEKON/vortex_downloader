import 'dart:io';

import '../../core/logging/vortex_logger.dart';
import 'extractor_service.dart';
import 'ytdlp_bootstrap.dart';

class YtdlpLocator {
  YtdlpLocator([this._customPath]);

  final String? _customPath;
  String? _cached;

  void invalidate() => _cached = null;

  Future<String?> binary() async {
    if (_cached != null) return _cached;

    if (ExtractorService.isPlatform) {
      if (await ExtractorService.ensureReady()) {
        _cached = ExtractorService.bundledMarker;
        VortexLog.ytdlp.fine('yt-dlp (extractor Android)');
        return _cached;
      }
      return null;
    }

    final custom = _customPath?.trim();
    if (custom != null && custom.isNotEmpty) {
      final file = File(custom);
      if (await file.exists()) {
        _cached = custom;
        VortexLog.ytdlp.fine('yt-dlp (paramètre) : $custom');
        return _cached;
      }
      VortexLog.ytdlp.warning('Chemin yt-dlp invalide : $custom');
    }

    for (final name in const ['yt-dlp', 'youtube-dl']) {
      final found = await _which(name);
      if (found != null) {
        _cached = found;
        VortexLog.ytdlp.fine('yt-dlp (PATH) : $found');
        return _cached;
      }
    }

    VortexLog.ytdlp.fine('Recherche / installation yt-dlp embarqué…');
    final bundled = await YtdlpBootstrap.ensureBinary();
    if (bundled != null) {
      _cached = bundled;
      return _cached;
    }
    return null;
  }

  Future<String?> _which(String name) async {
    try {
      if (Platform.isWindows) {
        final r = await Process.run('where', [name]);
        if (r.exitCode == 0) {
          final line = (r.stdout as String).trim().split(RegExp(r'\r?\n')).first;
          if (line.isNotEmpty) return line;
        }
        return null;
      }
      final r = await Process.run('which', [name]);
      if (r.exitCode == 0) {
        final line = (r.stdout as String).trim();
        if (line.isNotEmpty) return line;
      }
    } catch (_) {}
    return null;
  }
}
