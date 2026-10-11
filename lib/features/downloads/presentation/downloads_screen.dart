import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/design/glass_panel.dart';
import '../../../core/widgets/media_thumbnail.dart';
import '../../../core/utils/format_utils.dart';
import '../../../core/utils/url_security.dart';
import '../../../downloads/download_live_metrics.dart';
import '../../../features/downloads/domain/download_status.dart';
import '../../../features/downloads/domain/download_task.dart';
import 'downloads_completed_slivers.dart';

class DownloadsScreen extends ConsumerStatefulWidget {
  const DownloadsScreen({super.key});

  @override
  ConsumerState<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends ConsumerState<DownloadsScreen> {
  final _search = TextEditingController();
  CompletedView _view = CompletedView.list;
  CompletedFilter _filter = CompletedFilter.all;
  CompletedSort _sort = CompletedSort.dateDesc;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _dismissTask(DownloadTask task) async {
    await ref.read(downloadManagerProvider).deleteTask(task, deleteFile: false);
  }

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(downloadTasksProvider);
    final metrics = ref.watch(downloadMetricsProvider);
    final manager = ref.read(downloadManagerProvider);
    final storage = ref.watch(storageServiceProvider);

    return Scaffold(
      body: tasks.when(
        skipLoadingOnReload: true,
        skipError: true,
        data: (list) {
          final active = list.where((t) => t.status.isActive).toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          final failed = list
              .where((t) => t.status == DownloadStatus.failed)
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          final completed = list
              .where((t) => t.status == DownloadStatus.completed)
              .toList();

          final allEmpty =
              active.isEmpty && failed.isEmpty && completed.isEmpty;

          return RefreshIndicator(
            onRefresh: () async {
              ref.read(tasksRefreshProvider.notifier).bump();
              ref.invalidate(downloadTasksProvider);
              await ref.read(downloadTasksProvider.future);
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverSafeArea(
                  bottom: false,
                  sliver: SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                    sliver: SliverToBoxAdapter(
                      child: _DownloadsHeader(
                        activeCount: active.length,
                        completedCount: completed.length,
                        failedCount: failed.length,
                        view: _view,
                        onToggleView: () => setState(() {
                          _view = _view == CompletedView.list
                              ? CompletedView.grid
                              : CompletedView.list;
                        }),
                      ),
                    ),
                  ),
                ),
                if (allEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _EmptyDownloads(onAdd: () => context.go('/')),
                  )
                else ...[
                  if (active.isNotEmpty) ...[
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                      sliver: SliverToBoxAdapter(
                        child: Text(
                          'En cours',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                      sliver: SliverList.separated(
                        itemCount: active.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, i) {
                          final t = active[i];
                          return _ActiveTaskCard(
                            task: t,
                            metrics: metrics[t.id],
                            onPause: t.status == DownloadStatus.downloading
                                ? () => manager.pause(t.id)
                                : null,
                            onResume: t.status == DownloadStatus.paused
                                ? () => manager.resume(t)
                                : null,
                            onCancel: t.status.isActive &&
                                    t.status != DownloadStatus.converting
                                ? () => manager.cancel(t.id)
                                : null,
                          );
                        },
                      ),
                    ),
                  ],
                  if (failed.isNotEmpty) ...[
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 4),
                      sliver: SliverToBoxAdapter(
                        child: Text(
                          'Échecs récents',
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                      sliver: SliverList.separated(
                        itemCount: failed.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, i) {
                          final t = failed[i];
                          return _FailedTaskCard(
                            task: t,
                            onRetry: () => manager.retry(t),
                            onDismiss: () => _dismissTask(t),
                          );
                        },
                      ),
                    ),
                  ],
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 28, 20, 8),
                    sliver: SliverToBoxAdapter(
                      child: Text(
                        'Terminés',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        children: [
                          TextField(
                            controller: _search,
                            onChanged: (_) => setState(() {}),
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.search),
                              hintText: 'Rechercher…',
                              isDense: true,
                            ),
                          ),
                          const SizedBox(height: 8),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: CompletedFilter.values.map((f) {
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: FilterChip(
                                    label: Text(completedFilterLabel(f)),
                                    selected: _filter == f,
                                    onSelected: (_) =>
                                        setState(() => _filter = f),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: DropdownButton<CompletedSort>(
                              value: _sort,
                              onChanged: (v) => setState(() => _sort = v!),
                              items: const [
                                DropdownMenuItem(
                                  value: CompletedSort.dateDesc,
                                  child: Text('Plus récent'),
                                ),
                                DropdownMenuItem(
                                  value: CompletedSort.name,
                                  child: Text('Nom'),
                                ),
                                DropdownMenuItem(
                                  value: CompletedSort.size,
                                  child: Text('Taille'),
                                ),
                              ],
                            ),
                          ),
                          FutureBuilder<int>(
                            future: storage.totalBytes(),
                            builder: (_, snap) => Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Espace utilisé : ${FormatUtils.formatBytes(snap.data)}',
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  ...buildCompletedSlivers(
                    context: context,
                    ref: ref,
                    completed: completed,
                    view: _view,
                    filter: _filter,
                    sort: _sort,
                    searchQuery: _search.text,
                    onFiltersChanged: () => setState(() {}),
                  ),
                ],
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
      ),
    );
  }
}

class _DownloadsHeader extends StatelessWidget {
  const _DownloadsHeader({
    required this.activeCount,
    required this.completedCount,
    required this.failedCount,
    required this.view,
    required this.onToggleView,
  });

  final int activeCount;
  final int completedCount;
  final int failedCount;
  final CompletedView view;
  final VoidCallback onToggleView;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final parts = <String>[];
    if (activeCount > 0) {
      parts.add('$activeCount en cours');
    }
    if (completedCount > 0) {
      parts.add('$completedCount terminé${completedCount > 1 ? 's' : ''}');
    }
    if (failedCount > 0) {
      parts.add('$failedCount échec${failedCount > 1 ? 's' : ''}');
    }
    final subtitle = parts.isEmpty
        ? 'Ajoutez un lien depuis l’accueil.'
        : parts.join(' · ');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Téléchargements',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          icon: Icon(
            view == CompletedView.list ? Icons.grid_view : Icons.list,
          ),
          onPressed: onToggleView,
          tooltip: 'Affichage des fichiers terminés',
        ),
      ],
    );
  }
}

class _EmptyDownloads extends StatelessWidget {
  const _EmptyDownloads({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.download_outlined,
            size: 56,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Aucun téléchargement',
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Les transferts en cours et vos fichiers terminés apparaîtront ici.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_link_rounded),
            label: const Text('Ajouter un lien'),
          ),
        ],
      ),
    );
  }
}

class _ActiveTaskCard extends StatelessWidget {
  const _ActiveTaskCard({
    required this.task,
    required this.metrics,
    this.onPause,
    this.onResume,
    this.onCancel,
  });

  final DownloadTask task;
  final DownloadLiveMetrics? metrics;
  final VoidCallback? onPause;
  final VoidCallback? onResume;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isConverting = task.status == DownloadStatus.converting;
    final progress = !isConverting &&
            task.totalBytes != null &&
            task.totalBytes! > 0
        ? (task.receivedBytes / task.totalBytes!).clamp(0.0, 1.0)
        : null;
    final speed = metrics?.bytesPerSecond ?? 0;
    final eta = metrics?.etaSeconds;
    final indeterminate = task.status.isActive && progress == null;

    return GlassPanel(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MediaThumbnail(
                localPath: task.localPath,
                thumbnailUrl: task.thumbnailUrl,
                mimeType: task.mimeType,
                size: 48,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.fileName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${UrlSecurity.domainFromUrl(task.sourceUrl)} · ${task.outputProfile.shortLabel}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _StatusChip(status: task.status),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: indeterminate
                ? const LinearProgressIndicator(minHeight: 6)
                : LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                  ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  isConverting
                      ? 'Conversion en 420p…'
                      : _progressLine(task, speed: speed, eta: eta),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              if (onPause != null)
                _ActionIcon(
                  icon: Icons.pause_rounded,
                  tooltip: 'Pause',
                  onPressed: onPause!,
                ),
              if (onResume != null)
                _ActionIcon(
                  icon: Icons.play_arrow_rounded,
                  tooltip: 'Reprendre',
                  onPressed: onResume!,
                ),
              if (onCancel != null)
                _ActionIcon(
                  icon: Icons.close_rounded,
                  tooltip: 'Annuler',
                  onPressed: onCancel!,
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _progressLine(
    DownloadTask task, {
    required int speed,
    required int? eta,
  }) {
    final received = FormatUtils.formatBytes(task.receivedBytes);
    final total = task.totalBytes != null
        ? ' / ${FormatUtils.formatBytes(task.totalBytes)}'
        : '';
    final speedStr =
        speed > 0 ? ' · ${FormatUtils.formatSpeed(speed)}' : '';
    final etaStr =
        eta != null && eta > 0 ? ' · ${FormatUtils.formatEta(eta)}' : '';
    final pct = task.totalBytes != null && task.totalBytes! > 0
        ? ' · ${(100 * task.receivedBytes / task.totalBytes!).round()} %'
        : '';
    return '$received$total$pct$speedStr$etaStr';
  }
}

class _FailedTaskCard extends StatelessWidget {
  const _FailedTaskCard({
    required this.task,
    required this.onRetry,
    required this.onDismiss,
  });

  final DownloadTask task;
  final VoidCallback onRetry;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GlassPanel(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MediaThumbnail(
                localPath: task.localPath,
                thumbnailUrl: task.thumbnailUrl,
                mimeType: task.mimeType,
                size: 48,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.fileName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (task.lastError != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        task.lastError!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(onPressed: onDismiss, child: const Text('Retirer')),
              const SizedBox(width: 8),
              FilledButton.tonalIcon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Réessayer'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final DownloadStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (label, color) = switch (status) {
      DownloadStatus.queued => ('File', theme.colorScheme.outline),
      DownloadStatus.analyzing => ('En attente', theme.colorScheme.tertiary),
      DownloadStatus.downloading => ('Actif', theme.colorScheme.primary),
      DownloadStatus.converting => ('Conversion', theme.colorScheme.tertiary),
      DownloadStatus.paused => ('Pause', theme.colorScheme.outline),
      DownloadStatus.completed => ('Terminé', theme.colorScheme.primary),
      DownloadStatus.failed => ('Échec', theme.colorScheme.error),
      DownloadStatus.cancelled => ('Annulé', theme.colorScheme.outline),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  const _ActionIcon({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon, size: 22),
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      style: IconButton.styleFrom(
        foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}
