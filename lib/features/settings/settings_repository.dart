import 'package:shared_preferences/shared_preferences.dart';

import 'app_settings.dart';

class SettingsRepository {
  SettingsRepository(this._prefs);
  final SharedPreferences _prefs;

  AppSettings load() {
    final theme = AppThemeMode.values.firstWhere(
      (m) => m.name == (_prefs.getString('theme') ?? 'dark'),
      orElse: () => AppThemeMode.dark,
    );
    return AppSettings(
      themeMode: theme,
      wifiOnly: _prefs.getBool('wifi_only') ?? false,
      maxConcurrent: _prefs.getInt('max_concurrent') ?? 2,
      onboardingDone: _prefs.getBool('onboarding_done') ?? false,
      ytdlpPath: _prefs.getString('ytdlp_path') ?? '',
      promptQualityChoice: _prefs.getBool('prompt_quality') ?? true,
      saveToPublicStorage: _prefs.getBool('save_public_storage') ?? true,
    );
  }

  Future<void> save(AppSettings s) async {
    await _prefs.setString('theme', s.themeMode.name);
    await _prefs.setBool('wifi_only', s.wifiOnly);
    await _prefs.setInt('max_concurrent', s.maxConcurrent);
    await _prefs.setBool('onboarding_done', s.onboardingDone);
    await _prefs.setString('ytdlp_path', s.ytdlpPath);
    await _prefs.setBool('prompt_quality', s.promptQualityChoice);
    await _prefs.setBool('save_public_storage', s.saveToPublicStorage);
  }
}
