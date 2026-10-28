import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/controller.dart';
import '../data/api.dart';
import 'shared.dart';
import 'dashboard.dart';
import 'calendar.dart';
import 'timetable_screen.dart';
import 'planner_screen.dart';
import 'motion.dart';
import 'id_card.dart';

class WebShell extends StatefulWidget {
  final AppController controller;
  const WebShell(this.controller, {super.key});
  @override
  State<WebShell> createState() => _WebShellState();
}

class _WebShellState extends State<WebShell> {
  int page = 0;
  bool loggingOut = false;
  AppController get c => widget.controller;
  static const labels = [
    'Overview',
    'Calendar',
    'Timetable',
    'What if?',
    'Settings',
  ];
  static const icons = [
    Icons.dashboard_outlined,
    Icons.calendar_month_outlined,
    Icons.calendar_view_week_outlined,
    Icons.auto_awesome_outlined,
    Icons.tune_rounded,
  ];
  Future<void> logout() async {
    if (loggingOut) return;
    if (c.pending.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'You have ${c.pending.length} unsynced changes. Sync them before logging out so they are not lost.',
          ),
          action: SnackBarAction(
            label: 'Sync now',
            onPressed: () => c.synchronize(),
          ),
        ),
      );
      return;
    }
    setState(() => loggingOut = true);
    try {
      await c.signOut();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(Api.message(e))));
      }
    } finally {
      if (mounted) setState(() => loggingOut = false);
    }
  }

  void openIdCard() => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => IdCardScreen(controller: c)));

  @override
  Widget build(BuildContext context) {
    if (c.user == null) return AuthPage(c);
    final wide = MediaQuery.sizeOf(context).width >= 960;
    final scheme = Theme.of(context).colorScheme;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyI, alt: true): openIdCard,
        for (var i = 0; i < labels.length; i++)
          SingleActivator(
            [
              LogicalKeyboardKey.digit1,
              LogicalKeyboardKey.digit2,
              LogicalKeyboardKey.digit3,
              LogicalKeyboardKey.digit4,
              LogicalKeyboardKey.digit5,
            ][i],
            alt: true,
          ): () =>
              setState(() => page = i),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          appBar: wide
              ? null
              : AppBar(
                  title: const Brand(),
                  actions: [
                    IconButton(
                      tooltip: 'Refresh attendance',
                      onPressed: c.refreshing ? null : c.sync,
                      icon: const Icon(Icons.refresh),
                    ),
                    IconButton(
                      tooltip: 'Log out',
                      onPressed: loggingOut ? null : logout,
                      icon: const Icon(Icons.logout_rounded),
                    ),
                  ],
                ),
          body: SafeArea(
            child: Row(
              children: [
                if (wide)
                  SizedBox(
                    width: 256,
                    child: Material(
                      color: scheme.surfaceContainerLow,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.fromLTRB(24, 28, 24, 24),
                            child: Brand(),
                          ),
                          Expanded(
                            child: ListView(
                              padding: EdgeInsets.zero,
                              children: [
                                for (var i = 0; i < labels.length; i++)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 4,
                                    ),
                                    child: Tooltip(
                                      message: '${labels[i]} · Alt+${i + 1}',
                                      child: ListTile(
                                        selected: page == i,
                                        selectedTileColor:
                                            scheme.secondaryContainer,
                                        shape: const StadiumBorder(),
                                        leading: Icon(icons[i]),
                                        title: Text(labels[i]),
                                        onTap: () => setState(() => page = i),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            child: ListTile(
                              key: const Key('open-id-card'),
                              shape: const StadiumBorder(),
                              leading: const Icon(Icons.badge_outlined),
                              title: const Text('ID card'),
                              trailing: const Icon(Icons.open_in_new, size: 16),
                              onTap: openIdCard,
                            ),
                          ),
                          const Divider(height: 1),
                          Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 19,
                                      backgroundColor:
                                          scheme.secondaryContainer,
                                      child: Icon(
                                        Icons.person_outline_rounded,
                                        size: 20,
                                        color: scheme.onSecondaryContainer,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            c.user!['name'] ==
                                                    c.user!['studentId']
                                                ? 'Your IMS account'
                                                : c.user!['name'] as String,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            (c.user!['studentId'] ??
                                                    c.data.account)
                                                as String,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: scheme.onSurfaceVariant,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    key: const Key('sidebar-logout'),
                                    onPressed: loggingOut ? null : logout,
                                    icon: const Icon(
                                      Icons.logout_rounded,
                                      size: 18,
                                    ),
                                    label: Text(
                                      loggingOut ? 'Logging out…' : 'Log out',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                Expanded(
                  child: Column(
                    children: [
                      if (wide)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 16,
                          ),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: scheme.outlineVariant.withValues(
                                  alpha: .5,
                                ),
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Text(
                                labels[page],
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const Spacer(),
                              if (c.data.synced != null) ...[
                                Text(
                                  'Updated ${shortDate(c.data.synced!)} · ${TimeOfDay.fromDateTime(c.data.synced!).format(context)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(width: 20),
                              ],
                              FilledButton.tonalIcon(
                                onPressed: c.refreshing || c.limited
                                    ? null
                                    : c.sync,
                                icon: c.refreshing
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.refresh, size: 18),
                                label: Text(
                                  c.refreshing
                                      ? 'Updating…'
                                      : 'Refresh attendance',
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (c.limited)
                        Material(
                          color: scheme.secondaryContainer,
                          child: ListTile(
                            leading: const Icon(Icons.history),
                            title: const Text(
                              'IMS is unavailable. Showing saved records.',
                            ),
                            subtitle: const Text(
                              'Viewing only. Sign in with IMS again to make changes.',
                            ),
                            trailing: TextButton(
                              onPressed: () => showDialog<void>(
                                context: context,
                                builder: (_) => Dialog(
                                  child: SizedBox(
                                    width: 480,
                                    child: AuthPage(c, reauthenticate: true),
                                  ),
                                ),
                              ),
                              child: const Text('Verify again'),
                            ),
                          ),
                        ),
                      if (c.needsLogin || !c.online || c.pending.isNotEmpty)
                        Material(
                          color: scheme.surfaceContainerHighest,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 10,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  c.needsLogin
                                      ? Icons.lock_outline
                                      : !c.online
                                      ? Icons.cloud_off_outlined
                                      : Icons.cloud_upload_outlined,
                                  size: 18,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    c.needsLogin
                                        ? 'Sign in again to sync. Saved records are available.'
                                        : !c.online
                                        ? 'Offline · showing saved records'
                                        : '${c.pending.length} changes waiting to sync',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                                TextButton(
                                  onPressed: c.needsLogin
                                      ? () => showDialog<void>(
                                          context: context,
                                          builder: (_) => Dialog(
                                            child: SizedBox(
                                              width: 480,
                                              child: AuthPage(
                                                c,
                                                reauthenticate: true,
                                              ),
                                            ),
                                          ),
                                        )
                                      : () => c.checkSession(),
                                  child: Text(
                                    c.needsLogin ? 'Sign in' : 'Retry',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (c.conflicts.isNotEmpty)
                        Material(
                          color: scheme.errorContainer,
                          child: ListTile(
                            leading: const Icon(Icons.difference_outlined),
                            title: const Text(
                              'A record changed on another device',
                            ),
                            subtitle: const Text(
                              'Both versions are kept until you choose.',
                            ),
                            trailing: TextButton(
                              onPressed: () => reviewConflict(context),
                              child: const Text('Review'),
                            ),
                          ),
                        ),
                      Expanded(
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: SizedBox(
                            width: wide
                                ? (page == 2
                                      ? 1600
                                      : page == 4
                                      ? 960
                                      : page == 1
                                      ? 1120
                                      : 1400)
                                : double.infinity,
                            child: SmoothTabStack(
                              index: page,
                              children: [
                                c.data.subjects.isEmpty
                                    ? connectIntro(context)
                                    : Dashboard(
                                        c,
                                        onPlan: () => setState(() => page = 3),
                                      ),
                                c.data.subjects.isEmpty
                                    ? const Center(
                                        child: Text(
                                          'Your calendar will appear after attendance is refreshed.',
                                        ),
                                      )
                                    : CalendarScreen(c),
                                TimetableScreen(c),
                                PlannerScreen(c),
                                settings(context),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: wide
              ? null
              : NavigationBar(
                  labelBehavior:
                      NavigationDestinationLabelBehavior.onlyShowSelected,
                  selectedIndex: page == 4 ? 5 : page,
                  onDestinationSelected: (i) {
                    if (i == 4) {
                      openIdCard();
                    } else {
                      setState(() => page = i == 5 ? 4 : i);
                    }
                  },
                  destinations: [
                    for (var i = 0; i < 4; i++)
                      NavigationDestination(
                        icon: Icon(icons[i]),
                        label: labels[i],
                      ),
                    const NavigationDestination(
                      key: Key('mobile-id-card'),
                      icon: Icon(Icons.badge_outlined),
                      label: 'ID card',
                      tooltip: 'Open ID card',
                    ),
                    NavigationDestination(
                      icon: Icon(icons[4]),
                      label: labels[4],
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget connectIntro(BuildContext context) => ListView(
    padding: const EdgeInsets.all(32),
    children: [
      const Heading(
        'Your semester, in perspective',
        'A little clarity. More freedom.',
        'Your saved attendance will appear here after the first successful refresh.',
      ),
      Align(
        alignment: Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 650),
          child: Surface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.school_outlined, size: 36),
                const SizedBox(height: 18),
                Text(
                  'Your semester starts here',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 10),
                const Text(
                  'Your official records stay separate from your personal logs. Once fetched, attendance is also available offline on this device.',
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () => connect(context),
                  icon: const Icon(Icons.link),
                  label: const Text('Verify IMS login'),
                ),
              ],
            ),
          ),
        ),
      ),
    ],
  );
  Future<void> connect(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        child: SizedBox(width: 480, child: AuthPage(c, reauthenticate: true)),
      ),
    );
  }

  Widget settings(BuildContext context) => ListView(
    padding: const EdgeInsets.all(32),
    children: [
      const Heading(
        'Make it yours',
        'Settings',
        'Your account, appearance and university connection.',
      ),
      Surface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Appearance', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'light', label: Text('Light')),
                ButtonSegment(value: 'dark', label: Text('Dark')),
                ButtonSegment(value: 'system', label: Text('System')),
              ],
              selected: {c.theme},
              onSelectionChanged: (v) => c.setAppearance(mode: v.first),
            ),
            const SizedBox(height: 20),
            const Text('Accent colour'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final seed in [
                  0xFF2463BC,
                  0xFF237962,
                  0xFF6750A4,
                  0xFF9C4146,
                  0xFF805600,
                ])
                  IconButton.filledTonal(
                    tooltip: 'Choose accent',
                    onPressed: () => c.setAppearance(seed: seed),
                    icon: Icon(
                      c.accent == seed ? Icons.check_circle : Icons.circle,
                      color: Color(seed),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Use 24-hour time'),
              value: c.use24Hour,
              onChanged: (v) => c.setAppearance(clock: v ? '24' : '12'),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      Surface(
        child: Column(
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text((c.user!['studentId'] ?? c.user!['name']) as String),
              subtitle: const Text('Attendly account'),
              leading: const Icon(Icons.account_circle_outlined),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                c.data.account.isEmpty ? 'IMS not connected' : c.data.account,
              ),
              subtitle: Text(
                c.imsSessionReady
                    ? 'Connected · refresh is available'
                    : 'Reconnect IMS to fetch newer attendance',
              ),
              trailing: TextButton(
                onPressed: () => connect(context),
                child: const Text('Verify login'),
              ),
            ),
            if (c.user?['rememberIms'] == true)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Saved IMS password'),
                subtitle: const Text(
                  'Encrypted on the server for background refresh.',
                ),
                trailing: TextButton(
                  onPressed: c.limited
                      ? null
                      : () => safely(context, () async {
                          await c.api.post('/ims/forget-password');
                          await c.checkSession();
                        }),
                  child: const Text('Remove'),
                ),
              ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Sync records'),
              subtitle: Text('${c.pending.length} pending changes'),
              trailing: IconButton(
                tooltip: 'Sync records',
                onPressed: c.synchronize,
                icon: const Icon(Icons.sync),
              ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Sign out'),
              subtitle: const Text(
                'Clears records stored on this browser after pending edits are synced.',
              ),
              trailing: IconButton(
                tooltip: 'Sign out',
                onPressed: () => safely(context, c.signOut),
                icon: const Icon(Icons.logout),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      const Text(
        'Attendly is an independent student tool. Records sync to your Attendly account, with a saved copy on this device for offline use. Background refresh uses your encrypted IMS password if you enable it. Remove the saved password at any time in Settings.',
        style: TextStyle(fontSize: 12),
      ),
    ],
  );
  Future<void> reviewConflict(BuildContext context) async {
    final change = c.conflicts.first;
    final remote = c
        .serverRecords[c.key(change['kind'] as String, change['id'] as String)];
    final choice = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose which version to keep'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Your device: ${change['deleted'] == true ? 'Deleted' : change['payload']}',
              ),
              const SizedBox(height: 16),
              Text(
                'Other device: ${remote?['deleted'] == true ? 'Deleted' : remote?['payload']}',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Use synced version'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Keep my change'),
          ),
        ],
      ),
    );
    if (choice != null) await c.resolveConflict(choice);
  }
}

class Brand extends StatelessWidget {
  const Brand({super.key});
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      const SizedBox(
        width: 32,
        height: 36,
        child: CustomPaint(painter: _BrandPainter()),
      ),
      const SizedBox(width: 8),
      Flexible(
        child: Text(
          'attendly',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -.7,
          ),
        ),
      ),
    ],
  );
}

class _BrandPainter extends CustomPainter {
  const _BrandPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFF237962);
    for (var row = 0; row < 4; row++) {
      for (var column = 0; column < 2; column++) {
        canvas.drawCircle(
          Offset((row.isEven ? 12 : 5) + column * 14.0, 5 + row * 8.5),
          3.5,
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class AuthPage extends StatefulWidget {
  final AppController controller;
  final bool reauthenticate;
  const AuthPage(this.controller, {super.key, this.reauthenticate = false});
  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final student = TextEditingController(),
      password = TextEditingController(),
      captcha = TextEditingController();
  final form = GlobalKey<FormState>();
  Map<String, dynamic>? challenge;
  bool hidden = true, remember = true, loading = false;
  String? error, challengeError;
  @override
  void initState() {
    super.initState();
    student.text = widget.controller.data.account;
    unawaited(loadChallenge());
  }

  @override
  void dispose() {
    student.dispose();
    password.dispose();
    captcha.dispose();
    super.dispose();
  }

  Future<void> loadChallenge() async {
    setState(() {
      loading = true;
      challenge = null;
      captcha.clear();
      challengeError = null;
    });
    try {
      final value = await widget.controller.api.post('/auth/ims/challenge');
      if (mounted) {
        setState(() {
          challenge = value;
          captcha.text = value['answer'] as String? ?? '';
        });
      }
    } catch (e) {
      if (mounted) setState(() => challengeError = Api.message(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> submit() async {
    if (!form.currentState!.validate()) return;
    setState(() => error = null);
    try {
      await widget.controller.signIn({
        'studentId': student.text.trim(),
        'password': password.text,
        'challenge': challenge?['id'],
        'captcha': captcha.text.trim(),
        'remember': remember,
      });
      password.clear();
      if (mounted && widget.reauthenticate) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => error = Api.message(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final wide =
        MediaQuery.sizeOf(context).width >= 960 && !widget.reauthenticate;
    final panel = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 440),
      child: Surface(
        child: Form(
          key: form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Brand(),
              const SizedBox(height: 28),
              Text(
                'Sign in with IMS',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'Use your university login. Your Attendly account is created automatically after IMS verifies you.',
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: student,
                autofillHints: const [AutofillHints.username],
                decoration: const InputDecoration(labelText: 'IMS student ID'),
                validator: (v) =>
                    v != null &&
                        RegExp(r'^[A-Za-z0-9-]{4,40}$').hasMatch(v.trim())
                    ? null
                    : 'Enter your IMS student ID',
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: password,
                autofillHints: const [AutofillHints.password],
                obscureText: hidden,
                decoration: InputDecoration(
                  labelText: 'IMS password',
                  suffixIcon: IconButton(
                    tooltip: hidden ? 'Show password' : 'Hide password',
                    onPressed: () => setState(() => hidden = !hidden),
                    icon: Icon(
                      hidden
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Enter your IMS password' : null,
              ),
              const SizedBox(height: 14),
              if (loading) const LinearProgressIndicator(),
              if (challenge != null) ...[
                Image.memory(
                  Uri.parse(
                    challenge!['image'] as String,
                  ).data!.contentAsBytes(),
                  height: 60,
                ),
                TextFormField(
                  controller: captcha,
                  decoration: const InputDecoration(
                    labelText: 'Security number',
                    helperMaxLines: 2,
                    helperText:
                        'Filled automatically when possible. You can correct it.',
                  ),
                ),
              ],
              if (challengeError != null)
                Text(
                  challengeError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: loading || c.busy ? null : loadChallenge,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh security image'),
                ),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: remember,
                controlAffinity: ListTileControlAffinity.leading,
                onChanged: c.busy
                    ? null
                    : (v) => setState(() => remember = v ?? false),
                title: const Text('Keep attendance updated in the background'),
                subtitle: const Text(
                  'Stores an encrypted IMS password on the server. You can remove it in Settings.',
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'If IMS is down, your last verified password can open saved records for up to 7 days after verification.',
                style: TextStyle(fontSize: 12),
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: c.busy || loading ? null : submit,
                child: Text(
                  c.busy ? 'Verifying with IMS…' : 'Continue with IMS',
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: wide
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 72),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 440),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  'YOUR SEMESTER, IN PERSPECTIVE',
                                  style: TextStyle(
                                    letterSpacing: 2,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(height: 24),
                                Text(
                                  'A little clarity.\nMore freedom.',
                                  style: TextStyle(
                                    fontSize: 54,
                                    fontWeight: FontWeight.w500,
                                    height: 1.1,
                                    letterSpacing: -2,
                                  ),
                                ),
                                SizedBox(height: 24),
                                Text(
                                  'Check each subject. Keep your own logs. Plan a break with confidence.',
                                  style: TextStyle(fontSize: 18, height: 1.6),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      panel,
                    ],
                  )
                : panel,
          ),
        ),
      ),
    );
  }
}
