import 'package:flutter/material.dart';

import '../../../../core/theme/redesign/rd_theme.dart';
import '../../../redesign/presentation/widgets/rd_widgets.dart';
import '../../../../l10n/l10n.dart';

/// A person that can be assigned to a duty.
class DutyCandidate {
  const DutyCandidate({
    required this.personAttendanceId,
    required this.name,
    this.count = 0,
    this.sameDay = false,
    this.unavailableNote = '',
  });

  final String personAttendanceId;
  final String name;

  /// Duties of this person in the month of the Termin
  final int count;

  /// Already on duty that day (other Termin)
  final bool sameDay;

  /// Cancelled or regularly unavailable; shown greyed out, still selectable
  final String unavailableNote;
}

/// Sheet "Person einteilen": persons sorted by number of duties, multi-select.
/// Returns the selected person attendance ids, or null when cancelled.
Future<List<String>?> showDutyAssignSheet(
  BuildContext context, {
  required String title,
  required int openPlaces,
  required List<DutyCandidate> candidates,
  String monthLabel = '',
}) {
  return showRdSheet<List<String>>(
    context,
    _DutyAssignSheet(title: title, openPlaces: openPlaces, candidates: candidates, monthLabel: monthLabel),
  );
}

class _DutyAssignSheet extends StatefulWidget {
  const _DutyAssignSheet({
    required this.title,
    required this.openPlaces,
    required this.candidates,
    required this.monthLabel,
  });

  final String title;
  final int openPlaces;
  final List<DutyCandidate> candidates;
  final String monthLabel;

  @override
  State<_DutyAssignSheet> createState() => _DutyAssignSheetState();
}

class _DutyAssignSheetState extends State<_DutyAssignSheet> {
  final Set<String> _selected = {};
  late final List<DutyCandidate> _sorted;

  @override
  void initState() {
    super.initState();
    _sorted = [...widget.candidates]
      ..sort((a, b) {
        final ua = a.unavailableNote.isNotEmpty ? 1 : 0;
        final ub = b.unavailableNote.isNotEmpty ? 1 : 0;
        if (ua != ub) return ua - ub;
        if (a.count != b.count) return a.count - b.count;
        return a.name.compareTo(b.name);
      });
  }

  String get _confirmLabel {
    final names = _sorted
        .where((c) => _selected.contains(c.personAttendanceId))
        .map((c) => c.name.split(' ').first)
        .toList();
    final l10n = context.l10n;
    if (names.isEmpty) return l10n.attendanceAssign;
    return names.length == 1 ? l10n.dutyAssignName(names.first) : l10n.dutyAssignPeople(names.length);
  }

  String _subtitle(DutyCandidate c) {
    if (c.unavailableNote.isNotEmpty) return c.unavailableNote;
    final l10n = context.l10n;
    final duties = l10n.dutyDutiesCount(c.count);
    final month = widget.monthLabel.isNotEmpty ? l10n.dutyInMonth(widget.monthLabel) : '';
    final sameDay = c.sameDay ? ' ${l10n.dutySameDay}' : '';
    return '$duties$month$sameDay';
  }

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RdSheetTitle(l10n.attendanceAssignPerson),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Text(
            '${widget.title} · ${l10n.dutyPlacesFree(widget.openPlaces)}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: RdType.meta(p, size: 13),
          ),
        ),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            children: [
              if (_sorted.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(l10n.dutyAllAssigned, textAlign: TextAlign.center, style: RdType.meta(p, size: 14)),
                )
              else
                RdGroupedList(
                  children: [
                    for (final c in _sorted)
                      Semantics(
                        checked: _selected.contains(c.personAttendanceId),
                        child: RdListRow(
                          leading: Icon(
                            _selected.contains(c.personAttendanceId) ? Icons.check_circle : Icons.radio_button_unchecked,
                            color: _selected.contains(c.personAttendanceId) ? p.primary : p.text2,
                          ),
                          title: c.name,
                          titleColor: c.unavailableNote.isNotEmpty ? p.text2 : null,
                          subtitle: _subtitle(c),
                          showChevron: false,
                          onTap: () => setState(() {
                            if (!_selected.remove(c.personAttendanceId)) _selected.add(c.personAttendanceId);
                          }),
                        ),
                      ),
                  ],
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
                child: Text(l10n.dutyAssignHint, style: RdType.meta(p, size: 13)),
              ),
              if (_selected.length > widget.openPlaces)
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                  child: Text(l10n.dutyOverbooked, style: RdType.meta(p, size: 13).copyWith(color: p.late)),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: RdPrimaryButton(
            label: _confirmLabel,
            onPressed: _selected.isEmpty ? null : () => Navigator.of(context).pop(_selected.toList()),
          ),
        ),
      ],
    );
  }
}
