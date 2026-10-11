import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../clipboard/clipboard_detection.dart';
import '../../../core/design/vortex_tokens.dart';
import '../../../core/logging/vortex_logger.dart';
import '../../../core/utils/url_security.dart';
import '../../../features/downloads/domain/download_selection.dart';
import '../../../resolver/link_prefetch.dart';
import '../../../resolver/resolve_result.dart';
import 'quality_picker_sheet.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _urlCtrl = TextEditingController();
  bool _busy = false;
  bool _replaceDialogOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _warmResolveCache();
    });
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  void _warmResolveCache([String? url]) {
    final u = url ?? _displayedUrl;
    if (u.isEmpty) {
      ref.read(linkPrefetchProvider.notifier).invalidate();
      return;
    }
    ref.read(linkPrefetchProvider.notifier).schedule(u);
  }

  String? get _effectiveUrl {
    final det = ref.read(clipboardDetectionProvider);
    if (_urlCtrl.text.trim().isNotEmpty) return _urlCtrl.text.trim();
    return det.url;
  }

  Future<void> _onHeroTap() async {
    if (_busy) return;
    await _analyzeAndDownload();
  }

  Future<void> _analyzeAndDownload() async {
    final url = _effectiveUrl;
    if (url == null || UrlSecurity.parseAndValidate(url) == null) {
      _toast('Collez ou saisissez une URL http(s) valide.');
      return;
    }

    setState(() => _busy = true);
    VortexLog.app.info('Téléchargement demandé : $url');

    try {
      final result =
          await ref.read(linkPrefetchProvider.notifier).resolveForDownload(url);
      if (!mounted) return;
      switch (result) {
        case final ResolveSuccess success:
          final settings = ref.read(settingsProvider);
          final choices = success.choices;
          var selections = [
            DownloadSelection(resource: success.resource),
          ];
          if (settings.promptQualityChoice) {
            if (!mounted) return;
            setState(() => _busy = false);
            final picked = await showQualityPickerSheet(
              context: context,
              title: success.resource.fileName,
              variants: choices,
              defaultResource: success.resource,
            );
            if (!mounted) return;
            if (picked == null) return;
            selections = picked.selections;
          }
          await _startDownloads(url, selections);
        case ResolveFailure(:final message):
          ref.read(clipboardDetectionProvider.notifier).unsupported(message);
          _toast(message);
        case ResolveUnsupported(:final message):
          ref.read(clipboardDetectionProvider.notifier).unsupported(message);
          _toast(message);
      }
    } catch (e, st) {
      VortexLog.app.severe('Téléchargement interrompu', e, st);
      if (mounted) {
        ref.read(clipboardDetectionProvider.notifier).error('$e');
        _toast('Impossible de traiter le lien.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _startDownloads(
    String source,
    List<DownloadSelection> selections,
  ) async {
    if (selections.isEmpty) return;
    final manager = ref.read(downloadManagerProvider);
    for (final selection in selections) {
      final task = await manager.createTask(
        sourceUrl: source,
        resource: selection.resource,
        outputProfile: selection.outputProfile,
      );
      await manager.enqueue(task);
    }
    ref.read(tasksRefreshProvider.notifier).bump();
    ref.read(linkPrefetchProvider.notifier).invalidate();
    ref
        .read(clipboardDetectionProvider.notifier)
        .resetAfterSuccessfulDownload(source);
    _urlCtrl.clear();
    if (!mounted) return;
    context.go('/downloads');
    if (selections.length == 1) {
      final name = selections.first.resource.fileName;
      _toast('Téléchargement lancé — $name');
    } else {
      _toast('${selections.length} téléchargements lancés');
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String get _displayedUrl {
    final field = _urlCtrl.text.trim();
    if (field.isNotEmpty) return field;
    return ref.read(clipboardDetectionProvider).url?.trim() ?? '';
  }

  Future<void> _promptReplaceClipboardLink(String newUrl) async {
    if (_replaceDialogOpen || _busy) return;
    final current = _displayedUrl;
    if (current == newUrl) {
      ref.read(clipboardDetectionProvider.notifier).clearPendingReplacement();
      return;
    }

    _replaceDialogOpen = true;
    final domain = UrlSecurity.domainFromUrl(newUrl);
    final replace = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nouveau lien détecté'),
        content: Text(
          current.isEmpty
              ? 'Utiliser le lien du presse-papiers ($domain) ?'
              : 'Remplacer le lien actuel par celui du presse-papiers ($domain) ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(current.isEmpty ? 'Annuler' : 'Garder l’actuel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remplacer'),
          ),
        ],
      ),
    );
    _replaceDialogOpen = false;
    if (!mounted) return;

    final notifier = ref.read(clipboardDetectionProvider.notifier);
    if (replace == true) {
      _urlCtrl.text = newUrl;
      notifier.acceptPendingReplacement();
      _warmResolveCache(newUrl);
    } else {
      notifier.declinePendingReplacement();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(clipboardDetectionProvider, (previous, next) {
      final pending = next.pendingReplacementUrl;
      if (pending != null &&
          pending != previous?.pendingReplacementUrl) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _promptReplaceClipboardLink(pending);
        });
        return;
      }
      if (!next.manualLock &&
          next.url != null &&
          _urlCtrl.text.trim().isEmpty) {
        _urlCtrl.text = next.url!;
        _warmResolveCache(next.url);
      }
    });

    final detection = ref.watch(clipboardDetectionProvider);
    final activeCount = ref.watch(activeDownloadCountProvider);
    final theme = Theme.of(context);
    final hasValidLink =
        UrlSecurity.parseAndValidate(_effectiveUrl ?? '') != null;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Text(
                        'Vortex',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      if (activeCount > 0)
                        TextButton.icon(
                          onPressed: () => context.go('/downloads'),
                          icon: const Icon(Icons.bolt_rounded, size: 18),
                          label: Text('$activeCount'),
                        ),
                      IconButton(
                        icon: const Icon(Icons.settings_outlined),
                        onPressed: () => context.push('/settings'),
                      ),
                    ],
                  ),
                  Expanded(
                    child: Center(
                      child: _HeroDownloadButton(
                        busy: _busy,
                        hasLink: hasValidLink,
                        onPressed: _onHeroTap,
                      ),
                    ),
                  ),
                  TextField(
                    controller: _urlCtrl,
                    enabled: !_busy,
                    onChanged: (v) {
                      setState(() {});
                      if (v.trim().isNotEmpty) {
                        ref
                            .read(clipboardDetectionProvider.notifier)
                            .setManualUrl(v.trim());
                        _warmResolveCache(v.trim());
                      } else {
                        ref
                            .read(clipboardDetectionProvider.notifier)
                            .ignore();
                        _warmResolveCache();
                      }
                    },
                    decoration: InputDecoration(
                      hintText: 'https://…',
                      prefixIcon: const Icon(Icons.link_rounded),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (detection.url != null)
                            IconButton(
                              icon: const Icon(Icons.close_rounded, size: 20),
                              onPressed: _busy
                                  ? null
                                  : () {
                                      _urlCtrl.clear();
                                      ref
                                          .read(clipboardDetectionProvider.notifier)
                                          .ignore();
                                      _warmResolveCache();
                                    },
                            ),
                          IconButton(
                            icon: const Icon(Icons.content_paste_go_rounded),
                            onPressed: _busy
                                ? null
                                : () async {
                                    await ref
                                        .read(clipboardServiceProvider)
                                        .pasteToController((u) {
                                      _urlCtrl.text = u;
                                      ref
                                          .read(clipboardDetectionProvider
                                              .notifier)
                                          .setManualUrl(u);
                                      _warmResolveCache(u);
                                    });
                                  },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
          ),
        ),
      ),
    );
  }
}

class _HeroDownloadButton extends StatefulWidget {
  const _HeroDownloadButton({
    required this.busy,
    required this.hasLink,
    required this.onPressed,
  });

  final bool busy;
  final bool hasLink;
  final VoidCallback onPressed;

  @override
  State<_HeroDownloadButton> createState() => _HeroDownloadButtonState();
}

class _HeroDownloadButtonState extends State<_HeroDownloadButton>
    with SingleTickerProviderStateMixin {
  static const _size = 188.0;
  static const _fg = Color(0xE8FFFFFF);

  bool _pressed = false;
  late final AnimationController _glow;

  @override
  void initState() {
    super.initState();
    _glow = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _syncBreathing();
  }

  @override
  void didUpdateWidget(covariant _HeroDownloadButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.hasLink != widget.hasLink || oldWidget.busy != widget.busy) {
      _syncBreathing();
    }
  }

  void _syncBreathing() {
    final breathe = widget.hasLink && !widget.busy;
    if (breathe) {
      if (!_glow.isAnimating) {
        _glow.repeat(reverse: true);
      }
    } else {
      _glow.stop();
      _glow.value = 0;
    }
  }

  @override
  void dispose() {
    _glow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final busy = widget.busy;
    const gradient = VortexTokens.heroGradient;

    return Semantics(
      button: true,
      label: busy ? 'Téléchargement en cours' : 'Télécharger',
      child: SizedBox(
        width: _size + 36,
        height: _size + 36,
        child: Stack(
          alignment: Alignment.center,
          children: [
            AnimatedBuilder(
              animation: _glow,
              builder: (context, child) {
                final breathe = widget.hasLink && !busy;
                final pressScale = _pressed && !busy ? 0.94 : 1.0;
                final breatheScale = breathe
                    ? 1.0 + 0.085 * Curves.easeInOut.transform(_glow.value)
                    : 1.0;
                return Transform.scale(
                  scale: pressScale * breatheScale,
                  child: child,
                );
              },
              child: GestureDetector(
                onTapDown: busy ? null : (_) => setState(() => _pressed = true),
                onTapUp: busy
                    ? null
                    : (_) {
                        setState(() => _pressed = false);
                        widget.onPressed();
                      },
                onTapCancel: busy ? null : () => setState(() => _pressed = false),
                child: Material(
                  elevation: 0,
                  shadowColor: Colors.transparent,
                  shape: const CircleBorder(),
                  color: Colors.transparent,
                  child: Ink(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        width: 1.5,
                        color: busy
                            ? Colors.white.withValues(alpha: 0.18)
                            : Colors.white.withValues(alpha: 0.28),
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: busy
                            ? const [
                                Color(0xFF1E2230),
                                Color(0xFF12151E),
                              ]
                            : gradient,
                      ),
                    ),
                    child: SizedBox(
                      width: _size,
                      height: _size,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (busy)
                            const SizedBox(
                              width: 40,
                              height: 40,
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                color: _fg,
                              ),
                            )
                          else
                            const Icon(
                              Icons.download_rounded,
                              size: 58,
                              color: _fg,
                            ),
                          const SizedBox(height: 8),
                          Text(
                            'Télécharger',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: _fg,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
