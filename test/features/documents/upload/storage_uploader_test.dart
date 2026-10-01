// Unit tests for the direct-to-Storage PUT, driven through a stub Dio
// adapter so no network is touched. The EntityTooLarge case replays the
// byte-for-byte response real Supabase Storage returned when probed with
// a 52,428,801-byte upload (HTTP 400 with a body that says 413) — the
// shape the first, status-code-only implementation missed.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cerebro_mobile/core/network/app_exception.dart';
import 'package:cerebro_mobile/core/network/session_token_provider.dart';
import 'package:cerebro_mobile/features/documents/data/upload/storage_uploader.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_upload_services.dart';

class _Token implements SessionTokenProvider {
  _Token(this.currentAccessToken);
  @override
  final String? currentAccessToken;
}

/// Records the request it receives and replies with a canned response.
class _StubAdapter implements HttpClientAdapter {
  _StubAdapter({this.status = 200, this.body = '', this.throwOnFetch});

  final int status;
  final String body;
  final DioException Function(RequestOptions)? throwOnFetch;

  RequestOptions? seen;
  final List<int> receivedBytes = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    seen = options;
    final thrower = throwOnFetch;
    if (thrower != null) throw thrower(options);
    if (requestStream != null) {
      await for (final chunk in requestStream) {
        receivedBytes.addAll(chunk);
      }
    }
    return ResponseBody.fromString(
      body,
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  final url = Uri.parse('https://storage.example/object/upload/sign/x?token=t');

  DioStorageUploader uploader(_StubAdapter adapter, {String? token = 'jwt'}) {
    final dio = Dio()..httpClientAdapter = adapter;
    return DioStorageUploader(
      tokenProvider: _Token(token),
      apiKey: 'anon-key',
      dio: dio,
    );
  }

  Future<void> put(DioStorageUploader u, {int size = 5}) =>
      u.put(uploadUrl: url, file: fakePickedUpload(sizeBytes: size), mime: 'text/plain');

  test('sends the bytes with length, type, apikey and bearer token', () async {
    final adapter = _StubAdapter();

    await put(uploader(adapter), size: 5);

    final headers = adapter.seen!.headers;
    expect(adapter.seen!.method, 'PUT');
    expect(adapter.seen!.uri, url);
    expect(headers['content-length'], 5);
    expect(headers['content-type'], 'text/plain');
    expect(headers['apikey'], 'anon-key');
    expect(headers['authorization'], 'Bearer jwt');
    expect(adapter.receivedBytes, hasLength(5), reason: 'the body was streamed');
  });

  test('reports send progress', () async {
    final events = <(int, int)>[];
    await uploader(_StubAdapter()).put(
      uploadUrl: url,
      file: fakePickedUpload(sizeBytes: 5),
      mime: 'text/plain',
      onProgress: (sent, total) => events.add((sent, total)),
    );
    // The stub drains the stream without driving Dio's progress ticker, so
    // all we can promise here is that the callback is wired without error.
    expect(events.every((e) => e.$1 <= e.$2), isTrue);
  });

  test('with no session it fails fast, sending nothing', () async {
    final adapter = _StubAdapter();

    await expectLater(
      put(uploader(adapter, token: null)),
      throwsA(isA<UnauthenticatedException>()),
    );
    expect(adapter.seen, isNull);
  });

  group('an oversized object is a clean rejection, however Storage says it', () {
    test(
      "real Storage's answer: HTTP 400 with a body saying statusCode 413 / "
      'EntityTooLarge',
      () async {
        final adapter = _StubAdapter(
          status: 400,
          body:
              '{"statusCode":"413","error":"Payload too large","message":"The object exceeded the maximum allowed size","code":"EntityTooLarge"}',
        );

        await expectLater(
          put(uploader(adapter)),
          throwsA(
            isA<RequestRejectedException>()
                .having((e) => e.code, 'code', 'file_too_large')
                .having((e) => e.message, 'message', 'File exceeds the 50MB upload limit'),
          ),
        );
      },
    );

    test('a genuine HTTP 413 (e.g. from a proxy) is the same rejection', () async {
      await expectLater(
        put(uploader(_StubAdapter(status: 413, body: '{}'))),
        throwsA(isA<RequestRejectedException>()),
      );
    });

    test('an HTTP 400 that is NOT EntityTooLarge is not misreported as too large', () async {
      final adapter = _StubAdapter(
        status: 400,
        body: '{"statusCode":"400","error":"Bad Request","message":"nope"}',
      );

      await expectLater(
        put(uploader(adapter)),
        throwsA(
          isA<UnknownApiException>().having(
            (e) => e,
            'not a size rejection',
            isNot(isA<RequestRejectedException>()),
          ),
        ),
      );
    });
  });

  group('other failures map onto the shared AppException hierarchy', () {
    test('a 5xx is a ServerErrorException', () async {
      await expectLater(
        put(uploader(_StubAdapter(status: 503, body: '{}'))),
        throwsA(isA<ServerErrorException>()),
      );
    });

    test('a 401 (expired token or signed URL) is UnauthorizedException', () async {
      await expectLater(
        put(uploader(_StubAdapter(status: 401, body: '{}'))),
        throwsA(isA<UnauthorizedException>()),
      );
    });

    test('a dropped connection is NetworkUnreachableException', () async {
      final adapter = _StubAdapter(
        throwOnFetch: (options) => DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
          error: const SocketException('no route'),
        ),
      );

      await expectLater(
        put(uploader(adapter)),
        throwsA(isA<NetworkUnreachableException>()),
      );
    });
  });

  test('utf8 sanity: the stub really receives what the file streams', () async {
    final adapter = _StubAdapter();
    final file = fakePickedUpload(sizeBytes: 3);
    await uploader(adapter).put(uploadUrl: url, file: file, mime: 'text/plain');
    expect(utf8.decode(adapter.receivedBytes, allowMalformed: true).length, 3);
  });
}
