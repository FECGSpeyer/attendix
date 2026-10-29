import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/tenant/tenant.dart';
import '../../../../l10n/l10n.dart';
import 'settings_list.dart';

/// Card widget for displaying a critical rule
class CriticalRuleCard extends StatelessWidget {
  const CriticalRuleCard({
    super.key,
    required this.rule,
    required this.onDelete,
    required this.onEdit,
  });

  final CriticalRule rule;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    // UX_SETTINGS (WAVE 8): Ionic rule row inside the "Problemfall-Regeln"
    // group — wrapped description (h2), operator ion-badge (AND primary /
    // OR secondary) and a red trash button. Tap edits (Flutter extra).
    final isAnd = rule.operator == CriticalRuleOperator.and;
    final text = rule.name != null && rule.name!.isNotEmpty
        ? '${rule.name}: ${rule.description}'
        : rule.description;
    return ListTile(
      onTap: onEdit,
      title: Text(text),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Align(
          alignment: Alignment.centerLeft,
          child: IonBadge(
            text: isAnd ? 'AND' : 'OR',
            color: isAnd ? AppColors.primary : AppColors.secondary,
          ),
        ),
      ),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline, color: AppColors.danger),
        tooltip: context.l10n.commonDelete,
        onPressed: onDelete,
      ),
    );
  }
}
