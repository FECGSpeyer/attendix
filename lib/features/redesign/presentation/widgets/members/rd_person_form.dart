import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../../core/utils/person_matcher.dart' show RankedMatch;
import '../../../../../data/repositories/cross_tenant_person_repository.dart' show CrossTenantPersonCandidate;
import '../../../../../core/providers/church_providers.dart';
import '../../../../../core/providers/debug_providers.dart' show effectiveRoleProvider;
import '../../../../../core/providers/group_providers.dart';
import '../../../../../core/providers/parent_providers.dart';
import '../../../../../core/providers/shift_providers.dart';
import '../../../../../core/providers/teacher_providers.dart';
import '../../../../../core/providers/tenant_providers.dart';
import '../../../../../core/theme/redesign/rd_theme.dart';
import '../../../../../core/utils/extra_field_utils.dart' show parseExtraFieldNumber;
import '../../../../../core/utils/helper_member.dart';
import '../../../../../data/models/parent/parent_model.dart';
import '../../../../../data/models/person/person.dart';
import '../../../../../data/models/shift/shift_plan.dart';
import '../../../../../data/models/teacher/teacher.dart';
import '../../../../../data/models/tenant/tenant.dart';
import '../../../../../l10n/l10n.dart';
import '../../../../../shared/widgets/adaptive/adaptive.dart';
import '../../../../people/person_write.dart' show personUtcMidnightIso;
import '../../../../people/presentation/widgets/church_picker_sheet.dart';
import '../manage/rd_teacher_create_sheet.dart' show showRdAddTeacherSheet;
import '../../../../people/presentation/widgets/person_detail/allgemein_accordion.dart'
    show otherOrchestraOptions, personExtraFields;
import '../event/rd_form_widgets.dart';
import '../rd_widgets.dart';

/// REDESIGN: form parts shared by "Neue Person" and "Person bearbeiten"
/// (canvas "Einheitliche Beta-UX", board A). Changes are reported as
/// `player` columns, so the create page collects them and the edit page
/// writes them right away.

/// Reports changed `player` columns. [typing] is true while a text is
/// typed (the edit page saves those a moment later).
typedef RdPersonColumnsChanged = void Function(Map<String, dynamic> columns, {bool typing});

/// Reports a changed Zusatzfeld value.
typedef RdPersonExtraChanged = void Function(String fieldId, dynamic value, {bool typing});

/// [person] with the changed [columns] (keys as in the `player` table).
Person applyPersonColumns(Person person, Map<String, dynamic> columns) {
  var p = person;
  for (final e in columns.entries) {
    final v = e.value;
    p = switch (e.key) {
      'firstName' => p.copyWith(firstName: v as String? ?? ''),
      'lastName' => p.copyWith(lastName: v as String? ?? ''),
      'email' => p.copyWith(email: v as String?),
      'phone' => p.copyWith(phone: v as String?),
      'notes' => p.copyWith(notes: v as String?),
      'instrument' => p.copyWith(instrument: v as int?),
      'birthday' => p.copyWith(birthday: v as String?),
      'correctBirthday' => p.copyWith(correctBirthday: v as bool),
      'playsSince' => p.copyWith(playsSince: v as String?),
      'joined' => p.copyWith(joined: v as String?),
      'parent_id' => p.copyWith(parentId: v as int?),
      'hasTeacher' => p.copyWith(hasTeacher: v as bool),
      'teacher' => p.copyWith(teacher: v as int?),
      'isLeader' => p.copyWith(isLeader: v as bool),
      'range' => p.copyWith(range: v as String?),
      'instruments' => p.copyWith(instruments: v as String?),
      'otherOrchestras' => p.copyWith(otherOrchestras: (v as List?)?.cast<String>()),
      'examinee' => p.copyWith(examinee: v as bool),
      'testResult' => p.copyWith(testResult: v as String?),
      'shift_id' => p.copyWith(shiftId: v as String?),
      'shift_name' => p.copyWith(shiftName: v as String?),
      'shift_start' => p.copyWith(shiftStart: v as String?),
      'otherExercise' => p.copyWith(otherExercise: v as String?),
      'img' => p.copyWith(img: v as String?),
      _ => p,
    };
  }
  return p;
}

String? _textOrNull(String s) => s.trim().isEmpty ? null : s.trim();

/// Passbild (or initials) of the name card; tapping picks, replaces or
/// removes it.
class RdPersonAvatar extends StatelessWidget {
  const RdPersonAvatar({super.key, required this.name, required this.onTap, this.imageBytes, this.imageUrl});

  final String name;
  final VoidCallback? onTap;
  final Uint8List? imageBytes;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    const size = 72.0;
    final initials = RdInitials(rdInitialsOf(name.trim().isEmpty ? '?' : name), size: size);
    final url = imageUrl;
    final Widget image = imageBytes != null
        ? Image.memory(imageBytes!, width: size, height: size, fit: BoxFit.cover, errorBuilder: (_, __, ___) => initials)
        : url != null && url.isNotEmpty && !url.contains('.svg')
            ? Image.network(url, width: size, height: size, fit: BoxFit.cover, errorBuilder: (_, __, ___) => initials)
            : initials;
    return Semantics(
      button: onTap != null,
      label: context.l10n.peoplePassportPhoto,
      child: GestureDetector(
        key: const Key('rd-person-avatar'),
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              ClipOval(child: image),
              if (onTap != null)
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: p.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: p.surface, width: 2),
                    ),
                    child: Icon(Icons.camera_alt, size: 13, color: p.onPrimary),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Persons of other instances matching the typed name (Ionic
/// person.page name suggestions): tapping one takes over its data.
class RdPersonMatchList extends StatelessWidget {
  const RdPersonMatchList({super.key, required this.matches, required this.onSelected, required this.onDismiss});

  final List<RankedMatch<CrossTenantPersonCandidate>> matches;
  final ValueChanged<CrossTenantPersonCandidate> onSelected;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: RdGroupLabel(l10n.redesignPersonFormMatchFound)),
            RdTextLink(label: l10n.redesignPersonFormMatchDismiss, onTap: onDismiss),
          ],
        ),
        RdGroupedList(
          children: [
            for (final m in matches)
              RdListRow(
                title: m.candidate.label,
                subtitle: [
                  m.reason,
                  if (m.candidate.person.appId != null) l10n.personAccountBadge,
                ].where((s) => s.isNotEmpty).join(' · '),
                leading: Icon(Icons.person_search, color: context.rd.softText),
                onTap: () => onSelected(m.candidate),
              ),
          ],
        ),
      ],
    );
  }
}

/// Group chips like in the Werk and Termin forms (Ionic: no "none").
class RdPersonGroupChips extends ConsumerWidget {
  const RdPersonGroupChips({super.key, required this.selected, required this.onSelected, this.onManage});

  final int? selected;
  final ValueChanged<int>? onSelected;

  /// Leads: "Register verwalten" below the chips (Verwaltung › Register).
  final VoidCallback? onManage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(groupsProvider);
    final list = groups.valueOrNull;
    if (list == null) {
      return groups.hasError
          ? Text(context.l10n.redesignTodayLoadFailed, style: RdType.meta(context.rd, size: 13))
          : const LinearProgressIndicator();
    }
    final chips = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final g in list)
          if (g.id != null)
            RdChoiceChip(
              key: Key('rd-person-group-${g.id}'),
              label: g.name,
              selected: g.id == selected,
              onTap: onSelected == null ? null : () => onSelected!(g.id!),
            ),
      ],
    );
    if (onManage == null) return chips;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        chips,
        const SizedBox(height: 4),
        RdTextLink(label: context.l10n.rdAdminManageGroups, onTap: onManage!),
      ],
    );
  }
}

/// "Weitere Angaben": every rarely used field of the person page, with the
/// visibility rules of the normal app (group type, main group, settings).
class RdPersonMoreFields extends ConsumerStatefulWidget {
  const RdPersonMoreFields({
    super.key,
    required this.person,
    required this.isMainGroup,
    required this.additionalValues,
    required this.onColumns,
    required this.onExtra,
    this.birthdayHighlight = false,
  });

  /// Current values (draft or stored).
  final Person person;
  final bool isMainGroup;
  final Map<String, dynamic> additionalValues;
  final RdPersonColumnsChanged onColumns;
  final RdPersonExtraChanged onExtra;

  /// Birthday not confirmed yet (Ionic warning colour).
  final bool birthdayHighlight;

  @override
  ConsumerState<RdPersonMoreFields> createState() => _RdPersonMoreFieldsState();
}

class _RdPersonMoreFieldsState extends ConsumerState<RdPersonMoreFields> {
  final Map<String, TextEditingController> _texts = {};

  TextEditingController _text(String key, String? initial) =>
      _texts.putIfAbsent(key, () => TextEditingController(text: initial ?? ''));

  @override
  void dispose() {
    for (final c in _texts.values) {
      c.dispose();
    }
    super.dispose();
  }

  Person get _p => widget.person;

  Future<void> _pickDate(String column, String? current, {bool birthday = false, DateTime? lastDate}) async {
    final initial = DateTime.tryParse(current ?? '')?.toLocal() ?? DateTime.now();
    final picked = await showAppDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: lastDate ?? DateTime.now(),
    );
    if (picked == null || !mounted) return;
    widget.onColumns({
      column: personUtcMidnightIso(picked),
      if (birthday) 'correctBirthday': true,
    });
  }

  /// Aushilfe on (last day = today) or off.
  void _toggleHelper(bool on) => widget.onExtra(helperUntilKey, on ? helperDay(DateTime.now()) : null);

  Future<void> _pickHelperDay() async {
    final current = DateTime.tryParse(helperUntilOf(widget.additionalValues) ?? '') ?? DateTime.now();
    final today = DateTime.now();
    final picked = await showAppDatePicker(
      context: context,
      initialDate: current.isBefore(today) ? today : current,
      firstDate: DateTime(today.year, today.month, today.day),
      lastDate: DateTime(today.year + 5),
    );
    if (picked == null || !mounted) return;
    widget.onExtra(helperUntilKey, helperDay(picked));
  }

  Future<T?> _choose<T>(String title, List<(T, String)> options) => showAppActionSheet<T>(
        context,
        title: title,
        actions: [for (final o in options) AppActionSheetAction<T>(value: o.$1, label: o.$2)],
      );

  /// Teacher picker. Leads who may add teachers (old teacher page: Admin
  /// or Verantwortliche) get a last row "Neuer Lehrer": the add sheet of
  /// Verwaltung › Lehrer with the person's register ticked, and the new
  /// teacher is chosen right away. An empty list says why it is empty.
  Future<void> _pickTeacher(List<Teacher> teachers) async {
    final l10n = context.l10n;
    final role = ref.read(effectiveRoleProvider);
    final canAdd = role.isAdmin || role.isResponsible;
    const addNew = -1;
    final options = [
      for (final t in teachers)
        if (t.id != null) (t.id!, t.name),
    ];
    final v = await showAppActionSheet<int>(
      context,
      title: l10n.peopleTeacher,
      message: options.isEmpty ? l10n.rdPeopleTeacherNone : null,
      actions: [
        for (final o in options) AppActionSheetAction<int>(value: o.$1, label: o.$2),
        if (canAdd)
          AppActionSheetAction<int>(
            value: addNew,
            label: l10n.rdPeopleTeacherAdd,
            icon: Icons.add,
            color: context.rd.primary,
          ),
      ],
    );
    if (v == null || !mounted) return;
    if (v != addNew) {
      widget.onColumns({'teacher': v});
      return;
    }
    final instrument = _p.instrument;
    final created = await showRdAddTeacherSheet(
      context,
      ref,
      initialInstruments: [if (instrument != null) instrument],
    );
    if (created?.id != null && mounted) widget.onColumns({'teacher': created!.id});
  }

  String _date(String? iso) {
    final d = DateTime.tryParse(iso ?? '');
    return d == null ? context.l10n.redesignPersonFormNotSet : DateFormat.yMMMd(currentIntlLocale()).format(d);
  }

  Widget _switchRow(String title, bool value, ValueChanged<bool> onChanged, {Key? key}) => RdListRow(
        key: key,
        title: title,
        showChevron: false,
        trailing: Switch.adaptive(value: value, activeTrackColor: context.rd.primary, onChanged: onChanged),
        onTap: () => onChanged(!value),
      );

  Widget _textRow(String label, String column, String? value, {TextInputType? keyboard, int maxLines = 1}) {
    final p = context.rd;
    return RdFieldRow(
      label: label,
      child: TextField(
        key: Key('rd-person-field-$column'),
        controller: _text(column, value),
        keyboardType: keyboard,
        minLines: 1,
        maxLines: maxLines,
        textCapitalization: TextCapitalization.sentences,
        style: TextStyle(fontSize: 17, color: p.text),
        decoration: rdInputDecoration(p, ''),
        onChanged: (v) => widget.onColumns({column: _textOrNull(v)}, typing: true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.rd;
    final tenant = ref.watch(currentTenantProvider);
    final isGeneral = tenant?.type == 'general';
    final isChoir = tenant?.type == 'choir';
    final isVoS = tenant?.shortName == 'VoS';
    final isMain = widget.isMainGroup;
    final notSet = l10n.redesignPersonFormNotSet;

    // Dates
    final dates = <Widget>[
      RdListRow(
        key: const Key('rd-person-birthday'),
        title: l10n.peopleBirthday,
        titleColor: widget.birthdayHighlight ? p.late : null,
        value: _date(_p.birthday),
        onTap: () => _pickDate('birthday', _p.birthday, birthday: true),
      ),
      if (!isGeneral && !isChoir && !isMain)
        RdListRow(
          title: l10n.personPlaysSince,
          value: _date(_p.playsSince),
          onTap: () => _pickDate('playsSince', _p.playsSince),
        ),
      RdListRow(
        title: l10n.personJoinedOn,
        value: _date(_p.joined),
        onTap: () => _pickDate('joined', _p.joined),
      ),
    ];

    // Aushilfe ("dabei bis"): stored in additional_fields.
    final helperDayValue = helperUntilOf(widget.additionalValues);
    final helper = <Widget>[
      RdListRow(
        key: const Key('rd-person-helper'),
        title: l10n.rdHelperTitle,
        subtitle: l10n.rdHelperSwitchHint,
        showChevron: false,
        trailing: Switch.adaptive(
          value: helperDayValue != null,
          activeTrackColor: p.primary,
          onChanged: _toggleHelper,
        ),
        onTap: () => _toggleHelper(helperDayValue == null),
      ),
      if (helperDayValue != null)
        RdListRow(
          key: const Key('rd-person-helper-until'),
          title: l10n.rdHelperLastDay,
          value: _date(helperDayValue),
          onTap: _pickHelperDay,
        ),
    ];

    // Rolle in der Gruppe
    final teachers = (ref.watch(teachersProvider).valueOrNull ?? const [])
        .where((t) => _p.instrument == null || t.instruments.contains(_p.instrument))
        .toList();
    final allTeachers = ref.watch(teachersProvider).valueOrNull ?? const [];
    // Typed on purpose: an untyped `const []` made the list dynamic, so the
    // `fullName` extension getter failed at runtime and the tap did nothing.
    final List<ParentModel> parents =
        (tenant?.parents ?? false) ? ref.watch(parentsProvider).valueOrNull ?? const [] : const [];
    final membership = <Widget>[
      if ((tenant?.parents ?? false) && !isMain)
        RdListRow(
          title: l10n.personParents,
          value: parents.where((x) => x.id == _p.parentId).firstOrNull?.fullName ?? l10n.personNotSet,
          onTap: () async {
            final v = await _choose<int>(l10n.personParents, [
              (-1, l10n.personNotSet),
              for (final x in parents)
                if (x.id != null) (x.id!, x.fullName),
            ]);
            if (v != null) widget.onColumns({'parent_id': v == -1 ? null : v});
          },
        ),
      if ((tenant?.maintainTeachers ?? false) && !isMain) ...[
        // Ionic: switching off keeps the teacher (teacher pages count
        // students via player.teacher).
        _switchRow(l10n.personPlaysWithTeacher, _p.hasTeacher, (v) => widget.onColumns({'hasTeacher': v})),
        if (_p.hasTeacher)
          RdListRow(
            title: l10n.peopleTeacher,
            value: allTeachers.where((t) => t.id == _p.teacher).firstOrNull?.name ?? l10n.peopleNoTeacher,
            onTap: () => _pickTeacher(teachers),
          ),
      ],
      if (!isGeneral && !isMain)
        _switchRow(
          l10n.peopleVoiceLeader,
          _p.isLeader,
          (v) => widget.onColumns({'isLeader': v}),
          key: const Key('rd-person-leader'),
        ),
      if (isChoir) _textRow(l10n.personVocalRange, 'range', _p.range),
      if (isChoir && !isMain) _textRow(l10n.peopleInstruments, 'instruments', _p.instruments),
      _textRow(l10n.peopleOtherDuties, 'otherExercise', _p.otherExercise),
    ];

    // VoS
    final orchestras = _p.otherOrchestras ?? const <String>[];
    final vos = <Widget>[
      _switchRow(l10n.peopleCandidate, _p.examinee, (v) => widget.onColumns({'examinee': v})),
      _textRow(l10n.peopleTestResult, 'testResult', _p.testResult),
    ];

    // Schichten
    final shifts = ref.watch(shiftsProvider).valueOrNull ?? const [];
    final shift = shifts.where((s) => s.id == _p.shiftId).firstOrNull;
    final shiftRows = <Widget>[
      RdListRow(
        title: l10n.personShiftPlan,
        value: shift?.name ?? l10n.personNoShift,
        onTap: () async {
          final v = await _choose<String>(l10n.personShiftPlan, [
            ('', l10n.personNoShift),
            for (final s in shifts)
              if (s.id != null) (s.id!, s.name),
          ]);
          if (v == null) return;
          final plan = shifts.where((s) => s.id == v).firstOrNull;
          // Ionic onShiftChange: named shifts start with the first one,
          // otherwise the start date is today.
          widget.onColumns({
            'shift_id': plan?.id,
            'shift_name': plan != null && plan.hasNamedShifts ? plan.shifts.first.name : null,
            'shift_start': plan != null && !plan.hasNamedShifts ? DateTime.now().toUtc().toIso8601String() : null,
          });
        },
      ),
      if (shift != null && shift.hasNamedShifts)
        RdListRow(
          title: l10n.personShift,
          value: _p.shiftName ?? notSet,
          onTap: () async {
            final v = await _choose<String>(l10n.personShift, [
              for (final name in shift.shifts.map((x) => x.name).toSet()) (name, name),
            ]);
            if (v != null) widget.onColumns({'shift_name': v});
          },
        ),
      if (shift != null && !shift.hasNamedShifts)
        RdListRow(
          title: l10n.personStartDate,
          value: _date(_p.shiftStart),
          onTap: () => _pickDate('shift_start', _p.shiftStart, lastDate: DateTime(2100)),
        ),
    ];

    final extraFields = personExtraFields(ref, tenant);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RdGroupedList(children: dates),
        const SizedBox(height: 12),
        RdGroupedList(children: helper),
        if (helperDayValue != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
            child: Text(l10n.rdHelperFormHint, style: RdType.meta(p, size: 13)),
          ),
        const SizedBox(height: 12),
        RdGroupedList(children: membership),
        if (isVoS && !isMain) ...[
          const SizedBox(height: 20),
          RdGroupLabel(l10n.personOtherOrchestras),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final o in otherOrchestraOptions)
                RdChoiceChip(
                  label: o,
                  selected: orchestras.contains(o),
                  onTap: () {
                    final next = orchestras.contains(o)
                        ? orchestras.where((x) => x != o).toList()
                        : otherOrchestraOptions.where((x) => x == o || orchestras.contains(x)).toList();
                    widget.onColumns({'otherOrchestras': next.isEmpty ? null : next});
                  },
                ),
            ],
          ),
          const SizedBox(height: 12),
          RdGroupedList(children: vos),
        ],
        if (shifts.isNotEmpty) ...[
          const SizedBox(height: 12),
          RdGroupedList(children: shiftRows),
        ],
        if (extraFields.isNotEmpty) ...[
          const SizedBox(height: 20),
          RdGroupLabel(l10n.peopleExtraFields),
          RdGroupedList(children: [for (final f in extraFields) _extraRow(f)]),
        ],
      ],
    );
  }

  Widget _extraRow(ExtraField field) {
    final l10n = context.l10n;
    final value = widget.additionalValues[field.id];
    switch (field.type) {
      case 'boolean':
        return _switchRow(field.name, value == true, (v) => widget.onExtra(field.id, v));
      case 'date':
        return RdListRow(
          title: field.name,
          value: _date(value?.toString()),
          onTap: () async {
            final picked = await showAppDatePicker(
              context: context,
              initialDate: DateTime.tryParse(value?.toString() ?? '') ?? DateTime.now(),
              firstDate: DateTime(1900),
              lastDate: DateTime.now(),
            );
            if (picked != null) widget.onExtra(field.id, personUtcMidnightIso(picked));
          },
        );
      case 'select':
        final options = field.options ?? const <String>[];
        return RdListRow(
          title: field.name,
          value: value?.toString().isNotEmpty == true ? value.toString() : l10n.redesignPersonFormNotSet,
          onTap: options.isEmpty
              ? null
              : () async {
                  final v = await _choose<String>(field.name, [for (final o in options) (o, o)]);
                  if (v != null) widget.onExtra(field.id, v);
                },
        );
      case 'bfecg_church':
        final churches = ref.watch(churchesProvider).valueOrNull ?? const [];
        return RdListRow(
          title: field.name,
          value: churchLabel(value, churches),
          onTap: () async {
            final selected = await showChurchPickerSheet(
              context,
              title: field.name,
              churches: churches,
              selectedId: value?.toString(),
            );
            if (selected != null) widget.onExtra(field.id, selected);
          },
        );
      case 'number':
        return RdFieldRow(
          label: field.name,
          child: TextField(
            key: Key('rd-person-extra-${field.id}'),
            controller: _text('extra.${field.id}', value?.toString()),
            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
            style: TextStyle(fontSize: 17, color: context.rd.text),
            decoration: rdInputDecoration(context.rd, ''),
            onChanged: (v) => widget.onExtra(field.id, parseExtraFieldNumber(v), typing: true),
          ),
        );
      case 'text':
      case 'textarea':
        return RdFieldRow(
          label: field.name,
          child: TextField(
            key: Key('rd-person-extra-${field.id}'),
            controller: _text('extra.${field.id}', value?.toString()),
            minLines: 1,
            maxLines: field.type == 'textarea' ? 6 : 1,
            textCapitalization: TextCapitalization.sentences,
            style: TextStyle(fontSize: 17, color: context.rd.text),
            decoration: rdInputDecoration(context.rd, ''),
            onChanged: (v) => widget.onExtra(field.id, v, typing: true),
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }
}
