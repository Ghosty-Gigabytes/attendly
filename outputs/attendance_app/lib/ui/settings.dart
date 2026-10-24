import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/controller.dart';

import '../domain/export.dart';
import 'shared.dart';
import 'timetable_editor.dart';
import 'background_settings.dart';
import 'accent_settings.dart';
import 'app_information.dart';

class SettingsScreen extends StatelessWidget {
  final AppController controller;
  const SettingsScreen(this.controller, {super.key});
  @override
  Widget build(BuildContext context) {
    final data = controller.data;
    return ListView(
      padding: EdgeInsets.all(24),
      children: [
        Heading(
          'Make it yours',
          isMaterialDesign(context)
              ? 'Settings'
              : 'A calmer semester starts here.',
          'Manage your portal connection, timetable, and personal preferences.',
        ),
        Surface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.school_outlined, color: tone(context, green)),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'University account',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: isMaterialDesign(context)
                            ? FontWeight.w500
                            : FontWeight.w700,
                      ),
                    ),
                  ),
                  Tag(
                    controller.hasLiveSession
                        ? 'IMS CONNECTED'
                        : 'SAVED RECORDS',
                  ),
                ],
              ),
              SizedBox(height: 14),
              Text(
                data.account,
                style: TextStyle(color: tone(context, muted), height: 1.5),
              ),
              SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton.icon(
                    onPressed: controller.refreshing
                        ? null
                        : () => safely(context, controller.sync),
                    icon: Icon(Icons.sync, size: 18),
                    label: Text(
                      controller.refreshing ? 'Refreshing…' : 'Refresh records',
                    ),
                  ),
                  TextButton.icon(
                    onPressed: controller.refreshing
                        ? null
                        : () => safely(context, controller.logout),
                    icon: Icon(Icons.logout, size: 18),
                    label: Text('Sign out of IMS'),
                  ),
                ],
              ),
              SizedBox(height: 12),
              Text(
                'Your login is saved securely on this device. Saved attendance stays available offline. You can enable background updates below. Signing out removes your saved login but keeps your records.',
                style: TextStyle(
                  color: tone(context, muted),
                  fontSize: 11,
                  height: 1.5,
                ),
              ),
              if (controller.error != null)
                Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text(
                    controller.error!,
                    style: TextStyle(color: tone(context, red), fontSize: 12),
                  ),
                ),
            ],
          ),
        ),
        SizedBox(height: 20),
        Text('Time format', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: '12', label: Text('12 hour · 2:00 PM')),
            ButtonSegment(value: '24', label: Text('24 hour · 14:00')),
          ],
          selected: {controller.timeFormat},
          onSelectionChanged: (v) =>
              safely(context, () => controller.setTimeFormat(v.first)),
        ),
        const SizedBox(height: 20),
        BackgroundSettings(),
        SizedBox(height: 20),
        Text(
          'Appearance',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        SizedBox(height: 12),
        Text('Design', style: TextStyle(color: tone(context, muted))),
        SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final option in const [
              ('classic', 'Classic', Icons.contrast),
              ('bauhaus', 'Bauhaus', Icons.palette_outlined),
              ('material', 'Material', Icons.auto_awesome_mosaic_outlined),
            ])
              ChoiceChip(
                label: Text(option.$2),
                avatar: Icon(option.$3, size: 18),
                selected: controller.palettePreference == option.$1,
                onSelected: (_) =>
                    safely(context, () => controller.setPalette(option.$1)),
              ),
          ],
        ),
        SizedBox(height: 16),
        if (controller.palettePreference == 'material') ...[
          AccentSettings(controller),
          SizedBox(height: 20),
        ],
        Text('Brightness', style: TextStyle(color: tone(context, muted))),
        SizedBox(height: 8),
        SegmentedButton<String>(
          showSelectedIcon: false,
          style: ButtonStyle(
            visualDensity: VisualDensity.compact,
            textStyle: WidgetStatePropertyAll(TextStyle(fontSize: 12)),
          ),
          segments: [
            ButtonSegment(value: 'dark', label: Text('Dark')),
            ButtonSegment(value: 'light', label: Text('Light')),
            ButtonSegment(value: 'system', label: Text('System default')),
          ],
          selected: {controller.themePreference},
          onSelectionChanged: (values) =>
              safely(context, () => controller.setTheme(values.first)),
        ),
        SizedBox(height: 20),
        Card(
          child: ListTile(
            leading: const Icon(Icons.calendar_view_week_outlined),
            title: const Text('Weekly timetable'),
            subtitle: const Text(
              'Build a week, paste CSV, or convert a photo with AI',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => openTimetable(context, controller),
          ),
        ),
        SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: () async {
            await Clipboard.setData(
              ClipboardData(
                text: exportCsv(data, use24Hour: controller.use24Hour),
              ),
            );
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'CSV copied. Official and personal rows are labelled separately.',
                  ),
                ),
              );
            }
          },
          icon: Icon(Icons.file_copy_outlined, size: 18),
          label: Text('Copy attendance as CSV'),
        ),
        SizedBox(height: 20),
        const AppInformation(),
        SizedBox(height: 20),
        ListTile(
          leading: Icon(
            Icons.delete_outline,
            color: Theme.of(context).colorScheme.error,
          ),
          title: const Text('Delete local data'),
          subtitle: const Text(
            'Remove saved records, login, and preferences from this device',
          ),
          onTap: controller.deletingLocalData
              ? null
              : () => confirmDeleteLocalData(context, controller),
        ),
      ],
    );
  }
}
