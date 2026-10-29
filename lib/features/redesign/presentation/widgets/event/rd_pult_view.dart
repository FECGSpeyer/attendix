import 'package:flutter/material.dart';

import '../../../../../core/constants/enums.dart';
import '../../../../../core/theme/redesign/rd_theme.dart';
import '../../../../../l10n/l10n.dart';
import '../../../../attendance/presentation/widgets/attendance_detail/status_chip.dart'
    show ionicStatusLabel;
import '../../../data/providers/rd_today_providers.dart';
import '../../../data/rd_event_logic.dart';
import '../rd_widgets.dart';
import 'rd_record_widgets.dart';

/// REDESIGN: Pultmodus (canvas "TabletErfassen"): recording on a tablet at
/// the conductor's stand. Big tiles per register: tap = present, tap again
/// = back, long press = more status and note. The Termin page keeps the
/// state, the writes and "Rückgängig"; this view only draws them.
class RdPultView extends StatelessWidget {
  const RdPultView({
    super.key,
    required this.title,
    required this.members,
    required this.available,
    required this.showNote,
    required this.busy,
    required this.onToggle,
    required this.onMore,
    required this.onAllOpenPresent,
    required this.onDone,
    this.bottomPadding = 24,
  });

  /// Name of the Termin ("Gesamtprobe").
  final String title;
  final List<RdMember> members;
  final Set<AttendanceStatus> available;

  /// Helpers without the notes permission do not see notes.
  final bool showNote;

  /// A bulk write is running.
  final bool busy;
  final ValueChanged<RdMember> onToggle;
  final ValueChanged<RdMember> onMore;
  final VoidCallback onAllOpenPresent;

  /// Leaves the Pultmodus.
  final VoidCallback onDone;

  /// Room for the "Rückgängig" bar.
  final double bottomPadding;

  /// Tiles per row: at least 2, about 170 pt each.
  static int columnsFor(double width) => (width / 170).floor().clamp(2, 8);

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final counts = RdStatusCounts.fromStatuses(members.map((m) => m.status));
    final canPresent = available.contains(AttendanceStatus.present);

    // Registers in the page's order ("Holz", "Blech" …).
    final groups = <({String name, List<RdMember> members})>[];
    for (final m in members) {
      final name = m.groupName ?? l10n.attendanceNoGroup;
      if (groups.isEmpty || groups.last.name != name) {
        groups.add((name: name, members: [m]));
      } else {
        groups.last.members.add(m);
      }
    }

    Widget countChip(String text, Color color, Color soft) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: soft, borderRadius: BorderRadius.circular(999)),
          child: Text(text, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: color)),
        );

    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              sliver: SliverList.list(
                children: [
                  Row(
                    children: [
                      Expanded(child: RdBackLink(label: l10n.redesignPultBack, onTap: onDone)),
                      FilledButton(
                        onPressed: onDone,
                        style: FilledButton.styleFrom(
                          backgroundColor: p.primary,
                          foregroundColor: p.onPrimary,
                          minimumSize: const Size(88, 44),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(p.buttonRadius)),
                        ),
                        child: Text(l10n.redesignPultDone),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Semantics(
                    header: true,
                    child: Text(
                      l10n.redesignPultTitle(title),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: RdType.title(p),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(l10n.redesignPultHint, style: RdType.meta(p)),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      countChip(l10n.redesignEventCountPresent(counts.present), p.present, p.presentSoft),
                      if (counts.lateAnnounced > 0)
                        countChip(l10n.redesignEventCountLate(counts.lateAnnounced), p.late, p.lateSoft),
                      countChip(l10n.redesignEventCountExcused(counts.excused), p.excused, p.excusedSoft),
                      if (counts.absent > 0)
                        countChip(l10n.redesignEventCountAbsent(counts.absent), p.absent, p.absentSoft),
                      countChip(l10n.redesignEventCountOpen(counts.open), p.text2, p.track),
                      if (canPresent)
                        OutlinedButton.icon(
                          onPressed: counts.open == 0 || busy ? null : onAllOpenPresent,
                          icon: const Icon(Icons.done_all, size: 20),
                          label: Text(busy ? l10n.redesignEventSaving : l10n.redesignPultAllOpen),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: p.present,
                            side: BorderSide(color: p.present),
                            minimumSize: const Size(0, 44),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(p.buttonRadius)),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            for (final g in groups) ...[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 8),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          g.name,
                          style: RdType.section(p),
                        ),
                      ),
                      Text(
                        l10n.redesignPultGroupCount(
                          g.members.where((m) => m.status == AttendanceStatus.present).length,
                          g.members.length,
                        ),
                        style: RdType.meta(p),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverLayoutBuilder(
                  builder: (context, constraints) => SliverGrid.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columnsFor(constraints.crossAxisExtent),
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      mainAxisExtent: 84,
                    ),
                    itemCount: g.members.length,
                    itemBuilder: (context, i) {
                      final m = g.members[i];
                      return RdPultTile(
                        key: ValueKey('rd-pult-${m.id}'),
                        member: m,
                        showNote: showNote,
                        onTap: canPresent ? () => onToggle(m) : null,
                        onLongPress: () => onMore(m),
                      );
                    },
                  ),
                ),
              ),
            ],
            SliverToBoxAdapter(child: SizedBox(height: bottomPadding + MediaQuery.paddingOf(context).bottom)),
          ],
        ),
      ),
    );
  }
}

/// One person in the Pultmodus: solid when present, tinted for the other
/// statuses, white with a border while open. The second line says the
/// status (and the note, e.g. „Krank“).
class RdPultTile extends StatelessWidget {
  const RdPultTile({
    super.key,
    required this.member,
    required this.onTap,
    required this.onLongPress,
    this.showNote = true,
  });

  final RdMember member;
  final bool showNote;
  final VoidCallback? onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final status = member.status;
    final look = rdStatusLook(p, status);
    final present = status == AttendanceStatus.present;
    final open = status == AttendanceStatus.neutral;
    final background = present ? p.present : (open ? p.surface : look.soft);
    final foreground = present ? Colors.white : (open ? p.text : look.color);
    // Same words as the list ("Kommt später", "Entschuldigt").
    final statusText = switch (status) {
      AttendanceStatus.neutral => l10n.redesignPultStatusOpen,
      AttendanceStatus.lateExcused => l10n.redesignStatusLater,
      AttendanceStatus.excused => l10n.redesignStatusExcused,
      _ => ionicStatusLabel(status),
    };
    final note = showNote ? (member.note ?? '').trim() : '';
    final sub = note.isEmpty ? statusText : '$statusText · „$note“';

    return Semantics(
      button: true,
      label: '${member.name}, $sub',
      hint: l10n.redesignPultHint,
      excludeSemantics: true,
      onLongPress: onLongPress,
      child: Material(
        color: background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: open ? BorderSide(color: p.line, width: 1.5) : BorderSide.none,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        member.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: foreground),
                      ),
                    ),
                    if (!open) Icon(look.icon, size: 20, color: foreground),
                  ],
                ),
                Text(
                  sub,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: present ? Colors.white.withValues(alpha: 0.85) : (open ? p.text2 : foreground),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
