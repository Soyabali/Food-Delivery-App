import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../app/navigation/navigation_helpers.dart';
import '../../../app/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/adaptive_dialogs.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/async_view.dart';
import '../../../core/widgets/buttons.dart';
import '../../../data/models.dart';
import '../../../services/offer_service.dart';
import '../../../state/auth_controller.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/unsaved_changes_guard.dart';
import '../widgets/auth_widgets.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _emailFocus = FocusNode();
  final _phoneFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmFocus = FocusNode();

  bool _acceptedTerms = false;
  bool _showTermsError = false;
  bool _submitting = false;
  bool _completed = false;
  String? _error;

  late final List<TextEditingController> _controllers = [
    _name,
    _email,
    _phone,
    _password,
    _confirm,
  ];

  @override
  void initState() {
    super.initState();
    for (final c in _controllers) {
      c.addListener(_onChanged);
    }
  }

  void _onChanged() => setState(() {});

  bool get _hasChanges =>
      !_completed && _controllers.any((c) => c.text.trim().isNotEmpty);

  bool get _passwordsMatch =>
      _password.text.isNotEmpty && _password.text == _confirm.text;

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in [_emailFocus, _phoneFocus, _passwordFocus, _confirmFocus]) {
      f.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() {
      _error = null;
      _showTermsError = !_acceptedTerms;
    });
    final valid = _formKey.currentState!.validate();
    if (!valid || !_acceptedTerms) return;
    FocusScope.of(context).unfocus();

    setState(() => _submitting = true);
    final result = await context.read<AuthController>().register(
          name: _name.text,
          email: _email.text,
          phone: _phone.text,
          password: _password.text,
        );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (!result.isSuccess) {
      setState(() => _error = result.message);
      return;
    }
    // Design promises "Instant Access": the new (demo) account is signed in.
    _completed = true;
    showAppSnackBar(
      context,
      context.read<AuthController>().isDemoMode
          ? 'Welcome, ${_name.text.trim().split(' ').first}! Demo account saved on this device.'
          : 'Welcome, ${_name.text.trim().split(' ').first}!',
    );
    context.go(AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    return UnsavedChangesGuard(
      hasChanges: _hasChanges,
      onDiscard: () => context.canPop()
          ? context.pop()
          : context.go(AppRoutes.login),
      child: Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Form(
                  key: _formKey,
                  child: AutofillGroup(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            CircleIconButton(
                              icon: Icons.arrow_back,
                              tooltip: 'Back',
                              shadow: true,
                              onPressed: () => context.popOrGo(AppRoutes.login),
                            ),
                            const Pill(
                              label: 'Fast Bites',
                              icon: Icons.local_fire_department,
                              background: AppColors.primaryFixed,
                              foreground: AppColors.onPrimaryFixed,
                              uppercase: true,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // New-user offer from GET /offers; hidden on failure.
                        RequestBuilder<List<Offer>>(
                          request: context.read<OfferService>().getOffers,
                          loading: const SizedBox.shrink(),
                          isEmpty: (offers) => offers.isEmpty,
                          errorBuilder: (_, _) => const SizedBox.shrink(),
                          builder: (context, offers) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: _BonusCard(offer: offers.last),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text('Create Account', style: AppText.headlineLg),
                        const SizedBox(height: 4),
                        Text(
                          'Join Apna Food and enjoy fast delivery.',
                          style: AppText.bodyMd.copyWith(
                            color: AppColors.outline,
                          ),
                        ),
                        const SizedBox(height: 20),
                        AppTextField(
                          label: 'Full Name',
                          controller: _name,
                          icon: Icons.person_outline,
                          hint: 'Rahul Sharma',
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.name],
                          validator: Validators.name,
                          onFieldSubmitted: (_) => _emailFocus.requestFocus(),
                        ),
                        const SizedBox(height: 14),
                        AppTextField(
                          label: 'Email Address',
                          controller: _email,
                          focusNode: _emailFocus,
                          icon: Icons.mail_outline,
                          hint: 'rahul@apnafood.com',
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.email],
                          validator: Validators.email,
                          onFieldSubmitted: (_) => _phoneFocus.requestFocus(),
                        ),
                        const SizedBox(height: 14),
                        AppTextField(
                          label: 'Phone Number',
                          controller: _phone,
                          focusNode: _phoneFocus,
                          icon: Icons.phone_iphone,
                          hint: '98765 43210',
                          keyboardType: TextInputType.phone,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [
                            AutofillHints.telephoneNumberNational,
                          ],
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[0-9 ]')),
                            LengthLimitingTextInputFormatter(11),
                          ],
                          prefix: const _CountryCode(),
                          validator: Validators.indianPhone,
                          onFieldSubmitted: (_) =>
                              _passwordFocus.requestFocus(),
                        ),
                        const SizedBox(height: 14),
                        AppTextField(
                          label: 'Password',
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
                          label: 'Confirm Password',
                          controller: _confirm,
                          focusNode: _confirmFocus,
                          icon: Icons.lock_reset,
                          hint: 'Repeat your password',
                          isPassword: true,
                          textInputAction: TextInputAction.done,
                          validator: (v) =>
                              Validators.confirmPassword(v, _password.text),
                          onFieldSubmitted: (_) => _submit(),
                          suffix: AnimatedOpacity(
                            duration: const Duration(milliseconds: 200),
                            opacity: _passwordsMatch ? 1 : 0,
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Container(
                                width: 24,
                                height: 24,
                                decoration: const BoxDecoration(
                                  color: AppColors.tertiary,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.check,
                                  size: 15,
                                  color: Colors.white,
                                  semanticLabel:
                                      _passwordsMatch ? 'Passwords match' : null,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _TermsCheckbox(
                          value: _acceptedTerms,
                          showError: _showTermsError,
                          onChanged: (v) => setState(() {
                            _acceptedTerms = v;
                            if (v) _showTermsError = false;
                          }),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          AuthErrorBanner(message: _error!),
                        ],
                        const SizedBox(height: 20),
                        PrimaryButton(
                          label: 'Sign Up',
                          icon: Icons.arrow_forward,
                          loading: _submitting,
                          loadingLabel: 'Creating account…',
                          onPressed: _submit,
                        ),
                        const SizedBox(height: 20),
                        Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              'Already have an account?',
                              style: AppText.bodyMd.copyWith(
                                color: AppColors.outline,
                              ),
                            ),
                            const SizedBox(width: 4),
                            LinkButton(
                              label: 'Login',
                              style: AppText.labelLg,
                              onPressed: () => context.popOrGo(AppRoutes.login),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _TrustBadge(
                              icon: Icons.verified_user,
                              color: AppColors.tertiary,
                              label: '100% Secure',
                            ),
                            SizedBox(width: 24),
                            _TrustBadge(
                              icon: Icons.speed,
                              color: AppColors.primary,
                              label: 'Instant Access',
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
      ),
    );
  }
}

class _BonusCard extends StatelessWidget {
  const _BonusCard({required this.offer});

  final Offer offer;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: AppRadius.xl,
        boxShadow: AppShadows.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.stars, size: 13, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Text(
                      'NEW FOODIE BONUS',
                      style: AppText.labelSm.copyWith(
                        color: AppColors.primary,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text('Get ${offer.title}', style: AppText.titleMd),
                Text(
                  '${offer.subtitle} · code ${offer.code}',
                  style: AppText.bodySm.copyWith(color: AppColors.outline),
                ),
              ],
            ),
          ),
          AppImage(
            offer.imageUrl ?? 'assets/images/thali.jpg',
            width: 64,
            height: 64,
            borderRadius: AppRadius.xl,
          ),
        ],
      ),
    );
  }
}

class _CountryCode extends StatelessWidget {
  const _CountryCode();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: const BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: AppRadius.lg,
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('🇮🇳', style: TextStyle(fontSize: 13)),
          SizedBox(width: 6),
          Text('+91', style: AppText.labelMd),
        ],
      ),
    );
  }
}

class _TermsCheckbox extends StatelessWidget {
  const _TermsCheckbox({
    required this.value,
    required this.showError,
    required this.onChanged,
  });

  final bool value;
  final bool showError;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final linkStyle = AppText.labelSm.copyWith(
      decoration: TextDecoration.underline,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          checked: value,
          label: 'I agree to the Terms and Conditions and Privacy Policy',
          child: InkWell(
            onTap: () => onChanged(!value),
            borderRadius: AppRadius.lg,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 20,
                    height: 20,
                    margin: const EdgeInsets.only(top: 1),
                    decoration: BoxDecoration(
                      color: value
                          ? AppColors.primaryContainer
                          : AppColors.surfaceContainerHigh,
                      borderRadius: AppRadius.lg,
                      border: showError
                          ? Border.all(color: AppColors.error, width: 1.5)
                          : null,
                    ),
                    child: value
                        ? const Icon(Icons.check, size: 16, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        text: 'I agree to the ',
                        children: [
                          TextSpan(text: 'Terms & Conditions', style: linkStyle),
                          const TextSpan(text: ' and '),
                          TextSpan(text: 'Privacy Policy', style: linkStyle),
                        ],
                      ),
                      style: AppText.bodySm.copyWith(color: AppColors.outline),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (showError)
          Padding(
            padding: const EdgeInsets.only(left: 32, top: 2),
            child: Text(
              'Please accept the terms to continue',
              style: AppText.bodySm.copyWith(color: AppColors.error),
            ),
          ),
      ],
    );
  }
}

class _TrustBadge extends StatelessWidget {
  const _TrustBadge({
    required this.icon,
    required this.color,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(label, style: AppText.labelSm.copyWith(color: AppColors.outline)),
      ],
    );
  }
}
