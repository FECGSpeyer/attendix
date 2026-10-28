import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';

// UX_SETTINGS (WAVE 8): the settings lane renders Ionic **iOS mode** on
// iOS (iPhone app and iPhone Safari) and keeps the Material (Ionic md) look
// everywhere else. The numbers below come from @ionic/core 8 (ios) plus the
// @rdlabo/ionic-theme-ios26 structured-list layout the Ionic app loads.

/// True when the page should render the Ionic iOS look.
bool ionIsIos(BuildContext context) =>
    Theme.of(context).platform == TargetPlatform.iOS;

/// Ionic iOS metrics shared by the settings lane.
abstract final class IonIos {
  /// ios26 structured-list: `ion-item-group` border radius.
  static const double groupRadius = 24;

  /// ios26: `ion-item --min-height` inside inset groups.
  static const double itemMinHeight = 52;

  /// `ion-item --padding-start`.
  static const double itemPaddingStart = 16;

  /// ios26: native padding-right of items in inset groups.
  static const double itemPaddingEnd = 18;

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

  /// ion-item-group background (`--ion-item-background`).
  static Color itemBackground(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? AppColors.surfaceDark
          : Colors.white;
}

/// Ionic iOS item metrics for any [ListTile]/[SwitchListTile] placed in an
/// inset group: 52pt rows, 16pt insets, 26pt start icons in the text
/// colour, grey `p` lines.
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
    textColor: IonIos.text(context),
    titleTextStyle: base.copyWith(
      fontSize: 16,
      height: 1.25,
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
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimensions.paddingS,
                AppDimensions.paddingXS,
                AppDimensions.paddingS,
                AppDimensions.paddingXS,
              ),
              child: Row(
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18, color: AppColors.primary),
                    const SizedBox(width: 6),
                  ],
                  Expanded(
                    child: Text(
                      title!,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: AppColors.medium,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (headerAction != null) headerAction!,
                ],
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
    final indent = dividerIndent ?? IonIos.iconDividerIndent;
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
/// (0.9rem, semibold, medium-tint) at the bottom, optional primary icon.
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
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 14.4,
                  fontWeight: FontWeight.w600,
                  color: IonIos.mediumTint,
                ),
              ),
            ),
            if (action != null) action!,
          ],
        ),
      ),
    );
  }
}

/// Ionic iOS `ion-item-group` in an inset list: white rounded group (ios26
/// radius 24) with inset hairlines between the items.
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
                  Divider(
                    height: 0.5,
                    thickness: 0.5,
                    indent: dividerIndent,
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
          icon != null
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
      return Card(
        margin: margin,
        color: color,
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
            color: color ?? IonIos.itemBackground(context),
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
