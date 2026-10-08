import 'package:flutter/material.dart' hide Baseline;
import '../data/controller.dart';
import '../domain/models.dart';
import '../domain/planner.dart';
import 'shared.dart';
import 'material_controls.dart';
import 'timetable_editor.dart';

class PlannerScreen extends StatefulWidget {
  final AppController controller;
  const PlannerScreen(this.controller, {super.key});
  @override
  State<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends State<PlannerScreen> {
  late DateTime from = dayOnly(DateTime.now()).add(Duration(days: 1));
  late DateTime until = from.add(Duration(days: 13));
  Baseline baseline = Baseline.official;
  int target = 75;
  String name = 'My leave experiment';
  String? savedId;
  String? scope;
  Map<String, PlanAction> actions = {};
  List<Session> extras = [];
  Scenario get plan => Scenario(
    id: savedId ?? 'plan-${DateTime.now().microsecondsSinceEpoch}',
    name: name,
    from: from,
    until: until,
    baseline: baseline,
    target: target,
    actions: actions,
    extras: extras,
  );
  void load(Scenario p) => setState(() {
    savedId = p.id;
    name = p.name;
    from = p.from;
    until = p.until;
    baseline = p.baseline;
    target = p.target;
    actions = {...p.actions};
    extras = [...p.extras];
  });

  @override
  Widget build(BuildContext context) {
    final data = widget.controller.data;
    if (scope != widget.controller.scope) {
      scope = widget.controller.scope;
      actions = {};
      extras = [];
      savedId = null;
    }
    final scenario = plan,
        sessions = plannedSessions(data, scenario),
        results = project(data, scenario);
    final dates = sessions.map((s) => dateKey(s.starts)).toSet().toList();
    final stale = from.isBefore(dayOnly(DateTime.now()).add(Duration(days: 1)));
    return ListView(
      padding: EdgeInsets.all(24),
      children: [
        Heading(
          'Make room for life',
          isMaterialDesign(context)
              ? 'Leave planner'
              : 'What if you took a break?',
          'Try a plan. See every subject’s outcome. Your actual records stay untouched.',
        ),
        Surface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isMaterialDesign(context)
                    ? 'Starting point'
                    : '01  SET YOUR STARTING POINT',
                style: TextStyle(
                  color: tone(context, muted),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.3,
                ),
              ),
              SizedBox(height: 16),
              Wrap(
                spacing: 18,
                runSpacing: 16,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SegmentedButton<Baseline>(
                    segments: [
                      ButtonSegment(
                        value: Baseline.official,
                        label: Text('Official'),
                      ),
                      ButtonSegment(
                        value: Baseline.personal,
                        label: Text('With personal'),
                      ),
                    ],
                    selected: {baseline},
                    onSelectionChanged: (v) =>
                        setState(() => baseline = v.first),
                  ),
                  AppDropdown<int>(
                    value: target,
                    items: [
                      for (final p in [75, 80, 85, 90, 95])
                        DropdownMenuItem(value: p, child: Text('Target: $p%')),
                    ],
                    onChanged: (v) => setState(() => target = v!),
                  ),
                ],
              ),
              SizedBox(height: 14),
              Text(
                baseline == Baseline.official
                    ? 'Uses your latest IMS attendance. Classes your teachers have not uploaded yet are not included.'
                    : 'Uses IMS attendance and your logs for days IMS has not updated yet.',
                style: TextStyle(
                  color: tone(context, muted),
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
              SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () async {
                  final tomorrow = dayOnly(
                    DateTime.now(),
                  ).add(Duration(days: 1));
                  final range = await showDateRangePicker(
                    context: context,
                    firstDate: tomorrow,
                    lastDate: tomorrow.add(Duration(days: 365)),
                    initialDateRange: stale
                        ? null
                        : DateTimeRange(start: from, end: until),
                    helpText: 'Choose your planning window (up to 120 days)',
                  );
                  if (range != null && context.mounted) {
                    if (range.end.difference(range.start).inDays > 120) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Choose a planning window of 120 days or less.',
                          ),
                        ),
                      );
                      return;
                    }
                    setState(() {
                      from = range.start;
                      until = range.end;
                    });
                  }
                },
                icon: Icon(Icons.date_range, size: 18),
                label: Text('${shortDate(from)} → ${shortDate(until)}'),
              ),
              SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: tone(context, green),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Assumption: attend every other scheduled class in this window. Mark holidays and cancellations below. Timetable coverage limits the projection.',
                      style: TextStyle(
                        color: tone(context, green),
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
              if (stale)
                Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text(
                    'This saved plan includes past dates. Choose a future window before using its projections.',
                    style: TextStyle(
                      color: tone(context, red),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
        SizedBox(height: 22),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: stale
                  ? null
                  : () async {
                      final value = await askText(
                        context,
                        'Save this experiment',
                        initial: name,
                      );
                      if (value != null && context.mounted) {
                        setState(() => name = value);
                        final snapshot = plan;
                        await safely(
                          context,
                          () => widget.controller.saveScenario(snapshot),
                        );
                        setState(() => savedId = snapshot.id);
                      }
                    },
              icon: Icon(Icons.bookmark_outline, size: 17),
              label: Text('Save plan'),
            ),
            OutlinedButton.icon(
              onPressed: () => setState(() {
                actions = {};
                extras = [];
                savedId = null;
                name = 'My leave experiment';
              }),
              icon: Icon(Icons.restart_alt, size: 17),
              label: Text('Reset'),
            ),
            OutlinedButton.icon(
              onPressed: sessions.isEmpty || stale
                  ? null
                  : () => findDays(context, data, scenario),
              icon: Icon(Icons.travel_explore, size: 17),
              label: Text('Find leave dates'),
            ),
            OutlinedButton.icon(
              onPressed: data.subjects.isEmpty || stale
                  ? null
                  : () => addExtra(context, data),
              icon: Icon(Icons.add, size: 17),
              label: Text('Hypothetical class'),
            ),
            OutlinedButton.icon(
              onPressed: data.scenarios.isEmpty || stale
                  ? null
                  : () => comparePlans(context, data, scenario),
              icon: Icon(Icons.compare_arrows, size: 17),
              label: Text('Compare plans'),
            ),
          ],
        ),
        if (data.scenarios.isNotEmpty) ...[
          SizedBox(height: 18),
          Text(
            'SAVED EXPERIMENTS',
            style: TextStyle(
              color: tone(context, muted),
              fontSize: 10,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final saved in data.scenarios)
                InputChip(
                  label: Text(saved.name),
                  selected: savedId == saved.id,
                  onPressed: () => load(saved),
                  onDeleted: () => safely(
                    context,
                    () => widget.controller.deleteScenario(saved.id),
                  ),
                ),
            ],
          ),
          SizedBox(height: 6),
          Text(
            'Saved plans update when your attendance changes.',
            style: TextStyle(fontSize: 11, color: tone(context, muted)),
          ),
        ],
        SizedBox(height: 28),
        Text(
          isMaterialDesign(context) ? 'Your schedule' : '02  Shape your week',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        SizedBox(height: 8),
        Text(
          'Miss a whole day or change individual classes. Cancelled classes do not affect attendance.',
          style: TextStyle(
            color: tone(context, muted),
            fontSize: 12,
            height: 1.5,
          ),
        ),
        SizedBox(height: 16),
        if (sessions.isEmpty)
          Empty(
            'Add your timetable to start planning',
            'Add your weekly classes to plan future dates.',
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => openTimetable(context, widget.controller),
            icon: const Icon(Icons.calendar_view_week_outlined),
            label: const Text('Edit weekly timetable'),
          ),
        ),
        for (final date in dates)
          Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Surface(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        longDate(DateTime.parse(date)),
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      TextButton(
                        onPressed: () => setState(() {
                          for (final s in sessions.where(
                            (s) => dateKey(s.starts) == date,
                          )) {
                            if (actions[s.id] != PlanAction.cancel) {
                              actions[s.id] = PlanAction.miss;
                            }
                          }
                        }),
                        child: Text('Take day off'),
                      ),
                      TextButton(
                        onPressed: () => setState(() {
                          for (final s in sessions.where(
                            (s) => dateKey(s.starts) == date,
                          )) {
                            actions[s.id] = PlanAction.cancel;
                          }
                        }),
                        child: Text('Holiday'),
                      ),
                    ],
                  ),
                  for (final s in sessions.where(
                    (s) => dateKey(s.starts) == date,
                  ))
                    Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: LayoutBuilder(
                        builder: (context, c) {
                          final details = Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                data.subjectLabel(s.subject),
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                '${TimeOfDay.fromDateTime(s.starts).format(context)}${s.weight > 1 ? ' · ${s.weight} classes' : ''}${extras.any((e) => e.id == s.id) ? ' · hypothetical' : ''}',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: tone(context, muted),
                                ),
                              ),
                            ],
                          );
                          final choices = Wrap(
                            spacing: 5,
                            children: [
                              for (final action in PlanAction.values)
                                ChoiceChip(
                                  visualDensity: VisualDensity.compact,
                                  label: Text(switch (action) {
                                    PlanAction.attend => 'Attend',
                                    PlanAction.miss => 'Miss',
                                    PlanAction.cancel => 'Cancel',
                                  }, style: TextStyle(fontSize: 11)),
                                  selected:
                                      (actions[s.id] ?? PlanAction.attend) ==
                                      action,
                                  onSelected: (_) =>
                                      setState(() => actions[s.id] = action),
                                ),
                            ],
                          );
                          return c.maxWidth < 420
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    details,
                                    SizedBox(height: 6),
                                    choices,
                                  ],
                                )
                              : Row(
                                  children: [
                                    Expanded(child: details),
                                    choices,
                                  ],
                                );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        SizedBox(height: 18),
        Text(
          isMaterialDesign(context)
              ? 'Projected attendance'
              : '03  See the impact',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        SizedBox(height: 8),
        Text(
          'You need 75% in every subject. Reaching 75% later does not change an earlier day when you were below it.',
          style: TextStyle(color: tone(context, muted), fontSize: 12),
        ),
        SizedBox(height: 16),
        if (!stale)
          for (final result in results)
            Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: ProjectionCard(
                result,
                recovery: recoveryDate(data, scenario, result),
              ),
            ),
        if (stale)
          Empty(
            'Choose new dates',
            'Some planned classes are now in the past and may already be in your attendance. Choose future dates to try this plan.',
          ),
        SizedBox(height: 30),
      ],
    );
  }

  Future<void> comparePlans(
    BuildContext context,
    AppData data,
    Scenario current,
  ) async {
    var other = data.scenarios.first;
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, set) {
          final left = project(data, current), right = project(data, other);
          return AlertDialog(
            title: Text('Compare experiments'),
            content: SizedBox(
              width: 560,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppDropdown<String>(
                      itemHeight: 64,
                      isExpanded: true,
                      value: other.id,
                      items: [
                        for (final saved in data.scenarios)
                          DropdownMenuItem(
                            value: saved.id,
                            child: Text(
                              saved.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (id) => set(
                        () => other = data.scenarios.firstWhere(
                          (p) => p.id == id,
                        ),
                      ),
                    ),
                    Text(
                      'Current: ${current.baseline.name}, ${current.target}%, ${shortDate(current.from)}–${shortDate(current.until)}\nSaved: ${other.baseline.name}, ${other.target}%, ${shortDate(other.from)}–${shortDate(other.until)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: tone(context, muted),
                        height: 1.5,
                      ),
                    ),
                    if (other.from.isBefore(
                      dayOnly(DateTime.now()).add(Duration(days: 1)),
                    ))
                      Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: Text(
                          'The saved plan contains past dates. Update it before relying on this comparison.',
                          style: TextStyle(
                            color: tone(context, amber),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    SizedBox(height: 16),
                    for (var i = 0; i < left.length; i++)
                      Padding(
                        padding: EdgeInsets.only(bottom: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              left[i].subject.label,
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            SizedBox(height: 5),
                            Text(
                              'Current ${percentage(left[i].end)}${left[i].dipsBelow ? ' · dips below target' : ''}\nSaved   ${percentage(right[i].end)}${right[i].dipsBelow ? ' · dips below target' : ''}',
                              style: TextStyle(fontSize: 13, height: 1.6),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Done'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> findDays(
    BuildContext context,
    AppData data,
    Scenario scenario,
  ) async {
    final days = suitableDays(data, scenario);
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Potential days off'),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Each date is tested independently, on top of this plan. All subjects must remain at or above $target% throughout.',
                  style: TextStyle(color: tone(context, muted), height: 1.5),
                ),
                SizedBox(height: 16),
                if (days.isEmpty)
                  Text(
                    'No qualifying dates in this window. A subject may already be below your target.',
                  ),
                for (final day in days)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      Icons.check_circle_outline,
                      color: tone(context, green),
                    ),
                    title: Text(longDate(day)),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Done'),
          ),
        ],
      ),
    );
  }

  Future<void> addExtra(BuildContext context, AppData data) async {
    String code = data.subjects.first.code;
    DateTime date = from;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, set) => AlertDialog(
          title: Text('Hypothetical extra class'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Only a real, countable university class could improve official attendance.',
                style: TextStyle(color: tone(context, muted), fontSize: 12),
              ),
              AppDropdown<String>(
                itemHeight: 64,
                value: code,
                isExpanded: true,
                items: [
                  for (final s in data.subjects)
                    DropdownMenuItem(
                      value: s.code,
                      child: Text(
                        s.label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (v) => set(() => code = v!),
              ),
              TextButton(
                onPressed: () async {
                  final value = await showDatePicker(
                    context: context,
                    initialDate: date,
                    firstDate: from,
                    lastDate: until,
                  );
                  if (value != null) set(() => date = value);
                },
                child: Text(shortDate(date)),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Add to plan'),
            ),
          ],
        ),
      ),
    );
    if (result == true) {
      setState(
        () => extras.add(
          Session(
            id: 'hypothetical-${DateTime.now().microsecondsSinceEpoch}',
            subject: code,
            starts: DateTime(date.year, date.month, date.day, 17),
          ),
        ),
      );
    }
  }
}

class ProjectionCard extends StatelessWidget {
  final Projection result;
  final DateTime? recovery;
  const ProjectionCard(this.result, {super.key, this.recovery});
  @override
  Widget build(BuildContext context) {
    final end = result.end, good = end.eligible(result.target);
    return Surface(
      padding: EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  result.subject.name,
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Tag(
                end.held == 0
                    ? 'NO BASELINE'
                    : good
                    ? 'AT TARGET'
                    : 'BELOW TARGET',
                color: end.held == 0
                    ? tone(context, muted)
                    : good
                    ? tone(context, green)
                    : tone(context, amber),
              ),
            ],
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Text(
                percentage(result.start),
                style: TextStyle(fontSize: 21, color: tone(context, muted)),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 14),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  size: 19,
                  color: tone(context, muted),
                ),
              ),
              Text(
                percentage(end),
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: good ? tone(context, green) : tone(context, amber),
                ),
              ),
              Spacer(),
              Text(
                '${end.attended}/${end.held}',
                style: TextStyle(fontSize: 13, color: tone(context, muted)),
              ),
            ],
          ),
          SizedBox(height: 10),
          Text(
            result.dipsBelow
                ? 'Dips below ${result.target}% during this plan. Lowest: ${result.lowest?.toStringAsFixed(1)}%.'
                : 'Stays at or above ${result.target}% across this plan.',
            style: TextStyle(
              color: result.dipsBelow
                  ? tone(context, amber)
                  : tone(context, green),
              fontSize: 12,
            ),
          ),
          if (!good && end.held > 0)
            Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                'After this plan: attend ${end.recover(result.target)} more consecutive classes to reach ${result.target}%.',
                style: TextStyle(color: tone(context, muted), fontSize: 12),
              ),
            ),
          if (!good && end.held > 0)
            Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                recovery == null
                    ? 'Recovery is not possible within the known remaining timetable (checked up to one year).'
                    : 'Earliest recovery: ${longDate(recovery!)} if every remaining scheduled class is held and attended.',
                style: TextStyle(
                  color: tone(context, muted),
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            ),
          if (result.start.held == 0)
            Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                'No starting records. This projection covers future sessions only.',
                style: TextStyle(color: tone(context, amber), fontSize: 12),
              ),
            ),
          if (result.steps.isNotEmpty)
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              title: Text(
                'Show ${result.steps.length} planned sessions',
                style: TextStyle(fontSize: 12, color: tone(context, muted)),
              ),
              children: [
                for (final step in result.steps)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${shortDate(step.session.starts)} · ${step.action.name}',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                        Text(
                          '${step.counts.attended}/${step.counts.held} · ${percentage(step.counts)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: step.counts.eligible(result.target)
                                ? tone(context, green)
                                : tone(context, amber),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
