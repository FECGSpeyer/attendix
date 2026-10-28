import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/tenant/tenant.dart';
import '../../../../l10n/l10n.dart';

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
    return Card(
      margin: const EdgeInsets.only(bottom: AppDimensions.paddingS),
      child: ListTile(
        leading: Icon(
          Icons.warning_amber_rounded,
          color: AppColors.warning,
        ),
        title: Text(
          rule.displayName,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (rule.name != null)
              Text(
                rule.description,
                style: const TextStyle(fontSize: 12),
              ),
            const SizedBox(height: 4),
            Row(
              children: [
                _buildOperatorChip(context),
                // DB_REVIEW_REST (M3): no 'disabled' badge, Ionic has no
                // enabled flag (all rules are evaluated server-side).
              ],
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, size: 20),
              onPressed: onEdit,
            ),
            IconButton(
              icon: Icon(Icons.delete, size: 20, color: AppColors.danger),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOperatorChip(BuildContext context) {
    final isAnd = rule.operator == CriticalRuleOperator.and;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isAnd ? AppColors.info.withValues(alpha: 0.2) : AppColors.warning.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        isAnd ? context.l10n.generalSettingsFlutterAndShort : context.l10n.generalSettingsFlutterOrShort,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: isAnd ? AppColors.info : AppColors.warning,
        ),
      ),
    );
  }
}
