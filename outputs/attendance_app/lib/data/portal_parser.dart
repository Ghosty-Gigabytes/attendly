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

  // ({List<Subject> subjects, List<OfficialDay> days}) attendance(
  //   String source,
  //   List<Subject> subjects,
  //   String academicYear,
  // ) {
  //   final doc = parse(source), days = <OfficialDay>[];
  //   final totals = <String, Map<String, int>>{};
  //   for (final table in doc.querySelectorAll('table')) {
  //     final rows = table
  //         .querySelectorAll('tr')
  //         .where((r) => closest(r, 'table') == table);
  //     final columns = <int, String>{};
  //     for (final row in rows) {
  //       final cells = row.children
  //           .where((e) => e.localName == 'td' || e.localName == 'th')
  //           .toList();
  //       if (cells.length < 2) continue;
  //       for (var i = 1; i < cells.length; i++) {
  //         final text = clean(cells[i].text).toUpperCase();
  //         for (final subject in subjects) {
  //           if (RegExp(
  //             '(^|[^A-Z0-9])${RegExp.escape(subject.code.toUpperCase())}([^A-Z0-9]|\$)',
  //           ).hasMatch(text)) {
  //             columns[i] = subject.code;
  //           }
  //         }
  //       }
  //       if (columns.isEmpty) continue;
  //       final label = clean(cells.first.text);
  //       final date = parseDate(label, academicYear);
  //       for (final entry in columns.entries) {
  //         if (entry.key >= cells.length) {
  //           throw const PortalException(
  //             'An attendance row has missing subject columns. Import stopped.',
  //           );
  //         }
  //         final raw = clean(cells[entry.key].text);
  //         if (date != null) {
  //           days.add(OfficialDay(entry.value, dateKey(date), raw));
  //         }
  //         final lower = label.toLowerCase();
  //         if (lower.contains('overall')) {
  //           final key = lower.contains('present')
  //               ? 'a'
  //               : lower.contains('classes') || lower.contains('held')
  //               ? 't'
  //               : null;
  //           if (key != null) {
  //             final value = int.tryParse(raw);
  //             if (value == null || value < 0) {
  //               throw const PortalException(
  //                 'A subject total is not a valid count. Import stopped.',
  //               );
  //             }
  //             (totals[entry.value] ??= {})[key] = value;
  //           }
  //         }
  //       }
  //     }
  //   }
  //   final updated = subjects.map((s) {
  //     final total = totals[s.code];
  //     if (total?['a'] == null ||
  //         total?['t'] == null ||
  //         total!['a']! > total['t']!) {
  //       throw PortalException(
  //         'Verified totals for ${s.code} were not found. The attendance HTML needs adapter verification.',
  //       );
  //     }
  //     return Subject(s.code, s.name, Counts(total['a']!, total['t']!), s.color);
  //   }).toList();
  //   final unique = <String, OfficialDay>{};
  //   for (final day in days) {
  //     final key = '${day.subject}:${day.date}';
  //     if (unique.containsKey(key) && unique[key]!.raw != day.raw) {
  //       throw const PortalException(
  //         'Ambiguous duplicate daily attendance. Import stopped.',
  //       );
  //     }
  //     unique[key] = day;
  //   }
  //   return (subjects: updated, days: unique.values.toList());
  // }
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

    if (subjects.isEmpty) {
      throw const PortalException(
        'No subjects were found. Attendance import stopped.',
      );
    }

    final subjectByCode = <String, Subject>{
      for (final subject in subjects) subject.code.toUpperCase(): subject,
    };

    final totals = <String, Map<String, int>>{};
    final overallLabels = <String>{};

    // The attendance page tells us the REAL column order.
    //
    // Example:
    //
    // Days | DNCP0503 | EAEPC501 | EAEPC502 | ...
    //
    // We must use this instead of the order returned by
    // the Current Sem Courses page.
    final attendanceColumnMap = <int, String>{};

    // ------------------------------------------------------------
    // 1. Find the attendance table header
    // ------------------------------------------------------------

    for (final table in doc.querySelectorAll('table')) {
      final rows = table
          .querySelectorAll('tr')
          .where((row) => closest(row, 'table') == table)
          .toList();

      for (final row in rows) {
        final cells = row.children
            .where(
              (element) =>
                  element.localName == 'td' || element.localName == 'th',
            )
            .toList();

        if (cells.length < 2) continue;

        final first = clean(cells.first.text).toLowerCase();

        if (first != 'days' && first != 'date') continue;

        final mapping = <int, String>{};

        for (var i = 1; i < cells.length; i++) {
          final code = clean(cells[i].text).toUpperCase();

          if (subjectByCode.containsKey(code)) {
            mapping[i] = code;
          }
        }

        if (mapping.length == subjects.length) {
          attendanceColumnMap
            ..clear()
            ..addAll(mapping);
          break;
        }
      }

      if (attendanceColumnMap.isNotEmpty) {
        break;
      }
    }

    if (attendanceColumnMap.length != subjects.length) {
      throw PortalException(
        'Could not determine attendance subject column order. '
        'Expected ${subjects.length} subjects, found '
        '${attendanceColumnMap.length}.',
      );
    }

    // ------------------------------------------------------------
    // Debug: show the order obtained from the attendance HTML
    // ------------------------------------------------------------

    final sortedColumns = attendanceColumnMap.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    // ------------------------------------------------------------
    // 2. Parse all tables
    // ------------------------------------------------------------

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
          if (subjectByCode.containsKey(code)) localColumns[i] = code;
        }
        break;
      }
      if (localColumns.isEmpty) continue;
      if (localColumns.values.toSet().length != subjects.length) {
        throw const PortalException(
          'Incomplete subject header in an attendance table. No data imported.',
        );
      }
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

        // ----------------------------------------------------------
        // 3. Overall totals
        // ----------------------------------------------------------

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

        // ----------------------------------------------------------
        // 4. Daily attendance
        // ----------------------------------------------------------

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

    // ------------------------------------------------------------
    // 5. Build subjects in ATTENDANCE HTML order
    // ------------------------------------------------------------

    final orderedSubjects = <Subject>[];

    for (final entry in sortedColumns) {
      final code = entry.value;
      final original = subjectByCode[code];

      if (original == null) {
        throw PortalException('Attendance contains unknown subject $code.');
      }

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
          original.code,
          original.name,
          Counts(attended, totalClasses),
          original.color,
        ),
      );
    }

    // ------------------------------------------------------------
    // 6. Remove duplicate daily entries
    // ------------------------------------------------------------

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
