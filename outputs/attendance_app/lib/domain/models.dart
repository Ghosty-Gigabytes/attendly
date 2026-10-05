import 'display_dates.dart';
import 'dart:math' as math;

String dateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
DateTime dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

enum AttendanceStatus { present, absent, cancelled, unknown }

enum Baseline { official, personal }

enum PlanAction { attend, miss, cancel }

class Counts {
  final int attended, held;
  const Counts(this.attended, this.held)
    : assert(attended >= 0 && held >= attended);
  double? get percent => held == 0 ? null : 100 * attended / held;
  bool eligible([int target = 75]) =>
      held > 0 && attended * 100 >= held * target;
  int canMiss([int target = 75]) =>
      math.max(0, (100 * attended - target * held) ~/ target);
  int recover([int target = 75]) {
    if (held == 0) return 0;
    final deficit = target * held - 100 * attended;
    return deficit <= 0 ? 0 : (deficit + (100 - target) - 1) ~/ (100 - target);
  }

  Counts add(PlanAction action, [int weight = 1]) => switch (action) {
    PlanAction.attend => Counts(attended + weight, held + weight),
    PlanAction.miss => Counts(attended, held + weight),
    PlanAction.cancel => this,
  };
  Map<String, dynamic> toJson() => {'a': attended, 't': held};
  factory Counts.fromJson(Map<String, dynamic> j) =>
      Counts(j['a'] as int, j['t'] as int);
}

class Subject {
  final String code, name;
  final Counts official;
  final int color;
  const Subject(this.code, this.name, this.official, this.color);
  String get label =>
      name.trim().isEmpty || name == code ? code : '$code · $name';
  Map<String, dynamic> toJson() => {
    'code': code,
    'name': name,
    'official': official.toJson(),
    'color': color,
  };
  factory Subject.fromJson(Map<String, dynamic> j) =>
      Subject(j['code'], j['name'], Counts.fromJson(j['official']), j['color']);
}

class OfficialDay {
  final String subject, date, raw;
  const OfficialDay(this.subject, this.date, this.raw);
  List<String> get marks =>
      raw.split('+').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
  int get present => marks.where((s) => s == '1').length;
  int get absent => marks.where((s) => s == '0').length;
  static const offDayCodes = {
    'CR',
    'CS',
    'GH',
    'MB',
    'MS',
    'NA',
    'NT',
    'OD',
    'TL',
  };
  List<String> get offMarks =>
      marks.where((s) => offDayCodes.contains(s.toUpperCase())).toList();
  bool get hasOffMarks => offMarks.isNotEmpty;
  bool get noClass =>
      raw.trim().isEmpty ||
      (marks.isNotEmpty &&
          marks.every((s) => offDayCodes.contains(s.toUpperCase())));
  String get description {
    if (noClass) {
      return hasOffMarks ? 'No class · ${offMarks.join('+')}' : 'No class';
    }
    final parts = <String>[
      if (present > 0) '$present present',
      if (absent > 0) '$absent absent',
      ...marks.where((s) => s != '0' && s != '1'),
    ];
    return parts.join(' · ');
  }

  Map<String, dynamic> toJson() => {
    'subject': subject,
    'date': date,
    'raw': raw,
  };
  factory OfficialDay.fromJson(Map<String, dynamic> j) =>
      OfficialDay(j['subject'], j['date'], j['raw']);
}

class Session {
  final String id, subject, note;
  final DateTime starts;
  final AttendanceStatus status;
  final int weight;
  const Session({
    required this.id,
    required this.subject,
    required this.starts,
    this.status = AttendanceStatus.unknown,
    this.note = '',
    this.weight = 1,
  });
  Session mark(AttendanceStatus value, String text) => Session(
    id: id,
    subject: subject,
    starts: starts,
    status: value,
    note: text,
    weight: weight,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'subject': subject,
    'starts': starts.toIso8601String(),
    'status': status.name,
    'note': note,
    'weight': weight,
  };
  factory Session.fromJson(Map<String, dynamic> j) => Session(
    id: j['id'],
    subject: j['subject'],
    starts: DateTime.parse(j['starts']),
    status: AttendanceStatus.values.byName(j['status']),
    note: j['note'],
    weight: j['weight'],
  );
}

class TimetableRule {
  final String id, subject;
  final int weekday, hour, minute, weight;
  final DateTime from, until;
  const TimetableRule({
    required this.id,
    required this.subject,
    required this.weekday,
    required this.hour,
    this.minute = 0,
    this.weight = 1,
    required this.from,
    required this.until,
  });
  Session? on(DateTime day) {
    if (day.weekday != weekday ||
        dayOnly(day).isBefore(dayOnly(from)) ||
        dayOnly(day).isAfter(dayOnly(until))) {
      return null;
    }
    return Session(
      id: '$id:${dateKey(day)}',
      subject: subject,
      starts: DateTime(day.year, day.month, day.day, hour, minute),
      weight: weight,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'subject': subject,
    'weekday': weekday,
    'hour': hour,
    'minute': minute,
    'weight': weight,
    'from': dateKey(from),
    'until': dateKey(until),
  };
  factory TimetableRule.fromJson(Map<String, dynamic> j) => TimetableRule(
    id: j['id'],
    subject: j['subject'],
    weekday: j['weekday'],
    hour: j['hour'],
    minute: j['minute'],
    weight: j['weight'],
    from: DateTime.parse(j['from']),
    until: DateTime.parse(j['until']),
  );
}

class Scenario {
  final String id, name;
  final DateTime from, until;
  final Baseline baseline;
  final int target;
  final Map<String, PlanAction> actions;
  final List<Session> extras;
  const Scenario({
    required this.id,
    required this.name,
    required this.from,
    required this.until,
    this.baseline = Baseline.official,
    this.target = 75,
    this.actions = const {},
    this.extras = const [],
  });
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'from': dateKey(from),
    'until': dateKey(until),
    'baseline': baseline.name,
    'target': target,
    'actions': actions.map((k, v) => MapEntry(k, v.name)),
    'extras': extras.map((s) => s.toJson()).toList(),
  };
  factory Scenario.fromJson(Map<String, dynamic> j) => Scenario(
    id: j['id'],
    name: j['name'],
    from: DateTime.parse(j['from']),
    until: DateTime.parse(j['until']),
    baseline: Baseline.values.byName(j['baseline']),
    target: j['target'],
    actions: (j['actions'] as Map<String, dynamic>).map(
      (k, v) => MapEntry(k, PlanAction.values.byName(v)),
    ),
    extras: (j['extras'] as List? ?? [])
        .map((e) => Session.fromJson(e))
        .toList(),
  );
}

class AppData {
  String subjectLabel(String code) =>
      subjects.where((s) => s.code == code).firstOrNull?.label ?? code;

  final List<Subject> subjects;
  final List<OfficialDay> officialDays;
  final List<Session> sessions;
  final List<TimetableRule> timetable;
  final List<Scenario> scenarios;
  final String account, semester;
  final DateTime? synced;
  final bool showPersonal;
  final int target;
  const AppData({
    this.subjects = const [],
    this.officialDays = const [],
    this.sessions = const [],
    this.timetable = const [],
    this.scenarios = const [],
    this.account = '',
    this.semester = '',
    this.synced,
    this.showPersonal = false,
    this.target = 75,
  });
  AppData copyWith({
    List<Subject>? subjects,
    List<OfficialDay>? officialDays,
    List<Session>? sessions,
    List<TimetableRule>? timetable,
    List<Scenario>? scenarios,
    String? account,
    String? semester,
    DateTime? synced,
    bool? showPersonal,
    int? target,
  }) => AppData(
    subjects: subjects ?? this.subjects,
    officialDays: officialDays ?? this.officialDays,
    sessions: sessions ?? this.sessions,
    timetable: timetable ?? this.timetable,
    scenarios: scenarios ?? this.scenarios,
    account: account ?? this.account,
    semester: semester ?? this.semester,
    synced: synced ?? this.synced,
    showPersonal: showPersonal ?? this.showPersonal,
    target: target ?? this.target,
  );
  Counts personalLog(String code) {
    int a = 0, t = 0;
    for (final s in sessions.where((s) => s.subject == code)) {
      if (s.status == AttendanceStatus.present) {
        a += s.weight;
        t += s.weight;
      }
      if (s.status == AttendanceStatus.absent) t += s.weight;
    }
    return Counts(a, t);
  }

  Map<String, Counts> personalDays(String code) {
    final days = <String, Counts>{};
    for (final s in sessions.where(
      (s) => s.subject == code && s.status != AttendanceStatus.unknown,
    )) {
      final key = dateKey(s.starts), old = days[key] ?? const Counts(0, 0);
      days[key] = Counts(
        old.attended + (s.status == AttendanceStatus.present ? s.weight : 0),
        old.held +
            (s.status == AttendanceStatus.present ||
                    s.status == AttendanceStatus.absent
                ? s.weight
                : 0),
      );
    }
    return days;
  }

  /// IMS wins for any populated subject/day. Blank or absent IMS dates are pending.
  Counts personal(String code) {
    final official =
        subjects.where((s) => s.code == code).firstOrNull?.official ??
        const Counts(0, 0);
    var attended = official.attended, held = official.held;
    final recorded = officialDays
        .where((d) => d.subject == code && d.raw.trim().isNotEmpty)
        .map((d) => d.date)
        .toSet();
    for (final entry in personalDays(code).entries) {
      if (!recorded.contains(entry.key)) {
        attended += entry.value.attended;
        held += entry.value.held;
      }
    }
    return Counts(attended, held);
  }

  List<AttendanceDiscrepancy> get discrepancies {
    final result = <AttendanceDiscrepancy>[];
    for (final subject in subjects) {
      final personal = personalDays(subject.code);
      for (final day in officialDays.where(
        (d) => d.subject == subject.code && d.raw.trim().isNotEmpty,
      )) {
        final log = personal[day.date];
        // Unknown portal symbols cannot safely be compared to counted classes.
        if (log == null ||
            day.marks.any(
              (m) =>
                  m != '0' &&
                  m != '1' &&
                  !OfficialDay.offDayCodes.contains(m.toUpperCase()),
            )) {
          continue;
        }
        final official = Counts(day.present, day.present + day.absent);
        if (log.attended != official.attended || log.held != official.held) {
          result.add(
            AttendanceDiscrepancy(subject.code, day.date, official, log),
          );
        }
      }
    }
    result.sort(
      (a, b) => '${a.date}:${a.subject}'.compareTo('${b.date}:${b.subject}'),
    );
    return result;
  }

  List<Session> on(DateTime date) {
    final result = <String, Session>{};
    for (final rule in timetable) {
      final s = rule.on(date);
      if (s != null) result[s.id] = s;
    }
    for (final s in sessions.where((s) => dateKey(s.starts) == dateKey(date))) {
      result[s.id] = s;
    }
    return result.values.toList()..sort((a, b) => a.starts.compareTo(b.starts));
  }

  Map<String, dynamic> toJson() => {
    'subjects': subjects.map((s) => s.toJson()).toList(),
    'officialDays': officialDays.map((s) => s.toJson()).toList(),
    'sessions': sessions.map((s) => s.toJson()).toList(),
    'timetable': timetable.map((s) => s.toJson()).toList(),
    'scenarios': scenarios.map((s) => s.toJson()).toList(),
    'account': account,
    'semester': semester,
    'synced': synced?.toIso8601String(),
    'showPersonal': showPersonal,
    'target': target,
  };
  factory AppData.fromJson(Map<String, dynamic> j) => AppData(
    subjects: (j['subjects'] as List).map((s) => Subject.fromJson(s)).toList(),
    officialDays: (j['officialDays'] as List)
        .map((s) => OfficialDay.fromJson(s))
        .toList(),
    sessions: (j['sessions'] as List).map((s) => Session.fromJson(s)).toList(),
    timetable: (j['timetable'] as List)
        .map((s) => TimetableRule.fromJson(s))
        .toList(),
    scenarios: (j['scenarios'] as List)
        .map((s) => Scenario.fromJson(s))
        .toList(),
    account: j['account'],
    semester: j['semester'],
    synced: j['synced'] == null ? null : DateTime.parse(j['synced']),
    showPersonal: j['showPersonal'],
    target: j['target'],
  );
}

class AttendanceDiscrepancy {
  final String subject, date;
  final Counts official, personal;
  const AttendanceDiscrepancy(
    this.subject,
    this.date,
    this.official,
    this.personal,
  );
  String get summary =>
      '$subject · ${displayDate(DateTime.parse(date))}: IMS ${official.attended}/${official.held}, personal ${personal.attended}/${personal.held}';
}
