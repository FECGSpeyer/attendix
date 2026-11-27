import 'dart:async';

import 'package:flutter/material.dart';
import 'package:attendix/core/theme/app_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/design_theme.dart';
import '../../../../shared/widgets/adaptive/ion_datetime_button.dart';

/// Building blocks for inset grouped forms of the auth / registration /
/// tenant / profile screens.

/// Horizontal margin of an inset list.
double ionInsetMargin(BuildContext context) => 16;

/// Corner radius of an inset group.
double ionInsetRadius(BuildContext context) => context.rd.listRadius;

/// Label font size inside an inset item.
double ionItemFontSize(BuildContext context) => 16;

/// Grey tint used for list headers and notes.
const Color ionMediumTint = Color(0xFF9D9FA6);

/// Header above an inset group with optional leading badge and trailing button.
class IonListHeader extends StatelessWidget {
  const IonListHeader(
    this.text, {
    super.key,
    this.leading,
    this.trailing,
    this.style,
  });

  final String text;
  final Widget? leading;
  final Widget? trailing;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final rd = context.rd;
    return Padding(
      padding: EdgeInsets.fromLTRB(ionInsetMargin(context) + 4, 10, ionInsetMargin(context), 6),
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 8)],
          Expanded(
            child: Semantics(
              header: true,
              child: Text(text.toUpperCase(), style: RdType.eyebrow(rd.text2).merge(style?.copyWith(fontSize: 12))),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Rounded grouped list whose items are separated by lines.
class IonInsetGroup extends StatelessWidget {
  const IonInsetGroup({
    super.key,
    required this.children,
    this.margin,
    this.color,
  });

  final List<Widget> children;

  /// Defaults to the inset list margin left/right and 8 px below.
  final EdgeInsetsGeometry? margin;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final rd = context.rd;
    final background = color ?? rd.surface;
    final visible = children;
    return Container(
      margin: margin ??
          EdgeInsets.fromLTRB(
              ionInsetMargin(context), 0, ionInsetMargin(context), 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(ionInsetRadius(context)),
        boxShadow: rd.cardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < visible.length; i++) ...[
              if (i > 0) const IonItemDivider(),
              visible[i],
            ],
          ],
        ),
      ),
    );
  }
}

/// Hairline between two items of a group.
class IonItemDivider extends StatelessWidget {
  const IonItemDivider({super.key, this.indent = 16});

  final double indent;

  @override
  Widget build(BuildContext context) {
    return Divider(height: 1, thickness: 1, color: context.rd.line);
  }
}

/// List row: optional start slot, label (with optional subtitle),
/// optional end slot and optional chevron.
class IonItem extends StatelessWidget {
  const IonItem({
    super.key,
    this.start,
    this.label,
    this.title,
    this.subtitle,
    this.end,
    this.onTap,
    this.detail = false,
    this.labelColor,
    this.enabled = true,
    this.minHeight,
  });

  final Widget? start;

  /// Plain label text; ignored when [title] is given.
  final String? label;
  final Widget? title;
  final Widget? subtitle;
  final Widget? end;
  final VoidCallback? onTap;
  final bool detail;
  final Color? labelColor;
  final bool enabled;
  final double? minHeight;

  @override
  Widget build(BuildContext context) {
    final fontSize = ionItemFontSize(context);
    final theme = Theme.of(context);
    Widget content = Row(
      children: [
        if (start != null) ...[start!, const SizedBox(width: 16)],
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                DefaultTextStyle.merge(
                  style: TextStyle(
                    fontSize: fontSize,
                    color: labelColor ?? theme.colorScheme.onSurface,
                  ),
                  child: title ?? Text(label ?? ''),
                ),
                if (subtitle != null)
                  DefaultTextStyle.merge(
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF999999),
                    ),
                    child: subtitle!,
                  ),
              ],
            ),
          ),
        ),
        if (end != null) ...[const SizedBox(width: 8), end!],
        if (detail) ...[
          const SizedBox(width: 4),
          Icon(AppIcons.chevronRight,
              size: 22, color: AppColors.mediumOf(context).withValues(alpha: 0.6)),
        ],
      ],
    );
    content = ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight ?? 48),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: content,
      ),
    );
    if (!enabled) {
      return Opacity(opacity: 0.4, child: content);
    }
    if (onTap == null) return content;
    return InkWell(onTap: onTap, child: content);
  }
}

/// Stacked input decoration inside an inset group.
InputDecoration ionItemInputDecoration(
  BuildContext context,
  String label, {
  String? hint,
  String? helper,
  Widget? suffixIcon,
}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    helperText: helper,
    helperMaxLines: 3,
    hintStyle: TextStyle(color: AppColors.mediumOf(context).withValues(alpha: 0.75)),
    labelStyle: TextStyle(
      color: Theme.of(context).colorScheme.onSurface,
      fontSize: 16,
    ),
    floatingLabelStyle: TextStyle(
      color: Theme.of(context).colorScheme.onSurface,
      fontSize: 16,
    ),
    helperStyle: TextStyle(fontSize: 12, color: AppColors.mediumOf(context)),
    floatingLabelBehavior: FloatingLabelBehavior.always,
    filled: false,
    isDense: true,
    contentPadding: const EdgeInsets.fromLTRB(0, 6, 0, 10),
    border: InputBorder.none,
    enabledBorder: InputBorder.none,
    focusedBorder: InputBorder.none,
    errorBorder: InputBorder.none,
    focusedErrorBorder: InputBorder.none,
    disabledBorder: InputBorder.none,
    suffixIcon: suffixIcon,
  );
}

/// Text style of the value of an input inside an inset item.
TextStyle ionItemInputStyle(BuildContext context) => TextStyle(
      fontSize: ionItemFontSize(context),
      color: Theme.of(context).colorScheme.onSurface,
    );

/// Padding of an input row inside an [IonInsetGroup].
class IonInputItem extends StatelessWidget {
  const IonInputItem({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
      child: child,
    );
  }
}

/// Primary-tinted text item that acts as a button.
class IonButtonItem extends StatelessWidget {
  const IonButtonItem({
    super.key,
    required this.label,
    required this.onTap,
    this.color = AppColors.primary,
    this.icon,
    this.filled = false,
  });

  final String label;
  final VoidCallback? onTap;
  final Color color;
  final IconData? icon;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final fg = filled ? Colors.white : color;
    final item = IonItem(
      start: icon == null ? null : Icon(icon, color: fg),
      label: label,
      labelColor: fg,
      onTap: onTap,
      enabled: onTap != null,
    );
    if (!filled) return item;
    return ColoredBox(color: color, child: item);
  }
}

/// Date button chip at the end of an item.
class IonDateButton extends StatelessWidget {
  const IonDateButton({super.key, required this.text, required this.onTap});

  final String text;
  final FutureOr<void> Function()? onTap;

  @override
  Widget build(BuildContext context) => IonDatetimeButton(
        date: text,
        onDateTap: onTap,
        betaStyle: TextStyle(
          fontSize: ionItemFontSize(context),
          color: Theme.of(context).colorScheme.onSurface,
        ),
      );
}

/// Value + caret at the end of a select item.
class IonSelectValue extends StatelessWidget {
  const IonSelectValue({super.key, required this.text, this.placeholder = false});

  final String text;
  final bool placeholder;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.5),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: ionItemFontSize(context),
                color: placeholder
                    ? AppColors.mediumOf(context)
                    : Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            AppIcons.arrowDropDown,
            size: 18,
            color: AppColors.mediumOf(context),
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet list of select options with a checkmark on the current value.
Future<T?> showIonSelectOptions<T>(
  BuildContext context, {
  required String title,
  required List<(T, String)> options,
  T? selected,
}) {
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: true,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (sheetContext) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.7),
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13, color: AppColors.mediumOf(context)),
              ),
            ),
            for (final (value, label) in options)
              ListTile(
                title: Text(label),
                trailing: value == selected
                    ? Icon(AppIcons.check, color: AppColors.primary)
                    : null,
                onTap: () => Navigator.of(sheetContext).pop(value),
              ),
          ],
        ),
      ),
    ),
  );
}
