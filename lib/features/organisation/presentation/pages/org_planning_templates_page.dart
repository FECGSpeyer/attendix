import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../../../../core/providers/organisation_providers.dart';
import '../../../../core/providers/plan_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/plan_utils.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/plan/plan.dart';
import '../../../planning/presentation/widgets/plan_field_dialogs.dart';
import '../../../planning/presentation/widgets/plan_fields_editor.dart';
import '../../../../l10n/l10n.dart';
import '../../../settings/presentation/widgets/ion_condense.dart'; // UX_SETTINGS (WAVE 8)
import '../../../settings/presentation/widgets/settings_list.dart'; // UX_SETTINGS (WAVE 8)

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
    if (!ok && mounted) ToastHelper.showError(context, context.l10n.plansSaveFailed);
  }

  Future<void> _saveTemplates() async {
    final ok = await _notifier.updatePlanningTemplates([
      for (final t in _templates!) t.copyWith(end: _computeEnd(t)),
    ]);
    if (!ok && mounted) ToastHelper.showError(context, context.l10n.plansSaveFailed);
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
    final l10n = context.l10n;
    if (h == 0) return l10n.planningMinShort(m);
    return m > 0 ? l10n.orgTemplatesDuration(h, m) : l10n.orgTemplatesDurationH(h);
  }

  // ---------------------------------------------------------------------------
  // Default fields
  // ---------------------------------------------------------------------------

  Future<void> _addDefaultField() async {
    final r = await showPlanFieldDialog(
      context,
      title: context.l10n.typeSettingsAddField,
      nameLabel: context.l10n.orgTemplatesFieldName,
      nameHint: context.l10n.orgTemplatesFieldNamePh,
      conductorHint: context.l10n.orgTemplatesPerformerOptPh,
      emptyNameMessage: context.l10n.orgTemplatesEnterFieldName,
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
      title: context.l10n.orgTemplatesAddTemplate,
      hint: context.l10n.orgTemplatesTemplateNamePh,
      confirmText: context.l10n.attendanceAdd,
    );
    if (title == null) return;
    if (title.trim().isEmpty) {
      if (mounted) ToastHelper.showWarning(context, context.l10n.orgTemplatesEnterName);
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
      actions: [
        PlanSheetAction('rename', context.l10n.orgTemplatesRenameTemplate, icon: Icons.edit_outlined),
        PlanSheetAction('delete', context.l10n.commonDelete, icon: Icons.delete_outline, destructive: true),
      ],
    );
    if (action == null || !mounted) return;
    if (action == 'rename') {
      await _renameTemplate(index);
    } else {
      await _removeTemplate(index);
    }
  }

  Future<void> _renameTemplate(int index) async {
    final tpl = _templates![index];
    final title = await showPlanTextPrompt(
      context,
      title: context.l10n.orgTemplatesRenameTemplate,
      initialValue: tpl.title,
      hint: context.l10n.orgTemplatesTemplateNamePh,
      confirmText: context.l10n.commonSave,
    );
    if (title == null || title.trim().isEmpty) return;
    _updateTemplate(index, tpl.copyWith(title: title.trim()));
    await _saveTemplates();
  }

  Future<void> _removeTemplate(int index) async {
    setState(() {
      _templates = [..._templates!]..removeAt(index);
      if (_selected == index) {
        _selected = null;
      } else if (_selected != null && _selected! > index) {
        _selected = _selected! - 1;
      }
    });
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
        PlanSheetAction('field', context.l10n.typeSettingsAddField, icon: Icons.add),
        PlanSheetAction('note', context.l10n.typeSettingsAddNoteField, icon: Icons.sticky_note_2_outlined),
        if (!isGeneral) PlanSheetAction('song', context.l10n.orgTemplatesSongPlaceholder, icon: Icons.music_note_outlined),
        for (var i = 0; i < _defaultFields.length; i++)
          PlanSheetAction('default:$i', '${_defaultFields[i].name} (${context.l10n.planningMinShort(_defaultFields[i].time)})'),
      ],
    );
    if (action == null || !mounted) return;
    PlanField? field;
    if (action.startsWith('default:')) {
      field = _defaultFields[int.parse(action.substring(8))].copyWith(id: PlanUtils.uuid());
    } else if (action == 'field') {
      final r = await showPlanFieldDialog(
        context,
        title: context.l10n.typeSettingsAddField,
        nameHint: context.l10n.typeSettingsFreeTextPh,
        conductorHint: context.l10n.typeSettingsPerformerPh,
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
        title: context.l10n.typeSettingsAddNoteField,
        nameLabel: context.l10n.typeSettingsNote,
        nameHint: context.l10n.typeSettingsNotePh,
        withConductor: false,
        withInfo: false,
        withMinutes: false,
        requireName: false,
      );
      if (r == null) return;
      field = PlanField(id: 'noteFld ${r.name}', name: r.name, conductor: '', time: '0');
    } else if (action == 'song') {
      final n = tpl.fields.where((f) => f.id.startsWith(PlanUtils.songPlaceholderPrefix)).length + 1;
      field = PlanField(id: '${PlanUtils.songPlaceholderPrefix}$n', name: context.l10n.typeSettingsSongPlaceholderN(n), time: '20');
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
      helpText: context.l10n.shiftsStartTime,
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

  // UX_SETTINGS (WAVE 8): org-planning-templates.page.html — condense
  // title, inset lists with header "+" buttons, hint items in their own
  // inset lists (iOS).
  Widget _box(Widget child) => ionIsIos(context)
      ? Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: IonInsetGroup(children: [child]),
        )
      : Card(margin: const EdgeInsets.symmetric(horizontal: 12), child: child);

  Widget _header(String text, VoidCallback onAdd) => ionIsIos(context)
      ? Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: IonListHeader(
            title: text,
            action: IconButton(
              icon: const Icon(Icons.add, color: AppColors.primary),
              onPressed: onAdd,
            ),
          ),
        )
      : Padding(
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

  Widget _hint(String text) {
    final tile = ListTile(
      leading: const Icon(Icons.info_outline, color: AppColors.medium),
      title: Text(
        text,
        style: TextStyle(
          fontSize: ionIsIos(context) ? 14 : 13,
          color: ionIsIos(context) ? IonIos.labelP(context) : AppColors.medium,
        ),
      ),
    );
    return ionIsIos(context) ? _box(tile) : tile;
  }

  @override
  Widget build(BuildContext context) {
    final orgAsync = ref.watch(currentOrganisationProvider);
    if (_templates == null && orgAsync.hasValue) {
      final org = orgAsync.value;
      _templates = [...?org?.planningTemplates];
      _defaultFields = [...?org?.defaultFields];
    }

    return IonCondense(builder: (context, collapsed) => Scaffold(
      appBar: AppBar(title: IonCondenseTitle(context.l10n.orgTemplatesTitle, collapsed: collapsed)),
      body: _templates == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.only(bottom: 32),
              children: [
                IonLargeTitle(context.l10n.orgTemplatesTitle),
                _header(context.l10n.orgTemplatesDefaultFields, _addDefaultField),
                _box(_defaultFields.isEmpty
                      ? ListTile(
                          title: Text(context.l10n.orgTemplatesNoDefaultFields,
                              style: const TextStyle(color: AppColors.medium)))
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
                              // Ionic: ion-item-sliding with an expandable trash option
                              // (full swipe deletes).
                              Slidable(
                                key: ValueKey('df-${_defaultFields[i].id}-$i'),
                                endActionPane: ActionPane(
                                  motion: const DrawerMotion(),
                                  extentRatio: 0.2,
                                  dismissible: DismissiblePane(onDismissed: () => _removeDefaultField(i)),
                                  children: [
                                    SlidableAction(
                                      onPressed: (_) => _removeDefaultField(i),
                                      backgroundColor: AppColors.danger,
                                      foregroundColor: Colors.white,
                                      icon: Icons.delete,
                                    ),
                                  ],
                                ),
                                child: ListTile(
                                  title: Text(_defaultFields[i].name),
                                  subtitle: (_defaultFields[i].conductor ?? '').isNotEmpty
                                      ? Text(_defaultFields[i].conductor!)
                                      : null,
                                  onTap: () => _editDefaultField(i),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(context.l10n.planningMinShort(_defaultFields[i].time)),
                                      const SizedBox(width: 8),
                                      ReorderableDragStartListener(index: i, child: const Icon(Icons.drag_handle)),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                ),
                _hint(context.l10n.orgTemplatesDefaultFieldsHint),
                _header(context.l10n.orgTemplatesTemplates, _addTemplate),
                _box(Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_templates!.isEmpty)
                        ListTile(
                            title: Text(context.l10n.orgTemplatesNoTemplates,
                                style: const TextStyle(color: AppColors.medium))),
                      for (var i = 0; i < _templates!.length; i++) ..._templateTiles(i),
                    ],
                  ),
                ),
                _hint(context.l10n.orgTemplatesTemplatesHint),
              ],
            ),
    ));
  }

  List<Widget> _templateTiles(int i) {
    final tpl = _templates![i];
    final count = tpl.fields.length;
    final duration = _duration(tpl);
    final expanded = _selected == i;
    final end = _computeEnd(tpl);
    final start = PlanUtils.formatTime(tpl.time);
    return [
      // Ionic: ion-item-sliding with "Umbenennen" (pencil) and delete (trash).
      Slidable(
        key: ValueKey('tpl-$i-${tpl.title}'),
        endActionPane: ActionPane(
          motion: const DrawerMotion(),
          extentRatio: 0.4,
          children: [
            SlidableAction(
              onPressed: (_) => _renameTemplate(i),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              icon: Icons.edit_outlined,
            ),
            SlidableAction(
              onPressed: (_) => _removeTemplate(i),
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              icon: Icons.delete_outline,
            ),
          ],
        ),
        child: ListTile(
          title: Text(tpl.title ?? ''),
          subtitle: Text('${context.l10n.orgFlutterFieldCount(count)}${duration.isNotEmpty ? ' · $duration' : ''}'),
          onTap: () => setState(() => _selected = expanded ? null : i),
          // Desktop/mouse fallback for the swipe options.
          onLongPress: () => _templateOptions(i),
          trailing: Icon(expanded ? Icons.expand_less : Icons.expand_more, color: AppColors.medium),
        ),
      ),
      if (expanded) ...[
        ListTile(
          title: Text(context.l10n.shiftsStartTime),
          trailing: TextButton(onPressed: () => _pickStart(i), child: Text(start.isEmpty ? '--:--' : start)),
        ),
        PlanFieldsEditor(
          fields: tpl.fields,
          startTime: start,
          showTimes: start.isNotEmpty,
          emptyText: context.l10n.orgFlutterNoFields,
          onChanged: (f) {
            _updateTemplate(i, tpl.copyWith(fields: PlanUtils.normalizeGroups(f)));
            _saveTemplates();
          },
        ),
        ListTile(
          leading: const Icon(Icons.add, color: AppColors.primary),
          title: Text(context.l10n.typeSettingsAddField, style: const TextStyle(color: AppColors.primary)),
          onTap: () => _addToTemplate(i),
        ),
        if (end.isNotEmpty)
          ListTile(
            leading: const Icon(Icons.schedule, color: AppColors.medium),
            title: Text(context.l10n.orgTemplatesEndApprox(end), style: const TextStyle(color: AppColors.medium)),
          ),
        const Divider(height: 1),
      ],
    ];
  }
}
