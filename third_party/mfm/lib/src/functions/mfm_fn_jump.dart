import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mfm/src/extension/int_extension.dart';

class MfmFnJump extends StatefulWidget {
  final Widget child;

  final double speed;
  final double delay;

  const MfmFnJump({
    super.key,
    required this.child,
    required this.speed,
    required this.delay,
  });

  @override
  State<StatefulWidget> createState() => MfmFnJumpState();
}

class MfmFnJumpState extends State<MfmFnJump> with TickerProviderStateMixin {
  late AnimationController _controller;

  late Animation<double> _translateYAnimation;
  final _translateYSequence = TweenSequence([
    TweenSequenceItem(
        tween: Tween(begin: 0.0, end: -16.0), weight: 25), // 0% -> 25%
    TweenSequenceItem(
        tween: Tween(begin: -16.0, end: 0.0), weight: 25), // 25% -> 50%
    TweenSequenceItem(
        tween: Tween(begin: 0.0, end: -8.0), weight: 25), // 50% -> 75%
    TweenSequenceItem(
        tween: Tween(begin: -8.0, end: 0.0), weight: 25), // 75% -> 100%
  ]);

  Timer? _startTimer;

  void _startAnimation() {
    _startTimer?.cancel();
    if (widget.speed <= 0) return;
    _startTimer = Timer(
      Duration(milliseconds: (widget.delay * 1000).toInt()),
      () {
        if (mounted) _controller.repeat();
      },
    );
  }

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
        vsync: this,
        duration:
            Duration(milliseconds: (widget.speed * 1000).toInt().if0(999)));

    _startAnimation();

    _translateYAnimation = _controller.drive(_translateYSequence);
  }

  @override
  void didUpdateWidget(covariant MfmFnJump oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.speed == oldWidget.speed && widget.delay == oldWidget.delay) {
      return;
    }

    _controller.duration =
        Duration(milliseconds: (widget.speed * 1000).toInt().if0(999));
    _controller.reset();

    _startAnimation();
  }

  @override
  void dispose() {
    _startTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.speed <= 0) {
      return widget.child;
    }

    return AnimatedBuilder(
        animation: _controller,
        child: widget.child,
        builder: (context, child) {
          return Transform.translate(
              offset: Offset(0, _translateYAnimation.value),
              child: widget.child);
        });
  }
}
