import 'dart:async';
import 'package:cerebro_mobile/core/network/app_exception.dart';
import 'package:cerebro_mobile/features/auth/data/current_user_provider.dart';
import 'package:cerebro_mobile/features/todo/data/todo_api.dart';
import 'package:cerebro_mobile/features/todo/data/todo_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../fake_todo_api.dart';

final user = StateProvider<String?>((_) => 'owner');
Future<void> tick() => Future<void>.delayed(const Duration(milliseconds: 5));
void main() {
  test('mixed list groups completed tasks while preserving server order', () {
    final groups = groupTodos([
      sampleTasks[1],
      sampleTasks[0],
      const TodoTask(
        id: 'c',
        title: 'Another active',
        completed: false,
        priority: TodoPriority.high,
      ),
    ]);
    expect(groups.active.map((t) => t.id), ['a', 'c']);
    expect(groups.completed.single.id, 'b');
    expect(
      groupTodos(sampleTasks, priority: TodoPriority.high).active,
      isEmpty,
    );
    expect(groupTodos([]).completed, isEmpty);
  });
  late ProviderContainer container;
  late FakeTodoApi api;
  TodoController controller() =>
      container.read(todoControllerProvider.notifier);
  TodoState state() => container.read(todoControllerProvider);
  setUp(() async {
    api = FakeTodoApi();
    container = ProviderContainer(
      overrides: [
        currentUserIdProvider.overrideWith((ref) => ref.watch(user)),
        todoApiProvider.overrideWithValue(api),
      ],
    );
    container.listen(todoControllerProvider, (_, _) {});
    await tick();
  });
  tearDown(() => container.dispose());
  test(
    'create trims title and reloads real state; empty title rejected',
    () async {
      expect(await controller().save('  ', TodoPriority.medium), false);
      expect(api.creates, isEmpty);
      expect(await controller().save(' New task ', TodoPriority.high), true);
      expect(api.creates.single, ('New task', TodoPriority.high));
      expect(state().tasks!.first.id, 'new');
    },
  );
  test(
    'complete and reopen move between groups using server timestamps',
    () async {
      await controller().setCompleted('a', true);
      expect(groupTodos(state().tasks!).active, isEmpty);
      expect(state().tasks!.first.completedAt, DateTime.utc(2026, 10, 11));
      await controller().setCompleted('a', false);
      expect(groupTodos(state().tasks!).active.single.id, 'a');
      expect(state().tasks!.first.completedAt, isNull);
    },
  );
  test('edit and delete validate membership', () async {
    expect(await controller().save('Renamed', TodoPriority.low, id: 'a'), true);
    expect(state().tasks!.first.title, 'Renamed');
    expect(await controller().delete('missing'), false);
    expect(api.deletes, isEmpty);
    expect(await controller().setCompleted('missing', true), false);
    expect(await controller().delete('a'), true);
    expect(state().tasks!.single.id, 'b');
  });
  test('concurrent write is rejected while first is pending', () async {
    api.writeGate = Completer<void>();
    final pending = controller().setCompleted('a', true);
    expect(await controller().setCompleted('a', false), false);
    expect(await controller().save('Duplicate', TodoPriority.medium), false);
    api.writeGate!.complete();
    expect(await pending, true);
    expect(api.updates, hasLength(1));
  });
  test('failed mutation reconciles and retains safe error', () async {
    api.writeError = StateError('private response');
    expect(await controller().setCompleted('a', true), false);
    expect(state().tasks!.first.completed, false);
    expect(state().saving, false);
    expect(state().error!.message, isNot(contains('private response')));
    expect(api.lists, 2);
  });
  test('load error retries', () async {
    api.listError = const NetworkUnreachableException();
    await controller().reload();
    expect(state().error, isA<NetworkUnreachableException>());
    api.listError = null;
    await controller().reload();
    expect(state().error, isNull);
  });
  test('account switch suppresses a late mutation response', () async {
    api.writeGate = Completer<void>();
    final pending = controller().setCompleted('a', true);
    api.listGate = Completer<List<TodoTask>>();
    container.read(user.notifier).state = 'other';
    await tick();
    expect(state().tasks, isNull);
    api.writeGate!.complete();
    expect(await pending, false);
    expect(api.lists, 2);
    api.listGate!.complete([]);
    await tick();
    expect(state().tasks, isEmpty);
  });
  test('sign out clears task state without fetching', () async {
    container.read(user.notifier).state = null;
    await tick();
    expect(state().tasks, isNull);
    expect(api.lists, 1);
  });
}
