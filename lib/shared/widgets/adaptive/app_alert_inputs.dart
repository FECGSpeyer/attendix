import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/redesign/rd_theme.dart';
import '../../../l10n/l10n.dart';
import 'adaptive_platform.dart';
import 'app_dialog.dart';

/// One option of an [AppAlertRadioGroup] / [AppAlertCheckboxGroup] (Ionic
/// alert input `{type: 'radio' | 'checkbox', label, value, disabled}`).
class AppAlertOption<T> {
  const AppAlertOption(
    this.value,
    this.label, {
    this.description,
    this.enabled = true,
  });

  final T value;
  final String label;

  /// Small second line (Ionic `.select-option-description`).
  final String? description;
  final bool enabled;
}

/// The `.alert-radio-group` of an Ionic alert with `type: 'radio'` inputs:
/// use it as the `content` of an [AppAlertDialog] (see [showAppRadioAlert]
/// for the ready-made alert).
///
/// - iOS: rows with the label (primary when checked) and a primary
///   checkmark at the end, a hairline above the list;
/// - md: radio circle at the start, the label after it, a line above and
///   below the list;
/// - both: the list scrolls after 240 / 266pt like Ionic's.
///
/// [message] is the alert message above the list; [footer] is shown under
/// the list on the message edge (e.g. an [AppAlertInput] for "other").
class AppAlertRadioGroup<T> extends StatelessWidget
    implements AppAlertGroupContent {
  const AppAlertRadioGroup({
    super.key,
    this.message,
    required this.options,
    required this.groupValue,
    required this.onChanged,
    this.footer,
    this.beta,
  });

  final Widget? message;
  final List<AppAlertOption<T>> options;
  final T? groupValue;
  final ValueChanged<T> onChanged;
  final Widget? footer;

  /// Beta only: the content of the dialog in the new design (default:
  /// Material radio tiles).
  final Widget? beta;

  @override
  String? get alertMessageText => switch (message) {
        final Text t => t.data,
        _ => null,
      };

  @override
  Widget build(BuildContext context) {
    if (context.rdSkin != null) {
      final beta = this.beta;
      if (beta != null) return beta;
      return SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (message != null) message!,
            for (final o in options)
              // ignore: deprecated_member_use
              RadioListTile<T>(
                value: o.value,
                // ignore: deprecated_member_use
                groupValue: groupValue,
                title: Text(o.label),
                subtitle: o.description == null ? null : Text(o.description!),
                // ignore: deprecated_member_use
                onChanged: o.enabled ? (_) => onChanged(o.value) : null,
              ),
            if (footer != null) footer!,
          ],
        ),
      );
    }
    return _AlertOptionGroup(
      message: message,
      radio: true,
      footer: footer,
      rows: [
        for (final o in options)
          _AlertOptionRow(
            radio: true,
            label: o.label,
            description: o.description,
            enabled: o.enabled,
            checked: o.value == groupValue,
            onTap: () => onChanged(o.value),
          ),
      ],
    );
  }
}

/// The `.alert-checkbox-group` of an Ionic alert with `type: 'checkbox'`
/// inputs: use it as the `content` of an [AppAlertDialog] (see
/// [showAppCheckboxAlert] for the ready-made alert).
///
/// - iOS: round checkbox at the start (primary with a white check when
///   checked), the label after it;
/// - md: square 16pt checkbox at the start, the label after it.
class AppAlertCheckboxGroup<T> extends StatelessWidget
    implements AppAlertGroupContent {
  const AppAlertCheckboxGroup({
    super.key,
    this.message,
    required this.options,
    required this.values,
    required this.onChanged,
    this.footer,
    this.beta,
  });

  final Widget? message;
  final List<AppAlertOption<T>> options;

  /// The checked values.
  final Set<T> values;

  /// Called with the option's value and its new state.
  final void Function(T value, bool checked) onChanged;
  final Widget? footer;

  /// Beta only: the content of the dialog in the new design (default:
  /// Material checkbox tiles).
  final Widget? beta;

  @override
  String? get alertMessageText => switch (message) {
        final Text t => t.data,
        _ => null,
      };

  @override
  Widget build(BuildContext context) {
    if (context.rdSkin != null) {
      final beta = this.beta;
      if (beta != null) return beta;
      return SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (message != null) message!,
            for (final o in options)
              CheckboxListTile(
                title: Text(o.label),
                subtitle: o.description == null ? null : Text(o.description!),
                value: values.contains(o.value),
                onChanged:
                    o.enabled ? (v) => onChanged(o.value, v == true) : null,
              ),
            if (footer != null) footer!,
          ],
        ),
      );
    }
    return _AlertOptionGroup(
      message: message,
      radio: false,
      footer: footer,
      rows: [
        for (final o in options)
          _AlertOptionRow(
            radio: false,
            label: o.label,
            description: o.description,
            enabled: o.enabled,
            checked: values.contains(o.value),
            onTap: () => onChanged(o.value, !values.contains(o.value)),
          ),
      ],
    );
  }
}

/// Ionic `ion-alert` with `type: 'checkbox'` inputs: title, [message], one
/// checkbox per option ([initialValues] checked), "Abbrechen" (role cancel)
/// and a confirm button. Returns the checked values, or null when cancelled
/// or dismissed.
///
/// [canChange] may veto a change (e.g. "at least one stays checked").
Future<Set<T>?> showAppCheckboxAlert<T>(
  BuildContext context, {
  String? title,
  String? message,
  required List<AppAlertOption<T>> options,
  Iterable<T> initialValues = const [],
  String? confirmText,
  String? cancelText,
  bool Function(Set<T> current, T value, bool checked)? canChange,
}) {
  final selected = {...initialValues};
  return showAppDialog<Set<T>>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) => AppAlertDialog(
        title: title == null ? null : Text(title),
        content: AppAlertCheckboxGroup<T>(
          message: message == null || message.isEmpty ? null : Text(message),
          options: options,
          values: selected,
          onChanged: (value, checked) {
            if (canChange != null && !canChange(selected, value, checked)) {
              return;
            }
            setLocal(() {
              checked ? selected.add(value) : selected.remove(value);
            });
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(cancelText ?? ctx.l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, selected),
            child: Text(confirmText ?? ctx.l10n.commonOk),
          ),
        ],
      ),
    ),
  );
}

/// Message, the bordered scrolling option list and the footer.
class _AlertOptionGroup extends StatelessWidget {
  const _AlertOptionGroup({
    required this.message,
    required this.radio,
    required this.rows,
    required this.footer,
  });

  final Widget? message;
  final bool radio;
  final List<Widget> rows;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ios = useIosLook(context);
    final dark = theme.brightness == Brightness.dark;
    // iOS: `border-top: 0.55px solid rgba(text, .2)`, `max-height: 240px`
    // (ios27: radio group `margin-bottom: 12px`); md: 1px step-150 above
    // and below, `max-height: 266px`.
    final Border border;
    if (ios) {
      border = Border(
        top: BorderSide(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
          width: 0.55,
        ),
      );
    } else {
      final line = BorderSide(
        color: dark ? const Color(0xFF363636) : const Color(0xFFD9D9D9),
      );
      border = Border(top: line, bottom: line);
    }
    final footer = this.footer;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...appAlertMessageSlot(context, message),
        Flexible(
          child: Container(
            margin: ios && radio && footer == null
                ? const EdgeInsets.only(bottom: 12)
                : null,
            constraints: BoxConstraints(maxHeight: ios ? 240 : 266),
            decoration: BoxDecoration(border: border),
            child: Semantics(
              container: true,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: rows,
                ),
              ),
            ),
          ),
        ),
        if (footer != null)
          Padding(
            padding: ios
                ? const EdgeInsets.fromLTRB(16, 0, 16, 21)
                : const EdgeInsets.fromLTRB(24, 8, 24, 12),
            child: footer,
          ),
      ],
    );
  }
}

/// One `.alert-tappable` row (`alert-radio-button` / `alert-checkbox-button`).
class _AlertOptionRow extends StatelessWidget {
  const _AlertOptionRow({
    required this.radio,
    required this.label,
    required this.description,
    required this.enabled,
    required this.checked,
    required this.onTap,
  });

  final bool radio;
  final String label;
  final String? description;
  final bool enabled;
  final bool checked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ios = useIosLook(context);
    final dark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;

    Widget labelColumn(TextStyle style) {
      final text = Text(label, style: style);
      final description = this.description;
      if (description == null || description.isEmpty) return text;
      // `.select-option-description`: 0.75rem, step-700, 5px above.
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          text,
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Text(
              description,
              style: TextStyle(
                fontSize: 12,
                color: dark ? const Color(0xFFB3B3B3) : const Color(0xFF4D4D4D),
              ),
            ),
          ),
        ],
      );
    }

    final Widget row;
    if (ios) {
      // iOS: `min-height: 44px`, label `padding: 13px`, the alert's
      // 0.875rem font (14.875pt with the 17pt iOS root font).
      final style = TextStyle(
        fontSize: 14.875,
        letterSpacing: 0,
        color: radio && checked ? primary : theme.colorScheme.onSurface,
      );
      row = ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: radio
            // ios27 `.alert-radio-group button { padding: 0 8px }`; label
            // first, the 30pt wide checkmark slot at the end.
            ? Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(13),
                        child: labelColumn(style),
                      ),
                    ),
                    SizedBox(
                      width: 30,
                      height: 24,
                      child: checked
                          ? CustomPaint(
                              painter: _CheckPainter(
                                color: primary,
                                center: const Offset(10, 11),
                                width: 6,
                                height: 12,
                              ),
                            )
                          : null,
                    ),
                  ],
                ),
              )
            // Round 22pt checkbox (`margin: 10px 6px 10px 16px`), label
            // after it.
            : Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 6, 10),
                    child: _IosCheckbox(checked: checked),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(13),
                      child: labelColumn(style),
                    ),
                  ),
                ],
              ),
      );
    } else {
      // md: `min-height: 48px`, the control 24px from the edge, the label
      // 32px after it (`padding: 13px 24px 13px 56px` next to the control),
      // 16px step-850.
      final style = TextStyle(
        fontSize: 16,
        color: dark ? const Color(0xFFD9D9D9) : const Color(0xFF262626),
      );
      final off = dark ? const Color(0xFF949494) : const Color(0xFF737373);
      row = ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Row(
          children: [
            const SizedBox(width: 24),
            if (radio)
              _MdRadio(checked: checked, color: primary, off: off)
            else
              _MdCheckbox(
                checked: checked,
                color: primary,
                off: off,
                check: theme.colorScheme.onPrimary,
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(32, 13, 24, 13),
                child: labelColumn(style),
              ),
            ),
          ],
        ),
      );
    }

    return Semantics(
      checked: checked,
      inMutuallyExclusiveGroup: radio,
      enabled: enabled,
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: InkWell(
          onTap: enabled ? onTap : null,
          // iOS: no ripple.
          splashFactory: ios ? NoSplash.splashFactory : null,
          highlightColor: ios ? IosGlass.itemActivated(theme.brightness) : null,
          hoverColor: ios ? Colors.transparent : null,
          child: row,
        ),
      ),
    );
  }
}

/// iOS `.alert-checkbox-icon`: 22pt circle, 2pt border; checked: primary
/// with a white check.
class _IosCheckbox extends StatelessWidget {
  const _IosCheckbox({required this.checked});

  final bool checked;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: checked ? primary : (dark ? Colors.black : Colors.white),
        border: Border.all(
          color: checked
              ? primary
              : (dark ? const Color(0xFF404040) : const Color(0xFFC8C7CC)),
          width: 2,
        ),
      ),
      child: checked
          ? CustomPaint(
              painter: _CheckPainter(
                color: dark ? Colors.black : Colors.white,
                // relative to the padding box (inside the 2pt border)
                center: const Offset(9.67, 8.25),
                width: 4.67,
                height: 11,
              ),
            )
          : null,
    );
  }
}

/// md `.alert-radio-icon`: 20px circle, 2px border, 10px primary dot.
class _MdRadio extends StatelessWidget {
  const _MdRadio({required this.checked, required this.color, required this.off});

  final bool checked;
  final Color color;
  final Color off;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: checked ? color : off, width: 2),
      ),
      child: AnimatedScale(
        scale: checked ? 1 : 0,
        duration: const Duration(milliseconds: 280),
        curve: const Cubic(0.4, 0, 0.2, 1),
        child: Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
      ),
    );
  }
}

/// md `.alert-checkbox-icon`: 16px square (radius 2), 2px border; checked:
/// primary with a contrast check.
class _MdCheckbox extends StatelessWidget {
  const _MdCheckbox({
    required this.checked,
    required this.color,
    required this.off,
    required this.check,
  });

  final bool checked;
  final Color color;
  final Color off;
  final Color check;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(2),
        color: checked ? color : null,
        border: Border.all(color: checked ? color : off, width: 2),
      ),
      child: checked
          ? CustomPaint(
              painter: _CheckPainter(
                color: check,
                center: const Offset(6, 5),
                width: 6,
                height: 10,
              ),
            )
          : null,
    );
  }
}

/// The CSS checkmark of the Ionic alert controls: a [width] × [height] box
/// with a 2px right and bottom border, rotated by 45°.
class _CheckPainter extends CustomPainter {
  const _CheckPainter({
    required this.color,
    required this.center,
    required this.width,
    required this.height,
  });

  final Color color;
  final Offset center;
  final double width;
  final double height;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.butt
      ..strokeJoin = StrokeJoin.miter;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(math.pi / 4);
    final right = width / 2 - 1;
    final bottom = height / 2 - 1;
    canvas.drawPath(
      Path()
        ..moveTo(right, -height / 2)
        ..lineTo(right, bottom)
        ..lineTo(-width / 2, bottom),
      paint,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CheckPainter old) =>
      old.color != color ||
      old.center != center ||
      old.width != width ||
      old.height != height;
}
