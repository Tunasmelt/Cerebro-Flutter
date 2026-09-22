// Milestone 0.4 functional test: the generated client, calling the real
// deployed Render service — no mocking. Requires internet access to run.
import 'package:cerebro_mobile/core/network/api_client.dart';
import 'package:cerebro_mobile/core/network/generated/cerebro_api.swagger.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'the generated client calls the real /health endpoint and deserializes it',
    () async {
      final client = CerebroApi.create(
        baseUrl: Uri.parse(kDefaultApiBaseUrl),
      );

      final response = await client.healthGet();

      expect(response.isSuccessful, isTrue);
      final body = response.body as Map<String, dynamic>;
      expect(body['status'], 'ok');
    },
    // Render free-tier instances cold-start; give it room.
    timeout: const Timeout(Duration(seconds: 60)),
  );
}
