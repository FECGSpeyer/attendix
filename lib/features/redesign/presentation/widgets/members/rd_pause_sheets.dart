import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../../core/providers/tenant_providers.dart';
import '../../../../../core/theme/redesign/rd_theme.dart';
import '../../../../../core/utils/event_list_utils.dart';
import '../../../../../data/repositories/cross_tenant_person_repository.dart' show LinkedTenantRef;
import '../../../../../l10n/l10n.dart';
import '../../../../../shared/widgets/adaptive/adaptive.dart' show showAppDatePicker;
import '../../../../people/presentation/widgets/pause_person_sheet.dart' show PauseInput;
import '../rd_widgets.dart';

/// REDESIGN: "{Name} pausieren" (Leitung) and Ich › "Pausieren" in the
/// Beta: reason as chips (absence reasons of the group) plus a text field,
/// "Ab" (default today, only for the Leitung) and "Bis" (default "Ohne
/// Ende"). Returns the same [PauseInput] as the old sheet, so the pause
/// itself runs through the unchanged flows; null when closed.
Future<PauseInput?> showRdPauseSheet(
  BuildContext context, {
  required String title,
  required String hint,
  bool withFrom = true,
  int untilYears = 3,
}) {
  return showRdSheet<PauseInput>(
    context,
    _RdPauseSheet(title: title, hint: hint, withFrom: withFrom, untilYears: untilYears),
  );
}

class _RdPauseSheet extends ConsumerStatefulWidget {
  const _RdPauseSheet({
    required this.title,
    required this.hint,
    required this.withFrom,
    required this.untilYears,
  });

  final String title;
  final String hint;
  final bool withFrom;

  /// Latest "Bis" in years from today (old sheets: 3 for the Leitung, 5
  /// for the own pause).
  final int untilYears;

  @override
  ConsumerState<_RdPauseSheet> createState() => _RdPauseSheetState();
}

class _RdPauseSheetState extends ConsumerState<_RdPauseSheet> {
  final _reason = TextEditingController();
  DateTime? _from;
  DateTime? _until;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  Future<void> _pickFrom() async {
    final today = _today;
    final date = await showAppDatePicker(
      context: context,
      initialDate: _from ?? today,
      firstDate: DateTime(today.year - 5),
      lastDate: today,
    );
    if (date != null && mounted) setState(() => _from = date);
  }

  Future<void> _pickUntil() async {
    final today = _today;
    final date = await showAppDatePicker(
      context: context,
      initialDate: _until ?? today.add(const Duration(days: 30)),
      firstDate: today,
      lastDate: DateTime(today.year + widget.untilYears),
    );
    if (date != null && mounted) setState(() => _until = date);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final reasons = EventListUtils.absenceReasonsOf(ref.watch(currentTenantProvider)?.absenceReasons);
    final reason = _reason.text.trim();
    final fmt = DateFormat.yMMMd(currentIntlLocale());

    Widget clear(VoidCallback onPressed) => IconButton(
          tooltip: l10n.commonRemove,
          icon: Icon(Icons.cancel_outlined, color: p.text2),
          onPressed: onPressed,
        );

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            RdSheetTitle(widget.title),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  RdGroupLabel(l10n.redesignAbsenceReason),
                  if (reasons.isNotEmpty) ...[
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final r in reasons)
                          RdChoiceChip(
                            label: r,
                            selected: reason == r,
                            onTap: () => setState(() => _reason.text = r),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                  ],
                  TextField(
                    key: const Key('rd-pause-reason'),
                    controller: _reason,
                    textCapitalization: TextCapitalization.sentences,
                    minLines: 1,
                    maxLines: 4,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: l10n.rdPeoplePauseReasonHint,
                      filled: true,
                      fillColor: p.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(p.buttonRadius),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  RdGroupedList(
                    children: [
                      if (widget.withFrom)
                        RdListRow(
                          key: const Key('rd-pause-from'),
                          title: l10n.rdPeoplePauseFrom,
                          value: _from == null ? l10n.rdPeoplePauseToday : fmt.format(_from!),
                          trailing: _from == null ? null : clear(() => setState(() => _from = null)),
                          onTap: _pickFrom,
                        ),
                      RdListRow(
                        key: const Key('rd-pause-until'),
                        title: l10n.rdPeoplePauseUntil,
                        value: _until == null ? l10n.rdPeoplePauseNoEnd : fmt.format(_until!),
                        trailing: _until == null ? null : clear(() => setState(() => _until = null)),
                        onTap: _pickUntil,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  RdHintBox(widget.hint),
                  const SizedBox(height: 18),
                  RdPrimaryButton(
                    key: const Key('rd-pause-submit'),
                    label: l10n.peoplePause,
                    icon: Icons.pause_circle_outline,
                    onPressed: reason.isEmpty
                        ? null
                        : () => Navigator.of(context).pop(
                              PauseInput(reason: reason, from: widget.withFrom ? _from : null, until: _until),
                            ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// REDESIGN: "{Name} archivieren" as a sheet like [showRdPauseSheet] (was
/// a Material dialog): Austrittsdatum (default today), an optional reason,
/// a hint and one red button. Returns what the old dialog returned; null
/// when closed.
Future<({DateTime date, String note})?> showRdArchiveSheet(BuildContext context, {required String name}) {
  return showRdSheet<({DateTime date, String note})>(context, _RdArchiveSheet(name: name));
}

class _RdArchiveSheet extends StatefulWidget {
  const _RdArchiveSheet({required this.name});

  final String name;

  @override
  State<_RdArchiveSheet> createState() => _RdArchiveSheetState();
}

class _RdArchiveSheetState extends State<_RdArchiveSheet> {
  DateTime _date = DateTime.now();
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showAppDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            RdSheetTitle(l10n.rdPeopleArchiveTitle(widget.name)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  RdGroupLabel(l10n.dutyReasonOptional),
                  TextField(
                    key: const Key('rd-archive-reason'),
                    controller: _note,
                    textCapitalization: TextCapitalization.sentences,
                    minLines: 1,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: l10n.personFlutterArchiveReasonHint,
                      filled: true,
                      fillColor: p.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(p.buttonRadius),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  RdGroupedList(
                    children: [
                      RdListRow(
                        key: const Key('rd-archive-date'),
                        title: l10n.peopleLeaveDate,
                        value: DateFormat.yMMMd(currentIntlLocale()).format(_date),
                        onTap: _pickDate,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  RdHintBox(l10n.rdTextArchiveHint),
                  const SizedBox(height: 18),
                  RdPrimaryButton(
                    key: const Key('rd-archive-submit'),
                    label: l10n.peopleArchive,
                    icon: Icons.archive_outlined,
                    color: p.absent,
                    foreground: p.onStatus,
                    onPressed: () => Navigator.of(context).pop((date: _date, note: _note.text)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// REDESIGN: follow-up sheet "Auch in anderen Gruppen pausieren?" (old
/// dialog "Auch in anderen Instanzen pausieren?"): one round check per
/// group, "Überspringen" / "Pausieren". Returns the chosen groups, null
/// when skipped or closed.
Future<List<LinkedTenantRef>?> showRdPauseOthersSheet(
  BuildContext context, {
  required String name,
  required List<LinkedTenantRef> tenants,
}) {
  return showRdSheet<List<LinkedTenantRef>>(context, _RdPauseOthersSheet(name: name, tenants: tenants));
}

class _RdPauseOthersSheet extends StatefulWidget {
  const _RdPauseOthersSheet({required this.name, required this.tenants});

  final String name;
  final List<LinkedTenantRef> tenants;

  @override
  State<_RdPauseOthersSheet> createState() => _RdPauseOthersSheetState();
}

class _RdPauseOthersSheetState extends State<_RdPauseOthersSheet> {
  final _selected = <int>{};

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          RdSheetTitle(l10n.rdPeoplePauseOthersTitle),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l10n.rdPeoplePauseOthersHint(widget.name), style: RdType.body(p)),
                const SizedBox(height: 14),
                RdGroupedList(
                  children: [
                    for (final t in widget.tenants)
                      Semantics(
                        checked: _selected.contains(t.id),
                        child: RdListRow(
                          key: Key('rd-pause-other-${t.id}'),
                          title: t.name,
                          showChevron: false,
                          leading: Icon(
                            _selected.contains(t.id) ? Icons.check_circle : Icons.radio_button_unchecked,
                            color: _selected.contains(t.id) ? p.primary : p.text2,
                          ),
                          onTap: () => setState(() {
                            if (!_selected.remove(t.id)) _selected.add(t.id);
                          }),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: RdOutlineButton(
                        key: const Key('rd-pause-others-skip'),
                        label: l10n.peopleSkip,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: RdPrimaryButton(
                        key: const Key('rd-pause-others-submit'),
                        label: l10n.peoplePause,
                        onPressed: _selected.isEmpty
                            ? null
                            : () => Navigator.of(context).pop(
                                  widget.tenants.where((t) => _selected.contains(t.id)).toList(),
                                ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
