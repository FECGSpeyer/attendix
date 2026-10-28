import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// UX_AUTH: building blocks for the Ionic `ion-list [inset]="true"` forms of
/// the auth / registration / tenant / profile screens.
///
/// The Ionic app runs with the rdlabo iOS 26 theme on the iPhone (inset
/// groups 20 px from the screen edge, 28 px corners, 53 px rows, 17 px text)
/// and with the MD inset list elsewhere (16 px margin, 16 px corners).

/// True when the app renders the Ionic iOS mode (iPhone app and Flutter web
/// in iPhone Safari).
bool ionIsIos(BuildContext context) =>
    Theme.of(context).platform == TargetPlatform.iOS;

/// Horizontal margin of an inset list (`ion-list [inset]`).
double ionInsetMargin(BuildContext context) => ionIsIos(context) ? 20 : 16;

/// Corner radius of an inset group.
double ionInsetRadius(BuildContext context) => ionIsIos(context) ? 28 : 16;

/// `ion-label` font size inside an inset item (17 px on iOS, 16 px in MD).
double ionItemFontSize(BuildContext context) => ionIsIos(context) ? 17 : 16;

/// `ion-color-medium-tint` used for list headers and notes.
const Color ionMediumTint = Color(0xFF9D9FA6);

/// `ion-list-header` above an inset group: small medium-grey label
/// (0.9rem) with optional leading badge and trailing button.
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

  /// Page-specific override (e.g. register.page.scss: 1rem / 600).
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final base = TextStyle(fontSize: 14.4, color: ionMediumTint);
    return Padding(
      padding: EdgeInsets.fromLTRB(
          ionInsetMargin(context) + 4, 8, ionInsetMargin(context), 4),
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 10)],
          Expanded(child: Text(text, style: base.merge(style))),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// One `ion-item-group` of an inset list: white rounded block whose items are
/// separated by hairlines that start at the label (16 px inset).
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
    final theme = Theme.of(context);
    final background =
        color ?? theme.cardTheme.color ?? theme.colorScheme.surface;
    final visible = children;
    return Container(
      margin: margin ??
          EdgeInsets.fromLTRB(
              ionInsetMargin(context), 0, ionInsetMargin(context), 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(ionInsetRadius(context)),
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

/// Inset hairline between two items of a group.
class IonItemDivider extends StatelessWidget {
  const IonItemDivider({super.key, this.indent = 16});

  final double indent;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Divider(
      height: 0.5,
      thickness: 0.5,
      indent: indent,
      color: dark ? AppColors.dividerDark : AppColors.dividerLight,
    );
  }
}

/// `ion-item` row: optional start slot, label (with optional `p` line),
/// optional end slot and the iOS detail chevron.
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

  /// Ionic `detail`: chevron at the end (iOS only, like Ionic).
  final bool detail;

  /// `ion-label color="primary"` etc.
  final Color? labelColor;
  final bool enabled;
  final double? minHeight;

  @override
  Widget build(BuildContext context) {
    final ios = ionIsIos(context);
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
                    // ion-label p: 0.875rem, step-600 grey
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
        if (detail && ios) ...[
          const SizedBox(width: 4),
          Icon(Icons.chevron_right,
              size: 22, color: AppColors.medium.withValues(alpha: 0.6)),
        ],
      ],
    );
    content = ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight ?? (ios ? 53 : 48)),
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

/// `ion-item` + `ion-input labelPlacement="stacked"` inside an inset group:
/// small label above the value, no field border (the group draws the lines),
/// optional helper text / counter below.
InputDecoration ionItemInputDecoration(
  BuildContext context,
  String label, {
  String? hint,
  String? helper,
  Widget? suffixIcon,
}) {
  final ios = ionIsIos(context);
  return InputDecoration(
    labelText: label,
    hintText: hint,
    helperText: helper,
    helperMaxLines: 3,
    hintStyle: TextStyle(color: AppColors.medium.withValues(alpha: 0.75)),
    // Stacked label: 0.875rem (iOS) / 16px scaled to .75 (MD); the input
    // stretches the label to Flutter's floating size, so set the final size.
    labelStyle: TextStyle(
      color: Theme.of(context).colorScheme.onSurface,
      fontSize: ios ? 14 / 0.75 : 16,
    ),
    floatingLabelStyle: TextStyle(
      color: Theme.of(context).colorScheme.onSurface,
      fontSize: ios ? 14 / 0.75 : 16,
    ),
    helperStyle: const TextStyle(fontSize: 12, color: AppColors.medium),
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

/// Text style of the value of an `ion-input` inside an inset item.
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

/// Primary-tinted text item that acts as a button (`ion-item button`
/// with `ion-label color="primary"`).
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

  /// `ion-item color="primary"`: primary background, white text.
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
