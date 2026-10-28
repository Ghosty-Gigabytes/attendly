import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../data/controller.dart';
import '../data/api.dart';
import 'id_card_face.dart';
import 'shared.dart';

class IdCardScreen extends StatefulWidget {
  final AppController controller;
  const IdCardScreen({super.key, required this.controller});
  @override
  State<IdCardScreen> createState() => _IdCardScreenState();
}

class _IdCardScreenState extends State<IdCardScreen> {
  bool loading = true, back = false, portrait = true, motion = true;
  double x = 0, y = 0;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load({bool refresh = false}) async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      await widget.controller.loadIdCard(refresh: refresh);
    } catch (e) {
      if (mounted) {
        setState(() => error = e is StateError ? e.message : Api.message(e));
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.controller.idCard;
    final reduced = MediaQuery.disableAnimationsOf(context);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Close ID card',
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close),
        ),
        title: const Text('Your ID card'),
        actions: [
          IconButton(
            tooltip: 'Refresh ID card',
            onPressed: loading || widget.controller.limited
                ? null
                : () => load(refresh: true),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (loading) const LinearProgressIndicator(minHeight: 2),
            Expanded(
              child: card == null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(28),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.badge_outlined,
                              size: 56,
                              color: scheme.primary,
                            ),
                            const SizedBox(height: 20),
                            Text(
                              loading
                                  ? 'Getting your card from IMS…'
                                  : 'Your card is not saved yet',
                              style: Theme.of(context).textTheme.titleLarge,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              error ??
                                  'Your photo, signature and details come directly from IMS.',
                              textAlign: TextAlign.center,
                            ),
                            if (!loading)
                              Padding(
                                padding: const EdgeInsets.only(top: 20),
                                child: FilledButton.icon(
                                  onPressed: widget.controller.limited
                                      ? null
                                      : () => load(refresh: true),
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('Try again'),
                                ),
                              ),
                          ],
                        ),
                      ),
                    )
                  : LayoutBuilder(
                      builder: (context, bounds) => Center(
                        child: Padding(
                          padding: const EdgeInsets.all(22),
                          child: GestureDetector(
                            onDoubleTap: () => setState(() => back = !back),
                            onPanUpdate: !motion || reduced
                                ? null
                                : (details) => setState(() {
                                    y = (y + details.delta.dx / 500).clamp(
                                      -.20,
                                      .20,
                                    );
                                    x = (x - details.delta.dy / 500).clamp(
                                      -.20,
                                      .20,
                                    );
                                  }),
                            onPanEnd: (_) => setState(() {
                              x = 0;
                              y = 0;
                            }),
                            child: AnimatedContainer(
                              duration: reduced
                                  ? Duration.zero
                                  : const Duration(milliseconds: 180),
                              curve: Curves.easeOutCubic,
                              transformAlignment: Alignment.center,
                              transform: Matrix4.identity()
                                ..setEntry(3, 2, .001)
                                ..rotateX(x)
                                ..rotateY(y),
                              child: SizedBox(
                                width: portrait
                                    ? math.min(bounds.maxWidth - 44, 460)
                                    : math.min(bounds.maxWidth - 44, 850),
                                child: RotatedBox(
                                  quarterTurns: portrait ? 1 : 0,
                                  child: AspectRatio(
                                    aspectRatio: 800 / 504,
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        AnimatedSwitcher(
                                          duration: reduced
                                              ? Duration.zero
                                              : const Duration(
                                                  milliseconds: 240,
                                                ),
                                          child: IdCardFace(
                                            key: ValueKey(back),
                                            student: card,
                                            back: back,
                                          ),
                                        ),
                                        if (motion && !reduced)
                                          IgnorePointer(
                                            child: DecoratedBox(
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(22),
                                                gradient: LinearGradient(
                                                  begin: Alignment(
                                                    -1 + y * 5,
                                                    -1 + x * 5,
                                                  ),
                                                  end: Alignment(
                                                    1 + y * 5,
                                                    1 + x * 5,
                                                  ),
                                                  colors: [
                                                    Colors.white.withValues(
                                                      alpha:
                                                          (x.abs() + y.abs()) *
                                                          .35,
                                                    ),
                                                    Colors.transparent,
                                                    Colors.white.withValues(
                                                      alpha:
                                                          (x.abs() + y.abs()) *
                                                          .25,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
            if (card != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: Column(
                  children: [
                    if (error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Tooltip(
                          message: error!,
                          child: Text(
                            'Showing your saved card. Update unavailable.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: scheme.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(value: false, label: Text('Front')),
                        ButtonSegment(value: true, label: Text('Back')),
                      ],
                      selected: {back},
                      onSelectionChanged: (v) => setState(() => back = v.first),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 12,
                      children: [
                        TextButton.icon(
                          onPressed: () => setState(() {
                            portrait = !portrait;
                            x = y = 0;
                          }),
                          icon: const Icon(Icons.screen_rotation_alt),
                          label: Text(
                            portrait ? 'Landscape card' : 'Portrait card',
                          ),
                        ),
                        IconButton(
                          tooltip: motion
                              ? 'Turn off card motion'
                              : 'Turn on card motion',
                          onPressed: () => setState(() {
                            motion = !motion;
                            x = y = 0;
                          }),
                          icon: Icon(
                            motion ? Icons.view_in_ar : Icons.crop_free,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'Saved from IMS · ${longDate(card.fetchedAt)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
