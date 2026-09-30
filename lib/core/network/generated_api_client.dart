import 'dart:async';

import 'package:chopper/chopper.dart';

import 'api_client.dart' show kDefaultApiBaseUrl;
import 'app_exception.dart';
import 'generated/cerebro_api.swagger.dart';
import 'session_token_provider.dart';

/// Attaches the Supabase session JWT to every request made through the
/// generated (Chopper-based) client — the same policy as
/// `AuthInterceptor` for the hand-rolled `ApiClient`, reimplemented for
/// Chopper's interceptor API since the two HTTP stacks don't share one.
/// Fail-fast: throwing here (rather than calling `chain.proceed`) aborts
/// the request before it's sent when there's no session, exactly like
/// `AuthInterceptor`'s no-session policy.
///
/// Throws the real [UnauthenticatedException] directly, not a generic
/// `StateError` — a Milestone 2.1 audit finding: a generic sentinel type
/// isn't exclusively ours, so a mapper matching on it (as
/// `DocumentsErrorMapper.ofException` briefly did) would mislabel any
/// unrelated `StateError` from deep inside Chopper/http as a session
/// problem, masking the real one. `AuthInterceptor`/`ErrorMapper`
/// (Milestone 0.3) already got this right by carrying the real typed
/// exception through — this now matches that pattern instead of
/// reinventing a weaker one.
class GeneratedApiAuthInterceptor implements Interceptor {
  const GeneratedApiAuthInterceptor(this._tokenProvider);

  final SessionTokenProvider _tokenProvider;

  @override
  FutureOr<Response<BodyType>> intercept<BodyType>(Chain<BodyType> chain) {
    final token = _tokenProvider.currentAccessToken;
    if (token == null) {
      throw const UnauthenticatedException();
    }
    return chain.proceed(
      applyHeader(chain.request, 'Authorization', 'Bearer $token'),
    );
  }
}

/// Builds the generated client against the same deployed backend
/// `ApiClient` uses. A separate Chopper `ChopperClient` instance, not a
/// shared one with `ApiClient`'s Dio — the two HTTP stacks exist in
/// parallel since Milestone 0.4 generated this client independently of
/// Milestone 0.3's hand-rolled one.
CerebroApi buildGeneratedApiClient({
  required SessionTokenProvider tokenProvider,
  String baseUrl = kDefaultApiBaseUrl,
}) {
  return CerebroApi.create(
    baseUrl: Uri.parse(baseUrl),
    interceptors: [GeneratedApiAuthInterceptor(tokenProvider)],
  );
}
