import 'package:html/dom.dart';
import 'package:html/parser.dart' as html;
import '../domain/student_id.dart';
import 'portal_parser.dart';

String _clean(String text) => text.replaceAll(RegExp(r'\s+'), ' ').trim();
String _key(String text) =>
    _clean(text).toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

class IdCardDetails {
  final StudentIdData student;
  final Uri? photo, signature;
  const IdCardDetails(this.student, this.photo, this.signature);
}

class IdCardParser {
  Uri? link(String source, Uri page, List<String> labels) {
    final keys = labels.map(_key).toSet();
    for (final a in html.parse(source).querySelectorAll('a')) {
      if (!keys.contains(_key(a.text))) continue;
      final href = a.attributes['href']?.trim();
      if (href != null &&
          href.isNotEmpty &&
          href != '#' &&
          !href.toLowerCase().startsWith('javascript:')) {
        return page.resolve(href);
      }
    }
    return null;
  }

  Uri? logo(String source, Uri page) {
    for (final row in html.parse(source).querySelectorAll('tr')) {
      if (!row.text.toUpperCase().contains(
        'NETAJI SUBHAS UNIVERSITY OF TECHNOLOGY',
      )) {
        continue;
      }
      for (final img in row.querySelectorAll('img[src]')) {
        if (img.attributes['width'] == '100' &&
            img.attributes['height'] == '100') {
          return page.resolve(img.attributes['src']!);
        }
      }
    }
    return null;
  }

  IdCardDetails parse(String source, Uri page, String account) {
    final doc = html.parse(source);
    final fields = <String, String>{};
    final address = <String>[];
    bool addressContinuation = false;
    Element? portrait, signature;
    String roll = '';
    for (final row in doc.querySelectorAll('tr')) {
      final cells = row.children
          .where((e) => e.localName == 'td' || e.localName == 'th')
          .toList();
      if (cells.length < 2) continue;
      final label = _key(cells.first.text);
      final value = _clean(cells[1].text).replaceFirst(RegExp(r'^:\s*'), '');
      if (label.isNotEmpty) fields[label] = value;
      for (final cell in cells) {
        final match = RegExp(
          r'ID\s*No\s*:\s*([A-Za-z0-9-]+)',
          caseSensitive: false,
        ).firstMatch(cell.text);
        if (match != null) roll = match[1]!;
      }
      if (label == 'permanentaddress' || label == 'communicationaddress') {
        address.add(value);
        addressContinuation = true;
        signature = cells[1].querySelector('img[height="30"][src]');
      } else if (addressContinuation && label.isEmpty) {
        if (value.isNotEmpty) address.add(value);
      } else {
        addressContinuation = false;
      }
      if (label == 'fathersname') {
        for (final cell in cells.skip(2)) {
          portrait ??= cell.querySelector('img[src]');
        }
      }
    }
    if (roll.isEmpty ||
        fields['name']?.isNotEmpty != true ||
        fields['program']?.isNotEmpty != true) {
      throw const PortalException(
        'IMS did not return the ID Card Details page. Your saved card has not changed.',
      );
    }
    if (roll.toUpperCase() != account.trim().toUpperCase()) {
      throw const PortalException(
        'The ID card belongs to a different account. Please sign in again.',
      );
    }
    final phone = (fields['phno'] ?? '')
        .replaceAll(RegExp(r'\s*\([MR]\)', caseSensitive: false), '')
        .trim();
    return IdCardDetails(
      StudentIdData(
        name: fields['name']!,
        rollNumber: roll,
        course: fields['program']!,
        parentName: fields['fathersname'] ?? '',
        branch: fields['department'] ?? '',
        mobile: phone,
        address: address.join(', '),
        dob: fields['dob'] ?? '',
        issueDate: fields['dateofissue'] ?? '',
        bloodGroup: fields['bloodgroup'] ?? '',
        email: fields['email'] ?? '',
        fetchedAt: DateTime.now(),
      ),
      portrait == null ? null : page.resolve(portrait.attributes['src']!),
      signature == null ? null : page.resolve(signature.attributes['src']!),
    );
  }
}
