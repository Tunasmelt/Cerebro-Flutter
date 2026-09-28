import 'package:cerebro_mobile/features/auth/data/auth_error_mapper.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

void main() {
  group('mapAuthException', () {
    test('maps invalid credentials', () {
      expect(
        mapAuthException(
          const supabase.AuthException(
            'Invalid login credentials',
            code: 'invalid_credentials',
          ),
        ).message,
        'Incorrect email or password.',
      );
    });

    test(
      'maps the real over_email_send_rate_limit response to a rate-limit '
      'message, not "Enter a valid email address."',
      () {
        // The message contains "email", which the invalid-email branch
        // used to claim — misreporting a Supabase rate limit as a typo.
        final mapped = mapAuthException(
          const supabase.AuthException(
            'email rate limit exceeded',
            statusCode: '429',
            code: 'over_email_send_rate_limit',
          ),
        );
        expect(mapped.message, 'Too many attempts. Wait a few minutes and try again.');
      },
    );

    test('maps a rate limit identified only by message text', () {
      expect(
        mapAuthException(const supabase.AuthException('Email rate limit exceeded'))
            .message,
        'Too many attempts. Wait a few minutes and try again.',
      );
    });

    test('a genuinely invalid email is still reported as such', () {
      expect(
        mapAuthException(
          const supabase.AuthException(
            'Unable to validate email address: invalid format',
            code: 'email_address_invalid',
          ),
        ).message,
        'Enter a valid email address.',
      );
    });

    test('falls back to a generic message, never the raw text', () {
      final mapped = mapAuthException(
        const supabase.AuthException('database exploded at row 7'),
      );
      expect(mapped.message, 'Something went wrong. Try again.');
    });
  });

  group('mapAuthStreamError', () {
    test('a missing PKCE code verifier is reported as a bad link', () {
      expect(
        mapAuthStreamError(
          const supabase.AuthException(
            'Code verifier could not be found in local storage.',
          ),
        ).message,
        'That confirmation link is invalid or has expired. Request a new one.',
      );
    });

    test('an expired one-time code is reported as a bad link', () {
      expect(
        mapAuthStreamError(
          const supabase.AuthException(
            'Email link is invalid or has expired',
            code: 'otp_expired',
          ),
        ).message,
        'That confirmation link is invalid or has expired. Request a new one.',
      );
    });

    test('a network failure is not mislabelled as a bad link', () {
      expect(
        mapAuthStreamError(
          supabase.AuthRetryableFetchException(message: 'socket closed'),
        ).message,
        "Can't reach Cerebro. Check your connection.",
      );
    });

    test('a non-auth error gets the generic message', () {
      expect(
        mapAuthStreamError(StateError('boom')).message,
        'Something went wrong. Try again.',
      );
    });
  });
}
