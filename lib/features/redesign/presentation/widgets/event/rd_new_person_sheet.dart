import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../../core/constants/enums.dart';
import '../../../../../core/providers/attendance_detail_providers.dart';
import '../../../../../core/providers/attendance_providers.dart';
import '../../../../../core/providers/group_providers.dart';
import '../../../../../core/providers/player_providers.dart';
import '../../../../../core/providers/realtime_providers.dart';
import '../../../../../core/theme/redesign/rd_theme.dart';
import '../../../../../core/utils/helper_member.dart';
import '../../../../../core/utils/toast_helper.dart';
import '../../../../../data/models/attendance/attendance.dart';
import '../../../../../data/models/instrument/instrument.dart';
import '../../../../../data/models/person/person.dart';
import '../../../../../data/repositories/player_repository.dart';
import '../../../../../l10n/l10n.dart';
import '../../../../../shared/widgets/adaptive/adaptive.dart';
import '../../../../people/person_write.dart';
import '../../../data/rd_words.dart';
import '../manage/rd_settings_sheets.dart';
import '../rd_widgets.dart';
import 'rd_form_widgets.dart' show rdInputDecoration;

/// REDESIGN: "Neue Person anlegen" from "Person hinzufügen" of a Termin
/// (e.g. a helper who only joins for one concert). One sheet with
/// "Abbrechen · Neue Person · Anlegen", first and last name, the Register
/// and "Aushilfe" with its last day ("dabei bis", the Termin's day at
/// first); everything else is added later on the person's page.
///
/// The person is created like "Neue Person" (Ionic addPerson: duplicate
/// question, joins every Termin since today, an Aushilfe only up to the
/// last day) and then added to this Termin when it is not part of it yet
/// (a Termin of today or the past, or a Termin-Art for other Register)
/// with the type's default status. Writes and the check go through the
/// tenant repositories bound before the first await (id + tenantId).
Future<void> createPersonForAttendance(BuildContext context, WidgetRef ref, {required int attendanceId}) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final players = container.read(playerRepositoryWithTenantProvider);
  final attendances = container.read(attendanceRepositoryWithTenantProvider);
  final List<Group> groups;
  final AttendanceType? type;
  final Group? mainGroup;
  final DateTime? eventDay;
  try {
    groups = (await container.read(groupsProvider.future)).where((g) => g.id != null).toList();
    type = await container.read(attendanceTypeForAttendanceProvider(attendanceId).future);
    mainGroup = await container.read(mainGroupProvider.future).catchError((Object _) => null);
    final attendance = await container.read(attendanceDetailProvider(attendanceId).future);
    eventDay = DateTime.tryParse(attendance?.date ?? '')?.toLocal();
  } catch (_) {
    if (context.mounted) ToastHelper.showError(context, context.l10n.attendanceLoadPeopleFailed);
    return;
  }
  if (!context.mounted) return;

  // Ionic: a new person starts in the first group; here the first Register
  // the Termin-Art is meant for, so the person fits the Termin.
  final relevant = type?.relevantGroups ?? const <int>[];
  final initialGroup = groups.where((g) => relevant.contains(g.id)).firstOrNull?.id ?? groups.firstOrNull?.id;

  // Saved, but not added to (all) other Termine since today.
  var otherTermineMissing = false;
  Future<Person?>? pending;
  final created = await showRdSettingsSheet<Person>(
    context,
    (_) => RdNewPersonSheet(
      groups: groups,
      initialGroup: initialGroup,
      eventDay: eventDay,
      onStarted: (write) => pending = write,
      create: (sheetContext, person) async {
        if (!players.hasTenantId || !identical(container.read(playerRepositoryWithTenantProvider), players)) {
          throw StateError('tenant changed');
        }
        try {
          return await createPersonWithChecks(
            sheetContext,
            ref,
            person,
            isMainGroup: mainGroup?.id != null && mainGroup!.id == person.instrument,
            repo: players,
          );
        } on PersonNotAddedToAttendancesException catch (e) {
          // Saved, only the other Termine are missing: never create twice,
          // refresh the person lists, report it below.
          otherTermineMissing = true;
          container
            ..invalidate(realtimePlayersProvider)
            ..invalidate(playersProvider);
          return e.person;
        }
      },
    ),
  );
  final person = created ?? await pending?.catchError((Object _) => null);
  final personId = person?.id;
  if (person == null || personId == null) return;

  final name = '${person.firstName} ${person.lastName}'.trim();
  try {
    if (!await attendances.hasPersonAttendance(attendanceId, personId)) {
      await attendances.createPersonAttendances([
        PersonAttendance(
          attendanceId: attendanceId,
          personId: personId,
          status: type?.defaultStatus ?? AttendanceStatus.neutral,
          notes: '',
        ),
      ]);
    }
    if (!context.mounted) return;
    if (otherTermineMissing) {
      ToastHelper.showWarning(context, context.l10n.attendanceNewPersonOthersMissing(name));
    } else {
      ToastHelper.showSuccess(context, context.l10n.attendanceNewPersonAdded(name));
    }
  } catch (_) {
    if (context.mounted) ToastHelper.showError(context, context.l10n.attendanceNewPersonAddFailed(name));
  } finally {
    // The Termin page lists its persons from both providers.
    container
      ..invalidate(allPersonsForAttendanceProvider)
      ..invalidate(personAttendancesForAttendanceProvider(attendanceId));
  }
}

/// Content of the "Neue Person" sheet; [create] writes the person (with
/// the sheet's context for the duplicate question) and returns it, null
/// when the user cancelled there.
@visibleForTesting
class RdNewPersonSheet extends StatefulWidget {
  const RdNewPersonSheet({
    super.key,
    required this.groups,
    required this.create,
    this.initialGroup,
    this.eventDay,
    this.onStarted,
  });

  final List<Group> groups;
  final int? initialGroup;

  /// Day of the Termin: first last day of an Aushilfe.
  final DateTime? eventDay;
  final Future<Person?> Function(BuildContext context, Person person) create;

  /// Gets each started write (so the caller can await it when the sheet is
  /// dragged away while saving).
  final void Function(Future<Person?> write)? onStarted;

  @override
  State<RdNewPersonSheet> createState() => _RdNewPersonSheetState();
}

class _RdNewPersonSheetState extends State<RdNewPersonSheet> {
  final _first = TextEditingController();
  final _last = TextEditingController();
  late int? _group = widget.initialGroup;

  /// Aushilfe ("dabei bis") and its last day: never before the Termin's
  /// day (the person is added to this Termin) nor before today.
  bool _helper = false;
  late final DateTime _firstHelperDay = () {
    final today = DateTime.now();
    final day = widget.eventDay;
    final start = DateTime(today.year, today.month, today.day);
    return day == null || day.isBefore(start) ? start : DateTime(day.year, day.month, day.day);
  }();
  late DateTime _helperUntil = _firstHelperDay;

  /// Errors show only after the first "Anlegen".
  bool _tried = false;
  bool _busy = false;
  bool _failed = false;

  bool get _namesOk => _first.text.trim().isNotEmpty && _last.text.trim().isNotEmpty;

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_busy) return;
    if (!_namesOk) {
      setState(() => _tried = true);
      return;
    }
    // Ionic newPlayer: birthday, playsSince and joined = today, the
    // birthday counts as unconfirmed until it is edited.
    final today = personUtcMidnightIso(DateTime.now());
    final person = Person(
      firstName: _first.text.trim(),
      lastName: _last.text.trim(),
      instrument: _group,
      birthday: today,
      playsSince: today,
      joined: today,
      correctBirthday: false,
      additionalFields:
          _helper
              ? {helperUntilKey: helperDay(_helperUntil.isBefore(_firstHelperDay) ? _firstHelperDay : _helperUntil)}
              : null,
    );
    setState(() {
      _busy = true;
      _failed = false;
    });
    Person? created;
    var cancelled = false;
    try {
      final write = widget.create(context, person);
      widget.onStarted?.call(write);
      created = await write;
      cancelled = created == null;
    } catch (_) {
      created = null;
    }
    if (!mounted) return;
    if (created == null) {
      setState(() {
        _busy = false;
        _failed = !cancelled;
      });
      return;
    }
    Navigator.of(context).pop(created);
  }

  Future<void> _pickHelperDay() async {
    final picked = await showAppDatePicker(
      context: context,
      initialDate: _helperUntil,
      firstDate: _firstHelperDay,
      lastDate: DateTime(_firstHelperDay.year + 5),
    );
    if (picked != null && mounted) {
      setState(() => _helperUntil = picked.isBefore(_firstHelperDay) ? _firstHelperDay : picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    Widget note(String text, {bool error = false}) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Text(text, style: RdType.meta(p, size: 13).copyWith(color: error ? p.absent : null)),
    );
    Widget field(Key key, TextEditingController c, String hint, {bool autofocus = false, bool last = false}) =>
        TextField(
          key: key,
          controller: c,
          autofocus: autofocus,
          enabled: !_busy,
          textCapitalization: TextCapitalization.words,
          textInputAction: last ? TextInputAction.done : TextInputAction.next,
          onSubmitted: last ? (_) => _create() : null,
          onChanged: (_) => setState(() {}),
          style: RdType.body(p),
          decoration: rdInputDecoration(p, hint),
        );

    // No back / tap outside while saving.
    return PopScope(
      canPop: !_busy,
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              RdSheetHead(
                title: l10n.attendanceNewPersonTitle,
                doneLabel: l10n.attendanceNewPersonCreate,
                onDone: _busy ? null : _create,
                cancel: !_busy,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: RdCard(
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
                  child: Column(
                    children: [
                      field(
                        const Key('rd-new-person-first'),
                        _first,
                        l10n.attendanceNewPersonFirstName,
                        autofocus: true,
                      ),
                      Divider(height: 1, color: p.line),
                      field(const Key('rd-new-person-last'), _last, l10n.attendanceNewPersonLastName, last: true),
                    ],
                  ),
                ),
              ),
              if (_tried && !_namesOk) note(l10n.attendanceNewPersonNameMissing, error: true),
              if (widget.groups.isNotEmpty) ...[
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: RdGroupLabel(l10n.rdWordsGroup(rdGroupKindOf(context))),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final g in widget.groups)
                        RdChoiceChip(
                          key: Key('rd-new-person-group-${g.id}'),
                          label: g.name,
                          selected: _group == g.id,
                          onTap: _busy ? null : () => setState(() => _group = g.id),
                        ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: RdGroupedList(
                  children: [
                    RdListRow(
                      key: const Key('rd-new-person-helper'),
                      title: l10n.rdHelperTitle,
                      subtitle: l10n.rdHelperSwitchHint,
                      showChevron: false,
                      trailing: Switch.adaptive(
                        value: _helper,
                        activeTrackColor: p.primary,
                        onChanged: _busy ? null : (v) => setState(() => _helper = v),
                      ),
                      onTap: _busy ? null : () => setState(() => _helper = !_helper),
                    ),
                    if (_helper)
                      RdListRow(
                        key: const Key('rd-new-person-helper-until'),
                        title: l10n.rdHelperLastDay,
                        value: DateFormat.yMMMd(currentIntlLocale()).format(_helperUntil),
                        onTap: _busy ? null : _pickHelperDay,
                      ),
                  ],
                ),
              ),
              note(_helper ? l10n.rdHelperFormHint : l10n.attendanceNewPersonHint),
              if (_failed) note(l10n.attendanceNewPersonFailed, error: true),
              if (_busy)
                const Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: Center(
                    child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
