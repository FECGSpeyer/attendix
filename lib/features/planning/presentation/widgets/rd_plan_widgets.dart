import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/redesign/rd_theme.dart';
import '../../../../core/utils/plan_beamer.dart';
import '../../../../core/utils/plan_utils.dart';
import '../../../../l10n/l10n.dart';
import '../../../attendance/presentation/widgets/event/rd_form_widgets.dart' show RdFieldRow, rdInputDecoration;
import '../../../../shared/widgets/redesign/rd_widgets.dart';
import '../../../../data/models/song/song.dart';
import '../../../redesign/data/rd_collections_logic.dart';
import 'plan_export_actions.dart';
import 'plan_field_dialogs.dart';

/// REDESIGN (Termin-Werkzeuge T1): Plan dialogs and action sheets.

part 'rd_plan_field_form.dart';
part 'rd_plan_pickers.dart';

/// Bottom sheet in the Beta look: title with a close button, optional
/// subtitle, content. Follows the keyboard so text fields stay visible and
/// never grows under the status bar, so the drag handle and the close
/// button stay reachable. [footer] (usually the primary button) stays
/// pinned below the scrolling content, right above the keyboard.
Future<T?> showRdPlanSheet<T>(
  BuildContext context, {
  required String title,
  String? subtitle,
  Widget? action,
  required List<Widget> Function(BuildContext ctx, void Function(T value) pop) builder,
  Widget Function(BuildContext ctx, void Function(T value) pop)? footer,
}) {
  // Inside the sheet the status bar padding is already consumed.
  final statusBar = MediaQuery.paddingOf(context).top;
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: true,
    useSafeArea: true,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: context.rd.bg,
    builder: (ctx) {
      final p = ctx.rd;
      final mq = MediaQuery.of(ctx);
      void pop(T value) => Navigator.of(ctx).pop(value);
      // Room above the keyboard (the sheet already sits below the status
      // bar); keep a strip of the dimmed page visible so a tap outside
      // closes it too.
      final room = mq.size.height - mq.viewInsets.bottom - statusBar - 48 - kMinInteractiveDimension;
      final maxHeight = room.clamp(120.0, mq.size.height * 0.88);
      final footerWidget = footer?.call(ctx, pop);
      return Padding(
        padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
        child: SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 8, 0),
                  child: Row(
                    children: [
                      Expanded(child: Semantics(header: true, child: Text(title, style: RdType.cardTitle(p)))),
                      if (action != null) action,
                      IconButton(
                        key: const Key('rd-sheet-close'),
                        tooltip: ctx.l10n.commonClose,
                        icon: Icon(Icons.close, color: p.text2),
                        onPressed: () => Navigator.of(ctx).maybePop(),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(20, 0, 20, footerWidget == null ? 16 : 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (subtitle != null && subtitle.isNotEmpty) ...[
                          Text(subtitle, style: RdType.meta(p, size: 15)),
                          const SizedBox(height: 12),
                        ] else
                          const SizedBox(height: 8),
                        ...builder(ctx, pop),
                      ],
                    ),
                  ),
                ),
                if (footerWidget != null) Padding(padding: const EdgeInsets.fromLTRB(20, 4, 20, 12), child: footerWidget),
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// Beta replacement of [showPlanActionSheet]: one grouped list, dangerous
/// entries red and last.
Future<T?> showRdPlanActionSheet<T>(BuildContext context, {String? title, String? subtitle, required List<PlanSheetAction<T>> actions}) {
  final normal = actions.where((a) => !a.destructive).toList();
  final danger = actions.where((a) => a.destructive).toList();
  return showRdPlanSheet<T>(
    context,
    title: title ?? '',
    subtitle: subtitle,
    builder: (ctx, pop) {
      final p = ctx.rd;
      return [
        if (normal.isNotEmpty)
          RdGroupedList(
            children: [
              for (final a in normal)
                RdListRow(
                  leading: a.icon == null ? null : RdRowIcon(a.icon!),
                  title: a.label,
                  showChevron: false,
                  onTap: () => pop(a.value),
                ),
            ],
          ),
        if (danger.isNotEmpty) ...[
          const SizedBox(height: 12),
          RdGroupedList(
            children: [
              for (final a in danger)
                RdListRow(
                  leading: RdRowIcon(a.icon ?? Icons.delete_outline, color: p.absent, background: p.absentSoft),
                  title: a.label,
                  titleColor: p.absent,
                  showChevron: false,
                  onTap: () => pop(a.value),
                ),
            ],
          ),
        ],
      ];
    },
  );
}

/// Beta replacement of [showPlanTextPrompt]: one text field and a button.
Future<String?> showRdPlanTextSheet(
  BuildContext context, {
  required String title,
  String? message,
  String? initialValue,
  String? hint,
  String? confirmText,
  bool allowEmpty = false,
  String? emptyMessage,
}) {
  return showRdPlanSheet<String>(
    context,
    title: title,
    subtitle: message,
    builder:
        (ctx, pop) => [
          _RdTextPrompt(
            initialValue: initialValue,
            hint: hint,
            confirmText: confirmText ?? ctx.l10n.commonSave,
            allowEmpty: allowEmpty,
            emptyMessage: emptyMessage,
            onDone: pop,
          ),
        ],
  );
}

class _RdTextPrompt extends StatefulWidget {
  const _RdTextPrompt({
    required this.initialValue,
    required this.hint,
    required this.confirmText,
    required this.allowEmpty,
    required this.emptyMessage,
    required this.onDone,
  });

  final String? initialValue;
  final String? hint;
  final String confirmText;
  final bool allowEmpty;
  final String? emptyMessage;
  final void Function(String value) onDone;

  @override
  State<_RdTextPrompt> createState() => _RdTextPromptState();
}

class _RdTextPromptState extends State<_RdTextPrompt> {
  late final TextEditingController _controller = TextEditingController(text: widget.initialValue ?? '');
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final v = _controller.text.trim();
    if (!widget.allowEmpty && v.isEmpty) {
      setState(() => _error = widget.emptyMessage ?? context.l10n.planningEnterNamePlease);
      return;
    }
    widget.onDone(v);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RdGroupedList(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
              child: TextField(
                key: const Key('rd-plan-text-input'),
                controller: _controller,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.done,
                style: TextStyle(fontSize: 17, color: p.text),
                decoration: rdInputDecoration(p, widget.hint ?? ''),
                onSubmitted: (_) => _submit(),
              ),
            ),
          ],
        ),
        if (_error != null) ...[const SizedBox(height: 8), Text(_error!, style: TextStyle(color: p.absent, fontSize: 14))],
        const SizedBox(height: 16),
        RdPrimaryButton(label: widget.confirmText, onPressed: _submit),
      ],
    );
  }
}


/// "Beginn 19:00 · 1 Std. 20 Min · Ende 20:20" like the Termin's Ablauf
/// editor; a tap on Beginn changes the start.
class RdPlanSummaryBar extends StatelessWidget {
  const RdPlanSummaryBar({super.key, required this.time, required this.totalMinutes, this.onPickTime});

  final String time;
  final int totalMinutes;
  final VoidCallback? onPickTime;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final start = PlanUtils.parseTimeToMinutes(time);
    final end = start == null ? '' : PlanUtils.formatMinutes(start + totalMinutes);
    final rest = totalMinutes % 60;
    final duration =
        totalMinutes < 60
            ? l10n.redesignPlanMinutes(totalMinutes)
            : rest == 0
            ? l10n.redesignPlanHours(totalMinutes ~/ 60)
            : l10n.redesignPlanHoursMinutes(totalMinutes ~/ 60, rest);
    Widget part(String label, String value) => Text.rich(
      TextSpan(children: [TextSpan(text: '$label '), TextSpan(text: value, style: const TextStyle(fontWeight: FontWeight.w700))]),
      style: TextStyle(fontSize: 15, color: p.text),
    );
    return RdCard(
      padding: EdgeInsets.zero,
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: onPickTime,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                child: Row(
                  children: [
                    Flexible(child: part(l10n.redesignPlanStart, PlanUtils.formatTime(time))),
                    if (onPickTime != null) ...[const SizedBox(width: 4), Icon(Icons.edit_outlined, size: 16, color: p.link)],
                  ],
                ),
              ),
            ),
          ),
          Text(duration, style: RdType.meta(p, size: 15)),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 14, 12),
              child: Align(alignment: Alignment.centerRight, child: part(l10n.redesignPlanEnd, end)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Text row of a Beta settings card that saves on every change.
class RdPlanTextRow extends StatelessWidget {
  const RdPlanTextRow({super.key, required this.label, required this.controller, this.hint, this.onChanged});

  final String label;
  final TextEditingController controller;
  final String? hint;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    return RdFieldRow(
      label: label,
      child: TextField(
        controller: controller,
        textCapitalization: TextCapitalization.sentences,
        style: TextStyle(fontSize: 17, color: p.text),
        decoration: rdInputDecoration(p, hint ?? ''),
        onChanged: onChanged,
      ),
    );
  }
}
