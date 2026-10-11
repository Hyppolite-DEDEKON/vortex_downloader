import 'package:dio/dio.dart';

/// Messages utilisateur pour accès refusé / URL média expirée.
abstract final class LinkAccessMessages {
  static const expiredAccess =
      'L’accès au fichier a expiré. Retournez à l’accueil et relancez le téléchargement avec le même lien de publication.';

  static const reanalyzeFailed =
      'Impossible d’obtenir un nouveau lien. Vérifiez la connexion ou recopiez la publication depuis l’accueil.';

  static String resolveFailureForHttpStatus(int code) {
    switch (code) {
      case 403:
        return expiredAccess;
      case 410:
        return expiredAccess;
      case 404:
        return 'Fichier introuvable. Utilisez le lien de la publication plutôt qu’un lien direct, ou réessayez depuis l’accueil.';
      case 429:
        return 'Trop de requêtes (429). Patientez un instant puis réessayez.';
      default:
        if (code >= 500) return 'Erreur serveur ($code).';
        if (code >= 400) return 'Requête rejetée ($code).';
        return 'Erreur HTTP ($code).';
    }
  }

  static String userMessageForDio(DioException e) {
    final code = e.response?.statusCode;
    if (code != null && code >= 400) {
      return resolveFailureForHttpStatus(code);
    }
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Délai dépassé. Vérifiez votre connexion et réessayez.';
      case DioExceptionType.connectionError:
        return 'Connexion impossible. Vérifiez le réseau.';
      case DioExceptionType.cancel:
        return 'Téléchargement annulé.';
      default:
        return e.message?.trim().isNotEmpty == true
            ? e.message!
            : 'Erreur réseau pendant le téléchargement.';
    }
  }

  /// Indique si un nouvel essai devrait repasser par l’analyse du lien source.
  static bool shouldReanalyzeForRetry(String? lastError) {
    if (lastError == null || lastError.isEmpty) return false;
    final lower = lastError.toLowerCase();
    if (lower.contains('expir')) return true;
    if (lower.contains('403') || lower.contains('410')) return true;
    if (lower.contains('accès refusé')) return true;
    return lastError == expiredAccess;
  }
}
