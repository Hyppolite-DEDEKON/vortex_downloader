import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'clipboard_service.dart';

enum DetectionPhase { idle, detected, unsupported, error }

class ClipboardDetectionState {
  const ClipboardDetectionState({
    this.phase = DetectionPhase.idle,
    this.url,
    this.message,
    this.manualLock = false,
    this.pendingReplacementUrl,
  });

  final DetectionPhase phase;
  final String? url;
  final String? message;
  final bool manualLock;
  /// Nouveau lien presse-papiers en attente de confirmation (remplacer l’actuel).
  final String? pendingReplacementUrl;

  ClipboardDetectionState copyWith({
    DetectionPhase? phase,
    String? url,
    String? message,
    bool? manualLock,
    String? pendingReplacementUrl,
    bool clearUrl = false,
    bool clearPendingReplacement = false,
  }) {
    return ClipboardDetectionState(
      phase: phase ?? this.phase,
      url: clearUrl ? null : (url ?? this.url),
      message: message ?? this.message,
      manualLock: manualLock ?? this.manualLock,
      pendingReplacementUrl: clearPendingReplacement
          ? null
          : (pendingReplacementUrl ?? this.pendingReplacementUrl),
    );
  }
}

class ClipboardDetectionNotifier extends Notifier<ClipboardDetectionState> {
  String? _ignoredUrl;
  String? _lastShownUrl;

  @override
  ClipboardDetectionState build() => const ClipboardDetectionState();

  Future<void> onAppResumed() async {
    final url = await ref.read(clipboardServiceProvider).readUrl();
    if (url == null) {
      if (state.phase == DetectionPhase.detected) return;
      state = state.copyWith(phase: DetectionPhase.idle, clearUrl: true);
      return;
    }
    if (url == _ignoredUrl) return;
    if (url == _lastShownUrl &&
        state.url == url &&
        state.pendingReplacementUrl == null) {
      return;
    }

    final current = state.url?.trim();
    if (current == null || current.isEmpty) {
      _lastShownUrl = url;
      state = ClipboardDetectionState(
        phase: DetectionPhase.detected,
        url: url,
      );
      return;
    }

    if (url == current) {
      state = state.copyWith(clearPendingReplacement: true);
      return;
    }

    state = state.copyWith(pendingReplacementUrl: url);
  }

  void lockManualEntry() {
    state = state.copyWith(manualLock: true);
  }

  void unlockManual() {
    state = state.copyWith(manualLock: false);
  }

  void setManualUrl(String url) {
    _lastShownUrl = url;
    state = ClipboardDetectionState(
      phase: DetectionPhase.detected,
      url: url,
      manualLock: true,
    );
  }

  void ignore() {
    if (state.url != null) _ignoredUrl = state.url;
    state = const ClipboardDetectionState(phase: DetectionPhase.idle);
  }

  void clearPendingReplacement() {
    state = state.copyWith(clearPendingReplacement: true);
  }

  /// Refus de remplacer : on ignore le lien proposé (presse-papiers).
  void declinePendingReplacement() {
    final pending = state.pendingReplacementUrl;
    if (pending != null) _ignoredUrl = pending;
    state = state.copyWith(clearPendingReplacement: true);
  }

  void acceptPendingReplacement() {
    final pending = state.pendingReplacementUrl;
    if (pending == null) return;
    _lastShownUrl = pending;
    state = ClipboardDetectionState(
      phase: DetectionPhase.detected,
      url: pending,
      manualLock: true,
    );
  }

  void unsupported(String message) {
    state = state.copyWith(
      phase: DetectionPhase.unsupported,
      message: message,
    );
  }

  void error(String message) {
    state = state.copyWith(
      phase: DetectionPhase.error,
      message: message,
    );
  }

  /// Après un téléchargement lancé : vide l’accueil (évite de garder l’ancien lien).
  void resetAfterSuccessfulDownload(String? sourceUrl) {
    if (sourceUrl != null && sourceUrl.isNotEmpty) {
      _ignoredUrl = sourceUrl;
    }
    _lastShownUrl = null;
    state = const ClipboardDetectionState(phase: DetectionPhase.idle);
  }
}

final clipboardServiceProvider = Provider((ref) => ClipboardService());

final clipboardDetectionProvider =
    NotifierProvider<ClipboardDetectionNotifier, ClipboardDetectionState>(
  ClipboardDetectionNotifier.new,
);
