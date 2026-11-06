import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/attendance_type_providers.dart';
import '../../../../core/providers/auto_message_providers.dart';
import '../../../../core/providers/group_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/dialog_helper.dart';
import '../../../../core/utils/tiptap_converter.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/attendance/attendance.dart';
import '../../../../data/models/auto_message/auto_message.dart';
import '../../../../l10n/l10n.dart';
import '../widgets/message_editor_toolbar.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';
import '../../../../shared/widgets/adaptive/ion_toolbar_segment.dart';
import '../../../settings/presentation/widgets/settings_list.dart';
import '../auto_message_texts.dart';
import 'package:attendix/shared/widgets/layout/ios_tab_bar.dart';
import '../../../../core/providers/redesign_providers.dart';
import '../../../../core/theme/redesign/rd_theme.dart';
import '../../../redesign/presentation/widgets/event/rd_event_head.dart' show rdEventMeta;
import '../../../redesign/presentation/widgets/event/rd_form_widgets.dart';
import '../../../redesign/presentation/widgets/rd_widgets.dart';
import '../../../redesign/presentation/widgets/today/rd_today_common.dart' show RdInfoCard;

part 'auto_message_rule_beta.dart';

enum _Tab { rule, history }

/// Create or edit one rule of Automatische Nachrichten, with preview and
/// history. Port of Ionic `AutoMessageRulePage`
/// (route `/settings/auto-messages/:id`, `new?template=…`, `:id?tab=history`).
class AutoMessageRulePage extends ConsumerStatefulWidget {
  const AutoMessageRulePage({super.key, required this.ruleId, this.template, this.initialTab});

  /// Rule id or `new`.
  final String ruleId;
  final String? template;
  final String? initialTab;

  @override
  ConsumerState<AutoMessageRulePage> createState() => _AutoMessageRulePageState();
}

class _AutoMessageRulePageState extends ConsumerState<AutoMessageRulePage> {
  late AutoMessageRule _rule;
  AutoMessageRule? _saved;
  bool _loading = true;
  bool _saving = false;
  _Tab _tab = _Tab.rule;

  final _nameController = TextEditingController();
  final _titleController = TextEditingController();
  QuillController? _quill;

  List<AutoMessagePreviewTermin>? _preview;
  bool _previewLoading = false;
  bool _previewError = false;

  static const _statusOptions = [4, 3, 0];

  @override
  void initState() {
    super.initState();
    _rule = AutoMessageRule.defaults(ref.read(currentTenantIdProvider) ?? 0);
    // l10n needs the inherited Localizations → after the first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _titleController.dispose();
    _quill?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final l10n = context.l10n;
    try {
      if (widget.ruleId != 'new') {
        final rule = await ref.read(autoMessageRepositoryWithTenantProvider).getRule(widget.ruleId);
        if (rule != null) {
          _rule = rule;
          _saved = rule;
          if (widget.initialTab == 'history') _tab = _Tab.history;
        }
      } else {
        final template = widget.template;
        if (template != null && autoMessageTemplates.contains(template)) {
          _rule = _rule.copyWith(
            name: l10n.autoMessageTemplateName(template),
            templateKey: template,
            statuses:
                template == 'late'
                    ? [3]
                    : template == 'noAnswer'
                    ? [0]
                    : null,
            frequency: template == 'streak' ? AutoMessageFrequency.streak : null,
            frequencyCount: template == 'streak' ? 2 : null,
          );
        } else {
          _rule = _rule.copyWith(name: l10n.autoMessagesTplNameAbsent);
        }
      }
      _nameController.text = _rule.name;
      _titleController.text = _rule.title ?? '';
      if (_rule.bodyJson != null) _setQuill(_rule.bodyJson!);
    } catch (_) {
      if (mounted) ToastHelper.showError(context, l10n.autoMessagesLoadFailed);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool get _isNew => _rule.id == null;

  void _update(AutoMessageRule next, {bool resetPreview = false}) {
    setState(() {
      _rule = next;
      if (resetPreview) _preview = null;
    });
  }

  // --- Text ------------------------------------------------------------------

  void _setQuill(Map<String, dynamic> doc) {
    _quill?.dispose();
    final controller = QuillController(
      document: Document.fromJson(TiptapConverter.toDeltaOps(doc)),
      selection: const TextSelection.collapsed(offset: 0),
    );
    controller.document.changes.listen((_) {
      if (!mounted) return;
      _rule = _rule.copyWith(
        bodyJson: TiptapConverter.fromDeltaOps(
          controller.document.toDelta().toJson().cast<Map<String, dynamic>>(),
        ),
      );
    });
    _quill = controller;
  }

  void _setTextMode(bool custom) {
    final l10n = context.l10n;
    if (custom && _rule.bodyJson == null) {
      // Start the own text from the chosen template.
      final doc = textToDoc(l10n.autoMessageTemplateBody(_rule.templateKey));
      _titleController.text = l10n.autoMessageTemplateTitle(_rule.templateKey);
      _rule = _rule.copyWith(title: _titleController.text, bodyJson: doc);
      _setQuill(doc);
    }
    _update(_rule.copyWith(useTemplate: !custom));
  }

  void _resetToTemplate() {
    final l10n = context.l10n;
    final doc = textToDoc(l10n.autoMessageTemplateBody(_rule.templateKey));
    _titleController.text = l10n.autoMessageTemplateTitle(_rule.templateKey);
    _setQuill(doc);
    _update(_rule.copyWith(title: _titleController.text, bodyJson: doc));
  }

  void _insertPlaceholder(String name) {
    final quill = _quill;
    if (quill == null) return;
    final text = '{$name}';
    final sel = quill.selection;
    final index = sel.isValid ? sel.start : quill.document.length - 1;
    final length = sel.isValid ? sel.end - sel.start : 0;
    quill.replaceText(index, length, text, TextSelection.collapsed(offset: index + text.length));
  }

  /// Template text with sample values, as members would see it (Ionic sample).
  ({String title, String body}) _sample(List<AttendanceType> types) {
    final l10n = context.l10n;
    final tenant = ref.read(currentTenantProvider);
    final vars = <String, Object?>{
      'vorname': l10n.autoMessagesSampleFirstName,
      'name': l10n.autoMessagesSampleName,
      'termin':
          types.where((t) => _rule.typeIds?.contains(t.id) ?? false).firstOrNull?.name ??
          types.firstOrNull?.name ??
          l10n.autoMessagesSampleTermin,
      'datum': formatTerminDate(DateFormat('yyyy-MM-dd').format(DateTime.now())),
      'uhrzeit': '19:30',
      'instanz':
          (tenant?.longName.isNotEmpty ?? false) ? tenant!.longName : (tenant?.shortName ?? ''),
      'anzahl': _rule.frequencyCount,
    };
    return (
      title: fillPlaceholders(l10n.autoMessageTemplateTitle(_rule.templateKey), vars),
      body: fillPlaceholders(l10n.autoMessageTemplateBody(_rule.templateKey), vars),
    );
  }

  // --- Preview ---------------------------------------------------------------

  Future<void> _loadPreview() async {
    setState(() {
      _previewLoading = true;
      _previewError = false;
    });
    try {
      final preview = await ref
          .read(autoMessageRepositoryWithTenantProvider)
          .preview(_currentRule());
      if (mounted) setState(() => _preview = preview);
    } catch (_) {
      if (mounted) setState(() => _previewError = true);
    } finally {
      if (mounted) setState(() => _previewLoading = false);
    }
  }

  // --- Save / delete ---------------------------------------------------------

  /// The rule as shown, with the text fields and the editor content read
  /// directly: option callbacks of an older build may have written an
  /// older `bodyJson` back into [_rule] (the editor listener updates it
  /// without a rebuild).
  AutoMessageRule _currentRule() {
    final quill = _quill;
    return _rule.copyWith(
      name: _nameController.text.trim(),
      title: _titleController.text.trim().isEmpty ? null : _titleController.text.trim(),
      bodyJson: quill == null
          ? _rule.bodyJson
          : TiptapConverter.fromDeltaOps(
              quill.document.toDelta().toJson().cast<Map<String, dynamic>>(),
            ),
    );
  }

  List<String> _problems(AutoMessageRule rule) {
    final l10n = context.l10n;
    return [
      if (rule.name.isEmpty) l10n.autoMessagesErrName,
      if (rule.statuses.isEmpty) l10n.autoMessagesErrStatus,
      if (rule.channels.isEmpty) l10n.autoMessagesErrChannel,
      if (!rule.useTemplate &&
          ((rule.title?.isEmpty ?? true) ||
              rule.bodyJson == null ||
              !TiptapConverter.hasText(rule.bodyJson!)))
        l10n.autoMessagesErrText,
    ];
  }

  Future<void> _save() async {
    if (_saving) return;
    final rule = _currentRule();
    final problems = _problems(rule);
    if (problems.isNotEmpty) {
      ToastHelper.showWarning(context, problems.first);
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(autoMessageRepositoryWithTenantProvider).saveRule(rule, _saved);
      ref.invalidate(autoMessageRulesProvider);
      if (!_isNew) ref.invalidate(autoMessageRuleByIdProvider(_rule.id!));
      if (!mounted) return;
      ToastHelper.showSuccess(context, context.l10n.autoMessagesSaved);
      context.pop();
    } catch (_) {
      if (mounted) ToastHelper.showError(context, context.l10n.autoMessagesSaveFailed);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final repo = ref.read(autoMessageRepositoryWithTenantProvider);
    final id = _rule.id;
    if (id == null) return;
    final l10n = context.l10n;
    final confirmed = await DialogHelper.showConfirmation(
      context,
      title: l10n.autoMessagesDeleteConfirm,
      message: l10n.autoMessagesDeleteHint,
      confirmText: l10n.commonDelete,
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;
    try {
      await repo.deleteRule(id);
      ref.invalidate(autoMessageRulesProvider);
      if (mounted) context.pop();
    } catch (_) {
      if (mounted) ToastHelper.showError(context, l10n.autoMessagesSaveFailed);
    }
  }

  // --- Build -----------------------------------------------------------------

  void _setTab(_Tab tab) => setState(() => _tab = tab);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (ref.watch(redesignEnabledProvider)) return _buildBeta();
    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? l10n.autoMessagesNewRule : l10n.autoMessagesRule),
        bottom:
            _loading || _isNew
                ? null
                : PreferredSize(
                  preferredSize: Size.fromHeight(IonToolbarSegment.toolbarHeight(context)),
                  child: IonToolbarSegment<_Tab>(
                    items: [
                      IonSegmentItem(value: _Tab.rule, label: Text(l10n.autoMessagesRule)),
                      IonSegmentItem(value: _Tab.history, label: Text(l10n.autoMessagesHistory)),
                    ],
                    value: _tab,
                    onChanged: (v) => setState(() => _tab = v),
                  ),
                ),
      ),
      // Ionic 4.19.6: "Speichern" as FAB.
      floatingActionButton:
          !_loading && _tab == _Tab.rule
              ? TabBarFab.wrap(
                FloatingActionButton(
                  tooltip: l10n.commonSave,
                  onPressed: _saving ? null : _save,
                  child:
                      _saving
                          ? const SizedBox(width: 22, height: 22, child: AppSpinner(strokeWidth: 2))
                          : const Icon(Icons.save_outlined),
                ),
              )
              : null,
      body:
          _loading
              ? const Center(child: AppSpinner())
              : ListView(
                padding: EdgeInsets.fromLTRB(
                  AppDimensions.paddingM,
                  AppDimensions.paddingM,
                  AppDimensions.paddingM,
                  scrollEndPadding(context, base: 16, fabRoom: 80),
                ),
                children: _tab == _Tab.history ? _buildHistory() : _buildRule(),
              ),
    );
  }

  List<Widget> _buildRule() {
    final l10n = context.l10n;
    final types =
        (ref.watch(attendanceTypesProvider).valueOrNull ?? const <AttendanceType>[])
            .where((t) => t.visible)
            .toList();
    final groups =
        (ref.watch(groupsProvider).valueOrNull ?? const []).where((g) => g.id != null).toList();
    final rule = _rule;

    return [
      // --- Allgemein
      SettingsListSection(
        title: l10n.autoMessagesGeneral,
        icons: false,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TextField(
              controller: _nameController,
              maxLength: 100,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: l10n.autoMessagesName,
                border: InputBorder.none,
                counterText: '',
              ),
            ),
          ),
          SwitchListTile.adaptive(
            value: rule.enabled,
            title: Text(l10n.autoMessagesActive),
            onChanged: (v) => _update(_rule.copyWith(enabled: v)),
          ),
        ],
      ),
      AutoMessageHint(l10n.autoMessagesActiveHint),

      // --- Wann wird geschickt?
      SettingsListSection(
        title: l10n.autoMessagesWhen,
        icons: false,
        children: [
          for (final s in _statusOptions)
            CheckboxListTile(
              value: rule.statuses.contains(s),
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(l10n.autoMessageTrigger(s)),
              subtitle: Text(l10n.autoMessageTriggerHint(s)),
              onChanged:
                  (_) => _update(
                    _rule.copyWith(
                      statuses:
                          rule.statuses.contains(s)
                              ? rule.statuses.where((x) => x != s).toList()
                              : [...rule.statuses, s],
                    ),
                    resetPreview: true,
                  ),
            ),
        ],
      ),

      // --- Wie oft?
      IonListHeader(title: l10n.autoMessagesHowOften),
      IonSegment<AutoMessageFrequency>(
        items: [
          IonSegmentItem(value: AutoMessageFrequency.each, label: Text(l10n.autoMessagesFreqEach)),
          IonSegmentItem(
            value: AutoMessageFrequency.streak,
            label: Text(l10n.autoMessagesFreqStreak),
          ),
          IonSegmentItem(
            value: AutoMessageFrequency.window,
            label: Text(l10n.autoMessagesFreqWindow),
          ),
        ],
        value: rule.frequency,
        onChanged: (v) => _update(_rule.copyWith(frequency: v), resetPreview: true),
      ),
      const SizedBox(height: 12),
      if (rule.frequency != AutoMessageFrequency.each)
        SettingsListSection(
          icons: false,
          children: [
            _StepperTile(
              label: l10n.autoMessagesFreqCount,
              value: '${rule.frequencyCount}×',
              onLess:
                  () => _update(
                    _rule.copyWith(frequencyCount: (rule.frequencyCount - 1).clamp(2, 50)),
                    resetPreview: true,
                  ),
              onMore:
                  () => _update(
                    _rule.copyWith(frequencyCount: (rule.frequencyCount + 1).clamp(2, 50)),
                    resetPreview: true,
                  ),
            ),
            if (rule.frequency == AutoMessageFrequency.window)
              _StepperTile(
                label: l10n.autoMessagesFreqDays,
                value: l10n.autoMessagesDays(rule.frequencyDays),
                onLess:
                    () => _update(
                      _rule.copyWith(frequencyDays: (rule.frequencyDays - 7).clamp(1, 365)),
                      resetPreview: true,
                    ),
                onMore:
                    () => _update(
                      _rule.copyWith(frequencyDays: (rule.frequencyDays + 7).clamp(1, 365)),
                      resetPreview: true,
                    ),
              ),
          ],
        ),
      AutoMessageHint(l10n.autoMessageFrequencyHint(rule)),

      // --- Für welche Termine?
      IonListHeader(title: l10n.autoMessagesWhichTermine),
      AutoMessageChipWrap(
        children: [
          for (final type in types)
            AutoMessageChip(
              label: type.name,
              selected: rule.typeIds?.contains(type.id) ?? false,
              onTap: () {
                final ids = [...?rule.typeIds];
                ids.contains(type.id) ? ids.remove(type.id) : ids.add(type.id!);
                _update(_rule.copyWith(typeIds: ids.isEmpty ? null : ids), resetPreview: true);
              },
            ),
        ],
      ),
      AutoMessageHint(
        (rule.typeIds?.isNotEmpty ?? false)
            ? l10n.autoMessagesTypesSome
            : l10n.autoMessagesTypesAll,
      ),

      // --- Gruppen
      IonListHeader(title: l10n.autoMessagesGroups),
      AutoMessageChipWrap(
        children: [
          for (final group in groups)
            AutoMessageChip(
              label: group.name,
              selected: rule.groupIds?.contains(group.id) ?? false,
              onTap: () {
                final ids = [...?rule.groupIds];
                ids.contains(group.id) ? ids.remove(group.id) : ids.add(group.id!);
                _update(_rule.copyWith(groupIds: ids.isEmpty ? null : ids), resetPreview: true);
              },
            ),
        ],
      ),
      AutoMessageHint(
        (rule.groupIds?.isNotEmpty ?? false)
            ? l10n.autoMessagesGroupsSome
            : l10n.autoMessagesGroupsAll,
      ),

      // --- Wartezeit
      SettingsListSection(
        icons: false,
        children: [
          _SelectTile<int>(
            label: l10n.autoMessagesDelay,
            value: rule.delayMinutes,
            options: [
              for (final d in autoMessageDelayOptions)
                AppSelectOption(value: d, label: l10n.autoMessageDelayLabel(d)),
            ],
            onChanged: (v) => _update(_rule.copyWith(delayMinutes: v)),
          ),
        ],
      ),
      AutoMessageHint(l10n.autoMessagesDelayHint),

      // Ionic .lock
      Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.lock_outline, size: 18, color: AppColors.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                l10n.autoMessagesSafety,
                style: const TextStyle(fontSize: 13.6, height: 1.4),
              ),
            ),
          ],
        ),
      ),

      // --- Nachricht
      IonListHeader(title: l10n.autoMessagesMessage),
      IonSegment<bool>(
        items: [
          IonSegmentItem(value: true, label: Text(l10n.autoMessagesUseTemplate)),
          IonSegmentItem(value: false, label: Text(l10n.autoMessagesCustomText)),
        ],
        value: rule.useTemplate,
        onChanged: (v) => _setTextMode(!v),
      ),
      const SizedBox(height: 12),
      if (rule.useTemplate) ...[
        SettingsListSection(
          icons: false,
          children: [
            _SelectTile<String>(
              label: l10n.autoMessagesTemplate,
              value: rule.templateKey,
              options: [
                for (final tpl in autoMessageTemplates)
                  AppSelectOption(value: tpl, label: l10n.autoMessageTemplateName(tpl)),
              ],
              onChanged: (v) => _update(_rule.copyWith(templateKey: v)),
            ),
            Builder(
              builder: (context) {
                final sample = _sample(types);
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(sample.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Text(
                        sample.body,
                        style: const TextStyle(fontSize: 14, height: 1.4, color: AppColors.medium),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
        AutoMessageHint(l10n.autoMessagesTemplateHint),
      ] else ...[
        SettingsListSection(
          icons: false,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: TextField(
                controller: _titleController,
                maxLength: 200,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: l10n.messagesTitle,
                  border: InputBorder.none,
                  counterText: '',
                ),
              ),
            ),
          ],
        ),
        if (_quill != null)
          SettingsListSection(
            icons: false,
            children: [
              MessageEditorToolbar(controller: _quill!),
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 180),
                child: Padding(
                  padding: const EdgeInsets.all(AppDimensions.paddingM),
                  child: QuillEditor.basic(
                    controller: _quill!,
                    config: QuillEditorConfig(
                      scrollable: false,
                      placeholder: l10n.editorMessagePlaceholder,
                    ),
                  ),
                ),
              ),
            ],
          ),
        AutoMessageChipWrap(
          children: [
            for (final p in autoMessagePlaceholders)
              AutoMessageChip(label: '{$p}', selected: true, onTap: () => _insertPlaceholder(p)),
          ],
        ),
        AutoMessageHint(
          '${l10n.autoMessagesCustomHint} ',
          trailing: WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: GestureDetector(
              onTap: _resetToTemplate,
              child: Text(
                l10n.autoMessagesResetToTemplate,
                style: const TextStyle(fontSize: 12.8, color: AppColors.primary),
              ),
            ),
          ),
        ),
      ],

      // --- Kanäle
      SettingsListSection(
        title: l10n.autoMessagesChannels,
        icons: false,
        children: [
          for (final (channel, label) in [
            ('push', l10n.autoMessagesChannelPush),
            ('email', l10n.autoMessagesChannelEmail),
          ])
            SwitchListTile.adaptive(
              value: rule.channels.contains(channel),
              title: Text(label),
              onChanged:
                  (on) => _update(
                    _rule.copyWith(
                      channels:
                          on
                              ? {...rule.channels, channel}.toList()
                              : rule.channels.where((c) => c != channel).toList(),
                    ),
                  ),
            ),
        ],
      ),

      // --- Grund nachtragen (Ionic 37deb4de: one card with the radios)
      SettingsListSection(
        title: l10n.autoMessagesResponses,
        icons: false,
        children: [
          SwitchListTile.adaptive(
            value: rule.allowResponses,
            title: Text(l10n.autoMessagesAllowResponses),
            subtitle: Text(l10n.autoMessagesAllowResponsesHint),
            onChanged: (v) => _update(_rule.copyWith(allowResponses: v)),
          ),
          if (rule.allowResponses)
            for (final (instant, label) in [
              (false, l10n.autoMessagesExcuseAfterCheck),
              (true, l10n.autoMessagesExcuseInstant),
            ])
              // ignore: deprecated_member_use
              RadioListTile<bool>(
                value: instant,
                // ignore: deprecated_member_use
                groupValue: rule.instantExcuse,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(label),
                // ignore: deprecated_member_use
                onChanged: (v) => _update(_rule.copyWith(instantExcuse: v)),
              ),
        ],
      ),
      if (rule.allowResponses)
        AutoMessageHint(l10n.autoMessagesResponsesHint(autoMessageResponseDays)),

      // --- Kopie
      SettingsListSection(
        title: l10n.autoMessagesCopy,
        icons: false,
        children: [
          CheckboxListTile(
            value: rule.copyResponsibles,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(l10n.autoMessagesCopyResponsibles),
            onChanged: (v) => _update(_rule.copyWith(copyResponsibles: v ?? false)),
          ),
          CheckboxListTile(
            value: rule.copyVoiceLeaders,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(l10n.autoMessagesCopyVoiceLeaders),
            onChanged: (v) => _update(_rule.copyWith(copyVoiceLeaders: v ?? false)),
          ),
        ],
      ),
      AutoMessageHint(l10n.autoMessagesCopyHint),

      // --- Vorschau
      IonListHeader(title: l10n.autoMessagesPreview),
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: OutlinedButton.icon(
          onPressed: _previewLoading ? null : _loadPreview,
          icon:
              _previewLoading
                  ? const SizedBox(width: 16, height: 16, child: AppSpinner(strokeWidth: 2))
                  : const Icon(Icons.visibility_outlined),
          label: IonButtonLabel(l10n.autoMessagesShowPreview),
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
        ),
      ),
      if (_previewError) AutoMessageHint(l10n.autoMessagesPreviewFailed),
      ..._buildPreview(groups.map((g) => (g.id!, g.name)).toList()),

      if (!_isNew)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: TextButton(
            onPressed: _delete,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.danger,
              minimumSize: const Size.fromHeight(48),
            ),
            child: IonButtonLabel(l10n.autoMessagesDeleteRule),
          ),
        ),
    ];
  }

  List<Widget> _buildPreview(List<(int, String)> groups) {
    final preview = _preview;
    if (preview == null) return const [];
    final l10n = context.l10n;
    String date(String d) {
      final parsed = DateTime.tryParse(d);
      return parsed == null ? d : DateFormat(dateFmt()).format(parsed);
    }

    return [
      if (preview.isEmpty) AutoMessageHint(l10n.autoMessagesPreviewNoTermine),
      for (final (i, p) in preview.indexed)
        SettingsListSection(
          icons: false,
          children: [
            ListTile(
              title: Text(
                '${p.title} · ${date(p.date)}${p.startTime != null ? ' · ${p.startTime}' : ''}',
                style: const TextStyle(fontSize: 14, color: AppColors.medium),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!p.recorded)
                    Text(
                      l10n.autoMessagesPreviewNotRecorded,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    )
                  else ...[
                    Text(
                      l10n.autoMessagesPreviewWould(p.people.length),
                      style: Theme.of(
                        context,
                      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    if (i == 0 && p.sendAt != null)
                      Text(
                        l10n.autoMessagesPreviewAt(
                          DateFormat('${dateFmt()}, HH:mm').format(p.sendAt!.toLocal()),
                        ),
                      ),
                  ],
                ],
              ),
            ),
            for (final person in p.people)
              ListTile(
                title: Text(person.name),
                trailing: IonNote(
                  [
                    groups.where((g) => g.$1 == person.groupId).firstOrNull?.$2 ?? '',
                    if (!person.app && person.email) l10n.autoMessagesOnlyEmail,
                    if (!person.app && !person.email) l10n.autoMessagesUnreachable,
                  ].where((s) => s.isNotEmpty).join(' · '),
                ),
              ),
            if (p.recorded)
              ListTile(
                title: Text(
                  l10n.autoMessagesPreviewExcluded(p.excused, p.paused),
                  style: const TextStyle(fontSize: 13, color: AppColors.medium),
                ),
              ),
          ],
        ),
      AutoMessageHint(l10n.autoMessagesPreviewHint),
    ];
  }

  List<Widget> _buildHistory() {
    final l10n = context.l10n;
    final id = _rule.id;
    if (id == null) return const [];
    final historyAsync = ref.watch(autoMessageHistoryProvider(id));
    return historyAsync.when(
      loading:
          () => [const Padding(padding: EdgeInsets.all(32), child: Center(child: AppSpinner()))],
      error: (e, _) => [AutoMessageHint(l10n.autoMessagesLoadFailed, center: true)],
      data: (history) {
        final sent = history.where((h) => h.run.status == 'sent');
        final totals = (
          sent: sent.fold<int>(0, (s, h) => s + h.run.recipientCount),
          read: sent.fold<int>(0, (s, h) => s + h.read),
          responses: sent.fold<int>(0, (s, h) => s + h.responses),
        );
        String date(String d) {
          final parsed = DateTime.tryParse(d);
          return parsed == null ? d : DateFormat(dateFmt()).format(parsed.toLocal());
        }

        return [
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              children: [
                for (final (i, (value, label))
                    in [
                      (totals.sent, l10n.autoMessagesHistSent),
                      (totals.read, l10n.autoMessagesHistRead),
                      (totals.responses, l10n.autoMessagesHistResponses),
                    ].indexed) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(child: _HistoryTile(value: '$value', label: label)),
                ],
              ],
            ),
          ),
          if (history.isEmpty)
            AutoMessageHint(l10n.autoMessagesHistEmpty)
          else
            SettingsListSection(
              icons: false,
              children: [
                for (final h in history)
                  SettingsListTile(
                    title: '${h.title} · ${date(h.date)}',
                    subtitle: switch (h.run.status) {
                      'sent' => l10n.autoMessagesHistRowSent(
                        h.run.recipientCount,
                        h.read,
                        h.responses,
                      ),
                      'not_recorded' => l10n.autoMessagesHistRowNotRecorded,
                      'suspended' => l10n.autoMessagesHistRowSuspended(
                        h.run.createdByName ?? l10n.commonUnknown,
                      ),
                      _ => l10n.autoMessagesHistRowNone,
                    },
                    detail: h.run.messageId != null,
                    onTap:
                        h.run.messageId == null
                            ? null
                            : () => context.push('/messages/${h.run.messageId}'),
                  ),
              ],
            ),
        ];
      },
    );
  }
}

/// Ionic `.stepper` item: label, − value +.
class _StepperTile extends StatelessWidget {
  const _StepperTile({
    required this.label,
    required this.value,
    required this.onLess,
    required this.onMore,
  });

  final String label;
  final String value;
  final VoidCallback onLess;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(label),
      contentPadding: const EdgeInsetsDirectional.only(start: 16, end: 4),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: context.l10n.autoMessagesLess,
            icon: const Icon(Icons.remove, color: AppColors.primary),
            onPressed: onLess,
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
          IconButton(
            tooltip: context.l10n.autoMessagesMore,
            icon: const Icon(Icons.add, color: AppColors.primary),
            onPressed: onMore,
          ),
        ],
      ),
    );
  }
}

/// Ionic `ion-item > ion-select interface="popover"` with a label.
class _SelectTile<T> extends StatelessWidget {
  const _SelectTile({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<AppSelectOption<T>> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final ios = ionIsIos(context);
    BuildContext? valueContext;
    final current = options.where((o) => o.value == value).firstOrNull?.label ?? '';
    return ListTile(
      title: Text(label),
      trailing: Builder(
        builder: (c) {
          valueContext = c;
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                current,
                style: TextStyle(
                  fontSize: 16,
                  color: ios ? IonIos.text(context) : AppColors.medium,
                ),
              ),
              const SizedBox(width: 4),
              ios
                  ? const IonSelectIcon()
                  : const Icon(Icons.arrow_drop_down, color: AppColors.medium),
            ],
          );
        },
      ),
      onTap: () async {
        final picked = await showAppSelect<T>(
          context: valueContext ?? context,
          value: value,
          options: options,
          header: label,
        );
        if (picked != null) onChanged(picked.value);
      },
    );
  }
}

/// Ionic `.tile` of the history (value + label).
class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ios = ionIsIos(context);
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 21.6,
              fontWeight: FontWeight.w700,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          Text(label, maxLines: 2, style: const TextStyle(fontSize: 12, color: AppColors.medium)),
        ],
      ),
    );
    if (!ios) return Card(margin: EdgeInsets.zero, child: content);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: IonIos.itemBackground(context),
        borderRadius: BorderRadius.circular(10),
      ),
      child: content,
    );
  }
}
