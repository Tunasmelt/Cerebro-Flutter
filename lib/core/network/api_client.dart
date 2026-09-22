import 'package:dio/dio.dart';

import 'app_exception.dart';
import 'auth_interceptor.dart';
import 'error_mapper.dart';
import 'session_token_provider.dart';

/// The deployed FastAPI service, per
/// `Cerebro 2.0/.env.example` → `API_BASE_URL`. Mobile calls this
/// directly — no BFF/proxy layer, per architecture-and-spec.md §1.
const String kDefaultApiBaseUrl = 'https://cerebro-api-d47y.onrender.com';

/// The single HTTP client instance for the app. One [Dio] instance,
/// constructed once and reused — never instantiated per call, per
/// flutter-rules.md's networking rule.
class ApiClient {
  ApiClient({
    required SessionTokenProvider tokenProvider,
    String baseUrl = kDefaultApiBaseUrl,
    Dio? dio,
  }) : _dio =
           dio ??
           Dio(
             BaseOptions(
               baseUrl: baseUrl,
               connectTimeout: const Duration(seconds: 15),
               receiveTimeout: const Duration(seconds: 30),
             ),
           ) {
    _dio.interceptors.add(AuthInterceptor(tokenProvider));
  }

  final Dio _dio;

  /// Exposed for endpoints that need direct access (e.g. the generated
  /// typed client in Milestone 0.4 will wrap this same instance rather
  /// than construct its own).
  Dio get dio => _dio;

  /// GET request, mapping any failure to a typed [AppException]. Never
  /// lets a raw [DioException] escape this class.
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      return await _dio.get<T>(path, queryParameters: queryParameters);
    } on DioException catch (e) {
      throw ErrorMapper.map(e);
    }
  }

  /// Calls the deployed backend's `/health` endpoint. Used by
  /// Milestone 0.3's functional test — a real request against the real
  /// Render deployment, not a mock.
  Future<Response<Map<String, dynamic>>> health() =>
      get<Map<String, dynamic>>('/health');
}
