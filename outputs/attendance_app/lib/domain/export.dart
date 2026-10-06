import 'display_dates.dart';
import 'models.dart';

String exportCsv(AppData data) {
  String cell(Object value) {
    var text = value.toString();
    // Prevent formulas when the exported CSV is opened in a spreadsheet.
    if (RegExp(r'^[=+@\-\t\r]').hasMatch(text)) text = "'$text";
    return '"${text.replaceAll('"', '""')}"';
  }

  final rows = <List<Object>>[
    [
      'source',
      'subject',
      'subject_name',
      'date',
      'status_or_raw_value',
      'attended',
      'held',
      'weight',
      'note',
    ],
    for (final s in data.subjects)
      [
        'official_total',
        s.code,
        s.name,
        '',
        '',
        s.official.attended,
        s.official.held,
        '',
        '',
      ],
    for (final d in data.officialDays)
      [
        'official_day',
        d.subject,
        data.subjects.where((s) => s.code == d.subject).firstOrNull?.name ?? '',
        numericDate(DateTime.parse(d.date)),
        d.raw,
        '',
        '',
        '',
        '',
      ],
    for (final s in data.sessions)
      [
        'personal',
        s.subject,
        data.subjects
                .where((subject) => subject.code == s.subject)
                .firstOrNull
                ?.name ??
            '',
        displayDateTime(s.starts),
        s.status.name,
        '',
        '',
        s.weight,
        s.note,
      ],
  ];
  return rows.map((row) => row.map(cell).join(',')).join('\r\n');
}
