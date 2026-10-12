import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client_provider.dart';
import '../../../core/network/app_exception.dart';
import '../../auth/data/current_user_provider.dart';

final citationEvidenceProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>((ref, chunkId) async {
      if (ref.watch(currentUserIdProvider) == null) {
        throw const UnauthorizedException();
      }
      final cancel = CancelToken();
      ref.onDispose(() => cancel.cancel());
      try {
        final response = await ref
            .watch(apiClientProvider)
            .dio
            .get<Map<String, dynamic>>(
              '/api/v1/chunks/${Uri.encodeComponent(chunkId)}/evidence',
              cancelToken: cancel,
            );
        final data = response.data;
        if (data == null ||
            data['chunk_id'] != chunkId ||
            data['document'] is! Map ||
            (data['document'] as Map)['id'] is! String) {
          throw const UnknownApiException(
            'The server returned invalid source evidence.',
          );
        }
        return response.data!;
      } on DioException catch (e) {
        if (e.response?.statusCode == 423) {
          throw const RequestRejectedException(
            'This source is sealed. Open Document details to unlock it.',
            code: 'document_sealed',
          );
        }
        if (e.response?.statusCode == 404) {
          throw const RequestRejectedException(
            'This source excerpt is no longer available.',
            code: 'not_found',
          );
        }
        throw const UnknownApiException(
          'Could not load source evidence. Please retry.',
        );
      }
    });

// Signed URLs authorize themselves. Use a separate client without SDK headers.
final evidenceImageProvider = FutureProvider.autoDispose
    .family<Uint8List, String>((ref, url) async {
      if (ref.watch(currentUserIdProvider) == null) {
        throw const UnauthorizedException();
      }
      final uri = Uri.tryParse(url);
      if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
        throw const UnknownApiException();
      }
      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 60),
        ),
      );
      final cancel = CancelToken();
      ref.onDispose(() {
        cancel.cancel();
        dio.close(force: true);
      });
      try {
        final response = await dio.get<ResponseBody>(
          url,
          cancelToken: cancel,
          options: Options(
            responseType: ResponseType.stream,
            followRedirects: false,
          ),
        );
        final bytes = BytesBuilder(copy: false);
        await for (final chunk in response.data!.stream) {
          if (bytes.length + chunk.length > 50 * 1024 * 1024) {
            throw const UnknownApiException();
          }
          bytes.add(chunk);
        }
        return bytes.takeBytes();
      } catch (_) {
        throw const UnknownApiException('Could not load the source image.');
      } finally {
        dio.close(force: true);
      }
    });
