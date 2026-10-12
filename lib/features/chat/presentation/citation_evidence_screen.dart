import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/app_routes.dart';
import '../../../core/network/app_exception.dart';
import '../../../shared/tokens/app_colors.dart';
import '../../../shared/widgets/error_view.dart';
import '../../auth/data/current_user_provider.dart';
import '../data/citation_evidence.dart';

class CitationEvidenceScreen extends ConsumerWidget {
  const CitationEvidenceScreen({super.key, required this.chunkId});
  final String chunkId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final owner = ref.watch(currentUserIdProvider);
    final evidenceState = owner == null
        ? null
        : ref.watch(citationEvidenceProvider(chunkId));
    final loadedDocument = evidenceState?.asData?.value['document'] as Map?;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Source evidence'),
        actions: [
          if (loadedDocument != null)
            IconButton(
              tooltip: 'Open full document',
              icon: const Icon(Icons.open_in_new),
              onPressed: () => context.go(
                AppRoutes.documentPreview(loadedDocument['id'] as String),
              ),
            ),
        ],
      ),
      body: owner == null
          ? const Center(child: Text('Sign in to view evidence.'))
          : evidenceState!.when(
              skipLoadingOnReload: false,
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => ErrorView(
                exception: error is AppException
                    ? error
                    : const UnknownApiException(),
                expanded: true,
                onRetry: () =>
                    ref.invalidate(citationEvidenceProvider(chunkId)),
              ),
              data: (evidence) {
                final document = evidence['document'] as Map;
                final region = evidence['region'] as Map?;
                final excerpt = region?['content'] ?? evidence['content'];
                final url = evidence['render_url'] as String?;
                final page = (evidence['surface'] as Map?)?['page_number'];
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      document['title'] as String? ?? 'Source',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    if (page != null) Text('Page $page'),
                    if (evidence['legacy'] == true)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'This older source has no region coordinates. The citation identifies the excerpt or whole image.',
                        ),
                      ),
                    if (url != null)
                      ref
                          .watch(evidenceImageProvider(url))
                          .when(
                            loading: () => const Center(
                              child: CircularProgressIndicator(),
                            ),
                            error: (_, _) => const Text(
                              'The source image could not be loaded. The excerpt remains below.',
                            ),
                            data: (bytes) => _EvidenceImage(
                              key: ObjectKey(bytes),
                              bytes: bytes,
                              bbox: region?['bbox'] as List?,
                            ),
                          ),
                    if (excerpt is String && excerpt.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: SelectableText(
                          excerpt,
                          key: const Key('citation_excerpt'),
                        ),
                      ),
                    if (url == null && (excerpt == null || excerpt == ''))
                      const Text(
                        'No excerpt or image is available for this source.',
                      ),
                    TextButton.icon(
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('Open full document'),
                      onPressed: () => context.go(
                        AppRoutes.documentPreview(document['id'] as String),
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}

class _EvidenceImage extends StatefulWidget {
  const _EvidenceImage({super.key, required this.bytes, this.bbox});
  final Uint8List bytes;
  final List? bbox;
  @override
  State<_EvidenceImage> createState() => _EvidenceImageState();
}

class _EvidenceImageState extends State<_EvidenceImage> {
  late final image = MemoryImage(widget.bytes);
  @override
  void dispose() {
    image.evict();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bbox = widget.bbox;
    final valid =
        bbox != null &&
        bbox.length == 4 &&
        bbox.every((n) => n is num && n.isFinite && n >= 0 && n <= 1) &&
        bbox[2] > bbox[0] &&
        bbox[3] > bbox[1];
    return InteractiveViewer(
      child: Stack(
        children: [
          Image(
            image: image,
            errorBuilder: (_, _, _) =>
                const Text('Cannot display source image.'),
          ),
          if (valid)
            Positioned.fill(
              child: LayoutBuilder(
                builder: (context, size) => Stack(
                  children: [
                    Positioned(
                      left: (bbox[0] as num).toDouble() * size.maxWidth,
                      top: (bbox[1] as num).toDouble() * size.maxHeight,
                      width:
                          ((bbox[2] as num) - (bbox[0] as num)).toDouble() *
                          size.maxWidth,
                      height:
                          ((bbox[3] as num) - (bbox[1] as num)).toDouble() *
                          size.maxHeight,
                      child: IgnorePointer(
                        child: Container(
                          key: const Key('citation_region_highlight'),
                          decoration: BoxDecoration(
                            color: AppColors.accentSecondary.withValues(
                              alpha: 0.15,
                            ),
                            border: Border.all(
                              color: AppColors.accentSecondary,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
