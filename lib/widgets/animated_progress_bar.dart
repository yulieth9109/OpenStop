
import 'package:flutter/material.dart';

class AnimatedProgressBar extends ImplicitlyAnimatedWidget {
  final double value;

  final double minHeight;

  final Color? color;

  final Color? backgroundColor;

  const AnimatedProgressBar({
    Key? key,
    this.value = 0,
    this.minHeight = 1,
    this.color,
    this.backgroundColor,
    Duration duration = const Duration(milliseconds: 300),
    Curve curve = Curves.ease,
  }) : super(key: key, duration: duration, curve: curve);


  @override
  AnimatedWidgetBaseState<AnimatedProgressBar> createState() => _AnimatedProgressBarState();
}

class _AnimatedProgressBarState extends AnimatedWidgetBaseState<AnimatedProgressBar> {
  Tween<double>? _valueTween;

  @override
  void forEachTween(TweenVisitor<dynamic> visitor) {
    _valueTween = visitor(
      _valueTween,
      widget.value,
      (value) => Tween<double>(begin: value)
    ) as Tween<double>?;
  }


  @override
  Widget build(BuildContext context) {
    return LinearProgressIndicator(
      minHeight: widget.minHeight,
      color: widget.color,
      value: _valueTween?.evaluate(animation),
      backgroundColor: widget.backgroundColor
    );
  }
}
