import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../shared/tokens/app_colors.dart';
import '../../../shared/tokens/app_spacing.dart';
import '../../../shared/tokens/app_typography.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../data/auth_notifier.dart';
import '../data/auth_state.dart';
import 'auth_card.dart';

/// Adapted from `Mockups 2.0/src/components/SignIn.tsx` — same layout
/// (centered card), real app tokens instead of the mockup's literal
/// hex/Inter values (`AppColors`/`AppTypography` are the source of truth).
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  /// Set once the user has tried to submit, so an empty field is called out
  /// (and the call-out clears as they type) instead of the button silently
  /// doing nothing.
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_onTyped);
    _passwordController.addListener(_onTyped);
    // Auth state is app-wide; drop a stale error/"check your email" state
    // left by another screen. Post-frame because provider state can't be
    // modified while the widget tree is building.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(authNotifierProvider.notifier).clearStatus();
    });
  }

  void _onTyped() {
    if (_submitted) setState(() {});
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
    setState(() => _submitted = true);
    if (email.isEmpty || password.isEmpty) return;
    ref
        .read(authNotifierProvider.notifier)
        .signIn(email: email, password: password);
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
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.s6),
            child: AutofillGroup(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const AuthBrand(),
                  const SizedBox(height: AppSpacing.s8),
                  AuthCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Semantics(
                          header: true,
                          child: Text(
                            'Sign in',
                            style: AppTypography.xl.copyWith(
                              fontFamily: AppTypography.fontFamilyDisplay,
                              fontWeight: AppTypography.weightSemibold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.s5),
                        AppTextField(
                          key: const Key('sign_in_email'),
                          label: 'Email',
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.email],
                          errorText:
                              _submitted && _emailController.text.trim().isEmpty
                              ? 'Enter your email.'
                              : null,
                        ),
                        const SizedBox(height: AppSpacing.s4),
                        AppTextField(
                          key: const Key('sign_in_password'),
                          label: 'Password',
                          controller: _passwordController,
                          obscureText: true,
                          showVisibilityToggle: true,
                          textInputAction: TextInputAction.done,
                          autofillHints: const [AutofillHints.password],
                          onSubmitted: (_) => _handleSubmit(),
                          errorText:
                              _submitted && _passwordController.text.isEmpty
                              ? 'Enter your password.'
                              : null,
                        ),
                        if (errorMessage != null) ...[
                          const SizedBox(height: AppSpacing.s3),
                          AuthMessage(
                            errorMessage,
                            key: const Key('sign_in_error'),
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
        ),
      ),
    );
  }
}
