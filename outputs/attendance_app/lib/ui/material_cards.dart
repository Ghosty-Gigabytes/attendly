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
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: c.primaryContainer,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.insights_rounded, color: c.onPrimaryContainer, size: 28),
          const SizedBox(height: 16),
          Text(
            atRisk == 0
                ? 'Plan your next break'
                : '$atRisk ${atRisk == 1 ? 'subject needs' : 'subjects need'} attention',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w400,
              color: c.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Check each subject before planning time off.',
            style: TextStyle(color: c.onPrimaryContainer),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onPlan,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Create a plan'),
          ),
        ],
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
