import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../shared/tokens/app_colors.dart';
import '../../../shared/tokens/app_radius.dart';
import '../../../shared/tokens/app_spacing.dart';
import '../../../shared/tokens/app_typography.dart';
import '../data/auth_notifier.dart';
import '../data/auth_state.dart';

/// No sign-up mockup exists yet (only `SignIn.tsx` was reviewed) — this
/// mirrors web's real, working pattern instead
/// (`apps/web/src/app/signup/page.tsx`): email/password/confirm, then a
/// "Check your email" state once sign-up succeeds. This Supabase
/// project requires email confirmation (see CHANGELOG.md's Phase 1
/// audit entry), so `AwaitingEmailConfirmation` is the expected
/// post-signup state, not an edge case to special-case around.
class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  String? _localError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(authNotifierProvider.notifier).clearStatus();
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmPasswordController.text;

    if (password != confirm) {
      setState(() => _localError = "Passwords don't match.");
      return;
    }
    setState(() => _localError = null);
    ref.read(authNotifierProvider.notifier).signUp(
      email: email,
      password: password,
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);

    if (authState is AwaitingEmailConfirmation) {
      return _CheckEmailScreen(
        email: authState.email,
        errorMessage: authState.errorMessage,
      );
    }

    final loading = authState is AuthLoading;
    final remoteError = authState is Unauthenticated
        ? authState.errorMessage
        : null;
    final errorMessage = _localError ?? remoteError;

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      appBar: AppBar(
        backgroundColor: AppColors.bgBase,
        elevation: 0,
        title: const Text('Create your account'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.s6),
          child: Container(
            width: 360,
            padding: const EdgeInsets.all(AppSpacing.s6),
            decoration: BoxDecoration(
              color: AppColors.bgElevated,
              borderRadius: AppRadius.lgRadius,
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _LabeledField(
                  key: const Key('sign_up_email'),
                  label: 'Email',
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                ),
                const SizedBox(height: AppSpacing.s4),
                _LabeledField(
                  key: const Key('sign_up_password'),
                  label: 'Password',
                  controller: _passwordController,
                  obscureText: true,
                  autofillHints: const [AutofillHints.newPassword],
                ),
                const SizedBox(height: AppSpacing.s4),
                _LabeledField(
                  key: const Key('sign_up_confirm_password'),
                  label: 'Confirm password',
                  controller: _confirmPasswordController,
                  obscureText: true,
                  autofillHints: const [AutofillHints.newPassword],
                  onSubmitted: (_) => _handleSubmit(),
                ),
                if (errorMessage != null) ...[
                  const SizedBox(height: AppSpacing.s3),
                  Container(
                    key: const Key('sign_up_error'),
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s3,
                      vertical: AppSpacing.s2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.dangerSubtle,
                      borderRadius: AppRadius.mdRadius,
                    ),
                    child: Text(
                      errorMessage,
                      style: AppTypography.xs.copyWith(
                        color: AppColors.dangerHover,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.s5),
                SizedBox(
                  width: double.infinity,
                  height: AppSpacing.minTouchTarget,
                  child: ElevatedButton(
                    key: const Key('sign_up_submit'),
                    onPressed: loading ? null : _handleSubmit,
                    child: loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.textOnAccent,
                            ),
                          )
                        : const Text('Create account'),
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

enum _ResendStatus { idle, sending, sent }

class _CheckEmailScreen extends ConsumerStatefulWidget {
  const _CheckEmailScreen({required this.email, this.errorMessage});

  final String email;
  final String? errorMessage;

  @override
  ConsumerState<_CheckEmailScreen> createState() => _CheckEmailScreenState();
}

class _CheckEmailScreenState extends ConsumerState<_CheckEmailScreen> {
  _ResendStatus _status = _ResendStatus.idle;
  String? _resendError;

  Future<void> _resend() async {
    setState(() {
      _status = _ResendStatus.sending;
      _resendError = null;
    });
    final error = await ref
        .read(authNotifierProvider.notifier)
        .resendConfirmation(widget.email);
    if (!mounted) return;
    setState(() {
      _status = error == null ? _ResendStatus.sent : _ResendStatus.idle;
      _resendError = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final error = _resendError ?? widget.errorMessage;
    return Scaffold(
      backgroundColor: AppColors.bgBase,
      appBar: AppBar(backgroundColor: AppColors.bgBase, elevation: 0),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.s6),
          child: Column(
            key: const Key('check_email_state'),
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.mark_email_unread_outlined,
                color: AppColors.accentSecondary,
                size: 48,
              ),
              const SizedBox(height: AppSpacing.s5),
              Text(
                'Check your email',
                style: AppTypography.xl.copyWith(
                  fontFamily: AppTypography.fontFamilyDisplay,
                  fontWeight: AppTypography.weightSemibold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.s3),
              Text(
                'We sent a confirmation link to ${widget.email}. Tap it to finish creating your account.',
                textAlign: TextAlign.center,
                style: AppTypography.sm.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              if (error != null) ...[
                const SizedBox(height: AppSpacing.s4),
                Container(
                  key: const Key('check_email_error'),
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s3,
                    vertical: AppSpacing.s2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.dangerSubtle,
                    borderRadius: AppRadius.mdRadius,
                  ),
                  child: Text(
                    error,
                    style: AppTypography.xs.copyWith(
                      color: AppColors.dangerHover,
                    ),
                  ),
                ),
              ],
              if (_status == _ResendStatus.sent) ...[
                const SizedBox(height: AppSpacing.s4),
                Text(
                  'Sent. Check your inbox again.',
                  key: const Key('check_email_resent'),
                  style: AppTypography.xs.copyWith(
                    color: AppColors.accentSuccess,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.s6),
              SizedBox(
                width: double.infinity,
                height: AppSpacing.minTouchTarget,
                child: ElevatedButton(
                  key: const Key('check_email_resend'),
                  onPressed: _status == _ResendStatus.sending ? null : _resend,
                  child: const Text('Resend email'),
                ),
              ),
              const SizedBox(height: AppSpacing.s2),
              TextButton(
                key: const Key('check_email_change'),
                // Clearing the shared status swaps this screen back to the
                // sign-up form, which still holds what was typed, so a
                // typo'd address can be corrected.
                onPressed: () =>
                    ref.read(authNotifierProvider.notifier).clearStatus(),
                child: const Text('Use a different email'),
              ),
              TextButton(
                key: const Key('check_email_back_to_sign_in'),
                onPressed: () => context.go(AppRoutes.signIn),
                child: const Text('Back to sign in'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({
    super.key,
    required this.label,
    required this.controller,
    this.obscureText = false,
    this.keyboardType,
    this.autofillHints,
    this.onSubmitted,
  });

  final String label;
  final TextEditingController controller;
  final bool obscureText;
  final TextInputType? keyboardType;
  final List<String>? autofillHints;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.xs.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.s1),
        TextField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          autofillHints: autofillHints,
          onSubmitted: onSubmitted,
          style: AppTypography.sm.copyWith(color: AppColors.textPrimary),
        ),
      ],
    );
  }
}
