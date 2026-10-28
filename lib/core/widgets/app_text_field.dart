import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Labelled input matching the Stitch fields: tinted fill, 52px tall,
/// leading icon, white fill + shadow while focused.
class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    required this.label,
    required this.controller,
    required this.icon,
    this.hint,
    this.labelTrailing,
    this.focusNode,
    this.validator,
    this.keyboardType,
    this.textInputAction,
    this.onFieldSubmitted,
    this.onChanged,
    this.autofillHints,
    this.isPassword = false,
    this.prefix,
    this.suffix,
    this.inputFormatters,
    this.enabled = true,
    this.textCapitalization = TextCapitalization.none,
    this.filled = true,
  });

  final String label;
  final TextEditingController controller;
  final IconData icon;
  final String? hint;
  final Widget? labelTrailing;
  final FocusNode? focusNode;
  final FormFieldValidator<String>? validator;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onFieldSubmitted;
  final ValueChanged<String>? onChanged;
  final Iterable<String>? autofillHints;
  final bool isPassword;
  final Widget? prefix;

  /// Replaces the password visibility toggle when provided.
  final Widget? suffix;
  final List<TextInputFormatter>? inputFormatters;
  final bool enabled;
  final TextCapitalization textCapitalization;

  /// `false` renders the white-with-shadow variant used on some screens.
  final bool filled;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late FocusNode _focusNode;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_onFocus);
  }

  void _onFocus() => setState(() {});

  @override
  void dispose() {
    _focusNode.removeListener(_onFocus);
    if (widget.focusNode == null) _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final focused = _focusNode.hasFocus;
    final idleFill = widget.filled
        ? AppColors.surfaceContainerLow
        : AppColors.surfaceContainerLowest;
    final focusFill = widget.filled
        ? AppColors.surfaceContainerLowest
        : AppColors.surfaceContainerLow;

    Widget? suffix = widget.suffix;
    if (suffix == null && widget.isPassword) {
      suffix = IconButton(
        tooltip: _obscure ? 'Show password' : 'Hide password',
        onPressed: () => setState(() => _obscure = !_obscure),
        icon: Icon(
          _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
          size: 20,
          color: AppColors.outline,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(widget.label, style: AppText.labelMd)),
            ?widget.labelTrailing,
          ],
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: widget.controller,
          focusNode: _focusNode,
          validator: widget.validator,
          enabled: widget.enabled,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          onFieldSubmitted: widget.onFieldSubmitted,
          onChanged: widget.onChanged,
          autofillHints: widget.autofillHints,
          obscureText: widget.isPassword && _obscure,
          enableSuggestions: !widget.isPassword,
          autocorrect: !widget.isPassword,
          inputFormatters: widget.inputFormatters,
          textCapitalization: widget.textCapitalization,
          autovalidateMode: AutovalidateMode.onUserInteractionIfError,
          style: AppText.bodyMd,
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: AppText.bodyMd.copyWith(
              color: AppColors.outline.withValues(alpha: 0.7),
            ),
            filled: true,
            fillColor: focused ? focusFill : idleFill,
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
            prefixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(width: 14),
                ?widget.prefix,
                Icon(widget.icon, size: 20, color: AppColors.outline),
                const SizedBox(width: 10),
              ],
            ),
            suffixIcon: suffix,
            errorMaxLines: 2,
            errorStyle: AppText.bodySm.copyWith(color: AppColors.error),
            border: _border(Colors.transparent),
            enabledBorder: _border(Colors.transparent),
            disabledBorder: _border(Colors.transparent),
            focusedBorder: _border(
              AppColors.primaryContainer.withValues(alpha: 0.4),
              width: 2,
            ),
            errorBorder: _border(AppColors.error.withValues(alpha: 0.6)),
            focusedErrorBorder: _border(AppColors.error, width: 2),
          ),
        ),
      ],
    );
  }

  static OutlineInputBorder _border(Color color, {double width = 1}) =>
      OutlineInputBorder(
        borderRadius: AppRadius.xl,
        borderSide: BorderSide(color: color, width: width),
      );
}
