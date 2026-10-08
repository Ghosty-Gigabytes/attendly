import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:attendly/ui/motion.dart';

void main() {
  testWidgets('tab transitions preserve edits and respect reduced motion', (tester) async {
    var tab = 0;
    var reduced = false;
    late StateSetter update;
    await tester.pumpWidget(MaterialApp(home: StatefulBuilder(builder: (context, setState) {
      update = setState;
      return MediaQuery(data: MediaQueryData(disableAnimations: reduced), child: Scaffold(
        body: SmoothTabStack(index: tab, children: const [TextField(), Text('Second')]),
      ));
    })));
    await tester.enterText(find.byType(TextField), 'Saved plan');
    update(() => tab = 1);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    final moving = tester.widgetList<FadeTransition>(find.descendant(
      of: find.byType(SmoothTabStack), matching: find.byType(FadeTransition),
    ));
    expect(moving.where((fade) => fade.opacity.value > 0 && fade.opacity.value < 1).length, 2);
    await tester.pumpAndSettle();
    expect(find.text('Second'), findsOneWidget);
    update(() { tab = 0; reduced = true; });
    await tester.pump();
    expect(find.text('Saved plan'), findsOneWidget);
    final fade = tester.widget<FadeTransition>(find.descendant(of: find.byType(SmoothTabStack), matching: find.byType(FadeTransition)).first);
    expect(fade.opacity.value, 1);
    expect(tester.takeException(), isNull);
  });
}
