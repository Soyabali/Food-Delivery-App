import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/navigation/navigation_helpers.dart';
import '../../app/router/app_routes.dart';
import '../../state/auth_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/adaptive_dialogs.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/unsaved_changes_guard.dart';
import '../authentication/widgets/auth_widgets.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  final _newFocus = FocusNode();
  final _confirmFocus = FocusNode();

  bool _submitting = false;
  bool _done = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    for (final c in [_current, _new, _confirm]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final c in [_current, _new, _confirm]) {
      c.dispose();
    }
    _newFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  bool get _hasChanges =>
      !_done && [_current, _new, _confirm].any((c) => c.text.isNotEmpty);
  bool get _matches => _new.text.isNotEmpty && _new.text == _confirm.text;

  Future<void> _submit() async {
    if (_submitting || _done) return;
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    setState(() => _submitting = true);
    final result = await context.read<AuthController>().changePassword(
          currentPassword: _current.text,
          newPassword: _new.text,
        );
    if (!mounted) return;
    setState(() {
      _submitting = false;
      _done = result.isSuccess;
      _error = result.isSuccess ? null : result.message;
    });
    if (!result.isSuccess) return;

    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    showAppSnackBar(context, 'Password updated (demo, stored on this device only)');
    context.popOrGo(AppRoutes.profile);
  }

  @override
  Widget build(BuildContext context) {
    final strength = PasswordStrength(_new.text);
    final user = context.watch<AuthController>().currentUser;

    return UnsavedChangesGuard(
      hasChanges: _hasChanges,
      onDiscard: () =>
          context.canPop() ? context.pop() : context.go(AppRoutes.profile),
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    CircleIconButton(
                      icon: Icons.arrow_back,
                      tooltip: 'Back',
                      iconSize: 22,
                      onPressed: () => context.popOrGo(AppRoutes.profile),
                    ),
                    const Expanded(
                      child: Text(
                        'Change Password',
                        textAlign: TextAlign.center,
                        style: AppText.titleMd,
                      ),
                    ),
                    const SizedBox(
                      width: 40,
                      child: Icon(
                        Icons.shield_outlined,
                        size: 20,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _IntroBanner(),
                        const SizedBox(height: 16),
                        AppTextField(
                          label: 'Current Password',
                          controller: _current,
                          icon: Icons.lock_outline,
                          hint: 'Enter current password',
                          isPassword: true,
                          filled: false,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.password],
                          validator: Validators.loginPassword,
                          onFieldSubmitted: (_) => _newFocus.requestFocus(),
                          labelTrailing: InkWell(
                            onTap: () => context.push(AppRoutes.forgotPassword),
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Text(
                                'Forgot?',
                                style: AppText.labelSm.copyWith(
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        AppTextField(
                          label: 'New Password',
                          controller: _new,
                          focusNode: _newFocus,
                          icon: Icons.key,
                          hint: 'Enter new password',
                          isPassword: true,
                          filled: false,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.newPassword],
                          validator: (v) {
                            final base = Validators.newPassword(v);
                            if (base != null) return base;
                            if (PasswordStrength(v!).score < 3) {
                              return 'Add upper & lower case letters and a number or symbol';
                            }
                            return null;
                          },
                          onFieldSubmitted: (_) => _confirmFocus.requestFocus(),
                        ),
                        const SizedBox(height: 16),
                        _StrengthCard(strength: strength),
                        const SizedBox(height: 16),
                        AppTextField(
                          label: 'Confirm New Password',
                          controller: _confirm,
                          focusNode: _confirmFocus,
                          icon: Icons.verified_user_outlined,
                          hint: 'Confirm new password',
                          isPassword: true,
                          filled: false,
                          textInputAction: TextInputAction.done,
                          validator: (v) => Validators.confirmPassword(v, _new.text),
                          onFieldSubmitted: (_) => _submit(),
                          suffix: _matches
                              ? Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Container(
                                    width: 24,
                                    height: 24,
                                    decoration: const BoxDecoration(
                                      color: AppColors.tertiaryFixed,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.done_all,
                                      size: 16,
                                      color: AppColors.onTertiaryContainer,
                                    ),
                                  ),
                                )
                              : null,
                        ),
                        if (_matches)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.check_circle_outline,
                                  size: 15,
                                  color: AppColors.tertiary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Passwords match perfectly',
                                  style: AppText.bodySm.copyWith(
                                    color: AppColors.tertiary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          AuthErrorBanner(message: _error!),
                        ],
                        if (_matches && strength.score >= 3 && _current.text.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          const _ReadyCard(),
                        ],
                        const SizedBox(height: 24),
                        PrimaryButton(
                          label: _done ? 'Password Updated!' : 'Update Password',
                          leadingIcon: _done ? Icons.check : Icons.enhanced_encryption_outlined,
                          color: _done
                              ? AppColors.tertiaryContainer
                              : AppColors.primaryContainer,
                          loading: _submitting,
                          loadingLabel: 'Updating…',
                          onPressed: _submit,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.info_outline,
                              size: 15,
                              color: AppColors.onSurfaceVariant,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'Logged in as ${user?.email ?? 'guest'}',
                                overflow: TextOverflow.ellipsis,
                                style: AppText.bodySm.copyWith(
                                  color: AppColors.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
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

class _IntroBanner extends StatelessWidget {
  const _IntroBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: AppRadius.xl,
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: AppColors.primaryFixed,
              borderRadius: AppRadius.xl,
            ),
            child: const Icon(Icons.lock_reset, size: 26, color: AppColors.primary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Secure Your Account', style: AppText.headlineMd),
                const SizedBox(height: 2),
                Text(
                  'Create a strong password with at least 8 characters '
                  'including numbers and symbols.',
                  style: AppText.bodySm.copyWith(color: AppColors.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StrengthCard extends StatelessWidget {
  const _StrengthCard({required this.strength});

  final PasswordStrength strength;

  @override
  Widget build(BuildContext context) {
    final score = strength.score;
    final color = switch (score) {
      0 || 1 => AppColors.error,
      2 => AppColors.primaryContainer,
      _ => AppColors.tertiaryContainer,
    };
    final labelColor = score >= 3 ? AppColors.tertiary : color;

    Widget requirement(bool ok, String text) => Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: ok ? AppColors.tertiaryFixed : AppColors.surfaceContainerHigh,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  ok ? Icons.check : Icons.close,
                  size: 11,
                  color: ok ? AppColors.onTertiaryContainer : AppColors.outline,
                ),
              ),
              const SizedBox(width: 8),
              Text(text, style: AppText.bodySm),
            ],
          ),
        );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.xl,
        boxShadow: AppShadows.sm,
      ),
      child: Semantics(
        label: 'Password strength: ${strength.label}',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'STRENGTH RATING',
                    style: AppText.labelSm.copyWith(
                      color: AppColors.onSurfaceVariant,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: strength.isEmpty ? AppColors.surfaceDim : labelColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  strength.label,
                  style: AppText.labelMd.copyWith(
                    color: strength.isEmpty ? AppColors.outline : labelColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                for (var i = 0; i < 4; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      height: 6,
                      decoration: BoxDecoration(
                        color: i < score ? color : AppColors.surfaceContainerHigh,
                        borderRadius: AppRadius.full,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),
            requirement(strength.hasLength, 'At least 8 characters'),
            requirement(strength.hasMixedCase, 'Contains uppercase and lowercase'),
            requirement(strength.hasNumberOrSymbol, 'Contains a number or symbol'),
          ],
        ),
      ),
    );
  }
}

class _ReadyCard extends StatelessWidget {
  const _ReadyCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: const BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: AppRadius.xl,
        boxShadow: AppShadows.sm,
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: AppColors.tertiaryFixed,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.verified,
              size: 20,
              color: AppColors.onTertiaryContainer,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Password ready to be updated safely', style: AppText.labelMd),
                Text(
                  'You will stay signed in on this mobile device',
                  overflow: TextOverflow.ellipsis,
                  style: AppText.bodySm.copyWith(color: AppColors.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
