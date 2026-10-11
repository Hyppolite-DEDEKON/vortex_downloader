import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;
import 'package:video_player/video_player.dart';

import '../../core/design/glass_panel.dart';
import '../../core/design/vortex_tokens.dart';
import '../../core/logging/vortex_logger.dart';
import 'local_playback.dart';
import 'vortex_player_ui.dart';

class VortexMediaPlayerScreen extends StatefulWidget {
  const VortexMediaPlayerScreen({
    super.key,
    required this.filePath,
    required this.title,
    required this.kind,
    this.thumbnailUrl,
  });

  final String filePath;
  final String title;
  final LocalMediaKind kind;
  final String? thumbnailUrl;

  @override
  State<VortexMediaPlayerScreen> createState() => _VortexMediaPlayerScreenState();
}

class _VortexMediaPlayerScreenState extends State<VortexMediaPlayerScreen> {
  VideoPlayerController? _video;
  AudioPlayer? _audio;
  var _ready = false;
  var _error = false;
  var _channelError = false;

  @override
  void initState() {
    super.initState();
    if (widget.kind == LocalMediaKind.video) {
      unawaited(_enterVideoImmersive());
    } else {
      _audio = AudioPlayer();
    }
    unawaited(_init());
  }

  Future<void> _enterVideoImmersive() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );
  }

  Future<void> _exitVideoImmersive() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  Future<void> _init() async {
    try {
      if (widget.kind == LocalMediaKind.video) {
        final c = VideoPlayerController.file(File(widget.filePath));
        await c.initialize();
        if (!mounted) {
          await c.dispose();
          return;
        }
        _video = c;
        await c.play();
      } else {
        final player = _audio!;
        await player.setFilePath(widget.filePath);
        if (!mounted) return;
        if (mounted) setState(() => _ready = true);
        await player.play();
      }
      if (widget.kind == LocalMediaKind.video && mounted) {
        setState(() => _ready = true);
      }
    } on PlatformException catch (e, st) {
      VortexLog.app.warning('Lecteur natif : ${e.message}', e, st);
      if (mounted) {
        setState(() {
          _error = true;
          _channelError = e.code == 'channel-error';
        });
      }
    } catch (e, st) {
      VortexLog.app.warning('Lecteur : $e', e, st);
      if (mounted) setState(() => _error = true);
    }
  }

  void _openExternally() {
    Navigator.of(context).pop(true);
  }

  Future<void> _close() async {
    if (widget.kind == LocalMediaKind.video) {
      await _exitVideoImmersive();
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    if (widget.kind == LocalMediaKind.video) {
      unawaited(_exitVideoImmersive());
    }
    unawaited(_video?.dispose());
    unawaited(_audio?.dispose());
    super.dispose();
  }

  String get _displayTitle {
    final base = p.basenameWithoutExtension(widget.title);
    return base.isNotEmpty ? base : widget.title;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.kind == LocalMediaKind.video) {
      return _buildVideoScaffold(context);
    }
    return _buildAudioScaffold(context);
  }

  Widget _buildAudioScaffold(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          VortexPlayerBackdrop(imageUrl: widget.thumbnailUrl),
          SafeArea(
            child: Column(
              children: [
                VortexPlayerTopBar(
                  title: _displayTitle,
                  subtitle: 'Piste audio',
                  onClose: () => unawaited(_close()),
                ),
                Expanded(
                  child: _error
                      ? _ErrorPanel(
                          channelError: _channelError,
                          onExternal: _openExternally,
                        )
                      : _PremiumAudioBody(
                          player: _audio!,
                          title: _displayTitle,
                          fileName: widget.title,
                          thumbnailUrl: widget.thumbnailUrl,
                          sourceReady: _ready,
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoScaffold(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _error
          ? SafeArea(
              child: _ErrorPanel(
                channelError: _channelError,
                onExternal: _openExternally,
                lightText: true,
              ),
            )
          : !_ready
              ? const Center(
                  child: CircularProgressIndicator(color: VortexTokens.brandCyan),
                )
              : _PremiumVideoBody(
                  controller: _video!,
                  title: _displayTitle,
                  onClose: () => unawaited(_close()),
                ),
    );
  }
}

class _PremiumAudioBody extends StatelessWidget {
  const _PremiumAudioBody({
    required this.player,
    required this.title,
    required this.fileName,
    required this.sourceReady,
    this.thumbnailUrl,
  });

  final AudioPlayer player;
  final String title;
  final String fileName;
  final bool sourceReady;
  final String? thumbnailUrl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    return StreamBuilder<PlayerState>(
      stream: player.playerStateStream,
      builder: (context, stateSnap) {
        final state = stateSnap.data;
        final playing = state?.playing ?? false;
        final processing = state?.processingState;
        final busy = !sourceReady ||
            processing == ProcessingState.loading ||
            processing == ProcessingState.buffering;
        return StreamBuilder<Duration>(
          stream: player.positionStream,
          builder: (context, posSnap) {
            final pos = posSnap.data ?? Duration.zero;
            final dur = player.duration ?? Duration.zero;
            final progress = dur.inMilliseconds > 0
                ? pos.inMilliseconds / dur.inMilliseconds
                : 0.0;

            void seekRelative(int seconds) {
              final target = pos + Duration(seconds: seconds);
              final clamped = target < Duration.zero
                  ? Duration.zero
                  : (dur > Duration.zero && target > dur ? dur : target);
              unawaited(player.seek(clamped));
            }

            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Column(
                children: [
                  const Spacer(flex: 2),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: VortexAudioArtwork(thumbnailUrl: thumbnailUrl),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    fileName,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(color: muted),
                  ),
                  const SizedBox(height: 20),
                  VortexAudioVisualizer(active: playing && !busy),
                  const Spacer(flex: 3),
                  VortexPlayerTransport(
                    playing: playing,
                    loading: busy,
                    position: pos,
                    duration: dur,
                    progress: progress.clamp(0.0, 1.0),
                    onPlayPause: busy
                        ? null
                        : () {
                            if (playing) {
                              player.pause();
                            } else {
                              player.play();
                            }
                          },
                    onSeek: busy
                        ? null
                        : (v) => player.seek(
                              Duration(
                                milliseconds:
                                    (dur.inMilliseconds * v).round(),
                              ),
                            ),
                    onRewind: busy ? null : () => seekRelative(-10),
                    onForward: busy ? null : () => seekRelative(10),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _PremiumVideoBody extends StatefulWidget {
  const _PremiumVideoBody({
    required this.controller,
    required this.title,
    required this.onClose,
  });

  final VideoPlayerController controller;
  final String title;
  final VoidCallback onClose;

  @override
  State<_PremiumVideoBody> createState() => _PremiumVideoBodyState();
}

class _PremiumVideoBodyState extends State<_PremiumVideoBody> {
  var _controlsVisible = true;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onVideoTick);
    _scheduleHide();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    widget.controller.removeListener(_onVideoTick);
    super.dispose();
  }

  void _onVideoTick() {
    if (mounted) setState(() {});
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    if (!widget.controller.value.isPlaying) return;
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && widget.controller.value.isPlaying) {
        setState(() => _controlsVisible = false);
      }
    });
  }

  void _toggleControls() {
    setState(() => _controlsVisible = !_controlsVisible);
    if (_controlsVisible) _scheduleHide();
  }

  void _seekRelative(int seconds) {
    final c = widget.controller;
    final pos = c.value.position;
    final dur = c.value.duration;
    final target = pos + Duration(seconds: seconds);
    final clamped = target < Duration.zero
        ? Duration.zero
        : (dur > Duration.zero && target > dur ? dur : target);
    unawaited(c.seekTo(clamped));
    _revealControls();
  }

  void _revealControls() {
    setState(() => _controlsVisible = true);
    _scheduleHide();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final pos = c.value.position;
    final dur = c.value.duration;
    final progress = dur.inMilliseconds > 0
        ? pos.inMilliseconds / dur.inMilliseconds
        : 0.0;
    final playing = c.value.isPlaying;
    final aspect = c.value.aspectRatio > 0 ? c.value.aspectRatio : 16 / 9;

    return GestureDetector(
      onTap: _toggleControls,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: aspect,
              child: VideoPlayer(c),
            ),
          ),
          AnimatedOpacity(
            opacity: _controlsVisible ? 1 : 0,
            duration: const Duration(milliseconds: 220),
            child: IgnorePointer(
              ignoring: !_controlsVisible,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.65),
                          Colors.transparent,
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.85),
                        ],
                        stops: const [0, 0.22, 0.62, 1],
                      ),
                    ),
                  ),
                  VortexPlayerTopBar(
                    title: widget.title,
                    subtitle: 'Vidéo',
                    onClose: widget.onClose,
                    lightForeground: true,
                  ),
                  if (!playing)
                    Center(
                      child: VortexPlayPauseOrb(
                        playing: false,
                        onPressed: () {
                          unawaited(c.play());
                          _revealControls();
                        },
                        size: 80,
                      ),
                    ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(VortexTokens.radiusL),
                      ),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(
                          sigmaX: VortexTokens.blurSigma,
                          sigmaY: VortexTokens.blurSigma,
                        ),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.42),
                            border: Border(
                              top: BorderSide(
                                color: Colors.white.withValues(alpha: 0.12),
                              ),
                            ),
                          ),
                          child: VortexPlayerTransport(
                            dark: true,
                            compact: true,
                            playing: playing,
                            position: pos,
                            duration: dur,
                            progress: progress.clamp(0.0, 1.0),
                            onPlayPause: () {
                              if (playing) {
                                c.pause();
                              } else {
                                unawaited(c.play());
                              }
                              _revealControls();
                            },
                            onSeek: (v) {
                              unawaited(
                                c.seekTo(
                                  Duration(
                                    milliseconds:
                                        (dur.inMilliseconds * v).round(),
                                  ),
                                ),
                              );
                              _revealControls();
                            },
                            onRewind: () => _seekRelative(-10),
                            onForward: () => _seekRelative(10),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({
    required this.channelError,
    required this.onExternal,
    this.lightText = false,
  });

  final bool channelError;
  final VoidCallback onExternal;
  final bool lightText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fg = lightText ? Colors.white : theme.colorScheme.onSurface;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: GlassPanel(
          borderRadius: VortexTokens.radiusL,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 40,
                color: VortexTokens.brandViolet,
              ),
              const SizedBox(height: 16),
              Text(
                channelError
                    ? 'Le lecteur intégré n’est pas prêt. Arrêtez l’app puis relancez-la (pas un hot reload).'
                    : 'Impossible de lire ce fichier ici.',
                style: theme.textTheme.bodyLarge?.copyWith(color: fg),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onExternal,
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text('Ouvrir avec une autre app'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
