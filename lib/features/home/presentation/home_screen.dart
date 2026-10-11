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

enum _ActionPhase { idle, analyzing }

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _urlCtrl = TextEditingController();
  _ActionPhase _phase = _ActionPhase.idle;
  bool _replaceDialogOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _scheduleLinkPrefetch();
    });
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  void _scheduleLinkPrefetch([String? url]) {
    final u = url ?? _displayedUrl;
    if (u.isEmpty) {
      ref.read(linkPrefetchProvider.notifier).invalidate();
      return;
    }
    ref.read(linkPrefetchProvider.notifier).schedule(u);
  }

  bool get _busy => _phase != _ActionPhase.idle;

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

    setState(() => _phase = _ActionPhase.analyzing);
    ref.read(clipboardDetectionProvider.notifier).analyzing();
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
            setState(() => _phase = _ActionPhase.idle);
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
          ref
              .read(clipboardDetectionProvider.notifier)
              .ready(selections.first.resource);
          await _startDownloads(url, selections);
        case ResolveFailure(:final message):
          ref.read(clipboardDetectionProvider.notifier).unsupported(message);
          _toast(message);
        case ResolveUnsupported(:final message):
          ref.read(clipboardDetectionProvider.notifier).unsupported(message);
          _toast(message);
      }
    } catch (e, st) {
      VortexLog.app.severe('Analyse / téléchargement interrompu', e, st);
      if (mounted) {
        ref.read(clipboardDetectionProvider.notifier).error('$e');
        _toast('Impossible d’analyser le lien.');
      }
    } finally {
      if (mounted) setState(() => _phase = _ActionPhase.idle);
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
    if (selections.length == 1) {
      final name = selections.first.resource.fileName;
      _toast('Téléchargement lancé — $name');
    } else {
      _toast('${selections.length} téléchargements lancés');
    }
    context.go('/downloads');
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
      _scheduleLinkPrefetch(newUrl);
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
        _scheduleLinkPrefetch(next.url);
      }
    });

    final detection = ref.watch(clipboardDetectionProvider);
    final activeCount = ref.watch(activeDownloadCountProvider);
    final theme = Theme.of(context);

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
                        phase: _phase,
                        onPressed: _onHeroTap,
                      ),
                    ),
                  ),
                  TextField(
                    controller: _urlCtrl,
                    enabled: !_busy,
                    onChanged: (v) {
                      if (v.trim().isNotEmpty) {
                        ref
                            .read(clipboardDetectionProvider.notifier)
                            .setManualUrl(v.trim());
                        _scheduleLinkPrefetch(v.trim());
                      } else {
                        _scheduleLinkPrefetch();
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
                                      _scheduleLinkPrefetch();
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
                                      _scheduleLinkPrefetch(u);
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
    required this.phase,
    required this.onPressed,
  });

  final bool busy;
  final _ActionPhase phase;
  final VoidCallback onPressed;

  @override
  State<_HeroDownloadButton> createState() => _HeroDownloadButtonState();
}

class _HeroDownloadButtonState extends State<_HeroDownloadButton>
    with SingleTickerProviderStateMixin {
  static const _size = 168.0;
  static const _fg = Color(0xE8FFFFFF);
  static const _violetTop = Color(0xFF5C5280);
  static const _violetMid = Color(0xFF4A4268);
  static const _violetBottom = Color(0xFF38324F);

  bool _pressed = false;
  late final AnimationController _glow;

  @override
  void initState() {
    super.initState();
    _glow = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
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
    final scale = _pressed && !busy ? 0.94 : 1.0;

    return Semantics(
      button: true,
      label: busy ? 'Téléchargement en cours' : 'Télécharger',
      child: SizedBox(
        width: _size + 36,
        height: _size + 36,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (!busy)
              AnimatedBuilder(
                animation: _glow,
                builder: (context, child) {
                  final t = Curves.easeInOut.transform(_glow.value);
                  return Container(
                    width: _size + 8 + 10 * t,
                    height: _size + 8 + 10 * t,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: VortexTokens.brandViolet
                              .withValues(alpha: 0.10 + 0.08 * t),
                          blurRadius: 28 + 6 * t,
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                  );
                },
              ),
            Transform.scale(
              scale: scale,
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
                  elevation: busy ? 2 : 6,
                  shadowColor:
                      VortexTokens.brandViolet.withValues(alpha: 0.28),
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
                            ? [
                                const Color(0xFF1E2230),
                                const Color(0xFF12151E),
                              ]
                            : [
                                _violetTop,
                                _violetMid,
                                _violetBottom,
                              ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.35),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                        if (!busy)
                          BoxShadow(
                            color: Colors.white.withValues(alpha: 0.12),
                            blurRadius: 0,
                            offset: const Offset(0, -1),
                            spreadRadius: 0,
                          ),
                      ],
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
                              size: 52,
                              color: _fg,
                              shadows: [
                                Shadow(
                                  color: Color(0x66000000),
                                  blurRadius: 12,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                          const SizedBox(height: 8),
                          Text(
                            busy ? 'Analyse…' : 'Télécharger',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: _fg,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
                              shadows: const [
                                Shadow(
                                  color: Color(0x66000000),
                                  blurRadius: 8,
                                  offset: Offset(0, 2),
                                ),
                              ],
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
