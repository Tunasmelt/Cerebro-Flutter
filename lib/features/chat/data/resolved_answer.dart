import 'answer_segments.dart';

/// What is actually drawn for an answer: text, and numbered citation chips
/// that each point at a real source document.
sealed class AnswerPart {
  const AnswerPart();
}

final class TextPart extends AnswerPart {
  const TextPart(this.text);
  final String text;

  @override
  bool operator ==(Object other) => other is TextPart && other.text == text;
  @override
  int get hashCode => text.hashCode;
  @override
  String toString() => 'Text($text)';
}

/// A citation chip: footnote [number], resolved to the document it cites.
final class ChipPart extends AnswerPart {
  const ChipPart({
    required this.number,
    required this.chunkId,
    required this.documentId,
  });

  final int number;
  final String chunkId;
  final String documentId;

  @override
  bool operator ==(Object other) =>
      other is ChipPart &&
      other.number == number &&
      other.chunkId == chunkId &&
      other.documentId == documentId;
  @override
  int get hashCode => Object.hash(number, chunkId, documentId);
  @override
  String toString() => 'Chip($number→$documentId)';
}

/// Turns parsed [segments] into drawable parts.
///
/// A marker becomes a chip **only if** its chunk id is both in
/// [retrievedChunkIds] (what retrieval actually returned for this turn) and in
/// [citedDocuments] (the server's own `citation` events: chunk id → document
/// id). Anything else — an id the model invented, one from a different turn —
/// is dropped silently: a chip pointing nowhere is worse than no chip. (The
/// server already filters its citation events to the retrieved set; checking
/// both here means a bug or protocol change on either side can't put a dead
/// chip on screen.)
///
/// Chips are numbered by first appearance, and the same chunk cited twice
/// keeps one number. Text either side of a dropped marker is joined back up.
List<AnswerPart> resolveAnswer(
  List<AnswerSegment> segments, {
  required Set<String> retrievedChunkIds,
  required Map<String, String> citedDocuments,
}) {
  final parts = <AnswerPart>[];
  final numbers = <String, int>{};

  void addText(String text) {
    if (text.isEmpty) return;
    if (parts.isNotEmpty && parts.last is TextPart) {
      parts[parts.length - 1] = TextPart((parts.last as TextPart).text + text);
    } else {
      parts.add(TextPart(text));
    }
  }

  for (final segment in segments) {
    switch (segment) {
      case TextSegment(:final text):
        addText(text);
      case CitationSegment(:final chunkId):
        final documentId = citedDocuments[chunkId];
        if (documentId == null || !retrievedChunkIds.contains(chunkId)) {
          continue; // would point nowhere: suppressed
        }
        final number = numbers.putIfAbsent(chunkId, () => numbers.length + 1);
        parts.add(
          ChipPart(number: number, chunkId: chunkId, documentId: documentId),
        );
    }
  }
  return parts;
}

/// One source document under an answer: every footnote number that cites it.
final class CitedSource {
  const CitedSource({required this.documentId, required this.numbers});

  final String documentId;
  final List<int> numbers;
}

/// The distinct documents an answer cites, in order of first citation.
List<CitedSource> sourcesOf(List<AnswerPart> parts) {
  final order = <String>[];
  final numbers = <String, List<int>>{};
  for (final part in parts.whereType<ChipPart>()) {
    final list = numbers.putIfAbsent(part.documentId, () {
      order.add(part.documentId);
      return <int>[];
    });
    if (!list.contains(part.number)) list.add(part.number);
  }
  return [
    for (final id in order) CitedSource(documentId: id, numbers: numbers[id]!),
  ];
}
