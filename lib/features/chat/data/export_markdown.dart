import 'answer_segments.dart';
import 'chat_message.dart';

/// Turns a conversation into a Markdown document.
///
/// The shape follows the web client's export (`# Chat — <date>`, then
/// `## You` / `## Cerebro` per message, then a **Sources** section), with
/// citation markers turned into plain `[n]` footnotes numbered across the
/// whole conversation by first appearance — but two details differ on
/// purpose, both about keeping the output well-formed:
///
///  * Sources are a list (`- [1] Title`), not `[1]: Title`. In CommonMark
///    that second form is a *link reference definition*, so a one-word title
///    (`[1]: Notes`) renders as nothing at all.
///  * Message text is neutralised where it could break the document's own
///    structure — a line that reads as a heading or a horizontal rule, and a
///    code fence left open (which would swallow everything after it).
///
/// [documentTitle] supplies a title for a cited document id when the message
/// didn't carry one (a live conversation; a restored one does).
String exportConversationMarkdown({
  required DateTime startedAt,
  required List<ChatMessage> messages,
  String Function(String documentId)? documentTitle,
}) {
  final out = StringBuffer('# Chat — ${_formatDate(startedAt.toLocal())}\n\n');

  // chunk id → footnote number, and the title for each, in order.
  final numbers = <String, int>{};
  final sourceTitles = <String>[];

  for (final message in messages) {
    final isUser = message.role == ChatRole.user;
    out.write(isUser ? '## You\n\n' : '## Cerebro\n\n');

    var body = isUser
        ? message.text
        : _withFootnotes(message, numbers, sourceTitles, documentTitle);
    body = _neutralise(body.trim());
    if (body.isEmpty) body = isUser ? '_(empty)_' : '_(no answer)_';
    out.write('$body\n\n');

    if (!isUser) {
      if (message.status == ChatMessageStatus.stopped) {
        out.write('_(stopped before the answer finished)_\n\n');
      } else if (message.status == ChatMessageStatus.failed) {
        out.write('_(the answer did not finish)_\n\n');
      }
    }
  }

  if (sourceTitles.isNotEmpty) {
    out.write('---\n\n**Sources**\n\n');
    for (var i = 0; i < sourceTitles.length; i++) {
      out.write('- [${i + 1}] ${sourceTitles[i]}\n');
    }
  }

  return '${out.toString().trimRight()}\n';
}

/// The answer text with each backed `[[chunk:…]]` marker replaced by `[n]`.
/// A marker is kept only if the turn's retrieval set and its citations both
/// name the chunk — the same rule the screen applies — and is dropped
/// otherwise.
String _withFootnotes(
  ChatMessage message,
  Map<String, int> numbers,
  List<String> sourceTitles,
  String Function(String documentId)? documentTitle,
) {
  final buffer = StringBuffer();
  for (final segment in parseAnswerSegments(message.text)) {
    switch (segment) {
      case TextSegment(text: final piece):
        buffer.write(piece);
      case CitationSegment(:final chunkId):
        final documentId = message.citedDocuments[chunkId];
        if (documentId == null ||
            !message.retrievedChunkIds.contains(chunkId)) {
          continue;
        }
        var number = numbers[chunkId];
        if (number == null) {
          number = numbers[chunkId] = numbers.length + 1;
          sourceTitles.add(
            _cleanTitle(
              _firstUsable([
                message.citationTitles[documentId],
                documentTitle?.call(documentId),
              ]),
            ),
          );
        }
        buffer.write('[$number]');
    }
  }
  return buffer.toString();
}

/// The first title that is not blank; a placeholder if none is.
String _firstUsable(List<String?> candidates) {
  for (final candidate in candidates) {
    if (candidate != null && candidate.trim().isNotEmpty) return candidate;
  }
  return 'Source document';
}

/// One line, no brackets or backslashes that Markdown would read as syntax.
String _cleanTitle(String title) {
  final oneLine = title.replaceAll(RegExp(r'\s+'), ' ').trim();
  final escaped = oneLine.replaceAllMapped(
    RegExp(r'[\\\[\]]'),
    (m) => '\\${m[0]}',
  );
  return escaped.isEmpty ? 'Untitled' : escaped;
}

final RegExp _headingLine = RegExp(r'^\s{0,3}#{1,6}(\s|$)');
final RegExp _ruleLine = RegExp(r'^\s{0,3}([-*_])(\s*\1){2,}\s*$');
final RegExp _fenceLine = RegExp(r'^\s{0,3}(```|~~~)');

/// Stops message text from changing the document's own structure.
String _neutralise(String text) {
  final lines = text.split('\n');
  String? openFence;
  for (var i = 0; i < lines.length; i++) {
    final fence = _fenceLine.firstMatch(lines[i]);
    if (fence != null) {
      final marker = fence.group(1)!;
      if (openFence == null) {
        openFence = marker;
      } else if (marker == openFence) {
        openFence = null;
      }
      continue;
    }
    if (openFence != null) continue; // inside a code block: leave as written
    if (_headingLine.hasMatch(lines[i]) || _ruleLine.hasMatch(lines[i])) {
      final indent = lines[i].length - lines[i].trimLeft().length;
      lines[i] =
          '${lines[i].substring(0, indent)}\\${lines[i].substring(indent)}';
    }
  }
  var result = lines.join('\n');
  // A fence left open would swallow every message after this one.
  if (openFence != null) result = '$result\n$openFence';
  return result;
}

String _formatDate(DateTime d) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
}
