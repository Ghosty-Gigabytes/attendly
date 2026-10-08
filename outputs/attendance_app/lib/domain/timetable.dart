import 'models.dart';

const weekdays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];
const timetableHeader = 'day,subject_code,start_time,end_time,attendance_count';
const timetableTemplate =
    '$timetableHeader\nMonday,,09:00,10:00,1\nTuesday,,14:00,16:00,1';

int? weekdayNumber(String value) {
  final text = value.trim().toLowerCase();
  for (var i = 0; i < weekdays.length; i++) {
    if (text == weekdays[i].toLowerCase() ||
        text == weekdays[i].substring(0, 3).toLowerCase()) {
      return i + 1;
    }
  }
  return null;
}

int? clockMinutes(String value, {bool end = false}) {
  final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(value.trim());
  if (match == null) return null;
  final h = int.parse(match[1]!), m = int.parse(match[2]!);
  if (end && h == 24 && m == 0) return 1440;
  if (h > 23 || m > 59) return null;
  return h * 60 + m;
}

String clockText(int minutes) =>
    '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';

class TimetableEntry {
  final String id, day, subject, start, end, count;
  const TimetableEntry({
    required this.id,
    required this.day,
    required this.subject,
    required this.start,
    required this.end,
    this.count = '1',
  });
  int? get weekday => weekdayNumber(day);
  int? get startMinutes => clockMinutes(start);
  int? get endMinutes => clockMinutes(end, end: true);
  List<String> issues(List<Subject> subjects) => [
    if (weekday == null) 'Choose a weekday',
    if (!subjects.any((s) => s.code == subject)) 'Match a subject',
    if (startMinutes == null) 'Enter a start time (HH:MM)',
    if (endMinutes == null) 'Enter an end time (HH:MM)',
    if (startMinutes != null &&
        endMinutes != null &&
        endMinutes! <= startMinutes!)
      'End time must be after start time',
    if (int.tryParse(count) == null ||
        int.parse(count) < 1 ||
        int.parse(count) > 20)
      'Attendance count must be 1–20',
  ];
  TimetableEntry copy({
    String? id,
    String? day,
    String? subject,
    String? start,
    String? end,
    String? count,
  }) => TimetableEntry(
    id: id ?? this.id,
    day: day ?? this.day,
    subject: subject ?? this.subject,
    start: start ?? this.start,
    end: end ?? this.end,
    count: count ?? this.count,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'day': day,
    'subject': subject,
    'start': start,
    'end': end,
    'count': count,
  };
  factory TimetableEntry.fromJson(Map<String, dynamic> j) => TimetableEntry(
    id: j['id'],
    day: j['day'],
    subject: j['subject'],
    start: j['start'],
    end: j['end'],
    count: j['count'],
  );
  factory TimetableEntry.fromRule(TimetableRule r) => TimetableEntry(
    id: r.id,
    day: weekdays[r.weekday - 1],
    subject: r.subject,
    start: clockText(r.hour * 60 + r.minute),
    end: clockText(r.endMinutes),
    count: '${r.weight}',
  );
  TimetableRule rule(DateTime from, DateTime until) => TimetableRule(
    id: id,
    subject: subject,
    weekday: weekday!,
    hour: startMinutes! ~/ 60,
    minute: startMinutes! % 60,
    weight: int.parse(count),
    endMinuteOfDay: endMinutes,
    from: from,
    until: until,
  );
}

/// Strict CSV structure, tolerant cell values. Bad values remain editable.
List<TimetableEntry> importTimetableCsv(String source, List<Subject> subjects) {
  if (source.length > 200000) {
    throw const FormatException('CSV is too large. Use a file under 200 KB.');
  }
  var text = source.replaceAll('\uFEFF', '').trim();
  if (text.startsWith('```')) {
    text = text
        .replaceFirst(RegExp(r'^```(?:csv)?\s*\n', caseSensitive: false), '')
        .replaceFirst(RegExp(r'\n```\s*$'), '');
  }
  final rows = <List<String>>[], cells = <String>[];
  var field = StringBuffer(), quoted = false, closed = false;
  void cell() {
    cells.add(field.toString().trim());
    field = StringBuffer();
    closed = false;
  }

  void row() {
    cell();
    if (cells.any((s) => s.isNotEmpty)) rows.add(List.of(cells));
    cells.clear();
  }

  for (var i = 0; i < text.length; i++) {
    final ch = text[i];
    if (quoted) {
      if (ch == '"') {
        if (i + 1 < text.length && text[i + 1] == '"') {
          field.write('"');
          i++;
        } else {
          quoted = false;
          closed = true;
        }
      } else {
        field.write(ch);
      }
    } else if (ch == '"' && field.toString().trim().isEmpty && !closed) {
      field = StringBuffer();
      quoted = true;
    } else if (ch == ',') {
      cell();
    } else if (ch == '\n' || ch == '\r') {
      if (ch == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
      row();
    } else if (closed && ch.trim().isNotEmpty || ch == '"') {
      throw const FormatException(
        'Unexpected text after a quote. Paste only the CSV table.',
      );
    } else {
      field.write(ch);
    }
  }
  if (quoted) {
    throw const FormatException(
      'A quoted CSV field is unfinished. Check the pasted text.',
    );
  }
  row();
  if (rows.length < 2) {
    throw const FormatException('Include the header and at least one class.');
  }
  if (rows.length > 501) {
    throw const FormatException('Import up to 500 classes at a time.');
  }
  final header = rows.first.map((s) => s.toLowerCase()).toList();
  final expected = timetableHeader.split(',');
  if (header.length != 5 ||
      header.toSet().length != 5 ||
      !expected.every(header.contains)) {
    throw const FormatException(
      'Use the header: day,subject_code,start_time,end_time,attendance_count',
    );
  }
  final prefix = DateTime.now().microsecondsSinceEpoch;
  return [
    for (var i = 1; i < rows.length; i++)
      (() {
        final values = rows[i];
        if (values.length != header.length) {
          throw FormatException(
            'Row ${i + 1} has ${values.length} fields; expected 5. No rows were imported.',
          );
        }
        String get(String name) => values[header.indexOf(name)];
        final code = get('subject_code');
        final match = subjects
            .where((s) => s.code.toLowerCase() == code.toLowerCase())
            .firstOrNull;
        final day = weekdayNumber(get('day'));
        return TimetableEntry(
          id: 'import-$prefix-$i',
          day: day == null ? get('day') : weekdays[day - 1],
          subject: match?.code ?? code,
          start: get('start_time'),
          end: get('end_time'),
          count: get('attendance_count'),
        );
      })(),
  ];
}

Map<String, List<String>> timetableIssues(
  List<TimetableEntry> entries,
  List<Subject> subjects,
) {
  final result = {for (final e in entries) e.id: e.issues(subjects)};
  for (var i = 0; i < entries.length; i++) {
    final a = entries[i];
    if (a.weekday == null || a.startMinutes == null || a.endMinutes == null) {
      continue;
    }
    for (final b in entries.skip(i + 1)) {
      if (a.weekday == b.weekday &&
          b.startMinutes != null &&
          b.endMinutes != null &&
          a.startMinutes! < b.endMinutes! &&
          b.startMinutes! < a.endMinutes!) {
        final duplicate =
            a.subject == b.subject &&
            a.startMinutes == b.startMinutes &&
            a.endMinutes == b.endMinutes;
        final issue = duplicate
            ? 'Duplicate class — remove one copy'
            : 'Overlapping classes — check times or section';
        result[a.id]!.add(issue);
        result[b.id]!.add(issue);
      }
    }
  }
  return result;
}

String timetableAiPrompt(List<Subject> subjects, String section) =>
    '''Convert my timetable photo into CSV for an attendance app.
Return only CSV, with no Markdown or commentary, using this exact header:
$timetableHeader

- Use full English weekdays and 24-hour HH:MM times.
- Create one row per session. Exclude breaks and lunch.
- Include only section/batch: ${section.trim().isEmpty ? '[FILL IN YOUR SECTION/BATCH BEFORE SENDING]' : section.trim()}.
- Match subject codes to the list below. Leave unknown subject_code blank.
- Leave unreadable or ambiguous days/times blank; never invent information.
- Set attendance_count to 1 unless explicitly specified otherwise. Do not infer it from duration.
- Quote fields containing commas. Escape quotes by doubling them.
- For alternative batches, include only my batch. If unclear, ask me before generating CSV.

Valid subjects:
${subjects.map((s) => '${s.code} — ${s.name.replaceAll('\n', ' ')}').join('\n')}
''';

/// Replace only the chosen interval; retain both older and later schedules.
List<TimetableRule> replaceTimetableWindow(
  List<TimetableRule> previous,
  List<TimetableEntry> entries,
  DateTime from,
  DateTime until,
) {
  TimetableRule slice(TimetableRule r, DateTime a, DateTime b, String id) =>
      TimetableRule(
        id: id,
        subject: r.subject,
        weekday: r.weekday,
        hour: r.hour,
        minute: r.minute,
        weight: r.weight,
        endMinuteOfDay: r.endMinutes,
        from: a,
        until: b,
      );
  final result = <TimetableRule>[];
  for (final r in previous) {
    if (r.until.isBefore(from) || r.from.isAfter(until)) {
      result.add(r);
      continue;
    }
    if (r.from.isBefore(from)) {
      result.add(
        slice(r, r.from, DateTime(from.year, from.month, from.day - 1), r.id),
      );
    }
    if (r.until.isAfter(until)) {
      result.add(
        slice(
          r,
          DateTime(until.year, until.month, until.day + 1),
          r.until,
          r.id,
        ),
      );
    }
  }
  result.addAll(entries.map((e) => e.rule(from, until)));
  return result;
}
