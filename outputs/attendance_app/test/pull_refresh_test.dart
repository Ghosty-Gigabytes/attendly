import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:attendly/data/controller.dart';
import 'package:attendly/data/database.dart';
import 'package:attendly/data/portal_service.dart';
import 'package:attendly/ui/dashboard.dart';

class RefreshController extends AppController {
  int refreshes = 0;
  RefreshController() : super(AttendanceDatabase.memory(), PortalService());
  @override
  Future<void> sync() async { refreshes++; }
}
void main() {
  testWidgets('pulling Overview invokes attendance refresh', (tester) async {
    final controller = RefreshController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Dashboard(controller, onPlan: () {}))));
    await tester.drag(find.byType(ListView).first, const Offset(0, 500));
    await tester.pumpAndSettle();
    expect(controller.refreshes, 1);
    expect(tester.takeException(), isNull);
  });
}
