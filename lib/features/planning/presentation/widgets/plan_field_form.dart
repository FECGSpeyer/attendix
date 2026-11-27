part of 'plan_widgets.dart';

// Plan item/block form fields, duration presets, and field entry sheet.

/// Typical durations of a Programmpunkt (same as the inline editor).
const rdPlanDurationPresets = [5, 10, 15, 20, 30, 40, 45, 60];


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
    this.singleLineName = false,
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

  /// The name in one line, so Enter submits (quick adding several items).
  final bool singleLineName;
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

  bool get _beamerOn => _manualBeamer ?? PlanBeamer.autoNeedsBeamer(name: _name.text, songId: widget.beamer?.songId);

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
    final reason = beamer == null ? null : PlanBeamer.autoReason(name: _name.text, songId: beamer.songId, manual: _manualBeamer);
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
              maxLines: widget.singleLineName ? 1 : 3,
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
                    for (final v in rdPlanDurationPresets) RdChoiceChip(label: '$v', selected: v == m, onTap: () => _setMinutes(v)),
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
                    reason == null ? null : (reason.song ? l10n.planningBeamerAutoSong : l10n.planningBeamerAutoWord(reason.word ?? '')),
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
    builder:
        (ctx, pop) => [
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
        if (_error != null) ...[const SizedBox(height: 8), Text(_error!, style: TextStyle(color: p.absent, fontSize: 14))],
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

