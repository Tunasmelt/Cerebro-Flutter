import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Hands an exported conversation to the user. Behind an interface so
/// everything above it — formatting, fetching, error handling — is testable
/// without a platform share sheet.
abstract interface class ConversationExporter {
  /// Writes [markdown] to a file called [fileName] and offers it to the user
  /// (the system share sheet: save to Files, send, copy…).
  Future<void> export({required String fileName, required String markdown});
}

/// Hands a finished file to the platform share sheet.
typedef ShareFile = Future<void> Function(File file, String fileName);

Future<void> _systemShare(File file, String fileName) async {
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile(file.path, mimeType: 'text/markdown', name: fileName)],
      subject: 'Cerebro chat',
    ),
  );
}

/// Writes a temporary `.md` file and opens the platform share sheet on it.
///
/// The file holds the whole conversation, so it is deleted as soon as the
/// share sheet is done with it rather than left in the app cache.
class ShareConversationExporter implements ConversationExporter {
  const ShareConversationExporter({
    this.directory = getTemporaryDirectory,
    this.share = _systemShare,
  });

  final Future<Directory> Function() directory;
  final ShareFile share;

  @override
  Future<void> export({
    required String fileName,
    required String markdown,
  }) async {
    final dir = await directory();
    final file = File('${dir.path}${Platform.pathSeparator}$fileName');
    await file.writeAsString(markdown, flush: true);
    try {
      await share(file, fileName);
    } finally {
      try {
        if (await file.exists()) await file.delete();
      } on FileSystemException {
        // Best effort: the OS clears the cache directory eventually.
      }
    }
  }
}

/// `cerebro-chat-<first 8 of the id>.md`, as the web client names it.
String exportFileName(String sessionId) {
  final short = sessionId.length >= 8 ? sessionId.substring(0, 8) : sessionId;
  return 'cerebro-chat-$short.md';
}
