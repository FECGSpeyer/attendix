import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/providers/player_providers.dart';
import '../../../../core/providers/realtime_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/router/redesign_routes.dart';
import '../../../../core/theme/redesign/rd_theme.dart';
import '../../../../core/utils/demo_guard.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart' show showAppConfirm;
import '../../../people/presentation/pages/person_detail_page.dart'
    show personProvider, personAttendanceStatsProvider, personHistoryProvider;
import '../../../people/presentation/widgets/person_detail/person_detail.dart'
    show
        filterHistoryBySeason,
        historyEntryBody,
        historyEntryTitle,
        historyWithoutEntry,
        showAllHistoryProvider,
        showOldHistoryNote,
        upcomingAttendancesProvider;
import '../widgets/manage/rd_settings_sheets.dart' show showRdChoiceSheet;
import '../widgets/rd_widgets.dart';
import '../widgets/today/rd_today_common.dart' show RdInfoCard, rdOwnStatusPill;
import 'rd_members_page.dart' show rdPercentColor;

/// REDESIGN: "Verlauf" of a person (from "Alle Termine ansehen"): the
/// average, the coming Termine and the whole history of the old person
/// page (with its status changes) as Beta lists. Same data, filter, rights
/// and delete as the old "Historie" and "Kommende Termine" accordions.
class RdPersonHistoryPage extends ConsumerStatefulWidget {
  const RdPersonHistoryPage({super.key, required this.personId});

  final int personId;

  @override
  ConsumerState<RdPersonHistoryPage> createState() => _RdPersonHistoryPageState();
}

/// Status of an attendance as a pill ("Anwesend" green, "Entschuldigt" /
/// "Verspätet" yellow, "Abwesend" red).
RdPill rdHistoryStatusPill(AppLocalizations l10n, int status) {
  return switch (AttendanceStatus.fromValue(status)) {
    AttendanceStatus.present => RdPill(l10n.redesignHistoryPresent, tone: RdTone.present, icon: Icons.check),
    AttendanceStatus.excused => RdPill(l10n.redesignStatusExcused, tone: RdTone.excused),
    AttendanceStatus.late => RdPill(l10n.redesignStatusLate, tone: RdTone.late),
    AttendanceStatus.lateExcused => RdPill(l10n.redesignStatusLater, tone: RdTone.late),
    AttendanceStatus.absent => RdPill(l10n.redesignStatusAbsent, tone: RdTone.absent),
    AttendanceStatus.neutral => RdPill(l10n.redesignHistoryNeutral),
  };
}

int _intOf(Object? v) => v is int ? v : int.tryParse('${v ?? ''}') ?? 0;

class _RdPersonHistoryPageState extends ConsumerState<RdPersonHistoryPage> {
  int get _id => widget.personId;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final id = _id;
    final async = ref.watch(personProvider(id));
    final person = async.valueOrNull;
    // Same rights as the history of the old person page.
    final role = ref.watch(currentRoleProvider);
    final hasLeft = person?.left != null;
    final canEdit = (role.isAdmin || role.isResponsible) && !hasLeft;
    // A Termin opens for the roles that may open it (like the Termin list).
    final canOpenTermin = role.canAddAttendance;
    final name = person == null ? '' : '${person.firstName} ${person.lastName}'.trim();

    return RdPage(
      onRefresh: () async {
        ref.invalidate(personProvider(id));
        ref.invalidate(personHistoryProvider(id));
        ref.invalidate(personAttendanceStatsProvider(id));
        ref.invalidate(upcomingAttendancesProvider(id));
      },
      children: [
        RdBackLink(
          label: name.isEmpty ? l10n.redesignTabMembers : name,
          onTap: () => context.canPop() ? context.pop() : context.go(RedesignRoutes.person(id)),
        ),
        const SizedBox(height: 4),
        Semantics(header: true, child: Text(l10n.redesignPersonHistory, style: RdType.title(p))),
        const SizedBox(height: 12),
        if (person == null)
          // Same states as the person page: loading, failed, gone.
          async.isLoading
              ? RdInfoCard(text: l10n.redesignTodayLoading, loading: true)
              : RdInfoCard(
                  text: async.hasError ? l10n.redesignTodayLoadFailed : l10n.redesignPersonNotFound,
                  icon: Icons.person_off_outlined,
                  action: RdOutlineButton(
                    label: l10n.redesignCommonRetry,
                    onPressed: () => ref.invalidate(personProvider(id)),
                  ),
                )
        else ...[
          ..._averageCard(hasLeft: hasLeft),
          ..._upcoming(canOpenTermin: canOpenTermin),
          ..._history(canEdit: canEdit, hasLeft: hasLeft, canOpenTermin: canOpenTermin),
        ],
      ],
    );
  }

  /// "80 %" with "Durchschnitt · 1× zu spät" and "Seit Saisonbeginn | Alles".
  List<Widget> _averageCard({required bool hasLeft}) {
    final p = context.rd;
    final l10n = context.l10n;
    final stats = ref.watch(personAttendanceStatsProvider(_id)).valueOrNull;
    final seasonStart = DateTime.tryParse(ref.watch(currentTenantProvider)?.seasonStart ?? '');
    // Archived persons always see the whole history (old accordion).
    final showFilter = seasonStart != null && !hasLeft;
    if (stats == null && !showFilter) return const [];
    final percent = _intOf(stats?['percentage']);
    final late = _intOf(stats?['lateCount']);
    return [
      RdCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (stats != null)
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.end,
                spacing: 8,
                children: [
                  Text(
                    l10n.redesignPersonPercent(percent),
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w700,
                      color: rdPercentColor(p, percent),
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      late > 0 ? l10n.redesignHistoryAverageLate(late) : l10n.redesignHistoryAverage,
                      style: RdType.meta(p, size: 14),
                    ),
                  ),
                ],
              ),
            if (stats != null && showFilter) const SizedBox(height: 12),
            if (showFilter)
              RdSegmented<bool>(
                values: const [false, true],
                selected: ref.watch(showAllHistoryProvider),
                labelOf: (all) => all ? l10n.redesignHistoryAll : l10n.redesignHistorySeason,
                onChanged: (all) => ref.read(showAllHistoryProvider.notifier).state = all,
              ),
          ],
        ),
      ),
      const SizedBox(height: 22),
    ];
  }

  /// Date tile of a list row ("SA" over "1").
  Widget _dateTile(DateTime? date) => RdDateTile(
        weekday: date == null ? '' : DateFormat.E(currentIntlLocale()).format(date).replaceAll('.', ''),
        day: date == null ? '–' : '${date.day}',
      );

  /// Month and year below the title ("Okt. 2026"); the tile shows the day.
  String _month(DateTime? date) => date == null ? '' : DateFormat.yMMM(currentIntlLocale()).format(date);

  String _join(List<String?> parts) => parts.whereType<String>().where((s) => s.isNotEmpty).join(' · ');

  VoidCallback? _openTermin(Map<String, dynamic> item, {required bool canOpenTermin}) {
    final attendanceId = item['attendanceId'];
    if (!canOpenTermin || attendanceId is! int) return null;
    return () => context.push(RedesignRoutes.event(attendanceId));
  }

  /// "Kommende Termine" (hidden while empty, like the old accordion).
  List<Widget> _upcoming({required bool canOpenTermin}) {
    final l10n = context.l10n;
    final upcoming = ref.watch(upcomingAttendancesProvider(_id)).valueOrNull ?? const [];
    if (upcoming.isEmpty) return const [];
    return [
      RdGroupLabel(l10n.redesignHistoryUpcoming),
      RdGroupedList(
        children: [
          for (final item in upcoming)
            Builder(builder: (context) {
              final date = DateTime.tryParse(item['date']?.toString() ?? '');
              final title = item['meetingName']?.toString() ?? '';
              final onTap = _openTermin(item, canOpenTermin: canOpenTermin);
              return RdListRow(
                leading: _dateTile(date),
                title: title.isNotEmpty ? title : _month(date),
                subtitle: _join([if (title.isNotEmpty) _month(date), item['notes']?.toString()]),
                trailing: rdOwnStatusPill(l10n, AttendanceStatus.fromValue(_intOf(item['status']))),
                showChevron: false,
                onTap: onTap,
              );
            }),
        ],
      ),
      const SizedBox(height: 22),
    ];
  }

  /// "Verlauf": Termine with their status and the changes of the person.
  List<Widget> _history({required bool canEdit, required bool hasLeft, required bool canOpenTermin}) {
    final l10n = context.l10n;
    final historyAsync = ref.watch(personHistoryProvider(_id));
    final label = RdGroupLabel(l10n.redesignHistoryList);
    return historyAsync.when(
      loading: () => [label, RdInfoCard(text: l10n.redesignTodayLoading, loading: true)],
      error: (_, __) => [
        label,
        RdInfoCard(
          text: l10n.redesignTodayLoadFailed,
          icon: Icons.cloud_off_outlined,
          action: RdOutlineButton(
            label: l10n.redesignCommonRetry,
            onPressed: () => ref.invalidate(personHistoryProvider(_id)),
          ),
        ),
      ],
      data: (history) {
        final seasonStart = DateTime.tryParse(ref.watch(currentTenantProvider)?.seasonStart ?? '');
        final showAll = hasLeft || ref.watch(showAllHistoryProvider);
        final items = filterHistoryBySeason(history, seasonStart, showAll: showAll);
        if (items.isEmpty) return [label, RdInfoCard(text: l10n.redesignHistoryEmpty, icon: Icons.history)];
        return [
          label,
          RdGroupedList(
            children: [
              for (final item in items) _historyRow(item, canEdit: canEdit, canOpenTermin: canOpenTermin),
            ],
          ),
        ];
      },
    );
  }

  Widget _historyRow(Map<String, dynamic> item, {required bool canEdit, required bool canOpenTermin}) {
    final l10n = context.l10n;
    final p = context.rd;
    // Ionic date pipe: local time (history entries are stored as UTC ISO).
    final date = DateTime.tryParse(item['date']?.toString() ?? '')?.toLocal();
    final type = item['type'] as int?;
    final text = item['text']?.toString() ?? '';
    final isAttendance = type == PlayerHistoryType.attendance.value;

    if (isAttendance) {
      final title = item['meetingName']?.toString() ?? '';
      return RdListRow(
        leading: _dateTile(date),
        title: title.isNotEmpty ? title : _month(date),
        subtitle: _join([if (title.isNotEmpty) _month(date), item['notes']?.toString()]),
        trailing: rdHistoryStatusPill(l10n, _intOf(item['status'])),
        showChevron: false,
        onTap: _openTermin(item, canOpenTermin: canOpenTermin),
      );
    }

    final heading = date == null ? '' : historyEntryTitle(type, date);
    final body = historyEntryBody(type, text);
    final title = heading.isNotEmpty ? heading : (body.isNotEmpty ? body : _month(date));
    return RdListRow(
      leading: _dateTile(date),
      title: title,
      subtitle: heading.isNotEmpty ? body : (body.isNotEmpty ? _month(date) : null),
      showChevron: false,
      trailing: canEdit
          ? IconButton(
              tooltip: l10n.redesignHistoryMore,
              icon: Icon(Icons.more_horiz, color: p.text2),
              onPressed: () => _delete(item),
            )
          : null,
      // Ionic onHisItemClicked: the old note of a NOTES entry.
      onTap: type == PlayerHistoryType.notes.value && date != null
          ? () => showOldHistoryNote(context, date, text)
          : null,
    );
  }

  /// "⋯" › "Eintrag löschen": same removal as the old accordion. The
  /// group is held before the first await; after a group switch nothing
  /// is written.
  Future<void> _delete(Map<String, dynamic> item) async {
    final l10n = context.l10n;
    final container = ProviderScope.containerOf(context, listen: false);
    final tenantId = container.read(currentTenantIdProvider);
    final repo = container.read(playerRepositoryWithTenantProvider);
    final id = _id;
    final action = await showRdChoiceSheet<bool>(
      context,
      title: l10n.redesignHistoryMore,
      options: [(true, l10n.redesignHistoryRemove)],
    );
    if (action != true || !mounted) return;
    final confirmed = await showAppConfirm(
      context,
      // Ionic removeHis alert: header only, buttons Abbrechen / Ja.
      title: l10n.personRemoveEntry,
      confirmText: l10n.commonYes,
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    if (DemoGuard.blocked()) return; // DEMO_GUARD
    bool sameGroup() => tenantId != null && container.read(currentTenantIdProvider) == tenantId;
    if (!sameGroup()) return;

    try {
      final person = await container.read(personProvider(id).future);
      if (person == null || person.id == null || !sameGroup()) return;
      await repo.updatePlayerFields(person.id!, {'history': historyWithoutEntry(person.history, item)});
      container.invalidate(personProvider(id));
      container.invalidate(personHistoryProvider(id));
      container.invalidate(realtimePlayersProvider);
      if (mounted) ToastHelper.showSuccess(context, l10n.personEntryRemoved);
    } catch (_) {
      if (mounted) ToastHelper.showError(context, l10n.personEntryRemoveFailed);
    }
  }
}
