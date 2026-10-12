import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/app_exception.dart';
import '../../../core/network/generated_api_client_provider.dart';
import '../../../shared/tokens/app_colors.dart';
import '../../../shared/tokens/app_spacing.dart';
import '../../../shared/tokens/app_typography.dart';
import '../../auth/data/auth_exception.dart';
import '../../auth/data/auth_notifier.dart';
import '../../auth/data/current_user_provider.dart';
import '../../documents/data/documents_error_mapper.dart';
import '../../documents/data/upload/upload_controller.dart';
import '../../documents/data/upload/upload_state.dart';
import '../data/account_settings.dart';
import '../../../shared/widgets/app_confirm_dialog.dart';

final wipeVaultProvider = Provider<Future<void> Function()>(
  (ref) => () async {
    final response = await ref
        .read(generatedApiClientProvider)
        .apiV1AccountDelete();
    if (!response.isSuccessful) throw DocumentsErrorMapper.ofResponse(response);
  },
);

class AccountSettingsScreen extends ConsumerStatefulWidget {
  const AccountSettingsScreen({super.key, required this.account});
  final SettingsAccount account;
  @override
  ConsumerState<AccountSettingsScreen> createState() =>
      _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends ConsumerState<AccountSettingsScreen> {
  late final _name = TextEditingController(text: widget.account.name);
  late final _avatar = TextEditingController(text: widget.account.avatarUrl);
  late final _email = TextEditingController(text: widget.account.email);
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  final _delete = TextEditingController();
  bool _busy = false;
  String? _message;

  bool get _sameOwner =>
      mounted && ref.read(currentUserIdProvider) == widget.account.id;

  @override
  void dispose() {
    for (final controller in [
      _name,
      _avatar,
      _email,
      _password,
      _confirmPassword,
      _delete,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action, String success) async {
    if (_busy || !_sameOwner) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await action();
      if (_sameOwner) setState(() => _message = success);
    } catch (error) {
      if (_sameOwner) {
        setState(
          () => _message = error is AuthFailureException
              ? error.message
              : error is AppException
              ? error.message
              : 'Could not save changes. Try again.',
        );
      }
    } finally {
      if (_sameOwner) setState(() => _busy = false);
    }
  }

  Future<void> _update(UserAttributes attributes) =>
      ref.read(updateSettingsAccountProvider)(widget.account.id, attributes);

  void _saveProfile() {
    final error = validateProfile(_name.text, _avatar.text);
    if (error != null) {
      setState(() => _message = error);
      return;
    }
    _run(
      () => _update(
        UserAttributes(
          data: {
            'display_name': _name.text.trim().isEmpty
                ? null
                : _name.text.trim(),
            'avatar_url': _avatar.text.trim().isEmpty
                ? null
                : _avatar.text.trim(),
          },
        ),
      ),
      'Profile updated.',
    );
  }

  void _saveEmail() {
    final email = _email.text.trim();
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      setState(() => _message = 'Enter a valid email address.');
      return;
    }
    _run(
      () => _update(UserAttributes(email: email)),
      'Check your email to confirm the address change. Your current address remains active until confirmed.',
    );
  }

  void _savePassword() {
    if (_password.text.length < 8) {
      setState(() => _message = 'Password must be at least 8 characters.');
      return;
    }
    if (_password.text != _confirmPassword.text) {
      setState(() => _message = 'Passwords must match.');
      return;
    }
    _run(() async {
      await _update(UserAttributes(password: _password.text));
      if (_sameOwner) {
        _password.clear();
        _confirmPassword.clear();
      }
    }, 'Password updated.');
  }

  Future<void> _wipe() async {
    if (_delete.text != 'DELETE' || _busy || !_sameOwner) return;
    if (ref
        .read(uploadsProvider)
        .any((upload) => upload.flow.stage != UploadStage.done)) {
      setState(
        () => _message =
            'Finish or dismiss pending uploads before deleting vault data.',
      );
      return;
    }
    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Permanently delete vault data?',
      message:
          'Documents, sealed content, chats, boards and tasks will be '
          'deleted. This cannot be undone. Your sign-in account will remain.',
      confirmLabel: 'Delete vault data',
      destructive: true,
    );
    if (!confirmed || !_sameOwner) return;
    await _run(() async {
      await ref.read(uploadsProvider.notifier).restoration;
      if (!_sameOwner) return;
      // Recheck after the confirmation dialog; background recovery may start.
      if (ref
          .read(uploadsProvider)
          .any((upload) => upload.flow.stage != UploadStage.done)) {
        throw const RequestRejectedException(
          'Finish or dismiss pending uploads first.',
        );
      }
      await ref.read(wipeVaultProvider)();
      if (_sameOwner) await ref.read(authNotifierProvider.notifier).signOut();
    }, 'Vault data deleted.');
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    bool secret = false,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: TextField(
      controller: controller,
      enabled: !_busy,
      obscureText: secret,
      autocorrect: !secret,
      enableSuggestions: !secret,
      keyboardType: label == 'Email address'
          ? TextInputType.emailAddress
          : TextInputType.text,
      decoration: InputDecoration(labelText: label),
    ),
  );

  /// A small caps label above a group of fields (same look as the section
  /// headers on the Settings tab, without their extra side padding).
  Widget _section(String label, {Color? color}) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.s6, bottom: AppSpacing.s2),
    child: Semantics(
      header: true,
      child: Text(
        label.toUpperCase(),
        style: AppTypography.xs.copyWith(
          color: color ?? AppColors.textSecondary,
          fontWeight: AppTypography.weightSemibold,
          letterSpacing: 0.8,
        ),
      ),
    ),
  );

  Widget _hint(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.s2),
    child: Text(
      text,
      style: AppTypography.sm.copyWith(color: AppColors.textSecondary),
    ),
  );

  Widget _full(Widget button) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.s2),
    child: SizedBox(width: double.infinity, child: button),
  );

  @override
  Widget build(BuildContext context) {
    if (ref.watch(currentUserIdProvider) != widget.account.id) {
      return const Scaffold(
        body: Center(child: Text('Sign in to manage your account.')),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Account settings')),
      bottomNavigationBar: _message == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Semantics(
                  liveRegion: true,
                  child: Text(_message!, key: const Key('settings_result')),
                ),
              ),
            ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_busy) const LinearProgressIndicator(),
            _section('Profile'),
            _field('Display name', _name),
            _field('Avatar URL', _avatar),
            _full(
              FilledButton(
                onPressed: _busy ? null : _saveProfile,
                child: const Text('Save profile'),
              ),
            ),
            _section('Email'),
            _field('Email address', _email),
            _hint('Changing your email requires confirmation.'),
            _full(
              OutlinedButton(
                onPressed: _busy ? null : _saveEmail,
                child: const Text('Change email'),
              ),
            ),
            _section('Password'),
            _field('New password', _password, secret: true),
            _field('Confirm password', _confirmPassword, secret: true),
            _full(
              OutlinedButton(
                onPressed: _busy ? null : _savePassword,
                child: const Text('Update password'),
              ),
            ),
            _section('Danger zone', color: AppColors.danger),
            Text(
              'Delete vault data',
              style: AppTypography.base.copyWith(
                color: AppColors.textPrimary,
                fontWeight: AppTypography.weightSemibold,
              ),
            ),
            _hint(
              'Permanently removes your documents, chats, boards and tasks, including sealed content. Your sign-in account remains. This cannot be undone.',
            ),
            _field('Type DELETE to confirm', _delete),
            ListenableBuilder(
              listenable: _delete,
              builder: (context, _) => _full(
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: BorderSide(
                      color: AppColors.danger.withValues(alpha: 0.6),
                    ),
                  ),
                  onPressed: _busy || _delete.text != 'DELETE' ? null : _wipe,
                  child: const Text('Delete vault data'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
