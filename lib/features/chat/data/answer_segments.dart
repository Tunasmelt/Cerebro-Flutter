/// The answer text the model streams back carries its citations inline, as
/// `[[chunk:<id>]]` markers (chat/prompt.py). This is the client half of
/// that contract — it never lets raw marker syntax reach the screen.
///
/// Mirrors the backend's and the web client's parsing exactly (the same
/// non-greedy `\[\[chunk:(.+?)\]\]`, the same split of the malformed
/// multi-id group the model sometimes writes — `[[chunk:id1], [chunk:id2]]` —
/// into one citation per id), because all three must recognise the same
/// syntax.
sealed class AnswerSegment {
  const AnswerSegment();
}

final class TextSegment extends AnswerSegment {
  const TextSegment(this.text);
  final String text;

  @override
  bool operator ==(Object other) => other is TextSegment && other.text == text;
  @override
  int get hashCode => text.hashCode;
  @override
  String toString() => 'Text($text)';
}

final class CitationSegment extends AnswerSegment {
  const CitationSegment(this.chunkId);
  final String chunkId;

  @override
  bool operator ==(Object other) =>
      other is CitationSegment && other.chunkId == chunkId;
  @override
  int get hashCode => chunkId.hashCode;
  @override
  String toString() => 'Cite($chunkId)';
}

final RegExp _marker = RegExp(r'\[\[chunk:(.+?)\]\]');
final RegExp _groupSplit = RegExp(r'\]\s*,\s*\[chunk:');
const String _markerOpen = '[[chunk:';

List<String> _splitIds(String inner) => [
  for (final part in inner.split(_groupSplit))
    if (part.trim().isNotEmpty) part.trim(),
];

/// Splits [text] into text and citation segments.
///
/// While the answer is still arriving ([streaming]) a marker can be cut off
/// mid-way — by a token boundary, so the text so far may end in `[`, `[[ch`,
/// or `[[chunk:3f9a` with no closing `]]`. Those fragments are held back
/// (not shown) until the marker completes; otherwise the screen would flash
/// half a marker. An unterminated `[[chunk:` tail is dropped even once the
/// answer is complete: the backend's parser doesn't match it either, so it
/// was never a citation and is never worth showing.
List<AnswerSegment> parseAnswerSegments(String text, {bool streaming = false}) {
  final segments = <AnswerSegment>[];
  var last = 0;
  for (final match in _marker.allMatches(text)) {
    if (match.start > last) {
      segments.add(TextSegment(text.substring(last, match.start)));
    }
    for (final id in _splitIds(match.group(1)!)) {
      segments.add(CitationSegment(id));
    }
    last = match.end;
  }
  if (last < text.length) {
    final tail = _withoutPartialMarker(text.substring(last), streaming);
    if (tail.isNotEmpty) segments.add(TextSegment(tail));
  }
  return segments;
}

String _withoutPartialMarker(String tail, bool streaming) {
  final open = tail.lastIndexOf(_markerOpen);
  if (open != -1) return tail.substring(0, open); // unterminated marker
  if (!streaming) return tail;
  // Not yet a whole "[[chunk:" — but may be the beginning of one.
  for (var k = _markerOpen.length - 1; k >= 1; k--) {
    if (tail.endsWith(_markerOpen.substring(0, k))) {
      return tail.substring(0, tail.length - k);
    }
  }
  return tail;
}
