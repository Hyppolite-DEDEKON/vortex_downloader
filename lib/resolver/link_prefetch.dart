import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../clipboard/clipboard_detection.dart';
import '../core/utils/url_security.dart';
import 'resolve_result.dart';

class LinkPrefetchState {
  const LinkPrefetchState({
    this.url,
    this.result,
    this.loading = false,
  });

  final String? url;
  final ResolveResult? result;
  final bool loading;
}

class LinkPrefetchNotifier extends Notifier<LinkPrefetchState> {
  Timer? _debounce;
  Future<ResolveResult>? _inFlight;
  String? _inFlightUrl;

  @override
  LinkPrefetchState build() => const LinkPrefetchState();

  void invalidate() {
    _debounce?.cancel();
    _inFlight = null;
    _inFlightUrl = null;
    state = const LinkPrefetchState();
  }

  /// Analyse en arrière-plan après une courte pause (presse-papiers / champ URL).
  void schedule(String raw) {
    final normalized = _normalize(raw);
    if (normalized == null) {
      invalidate();
      return;
    }
    if (state.url == normalized &&
        (state.result != null || state.loading || _inFlightUrl == normalized)) {
      return;
    }
    _debounce?.cancel();
    state = LinkPrefetchState(url: normalized);
    _debounce = Timer(const Duration(milliseconds: 450), () {
      unawaited(_run(normalized));
    });
  }

  /// Résultat immédiat si déjà prêt, sinon lance ou attend l’analyse en cours.
  Future<ResolveResult> resolveForDownload(String raw) async {
    final normalized = _normalize(raw);
    if (normalized == null) {
      return const ResolveFailure('URL invalide (http/https uniquement).');
    }
    if (state.url == normalized && state.result != null) {
      return state.result!;
    }
    if (_inFlightUrl == normalized && _inFlight != null) {
      return _inFlight!;
    }
    return _run(normalized);
  }

  Future<ResolveResult> _run(String url) async {
    if (_inFlightUrl == url && _inFlight != null) {
      return _inFlight!;
    }

    _debounce?.cancel();
    _inFlightUrl = url;
    state = LinkPrefetchState(url: url, loading: true);

    final future = _analyze(url);
    _inFlight = future;
    try {
      return await future;
    } finally {
      if (_inFlightUrl == url) {
        _inFlight = null;
        _inFlightUrl = null;
      }
    }
  }

  Future<ResolveResult> _analyze(String url) async {
    try {
      final fetchVariants = ref.read(settingsProvider).promptQualityChoice;
      final result = await ref.read(linkAnalyzerProvider).analyze(
            url,
            fetchVariants: fetchVariants,
          );
      state = LinkPrefetchState(url: url, result: result);
      if (result is ResolveSuccess) {
        ref.read(clipboardDetectionProvider.notifier).ready(result.resource);
      }
      return result;
    } catch (e) {
      final failure = ResolveFailure('$e');
      state = LinkPrefetchState(url: url, result: failure);
      return failure;
    }
  }

  String? _normalize(String raw) {
    final uri = UrlSecurity.parseAndValidate(raw.trim());
    if (uri == null) return null;
    return UrlSecurity.normalize(uri).toString();
  }
}

final linkPrefetchProvider =
    NotifierProvider<LinkPrefetchNotifier, LinkPrefetchState>(
  LinkPrefetchNotifier.new,
);
