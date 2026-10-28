import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/organisation_providers.dart';
import '../../../../core/providers/plan_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/plan_utils.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/plan/plan.dart';
import '../../../planning/presentation/widgets/plan_field_dialogs.dart';
import '../../../planning/presentation/widgets/plan_fields_editor.dart';

/// "Planvorlagen & Felder" of the organisation (Ionic `OrgPlanningTemplatesPage`).
///
/// Edits `tenant_groups.default_fields` and `tenant_groups.planning_templates`.
class OrgPlanningTemplatesPage extends ConsumerStatefulWidget {
  const OrgPlanningTemplatesPage({super.key});

  @override
  ConsumerState<OrgPlanningTemplatesPage> createState() => _OrgPlanningTemplatesPageState();
}

class _OrgPlanningTemplatesPageState extends ConsumerState<OrgPlanningTemplatesPage> {
  List<Plan>? _templates;
  List<PlanField> _defaultFields = [];
  int? _selected;

  PlanSettingsNotifier get _notifier => ref.read(planSettingsNotifierProvider.notifier);

  Future<void> _saveDefaultFields() async {
    final ok = await _notifier.updateDefaultFields(_defaultFields);
    if (!ok && mounted) ToastHelper.showError(context, 'Fehler beim Speichern');
  }

  Future<void> _saveTemplates() async {
    final ok = await _notifier.updatePlanningTemplates([
      for (final t in _templates!) t.copyWith(end: _computeEnd(t)),
    ]);
    if (!ok && mounted) ToastHelper.showError(context, 'Fehler beim Speichern');
  }

  String _computeEnd(Plan tpl) {
    if (tpl.time.isEmpty || tpl.fields.isEmpty) return '';
    final t = PlanUtils.formatTime(tpl.time);
    return t.isEmpty ? '' : PlanUtils.computeEnd(t, tpl.fields);
  }

  String _duration(Plan tpl) {
    final total = PlanUtils.totalMinutes(tpl.fields);
    if (total == 0) return '';
    final h = total ~/ 60;
    final m = total % 60;
    if (h == 0) return '$m min';
    return m > 0 ? '$h h $m min' : '$h h';
  }

  // ---------------------------------------------------------------------------
  // Default fields
  // ---------------------------------------------------------------------------

  Future<void> _addDefaultField() async {
    final r = await showPlanFieldDialog(
      context,
      title: 'Feld hinzufügen',
      nameLabel: 'Feldname',
      nameHint: 'Feldname...',
      conductorHint: 'Ausführender (optional)...',
      emptyNameMessage: 'Bitte einen Feldnamen eingeben.',
      initialMinutes: 20,
    );
    if (r == null) return;
    setState(() => _defaultFields = [
          ..._defaultFields,
          PlanField(id: PlanUtils.uuid(), name: r.name, conductor: r.conductor, info: r.info, time: '${r.minutes ?? 20}'),
        ]);
    await _saveDefaultFields();
  }

  Future<void> _editDefaultField(int index) async {
    final field = _defaultFields[index];
    final r = await showPlanFieldDialog(
      context,
      title: 'Feld bearbeiten',
      nameLabel: 'Feldname',
      nameHint: 'Feldname...',
      conductorHint: 'Ausführender (optional)...',
      emptyNameMessage: 'Bitte einen Feldnamen eingeben.',
      confirmText: 'Speichern',
      initialName: field.name,
      initialConductor: field.conductor,
      initialMinutes: PlanUtils.minutesOf(field),
      withInfo: false,
    );
    if (r == null) return;
    setState(() {
      final list = [..._defaultFields];
      list[index] = field.copyWith(name: r.name, conductor: r.conductor, time: '${r.minutes ?? field.time}');
      _defaultFields = list;
    });
    await _saveDefaultFields();
  }

  Future<void> _removeDefaultField(int index) async {
    setState(() => _defaultFields = [..._defaultFields]..removeAt(index));
    await _saveDefaultFields();
  }

  // ---------------------------------------------------------------------------
  // Templates
  // ---------------------------------------------------------------------------

  Future<void> _addTemplate() async {
    final title = await showPlanTextPrompt(
      context,
      title: 'Vorlage hinzufügen',
      hint: 'Name der Vorlage...',
      confirmText: 'Hinzufügen',
    );
    if (title == null) return;
    if (title.trim().isEmpty) {
      if (mounted) ToastHelper.showWarning(context, 'Bitte einen Namen eingeben.');
      return;
    }
    setState(() {
      _templates = [..._templates!, Plan(title: title.trim(), time: '', end: '', fields: const [])];
      _selected = _templates!.length - 1;
    });
    await _saveTemplates();
  }

  Future<void> _templateOptions(int index) async {
    final tpl = _templates![index];
    final action = await showPlanActionSheet<String>(
      context,
      title: tpl.title,
      actions: const [
        PlanSheetAction('rename', 'Vorlage umbenennen', icon: Icons.edit_outlined),
        PlanSheetAction('delete', 'Löschen', icon: Icons.delete_outline, destructive: true),
      ],
    );
    if (action == null || !mounted) return;
    if (action == 'rename') {
      final title = await showPlanTextPrompt(
        context,
        title: 'Vorlage umbenennen',
        initialValue: tpl.title,
        hint: 'Name der Vorlage...',
      );
      if (title == null || title.trim().isEmpty) return;
      _updateTemplate(index, tpl.copyWith(title: title.trim()));
    } else {
      setState(() {
        _templates = [..._templates!]..removeAt(index);
        if (_selected == index) {
          _selected = null;
        } else if (_selected != null && _selected! > index) {
          _selected = _selected! - 1;
        }
      });
    }
    await _saveTemplates();
  }

  void _updateTemplate(int index, Plan tpl) {
    setState(() {
      final list = [..._templates!];
      list[index] = tpl;
      _templates = list;
    });
  }

  Future<void> _addToTemplate(int index) async {
    final tpl = _templates![index];
    final isGeneral = ref.read(currentTenantProvider)?.type == 'general';
    final action = await showPlanActionSheet<String>(
      context,
      actions: [
        const PlanSheetAction('field', 'Feld hinzufügen', icon: Icons.add),
        const PlanSheetAction('note', 'Notizfeld hinzufügen', icon: Icons.sticky_note_2_outlined),
        if (!isGeneral) const PlanSheetAction('song', 'Werk-Platzhalter', icon: Icons.music_note_outlined),
        for (var i = 0; i < _defaultFields.length; i++)
          PlanSheetAction('default:$i', '${_defaultFields[i].name} (${_defaultFields[i].time} min)'),
      ],
    );
    if (action == null || !mounted) return;
    PlanField? field;
    if (action.startsWith('default:')) {
      field = _defaultFields[int.parse(action.substring(8))].copyWith(id: PlanUtils.uuid());
    } else if (action == 'field') {
      final r = await showPlanFieldDialog(
        context,
        title: 'Feld hinzufügen',
        nameHint: 'Freitext eingeben...',
        conductorHint: 'Ausführenden eingeben...',
        initialMinutes: 20,
        requireName: false,
      );
      if (r == null) return;
      field = PlanField(
        id: r.name.isNotEmpty ? r.name : PlanUtils.uuid(),
        name: r.name,
        conductor: r.conductor,
        info: r.info,
        time: '${r.minutes ?? 20}',
      );
    } else if (action == 'note') {
      final r = await showPlanFieldDialog(
        context,
        title: 'Notizfeld hinzufügen',
        nameLabel: 'Notiz',
        nameHint: 'Notiz eingeben...',
        withConductor: false,
        withInfo: false,
        withMinutes: false,
        requireName: false,
      );
      if (r == null) return;
      field = PlanField(id: 'noteFld ${r.name}', name: r.name, conductor: '', time: '0');
    } else if (action == 'song') {
      final n = tpl.fields.where((f) => f.id.startsWith(PlanUtils.songPlaceholderPrefix)).length + 1;
      field = PlanField(id: '${PlanUtils.songPlaceholderPrefix}$n', name: 'Werk Platzhalter $n', time: '20');
    }
    if (field == null) return;
    _updateTemplate(index, tpl.copyWith(fields: [...tpl.fields, field]));
    await _saveTemplates();
  }

  Future<void> _pickStart(int index) async {
    final tpl = _templates![index];
    final m = PlanUtils.parseTimeToMinutes(tpl.time) ?? 600;
    final picked = await showTimePicker(
      context: context,
      helpText: 'Startzeit',
      initialTime: TimeOfDay(hour: m ~/ 60, minute: m % 60),
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked == null) return;
    _updateTemplate(index, tpl.copyWith(time: PlanUtils.formatMinutes(picked.hour * 60 + picked.minute)));
    await _saveTemplates();
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  Widget _header(String text, VoidCallback onAdd) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 4, 0),
        child: Row(
          children: [
            Expanded(
              child: Text(text.toUpperCase(),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.medium)),
            ),
            IconButton(icon: const Icon(Icons.add), onPressed: onAdd),
          ],
        ),
      );

  Widget _hint(String text) => ListTile(
        leading: const Icon(Icons.info_outline, color: AppColors.medium),
        title: Text(text, style: const TextStyle(fontSize: 13, color: AppColors.medium)),
      );

  @override
  Widget build(BuildContext context) {
    final orgAsync = ref.watch(currentOrganisationProvider);
    if (_templates == null && orgAsync.hasValue) {
      final org = orgAsync.value;
      _templates = [...?org?.planningTemplates];
      _defaultFields = [...?org?.defaultFields];
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Planvorlagen & Felder')),
      body: _templates == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.only(bottom: 32),
              children: [
                _header('Standardfelder', _addDefaultField),
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  child: _defaultFields.isEmpty
                      ? const ListTile(
                          title: Text('Noch keine Standardfelder definiert', style: TextStyle(color: AppColors.medium)))
                      : ReorderableListView(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          buildDefaultDragHandles: false,
                          onReorder: (from, to) {
                            setState(() {
                              final list = [..._defaultFields];
                              final item = list.removeAt(from);
                              list.insert(to > from ? to - 1 : to, item);
                              _defaultFields = list;
                            });
                            _saveDefaultFields();
                          },
                          children: [
                            for (var i = 0; i < _defaultFields.length; i++)
                              ListTile(
                                key: ValueKey('df-${_defaultFields[i].id}-$i'),
                                title: Text(_defaultFields[i].name),
                                subtitle: (_defaultFields[i].conductor ?? '').isNotEmpty
                                    ? Text(_defaultFields[i].conductor!)
                                    : null,
                                onTap: () => _editDefaultField(i),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('${_defaultFields[i].time} min'),
                                    IconButton(
                                      tooltip: 'Löschen',
                                      icon: const Icon(Icons.delete_outline),
                                      onPressed: () => _removeDefaultField(i),
                                    ),
                                    ReorderableDragStartListener(index: i, child: const Icon(Icons.drag_handle)),
                                  ],
                                ),
                              ),
                          ],
                        ),
                ),
                _hint('Standardfelder erscheinen im Planungs-Menü als schnell hinzufügbare Felder für alle Instanzen der Organisation.'),
                _header('Vorlagen', _addTemplate),
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_templates!.isEmpty)
                        const ListTile(
                            title: Text('Noch keine Vorlagen definiert', style: TextStyle(color: AppColors.medium))),
                      for (var i = 0; i < _templates!.length; i++) ..._templateTiles(i),
                    ],
                  ),
                ),
                _hint('Vorlagen können beim Planen mit einem Tippen auf das Programm angewendet werden und ersetzen dabei den aktuellen Ablauf.'),
              ],
            ),
    );
  }

  List<Widget> _templateTiles(int i) {
    final tpl = _templates![i];
    final count = tpl.fields.length;
    final duration = _duration(tpl);
    final expanded = _selected == i;
    final end = _computeEnd(tpl);
    final start = PlanUtils.formatTime(tpl.time);
    return [
      ListTile(
        title: Text(tpl.title ?? ''),
        subtitle: Text('$count ${count == 1 ? 'Feld' : 'Felder'}${duration.isNotEmpty ? ' · $duration' : ''}'),
        onTap: () => setState(() => _selected = expanded ? null : i),
        onLongPress: () => _templateOptions(i),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(icon: const Icon(Icons.more_horiz), onPressed: () => _templateOptions(i)),
            Icon(expanded ? Icons.expand_less : Icons.expand_more, color: AppColors.medium),
          ],
        ),
      ),
      if (expanded) ...[
        ListTile(
          title: const Text('Startzeit'),
          trailing: TextButton(onPressed: () => _pickStart(i), child: Text(start.isEmpty ? '--:--' : start)),
        ),
        PlanFieldsEditor(
          fields: tpl.fields,
          startTime: start,
          showTimes: start.isNotEmpty,
          emptyText: 'Keine Felder',
          onChanged: (f) {
            _updateTemplate(i, tpl.copyWith(fields: PlanUtils.normalizeGroups(f)));
            _saveTemplates();
          },
        ),
        ListTile(
          leading: const Icon(Icons.add, color: AppColors.primary),
          title: const Text('Feld hinzufügen', style: TextStyle(color: AppColors.primary)),
          onTap: () => _addToTemplate(i),
        ),
        if (end.isNotEmpty)
          ListTile(
            leading: const Icon(Icons.schedule, color: AppColors.medium),
            title: Text('Ende ca. $end', style: const TextStyle(color: AppColors.medium)),
          ),
        const Divider(height: 1),
      ],
    ];
  }
}
