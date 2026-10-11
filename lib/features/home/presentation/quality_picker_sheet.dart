import 'package:flutter/material.dart';

import '../../../core/utils/format_utils.dart';
import '../../../core/widgets/media_thumbnail.dart';
import '../../../features/downloads/domain/download_selection.dart';
import '../../../features/downloads/domain/output_profile.dart';
import '../../../downloads/extractor_download_headers.dart';
import '../../../resolver/analyzed_resource.dart';
import '../../../resolver/media_variant.dart';

class _PickerOption {
  _PickerOption({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.bytesLabel,
    required this.selection,
  });

  final String id;
  final String title;
  final String subtitle;
  final String bytesLabel;
  final DownloadSelection selection;
}

class _OptionSection {
  const _OptionSection({required this.title, required this.options});

  final String title;
  final List<_PickerOption> options;
}

/// Modal : choix du format source avant téléchargement.
Future<QualityPickerResult?> showQualityPickerSheet({
  required BuildContext context,
  required String title,
  required List<MediaVariant> variants,
  AnalyzedResource? defaultResource,
}) async {
  if (variants.isEmpty && defaultResource == null) return null;

  final options = _buildOptions(variants, defaultResource);
  if (options.isEmpty) return null;

  final sections = _groupOptionSections(options);
  final initialId = _initialOptionId(options, defaultResource);
  final multiSelect = _isImageCarousel(options);

  return showModalBottomSheet<QualityPickerResult>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (ctx) {
      var focusId = initialId;
      var checkedIds = multiSelect ? {initialId} : <String>{initialId};
      final maxSheetHeight = MediaQuery.sizeOf(ctx).height * 0.88;

      return StatefulBuilder(
        builder: (ctx, setState) {
          final theme = Theme.of(ctx);
          final focusOption = options.firstWhere(
            (o) => o.id == focusId,
            orElse: () => options.first,
          );
          final showPreview = options.any((o) => _showsPreview(o.selection.resource));
          final checkedCount =
              multiSelect ? checkedIds.length : (checkedIds.contains(focusId) ? 1 : 0);

          return ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxSheetHeight),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: CustomScrollView(
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                        sliver: SliverList(
                          delegate: SliverChildListDelegate([
                            Text(
                              'Avant de télécharger',
                              style: theme.textTheme.titleLarge,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _helperLine(options, multiSelect),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            if (multiSelect) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  TextButton(
                                    onPressed: () => setState(
                                      () => checkedIds =
                                          options.map((o) => o.id).toSet(),
                                    ),
                                    child: const Text('Tout sélectionner'),
                                  ),
                                  TextButton(
                                    onPressed: () => setState(() => checkedIds = {}),
                                    child: const Text('Aucune'),
                                  ),
                                ],
                              ),
                            ],
                            if (showPreview) ...[
                              const SizedBox(height: 12),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: AspectRatio(
                                  aspectRatio: 4 / 5,
                                  child: _VariantPreview(
                                    resource: focusOption.selection.resource,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 14),
                          ]),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final block = _sectionBlockAt(sections, index);
                              if (block.isHeader) {
                                return Padding(
                                  padding: EdgeInsets.only(
                                    top: block.sectionIndex == 0 ? 0 : 16,
                                    bottom: 8,
                                  ),
                                  child: Text(
                                    block.title!,
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                );
                              }
                              final o = block.option!;
                              final isFocused = focusId == o.id;
                              final isChecked = multiSelect
                                  ? checkedIds.contains(o.id)
                                  : isFocused;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: _PickerOptionTile(
                                  option: o,
                                  theme: theme,
                                  multiSelect: multiSelect,
                                  isFocused: isFocused,
                                  isChecked: isChecked,
                                  onTap: () => setState(() {
                                    focusId = o.id;
                                    if (multiSelect) {
                                      if (checkedIds.contains(o.id)) {
                                        checkedIds = Set.of(checkedIds)
                                          ..remove(o.id);
                                      } else {
                                        checkedIds = Set.of(checkedIds)
                                          ..add(o.id);
                                      }
                                    } else {
                                      checkedIds = {o.id};
                                    }
                                  }),
                                ),
                              );
                            },
                            childCount: _sectionBlockCount(sections),
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(
                          16,
                          10,
                          16,
                          8 + MediaQuery.paddingOf(ctx).bottom,
                        ),
                        sliver: SliverToBoxAdapter(
                          child: Text(
                            multiSelect
                                ? _selectionSummary(checkedCount)
                                : 'Sélection : ${focusOption.title}',
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    0,
                    16,
                    16 + MediaQuery.paddingOf(ctx).bottom,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Annuler'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: FilledButton(
                          onPressed: checkedCount == 0
                              ? null
                              : () {
                                  final picks = options
                                      .where(
                                        (o) => multiSelect
                                            ? checkedIds.contains(o.id)
                                            : o.id == focusId,
                                      )
                                      .map((o) => o.selection)
                                      .toList();
                                  Navigator.pop(
                                    ctx,
                                    QualityPickerResult(picks),
                                  );
                                },
                          child: Text(
                            multiSelect
                                ? 'Télécharger ($checkedCount)'
                                : 'Télécharger',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

bool _isImageCarousel(List<_PickerOption> options) {
  if (options.length < 2) return false;
  return options.every(
    (o) =>
        o.selection.resource.contentKind == ContentKind.image &&
        o.selection.outputProfile == OutputProfile.hd,
  );
}

List<_PickerOption> _buildOptions(
  List<MediaVariant> variants,
  AnalyzedResource? defaultResource,
) {
  final source = variants.isNotEmpty
      ? variants
      : [
          if (defaultResource != null)
            MediaVariant.fromResource(defaultResource),
        ];
  final sorted = [...source];
  sorted.sort((a, b) {
    final sa = a.resource.totalBytes;
    final sb = b.resource.totalBytes;
    if (sa == null && sb == null) return a.sortKey.compareTo(b.sortKey);
    if (sa == null) return 1;
    if (sb == null) return -1;
    return sa.compareTo(sb);
  });

  final out = <_PickerOption>[];
  for (final v in sorted) {
    final audioOnly = v.resource.contentKind == ContentKind.audio ||
        v.label.toLowerCase().contains('audio seul');
    final mergedHd = ExtractorDownloadHeaders.isMergedDownload(
      v.resource.downloadHeaders,
    );
    out.add(
      _PickerOption(
        id: v.id,
        title: v.label,
        subtitle: audioOnly
            ? 'Fichier audio uniquement'
            : mergedHd
                ? 'Vidéo + son (fusion HD)'
                : OutputProfile.hd.displayLabel,
        bytesLabel: _sizeLabel(v.resource.totalBytes),
        selection: DownloadSelection(
          resource: v.resource,
          outputProfile: OutputProfile.hd,
        ),
      ),
    );
  }
  return out;
}

String _sizeLabel(int? bytes) {
  if (bytes == null) return 'Taille inconnue';
  return FormatUtils.formatBytes(bytes);
}

bool _showsPreview(AnalyzedResource resource) {
  if (resource.contentKind == ContentKind.image) return true;
  final thumb = normalizeThumbnailUrl(resource.thumbnailUrl);
  return thumb != null;
}

String _selectionSummary(int count) {
  if (count <= 0) return 'Aucune photo sélectionnée';
  if (count == 1) return '1 photo sélectionnée';
  return '$count photos sélectionnées';
}

String _helperLine(List<_PickerOption> options, bool multiSelect) {
  if (multiSelect) {
    return 'Cochez les photos à enregistrer (qualité d’origine).';
  }
  final onlyImages = options.every(
    (o) => o.selection.resource.contentKind == ContentKind.image,
  );
  if (onlyImages) {
    return 'Qualité d’origine.';
  }
  if (_groupOptionSections(options).length > 1) {
    return 'Choisissez une vidéo avec son ou une piste audio seule.';
  }
  return 'Choisissez la qualité proposée par la source.';
}

bool _isAudioOnlyOption(_PickerOption option) {
  final kind = option.selection.resource.contentKind;
  if (kind == ContentKind.audio) return true;
  return option.title.toLowerCase().contains('audio seul');
}

List<_OptionSection> _groupOptionSections(List<_PickerOption> options) {
  if (_isImageCarousel(options)) {
    return [_OptionSection(title: 'Photos', options: options)];
  }

  final video = <_PickerOption>[];
  final audio = <_PickerOption>[];
  for (final o in options) {
    if (_isAudioOnlyOption(o)) {
      audio.add(o);
    } else {
      video.add(o);
    }
  }

  final sections = <_OptionSection>[];
  if (video.isNotEmpty) {
    sections.add(_OptionSection(title: 'Vidéo complète', options: video));
  }
  if (audio.isNotEmpty) {
    sections.add(_OptionSection(title: 'Audio seul', options: audio));
  }
  if (sections.isEmpty && options.isNotEmpty) {
    sections.add(_OptionSection(title: 'Formats disponibles', options: options));
  }
  return sections;
}

class _SectionBlock {
  const _SectionBlock.header(this.title, this.sectionIndex)
      : option = null,
        isHeader = true;

  const _SectionBlock.option(this.option)
      : title = null,
        sectionIndex = null,
        isHeader = false;

  final String? title;
  final int? sectionIndex;
  final _PickerOption? option;
  final bool isHeader;
}

int _sectionBlockCount(List<_OptionSection> sections) {
  var n = 0;
  for (final s in sections) {
    n += 1 + s.options.length;
  }
  return n;
}

_SectionBlock _sectionBlockAt(List<_OptionSection> sections, int index) {
  var i = 0;
  for (var si = 0; si < sections.length; si++) {
    final section = sections[si];
    if (i == index) {
      return _SectionBlock.header(section.title, si);
    }
    i++;
    for (final o in section.options) {
      if (i == index) return _SectionBlock.option(o);
      i++;
    }
  }
  throw StateError('Index hors limites : $index');
}

class _PickerOptionTile extends StatelessWidget {
  const _PickerOptionTile({
    required this.option,
    required this.theme,
    required this.multiSelect,
    required this.isFocused,
    required this.isChecked,
    required this.onTap,
  });

  final _PickerOption option;
  final ThemeData theme;
  final bool multiSelect;
  final bool isFocused;
  final bool isChecked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = theme.colorScheme;
    return Material(
      color: isFocused || isChecked
          ? scheme.primaryContainer.withValues(alpha: 0.45)
          : scheme.surfaceContainerHighest.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_showsPreview(option.selection.resource)) ...[
                _VariantPreview(
                  resource: option.selection.resource,
                  compact: true,
                ),
                const SizedBox(width: 10),
              ],
              Icon(
                multiSelect
                    ? (isChecked
                        ? Icons.check_box
                        : Icons.check_box_outline_blank)
                    : (isFocused
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off),
                size: 22,
                color: isChecked || isFocused
                    ? scheme.primary
                    : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option.title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      option.subtitle,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      option.bytesLabel,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VariantPreview extends StatelessWidget {
  const _VariantPreview({
    required this.resource,
    this.compact = false,
  });

  final AnalyzedResource resource;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return MediaThumbnail(
      thumbnailUrl: resource.thumbnailUrl,
      previewUrl: resource.finalUrl,
      httpHeaders: resource.downloadHeaders,
      mimeType: resource.mimeType,
      size: compact ? 52 : double.infinity,
      borderRadius: compact ? 10 : 0,
    );
  }
}

String _initialOptionId(
  List<_PickerOption> options,
  AnalyzedResource? defaultResource,
) {
  if (defaultResource != null) {
    final hd = options.where(
      (o) =>
          o.selection.outputProfile == OutputProfile.hd &&
          o.selection.resource.finalUrl == defaultResource.finalUrl,
    );
    if (hd.isNotEmpty) return hd.first.id;
  }
  final completeVideo = options.where((o) => !_isAudioOnlyOption(o));
  if (completeVideo.isNotEmpty) return completeVideo.first.id;

  final firstHd = options.where(
    (o) => o.selection.outputProfile == OutputProfile.hd,
  );
  return firstHd.isNotEmpty ? firstHd.first.id : options.first.id;
}
