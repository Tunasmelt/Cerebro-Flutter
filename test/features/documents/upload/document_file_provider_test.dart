import 'dart:convert';

import 'package:chopper/chopper.dart';
import 'package:cerebro_mobile/core/network/app_exception.dart';
import 'package:cerebro_mobile/core/network/generated/cerebro_api.swagger.dart';
import 'package:cerebro_mobile/core/network/generated_api_client_provider.dart';
import 'package:cerebro_mobile/features/auth/data/current_user_provider.dart';
import 'package:cerebro_mobile/features/documents/data/document_file_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

class _FileApi implements CerebroApi {
  _FileApi(this.status, this.body);
  final int status;
  final Map<String, dynamic> body;
  int calls = 0;

  @override
  Future<Response> apiV1DocumentsDocumentIdOriginalGet({
    required String? documentId,
  }) async {
    calls++;
    return Response(http.Response(jsonEncode(body), status), body);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('signed out viewer cannot request a download URL', () async {
    final api = _FileApi(200, {'url': 'https://example.invalid/original'});
    final container = ProviderContainer(
      overrides: [
        currentUserIdProvider.overrideWithValue(null),
        generatedApiClientProvider.overrideWithValue(api),
      ],
    );
    addTearDown(container.dispose);
    await expectLater(
      container.read(documentFileProvider('doc').future),
      throwsA(isA<UnauthorizedException>()),
    );
    expect(api.calls, 0);
  });

  test('sealed backend rejection preserves its typed error', () async {
    final api = _FileApi(423, {
      'error': {'code': 'document_sealed', 'message': 'Document is sealed'},
    });
    final container = ProviderContainer(
      overrides: [
        currentUserIdProvider.overrideWithValue('owner'),
        generatedApiClientProvider.overrideWithValue(api),
      ],
    );
    addTearDown(container.dispose);
    await expectLater(
      container.read(documentFileProvider('doc').future),
      throwsA(
        isA<RequestRejectedException>().having(
          (error) => error.code,
          'code',
          'document_sealed',
        ),
      ),
    );
    expect(api.calls, 1);
  });

  test('an insecure file URL is rejected before downloading bytes', () async {
    final api = _FileApi(200, {
      'url': 'http://example.invalid/original?token=private',
    });
    final container = ProviderContainer(
      overrides: [
        currentUserIdProvider.overrideWithValue('owner'),
        generatedApiClientProvider.overrideWithValue(api),
      ],
    );
    addTearDown(container.dispose);
    await expectLater(
      container.read(documentFileProvider('doc').future),
      throwsA(
        isA<UnknownApiException>().having(
          (error) => error.message.contains('token='),
          'contains URL',
          false,
        ),
      ),
    );
  });
}
