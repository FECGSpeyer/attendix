import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/attendance_type_providers.dart';
import '../../../../core/providers/auto_message_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/auto_message/auto_message.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';
import '../../../settings/presentation/widgets/settings_list.dart';
import '../auto_message_texts.dart';
import 'package:attendix/shared/widgets/layout/ios_tab_bar.dart';

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

  Future<void> _refresh() async {
    ref.invalidate(autoMessageRulesProvider);
    ref.invalidate(autoMessageLastWeekProvider);
    await ref.read(autoMessageRulesProvider.future);
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
    try {
      await ref.read(autoMessageRepositoryWithTenantProvider).setEnabled(id, enabled);
      ref.invalidate(autoMessageRulesProvider);
      await ref.read(autoMessageRulesProvider.future);
      if (mounted) {
        ToastHelper.showSuccess(
          context,
          enabled ? context.l10n.autoMessagesEnabledToast : context.l10n.autoMessagesDisabledToast,
        );
      }
    } catch (_) {
      if (mounted) ToastHelper.showError(context, context.l10n.autoMessagesSaveFailed);
    } finally {
      if (mounted) setState(() => _toggling.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final rulesAsync = ref.watch(autoMessageRulesProvider);
    final types = ref.watch(attendanceTypesProvider).valueOrNull ?? const [];
    final lastWeek = ref.watch(autoMessageLastWeekProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.autoMessagesTitle)),
      body: RefreshIndicator.adaptive(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            AppDimensions.paddingM,
            AppDimensions.paddingM,
            AppDimensions.paddingM,
            scrollEndPadding(context, base: 16),
          ),
          children: [
            // Ionic p.intro
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 16),
              child: Text(
                l10n.autoMessagesIntro,
                style: const TextStyle(fontSize: 14, height: 1.45, color: AppColors.medium),
              ),
            ),
            ...rulesAsync.when(
              loading:
                  () => [
                    const Padding(padding: EdgeInsets.all(32), child: Center(child: AppSpinner())),
                  ],
              error: (e, _) => [AutoMessageHint(l10n.autoMessagesLoadFailed, center: true)],
              data:
                  (rules) => [
                    if (rules.isNotEmpty)
                      SettingsListSection(
                        title: l10n.autoMessagesRules,
                        icons: false,
                        children: [
                          for (final rule in rules)
                            _RuleRow(
                              rule: rule,
                              enabled: _toggling[rule.id] ?? rule.enabled,
                              summary: l10n.autoMessageRuleSummary(rule, types),
                              chips: l10n.autoMessageRuleChips(rule),
                              onTap: () => _open(rule),
                              onToggle:
                                  _toggling.containsKey(rule.id) ? null : (v) => _toggle(rule, v),
                            ),
                        ],
                      ),
                    if (rules.isNotEmpty && (lastWeek?.sent ?? 0) > 0)
                      AutoMessageHint(l10n.autoMessagesLastWeek(lastWeek!.people)),
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppDimensions.paddingM),
                      child: FilledButton.icon(
                        onPressed: () => _create(),
                        icon: const Icon(Icons.add),
                        label: IonButtonLabel(l10n.autoMessagesNewRule),
                        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                      ),
                    ),
                    SettingsListSection(
                      title: l10n.autoMessagesStartFromTemplate,
                      icons: false,
                      children: [
                        for (final tpl in autoMessageTemplates)
                          SettingsListTile(
                            title: l10n.autoMessageTemplateName(tpl),
                            subtitle: l10n.autoMessageTemplateHint(tpl),
                            onTap: () => _create(tpl),
                          ),
                      ],
                    ),
                    AutoMessageHint(l10n.autoMessagesWhoCanUse),
                  ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RuleRow extends StatelessWidget {
  const _RuleRow({
    required this.rule,
    required this.enabled,
    required this.summary,
    required this.chips,
    required this.onTap,
    required this.onToggle,
  });

  final AutoMessageRule rule;
  final bool enabled;
  final String summary;
  final List<String> chips;
  final VoidCallback onTap;
  final ValueChanged<bool>? onToggle;

  @override
  Widget build(BuildContext context) {
    final ios = ionIsIos(context);
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding:
            ios
                ? const EdgeInsets.fromLTRB(IonIos.itemPaddingStart, 10, 10, 10)
                : const EdgeInsets.fromLTRB(AppDimensions.paddingM, 12, 8, 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    rule.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontSize: ios ? 16 : null,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    summary,
                    style: TextStyle(
                      fontSize: 14,
                      color: ios ? IonIos.labelP(context) : AppColors.medium,
                    ),
                  ),
                  if (chips.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        for (final c in chips)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              c,
                              style: const TextStyle(fontSize: 11.5, color: AppColors.primary),
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            Semantics(
              label: context.l10n.autoMessagesActive,
              child: Switch.adaptive(value: enabled, onChanged: onToggle),
            ),
          ],
        ),
      ),
    );
  }
}
