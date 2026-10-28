import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'connectivity_service.dart';

/// Global overlay that shows a dismissible banner while offline and a brief
/// "Back online" confirmation when connectivity returns.
class OfflineBanner extends StatefulWidget {
  const OfflineBanner({
    super.key,
    required this.connectivity,
    required this.child,
  });

  final ConnectivityService connectivity;
  final Widget child;

  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}

enum _BannerMode { hidden, offline, restored }

class _OfflineBannerState extends State<OfflineBanner> {
  _BannerMode _mode = _BannerMode.hidden;
  bool _wasOffline = false;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    widget.connectivity.addListener(_onChanged);
    _onChanged();
  }

  void _onChanged() {
    final online = widget.connectivity.isOnline;
    _hideTimer?.cancel();
    if (!online) {
      _wasOffline = true;
      setState(() => _mode = _BannerMode.offline);
    } else if (_wasOffline) {
      _wasOffline = false;
      setState(() => _mode = _BannerMode.restored);
      _hideTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) setState(() => _mode = _BannerMode.hidden);
      });
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    widget.connectivity.removeListener(_onChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final offline = _mode == _BannerMode.offline;
    return Stack(
      children: [
        widget.child,
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          child: SafeArea(
            bottom: false,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              transitionBuilder: (child, animation) => SizeTransition(
                sizeFactor: animation,
                alignment: Alignment.topCenter,
                child: FadeTransition(opacity: animation, child: child),
              ),
              child: _mode == _BannerMode.hidden
                  ? const SizedBox.shrink(key: ValueKey('none'))
                  : Padding(
                      key: ValueKey(_mode),
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                      child: Material(
                        color: offline
                            ? AppColors.onSurface
                            : AppColors.tertiaryContainer,
                        borderRadius: AppRadius.xl,
                        elevation: 4,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
                          child: Row(
                            children: [
                              Icon(
                                offline ? Icons.wifi_off : Icons.wifi,
                                size: 18,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  offline
                                      ? "You're offline. Browsing still works; "
                                          'ordering needs internet.'
                                      : 'Back online',
                                  style: AppText.bodySm.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              if (offline)
                                // No IconButton/Tooltip: this sits above the
                                // Navigator, so there is no Overlay here.
                                Semantics(
                                  button: true,
                                  label: 'Dismiss offline banner',
                                  child: InkWell(
                                    customBorder: const CircleBorder(),
                                    onTap: () => setState(
                                      () => _mode = _BannerMode.hidden,
                                    ),
                                    child: const Padding(
                                      padding: EdgeInsets.all(7),
                                      child: Icon(
                                        Icons.close,
                                        size: 18,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                )
                              else
                                const SizedBox(height: 32),
                            ],
                          ),
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}
