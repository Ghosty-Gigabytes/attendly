import '../domain/display_dates.dart';
import 'package:flutter/material.dart';
import '../data/controller.dart';
import '../domain/models.dart';
import 'shared.dart';
import 'motion.dart';
import 'bauhaus_theme.dart';
import 'calendar.dart';
import 'material_cards.dart';

class Dashboard extends StatelessWidget {
  final AppController controller;
  final VoidCallback onPlan;
  const Dashboard(this.controller, {super.key, required this.onPlan});
  @override
  Widget build(BuildContext context) {
    final data = controller.data;
    final scheme = Theme.of(context).colorScheme;
    final bauhaus = Theme.of(context).extension<BauhausPalette>() != null;
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
          if (isMaterialDesign(context))
            MaterialOverviewSummary(atRisk: atRisk, onPlan: onPlan)
          else
            Container(
              padding: EdgeInsets.all(26),
              decoration: BoxDecoration(
                color: bauhaus
                    ? scheme.primaryContainer
                    : Theme.of(context).brightness == Brightness.dark
                    ? Color(0xFF181A1D)
                    : ink,
                borderRadius: BorderRadius.circular(bauhaus ? 0 : 26),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.wb_sunny_outlined,
                        color: bauhaus
                            ? scheme.onPrimaryContainer
                            : Color(0xFFD5E8AE),
                        size: 20,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'YOUR OFFICIAL ATTENDANCE',
                          style: TextStyle(
                            color: bauhaus
                                ? scheme.onPrimaryContainer
                                : Color(0xFFD5E8AE),
                            fontSize: 10,
                            letterSpacing: 1.4,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 18),
                  Text(
                    atRisk == 0
                        ? 'Stay on track. Plan ahead.'
                        : '$atRisk ${atRisk == 1 ? 'subject needs' : 'subjects need'} a little attention.',
                    style: TextStyle(
                      color: bauhaus ? scheme.onPrimaryContainer : Colors.white,
                      fontSize: 25,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -.5,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Check your buffer before taking a break.',
                    style: TextStyle(
                      color: bauhaus
                          ? scheme.onPrimaryContainer
                          : Color(0xFFB9CEC6),
                      height: 1.6,
                    ),
                  ),
                  SizedBox(height: 20),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: bauhaus
                          ? scheme.primary
                          : Color(0xFFD5E8AE),
                      foregroundColor: bauhaus ? scheme.onPrimary : ink,
                    ),
                    onPressed: onPlan,
                    icon: Icon(Icons.arrow_outward_rounded, size: 18),
                    label: Text('Experiment with a leave'),
                  ),
                ],
              ),
            ),
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
              final columns = c.maxWidth >= 760 ? 2 : 1;
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
  Widget build(BuildContext context) {
    if (isMaterialDesign(context)) {
      return MaterialSubjectCard(subject: subject, data: data, onTap: onTap);
    }
    final c = subject.official,
        color = Color(subject.color),
        safe = c.eligible(),
        personal = data.personal(subject.code);
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Surface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.menu_book_rounded, color: color, size: 20),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    subject.code,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                      color: tone(context, muted),
                    ),
                  ),
                ),
                Tag(
                  c.held == 0
                      ? 'NO RECORDS'
                      : safe
                      ? 'ON TRACK'
                      : 'BELOW 75%',
                  color: c.held == 0
                      ? tone(context, muted)
                      : safe
                      ? tone(context, green)
                      : tone(context, amber),
                ),
              ],
            ),
            SizedBox(height: 16),
            Text(
              subject.name,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  percentage(c),
                  style: TextStyle(
                    fontSize: 35,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1.6,
                    color: tone(context, ink),
                  ),
                ),
                Spacer(),
                Padding(
                  padding: EdgeInsets.only(bottom: 7),
                  child: Text(
                    '${c.attended} / ${c.held} classes',
                    style: TextStyle(color: tone(context, muted), fontSize: 12),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, box) => Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SmoothAttendanceBar(
                      value: (c.percent ?? 0) / 100,
                      minHeight: 7,
                      color: safe ? tone(context, green) : tone(context, amber),
                      backgroundColor: tone(context, paper),
                    ),
                  ),
                  Positioned(
                    left: box.maxWidth * .75,
                    child: Container(
                      width: 2,
                      height: 7,
                      color: tone(context, ink),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 13),
            Text(
              c.held == 0
                  ? 'Waiting for attendance'
                  : safe
                  ? 'Can miss ${c.canMiss()} next ${c.canMiss() == 1 ? 'class' : 'classes'} at 75%'
                  : 'Attend ${c.recover()} consecutive classes to reach 75%',
              style: TextStyle(
                color: safe ? tone(context, green) : tone(context, amber),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (data.showPersonal) ...[
              Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Divider(height: 1, color: tone(context, line)),
              ),
              Row(
                children: [
                  Icon(
                    Icons.edit_note_rounded,
                    color: tone(context, muted),
                    size: 19,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'With personal',
                    style: TextStyle(color: tone(context, muted), fontSize: 12),
                  ),
                  Spacer(),
                  Text(
                    '${percentage(personal)}  ·  ${personal.attended}/${personal.held}',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ],
              ),
              SizedBox(height: 6),
              Text(
                'Includes your logs until IMS updates those days',
                style: TextStyle(fontSize: 10, color: tone(context, muted)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

void showSubject(
  BuildContext context,
  Subject subject,
  AppController controller,
) {
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
