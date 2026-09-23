import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// Rotating typewriter text — cycles phrases with a blinking cursor.
class TypewriterRotatingText extends StatefulWidget {
  final List<String> phrases;
  final TextStyle? style;
  final Duration charDelay;
  final Duration pauseAfterComplete;
  final Duration deleteDelay;

  const TypewriterRotatingText({
    super.key,
    required this.phrases,
    this.style,
    this.charDelay = const Duration(milliseconds: 55),
    this.pauseAfterComplete = const Duration(milliseconds: 1800),
    this.deleteDelay = const Duration(milliseconds: 28),
  });

  @override
  State<TypewriterRotatingText> createState() => _TypewriterRotatingTextState();
}

class _TypewriterRotatingTextState extends State<TypewriterRotatingText> with SingleTickerProviderStateMixin {
  late final AnimationController _cursor;
  int _phraseIndex = 0;
  int _charIndex = 0;
  bool _deleting = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _cursor = AnimationController(vsync: this, duration: const Duration(milliseconds: 520))..repeat(reverse: true);
    _scheduleTick();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _cursor.dispose();
    super.dispose();
  }

  void _scheduleTick() {
    _timer?.cancel();
    final phrase = widget.phrases.isEmpty ? '' : widget.phrases[_phraseIndex % widget.phrases.length];
    final delay = _deleting ? widget.deleteDelay : widget.charDelay;
    _timer = Timer(delay, () {
      if (!mounted) return;
      setState(() {
        if (!_deleting) {
          if (_charIndex < phrase.length) {
            _charIndex++;
          } else {
            _timer = Timer(widget.pauseAfterComplete, () {
              if (mounted) setState(() => _deleting = true);
              _scheduleTick();
            });
            return;
          }
        } else {
          if (_charIndex > 0) {
            _charIndex--;
          } else {
            _deleting = false;
            _phraseIndex = (_phraseIndex + 1) % widget.phrases.length;
          }
        }
      });
      _scheduleTick();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.phrases.isEmpty) return const SizedBox.shrink();
    final phrase = widget.phrases[_phraseIndex % widget.phrases.length];
    final visible = phrase.substring(0, _charIndex.clamp(0, phrase.length));
    final baseStyle = widget.style ?? Theme.of(context).textTheme.bodyMedium;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Flexible(
          child: Text(
            visible,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: baseStyle,
          ),
        ),
        FadeTransition(
          opacity: _cursor,
          child: Container(
            width: 2,
            height: (baseStyle?.fontSize ?? 14) + 2,
            margin: const EdgeInsetsDirectional.only(start: 2, bottom: 1),
            decoration: BoxDecoration(
              color: baseStyle?.color ?? Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ),
      ],
    );
  }
}

/// Horizontally scrolling strip — infinite marquee for city names.
class InfiniteMarquee extends StatefulWidget {
  final List<String> items;
  final TextStyle? textStyle;
  final double height;
  final double speed;

  const InfiniteMarquee({
    super.key,
    required this.items,
    this.textStyle,
    this.height = 36,
    this.speed = 42,
  });

  @override
  State<InfiniteMarquee> createState() => _InfiniteMarqueeState();
}

class _InfiniteMarqueeState extends State<InfiniteMarquee> with SingleTickerProviderStateMixin {
  late final ScrollController _controller;
  late final AnimationController _anim;
  double _segmentWidth = 0;

  @override
  void initState() {
    super.initState();
    _controller = ScrollController();
    _anim = AnimationController(vsync: this, duration: const Duration(seconds: 1));
    _anim.addListener(_onTick);
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  void _onTick() {
    if (!_controller.hasClients || _segmentWidth <= 0) return;
    final next = _controller.offset + widget.speed / 60;
    if (next >= _segmentWidth) {
      _controller.jumpTo(next - _segmentWidth);
    } else {
      _controller.jumpTo(next);
    }
  }

  void _start() {
    if (!mounted || widget.items.isEmpty) return;
    _anim.repeat();
  }

  @override
  void dispose() {
    _anim.removeListener(_onTick);
    _anim.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return SizedBox(height: widget.height);

    final style = widget.textStyle ??
        TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Colors.white.withValues(alpha: .88),
        );
    final separator = Text('  ·  ', style: style.copyWith(color: style.color?.withValues(alpha: .5)));

    Widget buildSegment() => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < widget.items.length; i++) ...[
              if (i > 0) separator,
              Text(widget.items[i], style: style),
            ],
          ],
        );

    return SizedBox(
      height: widget.height,
      child: ClipRect(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return NotificationListener<SizeChangedLayoutNotification>(
              onNotification: (_) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  final ctx = context;
                  // Measure one segment width via TextPainter
                  final painter = TextPainter(
                    text: TextSpan(
                      children: [
                        for (var i = 0; i < widget.items.length; i++) ...[
                          if (i > 0) TextSpan(text: '  ·  ', style: style.copyWith(color: style.color?.withValues(alpha: .5))),
                          TextSpan(text: widget.items[i], style: style),
                        ],
                      ],
                    ),
                    textDirection: Directionality.of(ctx),
                    maxLines: 1,
                  )..layout();
                  setState(() => _segmentWidth = painter.width + 32);
                });
                return false;
              },
              child: SizeChangedLayoutNotifier(
                child: ListView(
                  controller: _controller,
                  scrollDirection: Axis.horizontal,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    buildSegment(),
                    const SizedBox(width: 32),
                    buildSegment(),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class SegmentOption<T> {
  final T value;
  final String label;
  final IconData? icon;

  const SegmentOption({required this.value, required this.label, this.icon});
}

/// Sliding-pill segmented control with spring-like animation.
class AnimatedSegmentBar<T> extends StatelessWidget {
  final List<SegmentOption<T>> options;
  final T selected;
  final ValueChanged<T> onChanged;
  final double height;

  const AnimatedSegmentBar({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.height = 44,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final selectedIndex = options.indexWhere((o) => o.value == selected).clamp(0, options.length - 1);

    return Container(
      height: height,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: dark ? AppColors.surfaceDark : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: dark ? AppColors.borderDark : AppColors.borderLight),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tabWidth = constraints.maxWidth / options.length;
          final isRtl = Directionality.of(context) == TextDirection.rtl;
          final pillStart = isRtl ? tabWidth * (options.length - 1 - selectedIndex) : tabWidth * selectedIndex;
          return Stack(
            alignment: Alignment.center,
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOutCubic,
                left: pillStart,
                top: 0,
                bottom: 0,
                width: tabWidth,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: AppGradients.hero,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    boxShadow: AppShadows.subtle(AppColors.primary),
                  ),
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: options.map((opt) {
                  final isSelected = opt.value == selected;
                  return Expanded(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => onChanged(opt.value),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        child: Center(
                          child: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 220),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                              color: isSelected ? Colors.white : scheme.onSurface.withValues(alpha: .72),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (opt.icon != null) ...[
                                  Icon(
                                    opt.icon,
                                    size: 16,
                                    color: isSelected ? Colors.white : scheme.onSurface.withValues(alpha: .55),
                                  ),
                                  const SizedBox(width: 5),
                                ],
                                Flexible(
                                  child: Text(
                                    opt.label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Gradient hero banner with subtle floating orbs and entrance fade.
class HomeHeroBanner extends StatefulWidget {
  final String title;
  final List<String> typewriterPhrases;
  final List<String> marqueeItems;

  const HomeHeroBanner({
    super.key,
    required this.title,
    required this.typewriterPhrases,
    required this.marqueeItems,
  });

  @override
  State<HomeHeroBanner> createState() => _HomeHeroBannerState();
}

class _HomeHeroBannerState extends State<HomeHeroBanner> with SingleTickerProviderStateMixin {
  late final AnimationController _float;

  @override
  void initState() {
    super.initState();
    _float = AnimationController(vsync: this, duration: const Duration(milliseconds: 3200))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _float.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, (1 - t) * 16), child: child),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: DecoratedBox(
          decoration: const BoxDecoration(gradient: AppGradients.hero),
          child: Stack(
            children: [
              AnimatedBuilder(
                animation: _float,
                builder: (context, _) => Positioned(
                  top: -20 + _float.value * 12,
                  right: -10,
                  child: _orb(90, .14),
                ),
              ),
              AnimatedBuilder(
                animation: _float,
                builder: (context, _) => Positioned(
                  bottom: -24 + (1 - _float.value) * 10,
                  left: -16,
                  child: _orb(72, .10),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: .16),
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                          child: const Icon(Icons.directions_bus_filled_rounded, color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            widget.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                              height: 1.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    TypewriterRotatingText(
                      phrases: widget.typewriterPhrases,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .92),
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    if (widget.marqueeItems.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.sm),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: .12),
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                          child: InfiniteMarquee(items: widget.marqueeItems),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _orb(double size, double alpha) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: alpha),
        ),
      );
}
