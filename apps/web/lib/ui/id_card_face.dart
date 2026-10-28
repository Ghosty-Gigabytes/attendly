import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../domain/student_id.dart';

/// A fixed 800 × 504 card canvas scales uniformly on phones and tablets.
class IdCardFace extends StatelessWidget {
  final StudentIdData student;
  final bool back;
  const IdCardFace({super.key, required this.student, this.back = false});
  static const ink = Color(0xFF111111);
  String value(String text) => text.trim().isEmpty ? '—' : text.trim();
  Widget text(
    String content, {
    double size = 20,
    bool bold = true,
    int lines = 1,
    TextAlign align = TextAlign.left,
  }) => LayoutBuilder(
    builder: (context, constraints) {
      TextStyle style(double fontSize) => TextStyle(
        color: ink,
        fontFamily: 'Roboto',
        fontSize: fontSize,
        fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
        height: 1.05,
      );
      var fontSize = size;
      while (fontSize > 8) {
        final painter = TextPainter(
          text: TextSpan(text: content, style: style(fontSize)),
          textDirection: TextDirection.ltr,
          maxLines: lines,
        )..layout(maxWidth: constraints.maxWidth);
        final fits =
            !painter.didExceedMaxLines &&
            painter.height <= constraints.maxHeight;
        painter.dispose();
        if (fits) break;
        fontSize -= .5;
      }
      return Align(
        alignment: align == TextAlign.center
            ? Alignment.center
            : Alignment.centerLeft,
        child: Text(
          content,
          maxLines: lines,
          textAlign: align,
          textScaler: TextScaler.noScaling,
          style: style(fontSize),
        ),
      );
    },
  );
  Widget image(Uint8List? bytes, String label) => bytes == null
      ? Center(
          child: Text(
            '$label unavailable',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.black54, fontSize: 14),
          ),
        )
      : Image.memory(
          bytes,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => Center(
            child: Text(
              '$label unavailable',
              style: const TextStyle(color: Colors.black54, fontSize: 14),
            ),
          ),
        );
  Widget at(double x, double y, double w, double h, Widget child) =>
      Positioned(left: x, top: y, width: w, height: h, child: child);
  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.contain,
    child: Container(
      width: 800,
      height: 504,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFD9D9D9)),
      ),
      child: DefaultTextStyle(
        style: const TextStyle(color: ink, fontFamily: 'Roboto'),
        child: Stack(children: back ? _back() : _front()),
      ),
    ),
  );
  Widget signature() => ColoredBox(
    color: Colors.white,
    child: ColorFiltered(
      // Keep dark handwriting; lift the pale scanned paper to pure white.
      colorFilter: const ColorFilter.matrix([
        1.276,
        2.504,
        .488,
        0,
        -510,
        1.276,
        2.504,
        .488,
        0,
        -510,
        1.276,
        2.504,
        .488,
        0,
        -510,
        0,
        0,
        0,
        1,
        0,
      ]),
      child: image(student.signature, 'Signature'),
    ),
  );
  List<Widget> _front() => [
    at(26, 20, 110, 110, image(student.logo, 'Logo')),
    at(
      151,
      22,
      623,
      36,
      text(
        'Netaji Subhas University of Technology',
        size: 29,
        align: TextAlign.center,
      ),
    ),
    at(
      151,
      61,
      623,
      19,
      text(
        'A State University Under Act 06 of 2018 Govt. of NCT of Delhi',
        size: 16,
        align: TextAlign.center,
      ),
    ),
    at(
      151,
      82,
      623,
      19,
      text(
        '(Formerly, Netaji Subhas Institute of Technology)',
        size: 16,
        align: TextAlign.center,
      ),
    ),
    at(
      151,
      103,
      623,
      19,
      text(
        'Sector 3, Dwarka, New Delhi - 110078',
        size: 16,
        align: TextAlign.center,
      ),
    ),
    if (student.branch.toUpperCase().contains('EAST'))
      at(
        151,
        124,
        623,
        23,
        text('EAST CAMPUS', size: 20, align: TextAlign.center),
      ),
    at(
      26,
      159,
      174,
      214,
      Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(border: Border.all(color: ink, width: 2)),
        child: image(student.photo, 'Photo'),
      ),
    ),
    at(220, 157, 554, 29, text('NAME : ${value(student.name)}', size: 23)),
    at(220, 191, 322, 29, text('COURSE : ${value(student.course)}', size: 22)),
    at(549, 191, 225, 29, text('BATCH : ${value(student.batch)}', size: 22)),
    at(
      220,
      225,
      554,
      29,
      text('PARENT NAME : ${value(student.parentName)}', size: 22),
    ),
    at(
      220,
      259,
      554,
      29,
      text('ROLL NUMBER : ${value(student.rollNumber)}', size: 23),
    ),
    at(
      220,
      293,
      554,
      48,
      text('BRANCH : ${value(student.branch)}', size: 21, lines: 2),
    ),
    at(
      220,
      347,
      322,
      29,
      text('MOBILE NO.: ${value(student.mobile)}', size: 21),
    ),
    at(550, 347, 224, 29, text('D.O.B : ${value(student.dob)}', size: 21)),
    // The entire bottom band is reserved for the signature, not body text.
    at(26, 406, 174, 44, signature()),
    at(
      26,
      458,
      174,
      23,
      text('STUDENT SIGN.', size: 18, align: TextAlign.center),
    ),
  ];
  List<Widget> _back() => [
    at(34, 25, 732, 27, text('COMMUNICATION ADDRESS:', size: 23)),
    at(
      34,
      57,
      732,
      73,
      text(value(student.address).toUpperCase(), size: 22, lines: 3),
    ),
    at(
      34,
      143,
      435,
      28,
      text('YEAR OF ADMISSION: ${value(student.admissionYear)}', size: 21),
    ),
    at(
      505,
      143,
      261,
      28,
      text('BLOOD GROUP: ${value(student.bloodGroup)}', size: 21),
    ),
    at(34, 176, 732, 28, text('EMAIL ID: ${value(student.email)}', size: 21)),
    at(
      34,
      209,
      732,
      28,
      text('MOBILE NO.: ${value(student.mobile)}', size: 21),
    ),
    at(34, 251, 732, 23, text('Instructions:', size: 18)),
    at(
      34,
      280,
      732,
      107,
      text(
        '1. The Holder of this card is required to keep it with him/her while attending the NSUT or visiting public places.\n2. The loss or finding of this Identity Card should be reported immediately to the Academic Section NSUT.\n3. Impersonation using this Card is a serious offence.',
        size: 17,
        bold: false,
        lines: 6,
      ),
    ),
    // y=404..504 deliberately remains blank for the barcode area.
  ];
}
