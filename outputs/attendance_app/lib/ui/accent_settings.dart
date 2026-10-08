import 'package:flutter/material.dart';
import '../data/controller.dart';
import 'shared.dart';

class AccentSettings extends StatelessWidget {
  final AppController controller;
  const AccentSettings(this.controller, {super.key});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Accent color', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          ChoiceChip(
            label: const Text('System color'),
            avatar: const Icon(Icons.wallpaper_rounded, size: 18),
            selected: controller.materialAccent == 'system',
            onSelected: (_) =>
                safely(context, () => controller.setMaterialAccent('system')),
          ),
          for (final color in const [
            ('Blue', '2463BC'),
            ('Green', '287D58'),
            ('Purple', '7856A6'),
            ('Rose', 'B24C72'),
            ('Orange', 'A85A18'),
            ('Teal', '007F86'),
          ])
            ChoiceChip(
              label: Text(color.$1),
              avatar: CircleAvatar(
                backgroundColor: Color(
                  0xFF000000 | int.parse(color.$2, radix: 16),
                ),
                radius: 8,
              ),
              selected: controller.materialAccent == color.$2,
              onSelected: (_) =>
                  safely(context, () => controller.setMaterialAccent(color.$2)),
            ),
          ActionChip(
            label: const Text('Custom color'),
            avatar: const Icon(Icons.colorize_rounded, size: 18),
            onPressed: () async {
              final result = await showDialog<String>(
                context: context,
                builder: (_) => _CustomAccent(initial: controller.materialSeed),
              );
              if (result != null && context.mounted) {
                await safely(
                  context,
                  () => controller.setMaterialAccent(result),
                );
              }
            },
          ),
        ],
      ),
      const SizedBox(height: 8),
      Text(
        controller.materialAccent == 'system'
            ? controller.systemAccent == null
                  ? 'System colors need Android 12 or newer. Using blue on this device.'
                  : 'Uses your Android system accent. Updates when you return to the app.'
            : 'Accent #${controller.materialAccent} · Applies to Material light and dark.',
        style: TextStyle(fontSize: 12, color: tone(context, muted)),
      ),
    ],
  );
}

class _CustomAccent extends StatefulWidget {
  final int initial;
  const _CustomAccent({required this.initial});
  @override
  State<_CustomAccent> createState() => _CustomAccentState();
}

class _CustomAccentState extends State<_CustomAccent> {
  late final input = TextEditingController(
    text: (widget.initial & 0xFFFFFF)
        .toRadixString(16)
        .padLeft(6, '0')
        .toUpperCase(),
  );
  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final raw = input.text.replaceFirst('#', '').trim();
    final valid = RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(raw);
    return AlertDialog(
      title: const Text('Custom accent'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: input,
            autofocus: true,
            maxLength: 7,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Hex color',
              hintText: '2463BC',
              errorText: valid ? null : 'Enter 6 hexadecimal digits',
            ),
          ),
          if (valid)
            Container(
              height: 48,
              decoration: BoxDecoration(
                color: Color(0xFF000000 | int.parse(raw, radix: 16)),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: valid ? () => Navigator.pop(context, raw) : null,
          child: const Text('Apply'),
        ),
      ],
    );
  }
}
