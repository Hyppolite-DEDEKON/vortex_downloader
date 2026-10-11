class FormatUtils {
  FormatUtils._();

  static String formatBytes(int? bytes) {
    if (bytes == null) return '—';
    if (bytes < 1024) return '$bytes o';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} Ko';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} Mo';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} Go';
  }

  static String formatSpeed(int bytesPerSecond) {
    if (bytesPerSecond <= 0) return '—';
    return '${formatBytes(bytesPerSecond)}/s';
  }

  static String formatEta(int? seconds) {
    if (seconds == null || seconds < 0) return '—';
    if (seconds < 60) return '${seconds}s';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    if (m < 60) return '${m}m ${s}s';
    return '${m ~/ 60}h ${m % 60}m';
  }

  static String formatDate(DateTime d) {
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    return '$dd/$mm/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  static int? parseContentLength(String? v) =>
      v == null ? null : int.tryParse(v);
}
