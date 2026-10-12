import 'package:cerebro_mobile/features/chat/data/chat_message.dart';
import 'package:cerebro_mobile/features/chat/data/document_titles_provider.dart';
import 'package:cerebro_mobile/features/chat/presentation/message_bubble.dart';
import 'package:cerebro_mobile/shared/widgets/app_markdown.dart';
import 'package:cerebro_mobile/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> bubble(WidgetTester tester, String text, {Set<String> retrieved = const {'c'}}) => tester.pumpWidget(ProviderScope(
    overrides: [documentTitlesProvider.overrideWithValue({'d': 'notes.md'})],
    child: MaterialApp(theme: AppTheme.dark, home: Scaffold(body: SingleChildScrollView(child: ChatBubble(
      message: ChatMessage(id: 1, role: ChatRole.assistant, text: text, retrievalDone: true,
        retrievedChunkIds: retrieved, citedDocuments: const {'c': 'd'}),
      canRetry: false, onRetry: () {}, onOpenDocument: (_) {},
    )))),
  ));
  String visible(WidgetTester tester) => tester.widgetList<Text>(find.byType(Text)).map((text) => text.data ?? text.textSpan?.toPlainText() ?? '').join('\n');

  testWidgets('Markdown formats headings lists and repeated trusted citations', (tester) async {
    await bubble(tester, '## Heading\n\n**Bold** [[chunk:c]] and [[chunk:c]].\n\n- First\n- Second');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('citation_chip_1')), findsNWidgets(2));
    expect(visible(tester), contains('Heading'));
    expect(visible(tester), isNot(contains('**Bold**')));
    expect(visible(tester), isNot(contains('[[chunk:')));
    expect(tester.takeException(), isNull);
  });

  testWidgets('copy answer keeps Markdown and resolved footnotes without raw markers', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String;
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await bubble(tester, '**Bold** [[chunk:c]] [[chunk:invented]]'); await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('chat_copy_1'))); await tester.pump();
    expect(copied, '**Bold** [1] ');
  });

  testWidgets('code copy has no internal citation delimiter and images never fetch', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String;
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await bubble(tester, '```text\nexample [[chunk:c]]\n```\n\n![External image](https://example.invalid/tracker.png)');
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsNothing);
    await tester.tap(find.byTooltip('Copy code')); await tester.pump();
    expect(copied, contains('example [1]'));
    expect(copied, isNot(contains('\uE000')));
  });

  testWidgets('tables and long code fit a narrow viewport', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 640)); addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(theme: AppTheme.dark, home: Scaffold(body: SingleChildScrollView(child: AppMarkdown(
      data: '| Name | Value |\n|---|---|\n| One | Two |\n\n```text\n${'long ' * 100}\n```',
    )))));
    await tester.pumpAndSettle(); expect(tester.takeException(), isNull);
    expect(find.byType(Table), findsOneWidget);
  });
}
