import '../domain/display_dates.dart';
import 'package:flutter/material.dart';
import '../data/controller.dart';
import '../domain/models.dart';
import 'shared.dart';
import 'motion.dart';
import 'calendar.dart';
import 'material_cards.dart';

class Dashboard extends StatelessWidget {
  final AppController controller;
  final VoidCallback onPlan;
  const Dashboard(this.controller, {super.key, required this.onPlan});
  @override
  Widget build(BuildContext context) {
    final data = controller.data;
    final atRisk = data.subjects
        .where((s) => s.official.held > 0 && !s.official.eligible())
        .length;
    return RefreshIndicator(
      onRefresh: () => safely(context, controller.sync),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(
          MediaQuery.sizeOf(context).width < 600 ? 20 : 36,
        ),
        children: [
          Heading(
            'Your semester, in perspective',
            isMaterialDesign(context)
                ? 'Your attendance'
                : 'A little clarity. More freedom.',
            data.semester.isEmpty ? 'Connected to IMS' : data.semester,
          ),
          MaterialOverviewSummary(atRisk: atRisk, onPlan: onPlan),
          SizedBox(height: 26),
          if (controller.error != null)
            Padding(
              padding: EdgeInsets.only(bottom: 18),
              child: Surface(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      controller.error!,
                      style: TextStyle(
                        color: tone(context, amber),
                        height: 1.5,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: controller.refreshing
                          ? null
                          : () => safely(context, controller.sync),
                      icon: Icon(Icons.sync),
                      label: Text('Retry attendance fetch'),
                    ),
                  ],
                ),
              ),
            ),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 10,
            children: [
              Text(
                'Your subjects',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Show personal records',
                    style: TextStyle(fontSize: 12, color: tone(context, muted)),
                  ),
                  SizedBox(width: 8),
                  Switch(
                    value: data.showPersonal,
                    onChanged: (v) =>
                        safely(context, () => controller.showPersonal(v)),
                  ),
                ],
              ),
            ],
          ),
          Text(
            controller.refreshing
                ? 'Updating attendance…'
                : data.synced == null
                ? 'No official records fetched yet.'
                : 'Last fetched: ${longDate(data.synced!)} · ${TimeOfDay.fromDateTime(data.synced!).format(context)}. ',
            style: TextStyle(fontSize: 11, color: tone(context, muted)),
          ),
          if (data.discrepancies.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(top: 16),
              child: Surface(
                child: ExpansionTile(
                  title: Text(
                    '${data.discrepancies.length} attendance differences to check',
                  ),
                  subtitle: Text(
                    'Your logs and IMS show different attendance. Check the dates below. Your log or the IMS update may be incomplete.',
                  ),
                  children: [
                    for (final d in data.discrepancies)
                      ListTile(
                        title: Text(
                          '${data.subjectLabel(d.subject)} · ${displayDate(DateTime.parse(d.date))}',
                        ),
                        subtitle: Text(
                          'IMS ${d.official.attended}/${d.official.held} · Personal log ${d.personal.attended}/${d.personal.held}',
                        ),
                      ),
                  ],
                ),
              ),
            ),
          SizedBox(height: 18),
          if (data.subjects.isEmpty)
            Empty(
              'Your subjects will appear here',
              'Your IMS account is connected. Refresh attendance to load your subjects.',
            ),
          LayoutBuilder(
            builder: (context, c) {
              final columns = c.maxWidth >= 1120
                  ? 3
                  : c.maxWidth >= 700
                  ? 2
                  : 1;
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  for (final subject in data.subjects)
                    SizedBox(
                      width: (c.maxWidth - (columns - 1) * 16) / columns,
                      child: SubjectCard(
                        subject,
                        data,
                        onTap: () => showSubject(context, subject, controller),
                      ),
                    ),
                ],
              );
            },
          ),
          SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.lock_outline_rounded,
                size: 16,
                color: tone(context, muted),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'With personal includes your logs for days IMS has not updated yet. Once IMS records a day for a subject, we use that record instead of your log.',
                  style: TextStyle(
                    fontSize: 12,
                    color: tone(context, muted),
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 24),
        ],
      ),
    );
  }
}

class SubjectCard extends StatelessWidget {
  final Subject subject;
  final AppData data;
  final VoidCallback onTap;
  const SubjectCard(this.subject, this.data, {super.key, required this.onTap});
  @override
  Widget build(BuildContext context) =>
      MaterialSubjectCard(subject: subject, data: data, onTap: onTap);
}

void showSubject(
  BuildContext context,
  Subject subject,
  AppController controller,
) {
  if (MediaQuery.sizeOf(context).width >= 960) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          key: const Key('desktop-subject-panel'),
          width: 1000,
          height: MediaQuery.sizeOf(context).height * .86,
          child: Scaffold(
            appBar: AppBar(
              automaticallyImplyLeading: false,
              title: Text(
                subject.label,
                maxLines: 2,
                style: const TextStyle(fontSize: 16),
              ),
              actions: [
                IconButton(
                  tooltip: 'Close subject attendance',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            body: ListenableBuilder(
              listenable: controller,
              builder: (context, _) =>
                  CalendarScreen(controller, initialSubject: subject.code),
            ),
          ),
        ),
      ),
    );
    return;
  }
  Navigator.of(context).push(
    PageRouteBuilder<void>(
      transitionDuration: motionDuration(context, 300),
      reverseTransitionDuration: motionDuration(context, 240),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = animation.drive(CurveTween(curve: Curves.easeOutCubic));
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(.06, 0),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
      pageBuilder: (context, animation, secondaryAnimation) => Scaffold(
        appBar: AppBar(
          title: Text(
            subject.label,
            maxLines: 2,
            style: TextStyle(fontSize: 16),
          ),
        ),
        body: ListenableBuilder(
          listenable: controller,
          builder: (context, _) =>
              CalendarScreen(controller, initialSubject: subject.code),
        ),
      ),
    ),
  );
}
