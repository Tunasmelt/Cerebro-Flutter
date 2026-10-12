import 'dart:convert';
import 'dart:typed_data';
import 'package:cerebro_mobile/main.dart';
import 'package:cerebro_mobile/app/router.dart';
import 'package:cerebro_mobile/features/auth/data/auth_notifier.dart';
import 'package:cerebro_mobile/features/documents/data/document.dart';
import 'package:cerebro_mobile/features/documents/data/document_file_provider.dart';
import 'package:cerebro_mobile/features/documents/data/documents_repository_provider.dart';
import 'package:cerebro_mobile/features/documents/presentation/document_detail_screen.dart';
import 'package:cerebro_mobile/features/documents/presentation/document_file_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../features/auth/fake_auth_repository.dart';
import '../features/documents/fake_documents_repository.dart';

void main() {
  testWidgets(
    'document tap opens preview directly; details and back preserve navigation',
    (tester) async {
      final auth = FakeAuthRepository(initialUserId: 'owner');
      addTearDown(auth.dispose);
      final doc = DocumentSummary(
        id: 'doc',
        title: 'notes.txt',
        mime: 'text/plain',
        sizeBytes: 12,
        originalSizeBytes: 12,
        status: DocumentStatus.ready,
        createdAt: DateTime(2026),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(auth),
            documentsRepositoryProvider.overrideWithValue(
              FakeDocumentsRepository(documents: [doc]),
            ),
            documentFileProvider('doc').overrideWith(
              (ref) async =>
                  Uint8List.fromList(utf8.encode('Preview contents')),
            ),
          ],
          child: const CerebroApp(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('document_row_doc')));
      await tester.pumpAndSettle();
      expect(find.byType(DocumentFileScreen), findsOneWidget);
      expect(find.text('Preview contents'), findsOneWidget);
      expect(find.byType(DocumentDetailScreen), findsNothing);
      await tester.tap(find.byTooltip('Document details'));
      await tester.pumpAndSettle();
      expect(find.byType(DocumentDetailScreen), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Preview contents'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('document_row_doc')), findsOneWidget);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(CerebroApp)),
      );
      final router = container.read(routerProvider);
      router.go(AppRoutes.chat);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('chat_empty')), findsOneWidget);
      final pushed = router.push(AppRoutes.documentPreview('doc'));
      await tester.pumpAndSettle();
      expect(find.text('Preview contents'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await pushed;
      expect(find.byKey(const Key('chat_empty')), findsOneWidget);
    },
  );
}
