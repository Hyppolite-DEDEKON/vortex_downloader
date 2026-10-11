import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../downloads/domain/download_task.dart';
import 'vortex_media_player_screen.dart';

abstract final class LocalPlayback {
  static const _videoExt = {'.mp4', '.m4v', '.webm', '.mkv', '.mov'};
  static const _audioExt = {'.mp3', '.m4a', '.aac', '.wav', '.ogg', '.opus', '.flac'};

  static bool canPlayInApp(DownloadTask task) {
    final path = task.localPath;
    if (path == null || path.isEmpty) return false;
    return kindFor(task) != LocalMediaKind.other;
  }

  static LocalMediaKind kindFor(DownloadTask task) {
    final mime = task.mimeType?.toLowerCase() ?? '';
    if (mime.startsWith('video/')) return LocalMediaKind.video;
    if (mime.startsWith('audio/')) return LocalMediaKind.audio;
    final ext = p.extension(task.localPath ?? '').toLowerCase();
    if (_videoExt.contains(ext)) return LocalMediaKind.video;
    if (_audioExt.contains(ext)) return LocalMediaKind.audio;
    return LocalMediaKind.other;
  }

  /// Ouvre le lecteur intégré. Retourne `true` s’il faut ouvrir le fichier
  /// avec une application externe (échec ou choix utilisateur).
  static Future<bool> open(BuildContext context, DownloadTask task) async {
    final path = task.localPath;
    if (path == null || !await File(path).exists()) {
      if (!context.mounted) return true;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fichier introuvable sur l’appareil.')),
      );
      return true;
    }
    final kind = kindFor(task);
    if (kind == LocalMediaKind.other) return true;

    if (!context.mounted) return false;
    final useExternal = await Navigator.of(context, rootNavigator: true).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: kind == LocalMediaKind.video,
        builder: (_) => VortexMediaPlayerScreen(
          filePath: path,
          title: task.fileName,
          kind: kind,
          thumbnailUrl: task.thumbnailUrl,
        ),
      ),
    );
    return useExternal == true;
  }
}

enum LocalMediaKind { video, audio, other }
