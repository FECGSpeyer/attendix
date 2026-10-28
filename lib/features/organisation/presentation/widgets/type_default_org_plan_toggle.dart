import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/organisation_providers.dart';
import '../../../../core/providers/plan_providers.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../l10n/l10n.dart';

/// Toggle "Ablaufplan ist standardmäßig ein Organisationsplan"
/// (`attendance_types.is_default_org_plan`). Only shown when the tenant
/// belongs to an organisation; saved immediately.
class TypeDefaultOrgPlanToggle extends ConsumerStatefulWidget {
  const TypeDefaultOrgPlanToggle({super.key, required this.typeId});

  final String typeId;

  @override
  ConsumerState<TypeDefaultOrgPlanToggle> createState() => _TypeDefaultOrgPlanToggleState();
}

class _TypeDefaultOrgPlanToggleState extends ConsumerState<TypeDefaultOrgPlanToggle> {
  bool? _value;

  @override
  Widget build(BuildContext context) {
    final org = ref.watch(currentOrganisationProvider).valueOrNull;
    if (org == null) return const SizedBox.shrink();
    final type = ref
        .watch(planAttendanceTypesProvider)
        .valueOrNull
        ?.where((t) => t.id == widget.typeId)
        .firstOrNull;
    final value = _value ?? type?.isDefaultOrgPlan ?? false;
    return SwitchListTile(
      title: Text(context.l10n.typeSettingsOrgPlanDefault),
      value: value,
      onChanged: type == null
          ? null
          : (v) async {
              setState(() => _value = v);
              final ok = await ref.read(planSettingsNotifierProvider.notifier).setTypeDefaultOrgPlan(widget.typeId, v);
              if (!ok && context.mounted) {
                setState(() => _value = !v);
                ToastHelper.showError(context, context.l10n.plansSaveFailed);
              }
            },
    );
  }
}
