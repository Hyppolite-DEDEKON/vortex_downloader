import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../core/utils/url_security.dart';
import 'resolve_result.dart';

/// Cache de résolution (pré-chargement silencieux + réutilisation au tap).
class LinkResolveState {
  const LinkResolveState({
    this.url,
    this.result,
  });

  final String? url;
  final ResolveResult? result;
}

class LinkResolveNotifier extends Notifier<LinkResolveState> {
  Timer? _debounce;
  Future<ResolveResult>? _inFlight;
  String? _inFlightUrl;

  @override
  LinkResolveState build() => const LinkResolveState();

  void invalidate() {
    _debounce?.cancel();
    _inFlight = null;
    _inFlightUrl = null;
    state = const LinkResolveState();
  }

  /// Prépare le lien en arrière-plan (sans changer l’UI).
  void schedule(String raw) {
    final normalized = _normalize(raw);
    if (normalized == null) {
      invalidate();
      return;
    }
    if (state.url == normalized &&
        (state.result != null || _inFlightUrl == normalized)) {
      return;
    }
    _debounce?.cancel();
    state = LinkResolveState(url: normalized);
    _debounce = Timer(const Duration(milliseconds: 350), () {
      unawaited(_resolve(normalized));
    });
  }

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
    return _resolve(normalized);
  }

  Future<ResolveResult> _resolve(String url) async {
    if (_inFlightUrl == url && _inFlight != null) {
      return _inFlight!;
    }

    _debounce?.cancel();
    _inFlightUrl = url;
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
      state = LinkResolveState(url: url, result: result);
      return result;
    } catch (e) {
      final failure = ResolveFailure('$e');
      state = LinkResolveState(url: url, result: failure);
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
    NotifierProvider<LinkResolveNotifier, LinkResolveState>(
  LinkResolveNotifier.new,
);
