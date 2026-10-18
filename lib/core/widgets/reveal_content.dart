import 'package:flutter/material.dart';

/// Reveals content once without timers or perpetual animations.
class RevealContent extends StatelessWidget {
  const RevealContent({super.key, required this.child, this.order = 0});
  final Widget child;
  final int order;
  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 420 + order * 80),
      curve: Curves.easeOutCubic,
      child: child,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 14 * (1 - value)),
          child: child,
        ),
      ),
    );
  }
}
