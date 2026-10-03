import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

import '../../../core/network/app_exception.dart';
import '../../../core/network/error_mapper.dart';
import '../../../core/sse/sse_parser.dart';
import '../../documents/data/documents_error_mapper.dart';
import 'chat_stream_event.dart';

/// Streams one chat turn: the answer to [query] in session [sessionId], as
/// typed events, ending with [ChatDone] or [ChatError]. Cancelling the
/// subscription closes the connection.
///
/// Failures that happen *before* the first event (no network, 401, 404, 429,
/// 5xx) and a stream that dies *without* a terminal event (the backend's own
/// docs call this the "failed vs. still working?" ambiguity) arrive as stream
/// errors carrying an `AppException`. A failure the server *reports* — an
/// `error` event — is just a [ChatError] event, because it is part of the
/// protocol.
abstract interface class ChatStreamApi {
  Stream<ChatStreamEvent> stream({
    required String sessionId,
    required String query,
  });
}

class DioChatStreamClient implements ChatStreamApi {
  DioChatStreamClient(
    this._dio, {
    this.idleTimeout = const Duration(seconds: 90),
  });

  final Dio _dio;

  /// Longest the connection may stay completely silent before the turn is
  /// treated as dropped. The server sends `heartbeat`s while retrieving and
  /// tokens while generating, so silence this long is not "thinking".
  final Duration idleTimeout;

  @override
  Stream<ChatStreamEvent> stream({
    required String sessionId,
    required String query,
  }) {
    final cancelToken = CancelToken();
    StreamSubscription<dynamic>? subscription;
    Timer? idle;
    var finished = false;
    late final StreamController<ChatStreamEvent> controller;

    void finish([AppException? error]) {
      if (finished) return;
      finished = true;
      idle?.cancel();
      subscription?.cancel();
      cancelToken.cancel();
      if (controller.isClosed) return;
      if (error != null) controller.addError(error);
      controller.close();
    }

    AppException interrupted() => const UnknownApiException(
      'The connection dropped before the answer finished.',
    );

    void armIdleTimer() {
      idle?.cancel();
      idle = Timer(idleTimeout, () => finish(interrupted()));
    }

    Future<void> start() async {
      final Response<ResponseBody> response;
      try {
        armIdleTimer();
        response = await _dio.post<ResponseBody>(
          '/api/v1/chat/sessions/$sessionId/stream',
          data: {'query': query},
          cancelToken: cancelToken,
          options: Options(
            responseType: ResponseType.stream,
            headers: {'Accept': 'text/event-stream'},
            // The idle timer above is the timeout; a long answer must not be
            // cut by the client-wide 60 s receive timeout.
            receiveTimeout: Duration.zero,
          ),
        );
      } on DioException catch (e) {
        if (finished || CancelToken.isCancel(e)) return;
        finish(await _failure(e));
        return;
      } catch (_) {
        if (!finished) finish(const UnknownApiException());
        return;
      }
      if (finished) return;

      final bytes = response.data!.stream.map((chunk) {
        armIdleTimer(); // any bytes at all — even a comment — mean alive
        return chunk;
      });

      subscription = parseSse(bytes).listen(
        (sse) {
          if (finished) return;
          final ChatStreamEvent? event;
          try {
            event = chatEventFromSse(sse);
          } on FormatException {
            finish(
              const UnknownApiException(
                'Received an unexpected response from the server.',
              ),
            );
            return;
          }
          if (event == null) return; // an event this client doesn't know
          controller.add(event);
          if (event is ChatDone || event is ChatError) finish();
        },
        onError: (Object error) {
          if (finished) return;
          finish(
            error is DioException ||
                    error is SocketException ||
                    error is HttpException ||
                    error is TimeoutException
                ? interrupted()
                : const UnknownApiException(),
          );
        },
        onDone: () {
          // The body ended. Without a done/error first, the turn was cut off.
          if (!finished) finish(interrupted());
        },
      );
    }

    controller = StreamController<ChatStreamEvent>(
      onListen: () {
        start();
      },
      onCancel: () {
        finished = true;
        idle?.cancel();
        subscription?.cancel();
        cancelToken.cancel();
      },
    );
    return controller.stream;
  }

  /// Maps a failure to open the stream. A streamed response's error body is
  /// itself a stream, so it is read and decoded here.
  Future<AppException> _failure(DioException e) async {
    final response = e.response;
    if (response == null) return ErrorMapper.map(e);

    final status = response.statusCode ?? 0;
    final (code, message) = await _errorBody(response);

    if (status == 401) return const UnauthorizedException();
    if (status >= 500) return ServerErrorException(status);
    if (status == 429) {
      final retryAfter = int.tryParse(
        response.headers.value('retry-after') ?? '',
      );
      return RequestRejectedException(
        DocumentsErrorMapper.retryMessage(retryAfter),
        code: 'rate_limited',
      );
    }
    if (status == 404) {
      return RequestRejectedException(
        message ?? 'That conversation no longer exists.',
        code: code ?? 'not_found',
      );
    }
    if (message != null) return RequestRejectedException(message, code: code);
    return UnknownApiException('Unexpected status code $status');
  }

  Future<(String?, String?)> _errorBody(Response<dynamic> response) async {
    try {
      final data = response.data;
      final List<int> bytes;
      if (data is ResponseBody) {
        bytes = [];
        await for (final chunk in data.stream) {
          bytes.addAll(chunk);
          if (bytes.length > 64 * 1024) break;
        }
      } else if (data is String) {
        bytes = utf8.encode(data);
      } else {
        return (null, null);
      }
      final decoded = jsonDecode(utf8.decode(bytes, allowMalformed: true));
      final error = decoded is Map ? decoded['error'] : null;
      if (error is Map) {
        return (
          error['code'] is String ? error['code'] as String : null,
          error['message'] is String ? error['message'] as String : null,
        );
      }
    } catch (_) {
      // Not JSON: fall through to "no detail".
    }
    return (null, null);
  }
}
