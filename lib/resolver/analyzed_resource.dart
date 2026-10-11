class AnalyzedResource {
  const AnalyzedResource({
    required this.finalUrl,
    required this.fileName,
    this.mimeType,
    this.totalBytes,
    this.supportsResume = false,
    required this.resolverName,
    this.contentKind = ContentKind.file,
    this.downloadHeaders,
    this.thumbnailUrl,
  });

  final String finalUrl;
  final String fileName;
  final String? mimeType;
  final int? totalBytes;
  final bool supportsResume;
  final String resolverName;
  final ContentKind contentKind;

  /// En-têtes HTTP pour récupérer [finalUrl] (Referer, User-Agent…).
  final Map<String, String>? downloadHeaders;

  /// Vignette distante (couverture vidéo, preview…).
  final String? thumbnailUrl;
}

/// Normalise une URL de miniature renvoyée par un extracteur.
String? normalizeThumbnailUrl(String? raw) {
  final url = raw?.trim();
  if (url == null || url.isEmpty || url == 'null') return null;
  if (!url.startsWith('http')) return null;
  return url;
}

enum ContentKind { file, video, audio, image, document, archive, webpage, unknown }

ContentKind kindFromMime(String? mime) {
  if (mime == null) return ContentKind.unknown;
  if (mime.startsWith('video/')) return ContentKind.video;
  if (mime.startsWith('audio/')) return ContentKind.audio;
  if (mime.startsWith('image/')) return ContentKind.image;
  if (mime.contains('pdf') || mime.startsWith('text/')) return ContentKind.document;
  if (mime.contains('zip') || mime.contains('archive')) return ContentKind.archive;
  return ContentKind.file;
}
