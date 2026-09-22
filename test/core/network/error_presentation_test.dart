import 'package:cerebro_mobile/core/network/app_exception.dart';
import 'package:cerebro_mobile/core/network/error_presentation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ErrorPresentation.of — Milestone 1.3', () {
    test('NetworkUnreachableException maps to offline with its own message', () {
      final presentation = ErrorPresentation.of(
        const NetworkUnreachableException(),
      );
      expect(presentation.kind, ErrorKind.offline);
      expect(
        presentation.message,
        "Can't reach Cerebro. Check your connection.",
      );
    });

    test('ServerErrorException maps to serverError, not offline', () {
      final presentation = ErrorPresentation.of(const ServerErrorException(503));
      expect(presentation.kind, ErrorKind.serverError);
      expect(presentation.kind, isNot(ErrorKind.offline));
      expect(
        presentation.message,
        'Something went wrong on our end. Try again shortly.',
      );
    });

    test('UnauthorizedException maps to unauthorized', () {
      final presentation = ErrorPresentation.of(const UnauthorizedException());
      expect(presentation.kind, ErrorKind.unauthorized);
      expect(presentation.message, 'Your session has expired. Sign in again.');
    });

    test('UnauthenticatedException maps to unauthenticated', () {
      final presentation = ErrorPresentation.of(const UnauthenticatedException());
      expect(presentation.kind, ErrorKind.unauthenticated);
      expect(presentation.message, 'Sign in to continue.');
    });

    test('UnknownApiException maps to unknown and passes its detail through', () {
      final presentation = ErrorPresentation.of(
        const UnknownApiException('weird one'),
      );
      expect(presentation.kind, ErrorKind.unknown);
      expect(presentation.message, 'weird one');
    });

    test('every exception type gets a distinct icon', () {
      final icons = <AppException>[
        const NetworkUnreachableException(),
        const ServerErrorException(500),
        const UnauthorizedException(),
        const UnauthenticatedException(),
        const UnknownApiException(),
      ].map((e) => ErrorPresentation.of(e).icon).toSet();

      expect(icons.length, 5);
    });

    test(
      'offline uses a different color than serverError, so the two states '
      "don't look the same at a glance",
      () {
        final offline = ErrorPresentation.of(const NetworkUnreachableException());
        final serverError = ErrorPresentation.of(const ServerErrorException(500));
        expect(offline.color, isNot(serverError.color));
      },
    );
  });
}
