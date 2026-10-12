import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../shared/tokens/app_colors.dart';
import '../../../shared/tokens/app_typography.dart';

class TypingIndicator extends StatefulWidget {
  const TypingIndicator({super.key, required this.label});
  final String label;
  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _animation.stop();
    } else {
      _animation.repeat();
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    label: widget.label,
    excludeSemantics: true,
    child: Row(
      children: [
        AnimatedBuilder(
          animation: _animation,
          builder: (context, _) => Row(
            children: [
              for (var i = 0; i < 3; i++)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Opacity(
                    opacity: MediaQuery.disableAnimationsOf(context)
                        ? 0.7
                        : 0.3 +
                              0.7 *
                                  (math.sin(
                                        _animation.value * math.pi * 2 - i,
                                      ) +
                                      1) /
                                  2,
                    child: const SizedBox(
                      width: 5,
                      height: 5,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: AppColors.accentSecondary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            widget.label,
            style: AppTypography.sm.copyWith(color: AppColors.textSecondary),
          ),
        ),
      ],
    ),
  );
}
