import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';

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
  return showModalBottomSheet<List<String>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 1,
      builder: (ctx, scrollController) => _DutyAssignSheet(
        title: title,
        openPlaces: openPlaces,
        candidates: candidates,
        monthLabel: monthLabel,
        scrollController: scrollController,
      ),
    ),
  );
}

class _DutyAssignSheet extends StatefulWidget {
  const _DutyAssignSheet({
    required this.title,
    required this.openPlaces,
    required this.candidates,
    required this.monthLabel,
    required this.scrollController,
  });

  final String title;
  final int openPlaces;
  final List<DutyCandidate> candidates;
  final String monthLabel;
  final ScrollController scrollController;

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
    if (names.isEmpty) return 'Einteilen';
    return names.length == 1 ? '${names.first} einteilen' : '${names.length} Personen einteilen';
  }

  String _subtitle(DutyCandidate c) {
    if (c.unavailableNote.isNotEmpty) return c.unavailableNote;
    final duties = c.count == 1 ? '1 Dienst' : '${c.count} Dienste';
    final month = widget.monthLabel.isNotEmpty ? ' im ${widget.monthLabel}' : '';
    final sameDay = c.sameDay ? ' · am selben Tag schon dran' : '';
    return '$duties$month$sameDay';
  }

  @override
  Widget build(BuildContext context) {
    final places = widget.openPlaces == 1 ? '1 Platz frei' : '${widget.openPlaces} Plätze frei';
    return Column(
      children: [
        ListTile(
          leading: IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Abbrechen',
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: const Text('Person einteilen', style: TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text('${widget.title} · $places'),
        ),
        const Divider(height: 1),
        Expanded(
          child: _sorted.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(AppDimensions.paddingL),
                    child: Text(
                      'Alle aus dem Personenkreis sind schon eingeteilt.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView(
                  controller: widget.scrollController,
                  children: [
                    for (final c in _sorted)
                      Opacity(
                        opacity: c.unavailableNote.isNotEmpty ? 0.55 : 1,
                        child: CheckboxListTile(
                          controlAffinity: ListTileControlAffinity.leading,
                          value: _selected.contains(c.personAttendanceId),
                          onChanged: (_) => setState(() {
                            if (!_selected.remove(c.personAttendanceId)) {
                              _selected.add(c.personAttendanceId);
                            }
                          }),
                          title: Text(c.name),
                          subtitle: Text(_subtitle(c)),
                        ),
                      ),
                    const Padding(
                      padding: EdgeInsets.all(AppDimensions.paddingM),
                      child: Text(
                        'Sortiert nach Anzahl Dienste. Eingeteilte bekommen sofort eine '
                        'Push-Nachricht und müssen bestätigen.',
                        style: TextStyle(color: AppColors.medium, fontSize: 13),
                      ),
                    ),
                    if (_selected.length > widget.openPlaces)
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: AppDimensions.paddingM),
                        child: Text(
                          'Du hast mehr Personen gewählt als Plätze frei sind. '
                          'Der Dienst ist dann überbesetzt.',
                          style: TextStyle(color: AppColors.warningDark, fontSize: 13),
                        ),
                      ),
                  ],
                ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.paddingM),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _selected.isEmpty ? null : () => Navigator.of(context).pop(_selected.toList()),
                child: Text(_confirmLabel),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
