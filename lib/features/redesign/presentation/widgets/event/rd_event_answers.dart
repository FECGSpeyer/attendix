import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../../core/constants/enums.dart';
import '../../../../../core/providers/debug_providers.dart';
import '../../../../../core/theme/redesign/rd_theme.dart';
import '../../../../../data/models/attendance/attendance.dart';
import '../../../../../l10n/l10n.dart';
import '../../../../attendance/presentation/widgets/attendance_detail/auto_message_panel.dart';
import '../../../data/rd_dates.dart';
import '../../../data/rd_event_logic.dart';
import '../rd_widgets.dart';

/// "07:12" today, "gestern", "Mo" within a week, else "3.11.".
String rdChangedShort(AppLocalizations l10n, String? changedAt, {DateTime? now}) {
  final at = changedAt == null ? null : DateTime.tryParse(changedAt)?.toLocal();
  if (at == null) return '';
  final days = rdDaysBetween(at, now ?? DateTime.now());
  if (days <= 0) return DateFormat('HH:mm').format(at);
  if (days == 1) return l10n.redesignEventYesterday;
  if (days < 7) return DateFormat.E(currentIntlLocale()).format(at).replaceAll('.', '');
  return DateFormat('d.M.').format(at);
}

/// Pill of a person in the sign-out list. Before the Termin an excused
/// person "hat sich abgemeldet", afterwards the person "ist entschuldigt".
RdPill _statusPill(AppLocalizations l10n, AttendanceStatus status, {required bool started}) => switch (status) {
  AttendanceStatus.excused => RdPill(started ? l10n.redesignStatusExcused : l10n.redesignEventSignedOut, tone: RdTone.excused),
  AttendanceStatus.absent => RdPill(l10n.redesignStatusAbsent, tone: RdTone.absent),
  AttendanceStatus.lateExcused => RdPill(l10n.redesignStatusLater, tone: RdTone.late),
  _ => RdPill(l10n.redesignStatusLate, tone: RdTone.late),
};

/// "Sopran · „Krank“", "Alt · ohne Grund" (the reason only for those who
/// may see notes).
String _subtitle(AppLocalizations l10n, RdMember m, {required bool showNote}) {
  final note = (m.note ?? '').trim();
  return [
    m.groupName ?? '',
    if (showNote) note.isEmpty ? l10n.redesignEventNoReason : '„$note“',
  ].where((s) => s.isNotEmpty).join(' · ');
}

/// One person who will not be there: name, voice and reason, when, pill.
class _SignoutRow extends StatelessWidget {
  const _SignoutRow({required this.member, required this.showNote, required this.started, required this.onTap});

  final RdMember member;
  final bool showNote;
  final bool started;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final when = rdChangedShort(l10n, member.changedAt);
    return InkWell(
      key: ValueKey('rd-signout-${member.id}'),
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: p.text),
                    ),
                    Text(
                      _subtitle(l10n, member, showNote: showNote),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: RdType.meta(p, size: 13),
                    ),
                  ],
                ),
              ),
              if (when.isNotEmpty) ...[
                const SizedBox(width: 8),
                Text(when, style: RdType.meta(p, size: 12)),
              ],
              const SizedBox(width: 8),
              _statusPill(l10n, member.status, started: started),
            ],
          ),
        ),
      ),
    );
  }
}

/// Inside the answers card (concept L1/L4, Leon 2026-11-04): first everyone
/// who signed out or is absent, newest first, then one line "Kommt später:"
/// (after the start "Verspätet:"). From 7 sign-outs on only the 5 newest
/// and "Alle anzeigen".
class RdSignoutList extends StatelessWidget {
  const RdSignoutList({
    super.key,
    required this.members,
    required this.title,
    required this.showNote,
    required this.started,
    required this.onOpen,
  });

  final List<RdMember> members;

  /// Termin title for the "Alle anzeigen" sheet.
  final String title;
  final bool showNote;

  /// The Termin has started: "Entschuldigt" / "Verspätet" instead of
  /// "Abgemeldet" / "Kommt später".
  final bool started;
  final ValueChanged<RdMember> onOpen;

  static const _collapseFrom = 7;
  static const _collapsedRows = 5;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final signouts = rdSignouts(members);
    final away = signouts.away;
    final later = signouts.later;
    if (away.isEmpty && later.isEmpty) return const SizedBox.shrink();
    final shown = away.length >= _collapseFrom ? away.take(_collapsedRows).toList() : away;
    final showAll = shown.length < away.length || later.length > 4;

    void openAll() => showRdSignoutsSheet(
      context,
      members: members,
      title: title,
      showNote: showNote,
      started: started,
      onOpen: onOpen,
    );

    final rows = <Widget>[];
    for (final m in shown) {
      if (rows.isNotEmpty) rows.add(Divider(height: 1, thickness: 1, color: p.line));
      rows.add(_SignoutRow(member: m, showNote: showNote, started: started, onTap: () => onOpen(m)));
    }
    final laterNames = [
      for (final m in later)
        showNote && (m.note ?? '').trim().isNotEmpty ? '${m.name} „${m.note!.trim()}“' : m.name,
    ].join(', ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 14),
        Divider(height: 1, thickness: 1, color: p.line),
        const SizedBox(height: 4),
        ...rows,
        if (later.isNotEmpty) ...[
          if (rows.isNotEmpty) Divider(height: 1, thickness: 1, color: p.line),
          InkWell(
            key: const Key('rd-signouts-later'),
            onTap: later.length == 1 ? () => onOpen(later.single) : openAll,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Icon(Icons.schedule_rounded, size: 18, color: p.late),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '${started ? l10n.redesignStatusLate : l10n.redesignStatusLater}: ',
                            style: TextStyle(fontWeight: FontWeight.w700, color: p.late),
                          ),
                          TextSpan(text: laterNames),
                        ],
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 14, color: p.text, height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        if (showAll)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: const Key('rd-signouts-all'),
              onPressed: openAll,
              style: TextButton.styleFrom(
                foregroundColor: p.link,
                minimumSize: const Size(44, 44),
                padding: EdgeInsets.zero,
                textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              child: Text(l10n.redesignEventShowAll(away.length + later.length)),
            ),
          ),
      ],
    );
  }
}

/// "Rückmeldungen mit Grund" (concept L10): everyone who will not be there
/// or comes later, grouped, newest first. Tapping a person opens the
/// person sheet.
Future<void> showRdSignoutsSheet(
  BuildContext context, {
  required List<RdMember> members,
  required String title,
  required bool showNote,
  required bool started,
  required ValueChanged<RdMember> onOpen,
}) {
  final l10n = context.l10n;
  final signouts = rdSignouts(members);
  final groups = [
    (
      started ? l10n.redesignStatusExcused : l10n.redesignEventSignedOut,
      signouts.away.where((m) => m.status == AttendanceStatus.excused).toList(),
    ),
    (l10n.redesignStatusAbsent, signouts.away.where((m) => m.status == AttendanceStatus.absent).toList()),
    (started ? l10n.redesignStatusLate : l10n.redesignStatusLater, signouts.later),
  ];
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    useSafeArea: true,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: context.rd.bg,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (sheet) {
      final p = sheet.rd;
      return ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(sheet).height * 0.85),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l10n.redesignEventAnswersTitle, style: RdType.cardTitle(p)),
                Text(l10n.redesignEventNewestFirst(title), style: RdType.meta(p, size: 14)),
                const SizedBox(height: 12),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final (label, list) in groups)
                          if (list.isNotEmpty) ...[
                            RdGroupLabel(l10n.redesignEventSectionCount(label, list.length)),
                            RdCard(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                              child: Column(
                                children: [
                                  for (var i = 0; i < list.length; i++) ...[
                                    if (i > 0) Divider(height: 1, thickness: 1, color: p.line),
                                    _SignoutRow(
                                      member: list[i],
                                      showNote: showNote,
                                      started: started,
                                      onTap: () {
                                        Navigator.of(sheet).pop();
                                        onOpen(list[i]);
                                      },
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                RdPrimaryButton(label: l10n.redesignCommonDone, onPressed: () => Navigator.of(sheet).pop()),
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// "Abschluss" once the Termin has started (concept L5, Admins and
/// Verantwortliche): "Unentschuldigte anschreiben" and what the automatic
/// messages do for this Termin, with the members' answers.
class RdEventClosingSection extends ConsumerWidget {
  const RdEventClosingSection({
    super.key,
    required this.attendance,
    required this.type,
    required this.members,
    required this.personAttendanceIds,
  });

  final Attendance attendance;
  final AttendanceType? type;
  final List<RdMember> members;
  final Map<int, String?> personAttendanceIds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final role = ref.watch(effectiveRoleProvider);
    if (!(role.isAdmin || role.isResponsible) || attendance.id == null) return const SizedBox.shrink();
    final people = [
      for (final m in members)
        AutoMessagePanelPerson(
          personId: m.id,
          personAttendanceId: personAttendanceIds[m.id],
          name: m.name,
          status: m.status,
          left: (m.person.left ?? '').isNotEmpty,
        ),
    ];
    final unexcused = unexcusedPeople(people);
    return AutoMessagePanel(
      attendance: attendance,
      attendanceType: type,
      people: people,
      look: const _RdAutoMessageLook(),
      leading: [
        if (unexcused.isNotEmpty)
          RdListRow(
            key: const Key('rd-event-write-unexcused'),
            leading: RdCountBadge(unexcused.length, tone: RdTone.absent),
            title: l10n.autoMessagesWriteUnexcusedMenu(unexcused.length),
            subtitle: unexcused.map((u) => u.name).join(', '),
            onTap: () => openWriteUnexcused(
              context,
              ref,
              attendance: attendance,
              typeName: type?.name ?? '',
              people: people,
            ),
          ),
      ],
    );
  }
}

/// The automatic messages in the new design: one grouped list under
/// "Abschluss", the answers as their own list.
class _RdAutoMessageLook extends AutoMessagePanelLook {
  const _RdAutoMessageLook();

  @override
  Widget frame(BuildContext context, {required List<Widget> rows, Widget? answers}) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SizedBox(height: 24),
      RdGroupLabel(context.l10n.redesignEventClosing),
      if (rows.isNotEmpty) RdGroupedList(children: rows),
      if (answers != null) ...[const SizedBox(height: 16), answers],
    ],
  );

  @override
  Widget banner(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    (String, VoidCallback)? action,
  }) {
    final p = context.rd;
    return RdListRow(
      leading: RdRowIcon(icon),
      title: title,
      subtitle: subtitle,
      showChevron: false,
      trailing: action == null
          ? null
          : TextButton(
            onPressed: action.$2,
            style: TextButton.styleFrom(
              foregroundColor: p.link,
              minimumSize: const Size(44, 44),
              textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            child: Text(action.$1),
          ),
    );
  }

  @override
  Widget answers(BuildContext context, {required String title, required List<AutoMessageAnswer> answers}) {
    final p = context.rd;
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RdGroupLabel(title),
        RdGroupedList(
          children: [
            for (final a in answers)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RdRowIcon(a.wasPresent ? Icons.back_hand_outlined : Icons.chat_bubble_outline),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(a.name, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: p.text)),
                          const SizedBox(height: 2),
                          Text(a.detail, style: RdType.meta(p, size: 14)),
                          if (a.pending) ...[
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                RdPrimaryButton(
                                  label: a.acceptLabel,
                                  height: 40,
                                  onPressed: a.busy ? null : () => a.onDecide(true),
                                ),
                                RdOutlineButton(
                                  label: l10n.autoMessagesReject,
                                  height: 40,
                                  onPressed: a.busy ? null : () => a.onDecide(false),
                                ),
                              ],
                            ),
                          ] else if ((a.stateText ?? '').isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(a.stateText!, style: RdType.meta(p, size: 13)),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}
