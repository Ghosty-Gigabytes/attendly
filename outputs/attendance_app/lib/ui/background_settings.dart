import 'package:flutter/material.dart';
import '../data/platform_service.dart';
import 'shared.dart';

class BackgroundSettings extends StatefulWidget {
  const BackgroundSettings({super.key});
  @override
  State<BackgroundSettings> createState() => _BackgroundSettingsState();
}

class _BackgroundSettingsState extends State<BackgroundSettings>
    with WidgetsBindingObserver {
  final service = PlatformService();
  Map<String, dynamic> values = {};
  String? error;
  bool changing = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) load();
  }

  Future<void> load([Map<String, bool>? changes]) async {
    if (changing) return;
    setState(() => changing = true);
    try {
      final next = await service.settings(changes);
      if (mounted) {
        setState(() {
          values = next;
          error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Background features are available on Android.');
      }
    } finally {
      if (mounted) setState(() => changing = false);
    }
  }

  @override
  Widget build(BuildContext context) => Surface(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Background updates & widgets',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        SizedBox(height: 8),
        Text(
          'When enabled, Attendly uses your saved IMS login to check attendance while the app is closed. Checks run about hourly with internet and sufficient battery; Android may delay them. You can turn this off at any time.',
          style: TextStyle(color: tone(context, muted), fontSize: 12),
        ),
        for (final item in {
          'background': 'Background attendance refresh',
          'low': 'Low attendance alerts',
          'updates': 'Official record update alerts',
          'discrepancies': 'Alert me when IMS and my logs differ',
        }.entries)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(item.value),
            value: values[item.key] == true,
            onChanged: changing || values.isEmpty
                ? null
                : (v) async {
                    if (item.key == 'background' && v) {
                      final enable = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Enable background refresh?'),
                          content: const Text(
                            'Attendly will use your saved student ID and password to sign in directly to IMS and fetch attendance while the app is closed. CAPTCHA recognition happens on your device. Android may delay updates. You can turn this off in Settings.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Not now'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Enable'),
                            ),
                          ],
                        ),
                      );
                      if (enable != true || !mounted) return;
                    }
                    await load({item.key: v});
                  },
          ),
        Text(
          'Notifications: ${values['permission'] == true ? 'allowed' : 'not allowed'}',
          style: TextStyle(color: tone(context, muted)),
        ),
        Text(
          'Last background attempt: ${values['lastAttempt'] ?? 'Not run yet'}',
          style: TextStyle(color: tone(context, muted), fontSize: 12),
        ),
        if (error != null)
          Text(error!, style: TextStyle(color: tone(context, amber))),
        Wrap(
          spacing: 8,
          children: [
            TextButton(
              onPressed: () => safely(context, () async {
                await service.requestNotifications();
                await load();
              }),
              child: Text('Allow notifications'),
            ),
            TextButton(
              onPressed: () => safely(context, () async {
                final pinned = await service.pinWidget();
                if (!pinned && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Long-press your home screen, choose Widgets, then Attendly.',
                      ),
                    ),
                  );
                }
              }),
              child: Text('Add home-screen widget'),
            ),
          ],
        ),
      ],
    ),
  );
}
