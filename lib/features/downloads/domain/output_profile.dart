import 'package:path/path.dart' as p;

import '../../../core/utils/file_name_utils.dart';

/// Profil de fichier final après téléchargement (et conversion éventuelle).
enum OutputProfile {
  /// Fichier tel que fourni par la source (qualité d’origine).
  hd,

  /// Vidéo re-encodée en 420p pour réduire le poids.
  reduced420p;

  static OutputProfile fromStorage(String? value) {
    if (value == OutputProfile.reduced420p.name) return reduced420p;
    return hd;
  }

  String get storageValue => name;

  String get displayLabel => switch (this) {
        hd => 'HD — qualité d’origine',
        reduced420p => '420p — converti (plus léger)',
      };

  String get shortLabel => switch (this) {
        hd => 'HD',
        reduced420p => '420p',
      };
}

/// Applique le suffixe de profil au nom de fichier (ex. `_420p.mp4`).
String fileNameForProfile(String fileName, OutputProfile profile) {
  var name = FileNameUtils.forStorage(fileName);
  if (profile == OutputProfile.hd) return name;
  final lower = name.toLowerCase();
  if (!lower.endsWith('.mp4')) {
    name = '${p.basenameWithoutExtension(name)}.mp4';
  }
  final base = p.basenameWithoutExtension(name);
  if (base.endsWith('_420p')) return name;
  return '${base}_420p${p.extension(name)}';
}
