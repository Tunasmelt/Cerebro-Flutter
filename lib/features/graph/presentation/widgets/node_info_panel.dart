import 'package:flutter/material.dart';

import '../../../../core/network/app_exception.dart';
import '../../../../shared/tokens/app_colors.dart';
import '../../../../shared/tokens/app_radius.dart';
import '../../../../shared/tokens/app_spacing.dart';
import '../../../../shared/tokens/app_typography.dart';
import '../../data/graph_expansion.dart';
import '../../data/graph_models.dart';
import '../models/graph_node.dart';

/// The most of one chunk's text the panel will lay out. A single chunk can be
/// tens of thousands of characters (a whole section of a Markdown file).
const int maxChunkTextChars = 6000;

/// What the expanded node is, and what it holds: its chunks as a list, the
/// selected chunk's text, and the actions.
///
/// Not modal — unlike a bottom sheet it leaves the graph above it live, so a
/// user can keep panning, zooming and tapping other nodes while it is open.
/// Adapted from Brain.tsx's side panel; a bottom panel is the phone-native
/// shape for it.
class NodeInfoPanel extends StatelessWidget {
  const NodeInfoPanel({
    super.key,
    required this.node,
    required this.expansion,
    required this.onClose,
    required this.onRetry,
    required this.onSelectChunk,
    required this.onChatAboutThis,
    required this.onOpenInDocuments,
  });

  final GraphNodeData node;
  final GraphExpansion expansion;
  final VoidCallback onClose;
  final VoidCallback onRetry;
  final ValueChanged<String> onSelectChunk;
  final VoidCallback onChatAboutThis;
  final VoidCallback onOpenInDocuments;

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.5;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: DecoratedBox(
        key: const Key('node_panel'),
        decoration: const BoxDecoration(
          color: AppColors.bgElevated,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.lg),
          ),
          border: Border(top: BorderSide(color: AppColors.borderSubtle)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.s4,
            AppSpacing.s3,
            AppSpacing.s4,
            AppSpacing.s3,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Header(node: node, onClose: onClose),
              const SizedBox(height: AppSpacing.s2),
              Flexible(
                child: _Body(
                  node: node,
                  expansion: expansion,
                  onRetry: onRetry,
                  onSelectChunk: onSelectChunk,
                ),
              ),
              const SizedBox(height: AppSpacing.s3),
              Row(
                children: [
                  Expanded(
                    child: _PanelAction(
                      key: const Key('node_chat'),
                      label: 'Chat about this',
                      highlighted: true,
                      onTap: onChatAboutThis,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s2),
                  Expanded(
                    child: _PanelAction(
                      key: const Key('node_open'),
                      label: 'Open in Documents',
                      onTap: onOpenInDocuments,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.node, required this.onClose});

  final GraphNodeData node;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                node.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.md.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: AppTypography.weightMedium,
                ),
              ),
              const SizedBox(height: AppSpacing.s1),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: node.type.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s2),
                  Text(
                    node.type.label,
                    style: AppTypography.sm.copyWith(color: node.type.color),
                  ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(
          width: AppSpacing.minTouchTarget,
          height: AppSpacing.minTouchTarget,
          child: IconButton(
            key: const Key('node_close'),
            tooltip: 'Collapse',
            padding: EdgeInsets.zero,
            icon: const Icon(Icons.close, color: AppColors.grayDim),
            onPressed: onClose,
          ),
        ),
      ],
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.node,
    required this.expansion,
    required this.onRetry,
    required this.onSelectChunk,
  });

  final GraphNodeData node;
  final GraphExpansion expansion;
  final VoidCallback onRetry;
  final ValueChanged<String> onSelectChunk;

  Widget _status(String text, {Key? key, Widget? trailing}) => Row(
    key: key,
    children: [
      Expanded(
        child: Text(
          text,
          style: AppTypography.sm.copyWith(color: AppColors.textSecondary),
        ),
      ),
      ?trailing,
    ],
  );

  @override
  Widget build(BuildContext context) {
    switch (expansion.load) {
      case ChunkLoad.loading:
        return Row(
          key: const Key('node_loading'),
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: AppSpacing.s2),
            Text(
              'Loading chunks…',
              style: AppTypography.sm.copyWith(color: AppColors.textSecondary),
            ),
          ],
        );
      case ChunkLoad.failed:
        final error = expansion.error;
        final gone =
            error is RequestRejectedException && error.code == 'not_found';
        return _status(
          gone
              ? 'This document no longer exists. Refresh the graph.'
              : (error?.message ?? "Couldn't load this document's chunks."),
          key: const Key('node_chunks_error'),
          trailing: gone
              ? null
              : TextButton(
                  key: const Key('node_retry'),
                  onPressed: onRetry,
                  child: const Text('Retry'),
                ),
        );
      case ChunkLoad.loaded:
        break;
    }

    final chunks = expansion.chunks;
    if (chunks.isEmpty) {
      return _status(
        node.type == GraphNodeType.sealed
            ? "Sealed — this document's chunks are not shown."
            : 'This document has no chunks.',
        key: const Key('node_no_chunks'),
      );
    }

    final selected = expansion.selectedChunk;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          key: const Key('node_chunk_count'),
          '${chunks.length} ${chunks.length == 1 ? 'chunk' : 'chunks'}',
          style: AppTypography.sm.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.s2),
        if (selected != null) ...[
          _SelectedChunk(chunk: selected),
          const SizedBox(height: AppSpacing.s2),
        ],
        Flexible(
          flex: 2,
          child: ListView.builder(
            key: const Key('node_chunk_list'),
            // No inherited inset: a ListView would otherwise pad its top by the
            // status-bar height, leaving a gap above the first row.
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            itemCount: chunks.length,
            itemBuilder: (context, i) => _ChunkRow(
              chunk: chunks[i],
              number: i + 1,
              selected: chunks[i].id == expansion.selectedChunkId,
              onTap: () => onSelectChunk(chunks[i].id),
            ),
          ),
        ),
      ],
    );
  }
}

String _where(DocumentChunk c) =>
    [if (c.page != null) 'Page ${c.page}', ?c.regionType].join(' · ');

class _SelectedChunk extends StatelessWidget {
  const _SelectedChunk({required this.chunk});

  final DocumentChunk chunk;

  @override
  Widget build(BuildContext context) {
    final text = chunk.content.trim();
    final cut = text.length > maxChunkTextChars;
    final where = _where(chunk);
    // Flexible (one part to the list's two), so in a short panel the selected
    // text gives way — it scrolls — rather than overflowing or squeezing the
    // list out.
    return Flexible(
      flex: 1,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 140),
        child: Container(
          key: const Key('node_selected_chunk'),
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.s3),
          decoration: BoxDecoration(
            color: AppColors.bgBase,
            borderRadius: AppRadius.mdRadius,
            border: Border.all(color: AppColors.accentPrimaryBorder),
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (where.isNotEmpty)
                  Text(
                    where,
                    style: AppTypography.xs.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                SelectableText(
                  text.isEmpty
                      ? '(no text)'
                      : cut
                      ? text.substring(0, maxChunkTextChars)
                      : text,
                  style: AppTypography.sm.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                if (cut)
                  Text(
                    key: const Key('node_chunk_cut'),
                    '… shortened — ${text.length} characters in all',
                    style: AppTypography.xs.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChunkRow extends StatelessWidget {
  const _ChunkRow({
    required this.chunk,
    required this.number,
    required this.selected,
    required this.onTap,
  });

  final DocumentChunk chunk;
  final int number;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final where = _where(chunk);
    return InkWell(
      key: Key('node_chunk_${chunk.id}'),
      onTap: onTap,
      borderRadius: AppRadius.mdRadius,
      child: Container(
        constraints: const BoxConstraints(minHeight: AppSpacing.minTouchTarget),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s2,
          vertical: AppSpacing.s2,
        ),
        decoration: BoxDecoration(
          color: selected ? AppColors.accentPrimarySubtle : null,
          borderRadius: AppRadius.mdRadius,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 32,
              child: Text(
                '$number',
                style: AppTypography.xs.copyWith(color: AppColors.grayDim),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (where.isNotEmpty)
                    Text(
                      where,
                      style: AppTypography.xs.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  Text(
                    chunk.preview(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.sm.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PanelAction extends StatelessWidget {
  const _PanelAction({
    super.key,
    required this.label,
    required this.onTap,
    this.highlighted = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppSpacing.minTouchTarget,
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          backgroundColor: highlighted
              ? AppColors.accentPrimarySubtle
              : AppColors.surfaceHover,
          foregroundColor: AppColors.textSecondary,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.mdRadius),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s3),
        ),
        child: Text(label, style: AppTypography.sm),
      ),
    );
  }
}
