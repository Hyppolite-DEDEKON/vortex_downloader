class DownloadLiveMetrics {
  const DownloadLiveMetrics({
    this.bytesPerSecond = 0,
    this.etaSeconds,
  });

  final int bytesPerSecond;
  final int? etaSeconds;
}
