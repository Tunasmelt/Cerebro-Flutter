import 'package:flutter/material.dart';

import '../../../shared/tokens/app_colors.dart';
import '../../../shared/tokens/app_radius.dart';
import '../../../shared/tokens/app_spacing.dart';
import '../../../shared/tokens/app_typography.dart';
import 'unlock_sheet.dart';

/// Sealed document detail screen — the locked state a user sees when
/// opening a document that's in the sealed tier and hasn't been
/// unlocked on this device yet.
///
/// Presentation-layer only: no sealed-tier crypto, no backend call, no
/// real navigation. The unlock flow below is driven entirely by local
/// widget state so the three [UnlockSheetStatus] states can be reviewed
/// without a live unlock session. Naming follows CLAUDE.md's sealed-tier
/// discipline: never "encrypted" in isolation, never "zero-knowledge".
class SealedDocumentScreen extends StatefulWidget {
  const SealedDocumentScreen({
    super.key,
    this.fileName = 'financial-notes.pdf',
    this.fileSizeLabel = '2.4 MB',
    this.dateLabel = '18 Sep 2026',
  });

  final String fileName;
  final String fileSizeLabel;
  final String dateLabel;

  @override
  State<SealedDocumentScreen> createState() => _SealedDocumentScreenState();
}

class _SealedDocumentScreenState extends State<SealedDocumentScreen> {
  final _passphraseController = TextEditingController();
  bool _obscurePassphrase = true;
  UnlockSheetStatus _status = UnlockSheetStatus.idle;

  @override
  void dispose() {
    _passphraseController.dispose();
    super.dispose();
  }

  void _handleUnlockPressed() {
    // Presentation-layer stand-in only: this screen has no unlock
    // session to drive off of, so pressing Unlock just previews the
    // loading state. A real implementation calls the unlock endpoint
    // here and maps its result onto UnlockSheetStatus.
    setState(() => _status = UnlockSheetStatus.loading);
  }

  void _handleCancelPressed() {
    setState(() {
      _status = UnlockSheetStatus.idle;
      _passphraseController.clear();
    });
    Navigator.maybePop(context);
  }

  void _handleToggleObscure() {
    setState(() => _obscurePassphrase = !_obscurePassphrase);
  }

  // ---------------------------------------------------------------------
  // DEMO-ONLY — state switcher below this line.
  //
  // Lets a reviewer flip between the sheet's three visual states
  // (default / error / loading) without a live unlock session, mirroring
  // the state-switcher pattern used in Cerebro 2.0/Mockups/ui_kits. Not
  // part of the real product flow — safe to delete this block and the
  // `_DemoStateSwitcher` widget below when wiring in the real unlock
  // request.
  // ---------------------------------------------------------------------
  void _handleDemoStateChanged(UnlockSheetStatus status) {
    setState(() => _status = status);
  }
  // --- end DEMO-ONLY block -------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(
              fileName: widget.fileName,
              fileSizeLabel: widget.fileSizeLabel,
              dateLabel: widget.dateLabel,
            ),
            // DEMO-ONLY: strip this row along with _handleDemoStateChanged
            // above when wiring in the real unlock flow.
            _DemoStateSwitcher(
              current: _status,
              onChanged: _handleDemoStateChanged,
            ),
            Expanded(
              // SingleChildScrollView, not Center: when the top bar, demo
              // switcher, this card, and the unlock sheet together exceed
              // the available height (a real risk on shorter devices or
              // in the Error state, whose extra error line makes the
              // sheet taller), the card scrolls instead of overflowing.
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s6,
                  vertical: AppSpacing.s4,
                ),
                child: const _SealedLockedCard(),
              ),
            ),
            UnlockSheet(
              status: _status,
              controller: _passphraseController,
              obscureText: _obscurePassphrase,
              onToggleObscureText: _handleToggleObscure,
              onUnlock: _handleUnlockPressed,
              onCancel: _handleCancelPressed,
            ),
          ],
        ),
      ),
      bottomNavigationBar: const _BottomNavBar(),
    );
  }
}

/// DEMO-ONLY widget — see the comment block in [_SealedDocumentScreenState]
/// above. Not part of the shipped product surface.
class _DemoStateSwitcher extends StatelessWidget {
  const _DemoStateSwitcher({required this.current, required this.onChanged});

  final UnlockSheetStatus current;
  final ValueChanged<UnlockSheetStatus> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s4,
        AppSpacing.s2,
        AppSpacing.s4,
        0,
      ),
      child: Wrap(
        spacing: AppSpacing.s2,
        children: [
          _demoChip('Default', UnlockSheetStatus.idle),
          _demoChip('Error', UnlockSheetStatus.error),
          _demoChip('Loading', UnlockSheetStatus.loading),
        ],
      ),
    );
  }

  Widget _demoChip(String label, UnlockSheetStatus status) {
    final selected = current == status;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onChanged(status),
      labelStyle: AppTypography.xs.copyWith(
        color: selected ? AppColors.textOnAccent : AppColors.textSecondary,
      ),
      selectedColor: AppColors.accentPrimary,
      backgroundColor: AppColors.bgElevated,
      side: const BorderSide(color: AppColors.borderDefault),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.fileName,
    required this.fileSizeLabel,
    required this.dateLabel,
  });

  final String fileName;
  final String fileSizeLabel;
  final String dateLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s4,
        AppSpacing.s3,
        AppSpacing.s4,
        AppSpacing.s3,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ChromeIconButton(
            icon: Icons.arrow_back,
            tooltip: 'Back',
            onPressed: () => Navigator.maybePop(context),
          ),
          const SizedBox(width: AppSpacing.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fileName,
                  style: AppTypography.lg.copyWith(
                    fontFamily: AppTypography.fontFamilyDisplay,
                    fontWeight: AppTypography.weightBold,
                    color: AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.s2),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: AppSpacing.s2,
                  runSpacing: AppSpacing.s1,
                  children: [
                    const _SealedBadge(),
                    Text(
                      '$fileSizeLabel • $dateLabel',
                      style: AppTypography.mono(AppTypography.sm).copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.s3),
          _ChromeIconButton(
            icon: Icons.more_vert,
            tooltip: 'More options',
            onPressed: () {}, // Presentation-only — no real menu wired up.
          ),
        ],
      ),
    );
  }
}

/// Back/overflow buttons share the same bordered-square chrome in the
/// mockup.
class _ChromeIconButton extends StatelessWidget {
  const _ChromeIconButton({
    required this.icon,
    required this.onPressed,
    required this.tooltip,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: AppSpacing.minTouchTarget,
      height: AppSpacing.minTouchTarget,
      child: Material(
        color: AppColors.bgElevated,
        borderRadius: AppRadius.mdRadius,
        child: InkWell(
          borderRadius: AppRadius.mdRadius,
          onTap: onPressed,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: AppRadius.mdRadius,
              border: Border.all(color: AppColors.borderDefault),
            ),
            child: Icon(icon, color: AppColors.textPrimary, size: 20),
          ),
        ),
      ),
    );
  }
}

class _SealedBadge extends StatelessWidget {
  const _SealedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s2,
        vertical: AppSpacing.s1,
      ),
      decoration: BoxDecoration(
        color: AppColors.accentLockedSubtle,
        borderRadius: AppRadius.pillRadius,
        border: Border.all(color: AppColors.accentLocked),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.lock_outline,
            size: 12,
            color: AppColors.accentLocked,
          ),
          const SizedBox(width: AppSpacing.s1),
          Text(
            'SEALED',
            style: AppTypography.xs.copyWith(
              fontWeight: AppTypography.weightSemibold,
              color: AppColors.accentLocked,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// The large amber-bordered "this document is sealed" card.
class _SealedLockedCard extends StatelessWidget {
  const _SealedLockedCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s6,
        vertical: AppSpacing.s8,
      ),
      decoration: BoxDecoration(
        color: AppColors.accentLockedSubtle,
        borderRadius: AppRadius.lgRadius,
        border: Border.all(color: AppColors.accentLocked),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              borderRadius: AppRadius.mdRadius,
              border: Border.all(color: AppColors.accentLocked, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: AppColors.accentLocked.withValues(alpha: 0.55),
                  blurRadius: 24,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(
              Icons.lock_outline,
              color: AppColors.accentLocked,
              size: 32,
            ),
          ),
          const SizedBox(height: AppSpacing.s5),
          Text(
            'This document is sealed',
            textAlign: TextAlign.center,
            style: AppTypography.xxl.copyWith(
              fontFamily: AppTypography.fontFamilyDisplay,
              fontWeight: AppTypography.weightBold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.s3),
          Text(
            'Enter your passphrase to decrypt and view it on this device.',
            textAlign: TextAlign.center,
            style:
                AppTypography.base.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _BottomNavBar extends StatelessWidget {
  const _BottomNavBar();

  static const _items = <(_NavIcon, String)>[
    (_NavIcon(Icons.description_outlined, Icons.description), 'Docs'),
    (_NavIcon(Icons.chat_bubble_outline, Icons.chat_bubble), 'Chat'),
    (_NavIcon(Icons.hub_outlined, Icons.hub), 'Graph'),
    (_NavIcon(Icons.dashboard_outlined, Icons.dashboard), 'Board'),
    (_NavIcon(Icons.play_circle_outline, Icons.play_circle), 'Play'),
    (_NavIcon(Icons.settings_outlined, Icons.settings), 'Settings'),
  ];

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
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (final (index, item) in _items.indexed)
                _NavBarEntry(
                  navIcon: item.$1,
                  label: item.$2,
                  active: index == 0, // Docs active, per the mockup.
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavIcon {
  const _NavIcon(this.outlined, this.filled);
  final IconData outlined;
  final IconData filled;
}

class _NavBarEntry extends StatelessWidget {
  const _NavBarEntry({
    required this.navIcon,
    required this.label,
    required this.active,
  });

  final _NavIcon navIcon;
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.accentPrimary : AppColors.textSecondary;
    return Expanded(
      child: InkWell(
        // Presentation-only — no real navigation is wired up.
        onTap: () {},
        child: SizedBox(
          height: AppSpacing.minTouchTarget,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                active ? navIcon.filled : navIcon.outlined,
                color: color,
                size: 22,
              ),
              const SizedBox(height: AppSpacing.s1),
              Text(
                label,
                style: AppTypography.xs.copyWith(color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
