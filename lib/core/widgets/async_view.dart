import 'package:flutter/material.dart';

import '../api/api_exception.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'adaptive_dialogs.dart';
import 'common.dart';

/// Runs [request] and renders loading / error (with retry) / empty / data.
///
/// Changing [requestKey] re-runs the request; results of superseded requests
/// are ignored, so fast typing in search never shows stale results.
class RequestBuilder<T> extends StatefulWidget {
  const RequestBuilder({
    super.key,
    required this.request,
    required this.builder,
    this.requestKey,
    this.loading,
    this.isEmpty,
    this.empty,
    this.compactError = false,
    this.errorBuilder,
  });

  final Future<T> Function() request;
  final Widget Function(BuildContext context, T data) builder;
  final Object? requestKey;
  final Widget? loading;
  final bool Function(T data)? isEmpty;
  final Widget? empty;

  /// Smaller inline error for a section of a screen.
  final bool compactError;

  /// Overrides the default error view (e.g. hide optional content).
  final Widget Function(ApiException error, VoidCallback retry)? errorBuilder;

  @override
  State<RequestBuilder<T>> createState() => _RequestBuilderState<T>();
}

class _RequestBuilderState<T> extends State<RequestBuilder<T>> {
  int _generation = 0;
  bool _loading = true;
  T? _data;
  ApiException? _error;

  @override
  void initState() {
    super.initState();
    _run();
  }

  @override
  void didUpdateWidget(RequestBuilder<T> old) {
    super.didUpdateWidget(old);
    if (old.requestKey != widget.requestKey) _run();
  }

  Future<void> _run() async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await widget.request();
      if (!mounted || generation != _generation) return; // stale
      setState(() {
        _data = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _error = toApiException(e);
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return widget.loading ?? const Center(child: Padding(
        padding: EdgeInsets.all(32),
        child: CircularProgressIndicator(),
      ));
    }
    if (_error != null) {
      if (widget.errorBuilder != null) return widget.errorBuilder!(_error!, _run);
      return ErrorView(
        error: _error!,
        onRetry: _run,
        compact: widget.compactError,
      );
    }
    final data = _data as T;
    if (widget.isEmpty?.call(data) ?? false) {
      return widget.empty ?? const SizedBox.shrink();
    }
    return widget.builder(context, data);
  }
}

/// Error message in the app's style with a Retry button.
class ErrorView extends StatelessWidget {
  const ErrorView({
    super.key,
    required this.error,
    this.onRetry,
    this.compact = false,
  });

  final ApiException error;
  final VoidCallback? onRetry;
  final bool compact;

  IconData get _icon => switch (error.type) {
        ApiErrorType.network => Icons.wifi_off_rounded,
        ApiErrorType.timeout => Icons.hourglass_empty_rounded,
        ApiErrorType.notFound => Icons.search_off_rounded,
        ApiErrorType.unauthorized => Icons.lock_outline,
        _ => Icons.cloud_off_rounded,
      };

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: const BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: AppRadius.xl,
        ),
        child: Row(
          children: [
            Icon(_icon, size: 20, color: AppColors.outline),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                error.message,
                style: AppText.bodySm.copyWith(color: AppColors.onSurfaceVariant),
              ),
            ),
            if (onRetry != null)
              TextButton(
                onPressed: onRetry,
                child: Text(
                  'Retry',
                  style: AppText.labelMd.copyWith(color: AppColors.primaryContainer),
                ),
              ),
          ],
        ),
      );
    }
    return EmptyState(
      icon: _icon,
      title: switch (error.type) {
        ApiErrorType.network => 'You’re offline',
        ApiErrorType.notFound => 'Not found',
        _ => 'Couldn’t load this',
      },
      message: error.message,
      actionLabel: onRetry == null ? null : 'Retry',
      onAction: onRetry,
    );
  }
}

/// Pulsing placeholder block for skeleton loading states.
class SkeletonBox extends StatefulWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height = 16,
    this.radius = AppRadius.lg,
  });

  final double? width;
  final double height;
  final BorderRadius radius;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.45, end: 1.0).animate(_c),
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: AppColors.surfaceContainer,
          borderRadius: widget.radius,
        ),
      ),
    );
  }
}

/// Skeleton for a list of image + text rows.
class ListSkeleton extends StatelessWidget {
  const ListSkeleton({super.key, this.count = 3, this.imageSize = 80});

  final int count;
  final double imageSize;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading',
      child: Column(
        children: [
          for (var i = 0; i < count; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  SkeletonBox(width: imageSize, height: imageSize, radius: AppRadius.xl),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SkeletonBox(width: 160, height: 16),
                        SizedBox(height: 8),
                        SkeletonBox(width: 110, height: 12),
                        SizedBox(height: 12),
                        SkeletonBox(width: 200, height: 12),
                      ],
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

/// Runs a mutation and shows its error as a snackbar. Returns true on success.
Future<bool> runWithFeedback(
  BuildContext context,
  Future<void> Function() action,
) async {
  try {
    await action();
    return true;
  } catch (e) {
    if (context.mounted) showAppSnackBar(context, toApiException(e).message);
    return false;
  }
}
