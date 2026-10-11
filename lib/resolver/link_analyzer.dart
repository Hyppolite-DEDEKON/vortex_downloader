import '../core/errors/app_exception.dart';
import '../core/logging/vortex_logger.dart';
import '../core/utils/url_security.dart';
import 'resolve_result.dart';
import 'source_resolver.dart';

class LinkAnalyzer {
  LinkAnalyzer(this._chain);
  final SourceResolverChain _chain;

  Future<ResolveResult> analyze(
    String raw, {
    bool fetchVariants = true,
  }) async {
    final uri = UrlSecurity.parseAndValidate(raw);
    if (uri == null) {
      return const ResolveFailure('URL invalide (http/https uniquement).');
    }
    try {
      final normalized = UrlSecurity.normalize(uri);
      final result = await _chain.resolve(normalized);
      if (result is ResolveSuccess) {
        final success = result;
        if (!fetchVariants || success.variants.isNotEmpty) {
          return success;
        }
        final listed = await _chain.listMediaVariants(normalized);
        final variants = listed.isNotEmpty ? listed : success.variants;
        return ResolveSuccess(success.resource, variants: variants);
      }
      return result;
    } on SecurityBlockedException catch (e) {
      VortexLog.resolve.warning('Sécurité : ${e.message}');
      return ResolveFailure(e.message);
    } on AppException catch (e) {
      VortexLog.resolve.warning('Erreur analyse : ${e.message}');
      return ResolveFailure(e.message);
    }
  }
}
