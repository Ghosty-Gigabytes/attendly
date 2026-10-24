import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:attendly/data/platform_service.dart';
import 'package:attendly/domain/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'widget snapshot keeps saved schedule details and no student identifiers',
    () {
      final data = AppData(
        account: 'private-student',
        subjects: const [Subject('CS101', 'Computer Science', Counts(3, 4), 0)],
        timetable: [
          TimetableRule(
            id: 'lab',
            subject: 'CS101',
            weekday: 2,
            hour: 14,
            minute: 30,
            endMinuteOfDay: 990,
            kind: 'lab',
            group: 'G2',
            weight: 1,
            from: DateTime(2026, 10, 1),
            until: DateTime(2026, 12, 31),
          ),
        ],
      );
      final encoded =
          PlatformService.publication(data, use24Hour: false)['widget']
              as String;
      final widget = jsonDecode(encoded) as Map;
      final row = (widget['timetable'] as List).single as Map;
      expect(row['name'], 'Computer Science');
      expect(row['subject'], 'CS101');
      expect(row['from'], '2026-10-01');
      expect(row['until'], '2026-12-31');
      expect(row['endMinuteOfDay'], 990);
      expect(row['group'], 'G2');
      expect(widget['use24Hour'], false);
      expect(encoded, isNot(contains('private-student')));
      final empty = jsonDecode(
        PlatformService.publication(const AppData())['widget'] as String,
      );
      expect(empty['timetable'], isEmpty);
    },
  );
  test('pin action distinguishes timetable and attendance widgets', () async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(PlatformService.channel, (call) async {
          calls.add(call);
          return true;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(PlatformService.channel, null),
    );
    final service = PlatformService();
    expect(await service.pinWidget(timetable: true), true);
    expect(await service.pinWidget(), true);
    expect(calls.map((c) => c.arguments['timetable']), [true, false]);
  });
}
