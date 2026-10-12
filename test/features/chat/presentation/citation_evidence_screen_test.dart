import 'dart:convert';

import 'package:cerebro_mobile/features/auth/data/current_user_provider.dart';
import 'package:cerebro_mobile/features/chat/data/chat_message.dart';
import 'package:cerebro_mobile/features/chat/data/citation_evidence.dart';
import 'package:cerebro_mobile/features/chat/data/document_titles_provider.dart';
import 'package:cerebro_mobile/features/chat/presentation/citation_evidence_screen.dart';
import 'package:cerebro_mobile/features/chat/presentation/message_bubble.dart';
import 'package:cerebro_mobile/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'both inline and source citations open the exact chunk instead of the full file',
    (tester) async {
      final opened = <String>[];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            documentTitlesProvider.overrideWithValue({'doc': 'Notes'}),
          ],
          child: MaterialApp(
            theme: AppTheme.dark,
            home: Scaffold(
              body: ChatBubble(
                message: const ChatMessage(
                  id: 1,
                  role: ChatRole.assistant,
                  text: 'Claim [[chunk:exact]]',
                  retrievedChunkIds: {'exact'},
                  citedDocuments: {'exact': 'doc'},
                ),
                canRetry: false,
                onRetry: () {},
                onOpenDocument: (_) => fail('opened full file'),
                onOpenCitation: (part) => opened.add(part.chunkId),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('citation_chip_1')));
      await tester.tap(find.byKey(const Key('source_chip_doc')));
      expect(opened, ['exact', 'exact']);
    },
  );

  testWidgets(
    'legacy evidence shows the actual cited excerpt and separate full document action',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserIdProvider.overrideWithValue('owner'),
            citationEvidenceProvider('chunk').overrideWith(
              (ref) async => {
                'document': {'id': 'doc', 'title': 'Notes'},
                'legacy': true,
                'content': 'The exact supporting words',
                'render_url': null,
                'region': null,
              },
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.dark,
            home: const CitationEvidenceScreen(chunkId: 'chunk'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('The exact supporting words'), findsOneWidget);
      expect(find.text('Open full document'), findsOneWidget);
      expect(find.textContaining('no region coordinates'), findsOneWidget);
    },
  );

  testWidgets('image evidence highlights a recorded region only', (
    tester,
  ) async {
    const url = 'https://example.test/evidence.png';
    final bytes = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO2J5p8AAAAASUVORK5CYII=',
    );
    Future<void> show(List<num>? bbox) async {
      await tester.pumpWidget(
        ProviderScope(
          key: UniqueKey(),
          overrides: [
            currentUserIdProvider.overrideWithValue('owner'),
            citationEvidenceProvider('chunk').overrideWith(
              (ref) async => {
                'document': {'id': 'doc', 'title': 'Image'},
                'content': 'A cited image caption',
                'render_url': url,
                'region': bbox == null ? null : {'bbox': bbox},
              },
            ),
            evidenceImageProvider(url).overrideWith((ref) async => bytes),
          ],
          child: MaterialApp(
            theme: AppTheme.dark,
            home: const CitationEvidenceScreen(chunkId: 'chunk'),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await show([0.2, 0.3, 0.8, 0.9]);
    expect(find.byKey(const Key('citation_region_highlight')), findsOneWidget);
    await show(null);
    expect(find.byKey(const Key('citation_region_highlight')), findsNothing);
    expect(find.textContaining('A cited image caption'), findsOneWidget);
  });

  testWidgets('signed-out evidence never loads private content', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserIdProvider.overrideWithValue(null),
          citationEvidenceProvider(
            'chunk',
          ).overrideWith((ref) async => throw StateError('must not fetch')),
        ],
        child: const MaterialApp(
          home: CitationEvidenceScreen(chunkId: 'chunk'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Sign in to view evidence.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('signing out removes an already loaded source excerpt', (
    tester,
  ) async {
    final user = StateProvider<String?>((ref) => 'owner');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserIdProvider.overrideWith((ref) => ref.watch(user)),
          citationEvidenceProvider('chunk').overrideWith(
            (ref) async => {
              'document': {'id': 'doc', 'title': 'Notes'},
              'legacy': true,
              'content': 'Private excerpt',
              'render_url': null,
              'region': null,
            },
          ),
        ],
        child: const MaterialApp(
          home: CitationEvidenceScreen(chunkId: 'chunk'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Private excerpt'), findsOneWidget);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(CitationEvidenceScreen)),
    );
    container.read(user.notifier).state = null;
    await tester.pumpAndSettle();
    expect(find.text('Private excerpt'), findsNothing);
    expect(find.text('Sign in to view evidence.'), findsOneWidget);
  });
}
