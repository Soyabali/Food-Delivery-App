import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/router/app_routes.dart';
import '../../core/api/api_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/common.dart';
import '../../state/auth_controller.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, this.from});

  /// Location the user originally requested (deep link), if any.
  final String? from;

  /// Long enough to show the brand, short enough not to feel slow.
  static const minimumDisplay = Duration(milliseconds: 1600);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..forward();
  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  bool _navigated = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    setState(() => _error = null);
    final auth = context.read<AuthController>();
    try {
      await Future.wait([
        auth.restoreSession(),
        Future<void>.delayed(SplashScreen.minimumDisplay),
      ]);
    } catch (e) {
      // Session couldn't be verified (offline, server down): offer a retry
      // rather than silently logging the user out.
      if (mounted) setState(() => _error = toApiException(e).message);
      return;
    }
    if (!mounted || _navigated) return;
    _navigated = true;

    final from = widget.from;
    final canResume = from != null &&
        !AppRoutes.public.contains(Uri.parse(from).path);
    if (auth.isAuthenticated) {
      context.go(canResume ? from : AppRoutes.home);
    } else {
      // No onboarding screens exist in the design, so go straight to login.
      context.go(AppRoutes.login);
    }
  }

  @override
  void dispose() {
    _intro.dispose();
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fade = CurvedAnimation(parent: _intro, curve: Curves.easeOut);
    final scale = Tween(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _intro, curve: Curves.easeOutBack),
    );

    return PopScope(
      canPop: false, // nothing behind the splash screen
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Stack(
          children: [
            const _Blob(
              top: -128,
              left: -128,
              size: 320,
              color: AppColors.primaryFixed,
              opacity: 0.55,
            ),
            const _Blob(
              top: 260,
              right: -96,
              size: 288,
              color: AppColors.secondaryFixed,
              opacity: 0.5,
            ),
            const _Blob(
              bottom: -80,
              left: 90,
              size: 352,
              color: AppColors.primaryContainer,
              opacity: 0.12,
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: _KitchensLive(loop: _loop),
                    ),
                    Expanded(
                      child: Center(
                        child: SingleChildScrollView(
                          child: FadeTransition(
                            opacity: fade,
                            child: ScaleTransition(
                              scale: scale,
                              child: _Brand(loop: _loop),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (_error != null) ...[
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: AppText.bodyMd.copyWith(color: AppColors.error),
                      ),
                      TextButton(onPressed: _start, child: const Text('Retry')),
                    ] else
                      _BouncingDots(loop: _loop),
                    const SizedBox(height: 16),
                    Text.rich(
                      TextSpan(
                        text: 'V2.4.0 • MADE WITH ',
                        children: [
                          TextSpan(
                            text: '♥',
                            style: AppText.labelSm.copyWith(
                              color: AppColors.secondary,
                            ),
                          ),
                          const TextSpan(text: ' FOR FOODIES'),
                        ],
                      ),
                      style: AppText.labelSm.copyWith(
                        color: AppColors.outline,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.clean_hands_outlined,
                          size: 13,
                          color: AppColors.outline,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '100% Contactless & Hygienic',
                          style: AppText.labelSm.copyWith(
                            color: AppColors.outline.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand({required this.loop});

  final Animation<double> loop;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: 140,
          height: 140,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  borderRadius: AppRadius.xxxl,
                  gradient: LinearGradient(
                    begin: Alignment.bottomLeft,
                    end: Alignment.topRight,
                    colors: [
                      AppColors.primaryContainer.withValues(alpha: 0.18),
                      AppColors.secondaryContainer.withValues(alpha: 0.18),
                    ],
                  ),
                ),
              ),
              Container(
                width: 112,
                height: 112,
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: AppRadius.xxxl,
                  boxShadow: AppShadows.lg,
                ),
                child: const AppLogo(size: 96),
              ),
              Positioned(
                top: 4,
                right: 2,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: AppShadows.md,
                  ),
                  child: const Icon(
                    Icons.local_fire_department,
                    size: 18,
                    color: AppColors.primaryContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) => const LinearGradient(
            colors: [
              AppColors.primaryContainer,
              AppColors.secondaryContainer,
              AppColors.secondary,
            ],
          ).createShader(bounds),
          child: const Text('Apna Food', style: AppText.headlineXl),
        ),
        const SizedBox(height: 6),
        Text.rich(
          TextSpan(
            text: 'Fresh Food, ',
            style: AppText.bodyMd.copyWith(fontWeight: FontWeight.w600),
            children: [
              TextSpan(
                text: 'Fast Delivery.',
                style: AppText.bodyMd.copyWith(
                  color: AppColors.outline,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Container(
          width: 270,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLow.withValues(alpha: 0.8),
            borderRadius: AppRadius.xxl,
            boxShadow: AppShadows.sm,
          ),
          child: Column(
            children: [
              SizedBox(
                width: 112,
                height: 80,
                child: AnimatedBuilder(
                  animation: loop,
                  builder: (context, _) => CustomPaint(
                    painter: _DeliveryPainter(steam: loop.value),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Pill(
                label: 'Hyperlocal in 20 Mins',
                icon: Icons.bolt,
                background: AppColors.surfaceContainer,
                foreground: AppColors.onSurface,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _KitchensLive extends StatelessWidget {
  const _KitchensLive({required this.loop});

  final Animation<double> loop;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: const BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: AppRadius.full,
        boxShadow: AppShadows.sm,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FadeTransition(
            opacity: Tween(begin: 0.4, end: 1.0).animate(
              CurvedAnimation(parent: loop, curve: Curves.easeInOut),
            ),
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppColors.tertiaryContainer,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'KITCHENS LIVE',
            style: AppText.labelSm.copyWith(letterSpacing: 1.1),
          ),
        ],
      ),
    );
  }
}

class _BouncingDots extends StatelessWidget {
  const _BouncingDots({required this.loop});

  final Animation<double> loop;

  @override
  Widget build(BuildContext context) {
    const colors = [
      AppColors.primaryContainer,
      AppColors.secondaryContainer,
      AppColors.primaryFixedDim,
    ];
    return Semantics(
      label: 'Loading',
      child: AnimatedBuilder(
        animation: loop,
        builder: (context, _) => Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < 3; i++)
              Transform.translate(
                offset: Offset(
                  0,
                  -6 * math.max(0, math.sin((loop.value - i * 0.15) * 2 * math.pi)),
                ),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: colors[i],
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({
    this.top,
    this.left,
    this.right,
    this.bottom,
    required this.size,
    required this.color,
    required this.opacity,
  });

  final double? top, left, right, bottom;
  final double size;
  final Color color;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      left: left,
      right: right,
      bottom: bottom,
      child: IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                color.withValues(alpha: opacity),
                color.withValues(alpha: 0),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Port of the Stitch inline SVG (cloche on a scooter, viewBox 140x100).
class _DeliveryPainter extends CustomPainter {
  _DeliveryPainter({required this.steam});

  final double steam;

  static const _ink = Color(0xFF121C2A);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 140, size.height / 100);

    Paint stroke(Color c, double w) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    Paint fill(Color c) => Paint()..color = c;

    final pulse = 0.5 + 0.5 * math.sin(steam * 2 * math.pi);
    canvas.drawPath(
      Path()
        ..moveTo(48, 24)
        ..cubicTo(48, 18, 52, 14, 58, 14)
        ..cubicTo(62, 14, 65, 17, 65, 20)
        ..cubicTo(65, 24, 59, 26, 59, 30),
      stroke(const Color(0xFFFF6B35).withValues(alpha: 0.4 + 0.4 * pulse), 2.5),
    );
    canvas.drawPath(
      Path()
        ..moveTo(72, 20)
        ..cubicTo(72, 15, 76, 11, 81, 11)
        ..cubicTo(85, 11, 88, 14, 88, 18)
        ..cubicTo(88, 22, 83, 24, 83, 28),
      stroke(const Color(0xFFDE2B41).withValues(alpha: 0.6 - 0.3 * pulse), 2.5),
    );
    canvas.drawCircle(const Offset(70, 38), 4, fill(const Color(0xFFFF6B35)));

    final dome = Path()
      ..moveTo(26, 62)
      ..cubicTo(26, 43, 45.7, 39, 70, 39)
      ..cubicTo(94.3, 39, 114, 43, 114, 62)
      ..close();
    canvas.drawPath(dome, fill(const Color(0xFFE6EEFF)));
    canvas.drawPath(dome, stroke(_ink, 2.5));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(20, 62, 100, 5),
        const Radius.circular(2.5),
      ),
      fill(_ink),
    );

    canvas.translate(0, 4);
    for (final (x, hub) in [(50.0, 0xFFDE2B41), (90.0, 0xFFFF6B35)]) {
      canvas.drawCircle(Offset(x, 84), 8, fill(Colors.white));
      canvas.drawCircle(Offset(x, 84), 8, stroke(_ink, 2.5));
      canvas.drawCircle(Offset(x, 84), 3, fill(Color(hub)));
    }
    canvas.drawPath(
      Path()
        ..moveTo(50, 84)
        ..lineTo(74, 84)
        ..lineTo(82, 74)
        ..lineTo(90, 74),
      stroke(_ink, 2.5),
    );
    canvas.drawPath(
      Path()
        ..moveTo(72, 74)
        ..lineTo(68, 67)
        ..lineTo(60, 67),
      stroke(_ink, 2),
    );
  }

  @override
  bool shouldRepaint(_DeliveryPainter old) => old.steam != steam;
}
