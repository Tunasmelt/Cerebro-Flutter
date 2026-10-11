import 'dart:async';
import 'package:cerebro_mobile/core/network/app_exception.dart';
import 'package:cerebro_mobile/features/auth/data/current_user_provider.dart';
import 'package:cerebro_mobile/features/chat/data/chat_controller.dart';
import 'package:cerebro_mobile/features/playground/data/playground_api.dart';
import 'package:cerebro_mobile/features/playground/presentation/playground_screen.dart';
import 'package:cerebro_mobile/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../fake_playground_api.dart';

final owner = StateProvider<String?>((_) => 'owner');
void main() {
  late FakePlaygroundApi api;
  late FakePlaygroundHistory history;
  setUp(() {
    api = FakePlaygroundApi();
    history = FakePlaygroundHistory();
  });
  Future<void> mount(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserIdProvider.overrideWith((ref) => ref.watch(owner)),
          chatHistoryApiProvider.overrideWithValue(history),
          playgroundApiProvider.overrideWithValue(api),
        ],
        child: MaterialApp(
          theme: AppTheme.dark,
          home: const PlaygroundScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> choose(WidgetTester tester, int dropdown, String label) async {
    await tester.tap(find.byType(DropdownButtonFormField<String>).at(dropdown));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  Future<void> select(WidgetTester tester) async {
    await choose(tester, 0, 'Synthetic conversation');
    await choose(tester, 1, 'Reply 1: Synthetic response');
  }

  testWidgets(
    'read-only breakdown uses server totals, model, cost and sections',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await mount(tester);
      await select(tester);
      expect(find.text('server-model'), findsOneWidget);
      expect(find.text('64'), findsOneWidget);
      expect(find.text('84'), findsOneWidget);
      expect(find.text('\$0.000069'), findsOneWidget);
      expect(find.text('Synthetic context'), findsOneWidget);
      expect(find.text('Example · chunk_1234'), findsOneWidget);
      expect(find.text('Response'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(find.text('Run prompt'), findsNothing);
      expect(api.calls.single, ('s1', 'm1'));
    },
  );
  testWidgets('switching replies requests the selected server ID', (
    tester,
  ) async {
    await mount(tester);
    await select(tester);
    await choose(tester, 1, 'Reply 2: Second response');
    expect(api.calls.last, ('s1', 'm2'));
  });
  testWidgets('switching conversation clears previous reply and breakdown', (
    tester,
  ) async {
    await mount(tester);
    await select(tester);
    await choose(tester, 0, 'Other conversation');
    expect(find.byKey(const Key('playground_breakdown')), findsNothing);
    expect(api.calls, hasLength(1));
  });
  testWidgets('empty conversations show guidance', (tester) async {
    history.sessions = [];
    await mount(tester);
    expect(
      find.text('No saved conversations. Start a chat first.'),
      findsOneWidget,
    );
  });
  testWidgets('empty assistant list is an explicit empty state', (
    tester,
  ) async {
    api.replies = [];
    await mount(tester);
    await choose(tester, 0, 'Synthetic conversation');
    expect(
      find.text('This conversation has no saved assistant replies.'),
      findsOneWidget,
    );
  });
  testWidgets('conversation failure retries', (tester) async {
    history.error = const NetworkUnreachableException();
    await mount(tester);
    history.error = null;
    await tester.tap(find.byKey(const Key('error_view_retry')));
    await tester.pumpAndSettle();
    expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
  });
  testWidgets('prompt failure is safe and retries selected turn', (
    tester,
  ) async {
    api.error = StateError('private payload');
    await mount(tester);
    await select(tester);
    expect(find.textContaining('private payload'), findsNothing);
    api.error = null;
    await tester.tap(find.byKey(const Key('error_view_retry')));
    await tester.pumpAndSettle();
    expect(find.text('server-model'), findsOneWidget);
    expect(api.calls, hasLength(2));
  });
  testWidgets(
    'account change clears selected data and ignores old pending reply',
    (tester) async {
      api.gate = Completer<PromptBreakdown>();
      await mount(tester);
      await choose(tester, 0, 'Synthetic conversation');
      await tester.tap(find.byType(DropdownButtonFormField<String>).at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reply 1: Synthetic response').last);
      await tester.pump();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(PlaygroundScreen)),
      );
      container.read(owner.notifier).state = 'other';
      await tester.pump();
      api.gate!.complete(samplePrompt);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('playground_breakdown')), findsNothing);
      expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
