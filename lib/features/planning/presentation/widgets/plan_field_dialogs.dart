import 'package:flutter/material.dart';
import '../../../../l10n/l10n.dart';

/// Values entered in a plan field dialog.
class PlanFieldInput {
  const PlanFieldInput({required this.name, this.conductor = '', this.info, this.minutes});

  final String name;
  final String conductor;
  final String? info;
  final int? minutes;
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
}) {
  return showDialog<PlanFieldInput>(
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

  @override
  void dispose() {
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
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.title),
          if (widget.subtitle != null)
            Text(widget.subtitle!, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.message != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(widget.message!),
              ),
            TextField(
              controller: _name,
              autofocus: true,
              minLines: 1,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: widget.nameLabel ?? l10n.planningItem,
                hintText: widget.nameHint ?? l10n.planningEnterItem,
              ),
            ),
            if (widget.withConductor) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _conductor,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: widget.conductorLabel ?? l10n.planningPerformer,
                  hintText: widget.conductorHint ?? l10n.planningEnterPerformer,
                ),
              ),
            ],
            if (widget.withInfo) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _info,
                minLines: 1,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(labelText: l10n.planningInfo, hintText: widget.infoHint ?? l10n.planningInfoOptional),
              ),
            ],
            if (widget.withMinutes) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _minutes,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: l10n.planningMinutes, suffixText: l10n.planningMinPlaceholder),
              ),
            ],
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
          ],
        ),
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
}) {
  final controller = TextEditingController(text: initialValue ?? '');
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (message != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(message)),
          TextField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(hintText: hint),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(ctx.l10n.commonCancel)),
        FilledButton(
          onPressed: () {
            final v = controller.text.trim();
            if (!allowEmpty && v.isEmpty) return;
            Navigator.pop(ctx, v);
          },
          child: Text(confirmText ?? ctx.l10n.commonSave),
        ),
      ],
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
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
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
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null)
              ListTile(
                title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: subtitle != null ? Text(subtitle) : null,
              ),
            for (final a in actions)
              ListTile(
                leading: a.icon != null
                    ? Icon(a.icon, color: a.destructive ? Theme.of(ctx).colorScheme.error : null)
                    : null,
                title: Text(
                  a.label,
                  style: a.destructive ? TextStyle(color: Theme.of(ctx).colorScheme.error) : null,
                ),
                onTap: () => Navigator.pop(ctx, a.value),
              ),
            ListTile(
              title: Text(ctx.l10n.commonCancel, textAlign: TextAlign.center),
              onTap: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    ),
  );
}
