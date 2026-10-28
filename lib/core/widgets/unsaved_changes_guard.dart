import 'package:flutter/material.dart';

import 'adaptive_dialogs.dart';

/// Wraps a form screen. When [hasChanges] is true, system back / iOS swipe /
/// in-app back buttons (which should call `Navigator.maybePop`) ask for
/// confirmation before discarding. Untouched forms pop immediately.
class UnsavedChangesGuard extends StatefulWidget {
  const UnsavedChangesGuard({
    super.key,
    required this.hasChanges,
    required this.child,
    this.onDiscard,
  });

  final bool hasChanges;
  final Widget child;

  /// Called after the user confirms; defaults to popping the route.
  final VoidCallback? onDiscard;

  @override
  State<UnsavedChangesGuard> createState() => _UnsavedChangesGuardState();
}

class _UnsavedChangesGuardState extends State<UnsavedChangesGuard> {
  bool _asking = false;

  Future<void> _confirm() async {
    if (_asking) return;
    _asking = true;
    final discard = await showConfirmDialog(
      context,
      title: 'Discard changes?',
      message: "You've entered some details. If you go back now they'll be lost.",
      confirmLabel: 'Discard',
      cancelLabel: 'Keep editing',
      destructive: true,
    );
    _asking = false;
    if (!discard || !mounted) return;
    if (widget.onDiscard != null) {
      widget.onDiscard!();
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !widget.hasChanges,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirm();
      },
      child: widget.child,
    );
  }
}
