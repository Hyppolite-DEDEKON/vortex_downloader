import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/design/glass_panel.dart';
import '../../../core/utils/format_utils.dart';
import '../../../features/settings/app_settings.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Paramètres'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Vortex', style: Theme.of(context).textTheme.titleLarge),
                const Text('One link. One tap.'),
                const SizedBox(height: 4),
                const Text('Version 2.0.0'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          GlassPanel(
            child: Column(
              children: [
                ListTile(
                  title: const Text('Thème'),
                  trailing: DropdownButton<AppThemeMode>(
                    value: settings.themeMode,
                    onChanged: (v) {
                      if (v == null) return;
                      ref.read(settingsProvider.notifier).update(
                            settings.copyWith(themeMode: v),
                          );
                    },
                    items: const [
                      DropdownMenuItem(value: AppThemeMode.dark, child: Text('Sombre')),
                      DropdownMenuItem(value: AppThemeMode.light, child: Text('Clair')),
                      DropdownMenuItem(value: AppThemeMode.system, child: Text('Système')),
                    ],
                  ),
                ),
                SwitchListTile(
                  title: const Text('Wi‑Fi uniquement'),
                  value: settings.wifiOnly,
                  onChanged: (v) => ref.read(settingsProvider.notifier).update(
                        settings.copyWith(wifiOnly: v),
                      ),
                ),
                SwitchListTile(
                  title: const Text('Choisir la qualité'),
                  subtitle: const Text(
                    'Modal HD / 420p converti et poids avant chaque téléchargement.',
                  ),
                  value: settings.promptQualityChoice,
                  onChanged: (v) => ref.read(settingsProvider.notifier).update(
                        settings.copyWith(promptQualityChoice: v),
                      ),
                ),
                ListTile(
                  title: const Text('Téléchargements simultanés'),
                  subtitle: Slider(
                    min: 1,
                    max: 5,
                    divisions: 4,
                    value: settings.maxConcurrent.toDouble(),
                    label: '${settings.maxConcurrent}',
                    onChanged: (v) => ref.read(settingsProvider.notifier).update(
                          settings.copyWith(maxConcurrent: v.round()),
                        ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Plateformes (TikTok, Instagram…)',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                const Text(
                  'TikTok, Instagram, Vimeo, etc. utilisent yt-dlp. '
                  'Sur Android, yt-dlp est intégré automatiquement. '
                  'Sur ordinateur, Vortex le télécharge au premier besoin. '
                  'Ce champ est optionnel (chemin yt-dlp personnalisé sur desktop).',
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: settings.ytdlpPath,
                  decoration: const InputDecoration(
                    labelText: 'Chemin yt-dlp',
                    hintText: '/usr/bin/yt-dlp',
                  ),
                  onFieldSubmitted: (v) => ref.read(settingsProvider.notifier).update(
                        settings.copyWith(ytdlpPath: v.trim()),
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Confidentialité'),
                const SizedBox(height: 8),
                const Text(
                  'Le presse-papiers est lu uniquement lorsque Vortex devient active. '
                  'Aucune URL n’est envoyée à un serveur externe.',
                ),
                const SizedBox(height: 12),
                FutureBuilder<int>(
                  future: ref.read(storageServiceProvider).totalBytes(),
                  builder: (_, s) => Text(
                    'Stockage : ${FormatUtils.formatBytes(s.data)}',
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Vider les fichiers ?'),
                        content: const Text(
                          'Tous les fichiers téléchargés seront supprimés.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Annuler'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Vider'),
                          ),
                        ],
                      ),
                    );
                    if (ok == true) {
                      await ref.read(storageServiceProvider).clearAll();
                    }
                  },
                  child: const Text('Vider le stockage local'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
