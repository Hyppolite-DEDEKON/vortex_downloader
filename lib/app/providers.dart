import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../downloads/download_live_metrics.dart';
import '../downloads/download_manager.dart';
import '../downloads/media_opener.dart';
import '../downloads/storage_service.dart';
import '../features/downloads/data/download_database.dart';
import '../features/downloads/data/download_repository.dart';
import '../features/downloads/domain/download_status.dart';
import '../features/downloads/domain/download_task.dart';
import '../features/settings/app_settings.dart';
import '../features/settings/settings_repository.dart';
import '../resolver/link_analyzer.dart';
import '../resolver/source_resolver.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError();
});

final downloadDatabaseProvider = Provider<DownloadDatabase>((ref) {
  throw UnimplementedError();
});

final downloadRepositoryProvider = Provider(
  (ref) => DownloadRepository(ref.watch(downloadDatabaseProvider)),
);

final settingsRepositoryProvider = Provider(
  (ref) => SettingsRepository(ref.watch(sharedPreferencesProvider)),
);

final storageServiceProvider = Provider((ref) => StorageService());

final linkAnalyzerProvider = Provider(
  (ref) {
    final path = ref.watch(settingsProvider).ytdlpPath;
    return LinkAnalyzer(SourceResolverChain(ytdlpPath: path));
  },
);

final downloadMetricsProvider =
    NotifierProvider<DownloadMetricsNotifier, Map<String, DownloadLiveMetrics>>(
  DownloadMetricsNotifier.new,
);

class DownloadMetricsNotifier extends Notifier<Map<String, DownloadLiveMetrics>> {
  @override
  Map<String, DownloadLiveMetrics> build() => {};

  void set(String id, DownloadLiveMetrics m) {
    state = {...state, id: m};
  }

  void remove(String id) {
    if (!state.containsKey(id)) return;
    final next = Map<String, DownloadLiveMetrics>.from(state);
    next.remove(id);
    state = next;
  }
}

final downloadManagerProvider = Provider((ref) {
  ref.keepAlive();
  final manager = DownloadManager(
    repository: ref.watch(downloadRepositoryProvider),
    storage: ref.watch(storageServiceProvider),
    settings: ref.watch(settingsRepositoryProvider),
  );
  manager.onTaskUpdated = (task) {
    ref.read(downloadTasksProvider.notifier).upsertTask(task);
  };
  manager.onTaskDeleted = (id) {
    ref.read(downloadTasksProvider.notifier).removeTask(id);
    ref.read(downloadMetricsProvider.notifier).remove(id);
  };
  manager.onMetricsUpdated = (id, m) {
    ref.read(downloadMetricsProvider.notifier).set(id, m);
  };
  ref.onDispose(() {
    manager.onTaskUpdated = null;
    manager.onTaskDeleted = null;
    manager.onMetricsUpdated = null;
  });
  return manager;
});

class TasksRefreshNotifier extends Notifier<int> {
  @override
  int build() => 0;
  void bump() => state++;
}

final tasksRefreshProvider =
    NotifierProvider<TasksRefreshNotifier, int>(TasksRefreshNotifier.new);

class DownloadTasksNotifier extends AsyncNotifier<List<DownloadTask>> {
  /// Évite qu’un [onTaskUpdated] tardif réaffiche une tâche retirée.
  final Set<String> _removedIds = {};

  @override
  Future<List<DownloadTask>> build() async {
    ref.watch(tasksRefreshProvider);
    final all = await ref.read(downloadRepositoryProvider).all();
    final liveIds = all.map((t) => t.id).toSet();
    _removedIds.removeWhere(liveIds.contains);
    return all;
  }

  void upsertTask(DownloadTask task) {
    if (_removedIds.contains(task.id)) return;
    final value = state.value;
    if (value == null) return;
    final index = value.indexWhere((t) => t.id == task.id);
    if (index >= 0) {
      final next = List<DownloadTask>.from(value);
      next[index] = task;
      state = AsyncData(next);
    } else {
      state = AsyncData([task, ...value]);
    }
  }

  void removeTask(String id) {
    _removedIds.add(id);
    final value = state.value;
    if (value == null) {
      unawaited(_reloadFromDatabase());
      return;
    }
    final next = value.where((t) => t.id != id).toList();
    if (next.length == value.length) {
      unawaited(_reloadFromDatabase());
      return;
    }
    state = AsyncData(next);
  }

  Future<void> _reloadFromDatabase() async {
    final all = await ref.read(downloadRepositoryProvider).all();
    final liveIds = all.map((t) => t.id).toSet();
    _removedIds.removeWhere(liveIds.contains);
    state = AsyncData(all);
  }
}

final downloadTasksProvider =
    AsyncNotifierProvider<DownloadTasksNotifier, List<DownloadTask>>(
  DownloadTasksNotifier.new,
);

/// Alias historique — préférer [downloadTasksProvider].
final allTasksProvider = downloadTasksProvider;

final completedTasksProvider = Provider<AsyncValue<List<DownloadTask>>>((ref) {
  final all = ref.watch(downloadTasksProvider);
  return all.when(
    data: (list) => AsyncData(
      list.where((t) => t.status == DownloadStatus.completed).toList(),
    ),
    loading: () => const AsyncLoading(),
    error: (e, st) => AsyncError(e, st),
  );
});

final activeDownloadCountProvider = Provider<int>((ref) {
  final async = ref.watch(downloadTasksProvider);
  return async.maybeWhen(
    data: (list) => list.where((t) => t.status.isActive).length,
    orElse: () => 0,
  );
});

class SettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() => ref.watch(settingsRepositoryProvider).load();

  Future<void> update(AppSettings s) async {
    await ref.read(settingsRepositoryProvider).save(s);
    state = s;
  }
}

final settingsProvider =
    NotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);

final themeModeProvider = Provider<ThemeMode>((ref) {
  return switch (ref.watch(settingsProvider).themeMode) {
    AppThemeMode.system => ThemeMode.system,
    AppThemeMode.light => ThemeMode.light,
    AppThemeMode.dark => ThemeMode.dark,
  };
});

final mediaOpenerProvider = Provider((ref) => MediaOpener());
