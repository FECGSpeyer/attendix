import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/group_providers.dart';
import '../../../../core/providers/player_providers.dart';
import '../../../../core/providers/teacher_providers.dart';
import '../../../../core/router/redesign_routes.dart';
import '../../../../core/services/offline_queue_service.dart';
import '../../../../core/services/tracking/tracking_event.dart';
import '../../../../core/services/tracking/tracking_service.dart';
import '../../../../core/theme/redesign/rd_theme.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/instrument/instrument.dart';
import '../../../../data/repositories/teacher_repository.dart';
import '../../../../l10n/l10n.dart';
import '../widgets/event/rd_form_widgets.dart';
import '../widgets/rd_widgets.dart';
import '../widgets/today/rd_today_common.dart' show RdInfoCard;

/// REDESIGN: "Lehrer bearbeiten" (template of "Gruppe bearbeiten"): the
/// fields of the old teacher page (Name, Instrumente, Privatlehrer, Kontakt,
/// Notizen) and its players, saved right away (text fields when they lose
/// focus or the page closes). Like the old edit page there is no validation
/// (a teacher may have no instrument); only an empty name is not saved.
/// The old page cannot delete teachers (Ionic neither), so neither can this.
class RdTeacherEditPage extends ConsumerStatefulWidget {
  const RdTeacherEditPage({super.key, required this.teacherId});

  final int teacherId;

  @override
  ConsumerState<RdTeacherEditPage> createState() => _RdTeacherEditPageState();
}

class _RdTeacherEditPageState extends ConsumerState<RdTeacherEditPage> {
  final _name = TextEditingController();
  final _number = TextEditingController();
  final _notes = TextEditingController();
  final _nameFocus = FocusNode();
  final _numberFocus = FocusNode();
  final _notesFocus = FocusNode();

  /// Text columns as last written; empty until the teacher is loaded.
  final Map<String, String> _stored = {};

  bool _private = false;
  List<int> _instruments = const [];

  /// The teacher this form writes to, bound once.
  late final int _teacherId = widget.teacherId;

  /// Writes run one after another, so the last change always wins.
  Future<void> _queue = Future.value();

  /// Bound once the teacher is loaded, so text saved when the page closes
  /// still goes to the teacher's tenant.
  TeacherRepository? _repo;
  late final ProviderContainer _container;
  late final OfflineWriteSession _session;

  TextEditingController _controllerOf(String column) => switch (column) {
    'name' => _name,
    'number' => _number,
    _ => _notes,
  };

  @override
  void initState() {
    super.initState();
    _container = ProviderScope.containerOf(context, listen: false);
    _session = ref.read(offlineQueueNotifierProvider.notifier).captureWriteSession();
    for (final (focus, column) in [(_nameFocus, 'name'), (_numberFocus, 'number'), (_notesFocus, 'notes')]) {
      focus.addListener(() {
        if (!focus.hasFocus) _saveText(column);
      });
    }
  }

  @override
  void dispose() {
    // Text typed last is saved when the page closes (no focus change).
    for (final column in const ['name', 'number', 'notes']) {
      _saveText(column);
    }
    for (final c in [_name, _number, _notes]) {
      c.dispose();
    }
    for (final f in [_nameFocus, _numberFocus, _notesFocus]) {
      f.dispose();
    }
    super.dispose();
  }

  void _fill(Teacher teacher) {
    if (_repo != null) return;
    _repo = ref.read(teacherRepositoryWithTenantProvider);
    _stored
      ..['name'] = teacher.name
      ..['number'] = teacher.number
      ..['notes'] = teacher.notes;
    _name.text = teacher.name;
    _number.text = teacher.number;
    _notes.text = teacher.notes;
    _private = teacher.isPrivate;
    _instruments = [...teacher.instruments];
  }

  /// A failing task never blocks the writes after it.
  void _enqueue(Future<void> Function() task) {
    _queue = _queue.then((_) => task()).catchError((Object _) {});
  }

  /// Writes [updates]; reports a failure while the page is open.
  Future<bool> _store(Map<String, dynamic> updates) async {
    final repo = _repo;
    if (repo == null || !repo.hasTenantId || !_session.isCurrent()) return false;
    try {
      await repo.updateTeacher(_teacherId, {...updates});
      _container.read(trackingServiceProvider).track(TrackingEvent.teacherUpdated);
      _container
        ..invalidate(teachersProvider)
        ..invalidate(teacherByIdProvider(_teacherId));
      return true;
    } catch (_) {
      if (mounted) ToastHelper.showError(context, context.l10n.extraFieldsSaveFailed);
      return false;
    }
  }

  /// Writes [updates]; on failure [revert] puts the shown value back.
  void _write(Map<String, dynamic> updates, {VoidCallback? revert}) => _enqueue(() async {
    if (!await _store(updates) && revert != null && mounted) setState(revert);
  });

  /// Saves a text column when it differs from what is stored when it runs
  /// (the last typed value wins). Trimmed like the old page; an empty name
  /// is not saved. A failed save shows the value last stored again, unless
  /// the field was edited meanwhile.
  void _saveText(String column) {
    final value = _controllerOf(column).text.trim(); // read now: the page may be gone when it runs
    _enqueue(() async {
      if (!_stored.containsKey(column)) return;
      if (value == _stored[column]) return;
      if (column == 'name' && value.isEmpty) return;
      if (await _store({column: value})) {
        _stored[column] = value;
      } else if (mounted) {
        final controller = _controllerOf(column);
        if (controller.text.trim() == value) setState(() => controller.text = _stored[column]!);
      }
    });
  }

  void _done() {
    FocusScope.of(context).unfocus();
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(RedesignRoutes.teachers);
    }
  }

  void _toggleInstrument(int id) {
    final before = _instruments;
    final next = before.contains(id) ? [...before.where((i) => i != id)] : [...before, id];
    setState(() => _instruments = next);
    _write({'instruments': next}, revert: () {
      if (identical(_instruments, next)) _instruments = before;
    });
  }

  void _setPrivate(bool value) {
    final before = _private;
    setState(() => _private = value);
    _write({'private': value}, revert: () {
      if (_private == value) _private = before;
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final async = ref.watch(teachersProvider);
    final teacher = async.valueOrNull?.where((t) => t.id == _teacherId).firstOrNull;

    final Widget body;
    if (teacher == null) {
      body = RdFormBody(
        children: [
          async.isLoading
              ? RdInfoCard(text: l10n.redesignTodayLoading, loading: true)
              : RdInfoCard(
                text: async.hasError ? l10n.redesignTodayLoadFailed : l10n.redesignTeacherEditNotFound,
                icon: Icons.error_outline,
                action: RdOutlineButton(
                  label: l10n.redesignCommonRetry,
                  onPressed: () => ref.invalidate(teachersProvider),
                ),
              ),
        ],
      );
    } else {
      _fill(teacher);
      body = _form(context);
    }

    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
              child: Row(
                children: [
                  const SizedBox(width: 88),
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        l10n.redesignTeacherEditTitle,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: p.text),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 88,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: RdTextLink(
                        key: const Key('rd-teacher-edit-done'),
                        label: l10n.redesignCommonDone,
                        onTap: _done,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }

  Widget _form(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final groups = ref.watch(groupsProvider).valueOrNull ?? const <Group>[];
    // Old page: the persons of this teacher from the loaded persons.
    final players = (ref.watch(playersProvider).valueOrNull ?? const [])
        .where((pl) => pl.teacher == _teacherId)
        .map((pl) => '${pl.firstName} ${pl.lastName}')
        .toList();
    final textStyle = TextStyle(fontSize: 17, color: p.text);

    Widget hint(String text, {Color? color}) => Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
      child: Text(text, style: RdType.meta(p, size: 13).copyWith(color: color)),
    );

    Widget textField(String key, TextEditingController c, FocusNode f, {int maxLines = 1, bool words = false}) =>
        TextField(
          key: Key('rd-teacher-edit-$key'),
          controller: c,
          focusNode: f,
          minLines: 1,
          maxLines: maxLines,
          textCapitalization: words ? TextCapitalization.words : TextCapitalization.sentences,
          textInputAction: maxLines == 1 ? TextInputAction.done : TextInputAction.newline,
          style: textStyle,
          decoration: rdInputDecoration(p, ''),
          onChanged: key == 'name' ? (_) => setState(() {}) : null,
        );

    return RdFormBody(
      children: [
        RdGroupedList(
          children: [
            RdFieldRow(
              label: l10n.redesignTeacherEditName,
              child: textField('name', _name, _nameFocus, words: true),
            ),
          ],
        ),
        if (_name.text.trim().isEmpty) hint(l10n.redesignTeacherEditNameEmpty, color: p.absent),
        const SizedBox(height: 20),
        RdGroupLabel(l10n.redesignTeacherEditInstruments),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final g in groups)
              if (g.id != null)
                RdChoiceChip(
                  key: Key('rd-teacher-edit-instrument-${g.id}'),
                  label: g.name,
                  selected: _instruments.contains(g.id),
                  onTap: () => _toggleInstrument(g.id!),
                ),
          ],
        ),
        hint(l10n.redesignTeacherEditInstrumentsHint),
        const SizedBox(height: 20),
        RdGroupedList(
          children: [
            RdListRow(
              key: const Key('rd-teacher-edit-private'),
              title: l10n.redesignTeacherEditPrivate,
              showChevron: false,
              onTap: () => _setPrivate(!_private),
              trailing: Switch.adaptive(value: _private, activeTrackColor: p.primary, onChanged: _setPrivate),
            ),
            RdFieldRow(label: l10n.redesignTeacherEditContact, child: textField('number', _number, _numberFocus)),
            RdFieldRow(
              label: l10n.redesignTeacherEditNotes,
              child: textField('notes', _notes, _notesFocus, maxLines: 5),
            ),
          ],
        ),
        const SizedBox(height: 20),
        RdGroupLabel(l10n.redesignTeacherEditPlayers),
        if (players.isEmpty)
          hint(l10n.redesignTeacherEditPlayersNone)
        else
          RdGroupedList(
            children: [
              for (final name in players) RdListRow(title: name, showChevron: false),
            ],
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 16, 4, 20),
          child: Text(l10n.redesignGroupEditHint, style: RdType.meta(p, size: 13)),
        ),
        RdPrimaryButton(label: l10n.redesignCommonDone, onPressed: _done),
        const SizedBox(height: 28),
      ],
    );
  }
}
