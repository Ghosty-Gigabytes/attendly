import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// A determinate wave: it fills on load, then rests instead of looping forever.
class WavyAttendanceBar extends StatefulWidget {
  final double value;
  final Color color, trackColor;
  const WavyAttendanceBar({
    super.key,
    required this.value,
    required this.color,
    required this.trackColor,
  });
  @override
  State<WavyAttendanceBar> createState() => _WavyAttendanceBarState();
}

class _WavyAttendanceBarState extends State<WavyAttendanceBar>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );
  double _from = 0;
  ScrollPosition? _scrollPosition;
  bool _checkQueued = false;
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  void _queueVisibilityCheck() {
    if (_checkQueued || !mounted) return;
    _checkQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkQueued = false;
      if (mounted) _checkVisibility();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _checkVisibility() {
    final box = context.findRenderObject();
    var visible =
        _foreground &&
        TickerMode.valuesOf(context).enabled &&
        (ModalRoute.of(context)?.isCurrent ?? true);
    if (box is! RenderBox || !box.attached || !box.hasSize) return;
    final bounds = MatrixUtils.transformRect(
      box.getTransformTo(null),
      Offset.zero & box.size,
    );
    final viewport = RenderAbstractViewport.maybeOf(box);
    final clip = viewport == null
        ? Offset.zero & MediaQuery.sizeOf(context)
        : MatrixUtils.transformRect(
            viewport.getTransformTo(null),
            viewport.paintBounds,
          );
    final intersection = bounds.intersect(clip);
    visible =
        visible &&
        intersection.width > 0 &&
        intersection.height >= box.size.height * .5;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    } else if (visible && _controller.value < 1 && !_controller.isAnimating) {
      _controller.forward();
    } else if (!visible && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground) _controller.stop();
    _queueVisibilityCheck();
  }

  @override
  void didChangeMetrics() => _queueVisibilityCheck();
  double get _target =>
      widget.value.isFinite ? widget.value.clamp(0.0, 1.0) : 0;
  double get _displayed =>
      _from +
      (_target - _from) * Curves.easeOutCubic.transform(_controller.value);
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final position = Scrollable.maybeOf(context)?.position;
    if (position != _scrollPosition) {
      _scrollPosition?.removeListener(_queueVisibilityCheck);
      _scrollPosition = position;
      _scrollPosition?.addListener(_queueVisibilityCheck);
    }
    if (MediaQuery.disableAnimationsOf(context)) _controller.value = 1;
    _queueVisibilityCheck();
  }

  @override
  void didUpdateWidget(WavyAttendanceBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      final oldTarget = oldWidget.value.isFinite
          ? oldWidget.value.clamp(0.0, 1.0)
          : 0.0;
      _from +=
          (oldTarget - _from) *
          Curves.easeOutCubic.transform(_controller.value);
      if (MediaQuery.disableAnimationsOf(context)) {
        _controller.value = 1;
      } else {
        _controller.stop();
        _controller.value = 0;
        _queueVisibilityCheck();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollPosition?.removeListener(_queueVisibilityCheck);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _queueVisibilityCheck();
    return Semantics(
      label: 'Official attendance. Target 75 percent.',
      value: '${(_target * 100).toStringAsFixed(1)} percent',
      child: RepaintBoundary(
        child: SizedBox(
          height: 24,
          width: double.infinity,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => CustomPaint(
              painter: AttendanceWavePainter(
                value: _displayed,
                phase: _controller.value * math.pi * 4,
                color: widget.color,
                trackColor: widget.trackColor,
                rtl: Directionality.of(context) == TextDirection.rtl,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AttendanceWavePainter extends CustomPainter {
  final double value, phase;
  final Color color, trackColor;
  final bool rtl;
  const AttendanceWavePainter({
    required this.value,
    required this.phase,
    required this.color,
    required this.trackColor,
    this.rtl = false,
  });
  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 4) return;
    canvas.save();
    if (rtl) {
      canvas.translate(size.width, 0);
      canvas.scale(-1, 1);
    }
    const inset = 2.0, stroke = 4.0, amplitude = 3.0, wavelength = 24.0;
    final width = size.width - inset * 2, y = size.height / 2;
    final end = inset + width * value.clamp(0.0, 1.0);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    final trackStart = value <= 0 ? inset : end + 8;
    if (trackStart < size.width - inset) {
      canvas.drawLine(
        Offset(trackStart, y),
        Offset(size.width - inset, y),
        paint..color = trackColor,
      );
    }
    if (value > 0) {
      final path = Path();
      double wave(double x) =>
          y +
          amplitude * math.sin((x - inset) / wavelength * math.pi * 2 - phase);
      path.moveTo(inset, wave(inset));
      for (double x = inset + 1; x < end; x += 1) {
        path.lineTo(x, wave(x));
      }
      path.lineTo(end, wave(end));
      canvas.drawPath(path, paint..color = color);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(AttendanceWavePainter old) =>
      value != old.value ||
      phase != old.phase ||
      color != old.color ||
      trackColor != old.trackColor ||
      rtl != old.rtl;
}
