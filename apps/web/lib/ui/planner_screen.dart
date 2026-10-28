import 'package:flutter/material.dart' hide Baseline;
import 'package:intl/intl.dart';
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
  late DateTime from = dayOnly(DateTime.now()).add(const Duration(days: 1));
  late DateTime until = DateTime(from.year, from.month, from.day + 6);
  Baseline baseline = Baseline.official;
  int target = 75, step = 0;
  String name = 'My leave plan';
  String? savedId, scope;
  DateTime? selectedDay;
  final scroll = ScrollController();
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
  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  void go(int value) {
    setState(() => step = value);
    if (scroll.hasClients) scroll.jumpTo(0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && scroll.hasClients) scroll.jumpTo(0);
    });
  }

  void load(Scenario p) {
    setState(() {
      savedId = p.id;
      name = p.name;
      from = p.from;
      until = p.until;
      baseline = p.baseline;
      target = p.target;
      actions = {...p.actions};
      extras = [...p.extras];
      selectedDay = from;
    });
    go(0);
  }

  void reset() {
    setState(() {
      from = dayOnly(DateTime.now()).add(const Duration(days: 1));
      until = DateTime(from.year, from.month, from.day + 6);
      actions = {};
      extras = [];
      savedId = null;
      name = 'My leave plan';
      baseline = Baseline.official;
      target = 75;
      selectedDay = from;
    });
    go(0);
  }

  Future<void> chooseRange() async {
    final tomorrow = dayOnly(DateTime.now()).add(const Duration(days: 1));
    final range = await showDateRangePicker(
      context: context,
      firstDate: tomorrow,
      lastDate: tomorrow.add(const Duration(days: 365)),
      initialDateRange: from.isBefore(tomorrow)
          ? null
          : DateTimeRange(start: from, end: until),
      helpText: 'Choose the period to simulate',
    );
    if (range == null || !mounted) return;
    if (range.end.difference(range.start).inDays >= 120) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Choose up to 120 days.')));
      return;
    }
    setState(() {
      from = range.start;
      until = range.end;
      selectedDay = from;
    });
  }

  Future<void> save() async {
    final value = await askText(context, 'Save leave plan', initial: name);
    if (value == null || !mounted) return;
    setState(() => name = value);
    final snapshot = plan;
    try {
      await widget.controller.saveScenario(snapshot);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save this plan. Please try again.'),
          ),
        );
      }
      return;
    }
    if (mounted) {
      setState(() => savedId = snapshot.id);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Plan saved. Your attendance has not changed.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.controller.data;
    if (scope != widget.controller.scope) {
      scope = widget.controller.scope;
      actions = {};
      extras = [];
      savedId = null;
      step = 0;
      selectedDay = null;
      baseline = Baseline.official;
      target = 75;
      name = 'My leave plan';
      from = dayOnly(DateTime.now()).add(const Duration(days: 1));
      until = DateTime(from.year, from.month, from.day + 6);
    }
    final scenario = plan;
    final sessions = plannedSessions(data, scenario);
    final stale = from.isBefore(
      dayOnly(DateTime.now()).add(const Duration(days: 1)),
    );
    final canPlan = data.subjects.isNotEmpty && sessions.isNotEmpty && !stale;
    return ListView(
      controller: scroll,
      padding: const EdgeInsets.all(24),
      children: [
        const Heading(
          'Try a leave plan',
          'What if?',
          'Choose your dates, mark what you’ll miss, and see each subject’s attendance. Your real records stay unchanged.',
        ),
        Row(
          children: [
            for (var i = 0; i < 3; i++)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: TextButton(
                    onPressed: i == 0 || canPlan ? () => go(i) : null,
                    style: TextButton.styleFrom(
                      backgroundColor: step == i
                          ? Theme.of(context).colorScheme.secondaryContainer
                          : null,
                      foregroundColor: step == i
                          ? Theme.of(context).colorScheme.onSecondaryContainer
                          : null,
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                        horizontal: 2,
                      ),
                    ),
                    child: Text(
                      ['1 · Dates', '2 · Classes', '3 · Results'][i],
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 20),
        if (step == 0) ..._setup(data, sessions, stale),
        if (step == 1) ..._classes(data, scenario, sessions),
        if (step == 2) ..._results(data, scenario, sessions),
        const SizedBox(height: 24),
        Wrap(
          alignment: WrapAlignment.end,
          spacing: 12,
          runSpacing: 8,
          children: [
            if (step > 0)
              OutlinedButton.icon(
                onPressed: () => go(step - 1),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Back'),
              ),
            if (step < 2)
              FilledButton.icon(
                onPressed: canPlan ? () => go(step + 1) : null,
                icon: Icon(
                  step == 0 ? Icons.arrow_forward : Icons.insights_outlined,
                ),
                label: Text(step == 0 ? 'Choose classes' : 'See results'),
              ),
            if (step == 2)
              FilledButton.icon(
                onPressed: stale ? null : save,
                icon: const Icon(Icons.bookmark_outline),
                label: const Text('Save plan'),
              ),
          ],
        ),
        const SizedBox(height: 28),
      ],
    );
  }

  List<Widget> _setup(AppData data, List<Session> sessions, bool stale) => [
    Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'When are you planning?',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text(
            'Include the days off and any later classes you plan to attend.',
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final days in [7, 14])
                ActionChip(
                  label: Text('Next $days days'),
                  onPressed: () => setState(() {
                    from = dayOnly(DateTime.now()).add(const Duration(days: 1));
                    until = DateTime(
                      from.year,
                      from.month,
                      from.day + days - 1,
                    );
                    selectedDay = from;
                  }),
                ),
              ActionChip(
                avatar: const Icon(Icons.date_range, size: 18),
                label: const Text('Choose dates'),
                onPressed: chooseRange,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            '${longDate(from)} → ${longDate(until)}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            '${sessions.fold<int>(0, (n, s) => n + s.weight)} scheduled classes in this period',
            style: TextStyle(color: tone(context, muted)),
          ),
          const Divider(height: 32),
          Text('Start with', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          SegmentedButton<Baseline>(
            segments: const [
              ButtonSegment(value: Baseline.official, label: Text('IMS only')),
              ButtonSegment(
                value: Baseline.personal,
                label: Text('IMS + my logs'),
              ),
            ],
            selected: {baseline},
            onSelectionChanged: (v) => setState(() => baseline = v.first),
          ),
          const SizedBox(height: 12),
          Text(
            baseline == Baseline.official
                ? 'Uses the attendance currently uploaded to IMS.'
                : 'Adds your logs only for days IMS hasn’t recorded yet. Each class counts once.',
            style: TextStyle(color: tone(context, muted), fontSize: 13),
          ),
        ],
      ),
    ),
    const SizedBox(height: 14),
    if (data.subjects.isEmpty)
      const Empty(
        'Fetch your attendance first',
        'Your subjects are needed to calculate a leave plan.',
      ),
    if (data.timetable.isEmpty)
      Surface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Set up your timetable first',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your timetable tells us which subjects you would miss on a day off.',
            ),
            TextButton.icon(
              onPressed: () => openTimetable(context, widget.controller),
              icon: const Icon(Icons.calendar_view_week),
              label: const Text('Set up timetable'),
            ),
          ],
        ),
      ),
    if (data.timetable.isNotEmpty)
      TextButton.icon(
        onPressed: () => openTimetable(context, widget.controller),
        icon: const Icon(Icons.edit_calendar_outlined),
        label: const Text('Check or edit timetable'),
      ),
    if (stale)
      const Text(
        'This saved plan includes past dates. Choose new dates to calculate a future plan.',
      ),
    if (data.scenarios.isNotEmpty)
      ExpansionTile(
        title: const Text('Saved plans'),
        subtitle: const Text(
          'Open a plan to adjust it with your latest attendance.',
        ),
        children: [
          for (final saved in data.scenarios)
            ListTile(
              title: Text(saved.name),
              subtitle: Text(
                '${shortDate(saved.from)} – ${shortDate(saved.until)}',
              ),
              onTap: () => load(saved),
              trailing: IconButton(
                tooltip: 'Delete ${saved.name}',
                icon: const Icon(Icons.delete_outline),
                onPressed: () => safely(
                  context,
                  () => widget.controller.deleteScenario(saved.id),
                ),
              ),
            ),
        ],
      ),
  ];

  List<Widget> _classes(
    AppData data,
    Scenario scenario,
    List<Session> sessions,
  ) {
    final days = [
      for (
        var d = from;
        !d.isAfter(until);
        d = DateTime(d.year, d.month, d.day + 1)
      )
        d,
    ];
    final day =
        selectedDay != null &&
            !selectedDay!.isBefore(from) &&
            !selectedDay!.isAfter(until)
        ? selectedDay!
        : from;
    final todaySessions = sessions
        .where((s) => dateKey(s.starts) == dateKey(day))
        .toList();
    final choices = todaySessions
        .expand((s) => sessionActions(scenario, s))
        .toList();
    final off =
        choices.isNotEmpty &&
        choices.every((a) => a == PlanAction.miss || a == PlanAction.cancel) &&
        choices.contains(PlanAction.miss);
    final holiday =
        choices.isNotEmpty && choices.every((a) => a == PlanAction.cancel);
    void markDay(PlanAction action) => setState(() {
      for (final s in todaySessions) {
        setSessionAction(actions, s, action);
      }
    });
    return [
      Text(
        'Mark what you’ll miss',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 8),
      const Text(
        'Everything starts as Attend. Pick a day off, or change individual classes. Other classes in this period are assumed attended.',
      ),
      const SizedBox(height: 16),
      SizedBox(
        height: 80,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: days.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (context, i) {
            final d = days[i];
            final values = sessions
                .where((s) => dateKey(s.starts) == dateKey(d))
                .expand((s) => sessionActions(scenario, s));
            final missed = values.where((a) => a == PlanAction.miss).length;
            return ChoiceChip(
              label: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${DateFormat('EEE').format(d)} · ${shortDate(d)}'),
                  const SizedBox(height: 3),
                  Text(
                    missed > 0
                        ? '$missed missed'
                        : values.isEmpty
                        ? 'No classes'
                        : 'Attend',
                    style: const TextStyle(fontSize: 11),
                  ),
                ],
              ),
              selected: dateKey(day) == dateKey(d),
              onSelected: (_) => setState(() => selectedDay = d),
            );
          },
        ),
      ),
      const SizedBox(height: 14),
      Surface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(longDate(day), style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            if (todaySessions.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilterChip(
                    label: const Text('Day off'),
                    selected: off,
                    onSelected: (v) => setState(() {
                      for (final s in todaySessions) {
                        final previous = sessionActions(scenario, s);
                        for (var i = 0; i < previous.length; i++) {
                          if (previous[i] != PlanAction.cancel) {
                            actions[planClassKey(s, i)] = v
                                ? PlanAction.miss
                                : PlanAction.attend;
                          }
                        }
                      }
                    }),
                  ),
                  FilterChip(
                    label: const Text('Holiday / no classes'),
                    selected: holiday,
                    onSelected: (v) =>
                        markDay(v ? PlanAction.cancel : PlanAction.attend),
                  ),
                  TextButton(
                    onPressed: () => markDay(PlanAction.attend),
                    child: const Text('Reset day'),
                  ),
                ],
              ),
            if (todaySessions.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text('No classes in your saved timetable for this day.'),
              ),
            for (final s in todaySessions) _session(data, scenario, s),
          ],
        ),
      ),
      const SizedBox(height: 14),
      TextButton.icon(
        onPressed: () => addExtra(context, data),
        icon: const Icon(Icons.add),
        label: const Text('Add an expected extra class'),
      ),
      TextButton.icon(
        onPressed: () => openTimetable(context, widget.controller),
        icon: const Icon(Icons.edit_calendar_outlined),
        label: const Text('Edit timetable'),
      ),
    ];
  }

  Widget _session(AppData data, Scenario scenario, Session session) {
    final choices = sessionActions(scenario, session);
    final extra = extras.any((e) => e.id == session.id);
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(),
          Row(
            children: [
              Expanded(
                child: Text(
                  data.subjectLabel(session.subject),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              if (extra)
                IconButton(
                  tooltip: 'Remove extra class',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => setState(() {
                    extras.removeWhere((e) => e.id == session.id);
                    setSessionAction(actions, session, PlanAction.attend);
                  }),
                ),
            ],
          ),
          Text(
            '${TimeOfDay.fromDateTime(session.starts).format(context)} · ${session.weight} ${session.weight == 1 ? 'class' : 'classes'}${extra ? ' · Extra' : ''}',
            style: TextStyle(color: tone(context, muted), fontSize: 12),
          ),
          for (var i = 0; i < choices.length; i++)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (choices.length > 1)
                    Text(
                      'Class ${i + 1}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      for (final action in PlanAction.values)
                        ChoiceChip(
                          label: Text(switch (action) {
                            PlanAction.attend => 'Attend',
                            PlanAction.miss => 'Miss',
                            PlanAction.cancel => 'Not held',
                          }),
                          key: ValueKey('plan-${session.id}-$i-${action.name}'),
                          selected: choices[i] == action,
                          onSelected: (_) => setState(
                            () => actions[planClassKey(session, i)] = action,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _results(
    AppData data,
    Scenario scenario,
    List<Session> sessions,
  ) {
    final results = project(data, scenario);
    final choices = sessions
        .expand((s) => sessionActions(scenario, s))
        .toList();
    final missed = choices.where((a) => a == PlanAction.miss).length;
    final attended = choices.where((a) => a == PlanAction.attend).length;
    final cancelled = choices.where((a) => a == PlanAction.cancel).length;
    final below = results
        .where((r) => r.end.held > 0 && !r.end.eligible(target))
        .length;
    final dips = results.any((r) => r.dipsBelow && r.end.eligible(target));
    final missing = data.subjects.where(
      (s) => s.official.held > 0 && !sessions.any((x) => x.subject == s.code),
    );
    final uncovered =
        [
              for (
                var d = from;
                !d.isAfter(until);
                d = DateTime(d.year, d.month, d.day + 1)
              )
                d,
            ]
            .where(
              (d) =>
                  d.weekday <= 5 &&
                  !data.timetable.any(
                    (r) =>
                        !d.isBefore(dayOnly(r.from)) &&
                        !d.isAfter(dayOnly(r.until)),
                  ),
            )
            .length;
    return [
      Surface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Here’s how your plan looks',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            Text(
              '${shortDate(from)} – ${shortDate(until)} · ${baseline == Baseline.official ? 'IMS only' : 'IMS + my logs'}',
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Tag('$attended attend'),
                Tag('$missed miss', color: missed > 0 ? amber : green),
                Tag('$cancelled not held', color: muted),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              results.every((r) => r.end.held == 0)
                  ? 'No attendance available to calculate a percentage.'
                  : below > 0
                  ? '$below ${below == 1 ? 'subject ends' : 'subjects end'} below $target%.'
                  : 'Every subject with attendance ends at or above $target%.',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: tone(context, below > 0 ? amber : green),
              ),
            ),
            if (dips)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Some subjects fall below the target before recovering. Check their details below.',
                ),
              ),
            const SizedBox(height: 10),
            const Text(
              'These are estimates from your saved timetable. Each subject is checked separately.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
      if (uncovered > 0)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(
            '$uncovered weekdays are outside your saved timetable’s date range. Classes on those dates are not included.',
            style: TextStyle(color: tone(context, amber)),
          ),
        ),
      if (missing.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(
            'No classes found in this period for ${missing.map((s) => s.label).join(', ')}. Their percentages stay unchanged.',
            style: TextStyle(color: tone(context, muted), fontSize: 12),
          ),
        ),
      const SizedBox(height: 18),
      for (final result in results)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: ProjectionCard(result),
        ),
      ExpansionTile(
        title: const Text('More options'),
        subtitle: const Text(
          'Different target, leave suggestions, and comparisons',
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: AppDropdown<int>(
              value: target,
              items: [
                for (final p in [75, 80, 85, 90, 95])
                  DropdownMenuItem(value: p, child: Text('Target: $p%')),
              ],
              onChanged: (v) => setState(() => target = v!),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.travel_explore),
            title: const Text('Find possible days off'),
            onTap: sessions.isEmpty
                ? null
                : () => findDays(context, data, scenario),
          ),
          if (data.scenarios.isNotEmpty)
            ListTile(
              leading: const Icon(Icons.compare_arrows),
              title: const Text('Compare with a saved plan'),
              onTap: () => comparePlans(context, data, scenario),
            ),
          ListTile(
            leading: const Icon(Icons.restart_alt),
            title: const Text('Start a new plan'),
            onTap: reset,
          ),
        ],
      ),
    ];
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
                    trailing: const Icon(Icons.arrow_forward),
                    onTap: () {
                      final sessions = plannedSessions(
                        data,
                        scenario,
                      ).where((s) => dateKey(s.starts) == dateKey(day));
                      setState(() {
                        for (final s in sessions) {
                          final choices = sessionActions(scenario, s);
                          for (var i = 0; i < choices.length; i++) {
                            if (choices[i] != PlanAction.cancel) {
                              actions[planClassKey(s, i)] = PlanAction.miss;
                            }
                          }
                        }
                        selectedDay = day;
                      });
                      Navigator.pop(context);
                      go(1);
                    },
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
    DateTime date =
        selectedDay != null &&
            !selectedDay!.isBefore(from) &&
            !selectedDay!.isAfter(until)
        ? selectedDay!
        : from;
    var time = const TimeOfDay(hour: 17, minute: 0);
    int count = 1;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, set) => AlertDialog(
          title: Text('Expected extra class'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Add a class you expect to happen. This changes only your plan.',
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
                TextButton.icon(
                  onPressed: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: time,
                    );
                    if (picked != null) set(() => time = picked);
                  },
                  icon: const Icon(Icons.schedule),
                  label: Text(time.format(context)),
                ),
                AppDropdown<int>(
                  value: count,
                  items: [
                    for (var n = 1; n <= 8; n++)
                      DropdownMenuItem(
                        value: n,
                        child: Text('$n ${n == 1 ? 'class' : 'classes'}'),
                      ),
                  ],
                  onChanged: (v) => set(() => count = v!),
                ),
              ],
            ),
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
    if (result == true && mounted) {
      selectedDay = date;
      setState(
        () => extras.add(
          Session(
            id: 'hypothetical-${DateTime.now().microsecondsSinceEpoch}',
            subject: code,
            starts: DateTime(
              date.year,
              date.month,
              date.day,
              time.hour,
              time.minute,
            ),
            weight: count,
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
    final end = result.end;
    final good = end.held > 0 && end.eligible(result.target);
    final color = tone(
      context,
      end.held == 0
          ? muted
          : good
          ? green
          : amber,
    );
    return Surface(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            result.subject.label,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 20,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Now',
                    style: TextStyle(fontSize: 12, color: tone(context, muted)),
                  ),
                  Text(
                    percentage(result.start),
                    style: const TextStyle(fontSize: 24),
                  ),
                ],
              ),
              const Icon(Icons.arrow_forward_rounded, size: 20),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'After plan',
                    style: TextStyle(fontSize: 12, color: tone(context, muted)),
                  ),
                  Text(
                    percentage(end),
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '${end.attended} attended / ${end.held} held after this plan',
            style: TextStyle(color: tone(context, muted), fontSize: 12),
          ),
          const SizedBox(height: 12),
          if (end.held == 0)
            const Text(
              'No recorded or planned classes to calculate a percentage.',
            )
          else if (!good)
            Text(
              'Attend ${end.recover(result.target)} more consecutive classes to reach ${result.target}%.',
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            )
          else
            Text(
              'You could miss ${end.canMiss(result.target)} more ${end.canMiss(result.target) == 1 ? 'class' : 'classes'} and stay at ${result.target}% or above.',
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
          if (result.steps.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'No classes for this subject in the selected period.',
              ),
            ),
          if (result.dipsBelow && end.held > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                result.start.held > 0 && !result.start.eligible(result.target)
                    ? 'Starts below ${result.target}%. ${good ? 'Recovers by the end of the plan.' : 'Still below at the end.'}'
                    : 'Falls below ${result.target}% during the plan, even if it recovers later.',
                style: TextStyle(color: tone(context, amber), fontSize: 12),
              ),
            ),
          if (result.steps.isNotEmpty)
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text(
                'Class-by-class breakdown',
                style: TextStyle(fontSize: 13),
              ),
              children: [
                for (final step in result.steps)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      '${shortDate(step.session.starts)} · ${TimeOfDay.fromDateTime(step.session.starts).format(context)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    subtitle: Text(
                      '${switch (step.action) {
                        PlanAction.attend => 'Attend',
                        PlanAction.miss => 'Miss',
                        PlanAction.cancel => 'Not held',
                      }}${step.session.weight > 1 ? ' · ${step.session.weight} classes' : ''}${step.session.note.isEmpty ? '' : ' · ${step.session.note}'}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: Text(
                      '${step.counts.attended}/${step.counts.held} · ${percentage(step.counts)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
