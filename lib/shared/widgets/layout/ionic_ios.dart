import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../adaptive/adaptive_platform.dart';

/// Page building blocks that mirror Ionic components as they render in
/// **iOS mode** (iPhone app and iPhone Safari PWA, @rdlabo ionic-theme-ios26)
/// while keeping the Material look on Android / desktop (Ionic md mode).
///
/// UX_SONGS_SELF (wave 8): used by the songs, self-service, parents and
/// public link pages. `ion-segment` lives in the shared adaptive helpers
/// ([IonSegment] in `adaptive/app_segmented_button.dart`).

/// True when the app runs with the iOS look (Ionic `mode="ios"`).
/// Same as the shared adaptive [useIosLook].
bool isIosLook(BuildContext context) => useIosLook(context);

/// Ionic iOS metrics (ionic-theme-ios26).
class IonIos {
  IonIos._();

  /// `ion-list inset > ion-item-group` corner radius.
  static const double groupRadius = 24;

  /// `ion-list inset` without item group (plain inset list, Ionic core).
  static const double listRadius = 10;

  /// `ion-item` min height inside inset lists.
  static const double itemMinHeight = 52;

  /// `--ion-color-medium-tint`
  static const Color mediumTint = Color(0xFF9D9FA6);

  /// `ion-title size="large"`: 34px bold.
  static const TextStyle largeTitle = TextStyle(
    fontSize: 34,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.37,
    height: 1.2,
  );
}

/// Ionic `ion-header collapse="condense"`: on iOS the page shows a large
/// title at the top of the content ([IonLargeTitle]) and the toolbar title
/// only fades in once the large title has scrolled away. The toolbar is
/// transparent (no hairline) while the large title is visible.
///
/// On non-iOS platforms the toolbar title is always shown (Ionic md mode
/// hides the condensed header).
class CondenseHeader extends StatefulWidget {
  const CondenseHeader({super.key, required this.builder, this.enabled = true});

  /// Builds the page. `condensed` is true when the toolbar title should be
  /// visible (always true on non-iOS or when [enabled] is false).
  final Widget Function(BuildContext context, bool condensed) builder;

  /// Ionic shows the condensed header only in some states (e.g. not when the
  /// toolbar holds the tenant switcher).
  final bool enabled;

  @override
  State<CondenseHeader> createState() => _CondenseHeaderState();
}

class _CondenseHeaderState extends State<CondenseHeader> {
  static const double _threshold = 40;
  bool _condensed = false;

  bool _onScroll(ScrollNotification n) {
    if (n.metrics.axis != Axis.vertical || n.depth != 0) return false;
    final condensed = n.metrics.pixels > _threshold;
    if (condensed != _condensed) setState(() => _condensed = condensed);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled || !isIosLook(context)) {
      return widget.builder(context, true);
    }
    return NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: widget.builder(context, _condensed),
    );
  }
}

/// Toolbar title that fades in when the large title is condensed.
class CondenseTitle extends StatelessWidget {
  const CondenseTitle({
    super.key,
    required this.condensed,
    required this.child,
  });

  final bool condensed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: condensed ? 1 : 0,
      duration: const Duration(milliseconds: 150),
      child: child,
    );
  }
}

/// App bar background for a condense header: transparent (page background)
/// while the large title is visible, otherwise the theme default.
Color? condenseBarColor(BuildContext context, bool condensed) {
  if (condensed || !isIosLook(context)) return null;
  return Theme.of(context).scaffoldBackgroundColor;
}

/// App bar shape for a condense header: no hairline while the large title is
/// visible, otherwise the theme default.
ShapeBorder? condenseBarShape(BuildContext context, bool condensed) {
  if (condensed || !isIosLook(context)) return null;
  return const Border();
}

/// Ionic `ion-title size="large"` inside `ion-header collapse="condense"`.
/// Renders nothing outside iOS.
class IonLargeTitle extends StatelessWidget {
  const IonLargeTitle(this.title, {super.key, this.enabled = true});

  final String title;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (!enabled || !isIosLook(context)) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
      child: Text(
        title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: IonIos.largeTitle.copyWith(
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }
}

/// Ionic `ion-searchbar`. iOS: rounded glass pill (44px, radius 20) with the
/// search icon on the left; Material: the dense outlined text field.
class IonSearchbar extends StatelessWidget {
  const IonSearchbar({
    super.key,
    required this.controller,
    required this.hintText,
    required this.onChanged,
    this.onClear,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onChanged;
  final VoidCallback? onClear;

  void _clear() {
    controller.clear();
    onChanged('');
    onClear?.call();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final hasText = value.text.isNotEmpty;
        if (!isIosLook(context)) {
          return TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: hintText,
              prefixIcon: const Icon(Icons.search),
              isDense: true,
              suffixIcon:
                  hasText
                      ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: _clear,
                      )
                      : null,
            ),
            onChanged: onChanged,
          );
        }
        final dark = Theme.of(context).brightness == Brightness.dark;
        final iconColor =
            dark ? const Color(0x99EBEBF5) : const Color(0x993C3C43);
        return Container(
          height: 44,
          decoration: BoxDecoration(
            color:
                dark
                    ? const Color(0xFF1C1C1E)
                    : Colors.white.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: dark ? const Color(0x22FFFFFF) : Colors.white,
              width: 0.5,
            ),
            boxShadow:
                dark
                    ? null
                    : const [
                      BoxShadow(color: Color(0xD1DCDCDC), blurRadius: 10),
                    ],
          ),
          child: Row(
            children: [
              const SizedBox(width: 12),
              Icon(Icons.search, size: 20, color: iconColor),
              const SizedBox(width: 6),
              Expanded(
                child: TextField(
                  controller: controller,
                  onChanged: onChanged,
                  style: const TextStyle(fontSize: 17),
                  textAlignVertical: TextAlignVertical.center,
                  decoration: InputDecoration(
                    hintText: hintText,
                    hintStyle: TextStyle(color: iconColor, fontSize: 17),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    isCollapsed: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              if (hasText)
                GestureDetector(
                  onTap: _clear,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Icon(Icons.cancel, size: 18, color: iconColor),
                  ),
                )
              else
                const SizedBox(width: 12),
            ],
          ),
        );
      },
    );
  }
}

/// Ionic `ion-list-header` inside an inset list.
/// iOS (theme ios26): 0.9rem bold, medium tint, 20px from the screen edge.
class IonListHeader extends StatelessWidget {
  const IonListHeader(this.label, {super.key, this.trailing, this.color});

  final String label;
  final List<Widget>? trailing;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final ios = isIosLook(context);
    final style =
        ios
            ? TextStyle(
              fontSize: 14.4,
              fontWeight: FontWeight.w700,
              color: color ?? IonIos.mediumTint,
            )
            : Theme.of(context).textTheme.labelLarge?.copyWith(
              color: color ?? AppColors.medium,
              fontWeight: FontWeight.w600,
            );
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        ios ? 12 : 16,
        trailing == null ? 20 : 8,
        4,
      ),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          // Ionic `ion-button fill="clear"` in the header: primary icons.
          if (trailing != null)
            _PrimaryIconButtons(
              child: Row(mainAxisSize: MainAxisSize.min, children: trailing!),
            ),
        ],
      ),
    );
  }
}

/// Ionic `ion-list [inset]="true"` (with `ion-item-group` when [grouped]):
/// a rounded surface with 16px margin and inset hairlines between rows.
class IonInsetList extends StatelessWidget {
  const IonInsetList({
    super.key,
    required this.children,
    this.grouped = true,
    this.dividerIndent = 16,
    this.margin = const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    this.color,
    this.border,
  });

  final List<Widget> children;
  final bool grouped;
  final double dividerIndent;
  final EdgeInsetsGeometry margin;
  final Color? color;
  final BoxBorder? border;

  static double radiusOf(BuildContext context, {bool grouped = true}) {
    if (!isIosLook(context)) return 12;
    return grouped ? IonIos.groupRadius : IonIos.listRadius;
  }

  @override
  Widget build(BuildContext context) {
    final radius = radiusOf(context, grouped: grouped);
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        rows.add(Divider(height: 0.5, thickness: 0.5, indent: dividerIndent));
      }
      rows.add(children[i]);
    }
    return Container(
      margin: margin,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: color ?? Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(radius),
        border: border,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: rows,
        ),
      ),
    );
  }
}

/// Ionic `ion-item` row inside an [IonInsetList]: min height 52 on iOS,
/// optional detail chevron (Ionic `detail` / button items on iOS).
class IonItem extends StatelessWidget {
  const IonItem({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.detail = false,
    this.titleColor,
  });

  final Widget? leading;
  final Widget title;
  final Widget? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  /// Shows the iOS detail chevron (Ionic `detail="true"`).
  final bool detail;
  final Color? titleColor;

  @override
  Widget build(BuildContext context) {
    final ios = isIosLook(context);
    final chevron = ios && detail && onTap != null;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: ios ? IonIos.itemMinHeight : 48),
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 8, ios ? 18 : 16, 8),
          child: Row(
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 16)],
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DefaultTextStyle.merge(
                      style: TextStyle(
                        fontSize: ios ? 17 : 16,
                        color: titleColor,
                      ),
                      child: title,
                    ),
                    if (subtitle != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: DefaultTextStyle.merge(
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.medium,
                          ),
                          child: subtitle!,
                        ),
                      ),
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 8), trailing!],
              if (chevron) ...[
                const SizedBox(width: 6),
                Icon(
                  Icons.chevron_right,
                  size: 22,
                  color: AppColors.medium.withValues(alpha: 0.6),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Toolbar of an Ionic sheet modal (`ion-modal` > `ion-header` >
/// `ion-toolbar`): title centered on iOS (start-aligned in md mode) with
/// optional start / end buttons.
class IonSheetHeader extends StatelessWidget {
  const IonSheetHeader({
    super.key,
    required this.title,
    this.start = const [],
    this.end = const [],
  });

  final String title;
  final List<Widget> start;
  final List<Widget> end;

  @override
  Widget build(BuildContext context) {
    final ios = isIosLook(context);
    final titleWidget = Text(
      title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: ios ? TextAlign.center : TextAlign.start,
      style: TextStyle(
        fontSize: ios ? 17 : 20,
        fontWeight: ios ? FontWeight.w600 : FontWeight.w500,
        color: Theme.of(context).colorScheme.onSurface,
      ),
    );
    final header = Container(
      height: 56,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        // Matches the bottom sheet's rounded top corners.
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: _PrimaryIconButtons(
        child: ios
            ? Stack(
                alignment: Alignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 96),
                    child: titleWidget,
                  ),
                  Positioned(
                    left: 4,
                    top: 0,
                    bottom: 0,
                    child: Row(mainAxisSize: MainAxisSize.min, children: start),
                  ),
                  Positioned(
                    right: 4,
                    top: 0,
                    bottom: 0,
                    child: Row(mainAxisSize: MainAxisSize.min, children: end),
                  ),
                ],
              )
            : Row(
                children: [
                  if (start.isEmpty) const SizedBox(width: 16) else ...start,
                  Expanded(child: titleWidget),
                  ...end,
                  const SizedBox(width: 4),
                ],
              ),
      ),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [header, const Divider(height: 0.5, thickness: 0.5)],
    );
  }
}

/// Input decoration of an Ionic `ion-item` with `ion-label position="stacked"`
/// / `labelPlacement="stacked"`. iOS: label above a borderless input with an
/// inset hairline below the item; Material: the theme's filled field.
InputDecoration ionInputDecoration(
  BuildContext context, {
  required String label,
  String? helperText,
  String? hintText,
}) {
  if (!isIosLook(context)) {
    return InputDecoration(
      labelText: label,
      helperText: helperText,
      helperMaxLines: helperText == null ? null : 2,
      hintText: hintText,
    );
  }
  final hairline = BorderSide(color: Theme.of(context).dividerColor, width: 0.5);
  return InputDecoration(
    labelText: label,
    helperText: helperText,
    helperMaxLines: helperText == null ? null : 3,
    hintText: hintText,
    filled: false,
    floatingLabelBehavior: FloatingLabelBehavior.always,
    labelStyle: TextStyle(
      fontSize: 16,
      color: Theme.of(context).colorScheme.onSurface,
    ),
    floatingLabelStyle: TextStyle(
      fontSize: 16,
      color: Theme.of(context).colorScheme.onSurface,
    ),
    helperStyle: const TextStyle(fontSize: 12, color: AppColors.medium),
    contentPadding: const EdgeInsets.fromLTRB(0, 6, 0, 10),
    border: UnderlineInputBorder(borderSide: hairline),
    enabledBorder: UnderlineInputBorder(borderSide: hairline),
    focusedBorder: UnderlineInputBorder(borderSide: hairline),
  );
}

/// Ionic header / toolbar buttons: icons in primary.
class _PrimaryIconButtons extends StatelessWidget {
  const _PrimaryIconButtons({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return IconButtonTheme(
      data: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: AppColors.primary),
      ),
      child: IconTheme.merge(
        data: const IconThemeData(color: AppColors.primary),
        child: child,
      ),
    );
  }
}
