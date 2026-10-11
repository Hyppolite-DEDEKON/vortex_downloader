import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../core/errors/app_exception.dart';
import '../core/logging/vortex_logger.dart';
import '../core/utils/link_access_messages.dart';
import '../resolver/platform/extractor_service.dart';
import 'extractor_download_headers.dart';
import '../core/networking/http_client_factory.dart';
import '../core/utils/file_name_utils.dart';
import '../features/downloads/data/download_repository.dart';
import '../features/downloads/domain/download_status.dart';
import '../features/downloads/domain/download_task.dart';
import '../features/downloads/domain/output_profile.dart';
import '../features/settings/settings_repository.dart';
import '../resolver/analyzed_resource.dart';
import '../resolver/platform/tiktok_platform_extractor.dart';
import '../resolver/platform/tiktok_session.dart';
import 'platform_download_headers.dart';
import 'download_live_metrics.dart';
import 'public_media_export.dart';
import 'storage_service.dart';
import 'video_transcoder.dart';

class DownloadManager {
  DownloadManager({
    required DownloadRepository repository,
    required StorageService storage,
    required SettingsRepository settings,
    Dio? dio,
    Connectivity? connectivity,
  })  : _repo = repository,
        _storage = storage,
        _settings = settings,
        _dio = dio ?? createDownloadDio(),
        _connectivity = connectivity ?? Connectivity();

  final DownloadRepository _repo;
  final StorageService _storage;
  final SettingsRepository _settings;
  final Dio _dio;
  final Connectivity _connectivity;
  final _uuid = const Uuid();
  final _tokens = <String, CancelToken>{};
  final _jobs = <String>[];
  final _paused = <String>{};
  int _active = 0;

  void Function(DownloadTask task)? onTaskUpdated;
  void Function(String id)? onTaskDeleted;
  void Function(String id, DownloadLiveMetrics m)? onMetricsUpdated;

  Future<void> restoreInterrupted() async {
    VortexLog.download.info('Restauration des téléchargements interrompus');
    for (final t in await _repo.all()) {
      if (t.status == DownloadStatus.downloading ||
          t.status == DownloadStatus.converting) {
        final u = t.copyWith(
          status: DownloadStatus.paused,
          lastError: 'Interrompu — appuyez sur Reprendre.',
        );
        await _repo.upsert(u);
        onTaskUpdated?.call(u);
      } else if (t.status == DownloadStatus.queued) {
        if (!_jobs.contains(t.id)) _jobs.add(t.id);
      }
    }
    _pump();
    VortexLog.download.fine('File d’attente : ${_jobs.length} tâche(s)');
  }

  Future<DownloadTask> createTask({
    required String sourceUrl,
    required AnalyzedResource resource,
    OutputProfile outputProfile = OutputProfile.hd,
  }) async {
    final task = DownloadTask(
      id: _uuid.v4(),
      sourceUrl: sourceUrl,
      downloadUrl: resource.finalUrl,
      fileName: fileNameForProfile(resource.fileName, outputProfile),
      mimeType: resource.mimeType,
      totalBytes: resource.totalBytes,
      status: DownloadStatus.queued,
      createdAt: DateTime.now(),
      supportsResume: resource.supportsResume,
      downloadHeaders: resource.downloadHeaders,
      thumbnailUrl: resource.thumbnailUrl,
      outputProfile: outputProfile,
    );
    await _repo.upsert(task);
    onTaskUpdated?.call(task);
    VortexLog.download.info('Tâche créée ${task.id} → ${task.fileName}');
    return task;
  }

  Future<void> enqueue(DownloadTask task) async {
    if (!_jobs.contains(task.id)) _jobs.add(task.id);
    VortexLog.download.fine('Enqueue ${task.id}');
    _pump();
  }

  Future<void> pause(String id) async {
    _paused.add(id);
    _tokens[id]?.cancel('pause');
    await ExtractorService.cancelDownload(id);
    final t = await _repo.findById(id);
    if (t == null) return;
    final u = t.copyWith(status: DownloadStatus.paused);
    await _repo.upsert(u);
    onTaskUpdated?.call(u);
  }

  Future<void> resume(DownloadTask task) async {
    _paused.remove(task.id);
    final u = task.copyWith(status: DownloadStatus.queued, clearLastError: true);
    await _repo.upsert(u);
    onTaskUpdated?.call(u);
    await enqueue(u);
  }

  Future<void> cancel(String id) async {
    _jobs.remove(id);
    _paused.remove(id);
    _tokens[id]?.cancel('cancel');
    await ExtractorService.cancelDownload(id);
    final t = await _repo.findById(id);
    if (t == null) return;
    final u = t.copyWith(
      status: DownloadStatus.cancelled,
      finishedAt: DateTime.now(),
      lastError: 'Annulé.',
    );
    await _repo.upsert(u);
    onTaskUpdated?.call(u);
  }

  Future<void> retry(
    DownloadTask task, {
    Future<AnalyzedResource?> Function(String sourceUrl)? refreshFromSource,
  }) async {
    _paused.remove(task.id);
    var next = task;
    final shouldRefresh = refreshFromSource != null &&
        ((task.downloadUrl != null && task.downloadUrl != task.sourceUrl) ||
            LinkAccessMessages.shouldReanalyzeForRetry(task.lastError));
    if (shouldRefresh && refreshFromSource != null) {
      final resource = await refreshFromSource(task.sourceUrl);
      if (resource == null) {
        final failed = task.copyWith(
          status: DownloadStatus.failed,
          lastError: LinkAccessMessages.reanalyzeFailed,
        );
        await _repo.upsert(failed);
        onTaskUpdated?.call(failed);
        return;
      }
      next = task.copyWith(
        downloadUrl: resource.finalUrl,
        downloadHeaders: resource.downloadHeaders,
        totalBytes: resource.totalBytes,
        supportsResume: resource.supportsResume,
        mimeType: resource.mimeType,
        thumbnailUrl: resource.thumbnailUrl,
      );
    }
    final u = next.copyWith(
      status: DownloadStatus.queued,
      clearLastError: true,
      clearFinishedAt: true,
    );
    await _repo.upsert(u);
    onTaskUpdated?.call(u);
    await enqueue(u);
  }

  void _pump() {
    while (_active < _settings.load().maxConcurrent && _jobs.isNotEmpty) {
      final id = _jobs.removeAt(0);
      _active++;
      unawaited(_run(id).whenComplete(() {
        _active--;
        _pump();
      }));
    }
  }

  Future<void> _run(String id) async {
    final initial = await _repo.findById(id);
    if (initial == null ||
        initial.status == DownloadStatus.cancelled ||
        _paused.contains(id)) {
      return;
    }
    if (initial.status == DownloadStatus.paused) {
      VortexLog.download.fine('Run ignoré (pause) $id');
      return;
    }
    try {
      VortexLog.download.info('Démarrage ${initial.fileName} ($id)');
      await _checkWifi();
      final dir = await _storage.downloadsDirectory();
      final ext = p.extension(FileNameUtils.forStorage(initial.fileName));
      final name = FileNameUtils.diskNameForTask(
        initial.id,
        reduced420p: initial.outputProfile == OutputProfile.reduced420p,
        ext: ext.isEmpty ? '.mp4' : ext,
      );
      final target = p.join(dir.path, name);
      VortexLog.download.fine('Fichier disque : $name (← ${initial.fileName})');
      final temp = '$target.part';

      var received = 0;
      if (initial.supportsResume && File(temp).existsSync()) {
        received = await File(temp).length();
      } else if (File(temp).existsSync()) {
        await File(temp).delete();
      }

      var task = initial.copyWith(
        status: DownloadStatus.downloading,
        localPath: target,
        receivedBytes: received,
        clearLastError: true,
      );
      await _repo.upsert(task);
      onTaskUpdated?.call(task);

      final token = CancelToken();
      _tokens[id] = token;
      int? total;

      if (_isTiktokTask(task)) {
        VortexLog.download.fine('Téléchargement TikTok (session fraîche)');
        var lastT = DateTime.now();
        var lastB = received;
        if (received > 0 && File(temp).existsSync()) {
          await File(temp).delete();
          received = 0;
        }
        await TiktokSession.downloadToFile(
          sourceUrl: task.sourceUrl,
          tempPath: temp,
          cancelToken: token,
          mediaUrl: task.downloadUrl,
          headers: task.downloadHeaders,
          onProgress: (r, progressTotal) {
            if (_paused.contains(id)) {
              token.cancel('pause');
              return;
            }
            received = r;
            total = progressTotal;
            final now = DateTime.now();
            final dt = now.difference(lastT).inMilliseconds;
            task = task.copyWith(receivedBytes: received, totalBytes: total);
            onTaskUpdated?.call(task);
            if (dt >= 500) {
              final speed = ((received - lastB) * 1000 / dt).round();
              int? eta;
              if (total != null && speed > 0) {
                final bytesTotal = total!;
                eta = ((bytesTotal - received) / speed).ceil();
              }
              onMetricsUpdated?.call(
                id,
                DownloadLiveMetrics(bytesPerSecond: speed, etaSeconds: eta),
              );
              unawaited(_repo.upsert(task));
              lastT = now;
              lastB = received;
            }
          },
        );
        if (await File(temp).exists()) {
          received = await File(temp).length();
          total = received;
        }
      } else if (ExtractorDownloadHeaders.isMergedDownload(task.downloadHeaders) &&
          ExtractorService.isPlatform) {
        if (File(temp).existsSync()) await File(temp).delete();
        token.whenCancel.then((_) => ExtractorService.cancelDownload(id));
        await ExtractorService.downloadMergedToFile(
          pageUrl: task.sourceUrl,
          targetPath: temp,
          processId: id,
          formatSelector:
              ExtractorDownloadHeaders.formatSelector(task.downloadHeaders),
        );
        received = await File(temp).length();
        total = received;
      } else {
        final raf = await File(temp).open(
          mode: received > 0 ? FileMode.append : FileMode.write,
        );

        final headers = <String, dynamic>{};
        final extra = task.downloadHeaders ??
            PlatformDownloadHeaders.forSource(
              sourceUrl: task.sourceUrl,
              downloadUrl: task.effectiveDownloadUrl,
            );
        if (extra != null) headers.addAll(extra);
        if (received > 0 && task.supportsResume) {
          headers['Range'] = 'bytes=$received-';
        }

        final res = await _dio.get<ResponseBody>(
          task.effectiveDownloadUrl,
          options: Options(
            responseType: ResponseType.stream,
            headers: headers,
          ),
          cancelToken: token,
        );

        total = task.totalBytes;
        final cl = res.headers.value('content-length');
        if (cl != null) {
          final parsed = int.tryParse(cl);
          if (parsed != null) {
            total = received > 0 ? received + parsed : parsed;
          }
        }

        var lastT = DateTime.now();
        var lastB = received;

        await for (final chunk in res.data!.stream) {
          if (_paused.contains(id)) break;
          await raf.writeFrom(chunk);
          received += chunk.length;
          final now = DateTime.now();
          final dt = now.difference(lastT).inMilliseconds;
          task = task.copyWith(receivedBytes: received, totalBytes: total);
          onTaskUpdated?.call(task);
          if (dt >= 500) {
            final speed = ((received - lastB) * 1000 / dt).round();
            int? eta;
            if (total != null && speed > 0) {
              final bytesTotal = total;
              eta = ((bytesTotal - received) / speed).ceil();
            }
            onMetricsUpdated?.call(id, DownloadLiveMetrics(
              bytesPerSecond: speed,
              etaSeconds: eta,
            ));
            await _repo.upsert(task);
            lastT = now;
            lastB = received;
          }
        }
        await raf.close();
      }

      if (_paused.contains(id)) return;

      if (File(target).existsSync()) await File(target).delete();
      await File(temp).rename(target);

      task = await _maybeTranscode(task, target);
      final finalSize = await File(target).length();

      final done = task.copyWith(
        status: DownloadStatus.completed,
        receivedBytes: finalSize,
        totalBytes: finalSize,
        finishedAt: DateTime.now(),
        mimeType: task.outputProfile == OutputProfile.reduced420p &&
                VideoTranscoder.isVideoMime(task.mimeType)
            ? 'video/mp4'
            : task.mimeType,
      );
      await _repo.upsert(done);
      onTaskUpdated?.call(done);
      onMetricsUpdated?.call(id, const DownloadLiveMetrics());
      VortexLog.download.info('Terminé $id → $target');
      await _exportToPublicStorage(done, target);
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        if (_paused.contains(id)) {
          VortexLog.download.fine('Téléchargement $id annulé (pause)');
        }
        return;
      }
      VortexLog.download.warning('Réseau $id : ${e.message}', e);
      await _fail(id, LinkAccessMessages.userMessageForDio(e));
    } on AppException catch (e) {
      VortexLog.download.warning('Échec $id : ${e.message}');
      await _fail(id, e.message);
    } catch (e, st) {
      VortexLog.download.severe('Erreur inattendue $id', e, st);
      await _fail(id, e.toString());
    } finally {
      _tokens.remove(id);
    }
  }

  Future<DownloadTask> _maybeTranscode(DownloadTask task, String targetPath) async {
    if (task.outputProfile != OutputProfile.reduced420p ||
        !VideoTranscoder.isVideoMime(task.mimeType)) {
      return task;
    }
    final resolvedPath = _resolveDownloadedPath(task, targetPath);
    final ext = p.extension(resolvedPath).toLowerCase();
    if (ext == '.jpg' ||
        ext == '.jpeg' ||
        ext == '.png' ||
        ext == '.webp' ||
        ext == '.gif') {
      return task;
    }
    if (!await VideoTranscoder.looksLikeVideoFile(resolvedPath)) {
      throw DownloadException(
        'Qualité 420p impossible : le fichier téléchargé n’est pas une vidéo valide.',
      );
    }
    var converting = task.copyWith(status: DownloadStatus.converting);
    await _repo.upsert(converting);
    onTaskUpdated?.call(converting);
    final tempOut = VideoTranscoder.outputPathFor420p(resolvedPath);
    try {
      await VideoTranscoder.transcodeTo420p(
        inputPath: resolvedPath,
        outputPath: tempOut,
      );
    } catch (e) {
      if (await File(tempOut).exists()) await File(tempOut).delete();
      throw DownloadException('Conversion 420p : $e');
    }
    await File(resolvedPath).delete();
    await File(tempOut).rename(resolvedPath);
    return converting;
  }

  String _resolveDownloadedPath(DownloadTask task, String targetPath) {
    final local = task.localPath?.trim();
    if (local != null && local.isNotEmpty && File(local).existsSync()) {
      return local;
    }
    if (File(targetPath).existsSync()) return targetPath;
    final dir = p.dirname(targetPath);
    final byName = p.join(dir, task.fileName);
    if (File(byName).existsSync()) return byName;
    return targetPath;
  }

  Future<void> _exportToPublicStorage(DownloadTask task, String path) async {
    if (!_settings.load().saveToPublicStorage) return;
    try {
      await PublicMediaExport.export(
        localPath: path,
        displayFileName: task.fileName,
        mimeType: task.mimeType,
      );
    } catch (e, st) {
      VortexLog.download.warning(
        'Export galerie / Téléchargements échoué (${task.fileName})',
        e,
        st,
      );
    }
  }

  Future<void> _fail(String id, String msg) async {
    final t = await _repo.findById(id);
    if (t == null) return;
    final u = t.copyWith(
      status: DownloadStatus.failed,
      finishedAt: DateTime.now(),
      lastError: msg,
    );
    await _repo.upsert(u);
    onTaskUpdated?.call(u);
    VortexLog.download.warning('Tâche $id en échec : $msg');
  }

  static bool _isTiktokTask(DownloadTask task) {
    final host = Uri.tryParse(task.sourceUrl)?.host;
    return host != null && TiktokPlatformExtractor.matchesHost(host);
  }

  Future<void> _checkWifi() async {
    if (!_settings.load().wifiOnly) return;
    final r = await _connectivity.checkConnectivity();
    if (!r.contains(ConnectivityResult.wifi) &&
        !r.contains(ConnectivityResult.ethernet)) {
      throw const NetworkException('Wi‑Fi uniquement activé.');
    }
  }

  Future<void> deleteTask(DownloadTask task, {required bool deleteFile}) async {
    _jobs.remove(task.id);
    _paused.remove(task.id);
    _tokens[task.id]?.cancel('delete');
    _tokens.remove(task.id);
    if (task.status == DownloadStatus.downloading ||
        task.status == DownloadStatus.converting) {
      await pause(task.id);
    }
    if (deleteFile && task.localPath != null) {
      final f = File(task.localPath!);
      if (await f.exists()) await f.delete();
      final part = File('${task.localPath!}.part');
      if (await part.exists()) await part.delete();
    }
    await _repo.deleteById(task.id);
    onTaskDeleted?.call(task.id);
    VortexLog.download.fine('Tâche retirée ${task.id}');
  }
}
