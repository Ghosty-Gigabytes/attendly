import 'package:flutter/material.dart';
import '../data/controller.dart';
import '../domain/timetable.dart';
import '../domain/display_dates.dart';
import 'timetable_editor.dart';

class TimetableScreen extends StatefulWidget {
  final AppController controller;
  const TimetableScreen(this.controller, {super.key});
  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen> {
  late DateTime monday = weekStart(DateTime.now());
  final horizontal = ScrollController();
  bool compact = false;
  DateTime weekStart(DateTime day) =>
      DateTime(day.year, day.month, day.day - day.weekday + 1);
  @override
  void dispose() {
    horizontal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.controller.data;
    final rows = <TimetableEntry>[];
    for (final rule in data.timetable) {
      if (rule.weekday < 1 || rule.weekday > 5) continue;
      final date = DateTime(
        monday.year,
        monday.month,
        monday.day + rule.weekday - 1,
      );
      if (rule.on(date) != null) rows.add(TimetableEntry.fromRule(rule));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Timetable',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              IconButton(
                tooltip: compact ? 'Larger columns' : 'Compact week',
                icon: Icon(compact ? Icons.zoom_in : Icons.zoom_out),
                onPressed: () => setState(() => compact = !compact),
              ),
              FilledButton.tonalIcon(
                onPressed: () => openTimetable(context, widget.controller),
                icon: const Icon(Icons.edit_calendar_outlined),
                label: const Text('Edit'),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Previous week',
                onPressed: () => setState(
                  () => monday = DateTime(
                    monday.year,
                    monday.month,
                    monday.day - 7,
                  ),
                ),
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Text(
                  '${displayDate(monday)} – ${displayDate(DateTime(monday.year, monday.month, monday.day + 4))}',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ),
              IconButton(
                tooltip: 'Next week',
                onPressed: () => setState(
                  () => monday = DateTime(
                    monday.year,
                    monday.month,
                    monday.day + 7,
                  ),
                ),
                icon: const Icon(Icons.chevron_right),
              ),
              TextButton(
                onPressed: () =>
                    setState(() => monday = weekStart(DateTime.now())),
                child: const Text('Today'),
              ),
            ],
          ),
        ),
        if (rows.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Text(
              data.timetable.isEmpty
                  ? 'Set up your weekly classes with Edit. Import an AI response or add classes yourself.'
                  : 'No Monday–Friday classes are scheduled for this week.',
            ),
          ),
        Expanded(
          child: WeeklyTimetableGrid(
            entries: rows,
            subjects: data.subjects,
            issues: timetableIssues(rows, data.subjects),
            compact: compact,
            horizontal: horizontal,
            editable: false,
            onAdd: (_, _) {},
            onEdit: (entry) => showModalBottomSheet<void>(
              context: context,
              showDragHandle: true,
              useSafeArea: true,
              builder: (context) => SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data.subjectLabel(entry.subject),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '${entry.day} · ${displayClock(entry.startMinutes!, use24Hour: MediaQuery.of(context).alwaysUse24HourFormat)} – ${displayClock(entry.endMinutes!, use24Hour: MediaQuery.of(context).alwaysUse24HourFormat)}',
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${entry.kind} · ${entry.group == 'all' ? 'All groups' : entry.group} · ${entry.count} attendance ${entry.count == '1' ? 'class' : 'classes'}',
                      ),
                      if (entry.sourceLabel.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text('Timetable label: ${entry.sourceLabel}'),
                        ),
                      const SizedBox(height: 16),
                      const Text(
                        'Scheduled classes are for planning. They do not mark actual attendance.',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
