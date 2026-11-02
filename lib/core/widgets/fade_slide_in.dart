import 'package:flutter/material.dart';

/// Entrance animation for one widget — the Flutter analogue of app.css's
/// `.page-enter` (rise-in keyframe). Fades in while sliding up slightly.
class FadeSlideIn extends StatelessWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 420),
  });

  final Widget child;
  final Duration delay;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: duration + delay,
      curve: Interval(
        delay.inMilliseconds / (duration + delay).inMilliseconds,
        1,
        curve: Curves.easeOutCubic,
      ),
      builder: (context, t, child) {
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * 14),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

/// Staggers [FadeSlideIn] across a list of children — the Flutter analogue
/// of app.css's `.stagger > *` rule (each child entrance delayed a little
/// more than the last).
class StaggeredFadeSlideIn extends StatelessWidget {
  const StaggeredFadeSlideIn({
    super.key,
    required this.children,
    this.step = const Duration(milliseconds: 60),
    this.crossAxisAlignment = CrossAxisAlignment.stretch,
    this.spacing = 0,
  });

  final List<Widget> children;
  final Duration step;
  final CrossAxisAlignment crossAxisAlignment;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: crossAxisAlignment,
      children: [
        for (final (index, child) in children.indexed) ...[
          if (index > 0) SizedBox(height: spacing),
          FadeSlideIn(delay: step * index, child: child),
        ],
      ],
    );
  }
}
