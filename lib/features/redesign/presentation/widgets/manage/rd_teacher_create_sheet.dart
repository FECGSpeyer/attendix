import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/providers/teacher_providers.dart';
import '../../../../../core/services/tracking/tracking_event.dart';
import '../../../../../core/services/tracking/tracking_service.dart';
import '../../../../../core/theme/redesign/rd_theme.dart';
import '../../../../../data/models/instrument/instrument.dart';
import '../../../../../data/repositories/teacher_repository.dart';
import '../../../../../l10n/l10n.dart';
import '../../../../teachers/presentation/pages/teachers_list_page.dart'
    show isTeacherFormValid, loadTeacherGroups;
import '../event/rd_form_widgets.dart' show rdInputDecoration;
import '../rd_widgets.dart';
import 'rd_settings_sheets.dart';

/// REDESIGN: "Neuer Lehrer" – the one create step of the Beta (Verwaltung ›
/// Lehrer and the teacher picker of "Person bearbeiten"). One sheet with
/// "Abbrechen · Neuer Lehrer · Anlegen", the name and the instruments as
/// chips; contact, notes and "Privatlehrer" are added on the teacher's page
/// later. Validation as the old create sheet (Ionic `addTeacher`): a name of
/// at least 3 characters and at least one instrument.
///
/// Creates the teacher itself and stays open when that fails, so nothing
/// typed is lost. Returns the new teacher, null when cancelled.
/// [initialInstruments] are ticked when the sheet opens (only those that
/// are offered).
///
/// The repository (bound to tenant and account) is taken before the first
/// await: when the group changed while the sheet was open, nothing is
/// created (the instruments belong to the old group).
Future<Teacher?> showRdAddTeacherSheet(
  BuildContext context,
  WidgetRef ref, {
  Iterable<int> initialInstruments = const [],
}) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final repo = container.read(teacherRepositoryWithTenantProvider);
  // Old sheet (Ionic teachers.page): instruments without the main group.
  final groups = (await loadTeacherGroups(ref)).where((g) => g.maingroup != true && g.id != null).toList();
  if (!context.mounted) return null;
  return showRdSettingsSheet<Teacher>(
    context,
    (_) => RdAddTeacherSheet(
      groups: groups,
      initialInstruments: {
        for (final id in initialInstruments)
          if (groups.any((g) => g.id == id)) id,
      },
      create: (teacher) async {
        if (!repo.hasTenantId || !identical(container.read(teacherRepositoryWithTenantProvider), repo)) {
          throw StateError('tenant changed');
        }
        final created = await repo.createTeacher(teacher);
        container.read(trackingServiceProvider).track(TrackingEvent.teacherAdded);
        container
          ..invalidate(teachersProvider)
          ..invalidate(studentCountsProvider)
          ..invalidate(enrichedTeachersProvider);
        return created;
      },
    ),
  );
}

/// Content of [showRdAddTeacherSheet]; [create] writes the teacher.
@visibleForTesting
class RdAddTeacherSheet extends StatefulWidget {
  const RdAddTeacherSheet({
    super.key,
    required this.groups,
    required this.create,
    this.initialInstruments = const {},
  });

  final List<Group> groups;
  final Set<int> initialInstruments;
  final Future<Teacher?> Function(Teacher teacher) create;

  @override
  State<RdAddTeacherSheet> createState() => _RdAddTeacherSheetState();
}

class _RdAddTeacherSheetState extends State<RdAddTeacherSheet> {
  late final _name = TextEditingController();
  late final Set<int> _instruments = {...widget.initialInstruments};

  /// Errors show only after the first "Anlegen".
  bool _tried = false;
  bool _busy = false;
  bool _failed = false;

  bool get _nameOk => _name.text.trim().length >= 3;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_busy) return;
    final name = _name.text.trim();
    if (!isTeacherFormValid(isNew: true, name: name, instruments: _instruments)) {
      setState(() => _tried = true);
      return;
    }
    setState(() {
      _busy = true;
      _failed = false;
    });
    Teacher? created;
    try {
      created = await widget.create(
        Teacher(name: name, number: '', notes: '', isPrivate: false, instruments: _instruments.toList()),
      );
    } catch (_) {
      created = null;
    }
    if (!mounted) return;
    if (created == null) {
      setState(() {
        _busy = false;
        _failed = true;
      });
      return;
    }
    Navigator.of(context).pop(created);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    Widget note(String text, {bool error = false}) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Text(text, style: RdType.meta(p, size: 13).copyWith(color: error ? p.absent : null)),
    );

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            RdSheetHead(
              title: l10n.rdTeacherNewTitle,
              doneLabel: l10n.rdTeacherNewCreate,
              onDone: _busy ? null : _create,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: RdCard(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                child: TextField(
                  key: const Key('rd-teacher-new-name'),
                  controller: _name,
                  autofocus: true,
                  enabled: !_busy,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.done,
                  onChanged: (_) => setState(() {}),
                  style: RdType.body(p),
                  decoration: rdInputDecoration(p, l10n.rdTeacherNewName),
                ),
              ),
            ),
            if (_tried && !_nameOk) note(l10n.rdTeacherNewNameShort, error: true),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: RdGroupLabel(l10n.rdTeacherNewInstruments),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: widget.groups.isEmpty
                  ? Text(l10n.rdTeacherNewNoGroups, style: RdType.meta(p, size: 13))
                  : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final g in widget.groups)
                        RdChoiceChip(
                          key: Key('rd-teacher-new-instrument-${g.id}'),
                          label: g.name,
                          selected: _instruments.contains(g.id),
                          onTap: _busy
                              ? null
                              : () => setState(() {
                                if (!_instruments.remove(g.id)) _instruments.add(g.id!);
                              }),
                        ),
                    ],
                  ),
            ),
            if (_tried && _instruments.isEmpty)
              note(l10n.rdTeacherNewNoInstrument, error: true)
            else
              note(l10n.rdTeacherNewHint),
            if (_failed) note(l10n.redesignTeachersListAddFailed, error: true),
            if (_busy)
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))),
              ),
          ],
        ),
      ),
    );
  }
}
