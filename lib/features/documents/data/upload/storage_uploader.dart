import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../../core/network/app_exception.dart';
import '../../../../core/network/error_mapper.dart';
import '../../../../core/network/session_token_provider.dart';
import 'picked_upload.dart';

/// Step 2 of the upload flow: PUT the file's bytes straight to Supabase
/// Storage at the signed URL `upload-init` returned. Never through the
/// API — the whole reason this flow exists (architecture-and-spec.md §3).
abstract interface class StorageUploader {
  Future<void> put({
    required Uri uploadUrl,
    required PickedUpload file,
    required String mime,
    void Function(int sent, int total)? onProgress,
  });
}

class DioStorageUploader implements StorageUploader {
  DioStorageUploader({
    required SessionTokenProvider tokenProvider,
    required String apiKey,
    Dio? dio,
  }) : _tokenProvider = tokenProvider,
       _apiKey = apiKey,
       _dio =
           dio ??
           Dio(
             BaseOptions(
               connectTimeout: const Duration(seconds: 15),
               // A 50 MiB body on a slow mobile link legitimately takes
               // minutes; bounded so a stalled socket can't spin forever.
               sendTimeout: const Duration(minutes: 10),
               receiveTimeout: const Duration(seconds: 60),
             ),
           );

  final SessionTokenProvider _tokenProvider;
  final String _apiKey;
  final Dio _dio;

  @override
  Future<void> put({
    required Uri uploadUrl,
    required PickedUpload file,
    required String mime,
    void Function(int sent, int total)? onProgress,
  }) async {
    final token = _tokenProvider.currentAccessToken;
    if (token == null) throw const UnauthenticatedException();

    try {
      await _dio.putUri<void>(
        uploadUrl,
        // Streamed, never buffered: the file can be 50 MiB.
        data: file.openRead().map((chunk) => Uint8List.fromList(chunk)),
        onSendProgress: onProgress,
        options: Options(
          headers: {
            // Dio needs the length up front to stream a body.
            Headers.contentLengthHeader: file.sizeBytes,
            Headers.contentTypeHeader: mime,
            // Same headers the web upload page sends with this PUT.
            'apikey': _apiKey,
            'authorization': 'Bearer $token',
          },
        ),
      );
    } on DioException catch (e) {
      if (_isTooLarge(e.response)) {
        throw const RequestRejectedException(
          'File exceeds the 50MB upload limit',
          code: 'file_too_large',
        );
      }
      throw ErrorMapper.map(e);
    }
  }

  /// Supabase Storage refuses an oversized object with **HTTP 400** and a
  /// JSON body that itself says `{"statusCode": "413", "code":
  /// "EntityTooLarge"}` — found by uploading one byte over 52,428,800
  /// against the real project (matching the backend's own note that
  /// 52428801 "fails with EntityTooLarge"). The HTTP status alone is
  /// therefore not enough; recognize it by the body, and by a real 413
  /// in case a proxy in front returns one.
  static bool _isTooLarge(Response<dynamic>? response) {
    if (response == null) return false;
    if (response.statusCode == 413) return true;

    var data = response.data;
    if (data is String) {
      try {
        data = jsonDecode(data);
      } catch (_) {
        return false;
      }
    }
    if (data is Map) {
      return data['code'] == 'EntityTooLarge' ||
          data['statusCode']?.toString() == '413';
    }
    return false;
  }
}
