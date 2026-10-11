import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_store_plus/media_store_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/logging/vortex_logger.dart';
import 'app/providers.dart';
import 'app/router.dart';
import 'app/vortex_app.dart';
import 'features/downloads/data/download_database.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  VortexLog.init();
  if (Platform.isAndroid) {
    MediaStore.appFolder = 'Vortex';
    await MediaStore.ensureInitialized();
  }
  final prefs = await SharedPreferences.getInstance();
  final db = await DownloadDatabase.open();
  final router = createVortexRouter(
    onboardingDone: prefs.getBool('onboarding_done') ?? false,
  );

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        downloadDatabaseProvider.overrideWithValue(db),
      ],
      child: VortexApp(router: router),
    ),
  );
}
