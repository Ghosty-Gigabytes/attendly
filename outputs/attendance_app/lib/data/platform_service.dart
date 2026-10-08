import '../domain/display_dates.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import '../domain/models.dart';
import '../domain/widget_days.dart';

class PlatformService {
  static const channel = MethodChannel('dev.attendly/platform');
  Future<Map<String, dynamic>> settings([Map<String, bool>? values]) async =>
      Map<String, dynamic>.from(
        await channel.invokeMapMethod('settings', values) ?? {},
      );
  Future<Map<String, dynamic>> appInfo() async {
    try {
      return Map<String, dynamic>.from(
        await channel.invokeMapMethod('appInfo') ?? {},
      );
    } on MissingPluginException {
      return {};
    } on PlatformException {
      return {};
    }
  }

  Future<void> deleteLocalData() async {
    if (Platform.isAndroid) await channel.invokeMethod('deleteLocalData');
  }

  Future<void> requestNotifications() =>
      const MethodChannel('dev.attendly/permission').invokeMethod('request');
  Future<bool> pinWidget() async =>
      await channel.invokeMethod<bool>('pinWidget') ?? false;
  Future<void> clear() async {
    if (!Platform.isAndroid) return;
    try {
      await channel.invokeMethod('clear');
    } on MissingPluginException {
      /* Tests/non-Android. */
    }
  }

  Future<void> status(String message) async {
    await channel.invokeMethod('status', {'message': message});
  }

  Future<void> publish(AppData data, {AppData? previous}) async {
    if (!Platform.isAndroid) return;
    try {
      await channel.invokeMethod(
        'publish',
        publication(data, previous: previous),
      );
    } on MissingPluginException {
      /* Tests/non-Android. */
    } on PlatformException {
      /* Sync remains usable if notifications/widgets are unavailable. */
    }
  }

  static String officialSignature(AppData data, String code) {
    final counts = data.subjects
        .where((s) => s.code == code)
        .firstOrNull
        ?.official;
    final rows =
        data.officialDays
            .where((d) => d.subject == code && d.raw.trim().isNotEmpty)
            .map((d) => '${d.date}:${d.raw.trim()}')
            .toList()
          ..sort();
    return jsonEncode([counts?.attended, counts?.held, rows]);
  }

  static Map<String, dynamic> publication(AppData data, {AppData? previous}) {
    final low =
        data.subjects
            .where((s) => s.official.held > 0 && !s.official.eligible())
            .toList()
          ..sort((a, b) => a.code.compareTo(b.code));
    final alerts = <Map<String, String>>[];
    void add(String type, String title, String body, String fingerprint) =>
        alerts.add({
          'type': type,
          'title': title,
          'body': body,
          'fingerprint': '${data.account}:${data.semester}:$fingerprint',
        });
    if (low.isNotEmpty) {
      final body = low
          .map(
            (s) =>
                '${s.label}: ${s.official.percent!.toStringAsFixed(1)}% (${s.official.attended}/${s.official.held})',
          )
          .join(', ');
      add('low', 'Attendance below 75%', body, body);
    }
    if (previous != null &&
        previous.account == data.account &&
        previous.semester == data.semester &&
        previous.synced != null) {
      final changed =
          data.subjects
              .where(
                (s) =>
                    officialSignature(data, s.code) !=
                    officialSignature(previous, s.code),
              )
              .map((s) => s.code)
              .toList()
            ..sort();
      if (changed.isNotEmpty) {
        add(
          'updates',
          'IMS attendance updated',
          'New or revised records: ${changed.map(data.subjectLabel).join(', ')}',
          changed.map((c) => officialSignature(data, c)).join('|'),
        );
      }
    }
    final differences = data.discrepancies;
    if (differences.isNotEmpty) {
      final signature = differences.map((d) => d.summary).join('\n');
      add(
        'discrepancies',
        'Your logs and IMS differ',
        '${differences.length} attendance differences to check. Open the calendar to compare your logs with IMS.',
        signature,
      );
    }
    final sorted = [...data.subjects]
      ..sort(
        (a, b) =>
            (a.official.percent ?? 101).compareTo(b.official.percent ?? 101),
      );
    final lines = sorted
        .take(6)
        .map(
          (s) =>
              '${s.label}  ${s.official.percent?.toStringAsFixed(1) ?? '—'}%  ${s.official.attended}/${s.official.held}',
        )
        .toList();
    if (sorted.length > 6) lines.add('+${sorted.length - 6} more in app');
    return {
      'widget': jsonEncode({
        'subjects': sorted
            .map(
              (s) => {
                'code': s.code,
                'name': s.name,
                'attended': s.official.attended,
                'held': s.official.held,
                'dayAdvice': widgetDayAdvice(data, s),
              },
            )
            .toList(),
        'lowCount': low.length,
        'rows': lines.isEmpty
            ? 'Open Attendly to fetch attendance'
            : lines.join('\n'),
        'updated': data.synced == null
            ? 'Not refreshed yet'
            : 'Fetched ${displayDateTime(data.synced!)} · Tap to open',
      }),
      'alerts': alerts,
      'clear': [
        'auth',
        if (low.isEmpty) 'low',
        if (differences.isEmpty) 'discrepancies',
      ],
    };
  }
}
