import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:chopper/chopper.dart';

import '../../../core/network/app_exception.dart';

/// Maps a Chopper failure to the same [AppException] hierarchy
/// `ErrorMapper` (Milestone 0.3) uses for the hand-rolled `ApiClient` —
/// one error framework across both HTTP stacks, per Milestone 1.3's
/// "shared error-display pattern" requirement. Chopper doesn't throw on
/// a non-2xx response the way Dio does, so callers check
/// `response.isSuccessful` themselves and pass the failed response here;
/// [ofException] handles the connection-level failures Chopper does
/// throw for (no route to the server at all).
abstract final class DocumentsErrorMapper {
  static AppException ofResponse(Response response) {
    final statusCode = response.statusCode;
    if (statusCode == 401) return const UnauthorizedException();
    if (statusCode >= 500) return ServerErrorException(statusCode);
    // 429: the backend rate-limits per user (e.g. 10 upload-inits per
    // hour — `services/api/app/core/rate_limit.py`) and answers
    // `{"error": {"code": "rate_limited", "message": "Too many requests
    // for upload"}}` with a `Retry-After` header. That message leaks an
    // internal route-class name and says nothing actionable, so build the
    // user-facing text from `Retry-After` instead.
    if (statusCode == 429) {
      return RequestRejectedException(
        retryMessage(int.tryParse(response.headers['retry-after'] ?? '')),
        code: 'rate_limited',
      );
    }
    // The backend's own 4xx bodies are `{"error": {"code", "message"}}`
    // with a plain-language message meant to be shown (unsupported file
    // type, file too large, upload not found, document not found) —
    // prefer that over a generic "unexpected status code".
    final rejection = _rejectionFrom(response);
    if (rejection != null) return rejection;
    if (statusCode == 404) {
      return const UnknownApiException('Not found');
    }
    return UnknownApiException('Unexpected status code $statusCode');
  }

  /// "Try again in about 12 minutes." from a `Retry-After` seconds value.
  static String retryMessage(int? retryAfterSeconds) {
    const lead = "You're doing that too often.";
    if (retryAfterSeconds == null || retryAfterSeconds <= 0) {
      return '$lead Try again in a little while.';
    }
    final minutes = (retryAfterSeconds / 60).ceil();
    if (minutes <= 1) return '$lead Try again in a minute.';
    if (minutes < 120) return '$lead Try again in about $minutes minutes.';
    return '$lead Try again in about ${(minutes / 60).ceil()} hours.';
  }

  static RequestRejectedException? _rejectionFrom(Response response) {
    try {
      final decoded = jsonDecode(response.bodyString);
      if (decoded is Map && decoded['error'] is Map) {
        final error = decoded['error'] as Map;
        final message = error['message'];
        if (message is String && message.isNotEmpty) {
          final code = error['code'];
          return RequestRejectedException(
            message,
            code: code is String ? code : null,
          );
        }
      }
    } catch (_) {
      // Not JSON (or not our error shape) — fall through to the generic
      // status-code handling.
    }
    return null;
  }

  static AppException ofException(Object error) {
    // GeneratedApiAuthInterceptor's fail-fast no-session signal carries
    // the real exception, not a generic sentinel — pass it straight
    // through, exactly like `ErrorMapper.map` does for `ApiClient`'s
    // `AuthInterceptor`. Never match on a built-in type like
    // `StateError` here: it isn't exclusively ours, so doing that once
    // mislabeled any unrelated `StateError` as a session problem (a
    // Milestone 2.1 audit finding — see `GeneratedApiAuthInterceptor`).
    if (error is AppException) return error;
    if (error is SocketException ||
        error is TimeoutException ||
        error is HttpException) {
      return const NetworkUnreachableException();
    }
    return UnknownApiException(error.toString());
  }
}
