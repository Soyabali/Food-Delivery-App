import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../app/router/app_routes.dart';
import '../../../core/auth/auth_state.dart';
import '../../../core/connectivity/require_online.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/adaptive_dialogs.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/async_view.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/common.dart';
import '../../../data/models.dart';
import '../../../services/offer_service.dart';
import '../../../state/auth_controller.dart';
import '../widgets/auth_widgets.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  // In mock mode, prefilled with the seeded demo account (like the mockup).
  late final _demo = context.read<AuthController>().demoCredentials;
  late final _email = TextEditingController(text: _demo?.email);
  late final _password = TextEditingController(text: _demo?.password);
  final _passwordFocus = FocusNode();

  bool _submitting = false;
  String? _socialInProgress;
  String? _error;

  bool get _busy => _submitting || _socialInProgress != null;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    setState(() => _submitting = true);
    final result = await context.read<AuthController>().login(
          email: _email.text,
          password: _password.text,
        );
    if (!mounted) return;
    setState(() => _submitting = false);
    _handleResult(result);
  }

  Future<void> _social(String provider) async {
    if (_busy) return;
    if (!await requireOnline(context, action: '$provider sign-in')) return;
    if (!mounted) return;
    setState(() {
      _error = null;
      _socialInProgress = provider;
    });
    final result = await context.read<AuthController>().socialLogin(provider);
    if (!mounted) return;
    setState(() => _socialInProgress = null);
    _handleResult(result);
  }

  void _handleResult(AuthResult result) {
    if (!result.isSuccess) {
      setState(() => _error = result.message);
      return;
    }
    if (result.message != null) showAppSnackBar(context, result.message!);
    // `go` replaces the stack, so Back cannot return to login.
    context.go(AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: AutofillGroup(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _LoginHeader(),
                      if (_demo != null) ...[
                        const SizedBox(height: 8),
                        const Center(
                          child: Pill(
                            label: 'Demo mode · simulated sign-in',
                            icon: Icons.science_outlined,
                            background: AppColors.primaryFixed,
                            foreground: AppColors.onPrimaryFixedVariant,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      AppTextField(
                        label: 'Email Address',
                        controller: _email,
                        icon: Icons.mail_outline,
                        hint: 'rahul.sharma@example.com',
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.email],
                        validator: Validators.email,
                        onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
                      ),
                      const SizedBox(height: 16),
                      AppTextField(
                        label: 'Password',
                        controller: _password,
                        focusNode: _passwordFocus,
                        icon: Icons.lock_outline,
                        hint: '••••••••••••',
                        isPassword: true,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.password],
                        validator: Validators.loginPassword,
                        onFieldSubmitted: (_) => _submit(),
                        labelTrailing: LinkButton(
                          label: 'Forgot Password?',
                          onPressed: _busy
                              ? null
                              : () => context.push(AppRoutes.forgotPassword),
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        AuthErrorBanner(message: _error!),
                      ],
                      const SizedBox(height: 16),
                      // Promo from GET /offers; hidden if it can't load.
                      RequestBuilder<List<Offer>>(
                        request: context.read<OfferService>().getOffers,
                        loading: const SizedBox.shrink(),
                        isEmpty: (offers) => offers.isEmpty,
                        errorBuilder: (_, _) => const SizedBox.shrink(),
                        builder: (context, offers) {
                          final offer = offers.last;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: PerkBanner(
                              title: '${offer.title} with code ${offer.code}',
                              subtitle: offer.subtitle,
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      PrimaryButton(
                        label: 'Login',
                        icon: Icons.arrow_forward,
                        loading: _submitting,
                        loadingLabel: 'Logging in…',
                        onPressed: _socialInProgress == null ? _submit : null,
                      ),
                      const SizedBox(height: 24),
                      const OrDivider(label: 'Or continue with'),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: SecondaryButton(
                              label: _socialInProgress == 'Google'
                                  ? 'Signing in…'
                                  : 'Google',
                              iconWidget: const GoogleLogo(),
                              onPressed: _busy ? null : () => _social('Google'),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: SecondaryButton(
                              label: _socialInProgress == 'Apple'
                                  ? 'Signing in…'
                                  : 'Apple',
                              icon: Icons.apple,
                              onPressed: _busy ? null : () => _social('Apple'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            'Don’t have an account?',
                            style: AppText.bodyMd.copyWith(
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: 4),
                          LinkButton(
                            label: 'Sign Up',
                            onPressed: _busy
                                ? null
                                : () => context.push(AppRoutes.register),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoginHeader extends StatelessWidget {
  const _LoginHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: 84,
          height: 72,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: AppColors.primaryFixed,
                  shape: BoxShape.circle,
                  boxShadow: AppShadows.sm,
                ),
                child: const Icon(
                  Icons.lunch_dining,
                  size: 32,
                  color: AppColors.primary,
                ),
              ),
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: const BoxDecoration(
                    color: AppColors.primaryContainer,
                    borderRadius: AppRadius.full,
                    boxShadow: AppShadows.sm,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.local_fire_department,
                        size: 12,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        'HOT',
                        style: AppText.labelSm.copyWith(
                          color: Colors.white,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Apna Food',
              style: AppText.headlineMd.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: 6),
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppColors.primaryContainer,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Welcome Back',
          style: AppText.headlineLg.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(
          'Login to continue ordering your favourite food.',
          textAlign: TextAlign.center,
          style: AppText.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
        ),
      ],
    );
  }
}
