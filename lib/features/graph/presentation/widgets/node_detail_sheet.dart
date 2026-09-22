import 'package:flutter/material.dart';

import '../../../../shared/tokens/app_colors.dart';
import '../../../../shared/tokens/app_radius.dart';
import '../../../../shared/tokens/app_spacing.dart';
import '../../../../shared/tokens/app_typography.dart';
import '../models/graph_node.dart';

/// Node-detail chrome shown on tap, adapted from Brain.tsx's slide-in
/// top-right panel.
///
/// Deviation from Brain.tsx, deliberate: on a phone-width portrait
/// screen, a fixed top-right panel would either overlay a big chunk of
/// the already-small canvas or get cramped into a sliver. A bottom
/// sheet is the more native mobile pattern for "details about the thing
/// I just tapped" (comparable to how e.g. Maps apps surface a tapped
/// pin), reads full-width so `label`/`type`/actions have breathing room,
/// and is dismissible with the platform-standard swipe-down / tap-scrim
/// gesture instead of needing a bespoke close button to feel natural
/// (though one is still included, matching Brain.tsx's explicit ✕).
class NodeDetailSheet extends StatelessWidget {
  const NodeDetailSheet({
    super.key,
    required this.node,
    required this.onChatAboutThis,
    required this.onOpenInDocuments,
    required this.onZoomOut,
  });

  final GraphNode node;
  final VoidCallback onChatAboutThis;
  final VoidCallback onOpenInDocuments;
  final VoidCallback onZoomOut;

  @override
  Widget build(BuildContext context) {
    // showModalBottomSheet is called with backgroundColor: transparent
    // (the standard way to get true rounded top corners with no square
    // flash behind them) — which means this widget must supply its own
    // opaque background, or the sheet is invisible over whatever's
    // beneath it. Without this, the legend/ask bar show straight
    // through the "sheet".
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.s5,
            AppSpacing.s4,
            AppSpacing.s5,
            AppSpacing.s5,
          ),
          child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.s4),
                decoration: BoxDecoration(
                  color: AppColors.borderStrong,
                  borderRadius: AppRadius.pillRadius,
                ),
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        node.label,
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
                            style: AppTypography.sm
                                .copyWith(color: node.type.color),
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
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.close, color: AppColors.grayDim),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s4),
            _DetailAction(
              label: 'Chat about this',
              highlighted: true,
              onTap: onChatAboutThis,
            ),
            const SizedBox(height: AppSpacing.s2),
            _DetailAction(
              label: 'Open in Documents',
              onTap: onOpenInDocuments,
            ),
            const SizedBox(height: AppSpacing.s2),
            _DetailAction(
              label: 'Zoom out',
              muted: true,
              onTap: onZoomOut,
            ),
          ],
          ),
        ),
      ),
    );
  }
}

class _DetailAction extends StatelessWidget {
  const _DetailAction({
    required this.label,
    required this.onTap,
    this.highlighted = false,
    this.muted = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool highlighted;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: AppSpacing.minTouchTarget,
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          alignment: Alignment.centerLeft,
          backgroundColor: highlighted
              ? AppColors.accentPrimarySubtle
              : muted
                  ? Colors.transparent
                  : AppColors.surfaceHover,
          foregroundColor:
              muted ? AppColors.grayDim : AppColors.textSecondary,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.mdRadius),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s3),
        ),
        child: Text(label, style: AppTypography.sm),
      ),
    );
  }
}
