import 'dart:async';

import 'package:cerebro_mobile/core/network/app_exception.dart';
import 'package:cerebro_mobile/features/auth/data/current_user_provider.dart';
import 'package:cerebro_mobile/features/documents/data/documents_repository_provider.dart';
import 'package:cerebro_mobile/features/documents/data/upload/upload_controller.dart';
import 'package:cerebro_mobile/features/documents/data/upload/upload_picker.dart';
import 'package:cerebro_mobile/features/documents/presentation/documents_screen.dart';
import 'package:cerebro_mobile/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fake_documents_repository.dart';
import '../upload/fake_upload_services.dart';

void main() {
  late CallLog log;
  late FakeUploadApi api;
  late FakeStorageUploader storage;
  late FakeUploadPicker picker;

  setUp(() {
    log = CallLog();
    api = FakeUploadApi(log);
    storage = FakeStorageUploader(log);
    picker = FakeUploadPicker()..result = fakePickedUpload();
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserIdProvider.overrideWithValue('user-1'),
          documentsRepositoryProvider.overrideWithValue(
            FakeDocumentsRepository(),
          ),
          uploadApiProvider.overrideWithValue(api),
          storageUploaderProvider.overrideWithValue(storage),
          uploadPickerProvider.overrideWithValue(picker),
        ],
        child: MaterialApp(
          theme: AppTheme.dark,
          home: const DocumentsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openSheet(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('documents_add_fab')));
    await tester.pumpAndSettle();
  }

  testWidgets('the Add button opens the source sheet with all three sources', (
    tester,
  ) async {
    await pumpScreen(tester);
    await openSheet(tester);

    expect(find.byKey(const Key('upload_source_file')), findsOneWidget);
    expect(find.byKey(const Key('upload_source_photos')), findsOneWidget);
    expect(find.byKey(const Key('upload_source_camera')), findsOneWidget);
    expect(find.textContaining('up to 50MB'), findsOneWidget);
  });

  for (final (key, source) in [
    ('upload_source_file', UploadSource.file),
    ('upload_source_photos', UploadSource.photoLibrary),
    ('upload_source_camera', UploadSource.camera),
  ]) {
    testWidgets('choosing $key asks the picker for $source', (tester) async {
      await pumpScreen(tester);
      await openSheet(tester);

      await tester.tap(find.byKey(Key(key)));
      await tester.pumpAndSettle();

      expect(picker.requested, [source]);
    });
  }

  testWidgets('dismissing the sheet without choosing asks for nothing', (
    tester,
  ) async {
    await pumpScreen(tester);
    await openSheet(tester);

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(picker.requested, isEmpty);
    expect(find.byKey(const Key('upload_list')), findsNothing);
  });

  testWidgets('backing out of the picker starts no upload', (tester) async {
    picker.result = null;
    await pumpScreen(tester);
    await openSheet(tester);

    await tester.tap(find.byKey(const Key('upload_source_camera')));
    await tester.pumpAndSettle();

    expect(log.entries, isEmpty);
    expect(find.byKey(const Key('upload_list')), findsNothing);
  });

  testWidgets(
    'a denied camera permission shows its plain-language message, not a crash',
    (tester) async {
      picker.error = const UploadPickException(
        'Camera access is turned off. Enable it in Settings to take a photo.',
      );
      await pumpScreen(tester);
      await openSheet(tester);

      await tester.tap(find.byKey(const Key('upload_source_camera')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('upload_pick_error')), findsOneWidget);
      expect(
        find.text(
          'Camera access is turned off. Enable it in Settings to take a photo.',
        ),
        findsOneWidget,
      );
      expect(log.entries, isEmpty);
    },
  );

  testWidgets(
    'a picked file shows an Uploading row, then disappears once it is done',
    (tester) async {
      final putGate = Completer<void>();
      storage.putGate = putGate;
      await pumpScreen(tester);
      await openSheet(tester);

      await tester.tap(find.byKey(const Key('upload_source_file')));
      // Bounded pumps: the in-flight progress bar animates forever.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byKey(const Key('upload_list')), findsOneWidget);
      expect(find.text('notes.txt'), findsOneWidget);
      expect(find.text('Uploading'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);

      putGate.complete();
      await tester.pumpAndSettle();

      expect(log.entries, ['init', 'put', 'confirm']);
      expect(find.byKey(const Key('upload_list')), findsNothing);
    },
  );

  testWidgets('a failed upload shows the shared ErrorView and can be dismissed', (
    tester,
  ) async {
    storage.putError = const NetworkUnreachableException();
    await pumpScreen(tester);
    await openSheet(tester);

    await tester.tap(find.byKey(const Key('upload_source_file')));
    await tester.pumpAndSettle();

    expect(find.text('Failed'), findsOneWidget);
    expect(find.byKey(const Key('error_view_offline')), findsOneWidget);
    expect(
      find.text("Can't reach Cerebro. Check your connection."),
      findsOneWidget,
    );
    expect(log.entries, ['init', 'put'], reason: 'confirm was never called');

    await tester.tap(find.textContaining('Dismiss'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('upload_list')), findsNothing);
  });

  testWidgets(
    "a server rejection shows the server's own message on the row",
    (tester) async {
      api.initError = const RequestRejectedException(
        "'application/zip' is not a supported file type",
        code: 'unsupported_mime_type',
      );
      await pumpScreen(tester);
      await openSheet(tester);

      await tester.tap(find.byKey(const Key('upload_source_file')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('error_view_rejected')), findsOneWidget);
      expect(
        find.text("'application/zip' is not a supported file type"),
        findsOneWidget,
      );
    },
  );

  testWidgets('an oversized file is rejected on the row with no network call', (
    tester,
  ) async {
    picker.result = fakePickedUpload(name: 'big.pdf', mime: 'application/pdf', sizeBytes: 52428801);
    await pumpScreen(tester);
    await openSheet(tester);

    await tester.tap(find.byKey(const Key('upload_source_file')));
    await tester.pumpAndSettle();

    expect(find.text('File exceeds the 50MB upload limit'), findsOneWidget);
    expect(log.entries, isEmpty);
  });
}
