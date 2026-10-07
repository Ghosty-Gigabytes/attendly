import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/controller.dart';
import '../domain/models.dart';
import '../domain/export.dart';
import 'shared.dart';
import 'background_settings.dart';

class SettingsScreen extends StatelessWidget {
  final AppController controller;
  const SettingsScreen(this.controller, {super.key});
  @override
  Widget build(BuildContext context) {
    final data = controller.data;
    return ListView(
      padding: EdgeInsets.all(24),
      children: [
        Heading(
          'Make it yours',
          'A calmer semester starts here.',
          'Manage your portal connection, timetable, and personal preferences.',
        ),
        Surface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.school_outlined, color: tone(context, green)),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'University account',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Tag('IMS CONNECTED'),
                ],
              ),
              SizedBox(height: 14),
              Text(
                data.account,
                style: TextStyle(color: tone(context, muted), height: 1.5),
              ),
              SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton.icon(
                    onPressed: controller.busy
                        ? null
                        : () => safely(context, controller.sync),
                    icon: Icon(Icons.sync, size: 18),
                    label: Text(
                      controller.busy ? 'Refreshing…' : 'Refresh records',
                    ),
                  ),
                  TextButton.icon(
                    onPressed: controller.busy
                        ? null
                        : () => safely(context, controller.logout),
                    icon: Icon(Icons.logout, size: 18),
                    label: Text('Sign out of IMS'),
                  ),
                ],
              ),
              SizedBox(height: 12),
              Text(
                'Credentials are used only for this login and are not saved. Session cookies stay in memory. Reconnect after restarting the app.',
                style: TextStyle(
                  color: tone(context, muted),
                  fontSize: 11,
                  height: 1.5,
                ),
              ),
              if (controller.error != null)
                Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text(
                    controller.error!,
                    style: TextStyle(color: tone(context, red), fontSize: 12),
                  ),
                ),
            ],
          ),
        ),
        SizedBox(height: 20),
        BackgroundSettings(),
        SizedBox(height: 20),
        Text('Appearance', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        SizedBox(height: 12),
        SegmentedButton<String>(
          showSelectedIcon: false,
          style: ButtonStyle(visualDensity: VisualDensity.compact, textStyle: WidgetStatePropertyAll(TextStyle(fontSize: 12))),
          segments: [
            ButtonSegment(value: 'dark', label: Text('Dark')),
            ButtonSegment(value: 'light', label: Text('Light')),
            ButtonSegment(value: 'system', label: Text('System default')),
          ],
          selected: {controller.themePreference},
          onSelectionChanged: (values) => safely(context, () => controller.setTheme(values.first)),
        ),
        SizedBox(height: 20),
        Surface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Your timetable',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Add timetable class',
                    onPressed: data.subjects.isEmpty
                        ? null
                        : () => addRule(context, controller),
                    icon: Icon(
                      Icons.add_circle_outline,
                      color: tone(context, green),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Text(
                'Effective dates preserve history when your schedule changes. Class weights must match the university’s counting policy.',
                style: TextStyle(
                  color: tone(context, muted),
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
              SizedBox(height: 14),
              if (data.timetable.isEmpty)
                Text(
                  'No timetable yet. Add your weekly classes to start planning.',
                  style: TextStyle(color: tone(context, muted)),
                ),
              for (final rule in data.timetable)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    '${data.subjectLabel(rule.subject)} · ${['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][rule.weekday - 1]}',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    '${TimeOfDay(hour: rule.hour, minute: rule.minute).format(context)} · ${rule.weight} counted\n${shortDate(rule.from)} – ${shortDate(rule.until)}',
                    style: TextStyle(fontSize: 11, color: tone(context, muted)),
                  ),
                  trailing: IconButton(
                    tooltip: 'Set final date for this timetable rule',
                    icon: Icon(Icons.event_busy_outlined, size: 20),
                    onPressed: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: rule.until,
                        firstDate: rule.from,
                        lastDate: DateTime(rule.from.year + 3),
                      );
                      if (date != null && context.mounted) {
                        await safely(
                          context,
                          () => controller.update(
                            data.copyWith(
                              timetable: data.timetable
                                  .map(
                                    (r) => r.id == rule.id
                                        ? TimetableRule(
                                            id: r.id,
                                            subject: r.subject,
                                            weekday: r.weekday,
                                            hour: r.hour,
                                            minute: r.minute,
                                            weight: r.weight,
                                            from: r.from,
                                            until: date,
                                          )
                                        : r,
                                  )
                                  .toList(),
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ),
            ],
          ),
        ),
        SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: exportCsv(data)));
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'CSV copied. Official and personal rows are labelled separately.',
                  ),
                ),
              );
            }
          },
          icon: Icon(Icons.file_copy_outlined, size: 18),
          label: Text('Copy attendance as CSV'),
        ),
      ],
    );
  }
}

Future<void> addRule(BuildContext context, AppController controller) async {
  String code = controller.data.subjects.first.code;
  int weekday = 1, weight = 1;
  TimeOfDay time = TimeOfDay(hour: 9, minute: 0);
  DateTime from = dayOnly(DateTime.now()),
      until = dayOnly(DateTime.now()).add(Duration(days: 90));
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, set) => AlertDialog(
        title: Text('Add a weekly class'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButton<String>(
                itemHeight: 64,
                isExpanded: true,
                value: code,
                items: [
                  for (final s in controller.data.subjects)
                    DropdownMenuItem(
                      value: s.code,
                      child: Text(
                        s.label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (v) => set(() => code = v!),
              ),
              DropdownButton<int>(
                isExpanded: true,
                value: weekday,
                items: [
                  for (var i = 1; i <= 7; i++)
                    DropdownMenuItem(
                      value: i,
                      child: Text(
                        [
                          'Monday',
                          'Tuesday',
                          'Wednesday',
                          'Thursday',
                          'Friday',
                          'Saturday',
                          'Sunday',
                        ][i - 1],
                      ),
                    ),
                ],
                onChanged: (v) => set(() => weekday = v!),
              ),
              TextButton(
                onPressed: () async {
                  final value = await showTimePicker(
                    context: context,
                    initialTime: time,
                  );
                  if (value != null) set(() => time = value);
                },
                child: Text('Starts at ${time.format(context)}'),
              ),
              TextButton(
                onPressed: () async {
                  final range = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(DateTime.now().year - 1),
                    lastDate: DateTime(DateTime.now().year + 2),
                    initialDateRange: DateTimeRange(start: from, end: until),
                  );
                  if (range != null) {
                    set(() {
                      from = range.start;
                      until = range.end;
                    });
                  }
                },
                child: Text('${shortDate(from)} → ${shortDate(until)}'),
              ),
              DropdownButton<int>(
                value: weight,
                isExpanded: true,
                items: [
                  for (var i = 1; i <= 4; i++)
                    DropdownMenuItem(
                      value: i,
                      child: Text(
                        'Counts as $i ${i == 1 ? 'class' : 'classes'}',
                      ),
                    ),
                ],
                onChanged: (v) => set(() => weight = v!),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Add class'),
          ),
        ],
      ),
    ),
  );
  if (ok == true && context.mounted) {
    await safely(
      context,
      () => controller.update(
        controller.data.copyWith(
          timetable: [
            ...controller.data.timetable,
            TimetableRule(
              id: 'rule-${DateTime.now().microsecondsSinceEpoch}',
              subject: code,
              weekday: weekday,
              hour: time.hour,
              minute: time.minute,
              weight: weight,
              from: from,
              until: until,
            ),
          ],
        ),
      ),
    );
  }
}
