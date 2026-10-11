import 'link_analyzer.dart';
import 'analyzed_resource.dart';
import 'resolve_result.dart';

/// Ré-analyse la page source pour obtenir une URL média à jour (CDN signé).
Future<AnalyzedResource?> refreshSourceMedia(
  LinkAnalyzer analyzer,
  String sourceUrl,
) async {
  final result = await analyzer.analyze(sourceUrl, fetchVariants: false);
  if (result is ResolveSuccess) return result.resource;
  return null;
}
