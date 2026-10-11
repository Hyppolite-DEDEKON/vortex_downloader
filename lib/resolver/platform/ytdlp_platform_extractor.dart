import 'dart:convert';
import 'dart:io';

import '../../core/logging/vortex_logger.dart';
import '../../core/utils/file_name_utils.dart';
import '../analyzed_resource.dart';
import '../resolve_result.dart';
import 'extractor_service.dart';
import 'ytdlp_locator.dart';

class YtdlpPlatformExtractor {
  YtdlpPlatformExtractor(this._locator);

  final YtdlpLocator _locator;

  static const _missingBinaryMessage =
      'Impossible de préparer yt-dlp sur cet appareil. '
      'Vérifiez la connexion internet ou indiquez un chemin yt-dlp dans Paramètres.';

  Future<ResolveResult> resolve(String pageUrl) async {
    if (ExtractorService.isPlatform) {
      return ExtractorService.resolve(pageUrl);
    }

    final bin = await _locator.binary();
    if (bin == null) {
      VortexLog.ytdlp.warning('yt-dlp introuvable pour $pageUrl');
      return const ResolveFailure(_missingBinaryMessage);
    }

    try {
      VortexLog.ytdlp.info('Extraction yt-dlp : $pageUrl');
      VortexLog.ytdlp.fine('Binaire : $bin');
      final result = await Process.run(
        bin,
        [
          '--no-playlist',
          '--no-warnings',
          '--no-check-certificates',
          '-f',
          'b*[acodec!=none][vcodec!=none]/b/bv*+ba/b',
          '--print',
          'title',
          '--print',
          'url',
          '--print',
          'filesize',
          '--print',
          'ext',
          '--print',
          'vcodec',
          '--print',
          'acodec',
          '--print',
          'thumbnail',
          pageUrl,
        ],
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      );

      if (result.exitCode != 0) {
        final err = (result.stderr as String).trim();
        VortexLog.ytdlp.warning('yt-dlp code ${result.exitCode} : $err');
        if (err.isEmpty) {
          return const ResolveFailure('yt-dlp n’a pas pu extraire ce lien.');
        }
        final short = err.length > 280 ? '${err.substring(0, 280)}…' : err;
        return ResolveFailure(short);
      }

      final lines = (result.stdout as String)
          .split(RegExp(r'\r?\n'))
          .where((l) => l.trim().isNotEmpty)
          .toList();

      if (lines.length < 4) {
        return const ResolveFailure('Réponse yt-dlp incomplète.');
      }

      // Un seul format : 6–7 lignes (thumbnail optionnelle). Fusion : on refuse.
      if (lines.length > 7) {
        return const ResolveFailure(
          'Format nécessitant une fusion audio/vidéo non géré. '
          'Réessayez une autre qualité ou mettez à jour yt-dlp.',
        );
      }

      final title = lines[0].trim();
      final mediaUrl = lines[1].trim();
      final sizeRaw = lines[2].trim();
      final ext = lines[3].trim().replaceAll('.', '');
      final vcodec = lines.length > 4 ? lines[4].trim() : '';
      final acodec = lines.length > 5 ? lines[5].trim() : '';
      final thumbnail = lines.length > 6 ? lines[6].trim() : null;

      if (!mediaUrl.startsWith('http')) {
        return const ResolveFailure('URL média invalide renvoyée par yt-dlp.');
      }

      final fileName = FileNameUtils.sanitize(
        title.endsWith('.$ext') ? title : '$title.$ext',
      );
      final totalBytes = int.tryParse(sizeRaw);
      final mime = YtdlpMime.fromCodecs(ext, vcodec: vcodec, acodec: acodec);
      final kind = YtdlpMime.contentKind(vcodec, acodec, mime);

      VortexLog.ytdlp.info('yt-dlp OK → $fileName');
      return ResolveSuccess(
        AnalyzedResource(
          finalUrl: mediaUrl,
          fileName: fileName,
          mimeType: mime,
          totalBytes: totalBytes,
          supportsResume: false,
          resolverName: 'yt-dlp',
          contentKind: kind,
          thumbnailUrl: normalizeThumbnailUrl(thumbnail),
        ),
      );
    } on ProcessException catch (e) {
      return ResolveFailure('yt-dlp : ${e.message}');
    }
  }

  Future<ResolveResult> resolveOrUnsupported(String pageUrl) async {
    if (ExtractorService.isPlatform) {
      if (!await ExtractorService.ensureReady()) {
        return const ResolveUnsupported('yt-dlp absent');
      }
      return resolve(pageUrl);
    }
    final bin = await _locator.binary();
    if (bin == null) return const ResolveUnsupported('yt-dlp absent');
    return resolve(pageUrl);
  }
}
