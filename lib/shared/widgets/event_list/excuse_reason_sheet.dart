import 'package:flutter/material.dart';
import 'package:attendix/shared/widgets/layout/sheet_drag.dart';
import 'package:attendix/core/theme/app_icons.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/quill_utils.dart';
import '../../../data/models/attendance/attendance.dart';
import '../../../l10n/l10n.dart';
import '../adaptive/adaptive.dart';
import '../../../core/theme/redesign/rd_theme.dart';
import '../dialogs/ion_sheet.dart';
import '../layout/ionic_ios.dart';

// Internal sentinel for the free-text option (never stored).
const String _customReason = 'Sonstiger Grund';

/// Reason sheet for Absagen / Verspätung (Ionic ExcuseReasonPicker).
///
/// Shows the tenant's absence or late reasons plus "Sonstiger Grund (Text)".
/// When the Termin is today the free text is preselected, otherwise the
/// first predefined reason. Returns the reason or null when cancelled.
Future<String?> showExcuseReasonSheet(
  BuildContext context, {
  required bool isLate,
  required bool isToday,
  required List<String> absenceReasons,
  required List<String> lateReasons,
}) {
  if (context.rdSkin == null) {
    // Ionic excuse-reason-picker: breakpoints [0, 0.6, 1]
    return showIonSheet<String>(
      context,
      breakpoints: const [0, 0.6, 1],
      initialBreakpoint: 0.6,
      builder: (ctx, scrollController) => _ExcuseReasonSheet(
        isLate: isLate,
        reasons: isLate ? lateReasons : absenceReasons,
        isToday: isToday,
        scrollController: scrollController,
      ),
    );
  }
  return showModalBottomSheet<String>(
    context: context,
    useRootNavigator: true, // IOS_SHELL2: above the tab bar
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => _ExcuseReasonSheet(
      isLate: isLate,
      reasons: isLate ? lateReasons : absenceReasons,
      isToday: isToday,
    ),
  );
}

class _ExcuseReasonSheet extends StatefulWidget {
  const _ExcuseReasonSheet({
    required this.isLate,
    required this.reasons,
    required this.isToday,
    this.scrollController,
  });

  final bool isLate;
  final List<String> reasons;
  final bool isToday;

  /// Classic design: the controller of the Ionic breakpoint sheet.
  final ScrollController? scrollController;

  @override
  State<_ExcuseReasonSheet> createState() => _ExcuseReasonSheetState();
}

class _ExcuseReasonSheetState extends State<_ExcuseReasonSheet> {
  late String _selection;
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selection = widget.isToday || widget.reasons.isEmpty
        ? _customReason
        : widget.reasons.first;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _confirmable => _selection == _customReason
      ? _controller.text.trim().length > 4
      : _selection.isNotEmpty;

  void _confirm() {
    if (!_confirmable) return;
    Navigator.of(context).pop(
      _selection == _customReason ? _controller.text.trim() : _selection,
    );
  }

  @override
  Widget build(BuildContext context) {
    // UX_SONGS_SELF: Ionic excuse-reason-picker toolbar:
    // close (start), title, checkmark (end, strong)
    final title = widget.isLate ? context.l10n.excuseLate : context.l10n.excuseSignOut;
    final start = <Widget>[
      IconButton(
        icon: Icon(AppIcons.close),
        tooltip: context.l10n.commonCancel,
        onPressed: () => Navigator.of(context).pop(),
      ),
    ];
    final end = <Widget>[
      IconButton(
        icon: Icon(AppIcons.check),
        tooltip: context.l10n.commonConfirm,
        onPressed: _confirmable ? _confirm : null,
      ),
    ];
    final scrollController = widget.scrollController;
    if (scrollController != null) {
      return IonSheetScaffold(
        title: title,
        start: start,
        end: end,
        body: SafeArea(
          top: false,
          child: SingleChildScrollView(
            controller: scrollController,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: _rows(context),
            ),
          ),
        ),
      );
    }
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              IonSheetHeader(title: title, start: start, end: end),
              ..._rows(context),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _rows(BuildContext context) => [
              // Ionic ion-radio (justify start, label end, lines full); iOS
              // draws a checkmark for the selected reason.
              for (final reason in [...widget.reasons, _customReason])
                if (isIosLook(context))
                  _IosRadioRow(
                    label: reason == _customReason ? context.l10n.excuseCustomOption : reason,
                    selected: _selection == reason,
                    onTap: () => setState(() => _selection = reason),
                  )
                else
                  RadioListTile<String>(
                    value: reason,
                    groupValue: _selection,
                    onChanged: (v) => setState(() => _selection = v ?? _selection),
                    title: Text(reason == _customReason ? context.l10n.excuseCustomOption : reason),
                  ),
              if (_selection == _customReason)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  child: TextField(
                    controller: _controller,
                    autofocus: true,
                    minLines: 2,
                    maxLines: 5,
                    textCapitalization: TextCapitalization.sentences,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: context.l10n.excuseReason,
                      hintText: context.l10n.excuseMinChars,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: FilledButton(
                  onPressed: _confirmable ? _confirm : null,
                  child: IonButtonLabel(context.l10n.commonConfirm),
                ),
              ),
      ];
}

class _IosRadioRow extends StatelessWidget {
  const _IosRadioRow({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Theme.of(context).dividerColor, width: 0.5),
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              child: selected
                  ? Icon(AppIcons.check, color: AppColors.primary, size: 22)
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(child: Text(label, style: const TextStyle(fontSize: 16))),
          ],
        ),
      ),
    );
  }
}

/// Default answer of a registration field.
dynamic registrationFieldDefault(RegistrationField field) {
  switch (field.type) {
    case RegistrationFieldType.boolean:
      return false;
    case RegistrationFieldType.multiSelect:
      return <String>[];
    default:
      return '';
  }
}

/// Validates answers: text fields must not be empty. Returns the label of
/// the first missing field or null.
String? missingRegistrationField(
  List<RegistrationField> fields,
  Map<String, dynamic> answers,
) {
  for (final field in fields) {
    if (field.type == RegistrationFieldType.text &&
        (answers[field.id]?.toString().trim().isEmpty ?? true)) {
      return field.label;
    }
  }
  return null;
}

/// Readable answer ("Ja", "A, B", text).
String registrationAnswerText(RegistrationField field, dynamic answer) {
  if (answer == null) return '';
  if (field.type == RegistrationFieldType.boolean) {
    return answer == true
        ? l10nWithoutContext.commonYes
        : l10nWithoutContext.commonNo;
  }
  if (answer is List) return answer.join(', ');
  return answer.toString();
}

/// Sheet for the registration fields (Anmeldefelder) of a Termin.
///
/// [editMode] = "Anmeldefelder anpassen" (Speichern) instead of sign in
/// (Anmelden). Returns the answers or null when cancelled.
Future<Map<String, dynamic>?> showRegistrationFieldsSheet(
  BuildContext context, {
  required List<RegistrationField> fields,
  Map<String, dynamic>? existing,
  bool editMode = false,
  bool requireText = true,
}) {
  final answers = <String, dynamic>{
    for (final f in fields)
      f.id: (existing != null && existing.containsKey(f.id))
          ? (existing[f.id] is List ? List<String>.from((existing[f.id] as List).map((e) => e.toString())) : existing[f.id])
          : registrationFieldDefault(f),
  };
  if (context.rdSkin == null) {
    // Ionic regFieldsModal: breakpoints [0, 0.85, 1], initial 0.85
    return showIonSheet<Map<String, dynamic>>(
      context,
      breakpoints: const [0, 0.85, 1],
      initialBreakpoint: 0.85,
      backdropDismiss: editMode,
      builder: (ctx, scrollController) => _RegistrationFieldsSheet(
        fields: fields,
        answers: answers,
        editMode: editMode,
        requireText: requireText,
        scrollController: scrollController,
      ),
    );
  }
  return showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    useRootNavigator: true, // IOS_SHELL2: above the tab bar
    isScrollControlled: true,
    showDragHandle: true,
    isDismissible: editMode,
    builder: (ctx) => _RegistrationFieldsSheet(
      fields: fields,
      answers: answers,
      editMode: editMode,
      requireText: requireText,
    ),
  );
}

class _RegistrationFieldsSheet extends StatefulWidget {
  const _RegistrationFieldsSheet({
    required this.fields,
    required this.answers,
    required this.editMode,
    required this.requireText,
    this.scrollController,
  });

  final List<RegistrationField> fields;
  final Map<String, dynamic> answers;
  final bool editMode;
  final bool requireText;

  /// Classic design: the controller of the Ionic breakpoint sheet.
  final ScrollController? scrollController;

  @override
  State<_RegistrationFieldsSheet> createState() => _RegistrationFieldsSheetState();
}

class _RegistrationFieldsSheetState extends State<_RegistrationFieldsSheet> {
  late final Map<String, dynamic> _answers = Map.of(widget.answers);
  final Map<String, TextEditingController> _controllers = {};
  String? _error;

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _controllerFor(RegistrationField field) {
    return _controllers.putIfAbsent(
      field.id,
      () => TextEditingController(text: _answers[field.id]?.toString() ?? ''),
    );
  }

  void _submit() {
    if (widget.requireText) {
      final missing = missingRegistrationField(widget.fields, _answers);
      if (missing != null) {
        setState(() => _error = context.l10n.signoutFillField(missing));
        return;
      }
    }
    Navigator.of(context).pop(_answers);
  }

  Widget _buildField(RegistrationField field) {
    switch (field.type) {
      case RegistrationFieldType.boolean:
        return SwitchListTile.adaptive(
          title: Text(field.label),
          value: _answers[field.id] == true,
          onChanged: (v) => setState(() => _answers[field.id] = v),
        );
      case RegistrationFieldType.select:
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: AppDropdownFormField<String>(
            iosInterface: AppSelectInterface.alert,
            value: (field.options ?? []).contains(_answers[field.id]) ? _answers[field.id] as String : null,
            decoration: InputDecoration(labelText: field.label, border: const OutlineInputBorder()),
            items: [
              for (final opt in field.options ?? const <String>[])
                DropdownMenuItem(value: opt, child: Text(opt)),
            ],
            onChanged: (v) => setState(() => _answers[field.id] = v ?? ''),
          ),
        );
      case RegistrationFieldType.multiSelect:
        final selected = List<String>.from(_answers[field.id] as List? ?? const []);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Text(field.label, style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
            for (final opt in field.options ?? const <String>[])
              CheckboxListTile(
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(opt),
                value: selected.contains(opt),
                onChanged: (v) => setState(() {
                  if (v == true) {
                    selected.add(opt);
                  } else {
                    selected.remove(opt);
                  }
                  _answers[field.id] = selected;
                }),
              ),
          ],
        );
      default:
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: TextField(
            controller: _controllerFor(field),
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: field.label,
              hintText: '...',
              border: const OutlineInputBorder(),
            ),
            onChanged: (v) => _answers[field.id] = v,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    // UX_SONGS_SELF: Ionic modal toolbar (title, cancel at end)
    final title = widget.editMode
        ? context.l10n.attendanceRegFields
        : context.l10n.coreFlutterRegistration;
    final end = <Widget>[
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: IonButtonLabel(context.l10n.commonCancel),
      ),
    ];
    final scrollController = widget.scrollController;
    if (scrollController != null) {
      return IonSheetScaffold(
        title: title,
        end: end,
        body: SafeArea(
          top: false,
          child: SingleChildScrollView(
            controller: scrollController,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: _rows(context),
            ),
          ),
        ),
      );
    }
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              IonSheetHeader(title: title, end: end),
              ..._rows(context),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _rows(BuildContext context) => [
              for (final f in widget.fields) _buildField(f),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(_error!, style: const TextStyle(color: AppColors.danger)),
                ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton.icon(
                  onPressed: _submit,
                  icon: Icon(AppIcons.checkCircleOutline),
                  label: IonButtonLabel(widget.editMode
                      ? context.l10n.commonSave
                      : context.l10n.signoutSignIn),
                ),
              ),
      ];
}

/// Shows the description (HTML from the Ionic editor) of a Termin.
///
/// PARITY_SELF: Ionic `#descriptionModal` (signout, overview, parents): sheet
/// with breakpoints [0, 0.6, 1] (initial 0.6), toolbar "Beschreibung" + X and
/// the formatted `quill-view` (bold, lists, tappable links).
Future<void> showEventDescriptionSheet(BuildContext context, String description) {
  if (context.rdSkin == null) {
    return showIonSheet<void>(
      context,
      breakpoints: const [0, 0.6, 1],
      initialBreakpoint: 0.6,
      builder: (ctx, scrollController) => IonSheetScaffold(
        title: ctx.l10n.signoutDescription,
        showClose: true,
        body: SingleChildScrollView(
          controller: scrollController,
          padding: EdgeInsets.fromLTRB(
              16, 8, 16, 24 + MediaQuery.paddingOf(ctx).bottom),
          child: EventDescriptionView(html: description),
        ),
      ),
    );
  }
  return showModalBottomSheet(
    context: context,
    useRootNavigator: true, // IOS_SHELL2: above the tab bar
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (ctx) => AppDraggableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.25,
      maxChildSize: 1,
      snap: true,
      snapSizes: const [0.6],
      expand: false,
      builder: (ctx, scrollController) => Column(
        children: [
          IonSheetHeader(
            title: ctx.l10n.signoutDescription,
            end: [
              IconButton(
                tooltip: ctx.l10n.commonClose,
                icon: Icon(AppIcons.close),
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ],
          ),
          Expanded(
            child: SingleChildScrollView(
              controller: scrollController,
              padding: EdgeInsets.fromLTRB(
                  16, 8, 16, 24 + MediaQuery.paddingOf(ctx).bottom),
              child: EventDescriptionView(html: description),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Read-only rendering of a Quill HTML description (Ionic `quill-view`).
class EventDescriptionView extends StatefulWidget {
  const EventDescriptionView({super.key, required this.html});

  final String html;

  @override
  State<EventDescriptionView> createState() => _EventDescriptionViewState();
}

class _EventDescriptionViewState extends State<EventDescriptionView> {
  late QuillController _controller = _build();

  QuillController _build() => QuillController(
        document: QuillUtils.documentFromNotesString(widget.html),
        selection: const TextSelection.collapsed(offset: 0),
        readOnly: true,
      );

  @override
  void didUpdateWidget(covariant EventDescriptionView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.html != widget.html) {
      _controller.dispose();
      _controller = _build();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _openLink(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    // Ionic quill-view links open in a new tab / the system browser.
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return QuillEditor.basic(
      controller: _controller,
      config: QuillEditorConfig(
        showCursor: false,
        scrollable: false,
        onLaunchUrl: _openLink,
      ),
    );
  }
}

/// Note input dialog ("Notiz für Anmeldung" / "Notiz anpassen").
Future<String?> showEventNoteDialog(
  BuildContext context, {
  required String title,
  required String confirmText,
  String initialValue = '',
}) async {
  final controller = TextEditingController(text: initialValue);
  final result = await showAppDialog<String>(
    context: context,
    builder: (ctx) => AppAlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLines: 4,
        minLines: 2,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(hintText: ctx.l10n.signoutEnterNote),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(ctx.l10n.commonCancel)),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, controller.text),
          child: Text(confirmText),
        ),
      ],
    ),
  );
  controller.dispose();
  return result;
}

/// Result of [showRegistrationFieldAlert]: [value] null = nothing chosen.
typedef RegistrationFieldAlertResult = ({dynamic value});

/// Ionic attendance.page `showRegFieldAlert`: with exactly one Anmeldefeld
/// the answer is edited in an alert with the field label as header – text
/// input (placeholder „...“), Ja/Nein radios, options as radios or (multi
/// select) checkboxes – and „Abbrechen“ / „Speichern“. Returns null when
/// cancelled.
Future<RegistrationFieldAlertResult?> showRegistrationFieldAlert(
  BuildContext context, {
  required RegistrationField field,
  dynamic existing,
}) {
  return showAppDialog<RegistrationFieldAlertResult>(
    context: context,
    builder: (_) => _RegistrationFieldAlert(field: field, existing: existing),
  );
}

class _RegistrationFieldAlert extends StatefulWidget {
  const _RegistrationFieldAlert({required this.field, this.existing});

  final RegistrationField field;
  final dynamic existing;

  @override
  State<_RegistrationFieldAlert> createState() => _RegistrationFieldAlertState();
}

class _RegistrationFieldAlertState extends State<_RegistrationFieldAlert> {
  late final TextEditingController _text =
      TextEditingController(text: widget.existing is String ? widget.existing as String : '');
  // Without a previous answer nothing is preselected ('' counts as none).
  late dynamic _single = widget.existing == '' ? null : widget.existing;
  late final Set<String> _multi = {
    if (widget.existing is List) ...(widget.existing as List).map((e) => e.toString()),
  };

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Widget _choice(String label, bool checked, VoidCallback onTap, {bool checkbox = false}) {
    final primary = Theme.of(context).colorScheme.primary;
    final icon = checkbox
        ? (checked ? AppIcons.checkBox : AppIcons.checkBoxOutlineBlank)
        : (checked ? AppIcons.radioButtonChecked : AppIcons.radioButtonUnchecked);
    // Selection state is only shown via the icon: expose it to screen readers.
    return Semantics(
      container: true,
      button: true,
      checked: checked,
      inMutuallyExclusiveGroup: !checkbox,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: ListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        leading: Icon(icon, color: checked ? primary : null),
        title: Text(label),
        onTap: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final field = widget.field;
    final l10n = context.l10n;
    Widget content;
    switch (field.type) {
      case RegistrationFieldType.text:
        content = TextField(
          controller: _text,
          autofocus: true,
          decoration: const InputDecoration(hintText: '...'),
        );
      case RegistrationFieldType.boolean:
        content = Column(mainAxisSize: MainAxisSize.min, children: [
          _choice(l10n.commonYes, _single == true, () => setState(() => _single = true)),
          _choice(l10n.commonNo, _single == false, () => setState(() => _single = false)),
        ]);
      default:
        final multi = field.type == RegistrationFieldType.multiSelect;
        content = Column(mainAxisSize: MainAxisSize.min, children: [
          for (final o in field.options ?? const <String>[])
            multi
                ? _choice(o, _multi.contains(o), () => setState(() => _multi.contains(o) ? _multi.remove(o) : _multi.add(o)),
                    checkbox: true)
                : _choice(o, _single == o, () => setState(() => _single = o)),
        ]);
    }
    return AppAlertDialog(
      title: Text(field.label),
      scrollable: true,
      content: content,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        TextButton(
          onPressed: () {
            final dynamic value = switch (field.type) {
              RegistrationFieldType.text => _text.text,
              RegistrationFieldType.multiSelect => [
                  for (final o in field.options ?? const <String>[])
                    if (_multi.contains(o)) o,
                ],
              // Nothing chosen → null, never ''.
              _ => _single == '' ? null : _single,
            };
            Navigator.of(context).pop((value: value));
          },
          child: Text(l10n.commonSave),
        ),
      ],
    );
  }
}
