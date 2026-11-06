part of 'org_planning_templates_page.dart';

/// REDESIGN (Termin-Werkzeuge T2): Planungsvorlagen as a Verwaltungsliste
/// (Vorlagen and Standardfelder); a Vorlage opens the Beta Ablauf rows on
/// its own page. Saving and data stay the classic page's.
extension _OrgTemplatesBeta on _OrgPlanningTemplatesPageState {
  Widget _rdBuild(BuildContext context) {
    final l10n = context.l10n;
    final org = ref.watch(currentOrganisationProvider).valueOrNull;
    final templates = _templates;
    return RdManageListPage(
      title: l10n.orgTemplatesTitle,
      intro: org == null ? l10n.orgTemplatesTemplatesHint : l10n.redesignPlanTemplatesIntro(org.name),
      emptyText: l10n.orgTemplatesNoTemplates,
      emptyIcon: Icons.description_outlined,
      addLabel: l10n.orgTemplatesAddTemplate,
      // Only once the Vorlagen are loaded (_addTemplate needs them).
      onAdd:
          templates == null
              ? null
              : () async {
                final before = _templates?.length ?? 0;
                await _addTemplate();
                if (!mounted) return;
                final list = _templates;
                if (list != null && list.length > before) _rdOpenTemplate(list.length - 1);
              },
      sections:
          templates == null
              ? null
              : [
                RdManageListSection(
                  key: 'templates',
                  title: l10n.orgTemplatesTemplates,
                  items: [
                    for (var i = 0; i < templates.length; i++)
                      RdManageListItem(
                        // Position-independent: survives a failed save and a retry.
                        id: 'tpl-${identityHashCode(templates[i])}',
                        title: templates[i].title ?? '',
                        subtitle: _rdTemplateSubtitle(templates[i]),
                        onTap: () => _rdOpenTemplate(i),
                      ),
                  ],
                ),
                RdManageListSection(
                  key: 'fields',
                  title: l10n.orgTemplatesDefaultFields,
                  items: [
                    for (var i = 0; i < _defaultFields.length; i++)
                      RdManageListItem(
                        id: 'df-${_defaultFields[i].id}',
                        title: _defaultFields[i].name,
                        subtitle: [
                          if ((_defaultFields[i].conductor ?? '').isNotEmpty) _defaultFields[i].conductor!,
                          l10n.planningMinShort(_defaultFields[i].time),
                        ].join(' · '),
                        icon: Icons.short_text,
                        onTap: () => _rdEditDefaultField(i),
                      ),
                    RdManageListItem(
                      id: 'df-add',
                      title: l10n.redesignPlanAddDefaultField,
                      icon: Icons.add,
                      onTap: _addDefaultField,
                    ),
                  ],
                ),
              ],
      onReorder: (sections) async {
        final tplIds = sections.firstWhere((s) => s.key == 'templates').items.map((i) => i.id).toList();
        final fieldIds =
            sections.firstWhere((s) => s.key == 'fields').items.map((i) => i.id).where((id) => id != 'df-add').toList();
        final byId = {for (final t in _templates!) 'tpl-${identityHashCode(t)}': t};
        final newTemplates = [for (final id in tplIds) byId[id]!];
        final newFields = [for (final id in fieldIds) _defaultFields.firstWhere((f) => 'df-${f.id}' == id)];
        _update(() {
          _templates = newTemplates;
          _defaultFields = newFields;
        });
        // Both must be saved; a failure keeps the sort mode open for a retry.
        final templatesOk = await _saveTemplates();
        final fieldsOk = await _saveDefaultFields();
        return templatesOk && fieldsOk;
      },
    );
  }

  String _rdTemplateSubtitle(Plan tpl) {
    final l10n = context.l10n;
    final start = PlanUtils.formatTime(tpl.time);
    final end = _computeEnd(tpl);
    return [
      l10n.orgFlutterFieldCount(tpl.fields.length),
      if (start.isNotEmpty) start,
      if (end.isNotEmpty) l10n.orgTemplatesEndApprox(end),
    ].join(' · ');
  }

  /// Standardfeld: the same field sheet with Löschen.
  Future<void> _rdEditDefaultField(int index) async {
    final field = _defaultFields[index];
    var deleted = false;
    final r = await showPlanFieldDialog(
      context,
      title: context.l10n.typeSettingsEditField,
      nameLabel: context.l10n.orgTemplatesFieldName,
      nameHint: context.l10n.orgTemplatesFieldNamePh,
      conductorHint: context.l10n.orgTemplatesPerformerOptPh,
      emptyNameMessage: context.l10n.orgTemplatesEnterFieldName,
      confirmText: context.l10n.commonSave,
      initialName: field.name,
      initialConductor: field.conductor,
      initialMinutes: PlanUtils.minutesOf(field),
      withInfo: false,
      onDelete: () => deleted = true,
    );
    if (!mounted) return;
    final i = _defaultFields.indexWhere((f) => f.id == field.id);
    if (i < 0) return;
    if (deleted) {
      await _removeDefaultField(i);
      return;
    }
    if (r == null) return;
    _update(() {
      final list = [..._defaultFields];
      list[i] = field.copyWith(name: r.name, conductor: r.conductor, time: '${r.minutes ?? field.time}');
      _defaultFields = list;
    });
    await _saveDefaultFields();
  }

  void _rdOpenTemplate(int index) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => _RdTemplateEditor(host: this, index: index)));
  }
}

/// One Vorlage in the Beta look: name and start on top, the Ablauf rows,
/// "+ Punkt hinzufügen"; rename and delete behind •••.
class _RdTemplateEditor extends StatefulWidget {
  const _RdTemplateEditor({required this.host, required this.index});

  final _OrgPlanningTemplatesPageState host;
  final int index;

  @override
  State<_RdTemplateEditor> createState() => _RdTemplateEditorState();
}

class _RdTemplateEditorState extends State<_RdTemplateEditor> {
  _OrgPlanningTemplatesPageState get _host => widget.host;
  int get _index => widget.index;

  Plan? get _tpl {
    final list = _host._templates;
    return list != null && _index < list.length ? list[_index] : null;
  }

  @override
  void initState() {
    super.initState();
    _host._rdChanges.addListener(_onHostChanged);
  }

  @override
  void dispose() {
    _host._rdChanges.removeListener(_onHostChanged);
    super.dispose();
  }

  void _onHostChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _run(Future<void> Function() action) async {
    await action();
    if (mounted) setState(() {});
  }

  Future<void> _more() async {
    final l10n = context.l10n;
    final action = await showPlanActionSheet<String>(
      context,
      title: _tpl?.title,
      actions: [
        PlanSheetAction('rename', l10n.orgTemplatesRenameTemplate, icon: Icons.edit_outlined),
        PlanSheetAction('delete', l10n.commonDelete, icon: Icons.delete_outline, destructive: true),
      ],
    );
    if (!mounted || !_host.mounted) return;
    if (action == 'rename') await _run(() => _host._renameTemplate(_index));
    if (action == 'delete') {
      final ok = await showPlanConfirm(
        context,
        title: l10n.commonDelete,
        message: _tpl?.title ?? '',
        confirmText: l10n.commonDelete,
        destructive: true,
      );
      if (!ok || !mounted || !_host.mounted) return;
      await _host._removeTemplate(_index);
      if (mounted) Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final tpl = _tpl;
    if (tpl == null)
      return RdPage(
        children: [RdBackLink(label: l10n.orgTemplatesTitle, onTap: () => Navigator.of(context).maybePop())],
      );
    final start = PlanUtils.formatTime(tpl.time);
    return RdPage(
      children: [
        Row(
          children: [
            Expanded(child: RdBackLink(label: l10n.orgTemplatesTitle, onTap: () => Navigator.of(context).maybePop())),
            RdCircleButton(icon: Icons.more_horiz, label: l10n.redesignPlanMore, onPressed: _more),
          ],
        ),
        const SizedBox(height: 4),
        Semantics(header: true, child: Text(tpl.title ?? '', style: RdType.title(p))),
        const SizedBox(height: 4),
        Text(l10n.redesignPlanTemplateHint, style: RdType.meta(p, size: 15)),
        const SizedBox(height: 16),
        RdGroupedList(
          children: [
            RdListRow(
              leading: const RdRowIcon(Icons.edit_outlined),
              title: l10n.planningName,
              value: tpl.title ?? '',
              onTap: () => _run(() => _host._renameTemplate(_index)),
            ),
            RdListRow(
              leading: const RdRowIcon(Icons.schedule),
              title: l10n.shiftsStartTime,
              value: start.isEmpty ? '--:--' : start,
              onTap: () => _run(() => _host._pickStart(_index)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (start.isNotEmpty) ...[
          RdPlanSummaryBar(
            time: start,
            totalMinutes: PlanUtils.totalMinutes(tpl.fields),
            onPickTime: () => _run(() => _host._pickStart(_index)),
          ),
          const SizedBox(height: 12),
        ],
        RdCard(
          padding: EdgeInsets.zero,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: PlanFieldsEditor(
              fields: tpl.fields,
              startTime: start,
              showTimes: start.isNotEmpty,
              emptyText: l10n.orgFlutterNoFields,
              onChanged: (f) {
                final current = _tpl;
                if (current == null) return;
                _host._updateTemplate(_index, current.copyWith(fields: PlanUtils.normalizeGroups(f)));
                _host._saveTemplates();
                setState(() {});
              },
            ),
          ),
        ),
        const SizedBox(height: 16),
        Builder(
          builder:
              (button) => RdPrimaryButton(
                icon: Icons.add,
                label: l10n.redesignPlanAdd,
                onPressed: () => _run(() => _host._addToTemplate(_index, button)),
              ),
        ),
      ],
    );
  }
}
