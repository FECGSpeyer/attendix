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
import '../../../../../core/utils/toast_helper.dart';
import '../../pages/person_detail_page.dart';
import '../../../../../core/utils/demo_guard.dart';
import '../../../../../l10n/l10n.dart';
import '../../../../../core/utils/error_message.dart';

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
            title: Text(
              context.l10n.personHistory,
              style: const TextStyle(fontWeight: FontWeight.w600),
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
      loading:
          () => const Center(
            child: Padding(
              padding: EdgeInsets.all(AppDimensions.paddingL),
              child: CircularProgressIndicator(),
            ),
          ),
      error: (error, _) => Center(child: Text(context.l10n.peopleFlutterErrorWith(friendlyErrorMessage(error)))),
      data: (history) {
        if (history.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(AppDimensions.paddingL),
            child: Center(
              child: Column(
                children: [
                  const Icon(Icons.history, size: 48, color: AppColors.medium),
                  const SizedBox(height: AppDimensions.paddingS),
                  Text(context.l10n.personFlutterNoHistory),
                ],
              ),
            ),
          );
        }

        final tenant = ref.watch(currentTenantProvider);
        final showAll = ref.watch(showAllHistoryProvider);
        final seasonStart =
            tenant?.seasonStart != null
                ? DateTime.tryParse(tenant!.seasonStart!)
                : null;

        // Filter to current season unless "show all" is active
        final filteredHistory =
            (seasonStart != null && !showAll)
                ? history.where((item) {
                  final date = DateTime.tryParse(item['date'] ?? '');
                  return date == null || !date.isBefore(seasonStart);
                }).toList()
                : history;

        return Column(
          children: [
            // Stats summary row
            _buildStatsRow(context),

            // Season filter toggle
            if (seasonStart != null)
              Padding(
                padding: const EdgeInsets.only(top: AppDimensions.paddingS),
                child: Row(
                  children: [
                    Text(
                      showAll
                          ? context.l10n.personFlutterAllEntries
                          : context.l10n.personFlutterFromSeasonStart(DateFormat(dateFmt()).format(seasonStart)),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap:
                          () =>
                              ref.read(showAllHistoryProvider.notifier).state =
                                  !showAll,
                      child: Text(
                        showAll ? context.l10n.personFlutterSeasonOnly : context.l10n.personFlutterShowAll,
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
            ...filteredHistory
                .take(20)
                .map((item) => _buildHistoryItem(context, ref, item)),
          ],
        );
      },
    );
  }

  Widget _buildStatsRow(BuildContext context) {
    return statsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (stats) {
        final percentage = stats['percentage'] as int;
        final lateCount = stats['lateCount'] as int;
        final badgeColor =
            percentage >= 75
                ? AppColors.success
                : percentage >= 50
                ? AppColors.warning
                : AppColors.danger;

        return Container(
          padding: const EdgeInsets.symmetric(vertical: AppDimensions.paddingM),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  lateCount > 0
                      ? context.l10n.personAverageLate(lateCount)
                      : context.l10n.personAverage,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
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
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> item,
  ) {
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

    final dateStr = date != null ? DateFormat(dateFmt()).format(date) : '';
    final titleStr =
        fullTitle ??
        (displayTitle.isNotEmpty ? '$dateStr | $displayTitle' : dateStr);

    final isAttendance = type == PlayerHistoryType.attendance.value;
    final isDeletable = canEdit && !isAttendance;

    final content = InkWell(
      // Ionic onHisItemClicked: note entries open the old note.
      onTap:
          type == PlayerHistoryType.notes.value && date != null
              ? () => _showOldNote(context, date, text)
              : null,
      child: Container(
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
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                  if (!isAttendance && bodyText.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        bodyText,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
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
      ),
    );

    if (!isDeletable) return content;

    return Slidable(
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.25,
        children: [
          // Ionic: icon-only danger option (trash).
          SlidableAction(
            onPressed: (_) => _confirmDelete(context, ref, item),
            backgroundColor: AppColors.danger,
            foregroundColor: Colors.white,
            icon: Icons.delete,
          ),
        ],
      ),
      child: content,
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> item,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            // Ionic removeHis alert: header only, buttons Abbrechen / Ja.
            title: Text(context.l10n.personRemoveEntry),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(context.l10n.commonCancel),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(context.l10n.commonYes),
              ),
            ],
          ),
    );

    if (confirmed != true || !context.mounted) return;
    if (DemoGuard.blocked()) return; // DEMO_GUARD

    try {
      final supabase = ref.read(supabaseClientProvider);
      final tenant = ref.read(currentTenantProvider);
      final person = await ref.read(personProvider(personId).future);

      if (person == null || tenant == null) return;

      // Remove the matching history entry by date and type
      final itemDate = item['date']?.toString();
      final itemType = item['type'] as int?;
      final itemText = item['text']?.toString() ?? '';

      final updatedHistory =
          person.history
              .where((h) {
                // Match by date, type, and text to find exact entry
                if (h.date == itemDate && h.type == itemType) {
                  if ((h.text ?? '') == itemText) return false;
                }
                return true;
              })
              .map((h) => h.toJson())
              .toList();

      await supabase
          .from('player')
          .update({'history': updatedHistory})
          .eq('id', person.id!)
          .eq('tenantId', tenant.id!);

      ref.invalidate(personProvider(personId));
      ref.invalidate(personHistoryProvider(personId));
      ref.invalidate(realtimePlayersProvider);

      if (context.mounted) {
        ToastHelper.showSuccess(context, context.l10n.personEntryRemoved);
      }
    } catch (e) {
      if (context.mounted) {
        ToastHelper.showError(context, context.l10n.personEntryRemoveFailed);
      }
    }
  }

  /// Ionic onHisItemClicked for NOTES entries.
  Future<void> _showOldNote(BuildContext context, DateTime date, String note) {
    return showDialog<void>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(context.l10n.personNoteChanged),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat(dateFmt()).format(date),
                  style: Theme.of(ctx).textTheme.titleSmall,
                ),
                const SizedBox(height: AppDimensions.paddingS),
                Text(context.l10n.personOldNote(note)),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(context.l10n.commonOk),
              ),
            ],
          ),
    );
  }
}

/// Title of a player history entry (Ionic person.page.html history section).
String historyEntryTitle(int? type, DateTime date) {
  final l10n = l10nWithoutContext;
  final d = DateFormat(dateFmt()).format(date);
  final dt = DateFormat('${dateFmt()} HH:mm').format(date);
  return switch (type) {
    2 || 3 => l10n.personTalkedToAt(dt),
    5 => l10n.personNoteChangedAt(dt),
    1 => l10n.personPausedAt(dt),
    6 => l10n.personActiveSince(dt),
    8 => l10n.personArchivedAt(d),
    9 => l10n.personReactivatedAt(d),
    10 || 11 => l10n.personTransferredAt(d),
    12 || 13 => l10n.personCopiedAt(d),
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
      return l10nWithoutContext.personOldNote(
          text.isNotEmpty ? text : l10nWithoutContext.personFlutterNoNote);
    case 8:
    case 10:
    case 11:
    case 12:
    case 13:
      return text;
  }
  final l10n = l10nWithoutContext;
  final typeText = switch (type) {
    1 => l10n.commonHistoryPaused,
    2 => l10n.commonHistoryUnexcused,
    3 => '',
    7 => l10n.commonHistoryGroupChange,
    _ => l10n.commonOther,
  };
  final body = text.isNotEmpty ? text : l10n.personNoComment;
  return typeText.isEmpty ? body : '$typeText: $body';
}
