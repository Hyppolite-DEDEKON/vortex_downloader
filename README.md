# Vortex

**One link. One tap.** — Téléchargeur universel HTTP/HTTPS pour iOS et Android.

Interface Liquid Glass, détection du presse-papiers à l’ouverture de l’app, moteur de téléchargement modulaire et bibliothèque locale.

## Lancer

```bash
flutter pub get
flutter run
```

## Tests

```bash
flutter analyze
flutter test
```

## Android

```bash
flutter build apk --release
flutter install
```

## iOS (macOS + Xcode)

Ouvrir `ios/Runner.xcworkspace`, configurer la signature, puis `flutter run` ou Product → Run.

## Architecture

- `clipboard/` — détection à la reprise de l’app (pas de surveillance en arrière-plan)
- `resolver/` — analyse URL et résolveurs extensibles
- `downloads/` — moteur, métriques vitesse/ETA, pause/reprise (Range)
- `features/` — écrans Accueil, Téléchargements, Bibliothèque, Paramètres
- `core/design/` — tokens, verre, orbite Vortex

## Limites

- Pas de téléchargement garanti en arrière-plan système (MVP foreground).
- Pas de contournement DRM / auth / JS dynamique.
- Icône launcher par défaut Flutter — remplacer par une icône Vortex custom dans `assets/` si besoin prod.
