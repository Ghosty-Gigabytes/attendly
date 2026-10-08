import 'package:html/dom.dart';
import 'package:html/parser.dart' as html;
import '../domain/models.dart';

class PortalException implements Exception {
  final String message;
  const PortalException(this.message);
  @override
  String toString() => message;
}

class PortalSessionExpired extends PortalException {
  const PortalSessionExpired()
    : super('Your IMS session has expired. Please sign in again.');
}

class PortalLoginRejected extends PortalException {
  const PortalLoginRejected(super.message);
}

class PortalForm {
  final Uri action;
  final Map<String, String> fields;
  final Uri? captcha;
  const PortalForm(this.action, this.fields, this.captcha);
}

class PortalParser {
  static const colors = [
    0xFF4469E8,
    0xFF9B64D9,
    0xFF179B89,
    0xFFDE9747,
    0xFFDA6386,
    0xFF6383A0,
  ];
  Document parse(String source) => html.parse(source);
  Element? closest(Element? element, String tag) {
    while (element != null) {
      if (element.localName == tag) return element;
      element = element.parent;
    }
    return null;
  }

  String clean(String value) => value.replaceAll(RegExp(r'\s+'), ' ').trim();

  /// Matches captchaFetch() in the supplied Python program. The legacy IMS
  /// table/form nesting is repaired differently by HTML5 parsers, so inputs
  /// must be selected from the document, not required to descend from a form.
  PortalForm loginChallenge(String source) {
    final doc = parse(source);
    final token = doc.querySelector('#HRAND_NUM')?.attributes['value'];
    final image = doc.querySelector('#captchaimg')?.attributes['src'];
    if (token == null || token.isEmpty) {
      throw const PortalException(
        'IMS did not return the login security token. Refresh the CAPTCHA to try again.',
      );
    }
    if (image == null || image.isEmpty) {
      throw const PortalException(
        'IMS did not return a CAPTCHA image. Refresh to try again.',
      );
    }
    return PortalForm(
      Uri.parse('https://www.imsnsit.org/imsnsit/student_login.php'),
      {'HRAND_NUM': token},
      Uri.parse('https://imsnsit.org/imsnsit/').resolve(image),
    );
  }

  PortalForm form(String source, Uri page, String requiredField) {
    final doc = parse(source);
    final input =
        doc.querySelector('[name="$requiredField"]') ??
        doc.querySelector('#$requiredField');
    final forms = doc.querySelectorAll('form');
    final form =
        closest(input, 'form') ?? (forms.length == 1 ? forms.single : null);
    if (form == null || input == null) {
      throw const PortalException(
        'The portal form has changed. Your saved attendance is unchanged.',
      );
    }
    final fields = <String, String>{};
    final container = closest(input, 'form') == null ? doc : form;
    for (final e in container.querySelectorAll('input[name]')) {
      final type = e.attributes['type']?.toLowerCase();
      if (type == 'submit' ||
          type == 'button' ||
          ((type == 'checkbox' || type == 'radio') &&
              !e.attributes.containsKey('checked'))) {
        continue;
      }
      fields[e.attributes['name']!] = e.attributes['value'] ?? '';
    }
    for (final e in container.querySelectorAll('select[name]')) {
      final option =
          e.querySelector('option[selected]') ?? e.querySelector('option');
      if (option != null) {
        fields[e.attributes['name']!] =
            option.attributes['value'] ?? option.text.trim();
      }
    }
    final src = doc.querySelector('#captchaimg')?.attributes['src'];
    return PortalForm(
      page.resolve(form.attributes['action'] ?? ''),
      fields,
      src == null ? null : page.resolve(src),
    );
  }

  String attendanceSemester(String source, String? currentSemester) {
    bool valid(String? value) =>
        value != null && RegExp(r'^[1-9][0-9]?$').hasMatch(value.trim());
    if (valid(currentSemester)) return currentSemester!.trim();
    final selected = parse(
      source,
    ).querySelector('select[name="sem"] option[selected]');
    final value = selected == null
        ? null
        : (selected.attributes['value'] ?? selected.text).trim();
    if (valid(value)) return value!;
    throw const PortalException(
      'Could not verify the current semester. Please retry attendance refresh.',
    );
  }

  Uri link(String source, Uri page, String label) {
    for (final a in parse(source).querySelectorAll('a[href]')) {
      if (clean(a.text).toLowerCase().replaceAll('.', '') ==
          label.toLowerCase().replaceAll('.', '')) {
        final href = a.attributes['href']!;
        if (href.startsWith('javascript:')) {
          throw const PortalException(
            'This portal link requires a browser flow. Save the page HTML for adapter verification.',
          );
        }
        return page.resolve(href);
      }
    }
    throw PortalException(
      'Could not find "$label". The session may have expired or the portal layout changed.',
    );
  }

  ({String semester, List<Subject> subjects}) courses(String source) {
    final doc = parse(source);
    final sem = RegExp(
      r'Semester\s*:?\s*(\d+)',
      caseSensitive: false,
    ).firstMatch(doc.body?.text ?? '')?.group(1);
    if (sem == null) {
      throw const PortalException('Could not identify the current semester.');
    }
    for (final table in doc.querySelectorAll('table')) {
      final rows = table
          .querySelectorAll('tr')
          .where((r) => closest(r, 'table') == table)
          .toList();
      for (var i = 0; i < rows.length; i++) {
        final headers = rows[i].children
            .where((e) => e.localName == 'td' || e.localName == 'th')
            .map((e) => clean(e.text).toLowerCase())
            .toList();
        final codeIndex = headers.indexWhere((h) => h.contains('code'));
        final nameIndex = headers.indexWhere(
          (h) => h.contains('name') || h.contains('title'),
        );
        if (codeIndex < 0 || nameIndex < 0) continue;
        final subjects = <Subject>[];
        for (final row in rows.skip(i + 1)) {
          final cells = row.children
              .where((e) => e.localName == 'td' || e.localName == 'th')
              .toList();
          if (cells.length <= codeIndex || cells.length <= nameIndex) continue;
          final code = clean(cells[codeIndex].text),
              name = clean(cells[nameIndex].text);
          if (code.isEmpty ||
              name.isEmpty ||
              code.toLowerCase().contains('total')) {
            continue;
          }
          if (subjects.any((s) => s.code == code)) continue;
          subjects.add(
            Subject(
              code,
              name,
              const Counts(0, 0),
              colors[subjects.length % colors.length],
            ),
          );
        }
        if (subjects.isNotEmpty) return (semester: sem, subjects: subjects);
      }
    }
    throw const PortalException(
      'Course table headers were not recognized. No data was imported.',
    );
  }

  ({List<Subject> subjects, List<OfficialDay> days}) attendance(
    String source,
    List<Subject> subjects,
    String academicYear,
  ) {
    final doc = parse(source);

    if (doc.querySelector('frameset') != null &&
        doc.querySelector('table') == null) {
      throw const PortalException(
        'IMS returned its outer frameset instead of the attendance table. '
        'Inspect the attendance POST response, not the parent page source.',
      );
    }
    final days = <OfficialDay>[];

    // Registered courses enrich names/colors only. Attendance headers determine
    // the displayed subjects and each table's column order independently.
    final subjectByCode = <String, Subject>{
      for (final subject in subjects)
        clean(subject.code).toUpperCase(): subject,
    };
    final totals = <String, Map<String, int>>{};
    final overallLabels = <String>{};
    final attendanceCodes = <String>{};

    for (final table in doc.querySelectorAll('table')) {
      final rows = table
          .querySelectorAll('tr')
          .where((row) => closest(row, 'table') == table)
          .toList();

      final localColumns = <int, String>{};
      for (final row in rows) {
        final cells = row.children
            .where((e) => e.localName == 'td' || e.localName == 'th')
            .toList();
        if (cells.isEmpty) continue;
        final label = clean(cells.first.text).toLowerCase();
        if (label != 'days' && label != 'date') continue;

        for (var i = 1; i < cells.length; i++) {
          final code = clean(cells[i].text).toUpperCase();
          if ((cells[i].attributes['colspan'] ?? '1') != '1') {
            throw PortalException(
              'Attendance header column ${i + 1} spans multiple columns. Subject order cannot be read safely.',
            );
          }
          if (code.isEmpty) {
            // Ignore empty spacer columns, but retain their physical index:
            // removing them would move later subjects onto the wrong records.
            final hasRecords = rows.any((candidate) {
              final values = candidate.children
                  .where((e) => e.localName == 'td' || e.localName == 'th')
                  .toList();
              if (values.isEmpty) return false;
              final rowLabel = clean(values.first.text);
              if (parseDate(rowLabel, academicYear) == null &&
                  !rowLabel.toLowerCase().contains('overall') &&
                  !rowLabel.toLowerCase().startsWith('total')) {
                return false;
              }
              return i < values.length && clean(values[i].text).isNotEmpty;
            });

            if (!hasRecords) continue;

            throw PortalException(
              'Attendance column ${i + 1} has records but no subject code in its Days/Date header. Refresh the report; its subject cannot be identified safely.',
            );
          }
          if (localColumns.containsValue(code)) {
            throw PortalException(
              'Subject $code appears twice in the attendance header. Subject order cannot be read safely.',
            );
          }
          localColumns[i] = code;
        }
        break;
      }

      if (localColumns.isEmpty) continue;
      attendanceCodes.addAll(localColumns.values);
      for (final row in rows) {
        final cells = row.children
            .where(
              (element) =>
                  element.localName == 'td' || element.localName == 'th',
            )
            .toList();

        if (cells.length < 2) continue;

        final label = clean(cells.first.text);

        if (label.isEmpty) continue;

        final lower = label.toLowerCase();

        if (lower.contains('overall')) {
          overallLabels.add(label);
          String? type;

          if (lower.contains('present')) {
            type = 'attended';
          } else if (lower.contains('class') || lower.contains('held')) {
            type = 'total';
          } else if (lower.contains('absent')) {
            type = 'absent';
          }

          if (type == null) continue;

          for (final entry in localColumns.entries) {
            final columnIndex = entry.key;
            final subjectCode = entry.value;

            if (columnIndex >= cells.length) {
              throw PortalException(
                'Missing column $columnIndex for $subjectCode '
                'in "$label" row.',
              );
            }

            final raw = clean(cells[columnIndex].text);
            final value = int.tryParse(raw);

            if (value == null || value < 0) {
              throw PortalException(
                'Invalid $type attendance value for '
                '$subjectCode: "$raw"',
              );
            }

            final subjectTotals = totals[subjectCode] ??= {};

            subjectTotals[type] = value;
          }

          continue;
        }

        final date = parseDate(label, academicYear);

        if (date == null) {
          continue;
        }

        for (final entry in localColumns.entries) {
          final columnIndex = entry.key;
          final subjectCode = entry.value;

          if (columnIndex >= cells.length) {
            throw PortalException(
              'Missing attendance column $columnIndex '
              'for $subjectCode on $label.',
            );
          }

          final raw = clean(cells[columnIndex].text);

          days.add(OfficialDay(subjectCode, dateKey(date), raw));
        }
      }
    }

    final orderedSubjects = <Subject>[];

    if (attendanceCodes.isEmpty) {
      throw const PortalException(
        'Could not find subject columns in the attendance page. No attendance was imported.',
      );
    }
    for (final code in attendanceCodes) {
      final original = subjectByCode[code];

      final total = totals[code];

      if (total == null ||
          total['attended'] == null ||
          total['total'] == null) {
        final missing = [
          if (total?['attended'] == null) 'present count',
          if (total?['total'] == null) 'held-class count',
        ].join(' and ');
        final labels = overallLabels.isEmpty
            ? 'none'
            : overallLabels
                  .take(8)
                  .map(
                    (label) => label.length > 100
                        ? '${label.substring(0, 100)}...'
                        : label,
                  )
                  .join(' | ');
        throw PortalException(
          'Missing $missing for $code. '
          'Overall row labels found: $labels. '
          'No attendance was imported.',
        );
      }

      final attended = total['attended']!;
      final totalClasses = total['total']!;

      if (attended > totalClasses) {
        throw PortalException(
          'Attendance inconsistency for $code: '
          '$attended/$totalClasses.',
        );
      }

      orderedSubjects.add(
        Subject(
          code,
          original?.name ?? code,
          Counts(attended, totalClasses),
          original?.color ?? colors[orderedSubjects.length % colors.length],
        ),
      );
    }

    final unique = <String, OfficialDay>{};

    for (final day in days) {
      final key = '${day.subject}:${day.date}';

      if (unique.containsKey(key) && unique[key]!.raw != day.raw) {
        throw const PortalException(
          'Ambiguous duplicate daily attendance. Import stopped.',
        );
      }

      unique[key] = day;
    }

    return (subjects: orderedSubjects, days: unique.values.toList());
  }

  DateTime? parseDate(String text, String academicYear) {
    final iso = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(text);
    if (iso != null) {
      return validDate(
        int.parse(iso[1]!),
        int.parse(iso[2]!),
        int.parse(iso[3]!),
      );
    }
    final match = RegExp(
      r'^([A-Za-z]{3})-(\d{1,2})(?:-(\d{4}))?$',
    ).firstMatch(text);
    if (match == null) return null;
    const months = [
      'jan',
      'feb',
      'mar',
      'apr',
      'may',
      'jun',
      'jul',
      'aug',
      'sep',
      'oct',
      'nov',
      'dec',
    ];
    final month = months.indexOf(match[1]!.toLowerCase()) + 1;
    final years = RegExp(r'^(\d{4})-(\d{2}|\d{4})$').firstMatch(academicYear);
    if (month == 0 || years == null) {
      throw const PortalException('Attendance date context is missing.');
    }
    final start = int.parse(years[1]!);
    final end = years[2]!.length == 2
        ? (start ~/ 100) * 100 + int.parse(years[2]!)
        : int.parse(years[2]!);
    // NSUT academic-year mapping is an adapter assumption; verify against real HTML.
    return validDate(
      match[3] == null ? (month >= 7 ? start : end) : int.parse(match[3]!),
      month,
      int.parse(match[2]!),
    );
  }

  DateTime validDate(int y, int m, int d) {
    final date = DateTime(y, m, d);
    if (date.year != y || date.month != m || date.day != d) {
      throw const PortalException('Invalid attendance date from portal.');
    }
    return date;
  }
}
