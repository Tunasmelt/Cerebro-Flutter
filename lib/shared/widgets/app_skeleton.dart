import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';
import '../tokens/app_motion.dart';
import '../tokens/app_radius.dart';
import '../tokens/app_spacing.dart';

/// A placeholder for content that is still loading: a few card-shaped rows
/// with a slow shimmer, instead of a lone spinner on an empty screen. It
/// shows the *shape* of what is coming, so the screen does not jump when the
/// real rows arrive.
///
/// The shimmer stands still when the system asks for reduced motion.
class AppSkeletonList extends StatefulWidget {
  const AppSkeletonList({super.key, this.rows = 5, this.rowHeight = 64});

  final int rows;
  final double rowHeight;

  @override
  State<AppSkeletonList> createState() => _AppSkeletonListState();
}

class _AppSkeletonListState extends State<AppSkeletonList>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmer;

  @override
  void initState() {
    super.initState();
    _shimmer = AnimationController(vsync: this, duration: AppMotion.slow * 4);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = MediaQuery.disableAnimationsOf(context);
    if (still) {
      _shimmer.stop();
    } else if (!_shimmer.isAnimating) {
      _shimmer.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _shimmer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading',
      liveRegion: true,
      child: ExcludeSemantics(
        child: ListView.separated(
          key: const Key('app_skeleton'),
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.s4),
          itemCount: widget.rows,
          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.s3),
          itemBuilder: (_, _) => AnimatedBuilder(
            animation: _shimmer,
            builder: (context, _) => Container(
              height: widget.rowHeight,
              decoration: BoxDecoration(
                borderRadius: AppRadius.lgRadius,
                border: Border.all(color: AppColors.borderSubtle),
                color: Color.lerp(
                  AppColors.bgElevated,
                  AppColors.surfaceHover,
                  Curves.easeInOut.transform(_shimmer.value),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
