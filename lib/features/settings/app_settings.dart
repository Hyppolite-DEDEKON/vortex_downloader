enum AppThemeMode { system, dark, light }

class AppSettings {
  const AppSettings({
    this.themeMode = AppThemeMode.dark,
    this.wifiOnly = false,
    this.maxConcurrent = 2,
    this.onboardingDone = false,
    this.ytdlpPath = '',
    this.promptQualityChoice = true,
    this.saveToPublicStorage = true,
  });

  final AppThemeMode themeMode;
  final bool wifiOnly;
  final int maxConcurrent;
  final bool onboardingDone;
  final String ytdlpPath;
  final bool promptQualityChoice;

  /// Copie vers Galerie (photos/vidéos) ou Téléchargements système après succès.
  final bool saveToPublicStorage;

  AppSettings copyWith({
    AppThemeMode? themeMode,
    bool? wifiOnly,
    int? maxConcurrent,
    bool? onboardingDone,
    String? ytdlpPath,
    bool? promptQualityChoice,
    bool? saveToPublicStorage,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      wifiOnly: wifiOnly ?? this.wifiOnly,
      maxConcurrent: maxConcurrent ?? this.maxConcurrent,
      onboardingDone: onboardingDone ?? this.onboardingDone,
      ytdlpPath: ytdlpPath ?? this.ytdlpPath,
      promptQualityChoice:
          promptQualityChoice ?? this.promptQualityChoice,
      saveToPublicStorage:
          saveToPublicStorage ?? this.saveToPublicStorage,
    );
  }
}
