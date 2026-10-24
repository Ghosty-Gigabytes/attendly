import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/controller.dart';
import '../domain/models.dart';
import '../domain/timetable.dart';
import '../domain/display_dates.dart';

Future<void> openTimetable(BuildContext context, AppController controller) =>
    Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => TimetableEditor(controller)),
    );

class TimetableEditor extends StatefulWidget {
  final AppController controller;
  const TimetableEditor(this.controller, {super.key});
  @override
  State<TimetableEditor> createState() => _TimetableEditorState();
}

class _TimetableEditorState extends State<TimetableEditor> {
  List<TimetableEntry> entries = [];
  DateTime from = dayOnly(DateTime.now());
  late DateTime until = from.add(const Duration(days: 90));
  bool loading = true, saving = false, compact = false;
  String? draftMessage;
  final horizontal = ScrollController();
  Future<void> pendingDraft = Future.value();
  List<Subject> get subjects => widget.controller.data.subjects;
  String newId() => 'weekly-${DateTime.now().microsecondsSinceEpoch}';

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    horizontal.dispose();
    super.dispose();
  }

  Future<void> load() async {
    final rules = widget.controller.data.timetable;
    final active = rules
        .where((r) => !r.from.isAfter(from) && !r.until.isBefore(from))
        .toList();
    entries = active.map(TimetableEntry.fromRule).toList();
    if (active.isNotEmpty) {
      until = active
          .map((r) => r.until)
          .reduce((a, b) => a.isBefore(b) ? a : b);
    }
    try {
      final saved = await widget.controller.db.preference(
        'timetableDraft:${widget.controller.scope}',
      );
      if (saved != null && saved.isNotEmpty) {
        final draft = jsonDecode(saved) as Map<String, dynamic>;
        final restored = (draft['entries'] as List)
            .map((e) => TimetableEntry.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        final a = DateTime.parse(draft['from']),
            b = DateTime.parse(draft['until']);
        if (b.isBefore(a)) throw const FormatException();
        entries = restored;
        from = a;
        until = b;
        draftMessage = 'Your unfinished draft has been restored.';
      }
    } catch (_) {
      draftMessage =
          'Could not restore the draft. Your saved timetable is unchanged.';
    }
    if (mounted) setState(() => loading = false);
  }

  void changed() {
    setState(() => draftMessage = 'Saving draft…');
    pendingDraft = widget.controller
        .saveTimetableDraft(
          jsonEncode({
            'from': dateKey(from),
            'until': dateKey(until),
            'entries': entries.map((e) => e.toJson()).toList(),
          }),
        )
        .then(
          (_) {
            if (mounted) {
              setState(
                () => draftMessage =
                    'Draft saved on this device. Apply it when ready.',
              );
            }
          },
          onError: (Object _) {
            if (mounted) {
              setState(
                () => draftMessage =
                    'Draft could not be saved. Keep this screen open and try again.',
              );
            }
          },
        );
  }

  Future<void> edit({
    TimetableEntry? entry,
    int day = 1,
    int start = 540,
  }) async {
    final value = await showModalBottomSheet<TimetableEntry>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _ClassSheet(
        subjects: subjects,
        existing: entry != null,
        initial:
            entry ??
            TimetableEntry(
              id: newId(),
              day: weekdays[day - 1],
              subject: '',
              start: clockText(start),
              end: clockText(math.min(start + 60, 1440)),
            ),
      ),
    );
    if (value == null || !mounted) return;
    setState(() {
      if (entry != null && value.id == entry.id) {
        entries.removeWhere((e) => e.id == entry.id);
      }
      if (value.subject != '__delete__') entries.add(value);
    });
    changed();
    if (value.subject == '__delete__' && entry != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Class removed from draft.'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () {
              if (!mounted) return;
              setState(() => entries.add(entry));
              changed();
            },
          ),
        ),
      );
    }
  }

  Future<void> importCsv() async {
    final imported = await showModalBottomSheet<(List<TimetableEntry>, bool)>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) =>
          _ImportSheet(subjects: subjects, hasEntries: entries.isNotEmpty),
    );
    if (imported == null || !mounted) return;
    setState(
      () => entries = imported.$2 ? [...entries, ...imported.$1] : imported.$1,
    );
    changed();
    final problems = timetableIssues(
      entries,
      subjects,
    ).values.where((v) => v.isNotEmpty).length;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${imported.$1.length} classes imported · $problems need attention',
        ),
      ),
    );
  }

  Future<void> copyPrompt() async {
    final section = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Convert a photo with AI'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '1. Copy the instructions below.\n2. Paste them into your preferred image-capable AI with your timetable photo.\n3. Return here and import its JSON.\n\nCrop student details out of the photo before sharing it. Check the result before saving.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: section,
                decoration: const InputDecoration(
                  labelText: 'Your section / lab batch',
                  hintText: 'For example: ECE A, batch 2',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.copy),
            label: const Text('Copy prompt'),
            onPressed: () async {
              await Clipboard.setData(
                ClipboardData(text: timetableAiPrompt(subjects, section.text)),
              );
              if (context.mounted) Navigator.pop(context);
            },
          ),
        ],
      ),
    );
    // Dialog transitions finish before its text controller is disposed.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    section.dispose();
  }

  Future<void> copyDay() async {
    int source = 1, destination = 2;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, set) => AlertDialog(
          title: const Text('Copy a day'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Adds copies to another day. Conflicts must be fixed before saving.',
              ),
              for (final first in [true, false])
                DropdownButtonFormField<int>(
                  initialValue: first ? source : destination,
                  decoration: InputDecoration(
                    labelText: first ? 'Copy from' : 'Copy to',
                  ),
                  items: [
                    for (var i = 1; i <= weekdays.length; i++)
                      DropdownMenuItem(value: i, child: Text(weekdays[i - 1])),
                  ],
                  onChanged: (v) => set(() {
                    if (first) {
                      source = v!;
                    } else {
                      destination = v!;
                    }
                  }),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: source == destination
                  ? null
                  : () => Navigator.pop(context, true),
              child: const Text('Copy'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    final prefix = newId();
    final copies = entries.where((e) => e.weekday == source).toList();
    setState(() {
      for (var i = 0; i < copies.length; i++) {
        entries.add(
          copies[i].copy(id: '$prefix-$i', day: weekdays[destination - 1]),
        );
      }
    });
    changed();
  }

  Future<void> discardDraft() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard timetable draft?'),
        content: const Text(
          'Your saved timetable stays unchanged. Unsaved imports and edits will be removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => saving = true);
    try {
      await pendingDraft;
      await widget.controller.saveTimetableDraft('');
      from = dayOnly(DateTime.now());
      until = from.add(const Duration(days: 90));
      draftMessage = null;
      await load();
    } catch (_) {
      if (mounted) {
        setState(
          () => draftMessage = 'Could not discard the draft. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> reviewIssues() async {
    final issues = timetableIssues(entries, subjects);
    final selected = await showModalBottomSheet<TimetableEntry>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (context) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Classes needing attention',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          for (final e in entries.where((e) => issues[e.id]!.isNotEmpty))
            ListTile(
              leading: Icon(
                Icons.warning_amber,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(
                '${e.subject.isEmpty ? (e.sourceLabel.isEmpty ? 'Unmatched subject' : e.sourceLabel) : e.subject} · ${e.day} ${e.startMinutes == null ? e.start : displayClock(e.startMinutes!, use24Hour: MediaQuery.of(context).alwaysUse24HourFormat)}',
              ),
              subtitle: Text(issues[e.id]!.toSet().join('\n')),
              trailing: const Icon(Icons.edit_outlined),
              onTap: () => Navigator.pop(context, e),
            ),
        ],
      ),
    );
    if (selected != null && mounted) await edit(entry: selected);
  }

  Future<void> save() async {
    if (timetableIssues(entries, subjects).values.any((v) => v.isNotEmpty)) {
      await reviewIssues();
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Apply weekly timetable?'),
        content: Text(
          '${entries.length} weekly sessions\n${displayDate(from)} – ${displayDate(until)}\n\nThis replaces the schedule within these dates. Earlier and later schedules stay unchanged.\n\nCheck that attendance counts match IMS, especially for labs. This does not mark any actual attendance.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Review again'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Apply timetable'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => saving = true);
    try {
      await pendingDraft;
      await widget.controller.mutate(
        (data) => data.copyWith(
          timetable: replaceTimetableWindow(
            data.timetable,
            entries,
            from,
            until,
          ),
        ),
      );
      await widget.controller.saveTimetableDraft('');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Timetable saved. You can now plan leave dates.'),
          ),
        );
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          saving = false;
          draftMessage =
              'Could not save. Your draft is still available; please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final issues = timetableIssues(entries, subjects);
    final problemCount = issues.values.where((v) => v.isNotEmpty).length;
    return PopScope(
      canPop: !saving,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Weekly timetable'),
          actions: [
            IconButton(
              tooltip: 'Discard draft',
              onPressed: saving ? null : discardDraft,
              icon: const Icon(Icons.restart_alt),
            ),
            IconButton(
              tooltip: compact ? 'Larger columns' : 'Compact week',
              icon: Icon(compact ? Icons.zoom_in : Icons.zoom_out),
              onPressed: () => setState(() => compact = !compact),
            ),
          ],
        ),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            FilledButton.tonalIcon(
                              onPressed: saving ? null : importCsv,
                              icon: const Icon(Icons.upload_file),
                              label: const Text('Import timetable'),
                            ),
                            OutlinedButton.icon(
                              onPressed: saving ? null : copyPrompt,
                              icon: const Icon(Icons.auto_awesome_outlined),
                              label: const Text('AI prompt'),
                            ),
                            IconButton(
                              tooltip: 'Copy day',
                              onPressed: saving ? null : copyDay,
                              icon: const Icon(Icons.copy_all),
                            ),
                          ],
                        ),
                        TextButton.icon(
                          icon: const Icon(Icons.date_range),
                          label: Text(
                            '${displayDate(from)} – ${displayDate(until)}',
                          ),
                          onPressed: saving
                              ? null
                              : () async {
                                  final dates = await showDateRangePicker(
                                    context: context,
                                    firstDate: DateTime(2000),
                                    lastDate: DateTime(2100),
                                    initialDateRange: DateTimeRange(
                                      start: from,
                                      end: until,
                                    ),
                                  );
                                  if (dates != null && mounted) {
                                    setState(() {
                                      from = dates.start;
                                      until = dates.end;
                                    });
                                    changed();
                                  }
                                },
                        ),
                        if (subjects.isEmpty)
                          const Text(
                            'Refresh attendance to load subjects before adding classes.',
                          ),
                        if (problemCount > 0)
                          TextButton.icon(
                            onPressed: reviewIssues,
                            icon: Icon(
                              Icons.warning_amber,
                              color: Theme.of(context).colorScheme.error,
                            ),
                            label: Text(
                              '$problemCount classes need attention · Review',
                            ),
                          )
                        else
                          Text(
                            entries.isEmpty
                                ? 'Tap a time slot to add your first class, or import JSON or CSV.'
                                : 'Tap a class to edit. Swipe sideways to see the rest of the week.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: WeeklyTimetableGrid(
                      entries: entries,
                      subjects: subjects,
                      issues: issues,
                      compact: compact,
                      horizontal: horizontal,
                      onEdit: saving ? (_) {} : (e) => edit(entry: e),
                      onAdd: saving
                          ? (_, _) {}
                          : (d, t) => edit(day: d, start: t),
                    ),
                  ),
                ],
              ),
        bottomNavigationBar: loading
            ? null
            : SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          draftMessage ??
                              'Changes stay in a draft until you apply them.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: saving || widget.controller.scope.isEmpty
                            ? null
                            : save,
                        icon: saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.check),
                        label: const Text('Save'),
                      ),
                    ],
                  ),
                ),
              ),
        floatingActionButton: loading
            ? null
            : FloatingActionButton.small(
                tooltip: 'Add class',
                onPressed: saving ? null : () => edit(),
                child: const Icon(Icons.add),
              ),
      ),
    );
  }
}

class WeeklyTimetableGrid extends StatelessWidget {
  final List<TimetableEntry> entries;
  final List<Subject> subjects;
  final Map<String, List<String>> issues;
  final bool compact;
  final bool editable;
  final ScrollController horizontal;
  final void Function(TimetableEntry) onEdit;
  final void Function(int, int) onAdd;
  const WeeklyTimetableGrid({
    super.key,
    required this.entries,
    required this.subjects,
    required this.issues,
    required this.compact,
    this.editable = true,
    required this.horizontal,
    required this.onEdit,
    required this.onAdd,
  });
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final positioned = entries
        .where(
          (e) =>
              e.weekday != null &&
              e.startMinutes != null &&
              e.endMinutes != null &&
              e.endMinutes! > e.startMinutes!,
        )
        .toList();
    final first = positioned.fold<int>(
      8,
      (v, e) => math.min(v, e.startMinutes! ~/ 60),
    );
    final last = positioned.fold<int>(
      18,
      (v, e) => math.max(v, (e.endMinutes! / 60).ceil()),
    );
    const hourHeight = 96.0, gutter = 72.0;
    final height = (last - first) * hourHeight;
    return LayoutBuilder(
      builder: (context, constraints) {
        final columnWidth = math.max(
          compact ? 100.0 : 156.0,
          (constraints.maxWidth - gutter) / weekdays.length,
        );
        return Scrollbar(
          controller: horizontal,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: horizontal,
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: gutter + weekdays.length * columnWidth,
              child: Column(
                children: [
                  Container(
                    height: 48,
                    color: scheme.surfaceContainerHigh,
                    child: Row(
                      children: [
                        const SizedBox(
                          width: gutter,
                          child: Center(child: Text('Time')),
                        ),
                        for (var day = 1; day <= weekdays.length; day++)
                          SizedBox(
                            width: columnWidth,
                            child: Center(
                              child: Text(
                                compact
                                    ? weekdays[day - 1].substring(0, 3)
                                    : weekdays[day - 1],
                                style: Theme.of(context).textTheme.labelLarge,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      child: SizedBox(
                        height: height + 24,
                        child: Stack(
                          children: [
                            for (var h = first; h < last; h++)
                              Positioned(
                                left: 0,
                                top: (h - first) * hourHeight,
                                width: gutter,
                                child: Padding(
                                  padding: const EdgeInsets.only(
                                    top: 4,
                                    left: 6,
                                  ),
                                  child: Text(
                                    displayClock(
                                      h * 60,
                                      use24Hour: MediaQuery.of(
                                        context,
                                      ).alwaysUse24HourFormat,
                                    ),
                                    style: Theme.of(
                                      context,
                                    ).textTheme.labelSmall,
                                  ),
                                ),
                              ),
                            for (var day = 1; day <= weekdays.length; day++)
                              for (var h = first; h < last; h++)
                                Positioned(
                                  left: gutter + (day - 1) * columnWidth,
                                  top: (h - first) * hourHeight,
                                  width: columnWidth,
                                  height: hourHeight,
                                  child: Semantics(
                                    label:
                                        'Add class on ${weekdays[day - 1]} at ${displayClock(h * 60, use24Hour: MediaQuery.of(context).alwaysUse24HourFormat)}',
                                    button: editable,
                                    child: Material(
                                      color: day > 5
                                          ? scheme.surfaceContainerLow
                                          : scheme.surface,
                                      child: InkWell(
                                        onTap: editable
                                            ? () => onAdd(day, h * 60)
                                            : null,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            border: Border(
                                              top: BorderSide(
                                                color: scheme.outlineVariant,
                                              ),
                                              left: BorderSide(
                                                color: scheme.outlineVariant
                                                    .withValues(alpha: .5),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            for (var day = 1; day <= weekdays.length; day++)
                              ..._blocks(
                                context,
                                positioned
                                    .where((e) => e.weekday == day)
                                    .toList(),
                                day,
                                first,
                                columnWidth,
                                hourHeight,
                                gutter,
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
        );
      },
    );
  }

  List<Widget> _blocks(
    BuildContext context,
    List<TimetableEntry> dayEntries,
    int day,
    int first,
    double width,
    double scale,
    double gutter,
  ) {
    dayEntries.sort((a, b) => a.startMinutes!.compareTo(b.startMinutes!));
    final lanes = <int>[];
    final assignment = <String, int>{};
    for (final e in dayEntries) {
      var lane = lanes.indexWhere((end) => end <= e.startMinutes!);
      if (lane < 0) {
        lane = lanes.length;
        lanes.add(0);
      }
      lanes[lane] = e.endMinutes!;
      assignment[e.id] = lane;
    }
    final scheme = Theme.of(context).colorScheme;
    final blockWidth = width / math.max(1, lanes.length);
    return [
      for (final e in dayEntries)
        (() {
          final name =
              subjects.where((s) => s.code == e.subject).firstOrNull?.name ??
              (e.sourceLabel.isNotEmpty
                  ? e.sourceLabel
                  : e.subject.isEmpty
                  ? 'Match subject'
                  : e.subject);
          final index = subjects.indexWhere((s) => s.code == e.subject);
          final colors = [
            scheme.primaryContainer,
            scheme.secondaryContainer,
            scheme.tertiaryContainer,
          ];
          final ink = [
            scheme.onPrimaryContainer,
            scheme.onSecondaryContainer,
            scheme.onTertiaryContainer,
          ];
          final problem = issues[e.id]?.isNotEmpty ?? false;
          final height = math.max(
            24.0,
            (e.endMinutes! - e.startMinutes!) / 60 * scale - 4,
          );
          final label =
              '$name, ${e.subject}, ${weekdays[day - 1]}, ${e.startMinutes == null ? e.start : displayClock(e.startMinutes!, use24Hour: MediaQuery.of(context).alwaysUse24HourFormat)} to ${e.endMinutes == null ? e.end : displayClock(e.endMinutes!, use24Hour: MediaQuery.of(context).alwaysUse24HourFormat)}, counts as ${e.count} classes${problem ? ', needs attention' : ''}';
          return Positioned(
            left:
                gutter + (day - 1) * width + assignment[e.id]! * blockWidth + 3,
            top: (e.startMinutes! / 60 - first) * scale + 2,
            width: blockWidth - 6,
            height: height,
            child: Semantics(
              label: label,
              button: true,
              excludeSemantics: true,
              child: Tooltip(
                message: label,
                child: Material(
                  color: problem
                      ? scheme.errorContainer
                      : colors[index.abs() % 3],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(
                      color: problem ? scheme.error : colors[index.abs() % 3],
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => onEdit(e),
                    child: Padding(
                      padding: const EdgeInsets.all(7),
                      child: DefaultTextStyle.merge(
                        style: TextStyle(
                          color: problem
                              ? scheme.onErrorContainer
                              : ink[index.abs() % 3],
                          fontSize: 12,
                        ),
                        child: LayoutBuilder(
                          builder: (context, c) => Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  name,
                                  maxLines: height < 65 ? 1 : 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              if (c.maxHeight >= 50)
                                Text(
                                  '${e.subject} · ${e.kind}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 10),
                                ),
                              if (c.maxHeight >= 36)
                                Text(
                                  '${e.startMinutes == null ? e.start : displayClock(e.startMinutes!, use24Hour: MediaQuery.of(context).alwaysUse24HourFormat)}–${e.endMinutes == null ? e.end : displayClock(e.endMinutes!, use24Hour: MediaQuery.of(context).alwaysUse24HourFormat)}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 10),
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
          );
        })(),
    ];
  }
}

class _ClassSheet extends StatefulWidget {
  final TimetableEntry initial;
  final List<Subject> subjects;
  final bool existing;
  const _ClassSheet({
    required this.initial,
    required this.subjects,
    required this.existing,
  });
  @override
  State<_ClassSheet> createState() => _ClassSheetState();
}

class _ClassSheetState extends State<_ClassSheet> {
  late String subject = widget.initial.subject;
  late int? day = widget.initial.weekday;
  late String kind = widget.initial.kind;
  late final group = TextEditingController(text: widget.initial.group);
  bool clockInitialized = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (clockInitialized) return;
    clockInitialized = true;
    for (final field in [start, end]) {
      final minutes = clockMinutes(field.text, end: true);
      if (minutes != null) {
        field.text = displayClock(
          minutes,
          use24Hour: MediaQuery.of(context).alwaysUse24HourFormat,
        );
      }
    }
  }

  late final start = TextEditingController(text: widget.initial.start),
      end = TextEditingController(text: widget.initial.end),
      count = TextEditingController(text: widget.initial.count);
  List<String> errors = [];
  @override
  void dispose() {
    start.dispose();
    end.dispose();
    count.dispose();
    group.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      0,
      20,
      MediaQuery.viewInsetsOf(context).bottom + 20,
    ),
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Class details', style: Theme.of(context).textTheme.titleLarge),
          if (widget.initial.sourceLabel.isNotEmpty)
            Text('From photo: ${widget.initial.sourceLabel}'),
          const SizedBox(height: 12),
          DropdownMenu<String>(
            label: const Text('Session type'),
            initialSelection: {'lecture', 'tutorial', 'lab'}.contains(kind)
                ? kind
                : null,
            dropdownMenuEntries: const [
              DropdownMenuEntry(value: 'lecture', label: 'Lecture'),
              DropdownMenuEntry(value: 'tutorial', label: 'Tutorial'),
              DropdownMenuEntry(value: 'lab', label: 'Lab'),
            ],
            onSelected: (value) {
              if (value != null) setState(() => kind = value);
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: group,
            decoration: const InputDecoration(
              labelText: 'Group',
              helperText: 'Your lab group, or all for a shared class',
            ),
          ),
          const SizedBox(height: 16),
          DropdownMenu<String>(
            expandedInsets: EdgeInsets.zero,
            enableFilter: true,
            requestFocusOnTap: true,
            label: const Text('Subject'),
            initialSelection: widget.subjects.any((s) => s.code == subject)
                ? subject
                : null,
            dropdownMenuEntries: [
              for (final s in widget.subjects)
                DropdownMenuEntry(
                  value: s.code,
                  label: '${s.name} · ${s.code}',
                ),
            ],
            onSelected: (v) {
              if (v != null) setState(() => subject = v);
            },
          ),
          if (subject.isNotEmpty &&
              !widget.subjects.any((s) => s.code == subject))
            Text('Imported subject: $subject. Choose its match above.'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            children: [
              for (var i = 1; i <= weekdays.length; i++)
                ChoiceChip(
                  label: Text(weekdays[i - 1].substring(0, 3)),
                  selected: day == i,
                  onSelected: (_) => setState(() => day = i),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final first in [true, false])
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: first ? 8 : 0),
                    child: TextField(
                      key: ValueKey(
                        first ? 'class-start-time' : 'class-end-time',
                      ),
                      controller: first ? start : end,
                      keyboardType: TextInputType.datetime,
                      decoration: InputDecoration(
                        labelText: first ? 'Start time' : 'End time',
                        suffixIcon: IconButton(
                          tooltip: 'Choose time',
                          icon: const Icon(Icons.schedule),
                          onPressed: () async {
                            final minutes =
                                parseDisplayClock((first ? start : end).text) ??
                                540;
                            final time = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay(
                                hour: (minutes ~/ 60) % 24,
                                minute: minutes % 60,
                              ),
                            );
                            if (time != null && context.mounted) {
                              (first ? start : end).text = displayClock(
                                time.hour * 60 + time.minute,
                                use24Hour: MediaQuery.of(
                                  context,
                                ).alwaysUse24HourFormat,
                              );
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: count,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Attendance count',
              helperText:
                  'How many classes IMS counts for this session.\nDuration does not determine this number.',
              helperMaxLines: 3,
            ),
          ),
          for (final error in errors)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                error,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (widget.existing)
                TextButton.icon(
                  onPressed: () => Navigator.pop(
                    context,
                    widget.initial.copy(subject: '__delete__'),
                  ),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Remove'),
                ),
              if (widget.existing)
                OutlinedButton(
                  onPressed: () => finish(duplicate: true),
                  child: const Text('Duplicate'),
                ),
              FilledButton(
                onPressed: finish,
                child: Text(widget.existing ? 'Done' : 'Add class'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
  void finish({bool duplicate = false}) {
    final next = widget.initial.copy(
      id: duplicate ? 'weekly-${DateTime.now().microsecondsSinceEpoch}' : null,
      day: day == null ? '' : weekdays[day! - 1],
      subject: subject,
      start: parseDisplayClock(start.text) != null
          ? clockText(parseDisplayClock(start.text)!)
          : start.text.trim(),
      end: parseDisplayClock(end.text) != null
          ? clockText(
              parseDisplayClock(end.text)! == 0
                  ? 1440
                  : parseDisplayClock(end.text)!,
            )
          : end.text.trim(),
      count: count.text.trim(),
      kind: kind,
      group: group.text.trim(),
    );
    final found = next.issues(widget.subjects);
    if (found.isNotEmpty) {
      setState(() => errors = found);
      return;
    }
    Navigator.pop(context, next);
  }
}

class _ImportSheet extends StatefulWidget {
  final List<Subject> subjects;
  final bool hasEntries;
  const _ImportSheet({required this.subjects, required this.hasEntries});
  @override
  State<_ImportSheet> createState() => _ImportSheetState();
}

class _ImportSheetState extends State<_ImportSheet> {
  final text = TextEditingController();
  bool append = false;
  String? error;
  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      0,
      20,
      MediaQuery.viewInsetsOf(context).bottom + 20,
    ),
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Import timetable',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text(
            'Paste the JSON or CSV response from your AI. Nothing changes in your active timetable until you review and save.',
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              TextButton.icon(
                icon: const Icon(Icons.paste),
                label: const Text('Paste'),
                onPressed: () async {
                  final value = await Clipboard.getData(Clipboard.kTextPlain);
                  if (mounted && value != null) text.text = value.text ?? '';
                },
              ),
              TextButton(
                onPressed: () async {
                  await Clipboard.setData(
                    const ClipboardData(text: timetableJsonTemplate),
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'JSON template copied. Fill in your class details.',
                        ),
                      ),
                    );
                  }
                },
                child: const Text('Copy template'),
              ),
            ],
          ),
          TextField(
            controller: text,
            minLines: 5,
            maxLines: 9,
            maxLength: 200000,
            decoration: const InputDecoration(
              labelText: 'JSON or CSV',
              counterText: '',
              hintText: timetableJsonTemplate,
              border: OutlineInputBorder(),
            ),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
          if (widget.hasEntries) ...[
            const SizedBox(height: 12),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Replace draft')),
                ButtonSegment(value: true, label: Text('Add to draft')),
              ],
              selected: {append},
              onSelectionChanged: (v) => setState(() => append = v.first),
            ),
          ],
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: 16),
          FilledButton.icon(
            icon: const Icon(Icons.calendar_view_week),
            label: const Text('Review in timetable'),
            onPressed: () {
              try {
                final rows = importTimetable(text.text, widget.subjects);
                Navigator.pop(context, (rows, append));
              } on FormatException catch (e) {
                setState(() => error = e.message);
              }
            },
          ),
        ],
      ),
    ),
  );
}
