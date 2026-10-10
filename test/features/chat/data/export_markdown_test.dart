import 'package:cerebro_mobile/features/chat/data/chat_message.dart';
import 'package:cerebro_mobile/features/chat/data/export_markdown.dart';
import 'package:flutter_test/flutter_test.dart';

final _start = DateTime(
  2026,
  10,
  3,
  21,
  5,
); // local time, as the app formats it

ChatMessage _you(int id, String text) => ChatMessage.user(id: id, text: text);

ChatMessage _cerebro(
  int id,
  String text, {
  Map<String, String> cited = const {},
  Map<String, String> titles = const {},
  Set<String>? retrieved,
  ChatMessageStatus status = ChatMessageStatus.complete,
}) => ChatMessage(
  id: id,
  role: ChatRole.assistant,
  text: text,
  status: status,
  retrievalDone: true,
  retrievedChunkIds: retrieved ?? cited.keys.toSet(),
  citedDocuments: cited,
  citationTitles: titles,
);

String export(List<ChatMessage> messages, {String Function(String)? title}) =>
    exportConversationMarkdown(
      startedAt: _start,
      messages: messages,
      documentTitle: title,
    );

void main() {
  group('structure', () {
    test('a small cited conversation, exactly', () {
      final md = export([
        _you(0, 'Who invented it?'),
        _cerebro(
          1,
          'Dr. Quartermain.[[chunk:c1]]',
          cited: {'c1': 'd1'},
          titles: {'d1': 'zanzibar-notes.txt'},
        ),
      ]);

      expect(
        md,
        '# Chat — 2026-10-03 21:05\n'
        '\n'
        '## You\n'
        '\n'
        'Who invented it?\n'
        '\n'
        '## Cerebro\n'
        '\n'
        'Dr. Quartermain.[1]\n'
        '\n'
        '---\n'
        '\n'
        '**Sources**\n'
        '\n'
        '- [1] zanzibar-notes.txt\n',
      );
    });

    test('ends with exactly one newline, however it ends', () {
      expect(export([_you(0, 'hi')]).endsWith('hi\n'), isTrue);
      expect(export([_you(0, 'hi')]).endsWith('\n\n'), isFalse);
      final cited = export([
        _cerebro(1, 'x[[chunk:c1]]', cited: {'c1': 'd1'}, titles: {'d1': 'T'}),
      ]);
      expect(cited.endsWith('\n'), isTrue);
      expect(cited.endsWith('\n\n'), isFalse);
    });

    test('an empty conversation is just the header', () {
      expect(export([]), '# Chat — 2026-10-03 21:05\n');
    });

    test('no Sources section when nothing was cited', () {
      final md = export([_you(0, 'hi'), _cerebro(1, 'hello')]);
      expect(md, isNot(contains('**Sources**')));
      expect(md, isNot(contains('---')));
    });

    test('an empty question or answer still reads sensibly', () {
      final md = export([_you(0, '   '), _cerebro(1, '')]);
      expect(md, contains('_(empty)_'));
      expect(md, contains('_(no answer)_'));
    });

    test('a stopped or failed answer is marked as unfinished', () {
      final stopped = export([
        _cerebro(0, 'Half an ans', status: ChatMessageStatus.stopped),
      ]);
      expect(stopped, contains('Half an ans'));
      expect(stopped, contains('stopped before the answer finished'));
      final failed = export([
        _cerebro(0, 'Some', status: ChatMessageStatus.failed),
      ]);
      expect(failed, contains('did not finish'));
    });
  });

  group('citations', () {
    test('numbered across the WHOLE conversation by first appearance; the '
        'same chunk keeps its number', () {
      final md = export([
        _you(0, 'q1'),
        _cerebro(
          1,
          'A.[[chunk:c1]] B.[[chunk:c2]]',
          cited: {'c1': 'd1', 'c2': 'd2'},
          titles: {'d1': 'First', 'd2': 'Second'},
        ),
        _you(2, 'q2'),
        _cerebro(
          3,
          'C.[[chunk:c2]] D.[[chunk:c3]]',
          cited: {'c2': 'd2', 'c3': 'd3'},
          titles: {'d2': 'Second', 'd3': 'Third'},
        ),
      ]);

      expect(md, contains('A.[1] B.[2]'));
      expect(md, contains('C.[2] D.[3]'));
      expect(md, contains('- [1] First\n- [2] Second\n- [3] Third\n'));
    });

    test('back-to-back markers become back-to-back footnotes', () {
      final md = export([
        _cerebro(
          0,
          'Claim.[[chunk:a]][[chunk:b]]',
          cited: {'a': 'd1', 'b': 'd2'},
          titles: {'d1': 'A', 'd2': 'B'},
        ),
      ]);
      expect(md, contains('Claim.[1][2]'));
    });

    test('a marker the server did not back is removed, never exported raw', () {
      final md = export([
        _cerebro(
          0,
          'Real.[[chunk:c1]] Invented.[[chunk:ghost]] End.',
          cited: {'c1': 'd1'},
          titles: {'d1': 'T'},
        ),
      ]);
      expect(md, contains('Real.[1] Invented. End.'));
      expect(md, isNot(contains('ghost')));
    });

    test('a chunk outside the retrieval set is not a footnote', () {
      final md = export([
        _cerebro(
          0,
          'A.[[chunk:c1]]',
          cited: {'c1': 'd1'},
          titles: {'d1': 'T'},
          retrieved: {'other'},
        ),
      ]);
      expect(md, contains('A.'));
      expect(md, isNot(contains('[1]')));
      expect(md, isNot(contains('**Sources**')));
    });

    test('raw marker syntax never appears anywhere in the export', () {
      final md = export([
        _cerebro(
          0,
          'x[[chunk:c1]] y[[chunk:c2], [chunk:c3]] z[[chunk:ghost]] [[chunk:cut',
          cited: {'c1': 'd1', 'c2': 'd1', 'c3': 'd2'},
          titles: {'d1': 'One', 'd2': 'Two'},
        ),
      ]);
      expect(md, isNot(contains('[[')));
      expect(md, isNot(contains('chunk:')));
    });

    test(
      'titles come from the message, else the callback, else a fallback',
      () {
        final md = export([
          _cerebro(
            0,
            'a[[chunk:c1]] b[[chunk:c2]] c[[chunk:c3]]',
            cited: {'c1': 'd1', 'c2': 'd2', 'c3': 'd3'},
            titles: {'d1': 'From the server'},
          ),
        ], title: (id) => id == 'd2' ? 'From the list' : 'ignored');
        expect(md, contains('- [1] From the server\n'));
        expect(md, contains('- [2] From the list\n'));
        expect(md, contains('- [3] ignored\n'));

        final fallback = export([
          _cerebro(0, 'a[[chunk:c1]]', cited: {'c1': 'd1'}),
        ]);
        expect(fallback, contains('- [1] Source document\n'));
      },
    );
  });

  group('the output stays well-formed Markdown', () {
    test('sources are a list, never "[1]: Title" — that is a link reference '
        'definition and a one-word title would vanish when rendered', () {
      final md = export([
        _cerebro(
          0,
          'a[[chunk:c1]]',
          cited: {'c1': 'd1'},
          titles: {'d1': 'Notes'},
        ),
      ]);
      expect(RegExp(r'^\[\d+\]:', multiLine: true).hasMatch(md), isFalse);
      expect(md, contains('- [1] Notes'));
    });

    test('a title with brackets, backslashes or newlines is one safe line', () {
      final md = export([
        _cerebro(
          0,
          'a[[chunk:c1]]',
          cited: {'c1': 'd1'},
          titles: {'d1': 'Q3 [draft]\nfinal\\copy   v2'},
        ),
      ]);
      expect(md, contains(r'- [1] Q3 \[draft\] final\\copy v2'));
      expect(md.split('\n').where((l) => l.startsWith('- [1]')), hasLength(1));
    });

    test('a blank or whitespace title counts as missing', () {
      final md = export([
        _cerebro(
          0,
          'a[[chunk:c1]]',
          cited: {'c1': 'd1'},
          titles: {'d1': ' \n '},
        ),
      ]);
      expect(
        md,
        contains('- [1] Source document'),
        reason: 'a blank server title is ignored, the fallback is used',
      );
    });

    test('message text cannot add headings of its own', () {
      final md = export([
        _you(0, '## You\nfake heading\n# Title'),
        _cerebro(1, 'Intro\n## Cerebro\n###### deep'),
      ]);
      final headings = md
          .split('\n')
          .where((l) => RegExp(r'^#{1,6}\s').hasMatch(l))
          .toList();
      expect(headings, [
        '# Chat — 2026-10-03 21:05',
        '## You',
        '## Cerebro',
      ], reason: 'only the real structure remains');
      expect(md, contains(r'\## You'));
    });

    test('message text cannot add a horizontal rule (which would read as '
        'the end of the conversation)', () {
      final md = export([_you(0, 'before\n---\nafter\n***\n___\n- - -')]);
      for (final line in md.split('\n')) {
        expect(
          RegExp(r'^\s{0,3}([-*_])(\s*\1){2,}\s*$').hasMatch(line),
          isFalse,
          reason: 'unescaped rule: "$line"',
        );
      }
    });

    test('an unclosed code fence is closed so it cannot swallow the rest', () {
      final md = export([
        _cerebro(0, 'Run this:\n```bash\nls -la'),
        _you(1, 'thanks'),
      ]);
      final fences = md.split('\n').where((l) => l.startsWith('```')).length;
      expect(fences.isEven, isTrue, reason: 'odd number of fences:\n$md');
      expect(md, contains('## You'));
    });

    test(
      'a balanced code block is left exactly as written, headings and all',
      () {
        const code = '```\n# not a heading\n---\n```';
        final md = export([_cerebro(0, 'Look:\n$code')]);
        expect(md, contains(code));
      },
    );

    test('text with ordinary markdown is passed through untouched', () {
      final md = export([
        _cerebro(0, 'Use **bold**, a list:\n- one\n- two\nand `code`.'),
      ]);
      expect(md, contains('Use **bold**, a list:\n- one\n- two\nand `code`.'));
    });
  });

  group('the date', () {
    test('is formatted in local time, zero-padded', () {
      final md = exportConversationMarkdown(
        startedAt: DateTime(2026, 1, 2, 3, 4),
        messages: const [],
      );
      expect(md, startsWith('# Chat — 2026-01-02 03:04\n'));
    });
  });
}
