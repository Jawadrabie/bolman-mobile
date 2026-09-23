import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

class AnimatedListItem extends StatelessWidget {
  final int index;
  final Widget child;
  final Duration duration;

  const AnimatedListItem({
    super.key,
    required this.index,
    required this.child,
    this.duration = const Duration(milliseconds: 320),
  });

  @override
  Widget build(BuildContext context) => AnimationConfiguration.staggeredList(
        position: index,
        duration: duration,
        child: SlideAnimation(
          verticalOffset: 20,
          child: FadeInAnimation(child: child),
        ),
      );
}
