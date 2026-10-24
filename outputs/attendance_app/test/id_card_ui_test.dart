import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:attendly/data/controller.dart';
import 'package:attendly/data/database.dart';
import 'package:attendly/data/portal_service.dart';
import 'package:attendly/data/portal_parser.dart';
import 'package:attendly/domain/student_id.dart';
import 'package:attendly/domain/models.dart';
import 'package:attendly/ui/id_card.dart';
import 'package:attendly/ui/id_card_face.dart';
import 'id_card_test.dart' show fixtureCard;

class OfflineCardController extends AppController {
  OfflineCardController()
    : super(AttendanceDatabase.memory(), PortalService()) {
    authenticated = true;
    data = const AppData(account: '2024TEST001');
  }
  @override
  Future<StudentIdData?> cachedIdCard() async => fixtureCard();
  @override
  Future<StudentIdData> fetchIdCard() async =>
      throw const PortalException('Offline: showing saved card.');
}

void main() {
  testWidgets(
    'front and back scale without overflow and omit unwanted fields',
    (tester) async {
      await (FontLoader('Roboto')
            ..addFont(rootBundle.load('assets/fonts/roboto-regular.ttf'))
            ..addFont(rootBundle.load('assets/fonts/roboto-bold.ttf')))
          .load();
      tester.view.physicalSize = const Size(800, 504);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final back in [false, true]) {
        final boundary = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            home: RepaintBoundary(
              key: boundary,
              child: IdCardFace(student: fixtureCard(), back: back),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(find.textContaining('REGISTRAR'), findsNothing);
        expect(find.textContaining('PARENT MOBILE'), findsNothing);
        if (back) {
          final instructions = tester.getRect(
            find.textContaining('1. The Holder'),
          );
          expect(instructions.bottom, lessThanOrEqualTo(404));
        } else {
          for (final label in [
            'NAME :',
            'COURSE :',
            'BATCH :',
            'PARENT NAME :',
            'ROLL NUMBER :',
            'BRANCH :',
            'MOBILE NO.:',
            'D.O.B :',
          ]) {
            expect(
              tester
                  .getRect(
                    find.textContaining(RegExp('^${RegExp.escape(label)}')),
                  )
                  .bottom,
              lessThan(395),
            );
          }
          expect(find.byType(ColorFiltered), findsOneWidget);
        }
        await tester.runAsync(() async {
          final image =
              await (boundary.currentContext!.findRenderObject()
                      as RenderRepaintBoundary)
                  .toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final dir = Directory('../../work/ui-checks/id-card')
            ..createSync(recursive: true);
          File(
            '${dir.path}/${back ? 'back' : 'front'}.png',
          ).writeAsBytesSync(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
    },
  );
  testWidgets('saved card opens offline, flips, and exits to prior screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final orientations = <dynamic>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'SystemChrome.setPreferredOrientations') {
          orientations.add(call.arguments);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final controller = OfflineCardController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => IdCardScreen(controller: controller),
                ),
              ),
              child: const Text('Open card'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open card'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.textContaining('Offline: showing saved card.'), findsOneWidget);
    expect(find.byType(IdCardFace), findsOneWidget);
    expect(orientations.first, ['DeviceOrientation.portraitUp']);
    expect(
      tester
          .widget<RotatedBox>(find.byKey(const ValueKey('rotated-id-card')))
          .quarterTurns,
      1,
    );
    await tester.tap(find.byTooltip('Show landscape card'));
    await tester.pump();
    expect(
      tester
          .widget<RotatedBox>(find.byKey(const ValueKey('rotated-id-card')))
          .quarterTurns,
      0,
    );
    await tester.tap(find.byTooltip('Show portrait card'));
    await tester.pump();
    expect(
      tester
          .widget<RotatedBox>(find.byKey(const ValueKey('rotated-id-card')))
          .quarterTurns,
      1,
    );
    final highlight = find.byKey(const ValueKey('motion-metal-highlight'));
    final initial = tester.widget<DecoratedBox>(highlight).decoration;
    await tester.pump(const Duration(seconds: 2));
    expect(tester.widget<DecoratedBox>(highlight).decoration, initial);
    await tester.tap(find.text('Show back'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('COMMUNICATION ADDRESS:'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Exit ID Card'));
    await tester.pumpAndSettle();
    expect(find.text('Open card'), findsOneWidget);
    expect(orientations.last, isEmpty);
  });
}
