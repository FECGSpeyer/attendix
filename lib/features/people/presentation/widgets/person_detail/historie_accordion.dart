import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';

import '../../../../../core/config/supabase_config.dart';
import '../../../../../core/constants/app_constants.dart';
import '../../../../../core/constants/enums.dart';
import '../../../../../core/providers/realtime_providers.dart';
import '../../../../../core/providers/tenant_providers.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../pages/person_detail_page.dart';

/// Toggle to show all history entries (including before season start).
final showAllHistoryProvider = StateProvider.autoDispose<bool>((ref) => false);

/// Accordion section displaying person history (attendance + changes).
class HistorieAccordion extends ConsumerWidget {
  const HistorieAccordion({
    super.key,
    required this.isExpanded,
    required this.onToggle,
    required this.historyAsync,
    required this.statsAsync,
    required this.personId,
    required this.canEdit,
  });

  final bool isExpanded;
  final VoidCallback onToggle;
  final AsyncValue<List<Map<String, dynamic>>> historyAsync;
  final AsyncValue<Map<String, dynamic>> statsAsync;
  final int personId;
  final bool canEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingM,
        vertical: AppDimensions.paddingXS,
      ),
      child: Column(
        children: [
          ListTile(
            title: const Text(
              'Historie',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            trailing: Icon(isExpanded ? Icons.expand_less : Icons.expand_more),
            onTap: onToggle,
          ),
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimensions.paddingM,
                0,
                AppDimensions.paddingM,
                AppDimensions.paddingM,
              ),
              child: _buildContent(context, ref),
            ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref) {
    return historyAsync.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(AppDimensions.paddingL),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (error, _) => Center(child: Text('Fehler: $error')),
      data: (history) {
        if (history.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(AppDimensions.paddingL),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.history, size: 48, color: AppColors.medium),
                  SizedBox(height: AppDimensions.paddingS),
                  Text('Keine Historie vorhanden'),
                ],
              ),
            ),
          );
        }

        final tenant = ref.watch(currentTenantProvider);
        final showAll = ref.watch(showAllHistoryProvider);
        final seasonStart = tenant?.seasonStart != null
            ? DateTime.tryParse(tenant!.seasonStart!)
            : null;

        // Filter to current season unless "show all" is active
        final filteredHistory = (seasonStart != null && !showAll)
            ? history.where((item) {
                final date = DateTime.tryParse(item['date'] ?? '');
                return date == null || !date.isBefore(seasonStart);
              }).toList()
            : history;

        return Column(
          children: [
            // Stats summary row
            _buildStatsRow(),

            // Season filter toggle
            if (seasonStart != null)
              Padding(
                padding: const EdgeInsets.only(top: AppDimensions.paddingS),
                child: Row(
                  children: [
                    Text(
                      showAll
                          ? 'Alle Einträge'
                          : 'Ab Saisonstart (${DateFormat('dd.MM.yyyy').format(seasonStart)})',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => ref.read(showAllHistoryProvider.notifier).state = !showAll,
                      child: Text(
                        showAll ? 'Nur Saison' : 'Alle anzeigen',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // History items
            ...filteredHistory.take(20).map(
                  (item) => _buildHistoryItem(context, ref, item),
                ),
          ],
        );
      },
    );
  }

  Widget _buildStatsRow() {
    return statsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (stats) {
        final percentage = stats['percentage'] as int;
        final lateCount = stats['lateCount'] as int;
        final lateText = lateCount > 0 ? ' (${lateCount}x zu spät)' : '';
        final badgeColor = percentage >= 75
            ? AppColors.success
            : percentage >= 50
                ? AppColors.warning
                : AppColors.danger;

        return Container(
          padding:
              const EdgeInsets.symmetric(vertical: AppDimensions.paddingM),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Durchschnitt$lateText',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '$percentage%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHistoryItem(
      BuildContext context, WidgetRef ref, Map<String, dynamic> item) {
    final date = DateTime.tryParse(item['date'] ?? '');
    final type = item['type'] as int?;
    final text = item['text']?.toString() ?? '';
    final meetingName = item['meetingName']?.toString();
    final notes = item['notes']?.toString();

    // Determine display title (Ionic person.page.html history section,
    // PlayerHistoryType codes from utilities/constants.ts)
    String displayTitle = '';
    String? fullTitle;
    if (type == PlayerHistoryType.attendance.value) {
      displayTitle = meetingName ?? '';
    } else if (date != null) {
      fullTitle = historyEntryTitle(type, date);
    }
    final bodyText = historyEntryBody(type, text);

    // Build badge for attendance status
    String? badgeText;
    Color? badgeColor;
    if (type == PlayerHistoryType.attendance.value) {
      if (text == 'X') {
        badgeText = '✓';
        badgeColor = AppColors.success;
      } else if (text == 'L') {
        badgeText = 'L';
        badgeColor = AppColors.tertiary;
      } else if (text == 'E') {
        badgeText = 'E';
        badgeColor = AppColors.warning;
      } else if (text == 'N') {
        badgeText = 'N';
        badgeColor = AppColors.medium;
      } else {
        badgeText = 'A';
        badgeColor = AppColors.danger;
      }
    }

    final dateStr = date != null ? DateFormat('dd.MM.yyyy').format(date) : '';
    final titleStr = fullTitle ??
        (displayTitle.isNotEmpty ? '$dateStr | $displayTitle' : dateStr);

    final isAttendance = type == PlayerHistoryType.attendance.value;
    final isDeletable = canEdit && !isAttendance;

    final content = Container(
      padding: const EdgeInsets.symmetric(vertical: AppDimensions.paddingM),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titleStr, style: const TextStyle(fontSize: 15)),
                if (notes != null && notes.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      notes,
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ),
                if (!isAttendance && bodyText.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      bodyText,
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ),
              ],
            ),
          ),
          if (badgeText != null)
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: badgeColor,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Center(
                child: Text(
                  badgeText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    if (!isDeletable) return content;

    return Slidable(
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.25,
        children: [
          SlidableAction(
            onPressed: (_) => _confirmDelete(context, ref, item),
            backgroundColor: AppColors.danger,
            foregroundColor: Colors.white,
            icon: Icons.delete,
            label: 'Löschen',
          ),
        ],
      ),
      child: content,
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, Map<String, dynamic> item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eintrag löschen'),
        content:
            const Text('Eintrag unwiderruflich entfernen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      final supabase = ref.read(supabaseClientProvider);
      final tenant = ref.read(currentTenantProvider);
      final person = await ref.read(personProvider(personId).future);

      if (person == null || tenant == null) return;

      // Remove the matching history entry by date and type
      final itemDate = item['date']?.toString();
      final itemType = item['type'] as int?;
      final itemText = item['text']?.toString() ?? '';

      final updatedHistory = person.history.where((h) {
        // Match by date, type, and text to find exact entry
        if (h.date == itemDate && h.type == itemType) {
          if ((h.text ?? '') == itemText) return false;
        }
        return true;
      }).map((h) => h.toJson()).toList();

      await supabase
          .from('player')
          .update({'history': updatedHistory})
          .eq('id', person.id!)
          .eq('tenantId', tenant.id!);

      ref.invalidate(personProvider(personId));
      ref.invalidate(personHistoryProvider(personId));
      ref.invalidate(realtimePlayersProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Eintrag gelöscht'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }
}

/// Title of a player history entry (Ionic person.page.html history section).
String historyEntryTitle(int? type, DateTime date) {
  final d = DateFormat('dd.MM.yyyy').format(date);
  final dt = DateFormat('dd.MM.yyyy HH:mm').format(date);
  return switch (type) {
    2 || 3 => 'Mit Person gesprochen ($dt)',
    5 => 'Notiz geändert am $dt',
    1 => 'Pausiert am $dt',
    6 => 'Wieder aktiv seit $dt',
    8 => 'Archiviert am $d',
    9 => 'Reaktiviert am $d',
    10 || 11 => 'Übertragen am $d',
    12 || 13 => 'Kopiert am $d',
    _ => d,
  };
}

/// Body text of a player history entry (Ionic getPlayerHistoryTypeText).
String historyEntryBody(int? type, String text) {
  switch (type) {
    case 4:
    case 6:
    case 9:
      return '';
    case 5:
      return 'Alte Notiz: ${text.isNotEmpty ? text : 'Keine Notiz'}';
    case 8:
    case 10:
    case 11:
    case 12:
    case 13:
      return text;
  }
  final typeText = switch (type) {
    1 => 'Pausiert',
    2 => 'Unentschuldigt',
    3 => '',
    7 => 'Wechsel',
    _ => 'Sonstiges',
  };
  final body = text.isNotEmpty ? text : 'Keine Anmerkung';
  return typeText.isEmpty ? body : '$typeText: $body';
}
