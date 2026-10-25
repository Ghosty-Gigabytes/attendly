import 'dart:async';
import 'package:flutter/material.dart';
import '../data/controller.dart';
import '../data/api.dart';
import 'shared.dart';
import 'dashboard.dart';
import 'calendar.dart';
import 'timetable_screen.dart';
import 'planner_screen.dart';
import 'motion.dart';

class WebShell extends StatefulWidget {
  final AppController controller;
  const WebShell(this.controller, {super.key});
  @override
  State<WebShell> createState() => _WebShellState();
}

class _WebShellState extends State<WebShell> {
  int page = 0;
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
  @override
  Widget build(BuildContext context) {
    if (c.user == null) return AuthPage(c);
    final wide = MediaQuery.sizeOf(context).width >= 960;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
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
              ],
            ),
      body: SafeArea(
        child: Row(
          children: [
            if (wide)
              Container(
                width: 238,
                color: scheme.surfaceContainerLow,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(24, 28, 24, 24),
                      child: Brand(),
                    ),
                    for (var i = 0; i < labels.length; i++)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        child: ListTile(
                          selected: page == i,
                          selectedTileColor: scheme.secondaryContainer,
                          shape: const StadiumBorder(),
                          leading: Icon(icons[i]),
                          title: Text(labels[i]),
                          onTap: () => setState(() => page = i),
                        ),
                      ),
                    const Spacer(),
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            c.user!['name'] as String,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            c.user!['email'] as String,
                            style: TextStyle(
                              fontSize: 12,
                              color: scheme.onSurfaceVariant,
                            ),
                            maxLines: 2,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: Column(
                children: [
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
                              child: Text(c.needsLogin ? 'Sign in' : 'Retry'),
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
                        title: const Text('A record changed on another device'),
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
                                  'Connect IMS to load your attendance calendar.',
                                ),
                              )
                            : CalendarScreen(c),
                        TimetableScreen(c),
                        PlannerScreen(c),
                        settings(context),
                      ],
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
              selectedIndex: page,
              onDestinationSelected: (i) => setState(() => page = i),
              destinations: [
                for (var i = 0; i < labels.length; i++)
                  NavigationDestination(icon: Icon(icons[i]), label: labels[i]),
              ],
            ),
    );
  }

  Widget connectIntro(BuildContext context) => ListView(
    padding: const EdgeInsets.all(32),
    children: [
      const Heading(
        'Your semester, in perspective',
        'A little clarity. More freedom.',
        'Connect IMS once to bring your attendance, calendar and leave planning together.',
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
                  'Connect your university account',
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
                  label: const Text('Connect IMS'),
                ),
              ],
            ),
          ),
        ),
      ),
    ],
  );
  Future<void> connect(BuildContext context) async {
    await showDialog<void>(context: context, builder: (_) => ImsDialog(c));
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
              title: Text(c.user!['email'] as String),
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
                child: const Text('Connect IMS'),
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
        'Attendly is an independent student tool. Records sync to your Attendly account, with a saved copy on this device for offline use. Your IMS password is used to connect and is not saved.',
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
      Text(
        'attendly',
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -.7,
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
  final email = TextEditingController(),
      password = TextEditingController(),
      name = TextEditingController();
  final form = GlobalKey<FormState>();
  bool signup = false, hidden = true;
  String? error;
  @override
  void dispose() {
    email.dispose();
    password.dispose();
    name.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!form.currentState!.validate()) return;
    try {
      await widget.controller.signIn(
        email.text,
        password.text,
        name: signup ? name.text : null,
      );
      if (mounted && widget.reauthenticate) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => error = Api.message(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller,
        wide =
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
                signup ? 'Make room for life.' : 'Welcome back.',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 8),
              Text(
                signup
                    ? 'Create your Attendly account, then connect IMS.'
                    : 'Sign in to your attendance, wherever you are.',
              ),
              const SizedBox(height: 24),
              if (c.googleEnabled) ...[
                OutlinedButton(
                  onPressed: c.api.google,
                  child: const Text('Continue with Google'),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text('or use your email', textAlign: TextAlign.center),
                ),
              ],
              if (signup) ...[
                TextFormField(
                  controller: name,
                  autofillHints: const [AutofillHints.name],
                  decoration: const InputDecoration(labelText: 'Your name'),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Enter your name' : null,
                ),
                const SizedBox(height: 14),
              ],
              TextFormField(
                controller: email,
                autofillHints: const [AutofillHints.email],
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (v) =>
                    v != null &&
                        RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v.trim())
                    ? null
                    : 'Enter a valid email',
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: password,
                autofillHints: [
                  signup ? AutofillHints.newPassword : AutofillHints.password,
                ],
                obscureText: hidden,
                decoration: InputDecoration(
                  labelText: 'Password',
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
                validator: (v) => v == null || v.length < 8
                    ? 'Use at least 8 characters'
                    : null,
                onFieldSubmitted: (_) => submit(),
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
              const SizedBox(height: 24),
              FilledButton(
                onPressed: c.busy ? null : submit,
                child: Text(
                  c.busy
                      ? 'Please wait…'
                      : signup
                      ? 'Create account'
                      : 'Sign in',
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: c.busy
                    ? null
                    : () => setState(() {
                        signup = !signup;
                        error = null;
                      }),
                child: Text(
                  signup
                      ? 'Already have an account? Sign in'
                      : 'New here? Create an account',
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Your Attendly account is separate from your IMS login.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12),
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
                          padding: EdgeInsets.only(right: 72),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: 440),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
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

class ImsDialog extends StatefulWidget {
  final AppController c;
  const ImsDialog(this.c, {super.key});
  @override
  State<ImsDialog> createState() => _ImsDialogState();
}

class _ImsDialogState extends State<ImsDialog> {
  final student = TextEditingController(),
      password = TextEditingController(),
      captcha = TextEditingController();
  Map<String, dynamic>? challenge;
  String? error;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    student.text = widget.c.data.account;
    unawaited(load());
  }

  @override
  void dispose() {
    student.dispose();
    password.dispose();
    captcha.dispose();
    super.dispose();
  }

  Future<void> load() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final value = await widget.c.api.post('/ims/challenge');
      if (mounted) setState(() => challenge = value);
    } catch (e) {
      if (mounted) setState(() => error = Api.message(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> connect() async {
    if (challenge == null) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.c.connect({
        'challenge': challenge!['id'],
        'studentId': student.text.trim(),
        'password': password.text,
        'captcha': captcha.text.trim(),
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => error = Api.message(e));
    } finally {
      password.clear();
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Connect IMS'),
    content: SizedBox(
      width: 430,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Use your university login. Your IMS password is not saved.',
            ),
            const SizedBox(height: 20),
            TextField(
              controller: student,
              decoration: const InputDecoration(labelText: 'Student ID'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: password,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'IMS password'),
            ),
            const SizedBox(height: 16),
            if (busy) const LinearProgressIndicator(),
            if (challenge != null)
              Image.network(challenge!['image'] as String, height: 70),
            TextButton.icon(
              onPressed: busy ? null : load,
              icon: const Icon(Icons.refresh),
              label: const Text('New security image'),
            ),
            TextField(
              controller: captcha,
              decoration: const InputDecoration(labelText: 'Security number'),
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: busy || challenge == null ? null : connect,
        child: const Text('Connect & fetch'),
      ),
    ],
  );
}
