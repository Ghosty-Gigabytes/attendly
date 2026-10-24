import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../data/controller.dart';
import '../data/portal_parser.dart';
import '../domain/student_id.dart';
import '../domain/display_dates.dart';
import 'id_card_face.dart';

class IdCardScreen extends StatefulWidget {
  final AppController controller;
  const IdCardScreen({super.key, required this.controller});
  @override
  State<IdCardScreen> createState() => _IdCardScreenState();
}

class _IdCardScreenState extends State<IdCardScreen>
    with SingleTickerProviderStateMixin {
  StudentIdData? _student;
  String? _error;
  bool _loading = false, _back = false, _motion = true;
  bool _portraitCard = true;
  double _x = 0, _y = 0;
  double _targetX = 0, _targetY = 0, _softX = 0, _softY = 0;
  Duration? _lastFrame;
  double _restX = 0, _restY = 0;
  int _restSamples = 0;
  late final Ticker _tiltTicker = createTicker(_advanceTilt);

  void _rotateCard() {
    _tiltTicker.stop();
    setState(() {
      _portraitCard = !_portraitCard;
      _restSamples = 0;
      _restX = _restY = 0;
      _x = _y = _softX = _softY = _targetX = _targetY = 0;
      _lastFrame = null;
    });
  }
  void _toggleMotion() {
    _tiltTicker.stop();
    setState(() {
      _motion = !_motion;
      _restSamples = 0;       // restart the ~320 ms calibration window
      _restX = _restY = 0;
      _x = _y = _softX = _softY = _targetX = _targetY = 0;
      _lastFrame = null;
    });
  }

  void _advanceTilt(Duration elapsed) {
    final dt = _lastFrame == null
        ? 1 / 60
        : ((elapsed - _lastFrame!).inMicroseconds / 1000000).clamp(0.0, .05);
    _lastFrame = elapsed;
    // Two damped stages soften acceleration and settling without increasing tilt.
    final input = 1 - math.exp(-dt / .10);
    final settle = 1 - math.exp(-dt / .16);
    setState(() {
      _softX += (_targetX - _softX) * input;
      _softY += (_targetY - _softY) * input;
      _x += (_softX - _x) * settle;
      _y += (_softY - _y) * settle;
    });
    if ((_targetX - _x).abs() +
            (_targetY - _y).abs() +
            (_targetX - _softX).abs() +
            (_targetY - _softY).abs() <
        .0001) {
      _tiltTicker.stop();
      _lastFrame = null;
    }
  }

  StreamSubscription<AccelerometerEvent>? _sensor;
  @override
  void initState() {
    super.initState();
    unawaited(
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]),
    );
    unawaited(_load());
    _sensor =
        accelerometerEventStream(
          samplingPeriod: const Duration(milliseconds: 40),
        ).listen((event) {
          if (!mounted || !_motion || MediaQuery.disableAnimationsOf(context)) {
            return;
          }
          // Average the opening samples (~320 ms) so a single sensor spike
          // does not define the resting angle. Keep the card neutral meanwhile.
          if (_restSamples < 8) {
            _restSamples++;
            _restX += (event.x - _restX) / _restSamples;
            _restY += (event.y - _restY) / _restSamples;
            return;
          }
          _targetX = ((event.y - _restY) / 9.81 * .28).clamp(-.45, .45);
          _targetY = (-(event.x - _restX) / 9.81 * .28).clamp(-.45, .45);
          if (!_tiltTicker.isActive) {
            _lastFrame = null;
            _tiltTicker.start();
          }
        }, onError: (_) {});
  }

  Future<void> _load() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final saved = await widget.controller.cachedIdCard();
      if (!mounted) return;
      if (saved != null) setState(() => _student = saved);
      final fresh = await widget.controller.fetchIdCard();
      if (mounted) setState(() => _student = fresh);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is PortalException
              ? error.message
              : 'Could not load your ID card. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    unawaited(SystemChrome.setPreferredOrientations([]));
    _tiltTicker.dispose();
    _sensor?.cancel();
    super.dispose();
  }

  Widget _cardSurface(StudentIdData card) {
    final moving = _motion && !MediaQuery.disableAnimationsOf(context);
    // Map portrait phone axes into the card's quarter-turned coordinates.
    final tiltX = moving ? (_portraitCard ? -_y : _x) : 0.0;
    final tiltY = moving ? (_portraitCard ? _x : _y) : 0.0;
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..setEntry(3, 2, .0015)
        ..rotateX(tiltX)
        ..rotateY(tiltY),
      child: Semantics(
        button: true,
        label: _back
            ? 'Back of ID card. Tap to show front.'
            : 'Front of ID card. Tap to show back.',
        child: GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _back = !_back);
          },
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: _back ? math.pi : 0),
            duration: Duration(
              milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 760,
            ),
            curve: Curves.easeInOutCubic,
            builder: (context, angle, _) {
              final back = angle > math.pi / 2;
              return Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, .002)
                  ..rotateY(angle),
                child: Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.rotationY(back ? math.pi : 0),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: .3),
                          blurRadius: 24,
                          offset: Offset(8 * math.sin(angle), 10),
                        ),
                      ],
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        IdCardFace(student: card, back: back),

                        if (moving)
                          IgnorePointer(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: DecoratedBox(
                                key: const ValueKey('motion-metal-highlight'),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment(-1.6 + tiltY * 5, -1 + tiltX * 3),
                                    end: Alignment(1.2 + tiltY * 5, 1 + tiltX * 3),
                                    colors: [
                                      const Color(0xFF718096).withValues(alpha: .07),
                                      Colors.white.withValues(alpha: .0),
                                      Colors.white.withValues(alpha: .32),
                                      const Color(0xFFE2E9EF).withValues(alpha: .12),
                                      Colors.transparent,
                                    ],
                                    stops: const [0, .34, .48, .56, 1],
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final card =
            widget.controller.authenticated &&
                _student?.rollNumber.toUpperCase() ==
                    widget.controller.data.account.toUpperCase()
            ? _student
            : null;
        return Scaffold(
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) => Stack(
                children: [
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 60, 20, 12),
                      child: Center(
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (card == null) ...[
                                if (_loading)
                                  const CircularProgressIndicator()
                                else
                                  const Icon(Icons.badge_outlined, size: 48),
                                const SizedBox(height: 16),
                                Text(
                                  _loading
                                      ? 'Loading your ID card from IMS…'
                                      : _error ?? 'No saved ID card yet.',
                                  textAlign: TextAlign.center,
                                ),
                                if (!_loading)
                                  TextButton(
                                    onPressed: _load,
                                    child: const Text('Try again'),
                                  ),
                              ] else ...[
                                SizedBox(
                                  width: math.min(
                                    constraints.maxWidth - 40,
                                    math.max(
                                      120,
                                      (constraints.maxHeight - 220) *
                                          (_portraitCard
                                              ? 504 / 800
                                              : 800 / 504),
                                    ),
                                  ),
                                  child: AspectRatio(
                                    aspectRatio: _portraitCard
                                        ? 504 / 800
                                        : 800 / 504,
                                    child: RotatedBox(
                                      key: const ValueKey('rotated-id-card'),
                                      quarterTurns: _portraitCard ? 1 : 0,
                                      child: _cardSurface(card),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    TextButton.icon(
                                      onPressed: () =>
                                          setState(() => _back = !_back),
                                      icon: const Icon(Icons.flip),
                                      label: Text(
                                        _back ? 'Show front' : 'Show back',
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: _portraitCard
                                          ? 'Show landscape card'
                                          : 'Show portrait card',
                                      onPressed: _rotateCard,
                                      icon: Icon(
                                        _portraitCard
                                            ? Icons.crop_landscape_rounded
                                            : Icons.crop_portrait_rounded,
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: _motion
                                          ? 'Disable 3D motion'
                                          : 'Enable 3D motion',
                                      onPressed: _toggleMotion,
                                      icon: Icon(
                                        _motion
                                            ? Icons.view_in_ar_rounded
                                            : Icons.motion_photos_off_outlined,
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  _loading
                                      ? 'Refreshing from IMS…'
                                      : 'Saved ${displayDateTime(card.fetchedAt, use24Hour: widget.controller.use24Hour)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                if (_error != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                      _error!,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: scheme.error,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                if (card.photo == null ||
                                    card.logo == null ||
                                    card.signature == null)
                                  const Padding(
                                    padding: EdgeInsets.only(top: 8),
                                    child: Text(
                                      'Some IMS images are unavailable. Refresh to try again.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: IconButton(
                      tooltip: 'Exit ID Card',
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: IconButton(
                      tooltip: 'Refresh ID card',
                      onPressed: _loading ? null : _load,
                      icon: const Icon(Icons.refresh),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
