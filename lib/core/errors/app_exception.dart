sealed class AppException implements Exception {
  const AppException(this.message);
  final String message;
  @override
  String toString() => message;
}

final class InvalidUrlException extends AppException {
  const InvalidUrlException(super.message);
}

final class SecurityBlockedException extends AppException {
  const SecurityBlockedException(super.message);
}

final class NetworkException extends AppException {
  const NetworkException(super.message);
}

final class ResolveException extends AppException {
  const ResolveException(super.message);
}

final class DownloadException extends AppException {
  const DownloadException(super.message);
}
