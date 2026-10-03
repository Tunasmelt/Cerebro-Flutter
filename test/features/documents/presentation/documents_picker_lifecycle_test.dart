// Phase 2 audit: the picker (especially the camera) can stay open for a long
// time. If the Documents screen is gone by the time it returns — the session
// ended and the router moved on — the result must be dropped quietly, not
// thrown at a disposed widget.
import 'dart:async';

import 'package:cerebro_mobile/features/auth/data/current_user_provider.dart';
import 'package:cerebro_mobile/features/documents/data/documents_repository_provider.dart';
import 'package:cerebro_mobile/features/documents/data/upload/picked_upload.dart';
import 'package:cerebro_mobile/features/documents/data/upload/upload_controller.dart';
import 'package:cerebro_mobile/features/documents/data/upload/upload_picker.dart';
import 'package:cerebro_mobile/features/documents/presentation/documents_screen.dart';
import 'package:cerebro_mobile/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fake_documents_repository.dart';
import '../upload/fake_upload_services.dart';

class _SlowPicker implements UploadPicker {
  final Completer<PickedUpload?> result = Completer();

  @override
  Future<PickedUpload?> pick(UploadSource source) => result.future;
}

void main() {
  testWidgets(
    'a picker that returns after the screen is gone does not throw, and '
    'starts no upload',
    (tester) async {
      final log = CallLog();
      final picker = _SlowPicker();
      final showScreen = ValueNotifier<bool>(true);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserIdProvider.overrideWithValue('user-1'),
            documentsRepositoryProvider.overrideWithValue(
              FakeDocumentsRepository(),
            ),
            uploadApiProvider.overrideWithValue(FakeUploadApi(log)),
            storageUploaderProvider.overrideWithValue(FakeStorageUploader(log)),
            uploadPickerProvider.overrideWithValue(picker),
          ],
          child: MaterialApp(
            theme: AppTheme.dark,
            home: ValueListenableBuilder<bool>(
              valueListenable: showScreen,
              builder: (_, show, _) =>
                  show ? const DocumentsScreen() : const SizedBox(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('documents_add_fab')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('upload_source_camera')));
      await tester.pumpAndSettle();

      // The camera is "open"; meanwhile the screen goes away.
      showScreen.value = false;
      await tester.pumpAndSettle();

      picker.result.complete(
        fakePickedUpload(name: 'late-photo.jpg', mime: 'image/jpeg'),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        log.entries,
        isEmpty,
        reason: 'nothing may upload for a gone screen',
      );
    },
  );
}
