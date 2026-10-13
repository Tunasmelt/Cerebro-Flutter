import 'package:cerebro_mobile/features/auth/data/current_user_provider.dart';
import 'package:cerebro_mobile/features/documents/data/document.dart';
import 'package:cerebro_mobile/features/documents/data/document_actions_api.dart';
import 'package:cerebro_mobile/features/documents/data/document_actions_controller.dart';
import 'package:cerebro_mobile/features/documents/data/documents_list_notifier.dart';
import 'package:cerebro_mobile/features/documents/data/documents_repository_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../document_management_fakes.dart';
import '../fake_documents_repository.dart';

/// Serves a copy of the "server" list, as a real response would: handing back
/// the very list the fake server edits would make a refresh look like it
/// happened when it did not.
class _CopyingRepository extends FakeDocumentsRepository {
  _CopyingRepository(List<DocumentSummary> documents)
    : super(documents: documents);

  @override
  Future<List<DocumentSummary>> listDocuments() async =>
      List.of(await super.listDocuments());
}

void main() {
  group('validateDocumentTitle', () {
    test('accepts a normal name, with or without padding', () {
      expect(validateDocumentTitle('Quarterly report'), isNull);
      expect(validateDocumentTitle('  padded  '), isNull);
    });

    test('rejects empty and whitespace-only names', () {
      expect(validateDocumentTitle(''), 'Enter a name.');
      expect(validateDocumentTitle('   \n '), 'Enter a name.');
    });

    test('the limit is the server\'s 500, counted in characters', () {
      expect(validateDocumentTitle('a' * maxTitleChars), isNull);
      expect(validateDocumentTitle('a' * (maxTitleChars + 1)), isNotNull);
      // 500 emoji are 500 characters (and 1000 UTF-16 units).
      expect(validateDocumentTitle('😀' * maxTitleChars), isNull);
    });

    test('trailing spaces do not count towards the limit', () {
      expect(validateDocumentTitle('${'a' * maxTitleChars}   '), isNull);
    });
  });

  group('validateNoteText', () {
    test('needs something other than whitespace', () {
      expect(validateNoteText(''), 'Write something first.');
      expect(validateNoteText(' \n\t '), 'Write something first.');
      expect(validateNoteText('a thought'), isNull);
    });

    test('the limit is the server\'s 20,000, after trimming', () {
      expect(validateNoteText('a' * maxNoteChars), isNull);
      expect(validateNoteText('a' * (maxNoteChars + 1)), isNotNull);
      expect(validateNoteText('  ${'a' * maxNoteChars}  '), isNull);
    });
  });

  group('DocumentActions', () {
    late List<DocumentSummary> server;
    late FakeDocumentActionsApi api;

    ProviderContainer make({String? user = 'u1'}) {
      final c = ProviderContainer(
        overrides: [
          currentUserIdProvider.overrideWith((ref) => user),
          documentsRepositoryProvider.overrideWithValue(
            _CopyingRepository(server),
          ),
          documentActionsApiProvider.overrideWithValue(api),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    setUp(() {
      server = [managedDoc('a', 'Alpha'), managedDoc('b', 'Beta')];
      api = FakeDocumentActionsApi(server);
    });

    test(
      'rename sends the trimmed name and updates the list at once',
      () async {
        final c = make();
        await c.read(documentsListProvider.future);

        await c.read(documentActionsProvider).rename('a', '  Alpha prime  ');

        expect(api.renames, [('a', 'Alpha prime')]);
        final titles = c
            .read(documentsListProvider)
            .requireValue
            .map((d) => d.title);
        expect(titles, ['Alpha prime', 'Beta']);
      },
    );

    test('a refused rename leaves the list as it was and throws', () async {
      final c = make();
      await c.read(documentsListProvider.future);
      api.renameError = rejected;

      await expectLater(
        c.read(documentActionsProvider).rename('a', 'Whatever'),
        throwsA(rejected),
      );
      expect(c.read(documentsListProvider).requireValue.map((d) => d.title), [
        'Alpha',
        'Beta',
      ]);
    });

    test('createNote returns the id and the list gains the note', () async {
      final c = make();
      await c.read(documentsListProvider.future);

      final id = await c
          .read(documentActionsProvider)
          .createNote(text: 'Remember the milk', title: 'Shopping');
      await c.read(documentsListProvider.future);
      await pumpEventQueue();

      expect(id, 'note-1');
      expect(api.notes.single, (text: 'Remember the milk', title: 'Shopping'));
      final titles = c
          .read(documentsListProvider)
          .requireValue
          .map((d) => d.title);
      expect(titles, contains('Shopping'));
    });

    test('a failed createNote throws and adds nothing', () async {
      final c = make();
      await c.read(documentsListProvider.future);
      api.noteError = rejected;

      await expectLater(
        c.read(documentActionsProvider).createNote(text: 'x'),
        throwsA(rejected),
      );
      expect(c.read(documentsListProvider).requireValue, hasLength(2));
    });
  });
}
