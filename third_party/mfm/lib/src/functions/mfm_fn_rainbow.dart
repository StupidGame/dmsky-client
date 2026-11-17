import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:mfm/src/extension/int_extension.dart';
import 'package:mfm/src/functions/mfm_fn_color_matrix.dart';

/// 本家 Misskey の `@keyframes mfm-rainbow` の定義。
///
/// ```css
/// @keyframes mfm-rainbow {
///   0%   { filter: hue-rotate(0deg)   contrast(150%) saturate(150%); }
///   100% { filter: hue-rotate(360deg) contrast(150%) saturate(150%); }
/// }
/// ```
///
/// hue-rotate は 0deg から 360deg まで linear に変化し、
/// contrast / saturate は常に 150% で固定されている。
const double _rainbowContrast = 1.5;
const double _rainbowSaturate = 1.5;

class MfmRainbow extends StatefulWidget {
  final Widget child;

  final double speed;
  final double delay;

  const MfmRainbow(
      {super.key,
      required this.child,
      required this.speed,
      required this.delay});

  @override
  State<StatefulWidget> createState() => MfmRainbowState();
}

class MfmRainbowState extends State<MfmRainbow> with TickerProviderStateMixin {
  late final AnimationController _controller;

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
  }

  @override
  void didUpdateWidget(covariant MfmRainbow oldWidget) {
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

  /// [progress] (0.0...1.0) の時点での `mfm-rainbow` のカラーマトリクスを返す。
  ///
  /// CSS の `filter` は左に書かれたものから順に適用されるため、
  /// hue-rotate → contrast → saturate の順に合成する。
  @visibleForTesting
  static List<double> colorMatrix(double progress) {
    return CssColorMatrix.compose([
      CssColorMatrix.hueRotate(progress * 2 * pi),
      CssColorMatrix.contrast(_rainbowContrast),
      CssColorMatrix.saturate(_rainbowSaturate),
    ]);
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
          return ColorFiltered(
              colorFilter: ColorFilter.matrix(colorMatrix(_controller.value)),
              child: child);
        });
  }
}
