import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../app/navigation/navigation_helpers.dart';
import '../../../app/router/app_routes.dart';
import '../../../state/auth_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/adaptive_dialogs.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/common.dart';
import '../widgets/auth_widgets.dart';

/// Step 1: email -> POST /auth/forgot-password (a 6-digit code is emailed).
/// Step 2: code + new password -> POST /auth/reset-password.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  static const cooldownSeconds = 45;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _passwordFocus = FocusNode();
  final _confirmFocus = FocusNode();

  bool _sending = false;
  bool _sent = false;
  bool _resetting = false;
  String? _demoCode;
  String? _error;
  int _secondsLeft = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Signed-in users (coming from Change Password) get their email prefilled.
    final user = context.read<AuthController>().currentUser;
    if (user != null) _email.text = user.email;
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in [_email, _code, _password, _confirm]) {
      c.dispose();
    }
    _passwordFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  bool get _coolingDown => _secondsLeft > 0;

  Future<void> _sendCode() async {
    if (_sending || _coolingDown) return;
    if (Validators.email(_email.text) != null) {
      _formKey.currentState!.validate();
      return;
    }
    FocusScope.of(context).unfocus();

    setState(() {
      _sending = true;
      _error = null;
    });
    final result =
        await context.read<AuthController>().requestPasswordReset(_email.text);
    if (!mounted) return;
    setState(() => _sending = false);
    if (!result.isSuccess) {
      showAppSnackBar(context, result.message!);
      return;
    }
    setState(() {
      _sent = true;
      _demoCode = result.message;
      _code.clear();
    });
    _startCooldown();
  }

  Future<void> _resetPassword() async {
    if (_resetting) return;
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    setState(() => _resetting = true);
    final result = await context.read<AuthController>().resetPassword(
          email: _email.text,
          code: _code.text,
          newPassword: _password.text,
        );
    if (!mounted) return;
    setState(() => _resetting = false);
    if (!result.isSuccess) {
      setState(() => _error = result.message);
      return;
    }
    final auth = context.read<AuthController>();
    showAppSnackBar(context, 'Password reset. Log in with your new password.');
    // The backend signed out every device, including this one.
    if (auth.isAuthenticated) await auth.logout();
    if (mounted) context.go(AppRoutes.login);
  }

  void _startCooldown() {
    _timer?.cancel();
    setState(() => _secondsLeft = ForgotPasswordScreen.cooldownSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) t.cancel();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  CircleIconButton(
                    icon: Icons.arrow_back,
                    tooltip: 'Back',
                    iconSize: 22,
                    onPressed: () => context.popOrGo(AppRoutes.login),
                  ),
                  const Expanded(
                    child: Center(
                      child: Pill(
                        label: 'Secure Verification',
                        background: AppColors.surfaceContainerLow,
                        foreground: AppColors.onSurfaceVariant,
                        icon: Icons.circle,
                      ),
                    ),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 16),
                          const Center(child: _EnvelopeIllustration()),
                          const SizedBox(height: 20),
                          Text(
                            _sent ? 'Check Your Email' : 'Forgot Password?',
                            textAlign: TextAlign.center,
                            style: AppText.headlineLg,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _sent
                                ? 'Enter the 6-digit code we emailed you and '
                                    'choose a new password.'
                                : 'Enter your registered email address and '
                                    'we\'ll email you a 6-digit reset code.',
                            textAlign: TextAlign.center,
                            style: AppText.bodyMd.copyWith(
                              color: AppColors.onSurfaceVariant,
                              height: 1.6,
                            ),
                          ),
                          const SizedBox(height: 24),
                          AppTextField(
                            label: 'Email Address',
                            controller: _email,
                            icon: Icons.alternate_email,
                            hint: 'name@example.com',
                            filled: false,
                            enabled: !_sent,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.send,
                            autofillHints: const [AutofillHints.email],
                            validator: Validators.email,
                            onFieldSubmitted: (_) => _sendCode(),
                            labelTrailing: _sent
                                ? LinkButton(
                                    label: 'Change',
                                    onPressed: () => setState(() {
                                      _sent = false;
                                      _demoCode = null;
                                      _error = null;
                                    }),
                                  )
                                : null,
                          ),
                          const SizedBox(height: 16),
                          if (!_sent)
                            PrimaryButton(
                              label: _coolingDown
                                  ? 'Send again in ${_secondsLeft}s'
                                  : 'Send Reset Code',
                              icon: Icons.send,
                              loading: _sending,
                              loadingLabel: 'Sending…',
                              onPressed: _coolingDown ? null : _sendCode,
                            )
                          else ...[
                            _SentBanner(
                              email: _email.text.trim(),
                              demoCode: _demoCode,
                            ),
                            const SizedBox(height: 16),
                            AppTextField(
                              label: '6-Digit Code',
                              controller: _code,
                              icon: Icons.pin_outlined,
                              hint: '123456',
                              keyboardType: TextInputType.number,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.oneTimeCode],
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(6),
                              ],
                              validator: (v) => RegExp(r'^\d{6}$').hasMatch(v ?? '')
                                  ? null
                                  : 'Enter the 6-digit code from the email',
                              onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
                              labelTrailing: LinkButton(
                                label: _coolingDown
                                    ? 'Resend in ${_secondsLeft}s'
                                    : 'Resend code',
                                onPressed:
                                    _coolingDown || _sending ? null : _sendCode,
                              ),
                            ),
                            const SizedBox(height: 14),
                            AppTextField(
                              label: 'New Password',
                              controller: _password,
                              focusNode: _passwordFocus,
                              icon: Icons.lock_outline,
                              hint: 'At least 8 characters',
                              isPassword: true,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.newPassword],
                              validator: Validators.newPassword,
                              onFieldSubmitted: (_) => _confirmFocus.requestFocus(),
                            ),
                            const SizedBox(height: 14),
                            AppTextField(
                              label: 'Confirm New Password',
                              controller: _confirm,
                              focusNode: _confirmFocus,
                              icon: Icons.lock_reset,
                              hint: 'Repeat your new password',
                              isPassword: true,
                              textInputAction: TextInputAction.done,
                              validator: (v) =>
                                  Validators.confirmPassword(v, _password.text),
                              onFieldSubmitted: (_) => _resetPassword(),
                            ),
                            if (_error != null) ...[
                              const SizedBox(height: 12),
                              AuthErrorBanner(message: _error!),
                            ],
                            const SizedBox(height: 20),
                            PrimaryButton(
                              label: 'Reset Password',
                              icon: Icons.check,
                              loading: _resetting,
                              loadingLabel: 'Resetting…',
                              onPressed: _resetPassword,
                            ),
                          ],
                          const SizedBox(height: 24),
                          _HelpBox(
                            secondsLeft: _secondsLeft,
                            sent: _sent,
                          ),
                          const SizedBox(height: 32),
                          Center(
                            child: LinkButton(
                              label: 'Back to Login',
                              icon: Icons.arrow_back,
                              style: AppText.labelLg,
                              onPressed: () => context.popOrGo(AppRoutes.login),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SentBanner extends StatelessWidget {
  const _SentBanner({required this.email, this.demoCode});

  final String email;

  /// Only set by the on-device mock backend (it cannot send email).
  final String? demoCode;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: const BoxDecoration(
          color: AppColors.surfaceContainer,
          borderRadius: AppRadius.xl,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.check_circle, size: 20, color: AppColors.tertiary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Code Sent!', style: AppText.labelMd),
                  const SizedBox(height: 2),
                  Text(
                    'If an account exists for $email, a 6-digit code is on its '
                    'way. It expires in 15 minutes. Check spam if not found.',
                    style: AppText.bodySm.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  if (demoCode != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Demo mode (no email): your code is $demoCode',
                      style: AppText.bodySm.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HelpBox extends StatelessWidget {
  const _HelpBox({required this.secondsLeft, required this.sent});

  final int secondsLeft;
  final bool sent;

  @override
  Widget build(BuildContext context) {
    final ready = secondsLeft <= 0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: AppRadius.xxl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.info_outline, size: 18, color: AppColors.primary),
              SizedBox(width: 8),
              Text('Didn’t receive the email?', style: AppText.labelMd),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Check your spam or junk folder, or wait for the cooldown timer '
            'below before requesting another code.',
            style: AppText.bodySm.copyWith(
              color: AppColors.onSurfaceVariant,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.schedule, size: 14, color: AppColors.onSurfaceVariant),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Resend code in:',
                  style: AppText.labelSm.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ),
              Pill(
                label: !sent
                    ? '${ForgotPasswordScreen.cooldownSeconds}s'
                    : ready
                        ? 'Ready to Resend'
                        : '${secondsLeft}s',
                background:
                    sent && ready ? AppColors.tertiaryFixed : AppColors.primaryFixed,
                foreground:
                    sent && ready ? AppColors.tertiary : AppColors.primaryContainer,
                fontSize: 14,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EnvelopeIllustration extends StatelessWidget {
  const _EnvelopeIllustration();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 176,
      height: 176,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: AppShadows.sm,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.primaryFixed.withValues(alpha: 0.3),
                  AppColors.surfaceContainer,
                ],
              ),
            ),
          ),
          Positioned(
            top: -4,
            right: 12,
            child: _Bubble(
              size: 32,
              color: AppColors.primaryFixedDim.withValues(alpha: 0.6),
              icon: Icons.key,
              iconColor: AppColors.primary,
            ),
          ),
          Positioned(
            bottom: 8,
            left: -4,
            child: _Bubble(
              size: 28,
              color: AppColors.tertiaryFixed.withValues(alpha: 0.6),
              icon: Icons.verified_user_outlined,
              iconColor: AppColors.tertiary,
            ),
          ),
          const Positioned(top: 16, left: 16, child: _Dot(8, AppColors.primaryContainer)),
          const Positioned(bottom: 24, right: 24, child: _Dot(10, AppColors.surfaceDim)),
          Container(
            width: 112,
            height: 112,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: AppRadius.xxl,
              boxShadow: AppShadows.md,
            ),
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Container(
                  width: 80,
                  height: 56,
                  decoration: const BoxDecoration(
                    color: AppColors.surfaceContainerLow,
                    borderRadius: AppRadius.xl,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: ClipPath(
                          clipper: _FlapClipper(),
                          child: Container(
                            height: 28,
                            color: AppColors.surfaceVariant.withValues(alpha: 0.8),
                          ),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Icon(
                          Icons.mail_outline,
                          size: 28,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  bottom: -8,
                  right: -8,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      color: AppColors.primaryContainer,
                      borderRadius: AppRadius.xl,
                      boxShadow: AppShadows.md,
                    ),
                    child: const Icon(Icons.lock, size: 20, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.size,
    required this.color,
    required this.icon,
    required this.iconColor,
  });

  final double size;
  final Color color;
  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: AppShadows.sm,
        ),
        child: Icon(icon, size: size * 0.55, color: iconColor),
      );
}

class _Dot extends StatelessWidget {
  const _Dot(this.size, this.color);

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}

class _FlapClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) => Path()
    ..lineTo(size.width, 0)
    ..lineTo(size.width / 2, size.height)
    ..close();

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
