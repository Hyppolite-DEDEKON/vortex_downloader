import 'download_status.dart';
import 'output_profile.dart';

class DownloadTask {
  const DownloadTask({
    required this.id,
    required this.sourceUrl,
    this.downloadUrl,
    required this.fileName,
    this.localPath,
    this.mimeType,
    this.totalBytes,
    this.receivedBytes = 0,
    required this.status,
    required this.createdAt,
    this.finishedAt,
    this.lastError,
    this.supportsResume = false,
    this.downloadHeaders,
    this.thumbnailUrl,
    this.outputProfile = OutputProfile.hd,
  });

  final String id;
  final String sourceUrl;
  final String? downloadUrl;
  final String fileName;
  final String? localPath;
  final String? mimeType;
  final int? totalBytes;
  final int receivedBytes;
  final DownloadStatus status;
  final DateTime createdAt;
  final DateTime? finishedAt;
  final String? lastError;
  final bool supportsResume;
  final Map<String, String>? downloadHeaders;
  final String? thumbnailUrl;
  final OutputProfile outputProfile;

  String get effectiveDownloadUrl => downloadUrl ?? sourceUrl;

  DownloadTask copyWith({
    String? downloadUrl,
    String? fileName,
    String? localPath,
    String? mimeType,
    int? totalBytes,
    int? receivedBytes,
    DownloadStatus? status,
    DateTime? finishedAt,
    String? lastError,
    bool? supportsResume,
    Map<String, String>? downloadHeaders,
    String? thumbnailUrl,
    OutputProfile? outputProfile,
    bool clearLastError = false,
    bool clearFinishedAt = false,
  }) {
    return DownloadTask(
      id: id,
      sourceUrl: sourceUrl,
      downloadUrl: downloadUrl ?? this.downloadUrl,
      fileName: fileName ?? this.fileName,
      localPath: localPath ?? this.localPath,
      mimeType: mimeType ?? this.mimeType,
      totalBytes: totalBytes ?? this.totalBytes,
      receivedBytes: receivedBytes ?? this.receivedBytes,
      status: status ?? this.status,
      createdAt: createdAt,
      finishedAt: clearFinishedAt ? null : (finishedAt ?? this.finishedAt),
      lastError: clearLastError ? null : (lastError ?? this.lastError),
      supportsResume: supportsResume ?? this.supportsResume,
      downloadHeaders: downloadHeaders ?? this.downloadHeaders,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      outputProfile: outputProfile ?? this.outputProfile,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'source_url': sourceUrl,
        'download_url': downloadUrl,
        'file_name': fileName,
        'local_path': localPath,
        'mime_type': mimeType,
        'total_bytes': totalBytes,
        'received_bytes': receivedBytes,
        'status': status.name,
        'created_at': createdAt.millisecondsSinceEpoch,
        'finished_at': finishedAt?.millisecondsSinceEpoch,
        'last_error': lastError,
        'supports_resume': supportsResume ? 1 : 0,
        'download_headers': downloadHeaders == null || downloadHeaders!.isEmpty
            ? null
            : downloadHeaders!.entries
                .map((e) => '${e.key}\t${e.value}')
                .join('\n'),
        'thumbnail_url': thumbnailUrl,
        'output_profile': outputProfile.storageValue,
      };

  factory DownloadTask.fromMap(Map<String, Object?> m) => DownloadTask(
        id: m['id']! as String,
        sourceUrl: m['source_url']! as String,
        downloadUrl: m['download_url'] as String?,
        fileName: m['file_name']! as String,
        localPath: m['local_path'] as String?,
        mimeType: m['mime_type'] as String?,
        totalBytes: m['total_bytes'] as int?,
        receivedBytes: (m['received_bytes'] as int?) ?? 0,
        status: DownloadStatus.fromString(m['status']! as String),
        createdAt: DateTime.fromMillisecondsSinceEpoch(m['created_at']! as int),
        finishedAt: m['finished_at'] != null
            ? DateTime.fromMillisecondsSinceEpoch(m['finished_at']! as int)
            : null,
        lastError: m['last_error'] as String?,
        supportsResume: (m['supports_resume'] as int? ?? 0) == 1,
        downloadHeaders: _decodeHeaders(m['download_headers'] as String?),
        thumbnailUrl: m['thumbnail_url'] as String?,
        outputProfile: OutputProfile.fromStorage(m['output_profile'] as String?),
      );
}

Map<String, String>? _decodeHeaders(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  final out = <String, String>{};
  for (final line in raw.split('\n')) {
    final i = line.indexOf('\t');
    if (i <= 0) continue;
    out[line.substring(0, i)] = line.substring(i + 1);
  }
  return out.isEmpty ? null : out;
}
