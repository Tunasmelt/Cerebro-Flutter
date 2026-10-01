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

Response _responseWithStatus(
  int statusCode, [
  String body = '',
  Map<String, String> headers = const {},
]) {
  return Response(
    http.Response(body, statusCode, headers: headers),
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

    test(
      "a 4xx carrying the backend's {error:{code,message}} body surfaces its "
      'own plain-language message as a RequestRejectedException',
      () {
        final mapped = DocumentsErrorMapper.ofResponse(
          _responseWithStatus(
            413,
            '{"error":{"code":"file_too_large","message":"File exceeds the 50MB upload limit"}}',
          ),
        );
        expect(mapped, isA<RequestRejectedException>());
        expect(mapped.message, 'File exceeds the 50MB upload limit');
        expect((mapped as RequestRejectedException).code, 'file_too_large');
      },
    );

    test('the same shape on a 422 and a 404 is surfaced too', () {
      final upload = DocumentsErrorMapper.ofResponse(
        _responseWithStatus(
          422,
          '{"error":{"code":"upload_not_found","message":"No uploaded object found for this document yet"}}',
        ),
      );
      final missing = DocumentsErrorMapper.ofResponse(
        _responseWithStatus(
          404,
          '{"error":{"code":"not_found","message":"Document not found"}}',
        ),
      );
      expect(upload.message, 'No uploaded object found for this document yet');
      expect(missing, isA<RequestRejectedException>());
      expect(missing.message, 'Document not found');
    });

    test('a 4xx body that is not our error shape falls back, never throws', () {
      // FastAPI's own validation errors use {"detail": [...]}, and a
      // proxy might return HTML — neither may crash the mapper.
      expect(
        DocumentsErrorMapper.ofResponse(
          _responseWithStatus(422, '{"detail":[{"msg":"field required"}]}'),
        ),
        isA<UnknownApiException>(),
      );
      expect(
        DocumentsErrorMapper.ofResponse(_responseWithStatus(400, '<html>')),
        isA<UnknownApiException>(),
      );
    });

    group('429 rate limiting (the backend limits e.g. 10 upload-inits/hour)', () {
      const body =
          '{"error":{"code":"rate_limited","message":"Too many requests for upload"}}';

      test('is a plain-language message built from Retry-After, not the '
          "server's internal route-class wording", () {
        final mapped = DocumentsErrorMapper.ofResponse(
          _responseWithStatus(429, body, {'retry-after': '1500'}),
        );
        expect(mapped, isA<RequestRejectedException>());
        expect((mapped as RequestRejectedException).code, 'rate_limited');
        expect(mapped.message, "You're doing that too often. Try again in about 25 minutes.");
        expect(mapped.message, isNot(contains('upload')));
      });

      test('rounds up to whole minutes', () {
        expect(
          DocumentsErrorMapper.ofResponse(_responseWithStatus(429, body, {'retry-after': '61'})).message,
          contains('about 2 minutes'),
        );
      });

      test('under a minute reads "a minute"', () {
        expect(
          DocumentsErrorMapper.ofResponse(_responseWithStatus(429, body, {'retry-after': '20'})).message,
          "You're doing that too often. Try again in a minute.",
        );
      });

      test('a long wait is expressed in hours', () {
        expect(
          DocumentsErrorMapper.ofResponse(_responseWithStatus(429, body, {'retry-after': '7200'})).message,
          contains('about 2 hours'),
        );
      });

      test('a missing or malformed Retry-After still gives a usable message', () {
        for (final headers in [const <String, String>{}, {'retry-after': 'soon'}]) {
          expect(
            DocumentsErrorMapper.ofResponse(_responseWithStatus(429, '', headers)).message,
            "You're doing that too often. Try again in a little while.",
          );
        }
      });
    });

    test('a 401 is still Unauthorized even if the body has an error shape', () {
      expect(
        DocumentsErrorMapper.ofResponse(
          _responseWithStatus(401, '{"error":{"code":"x","message":"nope"}}'),
        ),
        isA<UnauthorizedException>(),
      );
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
