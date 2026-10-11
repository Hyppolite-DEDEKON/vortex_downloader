import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../core/utils/url_security.dart';
import 'resolve_result.dart';

/// Cache de résolution (pré-chargement silencieux ; pas réutilisé tel quel au tap).
class LinkResolveState {
  const LinkResolveState({
    this.url,
    this.result,
    this.resolvedAt,
  });

  final String? url;
  final ResolveResult? result;
  final DateTime? resolvedAt;
}

class LinkResolveNotifier extends Notifier<LinkResolveState> {
  Timer? _debounce;
  Future<ResolveResult>? _inFlight;
  String? _inFlightUrl;

  /// Durée pendant laquelle le préchargement évite une nouvelle analyse.
  static const prefetchTtl = Duration(minutes: 4);

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
        _isPrefetchFresh(normalized) &&
        (state.result != null || _inFlightUrl == normalized)) {
      return;
    }
    _debounce?.cancel();
    state = LinkResolveState(url: normalized, resolvedAt: state.resolvedAt);
    _debounce = Timer(const Duration(milliseconds: 350), () {
      unawaited(_resolve(normalized));
    });
  }

  /// Toujours ré-analyse avant un téléchargement (URLs CDN signées).
  Future<ResolveResult> resolveForDownload(String raw) async {
    final normalized = _normalize(raw);
    if (normalized == null) {
      return const ResolveFailure('URL invalide (http/https uniquement).');
    }
    if (_inFlightUrl == normalized && _inFlight != null) {
      return _inFlight!;
    }
    return _resolve(normalized);
  }

  bool _isPrefetchFresh(String url) {
    if (state.url != url || state.result == null || state.resolvedAt == null) {
      return false;
    }
    return DateTime.now().difference(state.resolvedAt!) < prefetchTtl;
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
      state = LinkResolveState(
        url: url,
        result: result,
        resolvedAt: DateTime.now(),
      );
      return result;
    } catch (e) {
      final failure = ResolveFailure('$e');
      state = LinkResolveState(
        url: url,
        result: failure,
        resolvedAt: DateTime.now(),
      );
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
