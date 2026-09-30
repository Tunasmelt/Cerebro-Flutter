import 'package:cerebro_mobile/features/documents/data/document.dart';
import 'package:cerebro_mobile/features/documents/data/documents_list_notifier.dart';
import 'package:cerebro_mobile/features/documents/data/documents_repository_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fake_documents_repository.dart';

void main() {
  late FakeDocumentsRepository fakeRepository;
  late ProviderContainer container;

  setUp(() => fakeRepository = FakeDocumentsRepository());
  tearDown(() => container.dispose());

  ProviderContainer buildContainer() {
    container = ProviderContainer(
      overrides: [
        documentsRepositoryProvider.overrideWithValue(fakeRepository),
      ],
    );
    return container;
  }

  test('build() resolves to the repository result', () async {
    final doc = DocumentSummary(
      id: 'doc-1',
      title: 'notes.txt',
      mime: 'text/plain',
      sizeBytes: 42,
      originalSizeBytes: 42,
      status: DocumentStatus.ready,
      createdAt: DateTime.utc(2026),
    );
    fakeRepository = FakeDocumentsRepository(documents: [doc]);
    final c = buildContainer();

    final result = await c.read(documentsListProvider.future);

    expect(result, [doc]);
  });

  test('a repository failure surfaces as an AsyncError, not a crash', () async {
    fakeRepository.nextListError = const FormatException('bad response');
    final c = buildContainer();

    await expectLater(
      c.read(documentsListProvider.future),
      throwsA(isA<FormatException>()),
    );
    expect(c.read(documentsListProvider).hasError, isTrue);
  });

  test('refresh() re-calls the repository and updates state', () async {
    final c = buildContainer();
    await c.read(documentsListProvider.future);
    expect(fakeRepository.listCalls, 1);

    await c.read(documentsListProvider.notifier).refresh();

    expect(fakeRepository.listCalls, 2);
    expect(c.read(documentsListProvider).value, isEmpty);
  });

  test(
    "refresh() keeps the previous list visible while it's in flight "
    '(pull-to-refresh shouldn\'t flash to a spinner)',
    () async {
      final c = buildContainer();
      await c.read(documentsListProvider.future);

      final refreshFuture = c.read(documentsListProvider.notifier).refresh();
      final duringRefresh = c.read(documentsListProvider);

      expect(duringRefresh.isLoading, isTrue);
      expect(duringRefresh.hasValue, isTrue);

      await refreshFuture;
    },
  );
}
