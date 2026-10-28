import 'models.dart';

class ProjectionStep {
  final Session session;
  final PlanAction action;
  final Counts counts;
  const ProjectionStep(this.session, this.action, this.counts);
}

class Projection {
  final Subject subject;
  final Counts start, end;
  final List<ProjectionStep> steps;
  final int target;
  const Projection(this.subject, this.start, this.end, this.steps, this.target);
  bool get dipsBelow =>
      (start.held > 0 && !start.eligible(target)) ||
      steps.any((s) => s.counts.held > 0 && !s.counts.eligible(target));
  double? get lowest {
    final values = [
      start.percent,
      ...steps.map((s) => s.counts.percent),
    ].whereType<double>().toList()..sort();
    return values.isEmpty ? null : values.first;
  }
}

List<Session> plannedSessions(AppData data, Scenario plan) {
  final map = <String, Session>{};
  for (
    var day = dayOnly(plan.from);
    !day.isAfter(dayOnly(plan.until));
    day = DateTime(day.year, day.month, day.day + 1)
  ) {
    for (final rule in data.timetable) {
      final s = rule.on(day);
      if (s != null) map[s.id] = s;
    }
  }
  for (final s in plan.extras) {
    if (!dayOnly(s.starts).isBefore(dayOnly(plan.from)) &&
        !dayOnly(s.starts).isAfter(dayOnly(plan.until))) {
      map[s.id] = s;
    }
  }
  return map.values.toList()..sort((a, b) {
    final time = a.starts.compareTo(b.starts);
    return time == 0 ? a.id.compareTo(b.id) : time;
  });
}

/// A block may count as multiple classes. Existing saved whole-block actions
/// remain the fallback; individual class choices override them.
String planClassKey(Session session, int index) =>
    '${session.id}::class:$index';
List<PlanAction> sessionActions(Scenario plan, Session session) => [
  for (var i = 0; i < session.weight; i++)
    plan.actions[planClassKey(session, i)] ??
        plan.actions[session.id] ??
        PlanAction.attend,
];
void setSessionAction(
  Map<String, PlanAction> actions,
  Session session,
  PlanAction action,
) {
  for (var i = 0; i < session.weight; i++) {
    actions.remove(planClassKey(session, i));
  }
  if (action == PlanAction.attend) {
    actions.remove(session.id);
  } else {
    actions[session.id] = action;
  }
}

List<Projection> project(AppData data, Scenario plan) {
  final sessions = plannedSessions(data, plan);
  return data.subjects.map((subject) {
    final start = plan.baseline == Baseline.official
        ? subject.official
        : data.personal(subject.code);
    var current = start;
    final steps = <ProjectionStep>[];
    for (final s in sessions.where((s) => s.subject == subject.code)) {
      final choices = sessionActions(plan, s);
      if (choices.every((a) => a == choices.first)) {
        current = current.add(choices.first, s.weight);
        steps.add(ProjectionStep(s, choices.first, current));
      } else {
        for (var i = 0; i < choices.length; i++) {
          final unit = Session(
            id: planClassKey(s, i),
            subject: s.subject,
            starts: s.starts,
            note: 'Class ${i + 1} of ${s.weight}',
          );
          current = current.add(choices[i]);
          steps.add(ProjectionStep(unit, choices[i], current));
        }
      }
    }
    return Projection(subject, start, current, steps, plan.target);
  }).toList();
}

/// Candidate whole-day absences that never cross the selected threshold.
List<DateTime> suitableDays(AppData data, Scenario plan) {
  final sessions = plannedSessions(data, plan);
  final dates = sessions.map((s) => dateKey(s.starts)).toSet();
  return dates
      .where((date) {
        final actions = {...plan.actions};
        for (final s in sessions.where((s) => dateKey(s.starts) == date)) {
          final choices = sessionActions(plan, s);
          for (var i = 0; i < choices.length; i++) {
            if (choices[i] != PlanAction.cancel) {
              actions[planClassKey(s, i)] = PlanAction.miss;
            }
          }
        }
        final candidate = Scenario(
          id: '',
          name: '',
          from: plan.from,
          until: plan.until,
          baseline: plan.baseline,
          target: plan.target,
          actions: actions,
          extras: plan.extras,
        );
        return project(data, candidate).every((p) => !p.dipsBelow);
      })
      .map(DateTime.parse)
      .toList();
}

/// Recovery after the planning window, assuming every remaining scheduled
/// session is held and attended. Null means the known timetable is insufficient.
DateTime? recoveryDate(AppData data, Scenario plan, Projection result) {
  if (result.end.eligible(plan.target)) return plan.until;
  var counts = result.end;
  final rules = data.timetable
      .where((r) => r.subject == result.subject.code)
      .toList();
  if (rules.isEmpty) return null;
  final last = rules.map((r) => r.until).reduce((a, b) => a.isAfter(b) ? a : b);
  final limit = plan.until.add(const Duration(days: 366));
  final until = last.isBefore(limit) ? last : limit;
  for (
    var day = DateTime(plan.until.year, plan.until.month, plan.until.day + 1);
    !day.isAfter(until);
    day = DateTime(day.year, day.month, day.day + 1)
  ) {
    final sessions = rules.map((r) => r.on(day)).whereType<Session>().toList()
      ..sort((a, b) => a.starts.compareTo(b.starts));
    for (final session in sessions) {
      counts = counts.add(PlanAction.attend, session.weight);
      if (counts.eligible(plan.target)) return session.starts;
    }
  }
  return null;
}
