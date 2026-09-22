// Milestone 0.4 unit test. The exit criteria's example ("a Document
// response type round-trips a JSON fixture") doesn't apply literally —
// checking the real deployed spec found every response schema in this
// API is untyped (no `response_model=` on any backend route except
// /health and a dev-only probe route); only request *bodies* are
// genuinely typed models. This tests a real generated request model
// instead: UploadInitBody, matching architecture-and-spec.md §3's
// documented upload-init call shape (filename, mime, size_bytes).
import 'package:cerebro_mobile/core/network/generated/cerebro_api.swagger.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Generated client models', () {
    test('UploadInitBody round-trips a known JSON fixture', () {
      const fixture = {
        'filename': 'financial-notes.pdf',
        'mime': 'application/pdf',
        'size_bytes': 2516582,
      };

      final model = UploadInitBody.fromJson(fixture);

      expect(model.filename, 'financial-notes.pdf');
      expect(model.mime, 'application/pdf');
      expect(model.sizeBytes, 2516582);
      expect(model.toJson(), fixture);
    });
  });
}
