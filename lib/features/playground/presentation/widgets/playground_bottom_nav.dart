import 'package:flutter/material.dart';

import '../../../../shared/tokens/app_colors.dart';
import '../../../../shared/tokens/app_spacing.dart';
import '../../../../shared/tokens/app_typography.dart';

/// Bottom navigation bar shared shape across the app's top-level
/// destinations. Presentation-only here: this screen is not wired into
/// real navigation yet, so taps are no-ops besides visual state.
class PlaygroundBottomNav extends StatelessWidget {
  const PlaygroundBottomNav({super.key});

  static const _items = <_NavItemData>[
    _NavItemData('Docs', Icons.description_outlined),
    _NavItemData('Chat', Icons.chat_bubble_outline),
    _NavItemData('Graph', Icons.hub_outlined),
    _NavItemData('Board', Icons.dashboard_outlined),
    _NavItemData('Play', Icons.play_circle_fill),
    _NavItemData('Settings', Icons.settings_outlined),
  ];

  static const _activeIndex = 4; // Play

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.bgElevated,
        border: Border(top: BorderSide(color: AppColors.borderSubtle)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              for (var i = 0; i < _items.length; i++)
                Expanded(
                  child: _NavItem(
                    data: _items[i],
                    active: i == _activeIndex,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItemData {
  const _NavItemData(this.label, this.icon);
  final String label;
  final IconData icon;
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.data, required this.active});

  final _NavItemData data;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.accentPrimary : AppColors.textSecondary;
    return Semantics(
      button: true,
      selected: active,
      label: data.label,
      child: InkWell(
        onTap: () {},
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSpacing.minTouchTarget),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              active
                  ? Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: AppColors.accentPrimary,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(data.icon, color: AppColors.textOnAccent, size: 18),
                    )
                  : Icon(data.icon, color: color, size: 22),
              const SizedBox(height: 4),
              Text(
                data.label,
                style: AppTypography.xs.copyWith(color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
