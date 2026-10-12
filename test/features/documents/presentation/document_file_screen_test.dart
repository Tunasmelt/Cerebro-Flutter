import 'dart:convert';
import 'dart:typed_data';

import 'package:cerebro_mobile/features/auth/data/current_user_provider.dart';
import 'package:cerebro_mobile/features/documents/data/document.dart';
import 'package:cerebro_mobile/features/documents/data/document_detail_provider.dart';
import 'package:cerebro_mobile/features/documents/data/document_file_provider.dart';
import 'package:cerebro_mobile/features/documents/presentation/document_file_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cerebro_mobile/core/network/app_exception.dart';
import 'package:cerebro_mobile/features/documents/presentation/extracted_text_preview.dart';
import 'package:cerebro_mobile/shared/widgets/app_markdown.dart';

void main() {
  DocumentDetail detail(DocumentStatus status) => DocumentDetail(
    id: 'doc',
    title: 'fixture.txt',
    mime: 'text/plain',
    sizeBytes: 12,
    status: status,
    createdAt: DateTime(2026),
    ingestState: 'ready',
    lastError: null,
  );

  testWidgets(
    'captured thoughts without an original use authenticated text preview',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserIdProvider.overrideWithValue('owner'),
            documentDetailProvider(
              'doc',
            ).overrideWith((ref) => Stream.value(detail(DocumentStatus.ready))),
            documentFileProvider('doc').overrideWith(
              (ref) async => throw const RequestRejectedException(
                'No original',
                code: 'not_available',
              ),
            ),
            extractedTextPreviewProvider(
              'doc',
            ).overrideWith((ref) async => '**Captured thought**'),
          ],
          child: const MaterialApp(home: DocumentFileScreen(documentId: 'doc')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Extracted text'), findsOneWidget);
      expect(find.byType(AppMarkdown), findsOneWidget);
      expect(find.byTooltip('Document details'), findsOneWidget);
    },
  );

  testWidgets(
    'unsupported types offer an external-app action without opening it automatically',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: DocumentFileContent(
            bytes: Uint8List.fromList([1, 2, 3]),
            mime: 'application/octet-stream',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Open with another app'), findsOneWidget);
      expect(find.textContaining('no in-app preview'), findsOneWidget);
    },
  );

  testWidgets('renders selectable original text inside the app', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserIdProvider.overrideWithValue('owner'),
          documentDetailProvider(
            'doc',
          ).overrideWith((ref) => Stream.value(detail(DocumentStatus.ready))),
          documentFileProvider('doc').overrideWith(
            (ref) async => Uint8List.fromList(utf8.encode('Original body')),
          ),
        ],
        child: const MaterialApp(home: DocumentFileScreen(documentId: 'doc')),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.widgetWithText(SelectableText, 'Original body'),
      findsOneWidget,
    );
  });

  testWidgets('sealed documents never request original bytes', (tester) async {
    var reads = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserIdProvider.overrideWithValue('owner'),
          documentDetailProvider(
            'doc',
          ).overrideWith((ref) => Stream.value(detail(DocumentStatus.sealed))),
          documentFileProvider('doc').overrideWith((ref) async {
            reads++;
            return Uint8List(0);
          }),
        ],
        child: const MaterialApp(home: DocumentFileScreen(documentId: 'doc')),
      ),
    );
    await tester.pumpAndSettle();
    expect(reads, 0);
    expect(
      find.textContaining('Original files cannot be viewed while sealed.'),
      findsOneWidget,
    );
  });

  testWidgets('sign out removes visible file content', (tester) async {
    final owner = StateProvider<String?>((ref) => 'owner');
    final container = ProviderContainer(
      overrides: [
        currentUserIdProvider.overrideWith((ref) => ref.watch(owner)),
        documentDetailProvider(
          'doc',
        ).overrideWith((ref) => Stream.value(detail(DocumentStatus.ready))),
        documentFileProvider('doc').overrideWith(
          (ref) async => Uint8List.fromList(utf8.encode('Private body')),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: DocumentFileScreen(documentId: 'doc')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Private body'), findsOneWidget);
    container.read(owner.notifier).state = null;
    await tester.pumpAndSettle();
    expect(find.text('Private body'), findsNothing);
    expect(find.text('Sign in to view this file.'), findsOneWidget);
  });
}
