import 'package:flutter/material.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/theme/design_theme.dart';
import '../../../l10n/l10n.dart';

/// One button of [showAppActionSheet].
class AppActionSheetAction<T> {
  const AppActionSheetAction({
    required this.label,
    required this.value,
    this.icon,
    this.destructive = false,
    this.color,
    this.enabled = true,
    this.subtitle,
    this.selected = false,
  });

  final String label;

  /// Returned by [showAppActionSheet] when this button is tapped.
  final T value;

  final IconData? icon;

  /// Destructive actions render with the alert/danger colour.
  final bool destructive;

  /// Optional text/icon colour (e.g. a status colour). Ignored for
  /// destructive actions.
  final Color? color;

  final bool enabled;

  final String? subtitle;

  final bool selected;
}

/// Shows the app's action sheet (or an anchored popup menu on desktop when
/// [anchor] is provided).
///
/// Returns the `value` of the tapped action, or null when cancelled or
/// dismissed.
Future<T?> showAppActionSheet<T>(
  BuildContext context, {
  String? title,
  String? message,
  required List<AppActionSheetAction<T>> actions,
  String? cancelLabel,
  bool showCancel = true,
  bool cancelDestructive = false,
  bool useRootNavigator = true,
  BuildContext? anchor,
}) {
  final rd = context.rd;
  if (anchor != null && MediaQuery.sizeOf(context).width >= 840) {
    return _showRdAnchoredMenu<T>(
      anchor,
      rd,
      actions,
      useRootNavigator: useRootNavigator,
    );
  }
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: useRootNavigator,
    isScrollControlled: true,
    backgroundColor: rd.bg,
    showDragHandle: false,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (ctx) => _RdActionSheet<T>(
      title: title,
      message: message,
      actions: actions,
      cancelLabel: showCancel ? (cancelLabel ?? ctx.l10n.commonCancel) : null,
      cancelDestructive: cancelDestructive,
    ),
  );
}

/// Redesign action sheet: drag pill, header, one rounded surface card for the
/// options (icon in soft badge, muted divider, optional subtitle, destructive
/// ones red) and an outlined cancel button.
class _RdActionSheet<T> extends StatelessWidget {
  const _RdActionSheet({
    required this.title,
    required this.message,
    required this.actions,
    required this.cancelLabel,
    this.cancelDestructive = false,
  });

  final String? title;
  final String? message;
  final List<AppActionSheetAction<T>> actions;
  final String? cancelLabel;
  final bool cancelDestructive;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final rows = <Widget>[];
    for (var i = 0; i < actions.length; i++) {
      final a = actions[i];
      final color = a.destructive ? p.absent : (a.color ?? p.text);
      if (i > 0) rows.add(Divider(height: 1, thickness: 1, color: p.line));
      rows.add(InkWell(
        onTap: a.enabled ? () => Navigator.of(context).pop(a.value) : null,
        child: Opacity(
          opacity: a.enabled ? 1 : 0.4,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                children: [
                  if (a.icon != null) ...[
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: a.destructive ? p.absentSoft : p.soft,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Icon(a.icon, size: 18, color: a.destructive ? p.absent : (a.color ?? p.softText)),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(a.label, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: color)),
                        if (a.subtitle != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(a.subtitle!, style: RdType.meta(p, size: 13)),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ));
    }
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 5,
                decoration: BoxDecoration(color: p.offBorder, borderRadius: BorderRadius.circular(3)),
              ),
            ),
            const SizedBox(height: 14),
            if (title != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Semantics(header: true, child: Text(title!, style: RdType.section(p))),
              ),
            if (message != null)
              Padding(
                padding: EdgeInsets.fromLTRB(4, title != null ? 4 : 0, 4, 0),
                child: Text(message!, style: RdType.meta(p)),
              ),
            if (title != null || message != null) const SizedBox(height: 12),
            DecoratedBox(
              decoration: BoxDecoration(
                color: p.surface,
                borderRadius: BorderRadius.circular(p.listRadius),
                boxShadow: p.cardShadow,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(p.listRadius),
                child: Material(type: MaterialType.transparency, child: Column(children: rows)),
              ),
            ),
            if (cancelLabel != null) ...[
              const SizedBox(height: 10),
              SizedBox(
                height: 48,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: cancelDestructive ? p.absent : p.text,
                    backgroundColor: p.surface,
                    side: BorderSide(color: p.offBorder, width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(p.buttonRadius)),
                    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  child: Text(cancelLabel!),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

Future<T?> _showRdAnchoredMenu<T>(
  BuildContext anchor,
  RdPalette p,
  List<AppActionSheetAction<T>> actions, {
  required bool useRootNavigator,
}) {
  final box = anchor.findRenderObject()! as RenderBox;
  final overlay = Navigator.of(anchor, rootNavigator: useRootNavigator).overlay!.context.findRenderObject()! as RenderBox;
  final rect = Rect.fromPoints(
    box.localToGlobal(Offset(0, box.size.height + 6), ancestor: overlay),
    box.localToGlobal(box.size.bottomRight(const Offset(0, 6)), ancestor: overlay),
  );
  return showMenu<T>(
    context: anchor,
    useRootNavigator: useRootNavigator,
    position: RelativeRect.fromRect(rect, Offset.zero & overlay.size),
    color: p.surface,
    surfaceTintColor: Colors.transparent,
    elevation: 8,
    constraints: const BoxConstraints(minWidth: 300, maxWidth: 380),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(color: p.line),
    ),
    items: [
      for (final a in actions)
        PopupMenuItem<T>(
          value: a.value,
          enabled: a.enabled,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            children: [
              if (a.icon != null) ...[
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: a.destructive ? p.absentSoft : p.soft,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(a.icon, size: 18, color: a.destructive ? p.absent : (a.color ?? p.softText)),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      a.label,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: a.destructive ? p.absent : (a.color ?? p.text),
                      ),
                    ),
                    if (a.subtitle != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(a.subtitle!, style: RdType.meta(p, size: 13)),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
    ],
  );
}
