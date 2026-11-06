import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/redesign/rd_theme.dart';
import '../../../../core/utils/plan_beamer.dart';
import '../../../../l10n/l10n.dart';
import '../../../redesign/presentation/widgets/event/rd_form_widgets.dart' show RdFieldRow, rdInputDecoration;
import '../../../redesign/presentation/widgets/rd_widgets.dart';
import '../../../../data/models/song/song.dart';
import 'plan_export_actions.dart';
import 'plan_field_dialogs.dart';

/// REDESIGN (Termin-Werkzeuge T1): Beta versions of the plan dialogs and
/// action sheets. The classic helpers in plan_field_dialogs.dart switch to
/// these when the Beta skin is active ([RdSkinContext.rdSkin]), so every
/// caller (Ablauf-Editor, Ablauf ansehen, Export) gets the Beta look without
/// changing its logic. The normal app keeps the classic dialogs.

/// Typical durations of a Programmpunkt (same as the inline editor).
const rdPlanDurationPresets = [5, 10, 15, 20, 30, 40, 45, 60];

/// Bottom sheet in the Beta look: title, optional subtitle, content.
/// Follows the keyboard so text fields stay visible.
Future<T?> showRdPlanSheet<T>(
  BuildContext context, {
  required String title,
  String? subtitle,
  Widget? action,
  required List<Widget> Function(BuildContext ctx, void Function(T value) pop) builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: context.rd.bg,
    builder: (ctx) {
      final p = ctx.rd;
      return Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.88),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(child: Semantics(header: true, child: Text(title, style: RdType.cardTitle(p)))),
                      if (action != null) action,
                    ],
                  ),
                  if (subtitle != null && subtitle.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(subtitle, style: RdType.meta(p, size: 15)),
                  ],
                  const SizedBox(height: 16),
                  ...builder(ctx, (value) => Navigator.of(ctx).pop(value)),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

/// Beta replacement of [showPlanActionSheet]: one grouped list, dangerous
/// entries red and last.
Future<T?> showRdPlanActionSheet<T>(
  BuildContext context, {
  String? title,
  String? subtitle,
  required List<PlanSheetAction<T>> actions,
}) {
  final normal = actions.where((a) => !a.destructive).toList();
  final danger = actions.where((a) => a.destructive).toList();
  return showRdPlanSheet<T>(
    context,
    title: title ?? '',
    subtitle: subtitle,
    builder: (ctx, pop) {
      final p = ctx.rd;
      return [
        if (normal.isNotEmpty)
          RdGroupedList(
            children: [
              for (final a in normal)
                RdListRow(
                  leading: a.icon == null ? null : RdRowIcon(a.icon!),
                  title: a.label,
                  showChevron: false,
                  onTap: () => pop(a.value),
                ),
            ],
          ),
        if (danger.isNotEmpty) ...[
          const SizedBox(height: 12),
          RdGroupedList(
            children: [
              for (final a in danger)
                RdListRow(
                  leading: RdRowIcon(a.icon ?? Icons.delete_outline, color: p.absent, background: p.absentSoft),
                  title: a.label,
                  titleColor: p.absent,
                  showChevron: false,
                  onTap: () => pop(a.value),
                ),
            ],
          ),
        ],
      ];
    },
  );
}

/// Beta replacement of [showPlanTextPrompt]: one text field and a button.
Future<String?> showRdPlanTextSheet(
  BuildContext context, {
  required String title,
  String? message,
  String? initialValue,
  String? hint,
  String? confirmText,
  bool allowEmpty = false,
  String? emptyMessage,
}) {
  return showRdPlanSheet<String>(
    context,
    title: title,
    subtitle: message,
    builder: (ctx, pop) => [
      _RdTextPrompt(
        initialValue: initialValue,
        hint: hint,
        confirmText: confirmText ?? ctx.l10n.commonSave,
        allowEmpty: allowEmpty,
        emptyMessage: emptyMessage,
        onDone: pop,
      ),
    ],
  );
}

class _RdTextPrompt extends StatefulWidget {
  const _RdTextPrompt({
    required this.initialValue,
    required this.hint,
    required this.confirmText,
    required this.allowEmpty,
    required this.emptyMessage,
    required this.onDone,
  });

  final String? initialValue;
  final String? hint;
  final String confirmText;
  final bool allowEmpty;
  final String? emptyMessage;
  final void Function(String value) onDone;

  @override
  State<_RdTextPrompt> createState() => _RdTextPromptState();
}

class _RdTextPromptState extends State<_RdTextPrompt> {
  late final TextEditingController _controller = TextEditingController(text: widget.initialValue ?? '');
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final v = _controller.text.trim();
    if (!widget.allowEmpty && v.isEmpty) {
      setState(() => _error = widget.emptyMessage ?? context.l10n.planningEnterNamePlease);
      return;
    }
    widget.onDone(v);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RdGroupedList(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
              child: TextField(
                key: const Key('rd-plan-text-input'),
                controller: _controller,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.done,
                style: TextStyle(fontSize: 17, color: p.text),
                decoration: rdInputDecoration(p, widget.hint ?? ''),
                onSubmitted: (_) => _submit(),
              ),
            ),
          ],
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: TextStyle(color: p.absent, fontSize: 14)),
        ],
        const SizedBox(height: 16),
        RdPrimaryButton(label: widget.confirmText, onPressed: _submit),
      ],
    );
  }
}

/// Labels of the [RdPlanFieldForm] fields.
class RdPlanFieldLabels {
  const RdPlanFieldLabels({this.name, this.nameHint, this.conductor, this.conductorHint, this.infoHint});

  final String? name;
  final String? nameHint;
  final String? conductor;
  final String? conductorHint;
  final String? infoHint;
}

/// Fields of a Programmpunkt, Block, Notiz or Unterpunkt in the Beta look:
/// name, Ausführender, Info, Dauer (chips and −/+) and the Beamer switch.
/// Reports every change through [onChanged]; the caller decides when the
/// values are saved (live in the Punkt-Blatt, with a button when adding).
class RdPlanFieldForm extends StatefulWidget {
  const RdPlanFieldForm({
    super.key,
    this.labels = const RdPlanFieldLabels(),
    this.initialName,
    this.initialConductor,
    this.initialInfo,
    this.initialMinutes,
    this.withConductor = true,
    this.withInfo = true,
    this.withMinutes = true,
    this.autofocus = false,
    this.beamer,
    required this.onChanged,
    this.onSubmitted,
  });

  final RdPlanFieldLabels labels;
  final String? initialName;
  final String? initialConductor;
  final String? initialInfo;
  final int? initialMinutes;
  final bool withConductor;
  final bool withInfo;
  final bool withMinutes;
  final bool autofocus;
  final PlanFieldBeamerOptions? beamer;
  final ValueChanged<PlanFieldInput> onChanged;
  final VoidCallback? onSubmitted;

  @override
  State<RdPlanFieldForm> createState() => _RdPlanFieldFormState();
}

class _RdPlanFieldFormState extends State<RdPlanFieldForm> {
  late final TextEditingController _name = TextEditingController(text: widget.initialName ?? '');
  late final TextEditingController _conductor = TextEditingController(text: widget.initialConductor ?? '');
  late final TextEditingController _info = TextEditingController(text: widget.initialInfo ?? '');
  late final TextEditingController _minutes = TextEditingController(text: widget.initialMinutes?.toString() ?? '');
  late bool? _manualBeamer = widget.beamer?.manual;

  @override
  void dispose() {
    _name.dispose();
    _conductor.dispose();
    _info.dispose();
    _minutes.dispose();
    super.dispose();
  }

  int? get _minutesValue => int.tryParse(_minutes.text.trim());

  bool get _beamerOn =>
      _manualBeamer ?? PlanBeamer.autoNeedsBeamer(name: _name.text, songId: widget.beamer?.songId);

  void _report() {
    final info = _info.text.trim();
    widget.onChanged(
      PlanFieldInput(
        name: _name.text.trim(),
        conductor: _conductor.text.trim(),
        info: info.isEmpty ? null : info,
        minutes: _minutesValue,
        needsBeamer: widget.beamer != null ? _manualBeamer : null,
      ),
    );
  }

  void _setMinutes(int m) {
    setState(() => _minutes.text = '${m.clamp(0, 999)}');
    _report();
  }

  Widget _text(
    TextEditingController c,
    String label,
    String hint, {
    Key? key,
    bool autofocus = false,
    int maxLines = 1,
    TextCapitalization caps = TextCapitalization.sentences,
  }) {
    final p = context.rd;
    return RdFieldRow(
      label: label,
      child: TextField(
        key: key,
        controller: c,
        autofocus: autofocus,
        minLines: 1,
        maxLines: maxLines,
        textCapitalization: caps,
        style: TextStyle(fontSize: 17, color: p.text),
        decoration: rdInputDecoration(p, hint),
        onChanged: (_) {
          if (widget.beamer != null && identical(c, _name)) setState(() {});
          _report();
        },
        onSubmitted: maxLines == 1 && widget.onSubmitted != null ? (_) => widget.onSubmitted!() : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final m = _minutesValue ?? 0;
    Widget step(IconData icon, String label, int to) => Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: p.soft,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => _setMinutes(to),
          child: SizedBox(width: 44, height: 44, child: Icon(icon, color: p.softText)),
        ),
      ),
    );
    final beamer = widget.beamer;
    final reason =
        beamer == null ? null : PlanBeamer.autoReason(name: _name.text, songId: beamer.songId, manual: _manualBeamer);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RdGroupedList(
          children: [
            _text(
              _name,
              widget.labels.name ?? l10n.planningItem,
              widget.labels.nameHint ?? l10n.planningEnterItem,
              key: const Key('rd-plan-field-name'),
              autofocus: widget.autofocus,
              maxLines: 3,
            ),
            if (widget.withConductor)
              _text(
                _conductor,
                widget.labels.conductor ?? l10n.planningPerformer,
                widget.labels.conductorHint ?? l10n.planningEnterPerformer,
                key: const Key('rd-plan-field-conductor'),
                caps: TextCapitalization.words,
              ),
            if (widget.withInfo)
              _text(
                _info,
                l10n.planningInfo,
                widget.labels.infoHint ?? l10n.planningInfoOptional,
                key: const Key('rd-plan-field-info'),
                maxLines: 3,
              ),
          ],
        ),
        if (widget.withMinutes) ...[
          const SizedBox(height: 16),
          RdGroupLabel(l10n.redesignPlanDuration),
          RdCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    step(Icons.remove, l10n.redesignPlanLess, m % 5 == 0 ? m - 5 : m - m % 5),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        key: const Key('rd-plan-field-minutes'),
                        controller: _minutes,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)],
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: p.text),
                        decoration: InputDecoration(
                          isDense: true,
                          filled: true,
                          fillColor: p.bg,
                          suffixText: l10n.redesignPlanMinUnit,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onChanged: (_) {
                          setState(() {});
                          _report();
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    step(Icons.add, l10n.redesignPlanMore5, m + (5 - m % 5)),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final v in rdPlanDurationPresets)
                      RdChoiceChip(label: '$v', selected: v == m, onTap: () => _setMinutes(v)),
                  ],
                ),
              ],
            ),
          ),
        ],
        if (beamer != null) ...[
          const SizedBox(height: 16),
          RdGroupLabel(l10n.planningBeamer),
          RdGroupedList(
            children: [
              RdListRow(
                key: const Key('rd-plan-field-beamer'),
                leading: const RdRowIcon(Icons.tv_outlined),
                title: l10n.planningBeamerNeeded,
                subtitle:
                    reason == null
                        ? null
                        : (reason.song ? l10n.planningBeamerAutoSong : l10n.planningBeamerAutoWord(reason.word ?? '')),
                showChevron: false,
                onTap: () {
                  setState(() => _manualBeamer = !_beamerOn);
                  _report();
                },
                trailing: Switch.adaptive(
                  value: _beamerOn,
                  onChanged: (v) {
                    setState(() => _manualBeamer = v);
                    _report();
                  },
                ),
              ),
              if (_beamerOn)
                RdListRow(
                  leading: RdRowIcon(
                    Icons.insert_drive_file_outlined,
                    color: beamer.file != null ? null : p.late,
                    background: beamer.file != null ? null : p.lateSoft,
                  ),
                  title: beamer.file?.name ?? l10n.planningBeamerNoFile,
                  subtitle: beamer.file != null ? l10n.planningBeamerChangeInApp : l10n.planningBeamerLinkInApp,
                  showChevron: false,
                ),
            ],
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(l10n.planningBeamerAutoHint, style: RdType.meta(p, size: 13)),
          ),
        ],
      ],
    );
  }
}

/// Beta replacement of [showPlanFieldDialog]: the same fields in a sheet,
/// confirmed with one button (used when adding).
Future<PlanFieldInput?> showRdPlanFieldSheet(
  BuildContext context, {
  required String title,
  String? subtitle,
  String? message,
  String? nameLabel,
  String? nameHint,
  String? conductorLabel,
  String? conductorHint,
  String? infoHint,
  String? confirmText,
  String? emptyNameMessage,
  String? initialName,
  String? initialConductor,
  String? initialInfo,
  int? initialMinutes,
  bool withConductor = true,
  bool withInfo = true,
  bool withMinutes = true,
  bool requireName = true,
  VoidCallback? onDelete,
  PlanFieldBeamerOptions? beamer,
}) async {
  final sub = [subtitle, message].whereType<String>().where((s) => s.isNotEmpty).join('\n');
  final result = await showRdPlanSheet<Object>(
    context,
    title: title,
    subtitle: sub.isEmpty ? null : sub,
    builder: (ctx, pop) => [
      _RdFieldSheetBody(
        labels: RdPlanFieldLabels(
          name: nameLabel,
          nameHint: nameHint,
          conductor: conductorLabel,
          conductorHint: conductorHint,
          infoHint: infoHint,
        ),
        confirmText: confirmText ?? ctx.l10n.attendanceAdd,
        emptyNameMessage: emptyNameMessage,
        initialName: initialName,
        initialConductor: initialConductor,
        initialInfo: initialInfo,
        initialMinutes: initialMinutes,
        withConductor: withConductor,
        withInfo: withInfo,
        withMinutes: withMinutes,
        requireName: requireName,
        withDelete: onDelete != null,
        beamer: beamer,
        onDone: pop,
      ),
    ],
  );
  if (result == _deleteChoice) {
    onDelete?.call();
    return null;
  }
  return result is PlanFieldInput ? result : null;
}

const _deleteChoice = 'delete';

class _RdFieldSheetBody extends StatefulWidget {
  const _RdFieldSheetBody({
    required this.labels,
    required this.confirmText,
    required this.emptyNameMessage,
    required this.initialName,
    required this.initialConductor,
    required this.initialInfo,
    required this.initialMinutes,
    required this.withConductor,
    required this.withInfo,
    required this.withMinutes,
    required this.requireName,
    required this.withDelete,
    required this.beamer,
    required this.onDone,
  });

  final RdPlanFieldLabels labels;
  final String confirmText;
  final String? emptyNameMessage;
  final String? initialName;
  final String? initialConductor;
  final String? initialInfo;
  final int? initialMinutes;
  final bool withConductor;
  final bool withInfo;
  final bool withMinutes;
  final bool requireName;
  final bool withDelete;
  final PlanFieldBeamerOptions? beamer;
  final void Function(Object value) onDone;

  @override
  State<_RdFieldSheetBody> createState() => _RdFieldSheetBodyState();
}

class _RdFieldSheetBodyState extends State<_RdFieldSheetBody> {
  late PlanFieldInput _value = PlanFieldInput(
    name: (widget.initialName ?? '').trim(),
    conductor: (widget.initialConductor ?? '').trim(),
    info: widget.initialInfo,
    minutes: widget.initialMinutes,
    needsBeamer: widget.beamer?.manual,
  );
  String? _error;

  void _submit() {
    if (widget.requireName && _value.name.isEmpty) {
      setState(() => _error = widget.emptyNameMessage ?? context.l10n.planningEnterItemPlease);
      return;
    }
    widget.onDone(_value);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RdPlanFieldForm(
          labels: widget.labels,
          initialName: widget.initialName,
          initialConductor: widget.initialConductor,
          initialInfo: widget.initialInfo,
          initialMinutes: widget.initialMinutes,
          withConductor: widget.withConductor,
          withInfo: widget.withInfo,
          withMinutes: widget.withMinutes,
          autofocus: true,
          beamer: widget.beamer,
          onChanged: (v) => _value = v,
          onSubmitted: _submit,
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: TextStyle(color: p.absent, fontSize: 14)),
        ],
        const SizedBox(height: 16),
        RdPrimaryButton(key: const Key('rd-plan-field-confirm'), label: widget.confirmText, onPressed: _submit),
        if (widget.withDelete) ...[
          const SizedBox(height: 12),
          RdGroupedList(
            children: [
              RdListRow(
                leading: RdRowIcon(Icons.delete_outline, color: p.absent, background: p.absentSoft),
                title: l10n.commonDelete,
                titleColor: p.absent,
                showChevron: false,
                onTap: () => widget.onDone(_deleteChoice),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Beta "Werk hinzufügen": sheet with search, current Werke first, then all.
Future<Song?> showRdPlanSongPicker(
  BuildContext context,
  List<Song> songs, {
  Set<int> currentIds = const {},
  Set<int> inPlanIds = const {},
}) {
  return showModalBottomSheet<Song>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: context.rd.bg,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(ctx).height * 0.85,
        child: _RdSongPicker(songs: songs, currentIds: currentIds, inPlanIds: inPlanIds),
      ),
    ),
  );
}

class _RdSongPicker extends StatefulWidget {
  const _RdSongPicker({required this.songs, required this.currentIds, required this.inPlanIds});

  final List<Song> songs;
  final Set<int> currentIds;
  final Set<int> inPlanIds;

  @override
  State<_RdSongPicker> createState() => _RdSongPickerState();
}

class _RdSongPickerState extends State<_RdSongPicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final q = _query.trim().toLowerCase();
    final filtered = widget.songs.where((s) {
      if (q.isEmpty) return true;
      final label = '${s.prefix ?? ''}${s.number ?? ''} ${s.name} ${s.composer ?? ''}'.toLowerCase();
      return label.contains(q);
    }).toList();
    final current = filtered.where((s) => widget.currentIds.contains(s.id)).toList();
    final rest = filtered.where((s) => !widget.currentIds.contains(s.id)).toList();

    Widget row(Song s) {
      final inPlan = widget.inPlanIds.contains(s.id);
      final composer = (s.composer ?? '').trim();
      return RdListRow(
        leading: RdRowIcon(
          Icons.music_note_outlined,
        ),
        title: '${s.prefix ?? ''}${s.number ?? ''} ${s.name}'.trim(),
        subtitle: composer.isEmpty ? null : composer,
        showChevron: false,
        trailing: inPlan
            ? Text(l10n.redesignPlanSongInPlan, style: RdType.meta(p, size: 13))
            : Icon(Icons.add_circle_outline, color: p.link),
        onTap: () => Navigator.of(context).pop(s),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        Semantics(header: true, child: Text(l10n.planningChooseSong, style: RdType.cardTitle(p))),
        const SizedBox(height: 12),
        TextField(
          key: const Key('rd-plan-song-search'),
          style: TextStyle(fontSize: 17, color: p.text),
          decoration: rdInputDecoration(p, l10n.attListSearchSong).copyWith(
            prefixIcon: Icon(Icons.search, color: p.text2),
          ),
          onChanged: (v) => setState(() => _query = v),
        ),
        const SizedBox(height: 16),
        if (filtered.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(l10n.attListNoSongsFound, textAlign: TextAlign.center, style: RdType.meta(p, size: 15)),
          ),
        if (current.isNotEmpty) ...[
          RdGroupLabel(l10n.songsCurrent),
          RdGroupedList(children: [for (final s in current) row(s)]),
          const SizedBox(height: 16),
        ],
        if (rest.isNotEmpty) ...[
          if (current.isNotEmpty) RdGroupLabel(l10n.songsAllSongs),
          RdGroupedList(children: [for (final s in rest) row(s)]),
        ],
      ],
    );
  }
}

/// Result of the Beta "Neuer Plan" sheet.
typedef RdNewPlanChoice = ({bool copy, int? day, String label});

/// Beta "+ Plan": name, day (multi-day Termine) and empty or as a copy.
Future<RdNewPlanChoice?> showRdNewPlanSheet(
  BuildContext context, {
  required List<({int day, String label})> days,
  int? initialDay,
  required String copyOf,
}) {
  return showRdPlanSheet<RdNewPlanChoice>(
    context,
    title: context.l10n.redesignPlanNewPlan,
    builder: (ctx, pop) => [_RdNewPlanBody(days: days, initialDay: initialDay, copyOf: copyOf, onDone: pop)],
  );
}

class _RdNewPlanBody extends StatefulWidget {
  const _RdNewPlanBody({required this.days, required this.initialDay, required this.copyOf, required this.onDone});

  final List<({int day, String label})> days;
  final int? initialDay;
  final String copyOf;
  final void Function(RdNewPlanChoice value) onDone;

  @override
  State<_RdNewPlanBody> createState() => _RdNewPlanBodyState();
}

class _RdNewPlanBodyState extends State<_RdNewPlanBody> {
  final _name = TextEditingController();
  late int? _day = widget.initialDay;
  bool _copy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RdGroupedList(
          children: [
            RdFieldRow(
              label: l10n.planningName,
              child: TextField(
                key: const Key('rd-plan-new-name'),
                controller: _name,
                textCapitalization: TextCapitalization.sentences,
                style: TextStyle(fontSize: 17, color: p.text),
                decoration: rdInputDecoration(p, l10n.redesignPlanNameHint),
              ),
            ),
          ],
        ),
        if (widget.days.isNotEmpty) ...[
          const SizedBox(height: 16),
          RdGroupLabel(l10n.redesignPlanDay),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final d in widget.days)
                RdChoiceChip(label: d.label, selected: d.day == _day, onTap: () => setState(() => _day = d.day)),
            ],
          ),
        ],
        const SizedBox(height: 16),
        RdGroupLabel(l10n.redesignPlanContent),
        RdSegmented<bool>(
          values: const [false, true],
          selected: _copy,
          labelOf: (v) => v ? l10n.redesignPlanCopyOf(widget.copyOf) : l10n.planningEmpty,
          onChanged: (v) => setState(() => _copy = v),
        ),
        const SizedBox(height: 20),
        RdPrimaryButton(
          key: const Key('rd-plan-new-confirm'),
          label: l10n.redesignPlanCreatePlan,
          onPressed: () => widget.onDone((copy: _copy, day: _day, label: _name.text.trim())),
        ),
      ],
    );
  }
}

/// Beta "Ablaufplan teilen" of a Termin with several plans: which plan on
/// top, then download and Telegram.
Future<PlanShareChoice?> showRdPlanShareSheet(
  BuildContext context, {
  required String currentLabel,
  required int planCount,
  required bool hasChatId,
}) {
  return showRdPlanSheet<PlanShareChoice>(
    context,
    title: context.l10n.attendanceShareRunSheet,
    builder: (ctx, pop) => [
      _RdShareBody(currentLabel: currentLabel, planCount: planCount, hasChatId: hasChatId, onDone: pop),
    ],
  );
}

class _RdShareBody extends StatefulWidget {
  const _RdShareBody({
    required this.currentLabel,
    required this.planCount,
    required this.hasChatId,
    required this.onDone,
  });

  final String currentLabel;
  final int planCount;
  final bool hasChatId;
  final void Function(PlanShareChoice value) onDone;

  @override
  State<_RdShareBody> createState() => _RdShareBodyState();
}

class _RdShareBodyState extends State<_RdShareBody> {
  bool _all = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    Widget option(IconData icon, String label, PlanExportAction action) => RdListRow(
      leading: RdRowIcon(icon),
      title: label,
      showChevron: false,
      onTap: () => widget.onDone((all: _all, action: action)),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RdGroupLabel(l10n.redesignPlanViewWhich),
        RdSegmented<bool>(
          values: const [false, true],
          selected: _all,
          labelOf: (v) => v ? l10n.planningAllPlans(widget.planCount) : l10n.planningOnlyLabel(widget.currentLabel),
          onChanged: (v) => setState(() => _all = v),
        ),
        const SizedBox(height: 16),
        RdGroupLabel(l10n.redesignPlanDownload),
        RdGroupedList(
          children: [
            option(Icons.description_outlined, l10n.attendanceExportPdf, PlanExportAction.pdf),
            option(Icons.file_copy_outlined, l10n.attendanceExportPdfA5, PlanExportAction.pdf2x),
          ],
        ),
        if (widget.hasChatId) ...[
          const SizedBox(height: 16),
          RdGroupLabel(l10n.redesignPlanTelegram),
          RdGroupedList(
            children: [
              option(Icons.send_outlined, l10n.attendanceTelegramPdf, PlanExportAction.telegram),
              option(Icons.send_outlined, l10n.attendanceTelegramPdfA5, PlanExportAction.telegram2x),
              if (!_all) option(Icons.image_outlined, l10n.attendanceTelegramImage, PlanExportAction.telegramImage),
            ],
          ),
        ],
      ],
    );
  }
}
