import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../auto_message_texts.dart';
import '../../../../core/providers/attendance_type_providers.dart';
import '../../../../core/providers/auto_message_providers.dart';
import '../../../../core/providers/group_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/utils/dialog_helper.dart';
import '../../../../core/utils/tiptap_converter.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/attendance/attendance.dart';
import '../../../../data/models/auto_message/auto_message.dart';
import '../../../../l10n/l10n.dart';
import '../widgets/message_editor_toolbar.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';
import '../../../../core/theme/redesign/rd_theme.dart';
import '../../../redesign/data/rd_words.dart';
import '../../../redesign/presentation/widgets/event/rd_event_head.dart' show rdEventMeta;
import '../../../redesign/presentation/widgets/event/rd_form_widgets.dart';
import '../../../redesign/presentation/widgets/rd_widgets.dart';
import '../../../redesign/presentation/widgets/today/rd_today_common.dart' show RdInfoCard;

part 'auto_message_rule_beta.dart';

enum _Tab { rule, history }

/// Rule ids are UUIDs; anything else can never exist (NACHTEST-A-10).
bool isAutoMessageRuleId(String id) => RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')
    .hasMatch(id);

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
        // NACHTEST-A-10 (EINST-60): an id that is no UUID (e.g. 99999999)
        // made the query fail with HTTP 400 and left an empty "Neue Regel"
        // form – treat it (and any load error) like an unknown id.
        AutoMessageRule? rule;
        if (isAutoMessageRuleId(widget.ruleId)) {
          try {
            rule = await ref.read(autoMessageRepositoryWithTenantProvider).getRule(widget.ruleId);
          } catch (_) {
            rule = null;
          }
        }
        if (rule != null) {
          _rule = rule;
          _saved = rule;
          if (widget.initialTab == 'history') _tab = _Tab.history;
        } else if (mounted) {
          // EINST-60: an unknown id used to open an empty "Neue Regel" form
          // (saving would create a new rule) – report it and go back.
          ToastHelper.showError(context, l10n.autoMessagesLoadFailed);
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/settings/auto-messages');
          }
          return;
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
  Widget build(BuildContext context) => _buildBeta();
}
