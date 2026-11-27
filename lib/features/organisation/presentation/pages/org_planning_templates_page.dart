import 'dart:async';

import 'package:flutter/material.dart';
import 'package:attendix/core/theme/app_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/organisation_providers.dart';
import '../../../../core/providers/plan_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/utils/plan_utils.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/plan/plan.dart';
import '../../../planning/presentation/widgets/plan_field_dialogs.dart';
import '../../../planning/presentation/widgets/plan_fields_editor.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';
import '../../../../core/theme/redesign/rd_theme.dart';
import '../../../planning/presentation/widgets/rd_plan_widgets.dart';
import '../../../settings/presentation/widgets/manage/rd_manage_list.dart';
import '../../../../shared/widgets/redesign/rd_widgets.dart';

part 'org_planning_templates_view.dart';

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

  /// Bumped on every host rebuild so a pushed Vorlagen-Editor shows
  /// local changes at once, not only after saving.
  final _rdChanges = ValueNotifier<int>(0);

  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    _rdChanges.value++;
  }

  @override
  void dispose() {
    _rdChanges.dispose();
    super.dispose();
  }
  List<PlanField> _defaultFields = [];
  int? _selected;

  /// Captured up front (not via `ref` later) so the inline minutes can still
  /// be saved from `dispose()` while the page is being removed.
  late final PlanSettingsNotifier _notifier;

  /// Organisation whose Standardfelder are shown; captured with them.
  int? _orgId;

  @override
  void initState() {
    super.initState();
    _notifier = ref.read(planSettingsNotifierProvider.notifier);
  }

  /// setState for the view extension (part file).
  void _update(VoidCallback fn) => setState(fn);

  /// Saves the current Standardfelder; `true` once the write is confirmed.
  /// Uses no `ref`/`context` unless the page is still mounted.
  Future<bool> _saveDefaultFields() async {
    final orgId = _orgId;
    if (orgId == null) return false;
    final ok = await _notifier.saveDefaultFields(orgId, _defaultFields);
    if (!ok && mounted) ToastHelper.showError(context, context.l10n.plansSaveFailed);
    return ok;
  }

  /// Ionic saves the templates as edited; `end` is not computed into them
  /// (new templates keep `end: ''`), the end is only shown.
  Future<bool> _saveTemplates() async {
    final ok = await _notifier.updatePlanningTemplates(_templates!);
    if (!ok && mounted) ToastHelper.showError(context, context.l10n.plansSaveFailed);
    return ok;
  }

  String _computeEnd(Plan tpl) {
    if (tpl.time.isEmpty || tpl.fields.isEmpty) return '';
    final t = PlanUtils.formatTime(tpl.time);
    return t.isEmpty ? '' : PlanUtils.computeEnd(t, tpl.fields);
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
      emptyMessage: context.l10n.orgTemplatesEnterName,
    );
    if (title == null || title.trim().isEmpty || _templates == null || !mounted) return;
    setState(() {
      _templates = [..._templates!, Plan(title: title.trim(), time: '', end: '', fields: const [])];
      _selected = _templates!.length - 1;
    });
    await _saveTemplates();
  }

  Future<void> _renameTemplate(int index) async {
    final tpl = _templates![index];
    final title = await showPlanTextPrompt(
      context,
      title: context.l10n.orgTemplatesRenameTemplate,
      initialValue: tpl.title,
      hint: context.l10n.orgTemplatesTemplateNamePh,
      confirmText: context.l10n.commonSave,
      emptyMessage: context.l10n.orgTemplatesEnterName,
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

  Future<void> _addToTemplate(int index, BuildContext buttonContext) async {
    final tpl = _templates![index];
    final isGeneral = ref.read(currentTenantProvider)?.type == 'general';
    final action = await showPlanActionSheet<String>(
      context,
      title: context.l10n.redesignPlanAddTitle,
      actions: [
        PlanSheetAction('field', context.l10n.typeSettingsAddField, icon: AppIcons.add),
        PlanSheetAction('note', context.l10n.typeSettingsAddNoteField, icon: AppIcons.stickyNote2Outlined),
        if (!isGeneral)
          PlanSheetAction('song', context.l10n.orgTemplatesSongPlaceholder, icon: AppIcons.musicNoteOutlined),
        for (var i = 0; i < _defaultFields.length; i++)
          PlanSheetAction(
            'default:$i',
            '${_defaultFields[i].name} · ${context.l10n.planningMinShort(_defaultFields[i].time)}',
            icon: AppIcons.shortText,
          ),
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
    final picked = await showAppTimePicker(
      context: context,
      helpText: context.l10n.shiftsStartTime,
      initialTime: TimeOfDay(hour: m ~/ 60, minute: m % 60),
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked == null) return;
    // Ionic ion-datetime writes tpl.time as ISO date time; Ionic
    // public-planning only takes it over when dayjs(tpl.time).isValid().
    _updateTemplate(index, tpl.copyWith(time: PlanUtils.ionTimeValue(picked.hour, picked.minute, previous: tpl.time)));
    await _saveTemplates();
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final orgAsync = ref.watch(currentOrganisationProvider);
    if (_templates == null && orgAsync.hasValue) {
      final org = orgAsync.value;
      _templates = [...?org?.planningTemplates];
      _defaultFields = [...?org?.defaultFields];
      _orgId = org?.id;
    }
    return _rdBuild(context);
  }
}
