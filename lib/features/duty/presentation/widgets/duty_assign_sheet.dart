import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../planning/presentation/widgets/ion_items.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart'; // PARITY_R5

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
    useRootNavigator: true, // IOS_SHELL2: above the tab bar
    isScrollControlled: true,
    useSafeArea: true,
    // Ionic: ion-content color="light".
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
    final places = context.l10n.dutyPlacesFree(widget.openPlaces);
    return Column(
      children: [
        // Ionic toolbar: close at the start, centered title with `.sub` line.
        AppBar(
          toolbarHeight: ionModalToolbarHeight(context), // PARITY_R5
          automaticallyImplyLeading: false,
          primary: false,
          leading: IconButton(
            icon: const Icon(Icons.close),
            tooltip: context.l10n.commonCancel,
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(context.l10n.attendanceAssignPerson),
              Text('${widget.title} · $places',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: AppColors.medium)),
            ],
          ),
        ),
        Expanded(
          child: _sorted.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    context.l10n.dutyAllAssigned,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.medium),
                  ),
                )
              : ListView(
                  controller: widget.scrollController,
                  padding: const EdgeInsets.only(bottom: 16),
                  children: [
                    IonInsetList(
                      dividerIndent: 56,
                      children: [
                        for (final c in _sorted)
                          Opacity(
                            // Ionic `.dim`
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
                              subtitle: Text(_subtitle(c), style: const TextStyle(color: AppColors.medium)),
                            ),
                          ),
                      ],
                    ),
                    // Ionic `.hint`
                    Padding(
                      padding: const EdgeInsets.fromLTRB(32, 16, 32, 0),
                      child: Text(
                        context.l10n.dutyAssignHint,
                        style: const TextStyle(color: AppColors.medium, fontSize: 13, height: 1.35),
                      ),
                    ),
                    if (_selected.length > widget.openPlaces)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(32, 12, 32, 0),
                        child: Text(
                          context.l10n.dutyOverbooked,
                          style: const TextStyle(color: AppColors.warningDark, fontSize: 13, height: 1.35),
                        ),
                      ),
                  ],
                ),
        ),
        // Ionic footer: round block button on the light background.
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(shape: const StadiumBorder()),
                onPressed: _selected.isEmpty ? null : () => Navigator.of(context).pop(_selected.toList()),
                child: IonButtonLabel(_confirmLabel),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
