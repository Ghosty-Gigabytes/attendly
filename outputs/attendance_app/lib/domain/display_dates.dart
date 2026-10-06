
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
String displayDateTime(DateTime date) {
  final local = date.toLocal();
  return '${longDate(local)} ${_two(local.hour)}:${_two(local.minute)}';
}

const _weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
String longDate(DateTime date) => '${_weekdays[date.weekday - 1]}, ${displayDate(date)}';
