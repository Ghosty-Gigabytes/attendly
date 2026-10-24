import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/controller.dart';
import '../data/platform_service.dart';

/// Available before sign-in as well as in Settings. No network access is needed.
void showPrivacyNotice(
  BuildContext context,
) => _showInformation(context, 'Privacy notice', const [
  (
    'About Attendly',
    'Attendly is an independent attendance app, not an official university service. This notice describes the data handling in this version.',
  ),
  (
    'Your IMS login',
    'Your student ID and password are sent directly to IMS over HTTPS to sign in. On Android, your saved login is encrypted using a key protected by Android Keystore. Attendly reuses it for automatic sign-in. Session cookies are held in memory. CAPTCHA images are read on your device; temporary image files are deleted after recognition.',
  ),
  (
    'Attendance and personal records',
    'Official attendance, your personal logs and notes, timetable, saved plans, and preferences are stored in the app’s private storage on this device. The attendance database does not have separate database encryption. This version has no developer-operated cloud backup, advertising, analytics, or automatic crash-reporting service.',
  ),
  (
    'Virtual ID card',
    'Opening ID Card fetches your identity details, photo, student signature and university logo directly from IMS. A copy is kept in private app storage for offline viewing, separately for each account. It is not sent to widgets or notifications. Signing out hides the card; Delete local data erases all saved cards and images. The card is an independent digital view, not a university-issued credential.',
  ),
  (
    'Refreshing attendance',
    'Opening the app can refresh saved attendance through IMS. Background refresh is optional: enable it in Settings to allow saved-login access while the app is closed. Android controls when background work runs. You can also refresh from the home-screen widget.',
  ),
  (
    'Widgets and notifications',
    'Widgets display attendance on your home screen. If you allow notifications, Attendly can show low attendance, official updates, and differences from your logs. Other people who can see your screen may see this information. Manage alerts in Settings and notification visibility in Android settings.',
  ),
  (
    'Exporting records',
    'Copy attendance as CSV places your records on the system clipboard. Anything you paste, export, or share is outside Attendly’s local storage and is not removed by deleting data in the app.',
  ),
  (
    'Keeping and deleting data',
    'Records stay on this device until you delete them or clear the app’s storage. Signing out removes the saved login and clears the widget and alerts, but keeps your records. Delete local data removes all accounts’ saved attendance, personal records, timetables, plans, ID cards and images, saved login, and app preferences. It stops scheduled refresh and clears widgets and notifications. It does not delete your university account or change records held by IMS. Android permission choices are managed separately by Android.',
  ),
  (
    'Questions and contact',
    'Use Help & support for troubleshooting. A public support contact and hosted privacy-policy page have not been configured for this build.',
  ),
]);

void showHelp(
  BuildContext context,
) => _showInformation(context, 'Help & support', const [
  (
    'Attendance will not refresh',
    'Check your connection and try again. IMS may be unavailable or may have changed its report. Your last saved attendance stays available. Check the fetched time before using it to plan a leave.',
  ),
  (
    'Sign-in needs attention',
    'Confirm that you can sign in on the university portal. Check your student ID and password, then refresh the CAPTCHA. Never share your password, session cookies, or CAPTCHA response with someone offering support.',
  ),
  (
    'Official and personal attendance',
    'IMS records are shown as official attendance. With personal records enabled, your logs are added only for days not recorded by IMS. When both have records for a day, IMS is used and disagreements are flagged.',
  ),
  (
    'Background refresh and widgets',
    'Enable background attendance refresh in Settings and allow notifications if you want alerts. Android can delay updates to save battery. Open the app or tap the widget refresh button to try again. After signing out or deleting local data, sign in again before refreshing.',
  ),
  (
    'Planning a leave',
    'Add your timetable before planning future days. Results assume the listed classes take place and that you attend those you have not marked as missed. Plans do not change your actual attendance. Confirm university requirements before relying on a projection.',
  ),
  (
    'Contact support',
    'No public support email or website is configured for this build. If you report a problem to the person who supplied it, include the app version and steps to reproduce it. Remove student details from screenshots. Attendly does not send a report automatically.',
  ),
]);

void _showInformation(
  BuildContext context,
  String title,
  List<(String, String)> sections,
) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (context) => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: SelectionArea(
          child: ListView.separated(
            padding: const EdgeInsets.all(24),
            itemCount: sections.length,
            separatorBuilder: (_, index) => const SizedBox(height: 24),
            itemBuilder: (context, index) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sections[index].$1,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(sections[index].$2, style: const TextStyle(height: 1.5)),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class AppInformation extends StatefulWidget {
  const AppInformation({super.key});
  @override
  State<AppInformation> createState() => _AppInformationState();
}

class _AppInformationState extends State<AppInformation> {
  late final info = PlatformService().appInfo();
  @override
  Widget build(BuildContext context) => Card(
    child: Column(
      children: [
        ListTile(
          leading: const Icon(Icons.privacy_tip_outlined),
          title: const Text('Privacy notice'),
          subtitle: const Text('How your data is used and stored'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => showPrivacyNotice(context),
        ),
        ListTile(
          leading: const Icon(Icons.help_outline),
          title: const Text('Help & support'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => showHelp(context),
        ),
        FutureBuilder<Map<String, dynamic>>(
          future: info,
          builder: (context, snapshot) {
            final version = snapshot.data?['version'];
            final build = snapshot.data?['build'];
            final label = version == null
                ? 'Version unavailable'
                : 'Version $version (build $build)';
            return Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('Attendly'),
                  subtitle: Text('$label\nIndependent app for NSUT attendance'),
                  trailing: version == null
                      ? null
                      : IconButton(
                          tooltip: 'Copy app version',
                          icon: const Icon(Icons.copy_outlined),
                          onPressed: () async {
                            await Clipboard.setData(
                              ClipboardData(text: 'Attendly · $label'),
                            );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('App version copied.'),
                                ),
                              );
                            }
                          },
                        ),
                ),
                ListTile(
                  leading: const Icon(Icons.article_outlined),
                  title: const Text('Open-source licences'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => showLicensePage(
                    context: context,
                    applicationName: 'Attendly',
                    applicationVersion: version == null
                        ? null
                        : '$version ($build)',
                  ),
                ),
              ],
            );
          },
        ),
      ],
    ),
  );
}

Future<bool> confirmDeleteLocalData(
  BuildContext context,
  AppController controller,
) async {
  bool deleting = false;
  String? error;
  final deleted = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => PopScope(
        canPop: !deleting,
        child: AlertDialog(
          title: const Text('Delete local data?'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'This removes all saved accounts’ attendance, personal logs, timetables, plans, login details, and app preferences from this device. Background refresh stops, and widget data and notifications are cleared.\n\nYour IMS account and university records are not changed. Exported copies and Android permission choices remain. This cannot be undone.',
                ),
                if (deleting)
                  const Padding(
                    padding: EdgeInsets.only(top: 20),
                    child: LinearProgressIndicator(
                      semanticsLabel: 'Deleting local data',
                    ),
                  ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(
                      error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: deleting ? null : () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              onPressed: deleting
                  ? null
                  : () async {
                      setState(() {
                        deleting = true;
                        error = null;
                      });
                      try {
                        await controller.deleteAllLocalData();
                        if (context.mounted) Navigator.pop(context, true);
                      } catch (_) {
                        if (context.mounted) {
                          setState(() {
                            deleting = false;
                            error =
                                'Could not finish deleting local data. Please try again.';
                          });
                        }
                      }
                    },
              child: Text(deleting ? 'Deleting…' : 'Delete local data'),
            ),
          ],
        ),
      ),
    ),
  );
  if (deleted == true && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Local data deleted. Sign in when you’re ready.'),
      ),
    );
  }
  return deleted == true;
}
