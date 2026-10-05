import 'dart:io';
import 'package:attendly/data/portal_service.dart';

Future<void> main() async {
  final portal = PortalService();
  try {
    final challenge = await portal.challenge();
    final jpg =
        challenge.image.length > 2 &&
        challenge.image[0] == 0xff &&
        challenge.image[1] == 0xd8;
    stdout.writeln(
      'IMS challenge fetched: ${challenge.image.length} bytes; JPEG=$jpg; token present=${challenge.form.fields['HRAND_NUM']?.isNotEmpty == true}',
    );
  } finally {
    portal.dio.close();
  }
}
