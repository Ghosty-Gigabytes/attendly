import 'models.dart';

/// Consecutive upcoming teaching days for this subject, starting tomorrow.
/// Assumes the saved timetable is followed; holidays are not inferred.
String widgetDayAdvice(AppData data, Subject subject, {DateTime? now}) {
  final counts = subject.official;
  if (counts.held == 0) return 'No classes recorded';
  final recovering = !counts.eligible();
  final required = recovering ? counts.recover() : counts.canMiss();
  if (!recovering && required == 0) return 'Skip 0 days';
  final rules = data.timetable.where((r) => r.subject == subject.code).toList();
  final fallback = recovering
      ? 'Need $required classes · set timetable'
      : 'Can miss $required classes · set timetable';
  if (rules.isEmpty) return fallback;
  final start = dayOnly(now ?? DateTime.now());
  var days = 0, classes = 0;
  for (var offset = 1; offset <= 366; offset++) {
    final date = DateTime(start.year, start.month, start.day + offset);
    final weight = rules.fold<int>(
      0,
      (sum, r) => sum + (r.on(date)?.weight ?? 0),
    );
    if (weight == 0) continue;
    if (!recovering && classes + weight > required) {
      return 'Skip ~$days class days';
    }
    classes += weight;
    days++;
    if (recovering && classes >= required) return 'Attend ~$days days to 75%';
  }
  if (!recovering && days > 0) return 'Skip ~$days scheduled days';
  return recovering ? 'Need $required classes · extend timetable' : fallback;
}
