import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/attendance_type_providers.dart';
import '../../../../core/providers/auto_message_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/theme/design_theme.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/attendance/attendance.dart';
import '../../../../data/models/auto_message/auto_message.dart';
import '../../../settings/presentation/widgets/manage/manage_list.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';
import '../auto_message_texts.dart';

/// Automatische Nachrichten: the tenant's rules (admins/responsibles).
/// Port of Ionic `AutoMessageListPage` (route `/settings/auto-messages`).
class AutoMessageListPage extends ConsumerStatefulWidget {
  const AutoMessageListPage({super.key});

  @override
  ConsumerState<AutoMessageListPage> createState() => _AutoMessageListPageState();
}

class _AutoMessageListPageState extends ConsumerState<AutoMessageListPage> {
  /// Optimistic toggle state while the update runs (rule id → enabled).
  final Map<String, bool> _toggling = {};

  /// Ionic takes over the saved rule after a toggle: the saved state wins
  /// until the rules are loaded again (rule id → enabled).
  final Map<String, bool> _saved = {};

  /// Ionic `load()` shows one red toast per (re)load, whether the rules or
  /// the recent runs failed.
  bool _loadFailedShown = false;

  /// Tenant whose recent runs the provider delivered last (only this page
  /// watches it). After a refresh error the earlier data stays visible, but
  /// never another tenant's (kept as previous value on a tenant switch).
  int? _lastWeekTenantId;

  @override
  void initState() {
    super.initState();
    // The Mitteilungen page preloads the rules: an error that happened
    // before this page opened doesn't reach the ref.listen callbacks.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _onLoadResult(null, ref.read(autoMessageRulesProvider));
      _onLoadResult(null, ref.read(autoMessageLastWeekProvider));
    });
  }

  void _onLoadResult(AsyncValue<Object?>? previous, AsyncValue<Object?> next) {
    if (!next.hasError || next.isLoading || _loadFailedShown || !mounted) return;
    _loadFailedShown = true;
    ToastHelper.showError(context, context.l10n.autoMessagesLoadFailed);
  }

  Future<void> _refresh() async {
    _loadFailedShown = false;
    ref.invalidate(autoMessageRulesProvider);
    ref.invalidate(autoMessageLastWeekProvider);
    try {
      await ref.read(autoMessageRulesProvider.future);
    } catch (_) {
      // shown as toast by _onLoadResult
    }
  }

  void _open(AutoMessageRule rule) => context.push('/settings/auto-messages/${rule.id}');

  void _create([String? template]) => context.push(
    template == null
        ? '/settings/auto-messages/new'
        : '/settings/auto-messages/new?template=$template',
  );

  Future<void> _toggle(AutoMessageRule rule, bool enabled) async {
    final id = rule.id;
    if (id == null) return;
    setState(() => _toggling[id] = enabled);
    final AutoMessageRule saved;
    try {
      saved = await ref.read(autoMessageRepositoryWithTenantProvider).setEnabled(id, enabled);
    } catch (_) {
      if (mounted) {
        ToastHelper.showError(context, context.l10n.autoMessagesSaveFailed);
        setState(() => _toggling.remove(id));
      }
      return;
    }
    if (!mounted) return;
    setState(() {
      _toggling.remove(id);
      _saved[id] = saved.enabled;
    });
    ToastHelper.showSuccess(
      context,
      saved.enabled ? context.l10n.autoMessagesEnabledToast : context.l10n.autoMessagesDisabledToast,
    );
    // Background reload for the count on Mitteilungen; the switch keeps the
    // saved state even if it fails. A new load gets its own error toast.
    _loadFailedShown = false;
    ref.invalidate(autoMessageRulesProvider);
  }

  @override
  Widget build(BuildContext context) {
    // A tenant switch reloads both providers: one new toast per tenant.
    ref.listen(currentTenantIdProvider, (_, _) => _loadFailedShown = false);
    ref.listen(autoMessageRulesProvider, (previous, next) {
      // One toast per load cycle, however the load was triggered (pull to
      // refresh, toggle, or invalidation from the rule editor after save or
      // delete): a new load or a successful result releases the lock.
      if (next.isLoading || !next.hasError) _loadFailedShown = false;
      if (next is AsyncData && !next.isLoading) _saved.clear();
      _onLoadResult(previous, next);
    });
    ref.listen(autoMessageLastWeekProvider, _onLoadResult);
    final tenantId = ref.watch(currentTenantIdProvider);
    final rulesAsync = ref.watch(autoMessageRulesProvider);
    final lastWeekAsync = ref.watch(autoMessageLastWeekProvider);
    if (lastWeekAsync is AsyncData && !lastWeekAsync.isLoading) _lastWeekTenantId = tenantId;
    final firstLoad = rulesAsync is AsyncLoading;
    final rules = [
      for (final rule in rulesAsync.valueOrNull ?? const <AutoMessageRule>[])
        if (rule.tenantId == tenantId) rule,
    ];
    final types = ref.watch(attendanceTypesProvider).valueOrNull ?? const [];
    final lastWeek = _lastWeekTenantId == tenantId ? lastWeekAsync.valueOrNull : null;

    return _buildBeta(
      firstLoad: firstLoad,
      failed: rulesAsync.hasError,
      rules: rules,
      types: types,
      lastWeek: lastWeek,
    );
  }
}

extension on _AutoMessageListPageState {
  Widget _buildBeta({
    required bool firstLoad,
    required bool failed,
    required List<AutoMessageRule> rules,
    required List<AttendanceType> types,
    required ({int sent, int people})? lastWeek,
  }) {
    final l10n = context.l10n;
    final p = context.rd;
    final notes = [
      if (rules.isNotEmpty && (lastWeek?.sent ?? 0) > 0) l10n.autoMessagesLastWeek(lastWeek!.people),
      l10n.autoMessagesWhoCanUse,
    ];
    return RdManageListPage(
      title: l10n.autoMessagesTitle,
      intro: l10n.autoMessagesIntro,
      notice: notes.join('\n\n'),
      backLabel: l10n.messagesMessages,
      sections: firstLoad && !failed
          ? null
          : [
              RdManageListSection(
                key: 'rules',
                title: rules.isEmpty ? null : l10n.autoMessagesRules,
                items: [
                  for (final rule in rules)
                    RdManageListItem(
                      id: rule.id ?? rule.name,
                      title: rule.name,
                      icon: Icons.timer_outlined,
                      subtitle: [l10n.autoMessageRuleSummary(rule, types), ...l10n.autoMessageRuleChips(rule)].join(' · '),
                      trailing: Semantics(
                        label: l10n.autoMessagesActive,
                        child: IonSwitch(
                          value: _toggling[rule.id] ?? _saved[rule.id] ?? rule.enabled,
                          activeTrackColor: p.primary,
                          onChanged: _toggling.containsKey(rule.id) ? null : (v) => _toggle(rule, v),
                        ),
                      ),
                      onTap: () => _open(rule),
                    ),
                ],
              ),
              RdManageListSection(
                key: 'templates',
                title: l10n.autoMessagesStartFromTemplate,
                items: [
                  for (final tpl in autoMessageTemplates)
                    RdManageListItem(
                      id: 'tpl-$tpl',
                      title: l10n.autoMessageTemplateName(tpl),
                      subtitle: l10n.autoMessageTemplateHint(tpl),
                      icon: Icons.auto_awesome_outlined,
                      onTap: () => _create(tpl),
                    ),
                ],
              ),
            ],
      emptyText: l10n.autoMessagesIntro,
      addLabel: l10n.autoMessagesNewRule,
      onAdd: () => _create(),
      onRefresh: _refresh,
    );
  }
}
