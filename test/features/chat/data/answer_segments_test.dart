import 'package:cerebro_mobile/features/chat/data/answer_segments.dart';
import 'package:cerebro_mobile/features/chat/data/resolved_answer.dart';
import 'package:flutter_test/flutter_test.dart';

String visible(List<AnswerSegment> segments) =>
    segments.whereType<TextSegment>().map((s) => s.text).join();

void main() {
  group('parseAnswerSegments', () {
    test('plain text is one segment', () {
      expect(parseAnswerSegments('hello world'), [
        const TextSegment('hello world'),
      ]);
    });

    test('empty text is no segments', () {
      expect(parseAnswerSegments(''), isEmpty);
    });

    test('a marker splits text around it', () {
      expect(parseAnswerSegments('Cerebro is a graph.[[chunk:c1]] It works.'), [
        const TextSegment('Cerebro is a graph.'),
        const CitationSegment('c1'),
        const TextSegment(' It works.'),
      ]);
    });

    test('back-to-back markers (the instructed multi-cite form)', () {
      expect(parseAnswerSegments('Claim.[[chunk:a]][[chunk:b]]'), [
        const TextSegment('Claim.'),
        const CitationSegment('a'),
        const CitationSegment('b'),
      ]);
    });

    test('the malformed multi-id group the model sometimes writes becomes '
        'one citation per id', () {
      expect(parseAnswerSegments('Claim.[[chunk:a], [chunk:b]] Next.'), [
        const TextSegment('Claim.'),
        const CitationSegment('a'),
        const CitationSegment('b'),
        const TextSegment(' Next.'),
      ]);
      expect(parseAnswerSegments('x[[chunk:a],[chunk:b], [chunk:c]]'), [
        const TextSegment('x'),
        const CitationSegment('a'),
        const CitationSegment('b'),
        const CitationSegment('c'),
      ]);
    });

    test('real uuid ids with dashes', () {
      const id = '3f9a1c2e-7b44-4d0e-9a55-0c1d2e3f4a5b';
      expect(parseAnswerSegments('Yes.[[chunk:$id]]'), [
        const TextSegment('Yes.'),
        const CitationSegment(id),
      ]);
    });

    test('an ordinary bracket is not a marker', () {
      expect(parseAnswerSegments('See [1] and [[not a chunk]] too.'), [
        const TextSegment('See [1] and [[not a chunk]] too.'),
      ]);
    });

    test(
      'an unterminated marker at the end is dropped, even when complete',
      () {
        expect(parseAnswerSegments('Done.[[chunk:3f9a'), [
          const TextSegment('Done.'),
        ]);
      },
    );
  });

  group(
    'while streaming, a marker cut off by a token boundary is held back',
    () {
      const cuts = [
        'The answer is 42.[',
        'The answer is 42.[[',
        'The answer is 42.[[c',
        'The answer is 42.[[chu',
        'The answer is 42.[[chunk',
        'The answer is 42.[[chunk:',
        'The answer is 42.[[chunk:3f9a-12',
        'The answer is 42.[[chunk:3f9a-12]',
      ];
      for (final partial in cuts) {
        test('"…${partial.substring(17)}"', () {
          expect(
            visible(parseAnswerSegments(partial, streaming: true)),
            'The answer is 42.',
          );
        });
      }

      test(
        'a lone "[" that turns out to be ordinary text appears once the next '
        'token shows it is not a marker',
        () {
          expect(
            visible(parseAnswerSegments('Items [', streaming: true)),
            'Items ',
          );
          expect(
            visible(
              parseAnswerSegments('Items [1] are listed', streaming: true),
            ),
            'Items [1] are listed',
          );
        },
      );

      test(
        'once streaming ends, a trailing lone "[" is kept (it is just text)',
        () {
          expect(visible(parseAnswerSegments('Items [')), 'Items [');
        },
      );
    },
  );

  group('for EVERY possible token boundary of a real-looking answer', () {
    const answer =
        'Cerebro keeps your notes as a graph.[[chunk:c1]] Documents are '
        'chunked and embedded.[[chunk:c2]][[chunk:c3]] Sealed documents are '
        'encrypted.[[chunk:c4], [chunk:c5]] See [1] for details [in the docs].';

    test('raw marker syntax never reaches the screen', () {
      for (var k = 0; k <= answer.length; k++) {
        final shown = visible(
          parseAnswerSegments(answer.substring(0, k), streaming: true),
        );
        expect(shown, isNot(contains('[[')), reason: 'prefix of length $k');
        expect(shown, isNot(contains('chunk:')), reason: 'prefix of length $k');
      }
    });

    test('the visible text only ever grows — it never jumps backwards or '
        'rewrites what is already shown', () {
      var previous = '';
      for (var k = 0; k <= answer.length; k++) {
        final shown = visible(
          parseAnswerSegments(answer.substring(0, k), streaming: true),
        );
        expect(
          shown.startsWith(previous),
          isTrue,
          reason: 'at $k: "$shown" does not extend "$previous"',
        );
        previous = shown;
      }
      expect(
        previous,
        'Cerebro keeps your notes as a graph. Documents are chunked and '
        'embedded. Sealed documents are encrypted. See [1] for details [in the docs].',
      );
    });

    test('once complete, every marker is a citation and nothing is lost', () {
      final segments = parseAnswerSegments(answer);
      expect(
        [for (final s in segments.whereType<CitationSegment>()) s.chunkId],
        ['c1', 'c2', 'c3', 'c4', 'c5'],
      );
    });
  });

  group('resolveAnswer — a chip never points nowhere', () {
    final segments = parseAnswerSegments(
      'One.[[chunk:c1]] Two.[[chunk:ghost]] Three.[[chunk:c2]] Again.[[chunk:c1]]',
    );

    test('every marker the server backs becomes a numbered chip', () {
      final parts = resolveAnswer(
        parseAnswerSegments('A.[[chunk:c1]] B.[[chunk:c2]]'),
        retrievedChunkIds: {'c1', 'c2'},
        citedDocuments: {'c1': 'docA', 'c2': 'docB'},
      );
      expect(parts, [
        const TextPart('A.'),
        const ChipPart(number: 1, chunkId: 'c1', documentId: 'docA'),
        const TextPart(' B.'),
        const ChipPart(number: 2, chunkId: 'c2', documentId: 'docB'),
      ]);
    });

    test(
      'a citation naming a chunk outside the retrieval set is suppressed',
      () {
        // "ghost" is in the server's citation events here (a protocol bug), but
        // retrieval never returned it: no chip.
        final parts = resolveAnswer(
          segments,
          retrievedChunkIds: {'c1', 'c2'},
          citedDocuments: {'c1': 'docA', 'c2': 'docB', 'ghost': 'docX'},
        );
        expect(parts.whereType<ChipPart>().map((c) => c.chunkId), [
          'c1',
          'c2',
          'c1',
        ]);
        expect(
          parts.whereType<ChipPart>().any((c) => c.documentId == 'docX'),
          isFalse,
        );
      },
    );

    test('a marker with no matching citation event is suppressed', () {
      final parts = resolveAnswer(
        segments,
        retrievedChunkIds: {'c1', 'c2', 'ghost'},
        citedDocuments: {'c1': 'docA', 'c2': 'docB'}, // no event for ghost
      );
      expect(
        parts.whereType<ChipPart>().any((c) => c.chunkId == 'ghost'),
        isFalse,
      );
    });

    test('with nothing retrieved, no chip appears at all', () {
      final parts = resolveAnswer(
        segments,
        retrievedChunkIds: {},
        citedDocuments: {'c1': 'docA'},
      );
      expect(parts.whereType<ChipPart>(), isEmpty);
    });

    test(
      'the text around a dropped marker is joined back up, with no raw marker',
      () {
        final parts = resolveAnswer(
          parseAnswerSegments('Before.[[chunk:ghost]] After.'),
          retrievedChunkIds: {},
          citedDocuments: {},
        );
        expect(parts, [const TextPart('Before. After.')]);
      },
    );

    test('the same chunk cited twice keeps one number', () {
      final parts = resolveAnswer(
        segments,
        retrievedChunkIds: {'c1', 'c2'},
        citedDocuments: {'c1': 'docA', 'c2': 'docB'},
      );
      expect(parts.whereType<ChipPart>().map((c) => c.number), [1, 2, 1]);
    });
  });

  group('sourcesOf', () {
    test(
      'distinct documents in order of first citation, with their numbers',
      () {
        final parts = resolveAnswer(
          parseAnswerSegments(
            'a[[chunk:c1]]b[[chunk:c2]]c[[chunk:c3]]d[[chunk:c1]]',
          ),
          retrievedChunkIds: {'c1', 'c2', 'c3'},
          citedDocuments: {'c1': 'docA', 'c2': 'docB', 'c3': 'docA'},
        );
        final sources = sourcesOf(parts);
        expect([for (final s in sources) s.documentId], ['docA', 'docB']);
        expect(sources[0].numbers, [1, 3]);
        expect(sources[1].numbers, [2]);
      },
    );

    test('an answer with no chips has no sources', () {
      expect(sourcesOf([const TextPart('hi')]), isEmpty);
    });
  });
}
