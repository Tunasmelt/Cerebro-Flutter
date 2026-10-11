import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../tokens/app_colors.dart';
import '../tokens/app_motion.dart';
import '../tokens/app_radius.dart';
import '../tokens/app_spacing.dart';
import '../tokens/app_typography.dart';

const _items = <(String, IconData)>[
  ('Docs', Icons.description_outlined),
  ('Chat', Icons.chat_bubble_outline),
  ('Graph', Icons.hub_outlined),
  ('Board', Icons.dashboard_outlined),
  ('Settings', Icons.settings_outlined),
];

class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final labelHeight = MediaQuery.textScalerOf(context).scale(12) * 8 / 3;
    return Material(
      color: AppColors.bgElevated,
      child: SafeArea(
        top: false,
        child: Container(
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AppColors.borderSubtle)),
          ),
          height: math.max(68, labelHeight + 40),
          child: Row(
            children: [
              for (final (index, item) in _items.indexed)
                Expanded(
                  child: Semantics(
                    key: Key('app_nav_${item.$1.toLowerCase()}'),
                    button: true,
                    selected: index == currentIndex,
                    label: item.$1,
                    onTap: () => onTap(index),
                    excludeSemantics: true,
                    child: InkWell(
                      onTap: () => onTap(index),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AnimatedContainer(
                            duration: MediaQuery.disableAnimationsOf(context)
                                ? Duration.zero
                                : AppMotion.base,
                            curve: AppMotion.soft,
                            width: 48,
                            height: 28,
                            decoration: BoxDecoration(
                              color: index == currentIndex
                                  ? AppColors.accentPrimarySubtle
                                  : Colors.transparent,
                              borderRadius: AppRadius.mdRadius,
                            ),
                            child: Icon(
                              item.$2,
                              size: 22,
                              color: index == currentIndex
                                  ? AppColors.accentSecondary
                                  : AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.s1),
                          SizedBox(
                            height: labelHeight,
                            child: Center(
                              child: Text(
                                item.$1,
                                maxLines: 2,
                                textAlign: TextAlign.center,
                                style: AppTypography.xs.copyWith(
                                  color: index == currentIndex
                                      ? AppColors.accentSecondary
                                      : AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class AppNavigationRail extends StatelessWidget {
  const AppNavigationRail({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) => SafeArea(
    right: false,
    child: NavigationRail(
      scrollable: true,
      backgroundColor: AppColors.bgElevated,
      selectedIndex: currentIndex,
      onDestinationSelected: onTap,
      labelType: NavigationRailLabelType.all,
      useIndicator: true,
      indicatorColor: AppColors.accentPrimarySubtle,
      selectedIconTheme: const IconThemeData(
        color: AppColors.accentSecondary,
        size: 22,
      ),
      unselectedIconTheme: const IconThemeData(
        color: AppColors.textSecondary,
        size: 22,
      ),
      selectedLabelTextStyle: AppTypography.xs.copyWith(
        color: AppColors.accentSecondary,
      ),
      unselectedLabelTextStyle: AppTypography.xs.copyWith(
        color: AppColors.textSecondary,
      ),
      destinations: [
        for (final item in _items)
          NavigationRailDestination(
            icon: Icon(item.$2, key: Key('app_nav_${item.$1.toLowerCase()}')),
            label: Text(item.$1),
          ),
      ],
    ),
  );
}
