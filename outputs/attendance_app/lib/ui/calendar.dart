import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/controller.dart';
import '../domain/models.dart';
import 'shared.dart';

class CalendarScreen extends StatefulWidget {
  final AppController controller;
  final String? initialSubject;
  const CalendarScreen(this.controller, {super.key, this.initialSubject});
  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime selected = dayOnly(DateTime.now());
  late DateTime month = DateTime(selected.year, selected.month);
  String? subject;
  @override
  void initState() {
    super.initState();
    subject = widget.initialSubject;
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.controller.data;
    if (subject != null && !data.subjects.any((s) => s.code == subject)) {
      subject = null;
    }
    final official = data.officialDays
        .where(
          (s) =>
              s.date == dateKey(selected) &&
              (subject == null || s.subject == subject),
        )
        .toList();
    final sessions = data
        .on(selected)
        .where((s) => subject == null || s.subject == subject)
        .toList();
    final selectedSubject = data.subjects
        .where((s) => s.code == subject)
        .firstOrNull;
    final offset = month.weekday - 1,
        total = DateTime(month.year, month.month + 1, 0).day;
    return ListView(
      padding: EdgeInsets.all(24),
      children: [
        Heading(
          'A day-by-day perspective',
          selectedSubject?.name ?? 'Your attendance, in detail.',
          'Official history and your own log, side by side when you need them.',
        ),
        if (selectedSubject != null)
          Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                Tag(
                  'Official ${percentage(selectedSubject.official)} · ${selectedSubject.official.attended}/${selectedSubject.official.held}',
                ),
                if (data.showPersonal)
                  Tag(
                    'With personal ${percentage(data.personal(selectedSubject.code))}',
                    color: Color(0xFF9662CD),
                  ),
              ],
            ),
          ),
        if (data.showPersonal)
          Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text(
              'Your logs count for days IMS has not updated yet. Once IMS records a day for a subject, we use its record instead.',
              style: TextStyle(color: tone(context, muted), fontSize: 12),
            ),
          ),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: (MediaQuery.sizeOf(context).width - 48).clamp(0, 360),
              child: DropdownButton<String?>(
                isExpanded: true,
                itemHeight: 64,
                value: subject,
                hint: Text('All subjects'),
                items: [
                  DropdownMenuItem(value: null, child: Text('All subjects')),
                  for (final s in data.subjects)
                    DropdownMenuItem(
                      value: s.code,
                      child: Text(
                        s.label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (v) => setState(() => subject = v),
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Show personal',
                  style: TextStyle(color: tone(context, muted)),
                ),
                Switch(
                  value: data.showPersonal,
                  onChanged: (v) =>
                      safely(context, () => widget.controller.showPersonal(v)),
                ),
              ],
            ),
            TextButton(
              onPressed: () => setState(() {
                selected = dayOnly(DateTime.now());
                month = DateTime(selected.year, selected.month);
              }),
              child: Text('Today'),
            ),
          ],
        ),
        SizedBox(height: 12),
        Surface(
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      DateFormat('MMMM yyyy').format(month),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Previous month',
                    onPressed: () => setState(
                      () => month = DateTime(month.year, month.month - 1),
                    ),
                    icon: Icon(Icons.chevron_left),
                  ),
                  IconButton(
                    tooltip: 'Next month',
                    onPressed: () => setState(
                      () => month = DateTime(month.year, month.month + 1),
                    ),
                    icon: Icon(Icons.chevron_right),
                  ),
                ],
              ),
              SizedBox(height: 18),
              Row(
                children: [
                  for (final d in ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
                    Expanded(
                      child: Center(
                        child: Text(
                          d,
                          style: TextStyle(
                            fontSize: 11,
                            color: tone(context, muted),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(height: 10),
              GridView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: ((offset + total + 6) ~/ 7) * 7,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisSpacing: 5,
                  crossAxisSpacing: 5,
                  mainAxisExtent: 64,
                ),
                itemBuilder: (context, index) {
                  final day = index - offset + 1;
                  if (day < 1 || day > total) return SizedBox.shrink();
                  final date = DateTime(month.year, month.month, day),
                      key = dateKey(date),
                      active = key == dateKey(selected);
                  final dayRecords = data.officialDays.where(
                    (d) =>
                        d.date == key &&
                        (subject == null || d.subject == subject),
                  );
                  final present = dayRecords.fold<int>(
                    0,
                    (sum, r) => sum + r.present,
                  );
                  final absent = dayRecords.fold<int>(
                    0,
                    (sum, r) => sum + r.absent,
                  );
                  final hasOfficial = dayRecords.any(
                    (r) => r.raw.trim().isNotEmpty,
                  );
                  final hasOffMarks = dayRecords.any((r) => r.hasOffMarks);
                  final dayColor = absent > 0
                      ? (present > 0
                            ? tone(context, amber)
                            : tone(context, red))
                      : present > 0
                      ? tone(context, green)
                      : hasOffMarks
                      ? tone(context, offDay)
                      : tone(context, muted);
                  final hasPersonal =
                      data.showPersonal &&
                      data.sessions.any(
                        (s) =>
                            dateKey(s.starts) == key &&
                            (subject == null || s.subject == subject),
                      );
                  return InkWell(
                    key: ValueKey('calendar-day-$key'),
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => setState(() => selected = date),
                    child: Container(
                      decoration: BoxDecoration(
                        color: active
                            ? ink
                            : hasOfficial
                            ? dayColor.withValues(alpha: .10)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: key == dateKey(DateTime.now()) && !active
                            ? Border.all(color: tone(context, green))
                            : null,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$day',
                            style: TextStyle(
                              color: active ? Colors.white : tone(context, ink),
                              fontWeight: active
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                            ),
                          ),
                          if (present + absent > 0)
                            Text(
                              '${present}P ${absent}A',
                              style: TextStyle(
                                fontSize: 9,
                                color: active ? Colors.white : dayColor,
                              ),
                            ),
                          if (hasOffMarks && present + absent == 0)
                            Text(
                              'Off',
                              style: TextStyle(
                                fontSize: 9,
                                color: active
                                    ? Colors.white
                                    : tone(context, offDay),
                              ),
                            ),
                          SizedBox(height: 5),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (hasOfficial)
                                dot(active ? Colors.white : dayColor),
                              if (hasOffMarks && present + absent > 0)
                                dot(
                                  active
                                      ? Color(0xFF9AC5FA)
                                      : tone(context, offDay),
                                ),
                              if (hasPersonal)
                                dot(
                                  active
                                      ? Color(0xFFD5E8AE)
                                      : Color(0xFF9662CD),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              SizedBox(height: 16),
              Wrap(
                spacing: 16,
                children: [
                  Text(
                    '● Present',
                    style: TextStyle(color: tone(context, green), fontSize: 11),
                  ),
                  Text(
                    '● Absent',
                    style: TextStyle(color: tone(context, red), fontSize: 11),
                  ),
                  Text(
                    '● Mixed',
                    style: TextStyle(color: tone(context, amber), fontSize: 11),
                  ),
                  Text(
                    '● No class / off',
                    style: TextStyle(
                      color: tone(context, offDay),
                      fontSize: 11,
                    ),
                  ),
                  Text(
                    'Blank cell: no class',
                    style: TextStyle(color: tone(context, muted), fontSize: 11),
                  ),
                  Text(
                    '● Personal',
                    style: TextStyle(color: Color(0xFF9662CD), fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(height: 24),
        Text(
          longDate(selected),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        SizedBox(height: 12),
        if (data.showPersonal)
          for (final difference in data.discrepancies.where(
            (d) =>
                d.date == dateKey(selected) &&
                (subject == null || d.subject == subject),
          ))
            Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Surface(
                child: Text(
                  'Attendance differs: ${difference.summary.replaceFirst(difference.subject, data.subjectLabel(difference.subject))}. The percentage uses the IMS record for this day. Check your log; IMS may still be updating.',
                  style: TextStyle(color: tone(context, amber)),
                ),
              ),
            ),
        Text(
          'OFFICIAL RECORDS',
          style: TextStyle(
            fontSize: 10,
            letterSpacing: 1.4,
            color: tone(context, muted),
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: 10),
        if (official.isEmpty)
          Empty(
            'No official entry for this day',
            'This date is not included in the fetched report. A blank cell within the report means no class.',
          ),
        for (final record in official)
          Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: Surface(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      data.subjectLabel(record.subject),
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Flexible(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      alignment: WrapAlignment.end,
                      children: [
                        if (record.noClass)
                          Tag('No class', color: tone(context, muted)),
                        if (record.present > 0)
                          Tag('${record.present} present'),
                        if (record.absent > 0)
                          Tag(
                            '${record.absent} absent',
                            color: tone(context, red),
                          ),
                        for (final code
                            in record.marks
                                .where((m) => m != '0' && m != '1')
                                .toSet())
                          Tag(
                            code,
                            color:
                                OfficialDay.offDayCodes.contains(
                                  code.toUpperCase(),
                                )
                                ? tone(context, offDay)
                                : tone(context, muted),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (data.showPersonal) ...[
          SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Text(
                  'PERSONAL LOG',
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 1.4,
                    color: tone(context, muted),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed:
                    selected.isAfter(dayOnly(DateTime.now())) ||
                        data.subjects.isEmpty
                    ? null
                    : () => addSession(
                        context,
                        widget.controller,
                        selected,
                        initialSubject: subject,
                      ),
                icon: Icon(Icons.add, size: 16),
                label: Text('Log a class'),
              ),
            ],
          ),
          if (selected.isAfter(dayOnly(DateTime.now())))
            Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                'Future attendance belongs in the What if? planner.',
                style: TextStyle(color: tone(context, muted)),
              ),
            ),
          if (sessions.isEmpty)
            Empty(
              'No classes scheduled',
              'Add your timetable in Settings, or log a class.',
            ),
          for (final session in sessions)
            Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: Surface(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            data.subjectLabel(session.subject),
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        Text(
                          '${session.id.startsWith('log-') ? '' : '${TimeOfDay.fromDateTime(session.starts).format(context)} · '}${session.weight} ${session.weight == 1 ? 'class' : 'classes'}',
                          style: TextStyle(
                            color: tone(context, muted),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    if (data.sessions.any((s) => s.id == session.id))
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          key: ValueKey('delete-${session.id}'),
                          onPressed: () => safely(
                            context,
                            () => widget.controller.deletePersonalRecord(
                              session.id,
                            ),
                          ),
                          icon: Icon(Icons.delete_outline, size: 18),
                          label: Text('Delete personal record'),
                        ),
                      ),
                    SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        for (final status in AttendanceStatus.values)
                          ChoiceChip(
                            label: Text(
                              status == AttendanceStatus.unknown
                                  ? 'Unrecorded'
                                  : status.name,
                            ),
                            selected: session.status == status,
                            onSelected:
                                selected.isAfter(dayOnly(DateTime.now()))
                                ? null
                                : (_) => safely(
                                    context,
                                    () => widget.controller.mark(
                                      session,
                                      status,
                                      session.note,
                                    ),
                                  ),
                          ),
                      ],
                    ),
                    TextButton.icon(
                      onPressed: () async {
                        final note = await askText(
                          context,
                          'Class note',
                          initial: session.note,
                          hint: 'A reminder or correction',
                        );
                        if (note != null && context.mounted) {
                          await safely(
                            context,
                            () => widget.controller.mark(
                              session,
                              session.status,
                              note,
                            ),
                          );
                        }
                      },
                      icon: Icon(Icons.edit_note, size: 17),
                      label: Text(
                        session.note.isEmpty ? 'Add a note' : session.note,
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
        SizedBox(height: 30),
      ],
    );
  }

  Widget dot(Color color) => Container(
    width: 4,
    height: 4,
    margin: EdgeInsets.symmetric(horizontal: 2),
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

Future<void> addSession(
  BuildContext context,
  AppController controller,
  DateTime day, {
  String? initialSubject,
}) async {
  String code = initialSubject ?? controller.data.subjects.first.code;
  int present = 0, absent = 0, maxChoice = 10;
  final formKey = GlobalKey<FormState>();
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, set) => AlertDialog(
        title: Text('Log a class'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(longDate(day)),
                SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  itemHeight: 64,
                  initialValue: code,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: 'Subject'),
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
                SizedBox(height: 16),
                for (final isPresent in [true, false])
                  Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isPresent ? 'Classes present' : 'Classes absent',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            for (var n = 0; n <= maxChoice; n++)
                              ChoiceChip(
                                key: ValueKey(
                                  '${isPresent ? 'present' : 'absent'}-$n',
                                ),
                                label: Text('$n'),
                                selected: (isPresent ? present : absent) == n,
                                onSelected: (_) => set(() {
                                  if (isPresent) {
                                    present = n;
                                  } else {
                                    absent = n;
                                  }
                                }),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                TextButton(
                  onPressed: () => set(() => maxChoice += 10),
                  child: Text('More numbers'),
                ),
                Text('Total: ${present + absent} classes'),
                SizedBox(height: 8),
                Text(
                  'Adds to your personal log for this day.',
                  style: TextStyle(fontSize: 12, color: tone(context, muted)),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          FilledButton(
            onPressed: present + absent == 0
                ? null
                : () {
                    if (formKey.currentState!.validate()) {
                      Navigator.pop(context, true);
                    }
                  },
            child: Text('Save'),
          ),
        ],
      ),
    ),
  );
  if (result == true && context.mounted) {
    await safely(
      context,
      () => controller.logClasses(code, day, present, absent),
    );
  }
}
