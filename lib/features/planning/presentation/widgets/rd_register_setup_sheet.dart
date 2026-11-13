import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/providers/conductor_providers.dart';
import '../../../../core/providers/group_providers.dart';
import '../../../../core/providers/player_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/services/error_reporter.dart';
import '../../../../core/services/register_plan_service.dart';
import '../../../../core/theme/redesign/rd_theme.dart';
import '../../../../core/utils/plan_utils.dart';
import '../../../../data/models/instrument/instrument.dart';
import '../../../../data/models/person/person.dart';
import '../../../../data/models/plan/plan.dart' show RegisterPlanSettings;
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';
import '../../../redesign/presentation/widgets/rd_widgets.dart';
import 'rd_plan_widgets.dart';
import 'register_plan_sheet.dart' show RegisterPlanChoice;

/// Beta Ablauf › Hinzufügen › Registerprobe: asks in the order a conductor
/// thinks (how long, which groups, who leads) and shows the rounds right
/// away. Groups and leads are chips that are switched on and off; the
/// category of the main group (the conductors) is never offered as a group.
class RdRegisterSetupSheet extends ConsumerStatefulWidget {
  const RdRegisterSetupSheet({super.key, this.initial, this.initialMinutes, this.startMinutes, this.subtitle});

  /// Change an existing Registerprobe ("Übernehmen").
  final RegisterPlanSettings? initial;
  final num? initialMinutes;

  /// Clock time of the block's start (minutes after midnight), for the
  /// rounds' times; null shows minutes from the start.
  final int? startMinutes;
  final String? subtitle;

  @override
  ConsumerState<RdRegisterSetupSheet> createState() => _RdRegisterSetupSheetState();
}

class _RdRegisterSetupSheetState extends ConsumerState<RdRegisterSetupSheet> {
  final List<String> _groupOptions = [];
  final Set<String> _groupOn = {};

  /// All leads in the drawn order ("Neu mischen" draws again); the
  /// selected ones lead in this order.
  final List<String> _leadOrder = [];
  final Set<String> _leadOn = {};
  late final _minutesController = TextEditingController(text: _fmt(widget.initialMinutes ?? 60));
  bool _loading = true;
  bool _choosing = false;

  static String _fmt(num m) => m == m.roundToDouble() ? '${m.round()}' : '$m';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _minutesController.dispose();
    super.dispose();
  }

  Future<T> _read<T>(Future<T> Function() load, T fallback) async {
    try {
      return await load();
    } catch (e, st) {
      ErrorReporter.report(e, st, where: 'rd_register_setup_sheet');
      return fallback;
    }
  }

  Future<void> _load() async {
    final l10n = l10nWithoutContext;
    final tenant = ref.read(currentTenantProvider);
    final categories = await _read(() => ref.read(groupCategoriesProvider.future), const <GroupCategory>[]);
    final groups = await _read(() => ref.read(groupsProvider.future), const <Group>[]);
    final conductors = await _read(() => ref.read(conductorsProvider.future), const <Person>[]);
    final leadCategories = RegisterPlanService.conductorCategoryIds(groups);
    final leadCategoryNames = {for (final c in categories) if (leadCategories.contains(c.id)) c.name.trim()};
    final defaults = RegisterPlanService.defaultGroups(
      categoryNames: [for (final c in categories) if (!leadCategories.contains(c.id)) c.name],
      isChoir: tenant?.type == 'choir',
      choirDefaults: [l10n.planningSoprano, l10n.planningAlto, l10n.planningTenor, l10n.planningBass],
      otherDefaults: [l10n.planningStrings, l10n.planningWoodwinds, l10n.commonOtherPlural],
    );
    final initial = widget.initial;
    List<String> selected;
    if (initial != null) {
      selected = [...initial.groups];
    } else {
      String? stored;
      if (tenant?.id != null) {
        try {
          final prefs = await SharedPreferences.getInstance();
          stored = prefs.getString(RegisterPlanService.groupsStorageKey(tenant!.id!));
        } catch (_) {}
      }
      // The last choice, without the conductors (stored before they were
      // left out).
      selected = [
        for (final g in RegisterPlanService.parseStoredGroups(stored, defaults))
          if (g.trim().isNotEmpty && !leadCategoryNames.contains(g.trim())) g,
      ];
      if (selected.length < 2) selected = [...defaults];
    }
    final names = RegisterPlanService.conductorNames(conductors);
    final leads = initial != null ? [...initial.conductors] : RegisterPlanService.shuffle(names);
    if (!mounted) return;
    setState(() {
      for (final g in [...defaults, ...selected]) {
        if (!_groupOptions.contains(g)) _groupOptions.add(g);
      }
      _groupOn.addAll(selected);
      for (final c in [...leads, ...names]) {
        if (c.trim().isNotEmpty && !_leadOrder.contains(c)) _leadOrder.add(c);
      }
      _leadOn.addAll(leads.where((c) => c.trim().isNotEmpty));
      _loading = false;
    });
  }

  List<String> get _groups => [for (final g in _groupOptions) if (_groupOn.contains(g)) g];
  List<String> get _leads => [for (final c in _leadOrder) if (_leadOn.contains(c)) c];
  num get _minutes => num.tryParse(_minutesController.text.trim()) ?? 0;

  bool get _ready =>
      !RegisterPlanService.isExportDisabled(
        conductors: _leads,
        groups: _groups,
        time: _minutesController.text.trim(),
      ) &&
      _minutes > 0;

  Future<void> _addGroup() async {
    final l10n = context.l10n;
    final name = await showRdPlanTextSheet(
      context,
      title: l10n.redesignPlanRegisterOwnGroupTitle,
      hint: l10n.redesignPlanRegisterOwnGroupHint,
      confirmText: l10n.rdTypeAdd,
    );
    final value = name?.trim() ?? '';
    if (value.isEmpty || !mounted) return;
    setState(() {
      if (!_groupOptions.contains(value)) _groupOptions.add(value);
      _groupOn.add(value);
    });
  }

  Future<void> _addLead() async {
    final l10n = context.l10n;
    final name = await showRdPlanSheet<String>(
      context,
      title: l10n.redesignPlanRegisterPersonTitle,
      builder: (ctx, pop) => [_RdLeadPicker(taken: {..._leadOrder}, onPick: pop)],
    );
    final value = name?.trim() ?? '';
    if (value.isEmpty || !mounted) return;
    setState(() {
      if (!_leadOrder.contains(value)) _leadOrder.add(value);
      _leadOn.add(value);
    });
  }

  Future<void> _choose() async {
    // Once: a second tap while the groups are stored would close the page below.
    if (_choosing || !_ready) return;
    _choosing = true;
    final choice = RegisterPlanChoice(groups: _groups, conductors: _leads, minutes: _minutes);
    final tenantId = ref.read(currentTenantProvider)?.id;
    if (tenantId != null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          RegisterPlanService.groupsStorageKey(tenantId),
          RegisterPlanService.encodeGroups(choice.groups),
        );
      } catch (_) {}
    }
    if (!mounted) return;
    Navigator.pop(context, choice);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    return Material(
      color: p.bg,
      child: SafeArea(
        child:
            _loading
                ? const Center(child: AppSpinner())
                : ListView(
                  padding: EdgeInsets.fromLTRB(20, 12, 20, 32 + MediaQuery.viewInsetsOf(context).bottom),
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Semantics(
                            header: true,
                            child: Text(l10n.redesignPlanRegister, style: RdType.title(p)),
                          ),
                        ),
                        RdCircleButton(
                          icon: Icons.close,
                          label: l10n.commonClose,
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    if ((widget.subtitle ?? '').isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(widget.subtitle!, style: RdType.meta(p, size: 15)),
                    ],
                    const SizedBox(height: 16),
                    RdGroupLabel(l10n.redesignPlanRegisterDuration),
                    _duration(context),
                    const SizedBox(height: 16),
                    RdGroupLabel(l10n.redesignPlanRegisterWhichGroups),
                    _chips([
                      for (final g in _groupOptions)
                        RdChoiceChip(
                          key: ValueKey('rd-register-group-$g'),
                          label: g,
                          selected: _groupOn.contains(g),
                          onTap: () => setState(() => _groupOn.contains(g) ? _groupOn.remove(g) : _groupOn.add(g)),
                        ),
                      RdChoiceChip(
                        key: const Key('rd-register-add-group'),
                        icon: Icons.add,
                        label: l10n.redesignPlanRegisterOwnGroup,
                        selected: false,
                        onTap: _addGroup,
                      ),
                    ]),
                    const SizedBox(height: 16),
                    RdGroupLabel(l10n.redesignPlanRegisterWhoLeads),
                    _chips([
                      for (final c in _leadOrder)
                        RdChoiceChip(
                          key: ValueKey('rd-register-lead-$c'),
                          label: c,
                          selected: _leadOn.contains(c),
                          onTap: () => setState(() => _leadOn.contains(c) ? _leadOn.remove(c) : _leadOn.add(c)),
                        ),
                      RdChoiceChip(
                        key: const Key('rd-register-add-lead'),
                        icon: Icons.add,
                        label: l10n.redesignPlanRegisterPerson,
                        selected: false,
                        onTap: _addLead,
                      ),
                    ]),
                    const SizedBox(height: 16),
                    ..._preview(context),
                    const SizedBox(height: 24),
                    RdPrimaryButton(
                      key: const Key('rd-register-insert'),
                      icon: widget.initial == null ? Icons.add : Icons.check,
                      label:
                          widget.initial == null ? l10n.redesignPlanRegisterInsert : l10n.redesignPlanRegisterApply,
                      onPressed: _ready ? _choose : null,
                    ),
                  ],
                ),
      ),
    );
  }

  Widget _chips(List<Widget> chips) =>
      RdCard(padding: const EdgeInsets.all(12), child: Wrap(spacing: 8, runSpacing: 8, children: chips));

  Widget _duration(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    void step(int delta) => setState(() {
      final next = (_minutes + delta).clamp(0, 999);
      _minutesController.text = _fmt(next);
    });
    Widget stepButton(IconData icon, String label, int delta) => Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: p.soft,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => step(delta),
          child: SizedBox(width: 44, height: 44, child: Icon(icon, color: p.softText)),
        ),
      ),
    );
    return RdCard(
      child: Row(
        children: [
          stepButton(Icons.remove, l10n.redesignPlanLess, -5),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _minutesController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: p.text),
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor: p.bg,
                suffixText: l10n.redesignPlanMinUnit,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 8),
          stepButton(Icons.add, l10n.redesignPlanMore5, 5),
        ],
      ),
    );
  }

  /// The rounds as they will be inserted: one card row per round with its
  /// time span and who leads which group.
  List<Widget> _preview(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final groups = _groups;
    final leads = _leads;
    final plan =
        _ready ? RegisterPlanService.generate(conductors: leads, groups: groups, totalMinutes: _minutes) : null;
    final lengths = plan == null ? const <int>[] : RegisterPlanService.roundMinutes(plan, _minutes);
    String at(int minute) {
      final start = widget.startMinutes;
      return start == null ? '$minute' : PlanUtils.formatMinutes(start + minute);
    }

    String span(int i) {
      final from = int.tryParse(plan!.rows[i].first) ?? 0;
      final range = '${at(from)} – ${at(from + lengths[i])}';
      return widget.startMinutes == null ? '$range ${l10n.redesignPlanMinUnit}' : range;
    }

    final extraGroups = groups.length - leads.length;
    final hint =
        plan == null
            ? l10n.redesignPlanRegisterIncomplete
            : extraGroups > 0
            ? l10n.redesignPlanRegisterMoreGroups(extraGroups)
            : extraGroups < 0
            ? l10n.redesignPlanRegisterMoreLeads(-extraGroups)
            : null;
    return [
      Row(
        children: [
          Expanded(child: RdGroupLabel(l10n.redesignPlanRegisterPreview(plan?.rows.length ?? 0))),
          TextButton.icon(
            key: const Key('rd-register-shuffle'),
            onPressed:
                leads.length < 2
                    ? null
                    : () => setState(() {
                      final order = RegisterPlanService.shuffle(_leadOrder);
                      _leadOrder
                        ..clear()
                        ..addAll(order);
                    }),
            icon: const Icon(Icons.shuffle, size: 18),
            label: Text(l10n.redesignPlanRegisterShuffle),
          ),
        ],
      ),
      if (hint != null)
        Padding(padding: const EdgeInsets.fromLTRB(4, 0, 4, 8), child: Text(hint, style: RdType.meta(p, size: 14))),
      if (plan != null)
        RdCard(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < plan.rows.length; i++)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    border: i == 0 ? null : Border(top: BorderSide(color: p.line)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        span(i),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: p.softText,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(height: 4),
                      for (var g = 0; g < plan.groups.length; g++)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: Text(plan.groups[g], style: TextStyle(fontSize: 14, color: p.text2))),
                              const SizedBox(width: 12),
                              Expanded(
                                child:
                                    plan.rows[i][g + 1].trim().isEmpty
                                        ? Text(
                                          l10n.redesignPlanRegisterSelf,
                                          style: TextStyle(fontSize: 14, color: p.text2, fontStyle: FontStyle.italic),
                                        )
                                        : Text(
                                          plan.rows[i][g + 1],
                                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: p.text),
                                        ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
    ];
  }
}

/// "+ Person": the group's members to pick a further lead (e.g. a
/// Registerführer), or the typed name.
class _RdLeadPicker extends ConsumerStatefulWidget {
  const _RdLeadPicker({required this.taken, required this.onPick});

  final Set<String> taken;
  final void Function(String name) onPick;

  @override
  ConsumerState<_RdLeadPicker> createState() => _RdLeadPickerState();
}

class _RdLeadPickerState extends ConsumerState<_RdLeadPicker> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final query = _search.text.trim().toLowerCase();
    final people = ref.watch(playersProvider).valueOrNull ?? const <Person>[];
    final matches = [
      for (final person in people)
        if (person.left == null &&
            '${person.firstName} ${person.lastName}'.toLowerCase().contains(query))
          (full: '${person.firstName} ${person.lastName}'.trim(), short: RegisterPlanService.conductorNames([person]).first),
    ].where((m) => !widget.taken.contains(m.short)).take(40).toList();
    final typed = _search.text.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const Key('rd-register-person-search'),
          controller: _search,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            hintText: l10n.redesignPlanRegisterPersonSearch,
            prefixIcon: const Icon(Icons.search),
            isDense: true,
            filled: true,
            fillColor: p.surface,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onChanged: (_) => setState(() {}),
          onSubmitted: (v) {
            if (v.trim().isNotEmpty) widget.onPick(v.trim());
          },
        ),
        const SizedBox(height: 12),
        RdGroupedList(
          children: [
            if (typed.isNotEmpty)
              RdListRow(
                leading: Icon(Icons.add, color: p.link),
                title: l10n.redesignPlanRegisterPersonUse(typed),
                titleColor: p.link,
                showChevron: false,
                onTap: () => widget.onPick(typed),
              ),
            for (final m in matches)
              RdListRow(
                leading: const RdRowIcon(Icons.person_outline),
                title: m.full,
                showChevron: false,
                onTap: () => widget.onPick(m.short),
              ),
          ],
        ),
      ],
    );
  }
}
