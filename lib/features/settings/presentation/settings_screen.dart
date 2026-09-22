import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/tokens/app_colors.dart';
import '../../../shared/tokens/app_radius.dart';
import '../../../shared/tokens/app_spacing.dart';
import '../../../shared/tokens/app_typography.dart';
import '../../auth/data/auth_notifier.dart';

/// Settings screen — profile summary, grouped preference sections, sign
/// out, and version footer. Row taps besides sign-out are still stubs;
/// profile data below is static/mock until a real profile endpoint
/// exists.
///
/// Amber is used ONLY on the "Encryption & sealed docs" row, per
/// AppColors.accentLocked's exclusivity rule — every other icon/accent
/// here is violet (avatar), teal (section labels, badge, mono values),
/// or muted gray (default icons/chevrons).
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.bgBase,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.s4,
            AppSpacing.s6,
            AppSpacing.s4,
            AppSpacing.s8,
          ),
          children: [
            Text(
              'Settings',
              style: AppTypography.xxxl.copyWith(
                fontFamily: AppTypography.fontFamilyDisplay,
                fontWeight: AppTypography.weightBold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.s6),
            const _ProfileCard(
              name: 'Alex Stone',
              email: 'alex@cerebro.dev',
              initials: 'AS',
            ),
            const SizedBox(height: AppSpacing.s6),
            const _SectionLabel('WORKSPACE'),
            const SizedBox(height: AppSpacing.s2),
            _SettingsGroup(
              rows: [
                _SettingsRowData(
                  icon: Icons.description_outlined,
                  label: 'Data sources',
                  trailing: const _CountBadge(count: 4),
                  onTap: () {},
                ),
                _SettingsRowData(
                  icon: Icons.tune,
                  label: 'Retrieval settings',
                  onTap: () {},
                ),
                _SettingsRowData(
                  icon: Icons.hub_outlined,
                  label: 'Graph preferences',
                  onTap: () {},
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s6),
            const _SectionLabel('SECURITY'),
            const SizedBox(height: AppSpacing.s2),
            _SettingsGroup(
              rows: [
                _SettingsRowData(
                  icon: Icons.lock_outline,
                  label: 'Encryption & sealed docs',
                  iconColor: AppColors.accentLocked,
                  onTap: () {},
                ),
                _SettingsRowData(
                  icon: Icons.shield_outlined,
                  label: 'App lock',
                  onTap: () {},
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s6),
            const _SectionLabel('GENERAL'),
            const SizedBox(height: AppSpacing.s2),
            _SettingsGroup(
              rows: [
                _SettingsRowData(
                  icon: Icons.dark_mode_outlined,
                  label: 'Appearance',
                  trailing: Text(
                    'Dark',
                    style: AppTypography.base.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  onTap: () {},
                ),
                _SettingsRowData(
                  icon: Icons.notifications_outlined,
                  label: 'Notifications',
                  onTap: () {},
                ),
                _SettingsRowData(
                  icon: Icons.storage_outlined,
                  label: 'Storage',
                  trailing: Text(
                    '284 MB',
                    style: AppTypography.mono(AppTypography.base).copyWith(
                      color: AppColors.accentSecondary,
                    ),
                  ),
                  onTap: () {},
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s6),
            _SignOutButton(
              onPressed: () =>
                  ref.read(authNotifierProvider.notifier).signOut(),
            ),
            const SizedBox(height: AppSpacing.s4),
            Center(
              child: Text(
                'Cerebro 2.0.0',
                style: AppTypography.mono(AppTypography.xs).copyWith(
                  color: AppColors.textDisabled,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.name,
    required this.email,
    required this.initials,
  });

  final String name;
  final String email;
  final String initials;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.bgElevated,
      borderRadius: AppRadius.lgRadius,
      child: InkWell(
        borderRadius: AppRadius.lgRadius,
        onTap: () {},
        child: Container(
          constraints: const BoxConstraints(
            minHeight: AppSpacing.s12 + AppSpacing.s4,
          ),
          padding: const EdgeInsets.all(AppSpacing.s4),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.borderDefault),
            borderRadius: AppRadius.lgRadius,
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: AppSpacing.s6,
                backgroundColor: AppColors.accentPrimary,
                child: Text(
                  initials,
                  style: AppTypography.md.copyWith(
                    color: AppColors.textOnAccent,
                    fontWeight: AppTypography.weightSemibold,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.s4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      style: AppTypography.md.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: AppTypography.weightSemibold,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s1),
                    Text(
                      email,
                      style: AppTypography.sm.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: AppColors.textSecondary,
                size: AppSpacing.s5,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s1),
      child: Text(
        text,
        style: AppTypography.xs.copyWith(
          color: AppColors.accentSecondary,
          fontWeight: AppTypography.weightSemibold,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s3,
        vertical: AppSpacing.s1,
      ),
      decoration: BoxDecoration(
        color: AppColors.accentSecondarySubtle,
        borderRadius: AppRadius.pillRadius,
      ),
      child: Text(
        '$count',
        style: AppTypography.mono(AppTypography.sm).copyWith(
          color: AppColors.accentSecondary,
          fontWeight: AppTypography.weightMedium,
        ),
      ),
    );
  }
}

class _SettingsRowData {
  const _SettingsRowData({
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing,
    this.iconColor,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Widget? trailing;
  final Color? iconColor;
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.rows});

  final List<_SettingsRowData> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgElevated,
        border: Border.all(color: AppColors.borderDefault),
        borderRadius: AppRadius.lgRadius,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                thickness: 1,
                color: AppColors.borderSubtle,
              ),
            _SettingsRow(data: rows[i]),
          ],
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({required this.data});

  final _SettingsRowData data;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: data.onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: AppSpacing.minTouchTarget),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s4,
            vertical: AppSpacing.s3,
          ),
          child: Row(
            children: [
              Icon(
                data.icon,
                color: data.iconColor ?? AppColors.textSecondary,
                size: AppSpacing.s5,
              ),
              const SizedBox(width: AppSpacing.s4),
              Expanded(
                child: Text(
                  data.label,
                  style: AppTypography.base.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: AppTypography.weightMedium,
                  ),
                ),
              ),
              if (data.trailing != null) ...[
                data.trailing!,
                const SizedBox(width: AppSpacing.s2),
              ],
              Icon(
                Icons.chevron_right,
                color: AppColors.textSecondary,
                size: AppSpacing.s5,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SignOutButton extends StatelessWidget {
  const _SignOutButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: AppSpacing.minTouchTarget + AppSpacing.s2,
      child: OutlinedButton.icon(
        key: const Key('settings_sign_out'),
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.danger,
          side: const BorderSide(color: AppColors.danger),
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadius.mdRadius,
          ),
        ),
        icon: const Icon(Icons.logout, size: AppSpacing.s5),
        label: Text(
          'Sign out',
          style: AppTypography.base.copyWith(
            fontWeight: AppTypography.weightSemibold,
          ),
        ),
      ),
    );
  }
}
