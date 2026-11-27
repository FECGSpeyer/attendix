part of 'planning_page.dart';

/// Multi-entry quick-add sheet and stateful form body for [PlanningPage].
extension _PlanningQuickAdd on _PlanningPageState {
  /// Adds several entries in a row in ONE sheet that stays open until
  /// "Fertig": Punkt or Notiz (form), "+ Werke" (the Werke of the Termin or
  /// the next Auftritt, else the Werk list) and "Block" (only its name; the
  /// next entries go into it, or behind it again). [group]: into that block
  /// (at its end, or behind [after] when it is inside); [block]: starts
  /// with the name of a new block ("Programmblock"). Every entry is stored
  /// at once (autosave).
  Future<void> _rdQuickAdd({String? group, PlanField? after, bool block = false}) async {
    final l10n = context.l10n;
    final loadGen = _loadGen;
    var join = group;
    // Where the next entry goes: behind this row. A position, not the row
    // itself: autosave may replace rows by copies (UIDs of the Gemeinde-App)
    // while the sheet is open; the rows only move by these inserts.
    int? lastAt;
    if (after != null) {
      final i = _fields.indexWhere((f) => identical(f, after));
      if (i >= 0) lastAt = i;
    }
    // The block made in this sheet, and the last entry added behind it.
    String? headId;
    int? behindAt;
    // A block of its own: still there after the plan changed meanwhile.
    bool alive() => mounted && loadGen == _loadGen && (join == null || _fields.any((f) => f.id == join));

    void insert(List<PlanField> rows) {
      final anchor = lastAt ?? -1;
      final int at;
      if (anchor >= 0 && anchor < _fields.length) {
        at = anchor + 1;
      } else if (join != null) {
        at = PlanUtils.lastIndexOfGroup(_fields, join!) + 1;
      } else {
        at = _fields.length;
      }
      final placed = [
        for (final r in rows)
          PlanUtils.isGroupHead(r) || PlanUtils.isAgendaPlaceholder(r) ? r : r.copyWith(groupId: join),
      ];
      if (join != null) _rdCollapsed.remove(join);
      _rdApply(PlanUtils.normalizeGroups([..._fields]..insertAll(at, placed)));
      lastAt = (at + placed.length - 1).clamp(0, _fields.length - 1);
      if (headId == null) return;
      if (join == headId) {
        if (behindAt != null) behindAt = behindAt! + placed.length;
      } else {
        behindAt = lastAt;
      }
    }

    String? headTitle() => join == null ? null : _fields.where((f) => f.id == join).firstOrNull?.name;
    // Not from "+ Punkt in …" (the sheet of that block): a block never sits
    // inside another one.
    final withBlock = !(join != null && after == null);
    final title =
        block && withBlock
            ? l10n.redesignPlanAddBlockRow
            : headTitle() != null
            ? l10n.redesignPlanQuickAddInBlock(headTitle()!)
            : l10n.redesignPlanAddPoint;
    final subtitle =
        join != null && after == null
            ? l10n.redesignPlanQuickAddInBlockHint
            : after != null
            ? l10n.redesignPlanAddAfter(after.name)
            : l10n.redesignPlanAddEnd;
    final isGeneral = ref.read(currentTenantProvider)?.type == 'general';

    await _rdSheet<String>(
      title: title,
      subtitle: subtitle,
      action: Builder(
        builder:
            (ctx) => TextButton(
              key: const Key('rd-plan-quick-done'),
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(l10n.redesignCommonDone),
            ),
      ),
      builder:
          (ctx, pop) => [
            _RdQuickAddBody(
              initialMinutes: join != null ? 5 : 20,
              withWorks: !isGeneral && _songs.isNotEmpty,
              withBlock: withBlock,
              startWithBlock: block && withBlock,
              duration: _rdDuration,
              block: () {
                final head = _fields.where((f) => f.id == headId).firstOrNull;
                if (head == null) return null;
                return (name: head.name, rows: [for (final f in _fields) if (f.groupId == head.id) f]);
              },
              onNewBlock: (name) {
                if (!alive()) return false;
                // A block never sits inside another one: behind the whole
                // block, and behind what was added after the last new one.
                final at = lastAt;
                if (headId != null && _fields.any((f) => f.id == headId)) {
                  lastAt = behindAt ?? PlanUtils.lastIndexOfGroup(_fields, headId!);
                } else if (at != null && at < _fields.length) {
                  final row = _fields[at];
                  final block = PlanUtils.isGroupHead(row) ? row.id : row.groupId;
                  if (block != null) lastAt = PlanUtils.lastIndexOfGroup(_fields, block);
                } else if (join != null) {
                  lastAt = PlanUtils.lastIndexOfGroup(_fields, join!);
                }
                final head = PlanUtils.newGroupHead(name);
                join = null;
                headId = null;
                insert([head]);
                headId = head.id;
                join = head.id;
                behindAt = null;
                return true;
              },
              onTarget: (inBlock) {
                final head = headId;
                if (head == null || !_fields.any((f) => f.id == head)) return;
                final end = PlanUtils.lastIndexOfGroup(_fields, head);
                join = inBlock ? head : null;
                lastAt = inBlock ? end : (behindAt ?? end);
              },
              onAdd: (kind, input) async {
                if (!alive()) return null;
                final PlanField row;
                if (kind == 'note') {
                  row = PlanField(id: 'noteFld ${input.name}', name: input.name, conductor: '', time: '0');
                } else {
                  row = PlanField(
                    id: 'fld-${PlanUtils.uuid()}',
                    name: input.name,
                    conductor: input.conductor,
                    info: input.info,
                    time: '${input.minutes ?? 0}',
                  );
                }
                insert([row]);
                return [row];
              },
              onWorks: () async {
                if (!alive()) return null;
                final rows = await _rdPickAnyWorksFields();
                if (rows.isEmpty || !alive()) return null;
                insert(rows);
                return rows;
              },
            ),
          ],
    );
  }
}

/// Content of the "Hinzufügen" sheet that stays open (see `_rdQuickAdd`):
/// one line on what was added so far, the block made here with what is in
/// it, the kind (Punkt, Notiz, Block, Werke), the form and one button.
class _RdQuickAddBody extends StatefulWidget {
  const _RdQuickAddBody({
    required this.initialMinutes,
    required this.withWorks,
    required this.withBlock,
    required this.startWithBlock,
    required this.duration,
    required this.block,
    required this.onNewBlock,
    required this.onTarget,
    required this.onAdd,
    required this.onWorks,
  });

  final int initialMinutes;
  final bool withWorks;

  /// The chip "Block" (not inside the sheet of an existing block).
  final bool withBlock;

  /// Opens with the name of a new block instead of the Punkt form.
  final bool startWithBlock;
  final String Function(int minutes) duration;

  /// The block made in this sheet with its Unterpunkte (null: none).
  final ({String name, List<PlanField> rows})? Function() block;

  /// A new block behind what was added; false when nothing was made.
  final bool Function(String name) onNewBlock;

  /// Where the next entries go: into the block made here, or behind it.
  final void Function(bool inBlock) onTarget;

  /// The rows that were added; null when nothing was.
  final Future<List<PlanField>?> Function(String kind, PlanFieldInput input) onAdd;
  final Future<List<PlanField>?> Function() onWorks;

  @override
  State<_RdQuickAddBody> createState() => _RdQuickAddBodyState();
}

class _RdQuickAddBodyState extends State<_RdQuickAddBody> {
  /// `field`, `note` or `block` (the form of a new block's name).
  late String _kind = widget.startWithBlock ? 'block' : 'field';
  late int _minutes = widget.initialMinutes;
  final _blockName = TextEditingController();
  int _count = 0;
  int _sum = 0;
  bool _inBlock = true;
  PlanFieldInput? _input;
  String? _error;
  int _gen = 0;
  bool _busy = false;

  @override
  void dispose() {
    _blockName.dispose();
    super.dispose();
  }

  void _setKind(String kind) => setState(() {
    if (_kind == kind) return;
    // A new form: the old entry is gone with it.
    _kind = kind;
    _input = null;
    _error = null;
  });

  Future<void> _submit() async {
    if (_kind == 'block') return _makeBlock();
    final input = _input;
    if (input == null || input.name.isEmpty) {
      setState(
        () => _error = _kind == 'note' ? context.l10n.plansEnterNotePlease : context.l10n.planningEnterNamePlease,
      );
      return;
    }
    await _run(() => widget.onAdd(_kind, input), minutes: input.minutes);
  }

  void _makeBlock() {
    final name = _blockName.text.trim();
    if (name.isEmpty) {
      setState(() => _error = context.l10n.planningEnterNamePlease);
      return;
    }
    if (!widget.onNewBlock(name)) return;
    setState(() {
      _blockName.clear();
      _kind = 'field';
      _inBlock = true;
      // Unterpunkte are short.
      _minutes = 5;
      _input = null;
      _error = null;
      _gen++;
    });
  }

  Future<void> _run(Future<List<PlanField>?> Function() add, {int? minutes}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final rows = await add();
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (rows == null) return;
      _count += rows.length;
      _sum += rows.fold(0, (a, r) => a + PlanUtils.fieldMinutes(r));
      // The next Punkt starts with the same length.
      if (minutes != null) _minutes = minutes;
      _input = null;
      _gen++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final note = _kind == 'note';
    final newBlock = _kind == 'block';
    final block = widget.block();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_count > 0) ...[
          Row(
            key: const Key('rd-plan-quick-summary'),
            children: [
              Icon(Icons.check, size: 20, color: p.softText),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  [l10n.redesignPlanQuickAddSummary(_count), if (_sum > 0) widget.duration(_sum)].join(' · '),
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: p.softText),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
        if (block != null) ...[
          RdGroupLabel(l10n.redesignPlanQuickAddTarget),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              RdChoiceChip(
                key: const Key('rd-plan-quick-target-in'),
                label: l10n.redesignPlanQuickAddTargetIn(block.name),
                selected: _inBlock,
                onTap: () {
                  widget.onTarget(true);
                  setState(() => _inBlock = true);
                },
              ),
              RdChoiceChip(
                key: const Key('rd-plan-quick-target-behind'),
                label: l10n.redesignPlanQuickAddTargetBehind,
                selected: !_inBlock,
                onTap: () {
                  widget.onTarget(false);
                  setState(() => _inBlock = false);
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          RdGroupedList(
            key: const Key('rd-plan-quick-block-card'),
            children: [
              RdListRow(
                leading: const RdRowIcon(Icons.view_agenda_outlined),
                title: block.name,
                subtitle: [
                  l10n.redesignPlanItemCount(block.rows.length),
                  if (block.rows.isNotEmpty)
                    widget.duration(block.rows.fold(0, (a, r) => a + PlanUtils.fieldMinutes(r))),
                ].join(' · '),
                showChevron: false,
              ),
              for (final (i, row) in block.rows.indexed)
                RdListRow(
                  key: ValueKey('rd-plan-quick-block-row-$i'),
                  title: row.name,
                  trailing:
                      PlanUtils.fieldMinutes(row) > 0 ? RdPill(widget.duration(PlanUtils.fieldMinutes(row))) : null,
                  showChevron: false,
                ),
            ],
          ),
          const SizedBox(height: 16),
        ],
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            RdChoiceChip(
              key: const Key('rd-plan-quick-kind-field'),
              label: l10n.redesignPlanAddItem,
              selected: _kind == 'field',
              onTap: () => _setKind('field'),
            ),
            RdChoiceChip(
              key: const Key('rd-plan-quick-kind-note'),
              label: l10n.redesignPlanAddNote,
              selected: note,
              onTap: () => _setKind('note'),
            ),
            if (widget.withBlock)
              RdChoiceChip(
                key: const Key('rd-plan-quick-block'),
                label: l10n.redesignPlanAddBlock,
                selected: newBlock,
                onTap: () => _setKind('block'),
              ),
            if (widget.withWorks)
              RdChoiceChip(
                key: const Key('rd-plan-quick-works'),
                label: l10n.redesignPlanAddWorks,
                icon: Icons.add,
                selected: false,
                onTap: () => _run(widget.onWorks),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (newBlock)
          RdGroupedList(
            children: [
              RdFieldRow(
                label: l10n.redesignPlanBlockName,
                child: TextField(
                  key: const Key('rd-plan-quick-block-name'),
                  controller: _blockName,
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.done,
                  style: TextStyle(fontSize: 17, color: p.text),
                  decoration: rdInputDecoration(p, l10n.planningBlockNamePlaceholder),
                  onSubmitted: (_) => _makeBlock(),
                ),
              ),
            ],
          )
        else
          RdPlanFieldForm(
            key: ValueKey('rd-plan-quick-form-$_kind-$_gen'),
            labels:
                note
                    ? RdPlanFieldLabels(name: l10n.planningNote, nameHint: l10n.planningEnterNote)
                    : RdPlanFieldLabels(infoHint: l10n.planningInfoOptionalEllipsis),
            initialMinutes: note ? null : _minutes,
            withConductor: !note,
            withInfo: !note,
            withMinutes: !note,
            autofocus: true,
            singleLineName: true,
            onChanged: (v) => _input = v,
            onSubmitted: _submit,
          ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: TextStyle(fontSize: 14, color: p.absent)),
        ],
        const SizedBox(height: 16),
        RdPrimaryButton(
          key: const Key('rd-plan-quick-add'),
          icon: Icons.add,
          label:
              newBlock
                  ? l10n.redesignPlanQuickAddBlockCreate
                  : _count > 0
                  ? l10n.redesignPlanQuickAddMore(_kind)
                  : l10n.redesignPlanQuickAddButton,
          loading: _busy,
          onPressed: _submit,
        ),
        const SizedBox(height: 8),
        Text(
          newBlock ? l10n.redesignPlanQuickAddBlockHint : l10n.redesignPlanQuickAddHint,
          textAlign: TextAlign.center,
          style: RdType.meta(p, size: 13),
        ),
      ],
    );
  }
}
