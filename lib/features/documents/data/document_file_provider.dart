import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/app_exception.dart';
import '../../../core/network/generated_api_client_provider.dart';
import '../../auth/data/current_user_provider.dart';
import 'documents_error_mapper.dart';
import 'upload/upload_constraints.dart';

/// Original bytes stay in memory and are discarded when the viewer closes.
final documentFileProvider = FutureProvider.autoDispose
    .family<Uint8List, String>((ref, id) async {
      if (ref.watch(currentUserIdProvider) == null) {
        throw const UnauthorizedException();
      }
      final cancel = CancelToken();
      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 60),
        ),
      );
      ref.onDispose(() {
        cancel.cancel();
        dio.close(force: true);
      });
      try {
        final response = await ref
            .watch(generatedApiClientProvider)
            .apiV1DocumentsDocumentIdOriginalGet(documentId: id);
        if (!response.isSuccessful) {
          throw DocumentsErrorMapper.ofResponse(response);
        }
        if (cancel.isCancelled) throw const UnauthorizedException();
        final url = Uri.parse((response.body as Map)['url'] as String);
        if (url.scheme != 'https' || url.host.isEmpty) {
          throw const UnknownApiException();
        }
        // Signed Storage URLs authorize themselves; never forward the SDK JWT.
        final download = await dio.get<ResponseBody>(
          url.toString(),
          cancelToken: cancel,
          options: Options(
            responseType: ResponseType.stream,
            followRedirects: false,
          ),
        );
        final bytes = BytesBuilder(copy: false);
        await for (final chunk in download.data!.stream) {
          if (bytes.length + chunk.length > kMaxUploadBytes) {
            throw const RequestRejectedException(
              'The file exceeds the viewing limit.',
            );
          }
          bytes.add(chunk);
        }
        return bytes.takeBytes();
      } on AppException {
        rethrow;
      } catch (_) {
        // Never expose a signed URL through transport exception text.
        throw const UnknownApiException(
          'Could not load this file. Please try again.',
        );
      } finally {
        dio.close(force: true);
      }
    });
