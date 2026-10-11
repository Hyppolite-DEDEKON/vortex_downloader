import 'dart:io';

import 'package:flutter/material.dart';

import '../../resolver/analyzed_resource.dart';

/// Vignette pour listes (Actifs, Fichiers) : fichier local, URL distante ou icône.
class MediaThumbnail extends StatelessWidget {
  const MediaThumbnail({
    super.key,
    this.localPath,
    this.thumbnailUrl,
    this.previewUrl,
    this.httpHeaders,
    this.mimeType,
    this.size = 48,
    this.borderRadius = 10,
  });

  final String? localPath;
  final String? thumbnailUrl;

  /// Secours (ex. URL directe d’une image TikTok) si [thumbnailUrl] est vide.
  final String? previewUrl;
  final Map<String, String>? httpHeaders;
  final String? mimeType;
  final double size;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final kind = kindFromMime(mimeType);
    final localImage = _localImageFile(localPath, kind);
    final expand = !size.isFinite;
    final w = expand ? double.infinity : size;
    final h = expand ? double.infinity : size;

    Widget child;
    if (localImage != null) {
      child = Image.file(
        localImage,
        width: w,
        height: h,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _iconFallback(theme, kind, expand: expand),
      );
    } else {
      final url = normalizeThumbnailUrl(thumbnailUrl) ??
          (kind == ContentKind.image ? normalizeThumbnailUrl(previewUrl) : null);
      if (url != null) {
        child = Image.network(
          url,
          headers: httpHeaders,
          width: w,
          height: h,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _iconFallback(theme, kind, expand: expand),
          loadingBuilder: (ctx, img, progress) {
            if (progress == null) return img;
            return _iconFallback(theme, kind, expand: expand);
          },
        );
      } else {
        child = _iconFallback(theme, kind, expand: expand);
      }
    }

    final framed = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: child,
    );
    if (size.isFinite) {
      return SizedBox(width: size, height: size, child: framed);
    }
    return framed;
  }

  static File? _localImageFile(String? path, ContentKind kind) {
    if (path == null || path.isEmpty) return null;
    if (kind != ContentKind.image) return null;
    final file = File(path);
    if (!file.existsSync()) return null;
    return file;
  }

  Widget _iconFallback(ThemeData theme, ContentKind kind, {required bool expand}) {
    final icon = switch (kind) {
      ContentKind.video => Icons.movie_outlined,
      ContentKind.audio => Icons.audiotrack_outlined,
      ContentKind.image => Icons.image_outlined,
      ContentKind.document => Icons.picture_as_pdf_outlined,
      _ => Icons.insert_drive_file_outlined,
    };

    final iconSize = expand ? 32.0 : size * 0.48;

    return ColoredBox(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.65),
      child: Center(
        child: Icon(icon, size: iconSize, color: theme.colorScheme.onSurfaceVariant),
      ),
    );
  }
}
