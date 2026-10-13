import 'dart:async';

import 'package:cerebro_mobile/core/network/app_exception.dart';
import 'package:cerebro_mobile/features/auth/data/current_user_provider.dart';
import 'package:cerebro_mobile/features/documents/data/delete_document_controller.dart';
import 'package:cerebro_mobile/features/documents/data/document.dart';
import 'package:cerebro_mobile/features/documents/data/document_actions_api.dart';
import 'package:cerebro_mobile/features/documents/data/document_actions_controller.dart';
import 'package:cerebro_mobile/features/documents/data/documents_repository_provider.dart';
import 'package:cerebro_mobile/features/documents/presentation/document_detail_screen.dart';
import 'package:cerebro_mobile/features/documents/presentation/documents_screen.dart';
import 'package:cerebro_mobile/features/documents/presentation/note_editor_screen.dart';
import 'package:cerebro_mobile/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../document_management_fakes.dart';
import '../fake_documents_repository.dart';

class _CopyingRepository extends FakeDocumentsRepository {
  _CopyingRepository(List<DocumentSummary> documents)
    : super(documents: documents);

  @override
  Future<List<DocumentSummary>> listDocuments() async =>
      List.of(await super.listDocuments());
}

void main() {
  late List<DocumentSummary> server;
  late FakeDocumentActionsApi actions;
  late FakeDeleteApi deletes;

  List<Override> overrides() => [
    currentUserIdProvider.overrideWithValue('u1'),
    documentsRepositoryProvider.overrideWithValue(_CopyingRepository(server)),
    documentActionsApiProvider.overrideWithValue(actions),
    deleteDocumentApiProvider.overrideWithValue(deletes),
  ];

  setUp(() {
    server = [managedDoc('a', 'Alpha report'), managedDoc('b', 'Beta notes')];
    actions = FakeDocumentActionsApi(server);
    deletes = FakeDeleteApi(server);
  });

  Future<void> pumpList(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides(),
        child: MaterialApp(theme: AppTheme.dark, home: const DocumentsScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openMenu(WidgetTester tester, String id) async {
    await tester.tap(find.byKey(Key('document_menu_$id')));
    await tester.pumpAndSettle();
  }

  Finder rowTitle(String title) => find.descendant(
    of: find.byKey(const Key('documents_list')),
    matching: find.text(title),
  );

  group('actions on a row', () {
    testWidgets('the row has a visible actions button', (tester) async {
      await pumpList(tester);
      expect(find.byKey(const Key('document_menu_a')), findsOneWidget);
      expect(find.byKey(const Key('document_menu_b')), findsOneWidget);
      expect(
        tester.getSize(find.byKey(const Key('document_menu_a'))).shortestSide,
        greaterThanOrEqualTo(44),
      );
    });

    testWidgets('the button opens Rename, Details and Delete', (tester) async {
      await pumpList(tester);
      await openMenu(tester, 'a');
      expect(find.byKey(const Key('document_action_rename')), findsOneWidget);
      expect(find.byKey(const Key('document_action_details')), findsOneWidget);
      expect(find.byKey(const Key('document_action_delete')), findsOneWidget);
    });

    testWidgets('a long press opens the same actions', (tester) async {
      await pumpList(tester);
      await tester.longPress(find.byKey(const Key('document_row_b')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('document_action_delete')), findsOneWidget);
    });

    testWidgets('every kind of document gets the actions, sealed too', (
      tester,
    ) async {
      server
        ..add(managedDoc('s', 'Vault', status: DocumentStatus.sealed))
        ..add(managedDoc('p', 'Working', status: DocumentStatus.processing))
        ..add(managedDoc('f', 'Broken', status: DocumentStatus.failed));
      await pumpList(tester);
      for (final id in ['a', 's', 'p', 'f']) {
        expect(
          find.byKey(Key('document_menu_$id')),
          findsOneWidget,
          reason: id,
        );
      }
    });
  });

  group('rename', () {
    Future<void> startRename(WidgetTester tester, String id) async {
      await openMenu(tester, id);
      await tester.tap(find.byKey(const Key('document_action_rename')));
      await tester.pumpAndSettle();
    }

    testWidgets('opens with the current name filled in', (tester) async {
      await pumpList(tester);
      await startRename(tester, 'a');
      final field = tester.widget<TextField>(
        find.descendant(
          of: find.byKey(const Key('rename_field')),
          matching: find.byType(TextField),
        ),
      );
      expect(field.controller!.text, 'Alpha report');
      // Selected, so typing replaces it.
      expect(field.controller!.selection.baseOffset, 0);
      expect(field.controller!.selection.extentOffset, 'Alpha report'.length);
    });

    testWidgets('the name field is focused on open, so the keyboard is up', (
      tester,
    ) async {
      await pumpList(tester);
      await startRename(tester, 'a');
      final field = tester.widget<TextField>(
        find.descendant(
          of: find.byKey(const Key('rename_field')),
          matching: find.byType(TextField),
        ),
      );
      expect(field.autofocus, isTrue);
      final editable = tester.widget<EditableText>(
        find.descendant(
          of: find.byKey(const Key('rename_field')),
          matching: find.byType(EditableText),
        ),
      );
      expect(editable.focusNode.hasFocus, isTrue);
    });

    testWidgets('saving shows the new name in the list', (tester) async {
      await pumpList(tester);
      await startRename(tester, 'a');
      await tester.enterText(
        find.descendant(
          of: find.byKey(const Key('rename_field')),
          matching: find.byType(TextField),
        ),
        '  Quarterly report  ',
      );
      await tester.tap(find.byKey(const Key('rename_save')));
      await tester.pumpAndSettle();

      expect(actions.renames, [('a', 'Quarterly report')]);
      expect(rowTitle('Quarterly report'), findsOneWidget);
      expect(rowTitle('Alpha report'), findsNothing);
      expect(find.byKey(const Key('rename_field')), findsNothing);
    });

    testWidgets('an empty name is refused on the spot, nothing is sent', (
      tester,
    ) async {
      await pumpList(tester);
      await startRename(tester, 'a');
      await tester.enterText(
        find.descendant(
          of: find.byKey(const Key('rename_field')),
          matching: find.byType(TextField),
        ),
        '   ',
      );
      await tester.tap(find.byKey(const Key('rename_save')));
      await tester.pump();

      expect(find.text('Enter a name.'), findsOneWidget);
      expect(actions.renames, isEmpty);
      expect(find.byKey(const Key('rename_field')), findsOneWidget);
    });

    testWidgets('an unchanged name just closes, nothing is sent', (
      tester,
    ) async {
      await pumpList(tester);
      await startRename(tester, 'a');
      await tester.tap(find.byKey(const Key('rename_save')));
      await tester.pumpAndSettle();

      expect(actions.renames, isEmpty);
      expect(find.byKey(const Key('rename_field')), findsNothing);
    });

    testWidgets('Cancel changes nothing', (tester) async {
      await pumpList(tester);
      await startRename(tester, 'a');
      await tester.enterText(
        find.descendant(
          of: find.byKey(const Key('rename_field')),
          matching: find.byType(TextField),
        ),
        'Something else',
      );
      await tester.tap(find.byKey(const Key('rename_cancel')));
      await tester.pumpAndSettle();

      expect(actions.renames, isEmpty);
      expect(rowTitle('Alpha report'), findsOneWidget);
    });

    testWidgets('a refusal from the server is shown and the dialog stays', (
      tester,
    ) async {
      await pumpList(tester);
      actions.renameError = rejected;
      await startRename(tester, 'a');
      await tester.enterText(
        find.descendant(
          of: find.byKey(const Key('rename_field')),
          matching: find.byType(TextField),
        ),
        'New name',
      );
      await tester.tap(find.byKey(const Key('rename_save')));
      await tester.pumpAndSettle();

      expect(find.text('That name is too long.'), findsOneWidget);
      expect(find.byKey(const Key('rename_field')), findsOneWidget);
      expect(rowTitle('Alpha report'), findsOneWidget);
      // And it can be tried again.
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('rename_save')))
            .onPressed,
        isNotNull,
      );
    });

    testWidgets('an unexpected failure says so in plain words', (tester) async {
      await pumpList(tester);
      actions.renameError = StateError('boom: internal detail');
      await startRename(tester, 'a');
      await tester.enterText(
        find.descendant(
          of: find.byKey(const Key('rename_field')),
          matching: find.byType(TextField),
        ),
        'New name',
      );
      await tester.tap(find.byKey(const Key('rename_save')));
      await tester.pumpAndSettle();

      expect(
        find.text("Couldn't rename this document. Try again."),
        findsOneWidget,
      );
      expect(find.textContaining('internal detail'), findsNothing);
    });
  });

  group('delete from the list', () {
    Future<void> startDelete(WidgetTester tester, String id) async {
      await openMenu(tester, id);
      await tester.tap(find.byKey(const Key('document_action_delete')));
      await tester.pumpAndSettle();
    }

    testWidgets('asks first; Cancel deletes nothing', (tester) async {
      await pumpList(tester);
      await startDelete(tester, 'a');
      expect(find.text('Delete this document?'), findsOneWidget);
      expect(find.textContaining('Alpha report'), findsWidgets);

      await tester.tap(find.byKey(const Key('document_delete_cancel')));
      await tester.pumpAndSettle();

      expect(deletes.deleted, isEmpty);
      expect(rowTitle('Alpha report'), findsOneWidget);
    });

    testWidgets('confirming deletes it and the row goes', (tester) async {
      await pumpList(tester);
      await startDelete(tester, 'a');
      await tester.tap(find.byKey(const Key('document_delete_confirm')));
      await tester.pumpAndSettle();

      expect(deletes.deleted, ['a']);
      expect(rowTitle('Alpha report'), findsNothing);
      expect(rowTitle('Beta notes'), findsOneWidget);
      expect(find.text('Document deleted.'), findsOneWidget);
    });

    testWidgets('a sealed document can be deleted without a passphrase', (
      tester,
    ) async {
      server.add(managedDoc('s', 'Vault', status: DocumentStatus.sealed));
      await pumpList(tester);
      await startDelete(tester, 's');
      await tester.tap(find.byKey(const Key('document_delete_confirm')));
      await tester.pumpAndSettle();

      expect(deletes.deleted, ['s']);
      expect(rowTitle('Vault'), findsNothing);
    });

    testWidgets('a refusal is shown and the document stays', (tester) async {
      deletes.error = const NetworkUnreachableException();
      await pumpList(tester);
      await startDelete(tester, 'a');
      await tester.tap(find.byKey(const Key('document_delete_confirm')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('document_delete_error')), findsOneWidget);
      expect(rowTitle('Alpha report'), findsOneWidget);
    });

    testWidgets('a document that is already gone counts as deleted', (
      tester,
    ) async {
      deletes.error = const RequestRejectedException(
        'Document not found',
        code: 'not_found',
      );
      await pumpList(tester);
      await startDelete(tester, 'a');
      await tester.tap(find.byKey(const Key('document_delete_confirm')));
      await tester.pumpAndSettle();

      expect(rowTitle('Alpha report'), findsNothing);
      expect(find.byKey(const Key('document_delete_error')), findsNothing);
    });
  });

  group('delete and rename on the detail screen', () {
    Future<void> pumpDetail(WidgetTester tester, String id) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides(),
          child: MaterialApp(
            theme: AppTheme.dark,
            home: DocumentDetailScreen(documentId: id),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('a ready document can be renamed from its details', (
      tester,
    ) async {
      await pumpDetail(tester, 'a');
      expect(find.text('Alpha report'), findsOneWidget);

      await tester.tap(find.byKey(const Key('document_detail_rename')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byKey(const Key('rename_field')),
          matching: find.byType(TextField),
        ),
        'Renamed here',
      );
      await tester.tap(find.byKey(const Key('rename_save')));
      await tester.pumpAndSettle();

      expect(actions.renames, [('a', 'Renamed here')]);
      expect(find.text('Renamed here'), findsOneWidget);
      expect(find.text('Alpha report'), findsNothing);
    });

    testWidgets('a ready document offers Delete', (tester) async {
      await pumpDetail(tester, 'a');
      expect(find.byKey(const Key('document_detail_delete')), findsOneWidget);
    });

    testWidgets('rename and Delete are 44px targets', (tester) async {
      await pumpDetail(tester, 'a');
      for (final k in ['document_detail_rename', 'document_detail_delete']) {
        expect(
          tester.getSize(find.byKey(Key(k))).height,
          greaterThanOrEqualTo(44),
          reason: k,
        );
      }
    });
  });

  group('note editor', () {
    Future<void> openEditor(WidgetTester tester) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, _) => Scaffold(
              body: Center(
                child: TextButton(
                  key: const Key('open_editor'),
                  onPressed: () async {
                    final saved = await context.push<bool>('/notes/new');
                    if (context.mounted) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text('result: $saved')));
                    }
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/notes/new',
            builder: (_, _) => const NoteEditorScreen(),
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides(),
          child: MaterialApp.router(theme: AppTheme.dark, routerConfig: router),
        ),
      );
      await tester.tap(find.byKey(const Key('open_editor')));
      await tester.pumpAndSettle();
    }

    TextField text(WidgetTester tester) =>
        tester.widget<TextField>(find.byKey(const Key('note_text')));

    bool canSave(WidgetTester tester) =>
        tester
            .widget<TextButton>(find.byKey(const Key('note_save')))
            .onPressed !=
        null;

    testWidgets('starts empty, with Save off and a zero counter', (
      tester,
    ) async {
      await openEditor(tester);
      expect(canSave(tester), isFalse);
      expect(find.text('0 / $maxNoteChars'), findsOneWidget);
    });

    testWidgets('typing turns Save on and counts the characters', (
      tester,
    ) async {
      await openEditor(tester);
      await tester.enterText(find.byKey(const Key('note_text')), 'hello');
      await tester.pump();
      expect(canSave(tester), isTrue);
      expect(find.text('5 / $maxNoteChars'), findsOneWidget);
    });

    testWidgets('only whitespace keeps Save off', (tester) async {
      await openEditor(tester);
      await tester.enterText(find.byKey(const Key('note_text')), '  \n  ');
      await tester.pump();
      expect(canSave(tester), isFalse);
    });

    testWidgets('a title alone is not a note', (tester) async {
      await openEditor(tester);
      await tester.enterText(
        find.descendant(
          of: find.byKey(const Key('note_title')),
          matching: find.byType(TextField),
        ),
        'Just a title',
      );
      await tester.pump();
      expect(canSave(tester), isFalse);
    });

    testWidgets('too long keeps Save off and turns the counter red', (
      tester,
    ) async {
      await openEditor(tester);
      await tester.enterText(
        find.byKey(const Key('note_text')),
        'a' * (maxNoteChars + 1),
      );
      await tester.pump();
      expect(canSave(tester), isFalse);
      final counter = tester.widget<Text>(
        find.byKey(const Key('note_counter')),
      );
      expect(counter.style?.color, isNot(equals(const Color(0xFF91A0BD))));
    });

    testWidgets('saving sends the trimmed text and title, then closes', (
      tester,
    ) async {
      await openEditor(tester);
      await tester.enterText(
        find.descendant(
          of: find.byKey(const Key('note_title')),
          matching: find.byType(TextField),
        ),
        '  Shopping  ',
      );
      await tester.enterText(
        find.byKey(const Key('note_text')),
        '  milk and eggs  ',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('note_save')));
      await tester.pumpAndSettle();

      expect(actions.notes.single, (text: 'milk and eggs', title: 'Shopping'));
      // Back on the first screen, which was told it saved.
      expect(find.byKey(const Key('note_text')), findsNothing);
      expect(find.text('result: true'), findsOneWidget);
    });

    testWidgets('a blank title is sent as none, so the server names it', (
      tester,
    ) async {
      await openEditor(tester);
      await tester.enterText(find.byKey(const Key('note_text')), 'a thought');
      await tester.pump();
      await tester.tap(find.byKey(const Key('note_save')));
      await tester.pumpAndSettle();

      expect(actions.notes.single, (text: 'a thought', title: null));
    });

    testWidgets('while saving it cannot be saved twice', (tester) async {
      actions.noteGate = Completer<void>();
      await openEditor(tester);
      await tester.enterText(find.byKey(const Key('note_text')), 'once');
      await tester.pump();
      await tester.tap(find.byKey(const Key('note_save')));
      await tester.pump();

      expect(canSave(tester), isFalse);
      expect(find.text('Saving…'), findsOneWidget);
      actions.noteGate!.complete();
      await tester.pumpAndSettle();
      expect(actions.notes, hasLength(1));
    });

    testWidgets('a failure keeps the text and says why', (tester) async {
      actions.noteError = rejected;
      await openEditor(tester);
      await tester.enterText(find.byKey(const Key('note_text')), 'keep me');
      await tester.pump();
      await tester.tap(find.byKey(const Key('note_save')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('note_error')), findsOneWidget);
      expect(find.text('That name is too long.'), findsOneWidget);
      expect(text(tester).controller!.text, 'keep me');
      expect(canSave(tester), isTrue, reason: 'it can be tried again');
    });

    testWidgets('an unexpected failure is plain, and the text stays', (
      tester,
    ) async {
      actions.noteError = StateError('internal stack detail');
      await openEditor(tester);
      await tester.enterText(find.byKey(const Key('note_text')), 'keep me');
      await tester.pump();
      await tester.tap(find.byKey(const Key('note_save')));
      await tester.pumpAndSettle();

      expect(find.textContaining("Couldn't save this note"), findsOneWidget);
      expect(find.textContaining('internal stack detail'), findsNothing);
      expect(text(tester).controller!.text, 'keep me');
    });

    testWidgets('leaving an empty note just goes', (tester) async {
      await openEditor(tester);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('note_text')), findsNothing);
      expect(find.text('result: false'), findsNothing);
    });

    testWidgets('leaving with text asks first; Keep writing stays', (
      tester,
    ) async {
      await openEditor(tester);
      await tester.enterText(find.byKey(const Key('note_text')), 'unsaved');
      await tester.pump();
      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.text('Discard this note?'), findsOneWidget);
      await tester.tap(find.byKey(const Key('note_discard_cancel')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('note_text')), findsOneWidget);
      expect(text(tester).controller!.text, 'unsaved');
    });

    testWidgets('Discard leaves, and nothing was saved', (tester) async {
      await openEditor(tester);
      await tester.enterText(find.byKey(const Key('note_text')), 'unsaved');
      await tester.pump();
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('note_discard_confirm')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('note_text')), findsNothing);
      expect(actions.notes, isEmpty);
      expect(find.text('result: false'), findsOneWidget);
    });
  });

  group('adding a note from the list', () {
    testWidgets('the add sheet offers Write a note beside the file sources', (
      tester,
    ) async {
      await pumpList(tester);
      await tester.tap(find.byKey(const Key('documents_add_fab')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('upload_source_file')), findsOneWidget);
      expect(find.byKey(const Key('upload_source_photos')), findsOneWidget);
      expect(find.byKey(const Key('upload_source_camera')), findsOneWidget);
      expect(find.byKey(const Key('upload_source_note')), findsOneWidget);
      expect(find.text('Write a note'), findsOneWidget);
    });
  });
}
