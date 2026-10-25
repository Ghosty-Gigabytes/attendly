import 'package:flutter/material.dart';

Duration motionDuration(BuildContext context, int milliseconds) =>
    MediaQuery.disableAnimationsOf(context)
    ? Duration.zero
    : Duration(milliseconds: milliseconds);

/// Keeps tab state and scroll positions while animating each newly selected page.
class SmoothTabStack extends StatefulWidget {
  final int index;
  final List<Widget> children;
  const SmoothTabStack({
    super.key,
    required this.index,
    required this.children,
  });
  @override
  State<SmoothTabStack> createState() => _SmoothTabStackState();
}

class _SmoothTabStackState extends State<SmoothTabStack>
    with SingleTickerProviderStateMixin {
  int? _previous;
  double _direction = 1;
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
    value: 1,
  );
  @override
  void didUpdateWidget(SmoothTabStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index) {
      _previous = oldWidget.index;
      _direction = widget.index > oldWidget.index ? 1 : -1;
      if (MediaQuery.disableAnimationsOf(context)) {
        _controller.value = 1;
      } else {
        _controller.forward(from: 0);
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) _controller.value = 1;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) {
      final t = Curves.easeInOutCubic.transform(_controller.value);
      return ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            for (var i = 0; i < widget.children.length; i++)
              Offstage(
                offstage:
                    i != widget.index &&
                    (i != _previous || _controller.isCompleted),
                child: IgnorePointer(
                  ignoring: i != widget.index,
                  child: ExcludeSemantics(
                    excluding: i != widget.index,
                    child: TickerMode(
                      enabled: i == widget.index,
                      child: FadeTransition(
                        opacity: AlwaysStoppedAnimation(
                          i == widget.index ? t : 1 - t,
                        ),
                        child: FractionalTranslation(
                          translation: Offset(
                            i == widget.index
                                ? (1 - t) * .08 * _direction
                                : -t * .08 * _direction,
                            0,
                          ),
                          child: widget.children[i],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
}

class SmoothAttendanceBar extends StatelessWidget {
  final double value, minHeight;
  final Color color, backgroundColor;
  const SmoothAttendanceBar({
    super.key,
    required this.value,
    required this.color,
    required this.backgroundColor,
    this.minHeight = 7,
  });
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween<double>(begin: value, end: value),
    duration: motionDuration(context, 360),
    curve: Curves.easeOutCubic,
    builder: (context, displayed, _) => LinearProgressIndicator(
      value: displayed,
      minHeight: minHeight,
      color: color,
      backgroundColor: backgroundColor,
    ),
  );
}
