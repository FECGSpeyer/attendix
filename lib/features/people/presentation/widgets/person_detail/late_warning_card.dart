import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/constants/app_constants.dart';
import '../../../../../core/providers/tenant_providers.dart';
import '../../../../../data/models/person/person.dart';
import '../../../../../l10n/l10n.dart';

/// Card showing late warning with threshold information and reset button.
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
    return statsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (stats) {
        final lateCount = stats['lateCount'] as int? ?? 0;
        final lateStatuses = stats['lateStatuses'] as List<int>? ?? [3];

        // Get threshold from tenant's critical rules
        final tenant = ref.watch(currentTenantProvider);
        int threshold = 3;
        final criticalRules = tenant?.criticalRules;
        if (criticalRules != null) {
          for (final rule in criticalRules) {
            // Status 3 = late
            if (rule.statuses.contains(3)) {
              threshold = rule.thresholdValue;
              break;
            }
          }
        }

        if (lateCount < threshold) return const SizedBox.shrink();

        // Dynamic text based on which statuses are counted
        // If only status 3 (late) is counted, say "unentschuldigt"
        // If status 5 (lateExcused) is also counted, just say "zu spät"

        return Card(
          margin: const EdgeInsets.all(AppDimensions.paddingM),
          color: Colors.orange.shade50,
          child: ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.schedule, color: Colors.orange),
            ),
            title: Text(
              context.l10n.personFlutterFrequentLate,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              lateStatuses.contains(5)
                  ? context.l10n.personFlutterLateCount(lateCount, threshold)
                  : context.l10n.personFlutterLateUnexcusedCount(lateCount, threshold),
              style: TextStyle(color: Colors.orange.shade800),
            ),
            trailing: FilledButton.tonal(
              onPressed: onResetLateCount,
              child: Text(context.l10n.dateDialogReset),
            ),
          ),
        );
      },
    );
  }
}
