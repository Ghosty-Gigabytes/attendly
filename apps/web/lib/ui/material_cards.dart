import 'package:flutter/material.dart';
import '../domain/models.dart';
import 'shared.dart';
import 'wavy_attendance_bar.dart';

class MaterialOverviewSummary extends StatelessWidget {
  final int atRisk;
  final VoidCallback onPlan;
  const MaterialOverviewSummary({
    super.key,
    required this.atRisk,
    required this.onPlan,
  });
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 600 ? 22 : 30),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [c.primaryContainer, c.secondaryContainer],
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final content = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.insights_rounded,
                    color: c.onPrimaryContainer,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'OFFICIAL ATTENDANCE',
                    style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w700,
                      color: c.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                atRisk == 0
                    ? 'A little room to breathe.'
                    : '$atRisk ${atRisk == 1 ? 'subject to' : 'subjects to'} keep an eye on.',
                style: TextStyle(
                  fontSize: 26,
                  height: 1.2,
                  letterSpacing: -.6,
                  fontWeight: FontWeight.w600,
                  color: c.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Your 75% target is checked for each subject.',
                style: TextStyle(height: 1.5, color: c.onPrimaryContainer),
              ),
            ],
          );
          final action = FilledButton.icon(
            onPressed: onPlan,
            icon: const Icon(Icons.arrow_outward_rounded, size: 18),
            label: const Text('Plan a break'),
          );
          return constraints.maxWidth >= 760
              ? Row(
                  children: [
                    Expanded(child: content),
                    const SizedBox(width: 28),
                    action,
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [content, const SizedBox(height: 22), action],
                );
        },
      ),
    );
  }
}

class MaterialSubjectCard extends StatelessWidget {
  final Subject subject;
  final AppData data;
  final VoidCallback onTap;
  const MaterialSubjectCard({
    super.key,
    required this.subject,
    required this.data,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final c = subject.official, scheme = Theme.of(context).colorScheme;
    final status = c.held == 0
        ? scheme.onSurfaceVariant
        : c.eligible()
        ? tone(context, green)
        : scheme.error;
    final personal = data.personal(subject.code);
    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          subject.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subject.code,
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: scheme.onSurfaceVariant,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    percentage(c),
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w400,
                      color: status,
                    ),
                  ),
                  Text(
                    '${c.attended} of ${c.held} classes',
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              WavyAttendanceBar(
                key: ValueKey(
                  '${subject.code}:${data.synced?.microsecondsSinceEpoch}',
                ),
                value: (c.percent ?? 0) / 100,
                color: status,
                trackColor: scheme.surfaceContainerHighest,
              ),
              const SizedBox(height: 12),
              Text(
                c.held == 0
                    ? 'No classes recorded yet'
                    : c.eligible()
                    ? 'You can miss ${c.canMiss()} more ${c.canMiss() == 1 ? 'class' : 'classes'}'
                    : 'Attend ${c.recover()} consecutive classes to reach 75%',
                style: TextStyle(color: status, fontSize: 13),
              ),
              if (data.showPersonal) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Divider(height: 1),
                ),
                Text(
                  'With personal logs: ${percentage(personal)} · ${personal.attended}/${personal.held}',
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
