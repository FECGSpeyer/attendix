import 'package:flutter/material.dart';
import 'package:attendix/core/theme/app_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/plan_beamer.dart';
import '../../../../data/models/plan/plan.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';
import '../../../../core/theme/redesign/rd_theme.dart';
import '../../../../shared/widgets/dialogs/ion_modal.dart';
import '../../../../shared/widgets/dialogs/ion_sheet.dart' show IonSheetScaffold;
import '../../../../shared/widgets/layout/ionic_ios.dart' show IonItem;
import 'ion_items.dart' show IonInsetList, IonStackedInput;
import 'rd_plan_widgets.dart';

/// Values entered in a plan field dialog.
class PlanFieldInput {
  const PlanFieldInput({required this.name, this.conductor = '', this.info, this.minutes, this.needsBeamer});

  final String name;
  final String conductor;
  final String? info;
  final int? minutes;

  /// "Beamer-Datei nötig" switched by hand; null = follows the automatic
  /// rule. Only meaningful when the dialog showed the Beamer section.
  final bool? needsBeamer;
}

/// Beamer section of the "Feld bearbeiten" dialog (Ionic 4.17.10
/// `PlanFieldEditComponent`): only on ORG plans of orgs linked to the
/// Gemeinde App (see [PlanBeamer.active]).
class PlanFieldBeamerOptions {
  const PlanFieldBeamerOptions({this.manual, this.songId, this.file});

  /// Value switched by hand (`field.needsBeamer`); null = automatic rule.
  final bool? manual;
  final int? songId;

  /// File of the row, otherwise the one stored with its Werk.
  final BeamerFile? file;
}

/// Generic dialog for Programmpunkte, Notizen, Programmblöcke and Unterpunkte
/// (Ionic alert inputs of planning.page.ts).
///
/// Returns null when cancelled. When [onDelete] is given, a "Löschen" button is shown.
Future<PlanFieldInput?> showPlanFieldDialog(
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
}) {
  if (context.rdSkin != null) {
    return showRdPlanFieldSheet(
      context,
      title: title,
      subtitle: subtitle,
      message: message,
      nameLabel: nameLabel,
      nameHint: nameHint,
      conductorLabel: conductorLabel,
      conductorHint: conductorHint,
      infoHint: infoHint,
      confirmText: confirmText,
      emptyNameMessage: emptyNameMessage,
      initialName: initialName,
      initialConductor: initialConductor,
      initialInfo: initialInfo,
      initialMinutes: initialMinutes,
      withConductor: withConductor,
      withInfo: withInfo,
      withMinutes: withMinutes,
      requireName: requireName,
      onDelete: onDelete,
      beamer: beamer,
    );
  }
  return showAppDialog<PlanFieldInput>(
    context: context,
    builder: (ctx) => _PlanFieldDialog(
      title: title,
      subtitle: subtitle,
      message: message,
      nameLabel: nameLabel,
      nameHint: nameHint,
      conductorLabel: conductorLabel,
      conductorHint: conductorHint,
      infoHint: infoHint,
      confirmText: confirmText,
      emptyNameMessage: emptyNameMessage,
      initialName: initialName,
      initialConductor: initialConductor,
      initialInfo: initialInfo,
      initialMinutes: initialMinutes,
      withConductor: withConductor,
      withInfo: withInfo,
      withMinutes: withMinutes,
      requireName: requireName,
      onDelete: onDelete,
      beamer: beamer,
    ),
  );
}

class _PlanFieldDialog extends StatefulWidget {
  const _PlanFieldDialog({
    required this.title,
    required this.subtitle,
    required this.message,
    required this.nameLabel,
    required this.nameHint,
    required this.conductorLabel,
    required this.conductorHint,
    required this.infoHint,
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
    required this.onDelete,
    this.beamer,
  });

  final String title;
  final String? subtitle;
  final String? message;
  final String? nameLabel;
  final String? nameHint;
  final String? conductorLabel;
  final String? conductorHint;
  final String? infoHint;
  final String? confirmText;
  final String? emptyNameMessage;
  final String? initialName;
  final String? initialConductor;
  final String? initialInfo;
  final int? initialMinutes;
  final bool withConductor;
  final bool withInfo;
  final bool withMinutes;
  final bool requireName;
  final VoidCallback? onDelete;
  final PlanFieldBeamerOptions? beamer;

  @override
  State<_PlanFieldDialog> createState() => _PlanFieldDialogState();
}

class _PlanFieldDialogState extends State<_PlanFieldDialog> {
  late final TextEditingController _name = TextEditingController(text: widget.initialName ?? '');
  late final TextEditingController _conductor = TextEditingController(text: widget.initialConductor ?? '');
  late final TextEditingController _info = TextEditingController(text: widget.initialInfo ?? '');
  late final TextEditingController _minutes =
      TextEditingController(text: widget.initialMinutes?.toString() ?? '');
  String? _error;

  /// Beamer switch set by hand; null while the automatic rule applies.
  late bool? _manualBeamer = widget.beamer?.manual;

  @override
  void initState() {
    super.initState();
    // The automatic rule follows the title while typing.
    if (widget.beamer != null) _name.addListener(_onNameChanged);
  }

  void _onNameChanged() => setState(() {});

  bool get _autoBeamer => PlanBeamer.autoNeedsBeamer(name: _name.text, songId: widget.beamer?.songId);

  bool get _beamerOn => _manualBeamer ?? _autoBeamer;

  void _setBeamer(bool on) {
    if (on != _beamerOn) setState(() => _manualBeamer = on);
  }

  @override
  void dispose() {
    _name.removeListener(_onNameChanged);
    _name.dispose();
    _conductor.dispose();
    _info.dispose();
    _minutes.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    if (widget.requireName && name.isEmpty) {
      setState(() => _error = widget.emptyNameMessage ?? context.l10n.planningEnterItemPlease);
      return;
    }
    final info = _info.text.trim();
    Navigator.of(context).pop(PlanFieldInput(
      name: name,
      conductor: _conductor.text.trim(),
      info: info.isEmpty ? null : info,
      minutes: int.tryParse(_minutes.text.trim()),
      needsBeamer: widget.beamer != null ? _manualBeamer : null,
    ));
  }

  /// Ionic plan-field-edit: list "Beamer" with the switch, the linked file
  /// (when on) and the hint below.
  List<Widget> _beamerSection(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final reason = PlanBeamer.autoReason(
      name: _name.text,
      songId: widget.beamer?.songId,
      manual: _manualBeamer,
    );
    final file = widget.beamer?.file;
    final muted = theme.textTheme.bodySmall?.copyWith(color: AppColors.medium);
    return [
      const SizedBox(height: 16),
      Align(
        alignment: Alignment.centerLeft,
        child: Text(l10n.planningBeamer.toUpperCase(),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.medium)),
      ),
      SwitchListTile.adaptive(
        key: const ValueKey('plan-field-beamer-toggle'),
        contentPadding: EdgeInsets.zero,
        value: _beamerOn,
        onChanged: _setBeamer,
        title: Text(l10n.planningBeamerNeeded),
        subtitle: reason == null
            ? null
            : Text(reason.song ? l10n.planningBeamerAutoSong : l10n.planningBeamerAutoWord(reason.word ?? '')),
      ),
      if (_beamerOn)
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(AppIcons.tvOutlined, color: file != null ? AppColors.primary : AppColors.warning),
          title: Text(file?.name ?? l10n.planningBeamerNoFile),
          subtitle: Text(file != null ? l10n.planningBeamerChangeInApp : l10n.planningBeamerLinkInApp),
        ),
      Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(l10n.planningBeamerAutoHint, style: muted),
      ),
    ];
  }

  static String? _nz(String? s) => s == null || s.isEmpty ? null : s;

  /// Existing values are edited: the fields get captions.
  late final bool _editing = (widget.initialName ?? '').isNotEmpty ||
      (widget.initialConductor ?? '').isNotEmpty ||
      (widget.initialInfo ?? '').isNotEmpty;

  List<Widget> _input({
    required TextEditingController controller,
    required String caption,
    required String placeholder,
    bool autofocus = false,
    int maxLines = 1,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return [
      if (_editing && caption.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(caption, style: const TextStyle(fontSize: 12, color: AppColors.medium)),
          ),
        ),
      AppAlertInput(
        controller: controller,
        placeholder: placeholder,
        autofocus: autofocus,
        minLines: 1,
        maxLines: maxLines,
        keyboardType: keyboardType,
        textCapitalization: textCapitalization,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppAlertDialog(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.title),
          if (widget.subtitle != null)
            Text(widget.subtitle!, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
      // The Ionic `.alert-message` + `.alert-input-group` (scrolls itself).
      content: AppAlertInputGroup(
          message: widget.message == null ? null : Text(widget.message!),
          children: [
            // Ionic `alertController` inputs: no labels, only placeholders
            // (planning.page.ts addExtraField …), in the same look as every
            // other alert. While existing values are edited each field
            // keeps a small caption, otherwise nobody could tell a filled
            // "Ausführender" from "Info".
            ..._input(
              controller: _name,
              caption: widget.nameLabel ?? l10n.planningItem,
              placeholder: _nz(widget.nameHint) ?? _nz(widget.nameLabel) ?? l10n.planningEnterItem,
              autofocus: true,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
            ),
            if (widget.withConductor)
              ..._input(
                controller: _conductor,
                caption: widget.conductorLabel ?? l10n.planningPerformer,
                placeholder: _nz(widget.conductorHint) ?? _nz(widget.conductorLabel) ?? l10n.planningEnterPerformer,
                maxLines: 3,
                textCapitalization: TextCapitalization.words,
              ),
            if (widget.withInfo)
              ..._input(
                controller: _info,
                caption: l10n.planningInfo,
                placeholder: widget.infoHint ?? l10n.planningInfoOptional,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
              ),
            if (widget.withMinutes)
              ..._input(
                controller: _minutes,
                caption: l10n.planningMinutes,
                placeholder: l10n.planningMinutes,
                keyboardType: TextInputType.number,
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
            if (widget.beamer != null) ..._beamerSection(context),
          ],
      ),
      actions: [
        if (widget.onDelete != null)
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              widget.onDelete!();
            },
            child: Text(l10n.commonDelete, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(onPressed: _submit, child: Text(widget.confirmText ?? l10n.attendanceAdd)),
      ],
    );
  }
}

/// Simple text prompt (rename etc.).
Future<String?> showPlanTextPrompt(
  BuildContext context, {
  required String title,
  String? message,
  String? initialValue,
  String? hint,
  String? confirmText,
  bool allowEmpty = false,
  String? emptyMessage,
}) {
  if (context.rdSkin != null) {
    return showRdPlanTextSheet(
      context,
      title: title,
      message: message,
      initialValue: initialValue,
      hint: hint,
      confirmText: confirmText,
      allowEmpty: allowEmpty,
      emptyMessage: emptyMessage,
    );
  }
  final controller = TextEditingController(text: initialValue ?? '');
  // Ionic `alert.message = …; return false`: an empty name shows
  // [emptyMessage] in the dialog, which stays open.
  String? shownMessage = message;
  return showAppDialog<String>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AppAlertDialog(
        title: Text(title),
        content: AppAlertInputGroup(
          message: shownMessage == null ? null : Text(shownMessage!),
          children: [
            AppAlertInput(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              placeholder: hint,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(ctx.l10n.commonCancel)),
          FilledButton(
            onPressed: () {
              final v = controller.text.trim();
              if (!allowEmpty && v.isEmpty) {
                if (emptyMessage != null) setDialogState(() => shownMessage = emptyMessage);
                return;
              }
              Navigator.pop(ctx, v);
            },
            child: Text(confirmText ?? ctx.l10n.commonSave),
          ),
        ],
      ),
    ),
  );
}

/// Confirm dialog returning true on confirm.
Future<bool> showPlanConfirm(
  BuildContext context, {
  required String title,
  required String message,
  String? confirmText,
  bool destructive = false,
}) async {
  final result = await showAppDialog<bool>(
    context: context,
    builder: (ctx) => AppAlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.l10n.commonCancel)),
        FilledButton(
          style: destructive ? FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error) : null,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmText ?? ctx.l10n.commonOk),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Action sheet entry.
class PlanSheetAction<T> {
  const PlanSheetAction(this.value, this.label, {this.icon, this.destructive = false});
  final T value;
  final String label;
  final IconData? icon;
  final bool destructive;
}

/// Bottom sheet with actions (Ionic action sheet).
Future<T?> showPlanActionSheet<T>(
  BuildContext context, {
  String? title,
  String? subtitle,
  required List<PlanSheetAction<T>> actions,
  bool cancelDestructive = false,
}) {
  if (context.rdSkin != null) {
    return showRdPlanActionSheet<T>(context, title: title, subtitle: subtitle, actions: actions);
  }
  // IOS_LOOK: adaptive ion-action-sheet. ABL-11: the Ionic plan / export /
  // org-plan action sheets are text-only buttons, so the classic design
  // leaves the icons out (the Beta sheet above keeps them).
  // ABL-30: [cancelDestructive] = Ionic `{ role: 'destructive' }` cancel.
  return showAppActionSheet<T>(
    context,
    title: title,
    message: title != null ? subtitle : null,
    cancelDestructive: cancelDestructive,
    actions: [
      for (final a in actions)
        AppActionSheetAction(
          value: a.value,
          label: a.label,
          destructive: a.destructive,
        ),
    ],
  );
}

/// ABL-02: Ionic `PlanFieldEditComponent` ("Feld bearbeiten" of a
/// Programmpunkt in the editor) – an `ion-modal` page, not an alert:
/// header "Abbrechen" | title | strong "Updaten", `ion-content
/// color="light"` with one inset list (stacked Programmpunkt, Ausführender,
/// Info, Minuten) and, on ORG plans of linked orgs, the inset list "Beamer"
/// with the toggle, the file row and the hint below.
///
/// Full screen on phones, centred card from 768px ([showIonModal]). The Beta
/// keeps its sheet ([showPlanFieldDialog]). Returns null when cancelled.
Future<PlanFieldInput?> showPlanFieldEditModal(
  BuildContext context, {
  String? initialName,
  String? initialConductor,
  String? initialInfo,
  int? initialMinutes,
  PlanFieldBeamerOptions? beamer,
}) {
  if (context.rdSkin != null) {
    final l10n = context.l10n;
    return showPlanFieldDialog(
      context,
      title: l10n.planningEditField,
      nameLabel: l10n.planningItem,
      nameHint: l10n.planningEnterItem,
      infoHint: l10n.planningInfoOptionalEllipsis,
      confirmText: l10n.planningUpdate,
      initialName: initialName,
      initialConductor: initialConductor,
      initialInfo: initialInfo,
      initialMinutes: initialMinutes,
      beamer: beamer,
    );
  }
  return showIonModal<PlanFieldInput>(
    context,
    builder: (ctx) => PlanFieldEditPage(
      initialName: initialName,
      initialConductor: initialConductor,
      initialInfo: initialInfo,
      initialMinutes: initialMinutes,
      beamer: beamer,
    ),
  );
}

/// Content of [showPlanFieldEditModal] (Ionic `plan-field-edit`).
class PlanFieldEditPage extends StatefulWidget {
  const PlanFieldEditPage({
    super.key,
    this.initialName,
    this.initialConductor,
    this.initialInfo,
    this.initialMinutes,
    this.beamer,
  });

  final String? initialName;
  final String? initialConductor;
  final String? initialInfo;
  final int? initialMinutes;
  final PlanFieldBeamerOptions? beamer;

  @override
  State<PlanFieldEditPage> createState() => _PlanFieldEditPageState();
}

class _PlanFieldEditPageState extends State<PlanFieldEditPage> {
  late final TextEditingController _name = TextEditingController(text: widget.initialName ?? '');
  late final TextEditingController _conductor = TextEditingController(text: widget.initialConductor ?? '');
  late final TextEditingController _info = TextEditingController(text: widget.initialInfo ?? '');
  late final TextEditingController _minutes =
      TextEditingController(text: widget.initialMinutes?.toString() ?? '');
  bool _showNameError = false;

  /// Beamer switch set by hand; null while the automatic rule applies.
  late bool? _manualBeamer = widget.beamer?.manual;

  @override
  void initState() {
    super.initState();
    if (widget.beamer != null) _name.addListener(_onNameChanged);
  }

  void _onNameChanged() => setState(() {});

  @override
  void dispose() {
    _name.removeListener(_onNameChanged);
    _name.dispose();
    _conductor.dispose();
    _info.dispose();
    _minutes.dispose();
    super.dispose();
  }

  bool get _beamerOn =>
      _manualBeamer ?? PlanBeamer.autoNeedsBeamer(name: _name.text, songId: widget.beamer?.songId);

  void _setBeamer(bool on) {
    if (on != _beamerOn) setState(() => _manualBeamer = on);
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _showNameError = true);
      return;
    }
    final info = _info.text.trim();
    Navigator.of(context).pop(PlanFieldInput(
      name: name,
      conductor: _conductor.text.trim(),
      info: info.isEmpty ? null : info,
      minutes: int.tryParse(_minutes.text.trim()),
      needsBeamer: widget.beamer != null ? _manualBeamer : null,
    ));
  }

  List<Widget> _beamerLists(BuildContext context) {
    final l10n = context.l10n;
    final reason = PlanBeamer.autoReason(
      name: _name.text,
      songId: widget.beamer?.songId,
      manual: _manualBeamer,
    );
    final file = widget.beamer?.file;
    return [
      IonInsetList(
        header: l10n.planningBeamer,
        dividerIndent: 16,
        children: [
          SwitchListTile.adaptive(
            key: const ValueKey('plan-field-beamer-toggle'),
            value: _beamerOn,
            onChanged: _setBeamer,
            title: Text(l10n.planningBeamerNeeded),
            subtitle: reason == null
                ? null
                : Text(reason.song ? l10n.planningBeamerAutoSong : l10n.planningBeamerAutoWord(reason.word ?? '')),
          ),
          if (_beamerOn)
            IonItem(
              leading: Icon(AppIcons.tvOutlined, color: file != null ? AppColors.primary : AppColors.warning),
              title: Text(file?.name ?? l10n.planningBeamerNoFile),
              subtitle: Text(file != null ? l10n.planningBeamerChangeInApp : l10n.planningBeamerLinkInApp),
            ),
        ],
      ),
      // Ionic `p.hint` under the list.
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
        child: Text(
          l10n.planningBeamerAutoHint,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.medium),
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final narrow = !isIonModalCard(MediaQuery.sizeOf(context));
    Widget page = IonSheetScaffold(
      title: l10n.planningEditField,
      start: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.commonCancel)),
      ],
      end: [
        TextButton(
          key: const ValueKey('plan-field-edit-save'),
          onPressed: _save,
          child: Text(l10n.planningUpdate, style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
      ],
      body: ListView(
        padding: EdgeInsets.only(bottom: 16 + MediaQuery.paddingOf(context).bottom),
        children: [
          IonInsetList(
            children: [
              IonStackedInput(
                controller: _name,
                label: l10n.planningItem,
                hint: l10n.planningEnterItem,
                minLines: 1,
                maxLines: null,
                onChanged: (_) {
                  if (_showNameError) setState(() => _showNameError = false);
                },
              ),
              if (_showNameError)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Text(l10n.planningEnterItemPlease,
                      style: TextStyle(color: theme.colorScheme.error, fontSize: 14)),
                ),
              IonStackedInput(
                controller: _conductor,
                label: l10n.planningPerformer,
                hint: l10n.planningEnterPerformer,
                minLines: 1,
                maxLines: null,
              ),
              IonStackedInput(
                controller: _info,
                label: l10n.planningInfo,
                hint: l10n.planningInfoOptionalEllipsis,
                minLines: 1,
                maxLines: null,
              ),
              IonStackedInput(
                controller: _minutes,
                label: l10n.planningMinutes,
                hint: l10n.planningMinutes,
                keyboardType: TextInputType.number,
                textCapitalization: TextCapitalization.none,
              ),
            ],
          ),
          if (widget.beamer != null) ..._beamerLists(context),
        ],
      ),
    );
    page = Material(color: theme.scaffoldBackgroundColor, child: page);
    if (!narrow) return page;
    // Full-screen modal: the status bar strip takes the toolbar colour.
    return ColoredBox(
      color: theme.appBarTheme.backgroundColor ?? theme.colorScheme.surface,
      child: SafeArea(bottom: false, child: page),
    );
  }
}
