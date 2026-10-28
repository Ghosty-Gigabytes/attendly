import 'package:flutter/material.dart';
import 'material_design.dart';
import 'package:intl/intl.dart';
import '../domain/models.dart';
export '../domain/display_dates.dart' show longDate;

const ink = Color(0xFF182D2A),
    muted = Color(0xFF71807B),
    green = Color(0xFF237962),
    paper = Color(0xFFF5F7F3),
    line = Color(0xFFE3E9E3),
    amber = Color(0xFFAC6722),
    red = Color(0xFFB94D42),
    offDay = Color(0xFF3974B8);
String percentage(Counts c) =>
    c.percent == null ? '—' : '${c.percent!.toStringAsFixed(1)}%';
String shortDate(DateTime d) => DateFormat('d-MMM', 'en_US').format(d);

bool isMaterialDesign(BuildContext context) =>
    Theme.of(context).extension<MaterialDesign>() != null;

Color tone(BuildContext context, Color color) {
  final theme = Theme.of(context);
  if (isMaterialDesign(context)) {
    final dark = theme.brightness == Brightness.dark;
    if (color == ink) return theme.colorScheme.onSurface;
    if (color == muted) return theme.colorScheme.onSurfaceVariant;
    if (color == paper) return theme.colorScheme.surfaceContainerHighest;
    if (color == line) return theme.colorScheme.outlineVariant;
    if (color == green) return Color(dark ? 0xFF91D5A5 : 0xFF216C3D);
    if (color == amber) return Color(dark ? 0xFFF1C16B : 0xFF805600);
    if (color == red) return theme.colorScheme.error;
    if (color == offDay) return theme.colorScheme.primary;
  }
  if (Theme.of(context).brightness != Brightness.dark) return color;
  if (color == ink) return const Color(0xFFE7E8EA);
  if (color == muted) return const Color(0xFFADB0B6);
  if (color == paper) return const Color(0xFF0D0E10);
  if (color == line) return const Color(0xFF34373D);
  if (color == green) return const Color(0xFF83D3B8);
  if (color == amber) return const Color(0xFFE8B77A);
  if (color == red) return const Color(0xFFFFA69A);
  if (color == offDay) return const Color(0xFF9BC5F3);
  return color;
}

class Surface extends StatelessWidget {
  final Widget child;
  final Color? color;
  final EdgeInsets padding;
  const Surface({
    super.key,
    required this.child,
    this.color,
    this.padding = const EdgeInsets.all(20),
  });
  @override
  Widget build(BuildContext context) => Material(
    color:
        color ??
        (isMaterialDesign(context)
            ? Theme.of(context).colorScheme.surfaceContainerLow
            : Theme.of(context).colorScheme.surface),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(24),
      side: isMaterialDesign(context)
          ? BorderSide.none
          : BorderSide(color: tone(context, line), width: 1),
    ),
    child: Padding(padding: padding, child: child),
  );
}

class Tag extends StatelessWidget {
  final String text;
  final Color color;
  const Tag(this.text, {super.key, this.color = green});
  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: tone(context, color).withValues(alpha: .09),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      text,
      style: TextStyle(
        color: tone(context, color),
        fontSize: 11,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class Heading extends StatelessWidget {
  final String eyebrow, title, subtitle;
  const Heading(this.eyebrow, this.title, this.subtitle, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!isMaterialDesign(context))
          Text(
            eyebrow.toUpperCase(),
            style: TextStyle(
              color: tone(context, green),
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
            ),
          ),
        SizedBox(height: 8),
        Text(title, style: Theme.of(context).textTheme.headlineLarge),
        SizedBox(height: 8),
        Text(
          subtitle,
          style: TextStyle(color: tone(context, muted), height: 1.5),
        ),
      ],
    ),
  );
}

class Empty extends StatelessWidget {
  final String title, body;
  const Empty(this.title, this.body, {super.key});
  @override
  Widget build(BuildContext context) => Surface(
    child: Column(
      children: [
        Icon(Icons.event_note_rounded, size: 38, color: tone(context, muted)),
        SizedBox(height: 12),
        Text(title, style: TextStyle(fontWeight: FontWeight.w700)),
        SizedBox(height: 8),
        Text(
          body,
          textAlign: TextAlign.center,
          style: TextStyle(color: tone(context, muted)),
        ),
      ],
    ),
  );
}

Future<void> safely(
  BuildContext context,
  Future<void> Function() action,
) async {
  try {
    await action();
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

Future<String?> askText(
  BuildContext context,
  String title, {
  String initial = '',
  String hint = '',
}) async {
  final input = TextEditingController(text: initial);
  final result = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: input,
        autofocus: true,
        decoration: InputDecoration(hintText: hint),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (input.text.trim().isNotEmpty) {
              Navigator.pop(context, input.text.trim());
            }
          },
          child: Text('Save'),
        ),
      ],
    ),
  );
  // Route disposal is asynchronous; the controller belongs to this short-lived dialog.
  return result;
}
