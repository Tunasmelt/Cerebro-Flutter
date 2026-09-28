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

/// Adapted from `Mockups 2.0/src/components/SignIn.tsx` — same layout
/// (centered card, violet radial glow), real app tokens instead of the
/// mockup's literal hex/Inter values (which happen to be close but
/// aren't the source of truth; `AppColors`/`AppTypography` are).
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Auth state is app-wide; drop a stale error/"check your email" state
    // left by another screen. Post-frame because provider state can't be
    // modified while the widget tree is building.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(authNotifierProvider.notifier).clearStatus();
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) return;
    ref.read(authNotifierProvider.notifier).signIn(
      email: email,
      password: password,
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final loading = authState is AuthLoading;
    final errorMessage = authState is Unauthenticated
        ? authState.errorMessage
        : null;

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.s6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Cerebro',
                style: AppTypography.lg.copyWith(
                  fontFamily: AppTypography.fontFamilyDisplay,
                  fontWeight: AppTypography.weightBold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.s8),
              Container(
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
                    Text(
                      'Sign in',
                      style: AppTypography.xl.copyWith(
                        fontFamily: AppTypography.fontFamilyDisplay,
                        fontWeight: AppTypography.weightSemibold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s5),
                    _Field(
                      key: const Key('sign_in_email'),
                      label: 'Email',
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                    ),
                    const SizedBox(height: AppSpacing.s4),
                    _Field(
                      key: const Key('sign_in_password'),
                      label: 'Password',
                      controller: _passwordController,
                      obscureText: true,
                      autofillHints: const [AutofillHints.password],
                      onSubmitted: (_) => _handleSubmit(),
                    ),
                    if (errorMessage != null) ...[
                      const SizedBox(height: AppSpacing.s3),
                      Container(
                        key: const Key('sign_in_error'),
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
                        key: const Key('sign_in_submit'),
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
                            : const Text('Sign in'),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s4),
                    Center(
                      child: TextButton(
                        key: const Key('sign_in_go_to_sign_up'),
                        // Through the router, not Navigator.push: an
                        // imperatively pushed route survives go_router's
                        // redirect and would stay on top of the app after
                        // sign-in completes.
                        onPressed: () => context.push(AppRoutes.signUp),
                        child: Text.rich(
                          TextSpan(
                            text: "Don't have an account? ",
                            style: AppTypography.xs.copyWith(
                              color: AppColors.textSecondary,
                            ),
                            children: [
                              TextSpan(
                                text: 'Sign up',
                                style: AppTypography.xs.copyWith(
                                  color: AppColors.accentSecondary,
                                  fontWeight: AppTypography.weightMedium,
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
            ],
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
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
