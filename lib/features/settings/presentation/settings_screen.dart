import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../core/network/app_exception.dart';
import '../../../core/network/connection_status_notifier.dart';
import '../../../shared/tokens/app_colors.dart';
import '../../../shared/tokens/app_radius.dart';
import '../../../shared/tokens/app_spacing.dart';
import '../../../shared/tokens/app_typography.dart';
import '../../../shared/widgets/error_view.dart';
import '../../auth/data/auth_notifier.dart';
import '../../auth/data/current_user_provider.dart';
import '../../documents/data/document.dart';
import '../../documents/data/documents_list_notifier.dart';
import '../../documents/presentation/document_presentation.dart';
import '../data/account_settings.dart';
import 'account_settings_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(settingsAccountProvider);
    final documents = ref.watch(documentsListProvider);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.s4),
          children: [
            Text('Settings', style: AppTypography.xxxl),
            const SizedBox(height: AppSpacing.s4),
            account.when(
              skipLoadingOnReload: false,
              loading: () => const LinearProgressIndicator(),
              error: (_, _) => ListTile(
                title: const Text('Could not load your profile'),
                trailing: IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () => ref.invalidate(settingsAccountProvider),
                ),
              ),
              data: (user) => user == null
                  ? const ListTile(
                      title: Text('Sign in to manage your account'),
                    )
                  : ListTile(
                      leading: CircleAvatar(
                        backgroundImage: _avatar(user.avatarUrl),
                        onBackgroundImageError: _avatar(user.avatarUrl) == null
                            ? null
                            : (_, _) {},
                        child: _avatar(user.avatarUrl) == null
                            ? const Icon(Icons.person_outline)
                            : null,
                      ),
                      title: Text(user.name.isEmpty ? user.email : user.name),
                      subtitle: Text(user.email),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => AccountSettingsScreen(account: user),
                        ),
                      ),
                    ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.description_outlined),
              title: const Text('Data sources'),
              subtitle: const Text(
                'Manage your uploaded files and captured thoughts',
              ),
              onTap: () => context.go(AppRoutes.documents),
            ),
            const ListTile(
              leading: Icon(Icons.dark_mode_outlined),
              title: Text('Appearance'),
              subtitle: Text('Dark theme'),
            ),
            const SizedBox(height: AppSpacing.s4),
            Text('DATA & STORAGE', style: AppTypography.sm),
            documents.when(
              skipLoadingOnReload: false,
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => ErrorView(
                exception: error is AppException
                    ? error
                    : const UnknownApiException(),
                onRetry: () =>
                    ref.read(documentsListProvider.notifier).refresh(),
              ),
              data: (rows) => Column(
                children: [
                  ListTile(
                    title: const Text('Indexed content'),
                    subtitle: Text(
                      formatDocumentSize(
                        rows.fold<int>(0, (sum, row) => sum + row.sizeBytes),
                      ),
                    ),
                  ),
                  ListTile(
                    title: const Text('Original files'),
                    subtitle: Text(
                      formatDocumentSize(
                        rows.fold<int>(
                          0,
                          (sum, row) => sum + (row.originalSizeBytes ?? 0),
                        ),
                      ),
                    ),
                  ),
                  const Text(
                    'Totals reflect document records for this account, not project-wide storage quotas.',
                  ),
                  const SizedBox(height: AppSpacing.s4),
                  Text('SEALED DOCUMENTS', style: AppTypography.sm),
                  const Text(
                    'Unlock sealed content from Documents. The derived key is sent to the server during an active unlock session.',
                  ),
                  if (!rows.any((row) => row.status == DocumentStatus.sealed))
                    const ListTile(title: Text('No sealed documents')),
                  for (final row in rows.where(
                    (row) => row.status == DocumentStatus.sealed,
                  ))
                    ListTile(
                      leading: const Icon(
                        Icons.lock_outline,
                        color: AppColors.accentLocked,
                      ),
                      title: Text(row.title),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.go(AppRoutes.documentDetail(row.id)),
                    ),
                  ExpansionTile(
                    title: const Text('Storage by document'),
                    children: [
                      for (final row in rows)
                        ListTile(
                          title: Text(row.title),
                          subtitle: Text(
                            'Original: ${row.originalSizeBytes == null ? "Unknown" : formatDocumentSize(row.originalSizeBytes!)} � Indexed: ${row.status == DocumentStatus.sealed ? "Unavailable while sealed" : formatDocumentSize(row.sizeBytes)}',
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.s4),
            Text('CONNECTION', style: AppTypography.sm),
            const _ConnectionStatusSection(),
            const SizedBox(height: AppSpacing.s4),
            OutlinedButton.icon(
              key: const Key('settings_sign_out'),
              icon: const Icon(Icons.logout),
              label: const Text('Sign out'),
              onPressed: () async {
                final owner = ref.read(currentUserIdProvider);
                try {
                  await ref.read(authNotifierProvider.notifier).signOut();
                } catch (_) {
                  if (context.mounted &&
                      ref.read(currentUserIdProvider) == owner) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Could not sign out. Try again.'),
                      ),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  ImageProvider? _avatar(String value) {
    final uri = Uri.tryParse(value);
    return uri != null &&
            {'http', 'https'}.contains(uri.scheme) &&
            uri.host.isNotEmpty
        ? NetworkImage(value)
        : null;
  }
}

/// Milestone 1.3: a real call to the deployed backend's `/health`
/// endpoint (via [connectionStatusProvider]), rendered through the
/// shared [ErrorView] on failure — the app's one concrete, wired-in
/// demonstration of "offline detection distinct from server-error
/// detection" ahead of Phase 2's real feature screens.
class _ConnectionStatusSection extends ConsumerWidget {
  const _ConnectionStatusSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(connectionStatusProvider);
    final notifier = ref.read(connectionStatusProvider.notifier);

    return status.when(
      data: (_) => _ConnectionRow(
        key: const Key('connection_status_connected'),
        icon: Icons.wifi_rounded,
        iconColor: AppColors.accentSuccess,
        label: 'Connected to Cerebro',
        onCheckAgain: notifier.refresh,
      ),
      loading: () => const _ConnectionRow(
        key: Key('connection_status_checking'),
        icon: Icons.wifi_find_rounded,
        iconColor: AppColors.textSecondary,
        label: 'Checking connection…',
      ),
      error: (error, _) => ErrorView(
        exception: error is AppException
            ? error
            : UnknownApiException(error.toString()),
        onRetry: notifier.refresh,
      ),
    );
  }
}

class _ConnectionRow extends StatelessWidget {
  const _ConnectionRow({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.label,
    this.onCheckAgain,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback? onCheckAgain;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgElevated,
        border: Border.all(color: AppColors.borderDefault),
        borderRadius: AppRadius.lgRadius,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s4,
        vertical: AppSpacing.s3,
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: AppSpacing.s5),
          const SizedBox(width: AppSpacing.s4),
          Expanded(
            child: Text(
              label,
              style: AppTypography.base.copyWith(color: AppColors.textPrimary),
            ),
          ),
          if (onCheckAgain != null)
            IconButton(
              key: const Key('connection_status_check_again'),
              onPressed: onCheckAgain,
              icon: const Icon(Icons.refresh, color: AppColors.textSecondary),
            ),
        ],
      ),
    );
  }
}
