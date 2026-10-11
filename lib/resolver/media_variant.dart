import 'analyzed_resource.dart';

/// Une qualité / format téléchargeable proposé à l'utilisateur.
class MediaVariant {
  const MediaVariant({
    required this.id,
    required this.label,
    required this.resource,
    this.sortKey = 0,
  });

  final String id;
  final String label;
  final AnalyzedResource resource;
  final int sortKey;

  factory MediaVariant.fromResource(AnalyzedResource r, {String? label}) {
    return MediaVariant(
      id: r.finalUrl,
      label: label ?? r.fileName,
      resource: r,
      sortKey: r.totalBytes ?? 0,
    );
  }
}
