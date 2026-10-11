enum DownloadStatus {
  queued,
  analyzing,
  downloading,
  converting,
  paused,
  completed,
  failed,
  cancelled;

  static DownloadStatus fromString(String v) =>
      DownloadStatus.values.firstWhere((s) => s.name == v, orElse: () => failed);

  bool get isActive =>
      this == queued ||
      this == analyzing ||
      this == downloading ||
      this == converting;
}
