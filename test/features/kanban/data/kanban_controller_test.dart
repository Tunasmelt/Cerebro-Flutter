import 'dart:async';
import 'package:cerebro_mobile/core/network/app_exception.dart';
import 'package:cerebro_mobile/features/auth/data/current_user_provider.dart';
import 'package:cerebro_mobile/features/kanban/data/kanban_api.dart';
import 'package:cerebro_mobile/features/kanban/data/kanban_board.dart';
import 'package:cerebro_mobile/features/kanban/data/kanban_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../fake_kanban_api.dart';

final user = StateProvider<String?>((_) => 'owner');
Future<void> tick() => Future<void>.delayed(const Duration(milliseconds: 5));
void main() {
  late FakeKanbanApi api;
  late ProviderContainer container;
  KanbanController controller() =>
      container.read(kanbanControllerProvider.notifier);
  KanbanState state() => container.read(kanbanControllerProvider);
  setUp(() async {
    api = FakeKanbanApi();
    container = ProviderContainer(
      overrides: [
        kanbanApiProvider.overrideWithValue(api),
        currentUserIdProvider.overrideWith((ref) => ref.watch(user)),
      ],
    );
    container.listen(kanbanControllerProvider, (_, _) {});
    await tick();
  });
  tearDown(() => container.dispose());
  test(
    'same-column reorder is persisted and rendered in the new order',
    () async {
      expect(await controller().move('b', 'Backlog', 0), true);
      expect(state().board!.inColumn('Backlog').map((c) => c.id), ['b', 'a']);
      expect(api.moves.single, ('b', 'Backlog', -1000.0));
    },
  );
  test(
    'cross-column insertion keeps destination order and removes source',
    () async {
      await controller().move('a', 'Done', 0);
      expect(state().board!.inColumn('Done').map((c) => c.id), ['a', 'c']);
      expect(state().board!.inColumn('Backlog').map((c) => c.id), ['b']);
    },
  );
  test('empty destination and append use server float positions', () async {
    await controller().move('b', 'In Progress', 0);
    expect(api.moves.last.$3, 0);
    await controller().move('a', 'Done', 1);
    expect(api.moves.last.$3, 1000);
  });
  test(
    'duplicate positions are renumbered preserving requested insertion',
    () async {
      api.board = const KanbanBoard(
        id: 'board',
        title: 'My Board',
        columns: ['Backlog', 'Done'],
        cards: [
          KanbanCard(
            id: 'a',
            column: 'Backlog',
            title: 'A',
            description: '',
            position: 0,
          ),
          KanbanCard(
            id: 'b',
            column: 'Backlog',
            title: 'B',
            description: '',
            position: 0,
          ),
          KanbanCard(
            id: 'c',
            column: 'Done',
            title: 'C',
            description: '',
            position: 0,
          ),
        ],
      );
      await controller().reload();
      await controller().move('c', 'Backlog', 1);
      expect(api.moves.map((m) => m.$1), ['a', 'c', 'b']);
      expect(state().board!.inColumn('Backlog').map((c) => c.id), [
        'a',
        'c',
        'b',
      ]);
    },
  );
  test('create trims fields and preserves optional document', () async {
    await controller().create('Backlog', ' New card ', ' Notes ', 'doc');
    expect(api.creates.single, ('Backlog', 'New card', 'Notes', 'doc'));
    expect(state().board!.cards.last.documentId, 'doc');
  });
  test('invalid input never reaches API', () async {
    expect(await controller().create('Backlog', '  ', '', null), false);
    expect(await controller().move('missing', 'Done', 0), false);
    expect(await controller().move('a', 'Unknown', 0), false);
    expect(await controller().move('a', 'Done', 99), false);
    expect(api.creates, isEmpty);
    expect(api.moves, isEmpty);
  });
  test('duplicate writes are blocked while saving', () async {
    api.writeGate = Completer<void>();
    final pending = controller().move('a', 'Done', 0);
    expect(state().saving, true);
    expect(await controller().move('b', 'Done', 0), false);
    expect(await controller().create('Backlog', 'New', '', null), false);
    api.writeGate!.complete();
    expect(await pending, true);
    expect(api.moves, hasLength(1));
  });
  test('failed write rereads server and uses a safe error', () async {
    api.writeError = StateError('private backend response');
    expect(await controller().move('a', 'Done', 0), false);
    expect(state().saving, false);
    expect(state().board!.inColumn('Backlog').first.id, 'a');
    expect(state().error, isA<UnknownApiException>());
    expect(api.gets, 1);
  });
  test('load failure can retry', () async {
    api.loadError = const NetworkUnreachableException();
    await controller().reload();
    expect(state().error, isA<NetworkUnreachableException>());
    api.loadError = null;
    await controller().reload();
    expect(state().error, isNull);
    expect(state().board!.id, 'board');
  });
  test('account change drops late write result and cached board', () async {
    api.writeGate = Completer<void>();
    final pending = controller().move('a', 'Done', 0);
    api.loadGate = Completer<KanbanBoard>();
    container.read(user.notifier).state = 'other';
    await tick();
    expect(state().board, isNull);
    api.writeGate!.complete();
    expect(await pending, false);
    expect(api.gets, 0);
    api.loadGate!.complete(
      const KanbanBoard(
        id: 'other',
        title: 'Other',
        columns: ['Backlog'],
        cards: [],
      ),
    );
    await tick();
    expect(state().board!.id, 'other');
  });
  test('sign-out does not request another board', () async {
    container.read(user.notifier).state = null;
    await tick();
    expect(state().board, isNull);
    expect(api.loads, 1);
    expect(state().error, isA<UnauthenticatedException>());
  });
}
