import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

import '../../app/i18n/l10n.dart';
import '../../app/theme.dart';
import '../../shared/widgets.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  static const seenKey = 'onboarding_seen';

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> with TickerProviderStateMixin {
  final _controller = PageController();
  late final AnimationController _floatController;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _floatController.dispose();
    _controller.dispose();
    super.dispose();
  }

  List<_OnboardItem> _items(BuildContext context) => [
        _OnboardItem(
          title: context.tr('passenger.onboardingTitle1'),
          body: context.tr('passenger.onboardingBody1'),
          asset: 'assets/images/onboarding_search.svg',
          icon: Icons.search_rounded,
          gradient: const [Color(0xFF6C63FF), Color(0xFF5146E5)],
        ),
        _OnboardItem(
          title: context.tr('passenger.onboardingTitle2'),
          body: context.tr('passenger.onboardingBody2'),
          asset: 'assets/images/onboarding_booking.svg',
          icon: Icons.event_seat_rounded,
          gradient: const [Color(0xFF5146E5), Color(0xFF4338CA)],
        ),
        _OnboardItem(
          title: context.tr('passenger.onboardingTitle3'),
          body: context.tr('passenger.onboardingBody3'),
          asset: 'assets/images/onboarding_travel.svg',
          icon: Icons.qr_code_scanner_rounded,
          gradient: const [Color(0xFF7C6CFF), Color(0xFF6C63FF)],
        ),
        _OnboardItem(
          title: context.tr('passenger.onboardingTitle4'),
          body: context.tr('passenger.onboardingBody4'),
          asset: 'assets/images/onboarding_wallet.svg',
          icon: Icons.account_balance_wallet_rounded,
          gradient: const [Color(0xFF5B52E8), Color(0xFF6C63FF)],
        ),
      ];

  Future<void> _complete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(OnboardingScreen.seenKey, true);
    if (!mounted) return;
    context.go('/login');
  }

  Future<void> _onNext(int count) async {
    if (_index == count - 1) {
      await _complete();
      return;
    }
    await _controller.nextPage(
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _items(context);
    final last = _index == items.length - 1;
    final active = items[_index];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 520),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    Color.lerp(AppColors.darkBg, active.gradient.first, .22)!,
                    Color.lerp(AppColors.darkBg, active.gradient.last, .14)!,
                  ]
                : [
                    Color.lerp(AppColors.lightBg, active.gradient.first, .10)!,
                    Color.lerp(AppColors.softAccent, active.gradient.last, .35)!,
                  ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.sm, AppSpacing.xs, AppSpacing.md, 0),
                child: Row(
                  children: [
                    _StepBadge(current: _index + 1, total: items.length, colors: active.gradient),
                    const Spacer(),
                    TextButton(
                      onPressed: _complete,
                      style: TextButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: .72),
                      ),
                      child: Text(context.tr('passenger.skip')),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: items.length,
                  onPageChanged: (value) => setState(() => _index = value),
                  itemBuilder: (_, i) => _OnboardingSlide(
                    key: ValueKey(i),
                    item: items[i],
                    active: i == _index,
                    floatAnimation: _floatController,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.md, AppSpacing.xl, AppSpacing.xl),
                child: Column(
                  children: [
                    SmoothPageIndicator(
                      controller: _controller,
                      count: items.length,
                      effect: ExpandingDotsEffect(
                        dotHeight: 8,
                        dotWidth: 8,
                        expansionFactor: 4,
                        spacing: 8,
                        dotColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: .18),
                        activeDotColor: active.gradient.first,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => _onNext(items.length),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                          backgroundColor: active.gradient.first,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              last ? context.tr('passenger.getStarted') : context.tr('passenger.next'),
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                            ),
                            if (!last) ...[
                              const SizedBox(width: AppSpacing.xs),
                              const Icon(Icons.arrow_forward_rounded, size: 20),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepBadge extends StatelessWidget {
  final int current;
  final int total;
  final List<Color> colors;

  const _StepBadge({
    required this.current,
    required this.total,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        boxShadow: AppShadows.subtle(colors.first),
      ),
      child: Text(
        '$current / $total',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 13,
        ),
      ),
    );
  }
}

class _OnboardItem {
  final String title;
  final String body;
  final String asset;
  final IconData icon;
  final List<Color> gradient;

  const _OnboardItem({
    required this.title,
    required this.body,
    required this.asset,
    required this.icon,
    required this.gradient,
  });
}

class _OnboardingSlide extends StatefulWidget {
  final _OnboardItem item;
  final bool active;
  final Animation<double> floatAnimation;

  const _OnboardingSlide({
    super.key,
    required this.item,
    required this.active,
    required this.floatAnimation,
  });

  @override
  State<_OnboardingSlide> createState() => _OnboardingSlideState();
}

class _OnboardingSlideState extends State<_OnboardingSlide> with SingleTickerProviderStateMixin {
  late final AnimationController _enterController;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _enterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 680),
    );
    _fade = CurvedAnimation(parent: _enterController, curve: Curves.easeOutCubic);
    _slide = Tween<Offset>(begin: const Offset(0, .08), end: Offset.zero).animate(
      CurvedAnimation(parent: _enterController, curve: Curves.easeOutCubic),
    );
    if (widget.active) _enterController.forward();
  }

  @override
  void didUpdateWidget(covariant _OnboardingSlide oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) {
      _enterController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _enterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: .72);

    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.sm, AppSpacing.xl, 0),
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: AnimatedBuilder(
                    animation: widget.floatAnimation,
                    builder: (context, child) {
                      final t = widget.floatAnimation.value;
                      final dy = math.sin(t * math.pi) * 10;
                      final scale = 1 + (math.sin(t * math.pi) * .02);
                      return Transform.translate(
                        offset: Offset(0, dy),
                        child: Transform.scale(scale: scale, child: child),
                      );
                    },
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 260,
                          height: 260,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                widget.item.gradient.first.withValues(alpha: .22),
                                widget.item.gradient.last.withValues(alpha: 0),
                              ],
                            ),
                          ),
                        ),
                        GlassCard(
                          padding: const EdgeInsets.all(AppSpacing.xl),
                          child: Stack(
                            children: [
                              Positioned(
                                top: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(AppSpacing.sm),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(colors: widget.item.gradient),
                                    borderRadius: BorderRadius.circular(AppRadius.md),
                                    boxShadow: AppShadows.subtle(widget.item.gradient.first),
                                  ),
                                  child: Icon(widget.item.icon, color: Colors.white, size: 22),
                                ),
                              ),
                              Center(
                                child: SvgPicture.asset(
                                  widget.item.asset,
                                  height: 220,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                widget.item.title,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  height: 1.2,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                widget.item.body,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: muted,
                  height: 1.55,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

