// Unit tests for DocumentsErrorMapper — added by the Milestone 2.1 audit,
// which found this mapper had zero direct test coverage despite being
// new logic (the widget/repository tests only exercised it indirectly
// through a fake that throws AppExceptions directly, bypassing the
// mapper entirely).
import 'dart:async';
import 'dart:io';

import 'package:cerebro_mobile/core/network/app_exception.dart';
import 'package:cerebro_mobile/features/documents/data/documents_error_mapper.dart';
import 'package:chopper/chopper.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

Response _responseWithStatus(int statusCode) {
  return Response(
    http.Response('', statusCode),
    null,
  );
}

void main() {
  group('DocumentsErrorMapper.ofResponse', () {
    test('401 maps to UnauthorizedException', () {
      expect(
        DocumentsErrorMapper.ofResponse(_responseWithStatus(401)),
        isA<UnauthorizedException>(),
      );
    });

    test('500 and other 5xx map to ServerErrorException with the real code', () {
      final mapped = DocumentsErrorMapper.ofResponse(_responseWithStatus(503));
      expect(mapped, isA<ServerErrorException>());
      expect((mapped as ServerErrorException).statusCode, 503);
    });

    test('404 maps to a not-found UnknownApiException', () {
      final mapped = DocumentsErrorMapper.ofResponse(_responseWithStatus(404));
      expect(mapped, isA<UnknownApiException>());
      expect(mapped.message, 'Not found');
    });

    test('an unexpected status code falls back to a generic UnknownApiException', () {
      final mapped = DocumentsErrorMapper.ofResponse(_responseWithStatus(418));
      expect(mapped, isA<UnknownApiException>());
      expect(mapped.message, contains('418'));
    });
  });

  group('DocumentsErrorMapper.ofException', () {
    test(
      "GeneratedApiAuthInterceptor's real UnauthenticatedException passes "
      'through unchanged',
      () {
        const original = UnauthenticatedException();
        expect(DocumentsErrorMapper.ofException(original), same(original));
      },
    );

    test('any AppException passes through unchanged, not just UnauthenticatedException', () {
      const original = ServerErrorException(502);
      expect(DocumentsErrorMapper.ofException(original), same(original));
    });

    test(
      'an unrelated StateError (not the auth sentinel) is NOT mislabeled as '
      'a session problem — the exact bug the audit found and this guards '
      'against regressing',
      () {
        final unrelated = StateError('Bad state: No element');
        final mapped = DocumentsErrorMapper.ofException(unrelated);

        expect(mapped, isNot(isA<UnauthenticatedException>()));
        expect(mapped, isA<UnknownApiException>());
      },
    );

    test('a socket-level failure maps to NetworkUnreachableException', () {
      expect(
        DocumentsErrorMapper.ofException(const SocketException('no route')),
        isA<NetworkUnreachableException>(),
      );
    });

    test('a timeout maps to NetworkUnreachableException', () {
      expect(
        DocumentsErrorMapper.ofException(TimeoutException('too slow')),
        isA<NetworkUnreachableException>(),
      );
    });

    test('anything else falls back to UnknownApiException, never a crash', () {
      expect(
        DocumentsErrorMapper.ofException(FormatException('bad json')),
        isA<UnknownApiException>(),
      );
    });
  });
}
