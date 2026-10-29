import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/providers/tenant_providers.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../data/models/person/person.dart';
import '../../../../../l10n/l10n.dart';
import '../../../../../shared/widgets/adaptive/ion_button_label.dart';
import '../../../person_stats.dart';

/// Ionic person.page `ion-card.late-warning-card` (color warning): shown to
/// admins when the person was late (unexcused) at least `lateThreshold`
/// times since the last "Gespräch geführt" ([Person.lastSolve]).
class LateWarningCard extends ConsumerWidget {
  const LateWarningCard({
    super.key,
    required this.person,
    required this.statsAsync,
    required this.onResetLateCount,
  });

  final Person person;
  final AsyncValue<Map<String, dynamic>> statsAsync;
  final VoidCallback onResetLateCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = statsAsync.valueOrNull;
    if (stats == null) return const SizedBox.shrink();
    final lateCount = stats['lateCount'] as int? ?? 0;
    final lateCountExcused = stats['lateCountExcused'] as int? ?? 0;
    final threshold =
        lateWarningThreshold(ref.watch(currentTenantProvider)?.criticalRules);
    if (lateCount < threshold) return const SizedBox.shrink();

    const textColor = Colors.black;
    return Card(
      key: const Key('late_warning_card'),
      margin: const EdgeInsets.all(16),
      color: AppColors.warning,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.personLateWarningTitle,
              style: const TextStyle(
                fontSize: 17.6,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text.rich(
              htmlStrongToSpan(context.l10n.personLateWarning(lateCount)),
              style: const TextStyle(color: textColor),
            ),
            if (lateCountExcused > 0) ...[
              const SizedBox(height: 8),
              Opacity(
                opacity: 0.8,
                child: Text(
                  context.l10n.personLateExcusedExtra(lateCountExcused),
                  style: const TextStyle(fontSize: 14.4, color: textColor),
                ),
              ),
            ],
            const SizedBox(height: 12),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.dark,
                foregroundColor: Colors.white,
                visualDensity: VisualDensity.compact,
              ),
              onPressed: onResetLateCount,
              icon: const Icon(Icons.check_circle_outline, size: 18),
              label: IonButtonLabel(context.l10n.personResetTalked),
            ),
          ],
        ),
      ),
    );
  }
}

/// Renders an Ionic innerHTML text with `<strong>` parts as bold spans.
TextSpan htmlStrongToSpan(String html) {
  final spans = <TextSpan>[];
  final parts = html.split(RegExp(r'</?strong>'));
  for (var i = 0; i < parts.length; i++) {
    if (parts[i].isEmpty) continue;
    spans.add(TextSpan(
      text: parts[i],
      style: i.isOdd ? const TextStyle(fontWeight: FontWeight.bold) : null,
    ));
  }
  return TextSpan(children: spans);
}
