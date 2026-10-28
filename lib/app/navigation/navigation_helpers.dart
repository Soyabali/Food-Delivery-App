import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

extension SafeNavigation on BuildContext {
  /// Pops when there is somewhere to go back to (respecting PopScope guards),
  /// otherwise replaces the stack with [fallback]. Handles screens opened via
  /// a deep link where there is no previous page.
  void popOrGo(String fallback) {
    if (canPop()) {
      Navigator.of(this).maybePop();
    } else {
      go(fallback);
    }
  }
}
