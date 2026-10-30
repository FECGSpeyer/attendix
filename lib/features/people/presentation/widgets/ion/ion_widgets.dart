// UX_PEOPLE (wave 8): building blocks that render the Ionic components used
// by the people pages the way Ionic draws them. On iOS (iPhone app and
// Flutter web in iPhone Safari) they follow Ionic's iOS mode with the
// @rdlabo/ionic-theme-ios27 1.1.0 theme the Ionic app loads in
// src/global.scss; everywhere else they follow Ionic's md mode.
//
// Values are taken from @ionic/core 9 (item/label/list-header/item-divider/
// badge *.ios.css / *.md.css; 1rem = 17px on the iPhone) and
// ionic-theme-ios27 (lines, detail icon, searchbar, fab) – IOS27_SWEEP.
import 'package:flutter/cupertino.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/redesign/rd_theme.dart';
import 'package:attendix/shared/widgets/adaptive/app_toolbar.dart' show ToolbarButtonGroup;
import 'package:attendix/shared/widgets/layout/ios_tab_bar.dart';
import 'package:attendix/shared/widgets/display/avatar.dart' show IonAvatarPlaceholder;
import 'package:attendix/shared/widgets/adaptive/adaptive_platform.dart'
    show IosGlass;
import 'package:attendix/shared/widgets/layout/ionic_ios.dart' as ios27
    show IonIos, IonDetailChevron, IonSearchbar;
import '../../../../../shared/widgets/display/ion_badge_text.dart';
import 'package:attendix/shared/widgets/layout/ionic_md.dart';
import '../../../../../shared/widgets/adaptive/ion_button_label.dart';

/// True when the page should look like Ionic's iOS mode.
bool ionIsIos(BuildContext context) =>
    Theme.of(context).platform == TargetPlatform.iOS;

bool _isDark(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark;

/// Background of an `ion-content` that holds a plain (not inset) ion-list:
/// Ionic --ion-background-color (white; dark: #000 on iOS, #121212 on md).
Color ionContentBackground(BuildContext context) {
  // Beta-Skin: rows sit on the new design's surface colour.
  final rd = context.rdSkin;
  if (rd != null) return rd.surface;
  if (!_isDark(context)) return Colors.white;
  return ionIsIos(context) ? Colors.black : const Color(0xFF121212);
}

/// Color of the inner item lines (--ion-item-border-color).
Color ionLineColor(BuildContext context) {
  final rd = context.rdSkin;
  if (rd != null) return rd.line;
  final dark = _isDark(context);
  if (ionIsIos(context)) {
    // IOS27_SWEEP: ionic-theme-ios27 `ion-list` --ion-border-color step-100.
    return ios27.IonIos.line(Theme.of(context).brightness);
  }
  return dark ? const Color(0xFF222222) : const Color(0x21000000);
}

/// Text styles of the elements inside an `ion-label`.
class IonText {
  IonText._();

  static Color _textColor(BuildContext context) =>
      Theme.of(context).colorScheme.onSurface;

  /// `<h2>`: iOS 1.0625rem (18.06pt), md 16px, normal weight.
  static TextStyle h2(BuildContext context) => TextStyle(
        fontSize: ionIsIos(context) ? ios27.IonIos.h2FontSize : 16,
        fontWeight: FontWeight.w400,
        color: _textColor(context),
        height: 1.2,
      );

  /// `<h3>`: 14px normal weight, text color.
  static TextStyle h3(BuildContext context) => TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: _textColor(context),
        height: 1.2,
      );

  /// `<p>`: iOS .875rem (14.875pt) step-400 (#999, dark #666); md 14px
  /// step-600.
  static TextStyle p(BuildContext context) {
    final rd = context.rdSkin;
    if (rd != null) return RdType.meta(rd, size: 13);
    final dark = _isDark(context);
    if (ionIsIos(context)) {
      return TextStyle(
        fontSize: ios27.IonIos.pFontSize,
        color: ios27.IonIos.labelP(Theme.of(context).brightness),
        height: 1.25,
      );
    }
    final color = dark ? const Color(0xFFA0A0A0) : const Color(0xFF666666);
    return TextStyle(fontSize: 14, color: color, height: 1.25);
  }

  /// `ion-note`: iOS max(16px, 1rem) = 17pt step-350 (#a6a6a6, dark
  /// #595959), md 14px.
  static TextStyle note(BuildContext context) {
    final rd = context.rdSkin;
    if (rd != null) return RdType.meta(rd, size: 15);
    if (ionIsIos(context)) {
      return TextStyle(
        fontSize: ios27.IonIos.noteFontSize,
        color: ios27.IonIos.note(Theme.of(context).brightness),
      );
    }
    // MD_SWEEP: md ion-note `--color: step-600` (#666666, dark #a0a0a0).
    return TextStyle(
      fontSize: IonMd.noteFontSize,
      color: IonMd.note(Theme.of(context).brightness),
    );
  }
}

/// `ion-list-header` with an `ion-label` in a plain list (iOS:
/// min(1.375rem, 56.1px) = 23.375pt bold, label margin 29 / 6; md: 14px).
class IonListHeader extends StatelessWidget {
  const IonListHeader({super.key, required this.text, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final rd = context.rdSkin;
    if (rd != null) {
      // Beta-Skin: section heading of the new design.
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 16, 8),
        child: Row(
          children: [
            Expanded(child: Semantics(header: true, child: Text(text, style: RdType.section(rd)))),
            if (trailing != null) trailing!,
          ],
        ),
      );
    }
    final ios = ionIsIos(context);
    final style = ios
        ? TextStyle(
            fontSize: 1.375 * ios27.IonIos.rem,
            fontWeight: FontWeight.w700,
            color: _isDark(context)
                ? const Color(0xFFD9D9D9)
                : const Color(0xFF262626),
          )
        : TextStyle(
            fontSize: 14,
            color: Theme.of(context).colorScheme.onSurface,
          );
    return Padding(
      padding: ios
          ? const EdgeInsets.fromLTRB(16, 29, 16, 6)
          : const EdgeInsets.fromLTRB(16, 13, 16, 10),
      child: Row(
        children: [
          Expanded(child: Text(text, style: style)),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// `ion-item-divider` (group header). With [color] it is filled with that
/// Ionic color and uses white text (color="primary").
class IonItemDivider extends StatelessWidget {
  const IonItemDivider({super.key, required this.text, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final rd = context.rdSkin;
    if (rd != null && color == null) {
      // Beta-Skin: the uppercase group label of the new design.
      return Container(
        width: double.infinity,
        color: rd.bg,
        padding: const EdgeInsets.fromLTRB(20, 14, 16, 6),
        child: Semantics(header: true, child: Text(text.toUpperCase(), style: RdType.eyebrow(rd.text2))),
      );
    }
    final ios = ionIsIos(context);
    final dark = _isDark(context);
    final background = color ??
        (ios
            ? (dark ? const Color(0xFF1A1A1A) : const Color(0xFFE6E6E6))
            : ionContentBackground(context));
    final textColor = color != null
        ? AppColors.getContrastColor(color!)
        : (ios
            ? (dark ? const Color(0xFFD9D9D9) : const Color(0xFF262626))
            // MD_SWEEP: md divider text step-400 (#999999, dark #717171).
            : IonMd.dividerText(Theme.of(context).brightness));
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(minHeight: ios ? 28 : 30),
      // MD_SWEEP: md ion-item-divider has a 1px bottom border.
      decoration: BoxDecoration(
        color: background,
        border: ios
            ? null
            : Border(
                bottom: BorderSide(
                    color: ionLineColor(context), width: IonMd.lineWidth)),
      ),
      alignment: Alignment.centerLeft,
      padding: ios
          ? const EdgeInsets.fromLTRB(16, 4, 8, 4)
          : const EdgeInsets.fromLTRB(16, 13, 16, 10),
      child: Text(
        text,
        style: TextStyle(
          // ion-item-divider (ios): min(1.0625rem, 20.4px) = 18.06pt
          fontSize: ios ? 1.0625 * ios27.IonIos.rem : 14,
          fontWeight: ios ? FontWeight.w600 : FontWeight.w400,
          color: textColor,
        ),
      ),
    );
  }
}

/// `ion-badge` with an Ionic color.
class IonBadge extends StatelessWidget {
  const IonBadge({
    super.key,
    required this.text,
    this.color = AppColors.primary,
    this.textColor,
  });

  final String text;
  final Color color;

  /// Defaults to the Ionic contrast color of [color].
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    final ios = ionIsIos(context);
    return Container(
      padding: ios
          ? const EdgeInsets.symmetric(horizontal: 8, vertical: 3)
          : const EdgeInsets.fromLTRB(4, 3, 4, 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(ios ? 10 : 4),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        // ion-badge (ios): max(13px, .8125rem) = 13.81pt; PARITY_R8:
        // real bold (700) also on the web
        style: ionBadgeTextStyle(
          fontSize: ios ? 0.8125 * ios27.IonIos.rem : 13,
          color: textColor ?? AppColors.getContrastColor(color),
        ),
      ),
    );
  }
}

/// `ion-item` inside a plain `ion-list`: optional start slot (avatar/icon),
/// the label, optional end slot, inset bottom line that starts at the label
/// (iOS) and an optional detail chevron (`detail="true"` / button items on
/// iOS).
class IonItem extends StatelessWidget {
  const IonItem({
    super.key,
    required this.child,
    this.start,
    this.end = const [],
    this.onTap,
    this.onLongPress,
    this.detail = false,
    this.lines = true,
    this.background,
    this.selected = false,
  });

  final Widget child;
  final Widget? start;
  final List<Widget> end;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool detail;
  final bool lines;
  final Color? background;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final rd = context.rdSkin;
    // Beta-Skin: rows take the iOS sizes and the new design's colours.
    final ios = rd != null || ionIsIos(context);
    final minHeight = rd != null ? 52.0 : (ios ? 44.0 : 48.0);
    // MD_SWEEP: md items use `--ion-item-background` (#fff, dark #1e1e1e).
    final bg = selected
        ? (rd?.soft ?? AppColors.primary.withValues(alpha: 0.1))
        : (background ??
            (ios
                ? ionContentBackground(context)
                : IonMd.itemBackground(Theme.of(context).brightness)));

    final inner = Container(
      constraints: BoxConstraints(minHeight: minHeight),
      decoration: lines
          ? BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: ionLineColor(context),
                  width: ios ? 0.55 : 1,
                ),
              ),
            )
          : null,
      padding: const EdgeInsets.only(right: 16),
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 10, right: 8),
              child: child,
            ),
          ),
          for (var i = 0; i < end.length; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            end[i],
          ],
          if (detail) ...[
            const SizedBox(width: 8),
            if (ios)
              const ios27.IonDetailChevron()
            else
              // MD_SWEEP: md detail icon – 20px, text colour at .25.
              Icon(
                Icons.chevron_right,
                size: 20,
                color: IonMd.text(Theme.of(context).brightness)
                    .withValues(alpha: 0.25),
              ),
          ],
        ],
      ),
    );

    return Material(
      color: bg,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        splashFactory: ios ? NoSplash.splashFactory : null,
        highlightColor: ios
            ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12)
            : null,
        child: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Row(
            children: [
              if (start != null) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: start!,
                ),
                // MD_SWEEP: md start icons keep 32px to the label.
                SizedBox(
                    width: !ios && start is Icon
                        ? IonMd.startIconGap
                        : IonMd.startGap),
              ],
              Expanded(child: inner),
            ],
          ),
        ),
      ),
    );
  }
}

/// `ion-avatar` in an item (iOS 36px, md 40px), with the Ionic
/// avatar-placeholder fallback.
class IonAvatar extends StatelessWidget {
  const IonAvatar({super.key, this.url, this.size});

  final String? url;
  final double? size;

  @override
  Widget build(BuildContext context) {
    final s = size ?? (ionIsIos(context) ? 36.0 : 40.0);
    final hasImage = url != null && url!.isNotEmpty && !url!.contains('.svg');
    // PARITY_R5: Ionic avatar-placeholder.svg (no coloured disc).
    final placeholder = IonAvatarPlaceholder(size: s);
    if (!hasImage) return placeholder;
    return ClipOval(
      // Cached: list avatars are not downloaded again on every scroll/visit.
      child: CachedNetworkImage(
        imageUrl: url!,
        width: s,
        height: s,
        fit: BoxFit.cover,
        placeholder: (_, __) => placeholder,
        errorWidget: (_, __, ___) => placeholder,
      ),
    );
  }
}

/// `ion-searchbar`. iOS: the shared ionic-theme-ios27 glass searchbar
/// ([ios27.IonSearchbar]: 8pt host padding, 44pt field, radius 22,
/// 18.06pt text). md: Ionic md searchbar look (white, shadow, radius 2).
class IonSearchbar extends StatelessWidget {
  const IonSearchbar({
    super.key,
    required this.controller,
    required this.placeholder,
    required this.onChanged,
    this.padding,
  });

  final TextEditingController controller;
  final String placeholder;
  final ValueChanged<String> onChanged;

  /// Outer padding; defaults to Ionic's host padding.
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    // Beta-Skin: the shared searchbar draws the new design's field.
    final ios = ionIsIos(context) || context.rdSkin != null;

    if (ios) {
      return Padding(
        padding: padding ?? const EdgeInsets.all(8),
        child: ios27.IonSearchbar(
          controller: controller,
          hintText: placeholder,
          onChanged: onChanged,
        ),
      );
    }
    // MD_SWEEP: the shared Ionic md searchbar (white / #121212, radius 2,
    // elevation-2 shadow, 42px, 21px step-600 icon, step-850 text).
    return IonMdSearchbar(
      controller: controller,
      hintText: placeholder,
      onChanged: onChanged,
      padding: padding ?? IonMd.searchbarPadding,
    );
  }
}

/// `ion-fab` button (vertical bottom, horizontal end). iOS: ionic-theme-ios27
/// glass button (61pt, `rgba(glass, .72)` – dark `.5` – with the light rim
/// ring, text-coloured icon); md: primary FloatingActionButton.
class IonFabButton extends StatelessWidget {
  const IonFabButton({
    super.key,
    required this.onPressed,
    this.icon = Icons.add,
    this.tooltip,
    this.heroTag,
  });

  final VoidCallback? onPressed;
  final IconData icon;
  final String? tooltip;
  final Object? heroTag;

  @override
  Widget build(BuildContext context) {
    // Beta-Skin: the themed FAB of the new design.
    if (!ionIsIos(context) || context.rdSkin != null) {
      return FloatingActionButton(
        heroTag: heroTag,
        tooltip: tooltip,
        onPressed: onPressed,
        child: Icon(icon),
      );
    }
    final dark = _isDark(context);
    final b = Theme.of(context).brightness;
    final button = Container(
      width: 61,
      height: 61,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: IosGlass.background(b, dark ? 0.5 : 0.72),
        border: Border.all(color: IosGlass.border(b), width: 0.5),
        boxShadow: IosGlass.shadow(b),
      ),
      child: Material(
        type: MaterialType.transparency,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          splashFactory: NoSplash.splashFactory,
          child: Icon(
            icon,
            size: 28,
            color: dark ? Colors.white : Colors.black,
          ),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

/// iOS `collapse="condense"` header: large title in the content that
/// collapses into the centered toolbar title on scroll.
Widget ionCondenseHeader(
  BuildContext context, {
  required String title,
  Widget? leading,
  Widget? trailing,
}) {
  final bg = ionContentBackground(context);
  return CupertinoSliverNavigationBar(
    largeTitle: Text(
      title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
    ),
    middle: Text(
      title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
    ),
    alwaysShowMiddle: false,
    leading: leading == null
        ? null
        : Material(type: MaterialType.transparency, child: leading),
    automaticallyImplyLeading: leading == null,
    trailing: trailing == null
        ? null
        : Material(
            type: MaterialType.transparency,
            // same icon color as the AppBar header buttons
            child: IconTheme.merge(
              data: Theme.of(context).appBarTheme.actionsIconTheme ??
                  const IconThemeData(),
              child: trailing,
            ),
          ),
    // IOS_SHELL2: a header button group brings its own 12pt edge margin
    // (like in the AppBar); Cupertino's 16pt bar padding would push the
    // capsule 28pt from the right.
    padding: trailing is ToolbarButtonGroup
        ? const EdgeInsetsDirectional.only(start: 16)
        : null,
    transitionBetweenRoutes: false,
    // PARITY_R5: ios27 translucent header – 20 % page colour + blur.
    backgroundColor: bg.withValues(alpha: 0.2),
    // ios26 toolbars have no hairline
    border: null,
  );
}

/// Ionic `.noDataContainer .noPersons` empty state: 80px icon, label,
/// optional grey hint and small outline buttons.
class IonNoData extends StatelessWidget {
  const IonNoData({
    super.key,
    required this.icon,
    required this.label,
    this.message,
    this.actions = const [],
  });

  final IconData icon;
  final String label;
  final String? message;

  /// (label, onPressed) pairs rendered as `ion-button size="small"
  /// fill="outline"`.
  final List<(String, VoidCallback)> actions;

  @override
  Widget build(BuildContext context) {
    final ios = ionIsIos(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 80, color: Theme.of(context).colorScheme.onSurface),
            Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
            if (message != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.medium),
                ),
              ),
            for (final (text, onPressed) in actions)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: OutlinedButton(
                  onPressed: onPressed,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    minimumSize: const Size(0, 30),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                    shape: ios
                        ? const StadiumBorder()
                        : RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  ),
                  child: IonButtonLabel(text),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Ionic `--ion-color-light` (accordion headers `ion-item color="light"`).
Color ionLightColor(BuildContext context) =>
    context.rdSkin?.bg ??
    (_isDark(context) ? const Color(0xFF222428) : const Color(0xFFF4F5F8));

/// `ion-accordion` with an `ion-item slot="header" color="light"` header
/// and the chevron toggle icon; the content follows directly below.
class IonAccordion extends StatelessWidget {
  const IonAccordion({
    super.key,
    required this.title,
    required this.expanded,
    required this.onToggle,
    required this.child,
    this.headerColor,
  });

  final String title;
  final bool expanded;
  final VoidCallback onToggle;
  final Widget child;

  /// Overrides the light header (e.g. color="danger").
  final Color? headerColor;

  @override
  Widget build(BuildContext context) {
    final ios = ionIsIos(context);
    final bg = headerColor ?? ionLightColor(context);
    final fg = headerColor != null
        ? AppColors.getContrastColor(headerColor!)
        : Theme.of(context).colorScheme.onSurface;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: bg,
          child: InkWell(
            onTap: onToggle,
            splashFactory: ios ? NoSplash.splashFactory : null,
            child: Container(
              constraints: BoxConstraints(minHeight: ios ? 44 : 48),
              padding: const EdgeInsets.only(left: 16, right: 16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: ionLineColor(context),
                    width: ios ? 0.55 : 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Text(
                        title,
                        style: TextStyle(fontSize: ios ? 17 : 16, color: fg),
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 300),
                    // IOS27_SWEEP: ion-item (ios) `::slotted(ion-icon)
                    // { font-size: 1.6em }` in the item colour.
                    child: Icon(
                      ios ? CupertinoIcons.chevron_down : Icons.expand_more,
                      size: ios ? 1.6 * ios27.IonIos.rem : 24,
                      // MD_SWEEP: md item icon rgba(text, .54).
                      color: headerColor != null || ios
                          ? fg
                          : IonMd.iconColor(Theme.of(context).brightness),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (expanded) child,
      ],
    );
  }
}

/// `ion-item` with `ion-label position="stacked"` and an input/select
/// value below it. Tapping opens the editor ([onEdit]) when [editable].
/// Signature compatible with the former EditableInfoRow ([icon] is not
/// shown, Ionic has no icons in these items).
class IonFieldRow extends StatelessWidget {
  const IonFieldRow({
    super.key,
    this.icon,
    required this.label,
    required this.value,
    this.onTap,
    this.onEdit,
    this.editable = false,
    this.highlight = false,
    this.highlightColor,
    this.subtitle,
    this.placeholder = false,
    this.trailing,
  });

  final IconData? icon;
  final String label;
  final String value;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final bool editable;

  /// Ionic `[color]="'warning'"` on the item (e.g. unconfirmed birthday).
  final bool highlight;
  final Color? highlightColor;
  final String? subtitle;

  /// Show [value] as grey placeholder text.
  final bool placeholder;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final ios = ionIsIos(context);
    final hl = highlightColor ?? AppColors.warning;
    final bg = highlight ? hl : null;
    final fg = highlight
        ? AppColors.getContrastColor(hl)
        : Theme.of(context).colorScheme.onSurface;
    final tap = editable ? onEdit : onTap;
    return Material(
      color: bg ?? Colors.transparent,
      child: InkWell(
        onTap: tap,
        splashFactory: ios ? NoSplash.splashFactory : null,
        child: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Container(
            constraints: BoxConstraints(minHeight: ios ? 68 : 72),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: ionLineColor(context),
                  width: ios ? 0.55 : 1,
                ),
              ),
            ),
            padding: const EdgeInsets.only(right: 16, top: 10, bottom: 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: ios ? 14 : 12,
                          color: ios ? fg : (highlight ? fg : AppColors.medium),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        value,
                        style: TextStyle(
                          fontSize: ios ? 17 : 16,
                          color: placeholder
                              ? fg.withValues(alpha: 0.45)
                              : (tap == null && !highlight
                                  ? fg.withValues(alpha: editable ? 1 : 0.85)
                                  : fg),
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: IonText.p(context),
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) trailing!,
                if (tap != null && trailing == null && !editable)
                  ios
                      ? const ios27.IonDetailChevron()
                      // MD_SWEEP: md detail icon – 20px, text at .25.
                      : Icon(
                          Icons.chevron_right,
                          size: 20,
                          color: IonMd.text(Theme.of(context).brightness)
                              .withValues(alpha: 0.25),
                        ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// `ion-item` with an `ion-toggle` (label left, toggle right).
/// Signature compatible with the former EditableToggleRow.
class IonToggleRow extends StatelessWidget {
  const IonToggleRow({
    super.key,
    this.icon,
    required this.label,
    required this.value,
    this.onChanged,
    this.editable = false,
    this.subtitle,
  });

  final IconData? icon;
  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool editable;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final ios = ionIsIos(context);
    return Padding(
      padding: const EdgeInsets.only(left: 16),
      child: Container(
        constraints: BoxConstraints(minHeight: ios ? 44 : 48),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: ionLineColor(context),
              width: ios ? 0.55 : 1,
            ),
          ),
        ),
        padding: const EdgeInsets.only(right: 16),
        child: Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: TextStyle(fontSize: ios ? 17 : 16)),
                    if (subtitle != null)
                      Text(subtitle!, style: IonText.p(context)),
                  ],
                ),
              ),
            ),
            Switch.adaptive(
              value: value,
              onChanged: editable ? onChanged : null,
              activeColor: AppColors.success,
            ),
          ],
        ),
      ),
    );
  }
}

/// Ionic page with `ion-header` + `ion-content fullscreen` and an iOS
/// `collapse="condense"` large title: on iOS the toolbar is a
/// [CupertinoSliverNavigationBar], elsewhere a Material [AppBar]. The
/// refresher is the platform one ([CupertinoSliverRefreshControl] /
/// [RefreshIndicator]).
class IonPage extends StatelessWidget {
  const IonPage({
    super.key,
    required this.title,
    required this.slivers,
    this.actions = const [],
    this.onRefresh,
    this.floatingActionButton,
    this.condense = true,
    this.leading,
  });

  final String title;
  final List<Widget> slivers;

  /// `ion-buttons slot="start"` (e.g. a back button with a fixed target).
  final Widget? leading;

  /// `ion-buttons slot="end"`.
  final List<Widget> actions;
  final Future<void> Function()? onRefresh;
  final Widget? floatingActionButton;

  /// False for pages without `collapse="condense"` (plain toolbar).
  final bool condense;

  @override
  Widget build(BuildContext context) {
    final ios = ionIsIos(context) && condense;
    Widget body = CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        if (ios)
          ionCondenseHeader(
            context,
            title: title,
            leading: leading,
            trailing: actions.isEmpty
                ? null
                : actions.length == 1
                    ? actions.first
                    : Row(mainAxisSize: MainAxisSize.min, children: actions),
          ),
        if (ios && onRefresh != null)
          CupertinoSliverRefreshControl(onRefresh: onRefresh),
        ...slivers,
        // IOS_SHELL2: list end above the floating tab bar (iOS shell:
        // MediaQuery padding; the FAB sits in the tab bar row).
        SliverToBoxAdapter(
            child: SizedBox(
                height: scrollEndPadding(context, base: 16, fabRoom: 80))),
      ],
    );
    if (!ios && onRefresh != null) {
      body = RefreshIndicator.adaptive(onRefresh: onRefresh!, child: body);
    }
    return Scaffold(
      backgroundColor: ionContentBackground(context),
      appBar: ios
          ? null
          : AppBar(title: Text(title), leading: leading, actions: actions),
      body: body,
      floatingActionButton: TabBarFab.wrap(floatingActionButton),
    );
  }
}

/// Wraps a form so that its Material text fields look like Ionic iOS
/// `ion-item` + `ion-label position="stacked"` + `ion-input`: no box, small
/// label above the value, inset hairline below. Elsewhere [child] keeps the
/// app's Material input theme (Ionic md mode).
class IonFormTheme extends StatelessWidget {
  const IonFormTheme({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!ionIsIos(context)) return child;
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final line = BorderSide(color: ionLineColor(context), width: 0.55);
    return Theme(
      data: theme.copyWith(
        inputDecorationTheme: InputDecorationTheme(
          filled: false,
          isDense: true,
          floatingLabelBehavior: FloatingLabelBehavior.always,
          contentPadding: const EdgeInsets.fromLTRB(0, 8, 16, 10),
          labelStyle: TextStyle(fontSize: 17, color: onSurface),
          floatingLabelStyle: TextStyle(fontSize: 17, color: onSurface),
          hintStyle: TextStyle(fontSize: 17, color: onSurface.withValues(alpha: 0.4)),
          border: UnderlineInputBorder(borderSide: line),
          enabledBorder: UnderlineInputBorder(borderSide: line),
          disabledBorder: UnderlineInputBorder(borderSide: line),
          focusedBorder: UnderlineInputBorder(borderSide: line),
          errorBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: AppColors.danger, width: 0.55),
          ),
          focusedErrorBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: AppColors.danger, width: 0.55),
          ),
        ),
      ),
      child: child,
    );
  }
}

/// `ion-list [inset]="true"`: rounded block with 16px margins (iOS radius
/// 10, md radius 2) on the item background.
class IonInsetList extends StatelessWidget {
  const IonInsetList({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final rd = context.rdSkin;
    if (rd != null) {
      // Beta-Skin: grouped list of the new design.
      return Container(
        margin: const EdgeInsets.all(16),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: rd.surface,
          borderRadius: BorderRadius.circular(rd.listRadius),
          boxShadow: rd.cardShadow,
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
      );
    }
    return Container(
      margin: const EdgeInsets.all(16),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _isDark(context)
            ? (ionIsIos(context) ? const Color(0xFF1C1C1D) : const Color(0xFF1E1E1E))
            : Colors.white,
        borderRadius: BorderRadius.circular(ionIsIos(context) ? 10 : 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}
