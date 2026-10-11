import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'dart:async';

import '../clipboard/clipboard_detection.dart';
import '../core/design/vortex_theme.dart';
import '../core/logging/vortex_logger.dart';
import '../resolver/platform/extractor_service.dart';
import '../resolver/platform/ytdlp_bootstrap.dart';
import 'providers.dart';

class VortexApp extends ConsumerStatefulWidget {
  const VortexApp({super.key, required this.router});

  final GoRouter router;

  @override
  ConsumerState<VortexApp> createState() => _VortexAppState();
}

class _VortexAppState extends ConsumerState<VortexApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(() async {
      await ref.read(downloadManagerProvider).restoreInterrupted();
      ref.read(tasksRefreshProvider.notifier).bump();
      await ref.read(clipboardDetectionProvider.notifier).onAppResumed();
      unawaited(Future(() async {
        if (ExtractorService.isPlatform) {
          await ExtractorService.ensureReady();
        } else {
          await YtdlpBootstrap.ensureBinary();
        }
        VortexLog.ytdlp.fine('Préparation yt-dlp en arrière-plan terminée');
      }));
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(clipboardDetectionProvider.notifier).onAppResumed();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Vortex',
      debugShowCheckedModeBanner: false,
      theme: VortexTheme.light(),
      darkTheme: VortexTheme.dark(),
      themeMode: ref.watch(themeModeProvider),
      routerConfig: widget.router,
    );
  }
}
