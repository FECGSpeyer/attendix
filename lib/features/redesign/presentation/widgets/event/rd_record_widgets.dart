import 'package:flutter/material.dart';

import '../../../../../core/constants/enums.dart';
import '../../../../../core/theme/redesign/rd_palette.dart';
import '../../../../../core/theme/redesign/rd_theme.dart';
import '../../../../../l10n/l10n.dart';
import '../../../../attendance/presentation/widgets/attendance_detail/status_chip.dart'
    show ionicSelectableStatuses, ionicStatusLabel;
import '../../../data/providers/rd_today_providers.dart';
import '../../../data/rd_event_logic.dart';
import '../rd_widgets.dart';

/// Colour and icon of a status in the new design.
({Color color, Color soft, IconData icon}) rdStatusLook(RdPalette p, AttendanceStatus status) =>
    switch (status) {
      AttendanceStatus.present => (color: p.present, soft: p.presentSoft, icon: Icons.check_rounded),
      AttendanceStatus.late => (color: p.late, soft: p.lateSoft, icon: Icons.schedule_rounded),
      AttendanceStatus.lateExcused => (color: p.late, soft: p.lateSoft, icon: Icons.more_time_rounded),
      AttendanceStatus.excused => (color: p.excused, soft: p.excusedSoft, icon: Icons.event_busy_outlined),
      AttendanceStatus.absent => (color: p.absent, soft: p.absentSoft, icon: Icons.close_rounded),
      AttendanceStatus.neutral => (color: p.text2, soft: p.track, icon: Icons.remove_rounded),
    };

/// "23 da · 1 später · 3 entsch. · 0 fehlt · 5 offen" (canvas D5).
class RdRecordCounts extends StatelessWidget {
  const RdRecordCounts({super.key, required this.counts});

  final RdStatusCounts counts;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    Widget chip(String text, Color color, Color soft) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(color: soft, borderRadius: BorderRadius.circular(999)),
          child: Text(text, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
        );
    return Semantics(
      container: true,
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          chip(l10n.redesignEventCountPresent(counts.present), p.present, p.presentSoft),
          chip(l10n.redesignEventCountLate(counts.lateAnnounced), p.late, p.lateSoft),
          chip(l10n.redesignEventCountExcused(counts.excused), p.excused, p.excusedSoft),
          chip(l10n.redesignEventCountAbsent(counts.absent), p.absent, p.absentSoft),
          chip(l10n.redesignEventCountOpen(counts.open), p.text2, p.track),
        ],
      ),
    );
  }
}

/// One person of the recording list: name, note, three status buttons
/// (only the ones the Termin type allows) and "more".
class RdRecordRow extends StatelessWidget {
  const RdRecordRow({
    super.key,
    required this.member,
    required this.available,
    required this.showNote,
    required this.onTap,
    required this.onMore,
  });

  final RdMember member;
  final Set<AttendanceStatus> available;

  /// Helpers without the notes permission do not see notes.
  final bool showNote;
  final ValueChanged<AttendanceStatus> onTap;
  final VoidCallback onMore;

  static const _buttons = [AttendanceStatus.present, AttendanceStatus.late, AttendanceStatus.absent];

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final status = member.status;
    final note = showNote ? (member.note ?? '').trim() : '';
    final badge = switch (status) {
      AttendanceStatus.excused => l10n.redesignStatusExcused,
      AttendanceStatus.lateExcused => l10n.redesignStatusLater,
      _ => null,
    };
    final look = rdStatusLook(p, status);
    final info = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          member.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: p.text),
        ),
        if (badge != null)
          Text(
            badge,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: look.color),
          ),
        if (note.isNotEmpty)
          Text(
            '„$note“',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: RdType.meta(p, size: 13),
          ),
      ],
    );
    final buttons = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final s in _buttons)
          if (available.contains(s)) ...[
            _StatusButton(status: s, active: status == s, onTap: () => onTap(s)),
            const SizedBox(width: 6),
          ],
        Semantics(
          button: true,
          label: l10n.redesignEventMoreStatus(member.name),
          excludeSemantics: true,
          child: InkResponse(
            onTap: onMore,
            radius: 22,
            child: SizedBox(
              width: 30,
              height: 44,
              child: Icon(Icons.more_horiz, color: p.text2),
            ),
          ),
        ),
      ],
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Narrow phones: the buttons go below the name.
          if (constraints.maxWidth < 300) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                info,
                const SizedBox(height: 6),
                Align(alignment: Alignment.centerRight, child: buttons),
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: info),
              const SizedBox(width: 8),
              buttons,
            ],
          );
        },
      ),
    );
  }
}

class _StatusButton extends StatelessWidget {
  const _StatusButton({required this.status, required this.active, required this.onTap});

  final AttendanceStatus status;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final look = rdStatusLook(p, status);
    return Semantics(
      button: true,
      toggled: active,
      label: ionicStatusLabel(status),
      excludeSemantics: true,
      child: Material(
        color: active ? look.color : p.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: active ? BorderSide.none : BorderSide(color: p.offBorder, width: 1.5),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(look.icon, size: 22, color: active ? p.onStatus : look.color),
          ),
        ),
      ),
    );
  }
}

/// Result of [showRdStatusSheet].
typedef RdStatusSheetResult = ({AttendanceStatus status, String? note});

/// "Weitere Status" (canvas StatusSheet): every status of the type and the
/// note of this Termin. Returns null when closed without "Fertig".
Future<RdStatusSheetResult?> showRdStatusSheet(
  BuildContext context, {
  required RdMember member,
  required String subtitle,
  required List<AttendanceStatus> available,
  required bool canEditNote,
}) {
  return showModalBottomSheet<RdStatusSheetResult>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: context.rd.bg,
    builder: (_) => _StatusSheet(
      member: member,
      subtitle: subtitle,
      available: available,
      canEditNote: canEditNote,
    ),
  );
}

class _StatusSheet extends StatefulWidget {
  const _StatusSheet({
    required this.member,
    required this.subtitle,
    required this.available,
    required this.canEditNote,
  });

  final RdMember member;
  final String subtitle;
  final List<AttendanceStatus> available;
  final bool canEditNote;

  @override
  State<_StatusSheet> createState() => _StatusSheetState();
}

class _StatusSheetState extends State<_StatusSheet> {
  late AttendanceStatus _status = widget.member.status;
  late final _note = TextEditingController(text: widget.member.note ?? '');

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final statuses = ionicSelectableStatuses(widget.available);
    if (!statuses.contains(_status)) statuses.insert(0, _status);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.member.name, style: RdType.cardTitle(p)),
              if (widget.subtitle.isNotEmpty)
                Text(widget.subtitle, style: RdType.meta(p, size: 14)),
              const SizedBox(height: 16),
              Semantics(
                label: l10n.redesignEventStatus,
                container: true,
                child: RdGroupedList(
                  children: [
                    for (final s in statuses)
                      RdListRow(
                        leading: RdRowIcon(
                          rdStatusLook(p, s).icon,
                          color: rdStatusLook(p, s).color,
                          background: rdStatusLook(p, s).soft,
                        ),
                        title: ionicStatusLabel(s),
                        subtitle: s == AttendanceStatus.neutral ? l10n.redesignEventNeutralHint : null,
                        selected: s == _status,
                        showChevron: false,
                        trailing: s == _status ? Icon(Icons.check_circle, color: p.primary) : null,
                        onTap: () => setState(() => _status = s),
                      ),
                  ],
                ),
              ),
              if (widget.canEditNote) ...[
                const SizedBox(height: 16),
                RdGroupLabel(l10n.redesignEventNote),
                TextField(
                  controller: _note,
                  minLines: 1,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: l10n.redesignEventNoteHint,
                    filled: true,
                    fillColor: p.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(p.buttonRadius),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              RdPrimaryButton(
                label: l10n.redesignCommonDone,
                onPressed: () => Navigator.of(context).pop((
                  status: _status,
                  note: widget.canEditNote ? _note.text.trim() : widget.member.note,
                )),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Anna Berg: Anwesend · Rückgängig" at the bottom of the recording view.
class RdUndoBar extends StatelessWidget {
  const RdUndoBar({super.key, required this.text, required this.onUndo});

  final String text;
  final VoidCallback? onUndo;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    return Semantics(
      liveRegion: true,
      container: true,
      child: Material(
        color: p.toastBg,
        elevation: 6,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.only(left: 16, right: 4),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    text,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 15, color: p.toastText),
                  ),
                ),
                if (onUndo != null)
                  TextButton(
                    onPressed: onUndo,
                    style: TextButton.styleFrom(
                      foregroundColor: p.toastAction,
                      minimumSize: const Size(44, 44),
                      textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                    child: Text(l10n.redesignEventUndo),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
