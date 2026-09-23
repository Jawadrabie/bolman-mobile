import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/cubits.dart';
import '../features/passenger/onboarding_screen.dart';
import 'i18n/l10n.dart';
import 'theme.dart';

/// Gradient-only shell shown while [GoRouter] initializes — matches native launch screen.
class SplashBootstrap extends StatelessWidget {
  const SplashBootstrap({super.key});

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(gradient: AppGradients.hero),
      child: SizedBox.expand(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  static const _minSplash = Duration(milliseconds: 3500);

  late final AnimationController _master;
  late final AnimationController _pulse;
  late final AnimationController _ripple;
  late final AnimationController _shimmer;
  late final AnimationController _lines;

  @override
  void initState() {
    super.initState();

    _master = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))..repeat(reverse: true);
    _ripple = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))..repeat();
    _shimmer = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat();
    _lines = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat();

    unawaited(_master.forward());
    unawaited(_resolve());
  }

  Future<void> _resolve() async {
    final started = DateTime.now();
    final auth = context.read<AuthCubit>();

    if (auth.state.loading) {
      await auth.stream.firstWhere((s) => !s.loading);
    }

    final elapsed = DateTime.now().difference(started);
    if (elapsed < _minSplash) {
      await Future<void>.delayed(_minSplash - elapsed);
    }

    if (!mounted) return;

    final a = auth.state;
    if (a.authed) {
      context.go(a.isDriver ? '/driver' : '/home');
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool(OnboardingScreen.seenKey) ?? false;
    if (!mounted) return;
    context.go(seen ? '/login' : '/onboarding');
  }

  @override
  void dispose() {
    _master.dispose();
    _pulse.dispose();
    _ripple.dispose();
    _shimmer.dispose();
    _lines.dispose();
    super.dispose();
  }

  double _progress(double t, double start, double end) {
    if (t <= start) return 0;
    if (t >= end) return 1;
    return (t - start) / (end - start);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final logoSize = math.min(size.width * 0.64, 270.0);

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(decoration: BoxDecoration(gradient: AppGradients.hero)),
          ..._backgroundOrbs(size),
          _SpeedLines(controller: _lines),
          AnimatedBuilder(
            animation: Listenable.merge([_master, _pulse, _ripple]),
            builder: (context, _) {
              final t = _master.value;
              final logoScale = TweenSequence<double>([
                TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.14), weight: 55),
                TweenSequenceItem(tween: Tween(begin: 1.14, end: 1.0), weight: 45),
              ]).transform(t.clamp(0.0, 1.0));
              final logoOpacity = Curves.easeOut.transform(_progress(t, 0, 0.25));
              final titleOpacity = Curves.easeOut.transform(_progress(t, 0.38, 0.78));
              final titleDy = (1 - Curves.easeOutCubic.transform(_progress(t, 0.38, 0.82))) * 28;
              final breathe = 1 + (_pulse.value * 0.04);

              return Stack(
                fit: StackFit.expand,
                children: [
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: logoSize * 1.35,
                          height: logoSize * 1.35,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              for (var i = 0; i < 3; i++)
                                _RippleRing(
                                  progress: (_ripple.value + i * 0.33) % 1.0,
                                  size: logoSize,
                                ),
                              Transform.scale(
                                scale: logoScale * breathe,
                                child: Opacity(
                                  opacity: logoOpacity,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.white.withValues(alpha: 0.35 + _pulse.value * 0.15),
                                          blurRadius: logoSize * 0.38,
                                          spreadRadius: logoSize * 0.02,
                                        ),
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.22),
                                          blurRadius: 32,
                                          offset: const Offset(0, 16),
                                        ),
                                      ],
                                    ),
                                    child: SvgPicture.asset(
                                      'assets/images/app_logo.svg',
                                      width: logoSize,
                                      height: logoSize,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 32 + titleDy * 0.15),
                        Opacity(
                          opacity: titleOpacity,
                          child: Transform.translate(
                            offset: Offset(0, titleDy),
                            child: _ShimmerTitle(
                              controller: _shimmer,
                              opacity: titleOpacity,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 52,
                    child: Opacity(
                      opacity: titleOpacity,
                      child: _LoadingBar(progress: (_ripple.value + _pulse.value * 0.15) % 1.0),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  List<Widget> _backgroundOrbs(Size size) {
    return [
      _FloatingOrb(
        top: size.height * 0.06,
        left: -size.width * 0.14,
        size: size.width * 0.58,
        opacity: 0.11,
        duration: const Duration(seconds: 8),
      ),
      _FloatingOrb(
        bottom: size.height * 0.12,
        right: -size.width * 0.2,
        size: size.width * 0.66,
        opacity: 0.09,
        duration: const Duration(seconds: 10),
        reverse: true,
      ),
      _FloatingOrb(
        top: size.height * 0.38,
        right: size.width * 0.02,
        size: size.width * 0.24,
        opacity: 0.13,
        duration: const Duration(seconds: 6),
      ),
    ];
  }
}

class _ShimmerTitle extends StatelessWidget {
  const _ShimmerTitle({required this.controller, required this.opacity});

  final AnimationController controller;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment(-1.5 + controller.value * 3, 0),
              end: Alignment(-0.5 + controller.value * 3, 0),
              colors: [
                Colors.white.withValues(alpha: 0.75),
                Colors.white,
                Colors.white.withValues(alpha: 0.75),
              ],
              stops: const [0.2, 0.5, 0.8],
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: Column(
        children: [
          Text(
            context.tr('auth.heroTitle'),
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.4,
                ),
          ),
          const SizedBox(height: 10),
          Text(
            context.tr('auth.heroSubtitle'),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.84 * opacity),
                  fontWeight: FontWeight.w500,
                ),
          ),
        ],
      ),
    );
  }
}

class _RippleRing extends StatelessWidget {
  const _RippleRing({required this.progress, required this.size});

  final double progress;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scale = 0.85 + progress * 0.55;
    final opacity = (1 - progress) * 0.28;

    return Transform.scale(
      scale: scale,
      child: Opacity(
        opacity: opacity,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.55), width: 2),
          ),
        ),
      ),
    );
  }
}

class _SpeedLines extends StatelessWidget {
  const _SpeedLines({required this.controller});

  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return CustomPaint(
          size: size,
          painter: _SpeedLinesPainter(controller.value),
        );
      },
    );
  }
}

class _SpeedLinesPainter extends CustomPainter {
  _SpeedLinesPainter(this.t);

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.07)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < 6; i++) {
      final baseY = size.height * (0.18 + i * 0.12);
      final offset = ((t + i * 0.14) % 1.0) * size.width;
      final lineW = size.width * (0.08 + (i % 3) * 0.03);
      canvas.drawLine(
        Offset(offset - lineW, baseY),
        Offset(offset, baseY),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SpeedLinesPainter oldDelegate) => oldDelegate.t != t;
}

class _LoadingBar extends StatelessWidget {
  const _LoadingBar({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 120,
        height: 3,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: Stack(
            children: [
              Container(color: Colors.white.withValues(alpha: 0.18)),
              FractionallySizedBox(
                widthFactor: 0.35 + progress * 0.45,
                alignment: Alignment(-1 + progress * 2, 0),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.2),
                        Colors.white.withValues(alpha: 0.95),
                        Colors.white.withValues(alpha: 0.2),
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

class _FloatingOrb extends StatefulWidget {
  const _FloatingOrb({
    required this.size,
    required this.opacity,
    required this.duration,
    this.top,
    this.left,
    this.right,
    this.bottom,
    this.reverse = false,
  });

  final double size;
  final double opacity;
  final Duration duration;
  final double? top;
  final double? left;
  final double? right;
  final double? bottom;
  final bool reverse;

  @override
  State<_FloatingOrb> createState() => _FloatingOrbState();
}

class _FloatingOrbState extends State<_FloatingOrb> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: widget.top,
      left: widget.left,
      right: widget.right,
      bottom: widget.bottom,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final v = widget.reverse ? 1 - _controller.value : _controller.value;
          return Transform.translate(
            offset: Offset(math.sin(v * math.pi) * 12, (v - 0.5) * 22),
            child: Opacity(
              opacity: widget.opacity * (0.7 + v * 0.3),
              child: child,
            ),
          );
        },
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.16),
          ),
        ),
      ),
    );
  }
}
