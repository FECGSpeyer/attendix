import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/layout/ionic_ios.dart' as ion; // IOS_SETTINGS2

// UX_SETTINGS (WAVE 8): the settings lane renders Ionic **iOS mode** on
// iOS (iPhone app and iPhone Safari) and keeps the Material (Ionic md) look
// everywhere else. The numbers below come from @ionic/core 8 (ios) plus the
// @rdlabo/ionic-theme-ios26 structured-list layout the Ionic app loads.

/// True when the page should render the Ionic iOS look.
bool ionIsIos(BuildContext context) =>
    Theme.of(context).platform == TargetPlatform.iOS;

/// Ionic iOS metrics shared by the settings lane.
abstract final class IonIos {
  /// ios26 structured-list: `ion-list inset` margin from the screen edge.
  /// IOS_SETTINGS2: shared value (20pt), same as the auth lane.
  static const double insetMargin = ion.IonIos.insetMargin;

  /// ios26 structured-list: `ion-item-group` border radius (28pt).
  static const double groupRadius = ion.IonIos.groupRadius;

  /// ios26: `ion-item --min-height` inside inset groups (53pt).
  static const double itemMinHeight = ion.IonIos.itemMinHeight;

  /// ios26: item font size inside inset groups (17pt).
  static const double itemFontSize = ion.IonIos.itemFontSize;

  /// `ion-item --padding-start`.
  static const double itemPaddingStart = 16;

  /// ios26: native padding-right of items in inset groups (16pt).
  static const double itemPaddingEnd = ion.IonIos.itemPaddingEnd;

  /// `::slotted(ion-icon)` font-size 1.6em.
  static const double itemIconSize = 26;

  /// `::slotted(ion-icon[slot=start])` margin-inline-end.
  static const double itemIconGap = 16;

  /// Inset line start for items with a start icon (line starts at the label).
  static const double iconDividerIndent =
      itemPaddingStart + itemIconSize + itemIconGap;

  /// ion-list inset margin (16) + ion-item-group margin-bottom (16).
  static const double sectionSpacing = 32;

  /// ion-list-header min-height.
  static const double listHeaderMinHeight = 40;

  /// `--ion-color-medium-tint` (list header label colour in the ios theme).
  static const Color mediumTint = Color(0xFF9D9FA6);

  /// `ion-label p` colour (`--ion-color-step-400`).
  static Color labelP(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF8C8C8C)
          : const Color(0xFF999999);

  /// `ion-note` colour (`--ion-color-step-350`).
  static Color note(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF8C8C8C)
          : const Color(0xFFA6A6A6);

  /// ios item text colour (`--ion-text-color`).
  static Color text(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? Colors.white
          : Colors.black;

  /// ios inset line colour (`--ion-color-step-250`, #c8c7cc).
  static Color line(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF404040)
          : AppColors.dividerLight;

  /// ion-item-group background (`--ion-item-background`): white, dark #000
  /// on the #222428 grouped page (IOS_R4, variables.scss
  /// attendix-dark-theme-ios-body; settings.page.scss `ion-item-group`).
  static Color itemBackground(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? AppColors.iosInsetItemDark
          : Colors.white;

  /// `ion-card` background (`--ion-card-background`): white, dark #1c1c1d.
  static Color cardBackground(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? AppColors.surfaceDark
          : Colors.white;
}

/// IOS_SETTINGS2: horizontal page padding around inset lists — the ios26
/// inset margin (20pt) on iOS, 16 elsewhere (Ionic md).
double ionListMargin(BuildContext context) =>
    ionIsIos(context) ? IonIos.insetMargin : AppDimensions.paddingM;

/// Ionic iOS item metrics for any [ListTile]/[SwitchListTile] placed in an
/// inset group: 53pt rows, 17pt labels, 16pt insets, 26pt start icons in the
/// text colour, grey `p` lines.
Widget ionIosListTileTheme(BuildContext context, {required Widget child}) {
  // SF default tracking (Ionic sets no letter-spacing on items).
  final base = (Theme.of(context).textTheme.bodyLarge ?? const TextStyle())
      .copyWith(letterSpacing: 0);
  return ListTileTheme.merge(
    contentPadding: const EdgeInsets.only(
      left: IonIos.itemPaddingStart,
      right: IonIos.itemPaddingEnd,
    ),
    minTileHeight: IonIos.itemMinHeight,
    minVerticalPadding: 10,
    horizontalTitleGap: IonIos.itemIconGap,
    minLeadingWidth: IonIos.itemIconSize,
    iconColor: IonIos.text(context),
    titleTextStyle: base.copyWith(
      fontSize: IonIos.itemFontSize,
      height: 20.3333 / 17,
      color: IonIos.text(context),
    ),
    subtitleTextStyle: base.copyWith(
      fontSize: 14,
      height: 1.4,
      color: IonIos.labelP(context),
    ),
    leadingAndTrailingTextStyle: base.copyWith(
      fontSize: 16,
      color: IonIos.note(context),
    ),
    child: IconTheme.merge(
      data: const IconThemeData(size: IonIos.itemIconSize),
      child: child,
    ),
  );
}

/// Ionic `ion-list [inset]="true" class="category-list"` with an
/// `ion-list-header` (optional icon + label) and one item group.
///
/// Used by the settings page and its admin sub pages so they share the
/// Ionic look: grey header label above a rounded card with plain list items.
class SettingsListSection extends StatelessWidget {
  const SettingsListSection({
    super.key,
    this.title,
    this.icon,
    this.headerAction,
    required this.children,
    this.footer,
    this.dividerIndent,
    this.icons = true,
  });

  final String? title;
  final IconData? icon;

  /// Optional button at the end of the header (Ionic header "+" button).
  final Widget? headerAction;
  final List<Widget> children;

  /// Optional widget below the card (e.g. Ionic "Konto löschen" link).
  final Widget? footer;

  /// Where the inset lines between items start. Defaults to the label start
  /// of items with a start icon ([SettingsListTile]).
  final double? dividerIndent;

  /// Whether the items carry a start icon. iOS: plain items get their inset
  /// lines at the 16pt item padding instead of after the icon.
  final bool icons;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty && footer == null) return const SizedBox.shrink();
    if (ionIsIos(context)) return _buildIos(context);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.paddingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null)
            // AUDIT_R4: ionic-theme-ios27 md-ion-list-inset (structured
            // list on md): `ion-list-header` min-height 45 with the label
            // centred, label 1rem (16px) semibold, line-height 1.29rem,
            // margin 8 4 4, colour medium-tint; header padding-start 16.
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 45),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 4, 4),
                child: Row(
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 18, color: AppColors.primary),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: Text(
                        title!,
                        style: TextStyle(
                          fontSize: 16,
                          height: 1.29,
                          fontWeight: FontWeight.w600,
                          color: theme.brightness == Brightness.dark
                              ? const Color(0xFFA2A4AB)
                              : const Color(0xFF737478),
                        ),
                      ),
                    ),
                    if (headerAction != null) headerAction!,
                  ],
                ),
              ),
            ),
          if (children.isNotEmpty)
            Card(
              margin: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (var i = 0; i < children.length; i++) ...[
                    if (i > 0) Divider(height: 1, indent: dividerIndent ?? 56),
                    children[i],
                  ],
                ],
              ),
            ),
          if (footer != null) footer!,
        ],
      ),
    );
  }

  Widget _buildIos(BuildContext context) {
    final indent = dividerIndent ??
        (icons ? IonIos.iconDividerIndent : IonIos.itemPaddingStart);
    return Padding(
      padding: const EdgeInsets.only(bottom: IonIos.sectionSpacing),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null)
            IonListHeader(title: title!, icon: icon, action: headerAction),
          if (children.isNotEmpty)
            IonInsetGroup(dividerIndent: indent, children: children),
          if (footer != null) footer!,
        ],
      ),
    );
  }
}

/// Ionic iOS `ion-list-header` inside an inset list: 40pt high, label
/// (ios27: 1rem = 17pt, semibold, line-height 1.29rem, `rgba(medium, .75)`
/// – dark `.93`) at the bottom, optional primary icon.
class IonListHeader extends StatelessWidget {
  const IonListHeader({super.key, required this.title, this.icon, this.action});

  final String title;
  final IconData? icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: IonIos.listHeaderMinHeight),
      child: Padding(
        // header padding-start 16 + label margin 8 4 4
        padding: const EdgeInsets.fromLTRB(20, 8, 4, 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 19,
                color: dark ? AppColors.primaryLight : AppColors.primary,
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              // IOS27_SWEEP: shared ios27 inset list header style
              child: Text(title, style: ion.IonIos.listHeaderStyle(context)),
            ),
            // ion-list-header ion-button: small, bottom aligned.
            if (action != null)
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 32),
                child: action!,
              ),
          ],
        ),
      ),
    );
  }
}

/// Ionic iOS `ion-item-group` in an inset list: white rounded group (ios26
/// radius 28) with inset hairlines between the items.
class IonInsetGroup extends StatelessWidget {
  const IonInsetGroup({
    super.key,
    required this.children,
    this.dividerIndent = IonIos.itemPaddingStart,
    this.color,
  });

  final List<Widget> children;
  final double dividerIndent;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(IonIos.groupRadius),
      child: Material(
        color: color ?? IonIos.itemBackground(context),
        child: ionIosListTileTheme(
          context,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0)
                  // Ionic inset list: the line is the border of `.item-inner`,
                  // which starts at the label and stops at the item's native
                  // padding-end, so it is inset on both sides.
                  Divider(
                    height: 0.5,
                    thickness: 0.5,
                    indent: dividerIndent,
                    endIndent: IonIos.itemPaddingEnd,
                    color: IonIos.line(context),
                  ),
                children[i],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Ionic iOS detail chevron (`chevron-forward`, 1.25em, opacity .25).
class IonDetailChevron extends StatelessWidget {
  const IonDetailChevron({super.key, this.color});

  final Color? color;

  @override
  Widget build(BuildContext context) {
    if (!ionIsIos(context)) {
      return Icon(Icons.chevron_right, color: color ?? AppColors.medium);
    }
    return Icon(
      CupertinoIcons.chevron_forward,
      size: 20,
      color: (color ?? IonIos.text(context)).withValues(alpha: 0.25),
    );
  }
}

/// Ionic `ion-item button` with an `ion-icon slot="start"`, a label and an
/// optional note/badge at the end. [detail] shows the chevron (Ionic
/// `detail="true"`, the default for router links).
class SettingsListTile extends StatelessWidget {
  const SettingsListTile({
    super.key,
    this.icon,
    this.iconWidget,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.detail = true,
    this.color,
    this.iconColor,
    this.background,
    this.titleWidget,
  });

  final IconData? icon;

  /// Start icon drawn by a widget (Ionic ionicons without a font glyph,
  /// e.g. [IonLibraryOutlineIcon]); takes precedence over [icon].
  final Widget? iconWidget;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool detail;

  /// Label color (Ionic `ion-label color="..."`).
  final Color? color;

  /// Icon color (Ionic `ion-icon color="..."`), defaults to [color].
  final Color? iconColor;

  /// Item background (Ionic `ion-item color="danger"`).
  final Color? background;

  /// Replaces the plain [title] text (e.g. label + "NEU" badge).
  final Widget? titleWidget;

  @override
  Widget build(BuildContext context) {
    final ios = ionIsIos(context);
    final onColor = background != null ? Colors.white : null;
    final fg = onColor ?? color;
    // Ionic ios: slotted icons inherit the item text colour; md: 54 % grey.
    final iconFg =
        onColor ??
        iconColor ??
        color ??
        (ios ? IonIos.text(context) : AppColors.medium);
    final showChevron = detail && onTap != null;
    final tile = ListTile(
      leading:
          iconWidget != null
              ? IconTheme.merge(
                data: IconThemeData(
                  color: iconFg,
                  size: ios ? IonIos.itemIconSize : 24,
                ),
                child: iconWidget!,
              )
              : icon != null
              ? Icon(
                icon,
                color: iconFg,
                size: ios ? IonIos.itemIconSize : null,
              )
              : null,
      title: titleWidget ?? Text(title, style: TextStyle(color: fg)),
      subtitle:
          subtitle != null
              ? Text(
                subtitle!,
                style: TextStyle(
                  fontSize: ios ? 14 : 13,
                  color:
                      background != null
                          ? Colors.white70
                          : (ios ? IonIos.labelP(context) : AppColors.medium),
                ),
              )
              : null,
      trailing:
          (trailing != null || showChevron)
              ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (trailing != null) trailing!,
                  if (showChevron) ...[
                    if (trailing != null) SizedBox(width: ios ? 8 : 4),
                    IonDetailChevron(color: fg),
                  ],
                ],
              )
              : null,
      onTap: onTap,
    );
    if (background == null) return tile;
    return Material(color: background, child: tile);
  }
}

/// Ionic `ion-badge` used as count in settings items
/// (ios: radius 10, md: radius 4; 13px bold, padding 3/8).
class SettingsCountBadge extends StatelessWidget {
  const SettingsCountBadge(
    this.count, {
    super.key,
    this.color = AppColors.medium,
  });

  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IonBadge(
      text: '$count',
      color: color,
      textColor: AppColors.getContrastColor(color),
    );
  }
}

/// Ionic `ion-badge` (ios: radius 10, md: radius 4; 13px bold).
class IonBadge extends StatelessWidget {
  const IonBadge({
    super.key,
    required this.text,
    this.color = AppColors.primary,
    this.textColor = Colors.white,
  });

  final String text;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 26),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(ionIsIos(context) ? 10 : 4),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: textColor,
          fontSize: 13,
          height: 1,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

/// Ionic `ion-card class="marginTop"` with a big header icon and a hint
/// text (used on top of the Admins/Eltern/Beobachter lists).
class SettingsHintCard extends StatelessWidget {
  const SettingsHintCard({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final ios = ionIsIos(context);
    return IonCardBox(
      margin: const EdgeInsets.only(bottom: AppDimensions.paddingM),
      child: Padding(
        padding: EdgeInsets.all(ios ? 20 : AppDimensions.paddingM),
        child: Column(
          children: [
            // global.scss .headerIcon: 4rem, default colour
            Icon(
              icon,
              size: ios ? 64 : 40,
              color: ios ? IonIos.text(context) : AppColors.primary,
            ),
            const SizedBox(height: AppDimensions.paddingS),
            // global.scss: ion-card-content text-align center
            Text(text, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

/// Ionic `ion-note slot="end"` (ios: step-350 grey, 16px; md: 14px).
class IonNote extends StatelessWidget {
  const IonNote(this.text, {super.key, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final ios = ionIsIos(context);
    return Text(
      text,
      style: TextStyle(
        fontSize: ios ? 16 : 14,
        color: color ?? (ios ? IonIos.note(context) : AppColors.medium),
      ),
    );
  }
}

/// ios26 theme: header `ion-buttons` render as a glass pill (44pt high,
/// radius 25, translucent white, soft shadow) with text-coloured content.
class IonHeaderPill extends StatelessWidget {
  const IonHeaderPill({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fg = IonIos.text(context);
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color:
            dark
                ? const Color(0xFF2C2C2E).withValues(alpha: 0.72)
                : Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(
          color: dark ? Colors.white12 : Colors.white,
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color:
                dark
                    ? Colors.black.withValues(alpha: 0.5)
                    : const Color(0xFFDCDCDC).withValues(alpha: 0.82),
            blurRadius: 10,
          ),
        ],
      ),
      child: DefaultTextStyle.merge(
        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500, color: fg),
        child: IconTheme.merge(
          data: IconThemeData(color: fg, size: 18),
          child: Align(widthFactor: 1, child: child),
        ),
      ),
    );
  }
}

/// Ionic `ion-card` box. iOS (ios26): radius 24, shadow 0 4 16 12 %,
/// #666 14px text; md: the app's Material card.
class IonCardBox extends StatelessWidget {
  const IonCardBox({
    super.key,
    required this.child,
    this.color,
    this.margin = EdgeInsets.zero,
    this.onTap,
  });

  final Widget child;
  final Color? color;
  final EdgeInsetsGeometry margin;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (!ionIsIos(context)) {
      // PARITY_R7: Ionic md `ion-card` – 4px radius with the md elevation-2
      // shadow (the app card theme is flat with a 12px radius).
      return Card(
        margin: margin,
        color: color,
        elevation: 2,
        shadowColor: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        clipBehavior: Clip.antiAlias,
        child: onTap != null ? InkWell(onTap: onTap, child: child) : child,
      );
    }
    return Padding(
      padding: margin,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(IonIos.groupRadius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(IonIos.groupRadius),
          child: Material(
            color: color ?? IonIos.cardBackground(context),
            child: DefaultTextStyle.merge(
              style: TextStyle(
                fontSize: 14,
                color:
                    color == null
                        ? (Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFFB3B3B3)
                            : const Color(0xFF666666))
                        : null,
              ),
              child:
                  onTap != null ? InkWell(onTap: onTap, child: child) : child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Ionic `ion-item` + stacked `ion-label` + `ion-input` (+ helperText).
///
/// iOS: plain row inside the inset group — 14px label in the text colour,
/// borderless 16px input below, 12px #737373 helper. md: the app's filled
/// Material field with floating label (unchanged look).
class IonStackedField extends StatelessWidget {
  const IonStackedField({
    super.key,
    this.label,
    this.helper,
    this.hint,
    required this.builder,
    this.flush = false,
  });

  final String? label;
  final String? helper;
  final String? hint;

  /// iOS: no horizontal item padding (the parent already insets).
  final bool flush;

  /// Builds the field with the platform decoration.
  final Widget Function(InputDecoration decoration) builder;

  /// Helper/error text colour of iOS inputs (`--ion-color-step-550`).
  static const Color iosHelper = Color(0xFF737373);

  @override
  Widget build(BuildContext context) {
    if (!ionIsIos(context)) {
      return Padding(
        padding: EdgeInsets.symmetric(
          horizontal: flush ? 0 : AppDimensions.paddingM,
          vertical: AppDimensions.paddingS,
        ),
        child: builder(InputDecoration(
          labelText: label,
          helperText: helper,
          helperMaxLines: 4,
          hintText: hint,
        )),
      );
    }
    final base = (Theme.of(context).textTheme.bodyLarge ?? const TextStyle())
        .copyWith(letterSpacing: 0);
    return Padding(
      padding: flush
          ? const EdgeInsets.symmetric(vertical: 8)
          : const EdgeInsets.fromLTRB(
              IonIos.itemPaddingStart,
              10,
              IonIos.itemPaddingEnd,
              8,
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (label != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                label!,
                style: base.copyWith(fontSize: 14, color: IonIos.text(context)),
              ),
            ),
          Theme(
            // ion-input: 16px text without Material letter spacing.
            data: Theme.of(context).copyWith(
              textTheme: Theme.of(context).textTheme.copyWith(
                    bodyLarge: base.copyWith(fontSize: 16),
                    titleMedium: base.copyWith(fontSize: 16),
                  ),
            ),
            child: builder(InputDecoration(
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              filled: false,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 6),
              hintText: hint,
              hintStyle: base.copyWith(fontSize: 16, color: IonIos.note(context)),
              helperText: helper,
              helperMaxLines: 4,
              helperStyle: base.copyWith(fontSize: 12, color: iosHelper),
              errorStyle: base.copyWith(fontSize: 12, color: AppColors.danger),
            )),
          ),
        ],
      ),
    );
  }
}

/// Ionic stacked `ion-label` + read-only value (e.g. a date input that
/// opens a picker). md: a [ListTile] with the value as subtitle.
class IonStackedValue extends StatelessWidget {
  const IonStackedValue({
    super.key,
    required this.label,
    required this.value,
    this.helper,
    this.onTap,
    this.trailing,
    this.flush = false,
  });

  /// iOS: no horizontal item padding (the parent already insets).
  final bool flush;

  final String label;
  final String value;
  final String? helper;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    if (!ionIsIos(context)) {
      return ListTile(
        contentPadding: flush ? EdgeInsets.zero : null,
        title: Text(label),
        subtitle: Text(helper == null ? value : '$value\n$helper'),
        isThreeLine: helper != null,
        trailing: trailing,
        onTap: onTap,
      );
    }
    final base = (Theme.of(context).textTheme.bodyLarge ?? const TextStyle())
        .copyWith(letterSpacing: 0);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: flush
            ? const EdgeInsets.symmetric(vertical: 10)
            : const EdgeInsets.fromLTRB(
                IonIos.itemPaddingStart,
                10,
                IonIos.itemPaddingEnd,
                10,
              ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: base.copyWith(fontSize: 14, color: IonIos.text(context))),
                  const SizedBox(height: 4),
                  Text(value, style: base.copyWith(fontSize: 16, color: IonIos.text(context))),
                  if (helper != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      helper!,
                      style: base.copyWith(fontSize: 12, color: IonStackedField.iosHelper),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

/// Ionic `ion-toggle` with `helperText` as a list row: title + 12px helper.
/// The switch itself is the platform [SwitchListTile] (restyled app-wide by
/// the iOS look lane).
class IonToggleItem extends StatelessWidget {
  const IonToggleItem({
    super.key,
    required this.title,
    this.helper,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String? helper;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final ios = ionIsIos(context);
    return SwitchListTile.adaptive(
      title: Text(title),
      subtitle: helper == null
          ? null
          : Text(
              helper!,
              style: TextStyle(
                fontSize: 12,
                color: ios ? IonStackedField.iosHelper : AppColors.medium,
              ),
            ),
      value: value,
      onChanged: onChanged,
    );
  }
}

/// Ionic `ion-searchbar` in a toolbar. iOS (ios26): 60pt row, glass field
/// (44pt, radius 20, 72 % white, soft shadow) with the search icon 12pt in;
/// md: the app's filled Material field.
class IonSearchbar extends StatelessWidget {
  const IonSearchbar({
    super.key,
    required this.controller,
    required this.hint,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    void clear() {
      controller.clear();
      onChanged('');
    }

    if (!ionIsIos(context)) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(
          AppDimensions.paddingM,
          0,
          AppDimensions.paddingM,
          AppDimensions.paddingS,
        ),
        child: ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) => TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: hint,
              prefixIcon: const Icon(Icons.search),
              isDense: true,
              suffixIcon: value.text.isEmpty
                  ? null
                  : IconButton(icon: const Icon(Icons.clear), onPressed: clear),
            ),
            onChanged: onChanged,
          ),
        ),
      );
    }
    final dark = Theme.of(context).brightness == Brightness.dark;
    final grey = dark ? const Color(0xFF8E8E93) : const Color(0xFF8A8A8E);
    return SizedBox(
      height: 60,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: dark
                ? const Color(0xFF2C2C2E).withValues(alpha: 0.72)
                : Colors.white.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(20),
            border: Border(
              top: BorderSide(
                color: dark ? Colors.white12 : Colors.white,
                width: 0.5,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: dark
                    ? Colors.black.withValues(alpha: 0.5)
                    : const Color(0xFFDCDCDC).withValues(alpha: 0.82),
                blurRadius: 10,
              ),
            ],
          ),
          child: ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) => Row(
              children: [
                const SizedBox(width: 12),
                Icon(CupertinoIcons.search, size: 20, color: grey),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: controller,
                    onChanged: onChanged,
                    style: TextStyle(fontSize: 16, color: IonIos.text(context)),
                    decoration: InputDecoration(
                      hintText: hint,
                      hintStyle: TextStyle(fontSize: 16, color: grey),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                if (value.text.isNotEmpty)
                  GestureDetector(
                    onTap: clear,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Icon(
                        CupertinoIcons.clear_circled_solid,
                        size: 18,
                        color: grey,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Ionicons `library-outline` (books on a shelf), which has no
/// Material/Cupertino glyph. Drawn from the ionicons 512×512 SVG with the
/// ambient [IconTheme] colour and size.
class IonLibraryOutlineIcon extends StatelessWidget {
  const IonLibraryOutlineIcon({super.key, this.size, this.color});

  final double? size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = IconTheme.of(context);
    final s = size ?? theme.size ?? 24;
    return SizedBox.square(
      dimension: s,
      child: CustomPaint(
        painter: _IonLibraryPainter(
          color ?? theme.color ?? IonIos.text(context),
        ),
      ),
    );
  }
}

class _IonLibraryPainter extends CustomPainter {
  _IonLibraryPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 512;
    canvas.save();
    canvas.scale(k, k);
    final paint =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 32
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round;
    RRect book(double x, double y, double w, double h) =>
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, w, h),
          const Radius.circular(16),
        );
    canvas.drawRRect(book(32, 96, 64, 368), paint);
    canvas.drawRRect(book(112, 160, 128, 304), paint);
    canvas.drawRRect(book(256, 48, 96, 416), paint);
    canvas.drawLine(const Offset(112, 224), const Offset(240, 224), paint);
    canvas.drawLine(const Offset(112, 400), const Offset(240, 400), paint);
    // Tilted book (the SVG path verbatim).
    final tilted =
        Path()
          ..moveTo(422.46, 96.11)
          ..relativeLineTo(-40.4, 4.25)
          ..relativeCubicTo(-11.12, 1.17, -19.18, 11.57, -17.93, 23.1)
          ..relativeLineTo(34.92, 321.59)
          ..relativeCubicTo(1.26, 11.53, 11.37, 20, 22.49, 18.84)
          ..relativeLineTo(40.4, -4.25)
          ..relativeCubicTo(11.12, -1.17, 19.18, -11.57, 17.93, -23.1)
          ..lineTo(445, 115)
          ..relativeCubicTo(-1.31, -11.58, -11.42, -20.06, -22.54, -18.89)
          ..close();
    canvas.drawPath(tilted, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_IonLibraryPainter oldDelegate) =>
      oldDelegate.color != color;
}
