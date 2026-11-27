part of 'general_settings_page.dart';

/// Critical-rule configuration, evaluation status, and rule list widgets for
/// [RdTenantSettingsBlock].
extension _RdCriticalSettings on _RdTenantSettingsBlockState {
  List<CriticalRule> _rules(Tenant t) => [...?t.criticalRules];

  Future<void> _saveRules(Tenant t, List<CriticalRule> rules, String toast) async {
    // Stored and local list are the same normalised rules (e.g. a legacy
    // rule without period is saved with its default period).
    final json = rules.map(criticalRuleToJson).toList();
    final normalised = json.map(CriticalRule.fromJson).toList();
    final ok = await _save(
      t.id,
      {'critical_rules': json},
      (c) => c.copyWith(criticalRules: normalised),
      // Ionic re-evaluates the Problemfall rules right away.
      evaluate: true,
    );
    if (ok && mounted) ToastHelper.showSuccess(context, toast);
  }

  /// The rules as the list shows them: the "und" parts as one rule.
  List<List<CriticalRule>> _groups(Tenant t) => rdCriticalRuleGroups(_rules(t));

  /// [index] is a rule of the list ([_groups]), null for a new one.
  Future<void> _ruleSheet(Tenant t, {int? index}) async {
    final l10n = context.l10n;
    final types = await _load(attendanceTypesProvider);
    if (types == null || !mounted) return;
    if (index == null && types.isEmpty) {
      ToastHelper.showError(context, l10n.generalSettingsFlutterNoTypes);
      return;
    }
    final groups = _groups(t);
    final old = index == null || index >= groups.length ? const <CriticalRule>[] : groups[index];
    // The server knows one "und" rule per group: another rule can't get one.
    final combined = groups.where((g) => rdCriticalIsAndGroup(g) && !identical(g, old)).firstOrNull;
    final parts = await openRdCriticalRulePage(
      context,
      parts: old.isEmpty ? null : old,
      attendanceTypes: types,
      combinedElsewhere: combined == null ? null : _ruleTitle(combined.first, types),
    );
    if (parts == null || parts.isEmpty || !mounted) return;
    final current = ref.read(currentTenantProvider);
    if (current == null) return;
    final rules = rdCriticalReplaceGroup(_rules(current), old, parts);
    await _saveRules(
      t,
      rules,
      index == null ? l10n.generalSettingsFlutterRuleAdded : l10n.generalSettingsFlutterRuleUpdated,
    );
  }

  /// The rule's name, or a short one by what it counts ("Fehlt oft").
  String _ruleTitle(CriticalRule rule, List<AttendanceType> types) {
    final name = rule.name?.trim() ?? '';
    return name.isNotEmpty ? name : rdCriticalDefaultName(rule, context.l10n);
  }

  Future<void> _ruleActions(Tenant t, int index) async {
    final l10n = context.l10n;
    final groups = _groups(t);
    if (index >= groups.length) return;
    final group = groups[index];
    final action = await showAppActionSheet<String>(
      context,
      title: _ruleTitle(group.first, ref.read(attendanceTypesProvider).valueOrNull ?? const []),
      actions: [
        AppActionSheetAction(value: 'edit', label: l10n.commonEdit, icon: Icons.edit_outlined),
        AppActionSheetAction(value: 'delete', label: l10n.commonDelete, icon: Icons.delete_outline, destructive: true),
      ],
    );
    if (!mounted) return;
    if (action == 'edit') return _ruleSheet(t, index: index);
    if (action != 'delete') return;
    final rule = group.first;
    final confirmed = await showAppConfirm(
      context,
      title: l10n.generalSettingsDeleteRule,
      message: l10n.generalSettingsFlutterDeleteRuleNamed(rule.displayName),
      confirmText: l10n.commonDelete,
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    final current = ref.read(currentTenantProvider);
    if (current == null) return;
    final ids = {for (final r in group) r.id};
    final rules = _rules(current)..removeWhere((r) => ids.contains(r.id));
    await _saveRules(t, rules, l10n.generalSettingsFlutterRuleDeleted);
  }
}

/// "Gerade 2 Problemfälle · Personen ansehen": what the server decided
/// (the same set as Heute and the Mitglieder filter).
class _CriticalNow extends ConsumerWidget {
  const _CriticalNow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.rd;
    final l10n = context.l10n;
    final count = ref.watch(criticalPlayersProvider).valueOrNull?.where((x) => !x.paused).length;
    if (count == null) return const SizedBox.shrink();
    return RdGroupedList(
      children: [
        RdListRow(
          leading: RdRowIcon(
            Icons.warning_amber_rounded,
            color: count > 0 ? p.absent : p.text2,
            background: count > 0 ? p.absentSoft : p.line,
          ),
          title: l10n.rdCriticalListNow(count),
          subtitle: count > 0 ? l10n.rdCriticalListShow : null,
          showChevron: count > 0,
          onTap:
              count == 0
                  ? null
                  // Pushed, so back (and the swipe) returns to the rules.
                  : () => context.push(RedesignRoutes.criticalMembers(from: 'verwaltung')),
        ),
      ],
    );
  }
}

/// The rules as name + sentence, each with how many active members it hits
/// on its own right now, and "Regel hinzufügen". The "nur zusammen" parts
/// are one rule, joined by "und".
class _CriticalRuleList extends ConsumerWidget {
  const _CriticalRuleList({
    required this.rules,
    required this.types,
    required this.titleOf,
    required this.onTap,
    required this.onAdd,
  });

  final List<CriticalRule> rules;
  final List<AttendanceType> types;
  final String Function(CriticalRule rule, List<AttendanceType> types) titleOf;
  final void Function(int index)? onTap;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.rd;
    final l10n = context.l10n;
    final tenant = ref.watch(currentTenantProvider);
    final season = rdSeasonStartOf(tenant?.seasonStart);
    final now = DateTime.now();
    final key = rules.isEmpty ? null : rdCriticalKeyFor(tenant, rules);
    // Only data of this group: nothing from before a group switch.
    final entries = key == null ? null : ref.watch(rdCriticalEntriesProvider(key)).valueOrNull;
    final people = key == null ? null : rdLoadedValue(ref.watch(realtimePlayersProvider));

    int? hitsOf(List<CriticalRule> group) {
      if (entries == null || people == null) return null;
      var n = 0;
      for (final Person x in people) {
        if (x.id == null || x.paused || x.pending || x.left != null) continue;
        final all = group.every(
          (rule) =>
              rdEvaluateCriticalRule(
                rule,
                entries[x.id] ?? const [],
                lastSolve: x.lastSolve == null ? null : DateTime.tryParse(x.lastSolve!),
                seasonStart: season,
                now: now,
              ).matches,
        );
        if (all) n++;
      }
      return n;
    }

    final groups = rdCriticalRuleGroups(rules);
    return RdGroupedList(
      children: [
        for (var i = 0; i < groups.length; i++)
          Builder(
            builder: (context) {
              final group = groups[i];
              final title = titleOf(group.first, types);
              final hits = hitsOf(group);
              return RdListRow(
                title: title,
                subtitle: [
                  for (final (j, rule) in group.indexed)
                    j == 0 ? rdCriticalSummary(rule, types, l10n) : _lowerFirst(rdCriticalSummary(rule, types, l10n)),
                ].join(' ${l10n.rdCriticalAnd} '),
                trailing: hits == null ? null : RdCountBadge(hits, tone: hits > 0 ? RdTone.absent : RdTone.primary),
                onTap: onTap == null ? null : () => onTap!(i),
              );
            },
          ),
        RdListRow(
          title: l10n.rdSettingsAddRule,
          titleColor: p.primary,
          showChevron: false,
          onTap: onAdd,
        ),
      ],
    );
  }
}

String _lowerFirst(String s) => s.isEmpty ? s : s[0].toLowerCase() + s.substring(1);
