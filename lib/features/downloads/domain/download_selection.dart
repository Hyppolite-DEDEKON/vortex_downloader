import '../../../resolver/analyzed_resource.dart';
import 'output_profile.dart';

/// Choix utilisateur avant lancement d’un téléchargement.
class DownloadSelection {
  const DownloadSelection({
    required this.resource,
    this.outputProfile = OutputProfile.hd,
  });

  final AnalyzedResource resource;
  final OutputProfile outputProfile;
}

/// Résultat du bottom sheet qualité (une ou plusieurs ressources).
class QualityPickerResult {
  const QualityPickerResult(this.selections);

  final List<DownloadSelection> selections;

  factory QualityPickerResult.single(DownloadSelection selection) =>
      QualityPickerResult([selection]);
}
