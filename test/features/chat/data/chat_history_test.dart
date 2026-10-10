import 'package:cerebro_mobile/features/chat/data/answer_segments.dart';
import 'package:cerebro_mobile/features/chat/data/chat_history_api.dart';
import 'package:cerebro_mobile/features/chat/data/chat_message.dart';
import 'package:cerebro_mobile/features/chat/data/resolved_answer.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _assistantRow({
  String content = 'The answer.[[chunk:c1]]',
  Object? chunks = const ['c1', 'c2'],
  Object? citations = const [
    {'chunk_id': 'c1', 'document_id': 'd1', 'document_title': 'notes.txt'},
  ],
}) => {
  'id': 'm2',
  'role': 'assistant',
  'content': content,
  'retrieved_chunk_ids': chunks,
  'citations': citations,
  'created_at': '2026-10-03T21:05:30.000Z',
};

void main() {
  group('ChatMessage.fromHistory', () {
    test('a user message', () {
      final m = ChatMessage.fromHistory({
        'id': 'm1',
        'role': 'user',
        'content': 'Who invented it?',
        'created_at': '2026-10-03T21:05:00.000Z',
      }, id: 0)!;

      expect(m.role, ChatRole.user);
      expect(m.text, 'Who invented it?');
      expect(m.createdAt, DateTime.utc(2026, 10, 3, 21, 5));
      expect(m.status, ChatMessageStatus.complete);
    });

    test('an assistant message carries its retrieval and server-resolved '
        'citations, with titles', () {
      final m = ChatMessage.fromHistory(_assistantRow(), id: 1)!;

      expect(m.role, ChatRole.assistant);
      expect(m.status, ChatMessageStatus.complete);
      expect(m.retrievalDone, isTrue);
      expect(m.retrievedChunkIds, {'c1', 'c2'});
      expect(m.citedDocuments, {'c1': 'd1'});
      expect(m.citationTitles, {'d1': 'notes.txt'});
    });

    test('a restored answer draws working chips through the same pipeline as '
        'a live one — no raw markers', () {
      final m = ChatMessage.fromHistory(
        _assistantRow(content: 'Yes.[[chunk:c1]] Also.[[chunk:ghost]]'),
        id: 1,
      )!;
      final parts = resolveAnswer(
        parseAnswerSegments(m.text),
        retrievedChunkIds: m.retrievedChunkIds,
        citedDocuments: m.citedDocuments,
      );

      expect(parts.whereType<ChipPart>().map((c) => c.documentId), ['d1']);
      expect(
        parts.whereType<TextPart>().map((p) => p.text).join(),
        'Yes. Also.',
      );
    });

    test(
      'an answer stored with no retrieved chunks reads as "found nothing"',
      () {
        final m = ChatMessage.fromHistory(
          _assistantRow(chunks: const [], citations: const []),
          id: 1,
        )!;
        expect(m.retrievalFoundNothing, isTrue);
      },
    );

    test('rows this client cannot use are skipped, not crashed on', () {
      expect(ChatMessage.fromHistory('nope', id: 0), isNull);
      expect(ChatMessage.fromHistory(null, id: 0), isNull);
      expect(
        ChatMessage.fromHistory({'role': 'system', 'content': 'x'}, id: 0),
        isNull,
      );
      expect(ChatMessage.fromHistory({'content': 'no role'}, id: 0), isNull);
    });

    test('missing or malformed fields degrade gracefully', () {
      final m = ChatMessage.fromHistory({
        'role': 'assistant',
        'content': null,
        'created_at': 'not a date',
        'retrieved_chunk_ids': 'oops',
        'citations': [
          'junk',
          {'chunk_id': 'c1'}, // no document
          {'chunk_id': 'c2', 'document_id': 'd2', 'document_title': '   '},
          {'chunk_id': 5, 'document_id': 'd3'},
        ],
      }, id: 3)!;

      expect(m.text, '');
      expect(m.createdAt, isNull);
      expect(m.retrievedChunkIds, isEmpty);
      expect(m.citedDocuments, {'c2': 'd2'});
      expect(m.citationTitles, isEmpty, reason: 'a blank title is no title');
    });

    test('non-string chunk ids are dropped from the retrieval set', () {
      final m = ChatMessage.fromHistory(
        _assistantRow(chunks: const ['c1', 7, null, 'c2']),
        id: 1,
      )!;
      expect(m.retrievedChunkIds, {'c1', 'c2'});
    });
  });

  group('ChatSessionSummary.fromJson', () {
    test('a full row', () {
      final s = ChatSessionSummary.fromJson({
        'id': 's1',
        'created_at': '2026-10-03T21:05:00.000Z',
        'preview': '  Who invented the Zanzibar Protocol?  ',
      })!;
      expect(s.id, 's1');
      expect(s.createdAt, DateTime.utc(2026, 10, 3, 21, 5));
      expect(s.preview, 'Who invented the Zanzibar Protocol?');
    });

    test('a conversation with no question has no preview', () {
      for (final preview in [null, '', '   ', 5]) {
        final s = ChatSessionSummary.fromJson({
          'id': 's1',
          'created_at': '2026-10-03T21:05:00.000Z',
          'preview': preview,
        })!;
        expect(s.preview, isNull, reason: 'preview: $preview');
      }
      expect(
        ChatSessionSummary.fromJson({
          'id': 's1',
          'created_at': '2026-10-03T21:05:00.000Z',
        })!.preview,
        isNull,
      );
    });

    test('a row without a usable id or date is skipped', () {
      expect(
        ChatSessionSummary.fromJson({'created_at': '2026-10-03T21:05:00Z'}),
        isNull,
      );
      expect(ChatSessionSummary.fromJson({'id': 's1'}), isNull);
      expect(
        ChatSessionSummary.fromJson({'id': 's1', 'created_at': 'x'}),
        isNull,
      );
      expect(ChatSessionSummary.fromJson('row'), isNull);
    });
  });
}
