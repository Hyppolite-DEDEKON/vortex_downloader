import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vortex/core/utils/link_access_messages.dart';

void main() {
  test('403 et 410 → message expiration', () {
    expect(
      LinkAccessMessages.resolveFailureForHttpStatus(403),
      LinkAccessMessages.expiredAccess,
    );
    expect(
      LinkAccessMessages.resolveFailureForHttpStatus(410),
      LinkAccessMessages.expiredAccess,
    );
  });

  test('Dio 403 → message lisible', () {
    final msg = LinkAccessMessages.userMessageForDio(
      DioException(
        requestOptions: RequestOptions(path: '/'),
        response: Response(
          requestOptions: RequestOptions(path: '/'),
          statusCode: 403,
        ),
        type: DioExceptionType.badResponse,
      ),
    );
    expect(msg, LinkAccessMessages.expiredAccess);
  });

  test('shouldReanalyzeForRetry détecte expiration', () {
    expect(
      LinkAccessMessages.shouldReanalyzeForRetry(
        LinkAccessMessages.expiredAccess,
      ),
      isTrue,
    );
    expect(LinkAccessMessages.shouldReanalyzeForRetry('Accès refusé (403).'), isTrue);
    expect(LinkAccessMessages.shouldReanalyzeForRetry('Espace disque plein'), isFalse);
  });
}
