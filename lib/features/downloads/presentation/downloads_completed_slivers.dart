import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/design/glass_panel.dart';
import '../../../core/utils/format_utils.dart';
import '../../../core/widgets/media_thumbnail.dart';
import '../domain/download_task.dart';
import '../domain/output_profile.dart';

enum CompletedView { list, grid }

enum CompletedFilter { all, video, audio, image, document, other }

enum CompletedSort { dateDesc, name, size }

List<Widget> buildCompletedSlivers({
  required BuildContext context,
  required WidgetRef ref,
  required List<DownloadTask> completed,
  required CompletedView view,
  required CompletedFilter filter,
  required CompletedSort sort,
  required String searchQuery,
  required VoidCallback onFiltersChanged,
}) {
  final opener = ref.read(mediaOpenerProvider);
  final manager = ref.read(downloadManagerProvider);
  final q = searchQuery.trim().toLowerCase();

  var list = completed.where((t) {
    if (q.isNotEmpty && !t.fileName.toLowerCase().contains(q)) return false;
    return _matchesFilter(t, filter);
  }).toList();

  list.sort((a, b) => switch (sort) {
        CompletedSort.dateDesc => (b.finishedAt ?? b.createdAt)
            .compareTo(a.finishedAt ?? a.createdAt),
        CompletedSort.name => a.fileName.compareTo(b.fileName),
        CompletedSort.size => (b.totalBytes ?? 0).compareTo(a.totalBytes ?? 0),
      });

  if (completed.isEmpty) {
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        sliver: SliverToBoxAdapter(
          child: Text(
            'Aucun fichier terminé.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
      ),
    ];
  }

  if (list.isEmpty) {
    return [
      const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: Text('Aucun résultat.')),
        ),
      ),
    ];
  }

  if (view == CompletedView.list) {
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
        sliver: SliverList.separated(
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) => _CompletedFileTile(
            task: list[i],
            onOpen: () => opener.open(list[i].localPath!),
            onShare: () => opener.share(
              list[i].localPath!,
              subject: list[i].fileName,
            ),
            onDelete: () => _confirmDelete(context, ref, list[i], manager),
          ),
        ),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 100)),
    ];
  }

  return [
    SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.05,
        ),
        delegate: SliverChildBuilderDelegate(
          (_, i) {
            final t = list[i];
            return GlassPanel(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: MediaThumbnail(
                      localPath: t.localPath,
                      thumbnailUrl: t.thumbnailUrl,
                      mimeType: t.mimeType,
                      size: double.nan,
                      borderRadius: 8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    t.fileName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  Text(
                    FormatUtils.formatBytes(t.totalBytes),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            );
          },
          childCount: list.length,
        ),
      ),
    ),
  ];
}

Future<void> _confirmDelete(
  BuildContext context,
  WidgetRef ref,
  DownloadTask t,
  dynamic manager,
) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Supprimer le fichier ?'),
      content: Text('« ${t.fileName} » sera supprimé définitivement.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Supprimer'),
        ),
      ],
    ),
  );
  if (ok == true) {
    await ref.read(downloadManagerProvider).deleteTask(t, deleteFile: true);
  }
}

bool _matchesFilter(DownloadTask t, CompletedFilter f) {
  if (f == CompletedFilter.all) return true;
  final mime = t.mimeType ?? '';
  return switch (f) {
    CompletedFilter.video => mime.startsWith('video/'),
    CompletedFilter.audio => mime.startsWith('audio/'),
    CompletedFilter.image => mime.startsWith('image/'),
    CompletedFilter.document =>
      mime.contains('pdf') || mime.startsWith('text/'),
    CompletedFilter.other =>
      !mime.startsWith('video/') &&
          !mime.startsWith('audio/') &&
          !mime.startsWith('image/') &&
          !mime.contains('pdf') &&
          !mime.startsWith('text/'),
    CompletedFilter.all => true,
  };
}

String completedFilterLabel(CompletedFilter f) => switch (f) {
      CompletedFilter.all => 'Tous',
      CompletedFilter.video => 'Vidéo',
      CompletedFilter.audio => 'Audio',
      CompletedFilter.image => 'Image',
      CompletedFilter.document => 'Document',
      CompletedFilter.other => 'Autre',
    };

class _CompletedFileTile extends StatelessWidget {
  const _CompletedFileTile({
    required this.task,
    required this.onOpen,
    required this.onShare,
    required this.onDelete,
  });

  final DownloadTask task;
  final VoidCallback onOpen;
  final VoidCallback onShare;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final profile = task.outputProfile == OutputProfile.reduced420p
        ? ' · ${task.outputProfile.shortLabel}'
        : '';
    return GlassPanel(
      child: Row(
        children: [
          MediaThumbnail(
            localPath: task.localPath,
            thumbnailUrl: task.thumbnailUrl,
            mimeType: task.mimeType,
            size: 52,
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
                ),
                Text(
                  '${FormatUtils.formatBytes(task.totalBytes)}$profile • '
                  '${task.finishedAt != null ? FormatUtils.formatDate(task.finishedAt!) : ''}',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          ),
          IconButton(onPressed: onOpen, icon: const Icon(Icons.open_in_new)),
          IconButton(onPressed: onShare, icon: const Icon(Icons.share_outlined)),
          IconButton(onPressed: onDelete, icon: const Icon(Icons.delete_outline)),
        ],
      ),
    );
  }
}
