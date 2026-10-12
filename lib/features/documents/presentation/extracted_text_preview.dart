import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/app_exception.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/app_markdown.dart';
import '../../auth/data/current_user_provider.dart';
import '../../graph/data/graph_api.dart';

final extractedTextPreviewProvider = FutureProvider.autoDispose
    .family<String, String>((ref, id) async {
      if (ref.watch(currentUserIdProvider) == null) {
        throw const UnauthorizedException();
      }
      final chunks = await ref.watch(graphApiProvider).chunks(id);
      return chunks.map((chunk) => chunk.content).join('\n\n');
    });

/// Captured thoughts have no original Storage object. Use the existing,
/// authenticated reading-order chunks endpoint rather than inventing a file.
class ExtractedTextPreview extends ConsumerWidget {
  const ExtractedTextPreview({super.key, required this.documentId});
  final String documentId;
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(extractedTextPreviewProvider(documentId))
      .when(
        skipLoadingOnReload: false,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorView(
          exception: error is AppException
              ? error
              : const UnknownApiException(),
          expanded: true,
          onRetry: () =>
              ref.invalidate(extractedTextPreviewProvider(documentId)),
        ),
        data: (text) => text.trim().isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'No preview is available yet. Open Document details to check its status.',
                  ),
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Extracted text'),
                    const SizedBox(height: 16),
                    AppMarkdown(data: text),
                  ],
                ),
              ),
      );
}
