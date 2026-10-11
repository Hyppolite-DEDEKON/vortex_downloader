# Vortex

**One link. One tap.** — Téléchargeur universel pour liens HTTP/HTTPS et grandes plateformes vidéo / audio.

[![Flutter](https://img.shields.io/badge/Flutter-3.10+-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Plateformes](https://img.shields.io/badge/Plateformes-Android%20%7C%20iOS%20%7C%20Desktop-7B5CFF)](https://github.com/Hyppolite-DEDEKON/vortex_downloader)
[![Open Source](https://img.shields.io/badge/Open%20Source-GitHub-181717?logo=github)](https://github.com/Hyppolite-DEDEKON/vortex_downloader)

Application **Flutter** open source : interface type *liquid glass*, analyse de liens, choix de qualité, téléchargements avec pause/reprise, export galerie / dossier Téléchargements, et **lecteur audio / vidéo intégré** pour les fichiers terminés.

> Dépôt : [github.com/Hyppolite-DEDEKON/vortex_downloader](https://github.com/Hyppolite-DEDEKON/vortex_downloader)

---

## Fonctionnalités

| Domaine | Détail |
|--------|--------|
| **Accueil** | Coller ou partager une URL, pré-analyse du lien, proposition de téléchargement |
| **Plateformes** | YouTube, TikTok, Instagram, Facebook, X/Twitter, Vimeo, Twitch, Reddit, SoundCloud, etc. (via résolveurs dédiés + **yt-dlp**) |
| **Qualité** | Feuille de choix vidéo complète / audio seul, fusion HD (YouTube + Android / extracteur) |
| **Téléchargements** | File d’attente, pause / reprise (HTTP Range quand supporté), vitesse et ETA, retry si lien expiré |
| **Lecteur** | Lecture locale **audio** (`just_audio`) et **vidéo** (`video_player`), UI dédiée ; repli vers une app externe si besoin |
| **Paramètres** | Thème clair / sombre / système, Wi‑Fi uniquement, export public, concurrence, chemin yt-dlp (desktop) |
| **Vie privée** | Presse-papiers lu **uniquement** quand l’app reprend le premier plan ; pas d’envoi d’URL vers un serveur Vortex |

---

## Prérequis

- [Flutter SDK](https://docs.flutter.dev/get-started/install) **3.10+** (Dart **3.10+**)
- **Android** : SDK 24+, build Gradle standard du template Flutter
- **iOS** : Xcode sur macOS pour compiler et signer
- **Desktop** (Linux / macOS / Windows) : possible pour le développement ; **yt-dlp** est téléchargé au premier besoin ou configurable dans les paramètres

---

## Installation & lancement

```bash
git clone https://github.com/Hyppolite-DEDEKON/vortex_downloader.git
cd vortex_downloader
flutter pub get
flutter run
```

Cible explicite :

```bash
flutter run -d android
flutter run -d ios
flutter run -d linux   # ou windows / macos
```

### Build release

**Android**

```bash
flutter build apk --release
# ou
flutter build appbundle --release
```

**iOS** — ouvrir `ios/Runner.xcworkspace`, configurer l’équipe de signature, puis :

```bash
flutter build ios --release
```

---

## Qualité & tests

```bash
flutter analyze
flutter test
```

---

## Architecture du code

```
lib/
├── app/              # Router (go_router), providers Riverpod
├── clipboard/        # Détection d’URL au retour sur l’app
├── core/             # Design system, réseau, utils, logs
├── downloads/        # Moteur de téléchargement, export, fusion extracteur
├── features/
│   ├── home/         # Accueil, choix de qualité
│   ├── downloads/    # Liste actifs / terminés
│   ├── player/       # Lecteur média intégré
│   ├── settings/
│   └── onboarding/
└── resolver/         # Chaîne de résolution URL → ressource + variantes
```

- **Résolution** : extracteurs natifs (ex. YouTube via `youtube_explode_dart`, TikTok) complétés par **yt-dlp** pour de nombreux hôtes.
- **Persistance** : SQLite (`sqflite`) pour l’historique des tâches.
- **UI** : Material 3, tokens `vortex_tokens.dart`, panneaux verre `glass_panel.dart`.

---

## Lecteur intégré

Après un téléchargement terminé, un appui sur **lecture** ouvre le lecteur Vortex pour les fichiers audio / vidéo reconnus (MIME ou extension). En cas d’échec du moteur natif (souvent après un **hot reload** sans rebuild complet), utilisez **Ouvrir avec une autre app** ou relancez l’application :

```bash
flutter clean && flutter pub get && flutter run
```

---

## Contribuer

Les contributions sont les bienvenues (issues, PR, traductions, tests).

1. Fork le dépôt et créez une branche (`feat/ma-fonctionnalite`).
2. Respectez `flutter analyze` et `flutter test`.
3. Décrivez clairement le **pourquoi** dans la PR.

Pour les bugs, indiquez la **plateforme**, la **version Flutter** et un **lien exemple** (si possible sans contenu sensible).

---

## Limites & responsabilité

- Vortex est un **outil technique** : respectez les conditions d’utilisation des sites et les **droits d’auteur** des contenus que vous téléchargez.
- Pas de garantie sur le contournement de DRM, authentification forte ou flux protégés.
- Les téléchargements longs dépendent du foreground ; le comportement en arrière-plan varie selon l’OS.
- La disponibilité des formats dépend des plateformes (URLs expirées, changements d’API) ; un **rafraîchissement** du lien est tenté automatiquement dans plusieurs cas.

---

## Stack principale

- **Flutter** · **Riverpod** · **go_router** · **Dio**
- **youtube_explode_dart** · **yt-dlp** (binaire embarqué / bootstrap)
- **extractor** (fusion média Android) · **just_audio** · **video_player**
- **sqflite** · **google_fonts** (Plus Jakarta Sans)

---

## Licence

Ce projet est publié en open source sur GitHub. Consultez le fichier **LICENSE** à la racine du dépôt pour les conditions d’utilisation, de modification et de distribution. S’il n’est pas encore présent, ajoutez une licence explicite (MIT, Apache-2.0, GPL, etc.) avant une release publique.

---

<p align="center">
  <strong>Vortex</strong> — One link. One tap.
</p>
