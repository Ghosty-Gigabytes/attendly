const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];
String _two(int value) => value.toString().padLeft(2, '0');
String displayDate(DateTime date) =>
    '${date.day} ${_months[date.month - 1]} ${date.year}';
String numericDate(DateTime date) =>
    '${_two(date.day)}-${_two(date.month)}-${date.year}';
String displayClock(int minutes, {bool use24Hour = true}) {
  final hour = (minutes ~/ 60) % 24, minute = minutes % 60;
  if (use24Hour) return '${_two(minutes ~/ 60)}:${_two(minute)}';
  return '${hour % 12 == 0 ? 12 : hour % 12}:${_two(minute)} ${hour < 12 ? 'AM' : 'PM'}';
}

int? parseDisplayClock(String text) {
  final match = RegExp(
    r'^(\d{1,2}):(\d{2})\s*(AM|PM)?$',
    caseSensitive: false,
  ).firstMatch(text.trim());
  if (match == null) return null;
  var h = int.parse(match[1]!);
  final m = int.parse(match[2]!);
  final suffix = match[3]?.toUpperCase();
  if (m > 59) return null;
  if (suffix != null) {
    if (h < 1 || h > 12) return null;
    h = h % 12 + (suffix == 'PM' ? 12 : 0);
  } else if (h > 24 || h == 24 && m != 0) {
    return null;
  }
  return h * 60 + m;
}

String displayDateTime(DateTime date, {bool use24Hour = true}) {
  final local = date.toLocal();
  return '${longDate(local)} ${displayClock(local.hour * 60 + local.minute, use24Hour: use24Hour)}';
}

const _weekdays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];
String longDate(DateTime date) =>
    '${_weekdays[date.weekday - 1]}, ${displayDate(date)}';
