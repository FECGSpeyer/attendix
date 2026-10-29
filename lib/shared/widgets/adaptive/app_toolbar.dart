import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import 'adaptive_platform.dart';

/// IOS_LOOK: header buttons of an `ion-toolbar` in the Ionic iOS theme:
/// all `ion-button`s of one `ion-buttons` slot share one 44pt Liquid Glass
/// capsule with black icons. Elsewhere the children are a plain [Row].
/// IOS27_SWEEP: ionic-theme-ios27 `theme-buttons` – icon-only buttons 44pt
/// with a 1.4rem (23.8pt) icon, text buttons 1.05rem (17.85pt) medium with
/// 12pt padding.
///
/// Use it as the only entry of `AppBar.actions` (or as `leading`):
/// `actions: [ToolbarButtonGroup(children: [IconButton(...), ...])]`.
class ToolbarButtonGroup extends StatelessWidget {
  const ToolbarButtonGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (!useIosLook(context)) {
      return Row(mainAxisSize: MainAxisSize.min, children: children);
    }
    final fg = Theme.of(context).colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: IosGlassSurface(
        borderRadius: const BorderRadius.all(Radius.circular(22)),
        blur: 2,
        child: SizedBox(
          height: 44,
          child: IconButtonTheme(
            data: IconButtonThemeData(
              style: IconButton.styleFrom(
                foregroundColor: fg,
                minimumSize: const Size(44, 44),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                iconSize: IonToolbarButtonMetrics.iconSize,
              ),
            ),
            child: TextButtonTheme(
              data: TextButtonThemeData(
                style: TextButton.styleFrom(
                  foregroundColor: fg,
                  minimumSize: const Size(44, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  textStyle: const TextStyle(
                      fontSize: IonToolbarButtonMetrics.textSize,
                      fontWeight: FontWeight.w500),
                ),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: children),
            ),
          ),
        ),
      ),
    );
  }
}

/// IOS27_SWEEP: ionic-theme-ios27 toolbar button metrics (1rem = 17px on
/// the iPhone, Ionic `--ion-dynamic-font: -apple-system-body`).
abstract final class IonToolbarButtonMetrics {
  /// Icon-only `ion-button` / `ion-back-button`: 44 × 44.
  static const double size = 44;

  /// `.button-has-icon-only ion-icon { font-size: 1.4rem }`.
  static const double iconSize = 23.8;

  /// `ion-button { font-size: 1.05rem }` (text buttons).
  static const double textSize = 17.85;
}

/// IOS_LOOK: close button of an `ion-modal` header (`ion-buttons slot="end"`
/// > `ion-button` > close icon), the Material [CloseButton] elsewhere.
/// PARITY_R5: iOS = the ios27 toolbar button – a 44pt white Liquid Glass
/// circle with a black ✕, 12pt from the edge (same as a single-button
/// [ToolbarButtonGroup], e.g. the register modal ✕), not a grey disc.
class IonCloseButton extends StatelessWidget {
  const IonCloseButton({super.key, this.onPressed, this.tooltip});

  final VoidCallback? onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final onTap = onPressed ?? () => Navigator.of(context).maybePop();
    if (!useIosLook(context)) {
      return IconButton(
        icon: const Icon(Icons.close),
        tooltip: tooltip ?? context.l10n.commonClose,
        onPressed: onTap,
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Semantics(
        button: true,
        label: tooltip ?? context.l10n.commonClose,
        child: GestureDetector(
          onTap: onTap,
          child: const IosCircleIcon(icon: Icons.close, size: 44),
        ),
      ),
    );
  }
}

/// A 44pt round icon in the iOS look (IOS27_SWEEP: ios27 back button
/// `--min-width/--min-height: 44px`) – used for the back chevron and
/// close buttons. [filled] gives the light-grey modal close style, otherwise
/// the Liquid Glass circle of the toolbar back button.
class IosCircleIcon extends StatelessWidget {
  const IosCircleIcon({
    super.key,
    required this.icon,
    this.filled = false,
    this.size = IonToolbarButtonMetrics.size,
    this.iconSize = 22,
  });

  final IconData icon;
  final bool filled;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final b = theme.brightness;
    final fg = theme.colorScheme.onSurface;
    final glyph = Icon(icon, size: iconSize, color: fg);
    if (filled) {
      return Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: b == Brightness.dark
              ? const Color(0xFF3A3A3C)
              : const Color(0xFFE9E9EB),
        ),
        child: glyph,
      );
    }
    return SizedBox(
      width: size,
      height: size,
      child: IosGlassSurface(
        borderRadius: BorderRadius.circular(size / 2),
        blur: 2,
        child: Center(child: glyph),
      ),
    );
  }
}

/// PARITY_R5: height of the header toolbar of an iOS card or sheet modal
/// (ionic-theme-ios27 `ion-modal.modal-card / .modal-sheet ion-header
/// ion-toolbar:first-of-type { padding-top: 0; padding-bottom: 0;
/// --min-height: 64px }`). The same value as [kIosCardModalToolbarHeight].
const double kIonModalToolbarHeight = 64;

/// IOS27_SWEEP: iOS `ion-title` font size, `min(1.0625rem, 20.4px)` with
/// the iPhone root font of 17px (`-apple-system-body`) = 18.06pt, weight
/// 600.
const double kIonTitleFontSize = 18.0625;

/// PARITY_R5: `toolbarHeight` for an [AppBar] inside a sheet / card modal:
/// [kIonModalToolbarHeight] on iOS, null (theme default) elsewhere. Without
/// it an app bar in a bottom sheet would get the page toolbar height of
/// [IonToolbarMetrics] (≈73pt in the browser).
double? ionModalToolbarHeight(BuildContext context) =>
    useIosLook(context) ? kIonModalToolbarHeight : null;

/// IOS_LOOK: header of a sheet / modal like an Ionic `ion-modal` toolbar:
/// centred semibold 17pt title, optional start button (e.g. "Abbrechen"),
/// end button (default: [IonCloseButton]) and a hairline below.
/// PARITY_R5: 64pt high like every iOS sheet / card modal toolbar.
class IonModalHeader extends StatelessWidget implements PreferredSizeWidget {
  const IonModalHeader({
    super.key,
    required this.title,
    this.leading,
    this.trailing,
    this.showClose = true,
    this.onClose,
    this.showDivider = true,
  });

  final Widget title;
  final Widget? leading;
  final Widget? trailing;
  final bool showClose;
  final VoidCallback? onClose;
  final bool showDivider;

  @override
  Size get preferredSize => const Size.fromHeight(kIonModalToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final end = trailing ??
        (showClose ? IonCloseButton(onPressed: onClose) : null);
    // MD_SWEEP: md modal toolbar = md ion-toolbar: 56px, start-aligned
    // 20px medium title (toolbar colour, .0125em tracking) 20px in, buttons
    // 4px from the edges, the md header shadow instead of a hairline.
    if (!useIosLook(context)) {
      final b = theme.brightness;
      return Container(
        height: 56,
        decoration: BoxDecoration(
          color: theme.appBarTheme.backgroundColor,
          boxShadow: showDivider
              ? const [
                  BoxShadow(
                      color: Color(0x33000000),
                      offset: Offset(0, 2),
                      blurRadius: 4,
                      spreadRadius: -1),
                  BoxShadow(
                      color: Color(0x24000000),
                      offset: Offset(0, 4),
                      blurRadius: 5),
                  BoxShadow(
                      color: Color(0x1F000000),
                      offset: Offset(0, 1),
                      blurRadius: 10),
                ]
              : null,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: NavigationToolbar(
          leading: leading,
          trailing: end,
          middle: DefaultTextStyle.merge(
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.25,
              color: b == Brightness.dark
                  ? Colors.white
                  : const Color(0xFF424242),
            ),
            child: title,
          ),
          centerMiddle: false,
          middleSpacing: leading == null ? 16 : 20,
        ),
      );
    }
    return Container(
      height: kIonModalToolbarHeight,
      decoration: BoxDecoration(
        border: showDivider
            ? Border(
                bottom: BorderSide(
                  // IOS27_SWEEP: ion-toolbar (ios) --border-color
                  // step-150 → rgba(0,0,0,.2); dark #404040.
                  color: useIosLook(context)
                      ? (theme.brightness == Brightness.dark
                          ? const Color(0xFF404040)
                          : const Color(0x33000000))
                      : theme.dividerColor,
                  width: 0.5,
                ))
            : null,
      ),
      child: NavigationToolbar(
        leading: leading,
        trailing: end,
        middle: DefaultTextStyle.merge(
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            // IOS27_SWEEP: ion-title min(1.0625rem, 20.4px) = 18.06pt
            fontSize: kIonTitleFontSize,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
          child: title,
        ),
        centerMiddle: true,
        middleSpacing: 8,
      ),
    );
  }
}

/// IOS_R4: height of a page `ion-toolbar` below the status bar in the
/// iOS 26/27 theme. The header toolbar gets
/// `padding-top: max(safe-area-top - 10px, 6px)`, `--min-height: 64px` and
/// the iOS toolbar padding-bottom of 3px, so its bottom edge is at
/// `max(safeTop - 10, 6) + 67`: 73pt in a browser without safe area (the
/// glass capsules centred at ≈38pt) and safe area + 57pt on a notched
/// iPhone. A Flutter [AppBar] adds [safeTop] itself, hence the difference.
double ionToolbarHeight(double safeTop) =>
    math.max(safeTop - 10, 6.0) + 67 - safeTop;

/// IOS_R4: applies [ionToolbarHeight] to every [AppBar] below it (iOS look
/// only; Material keeps its 56pt toolbar). Placed once around the app's
/// navigator (MaterialApp.builder). Pages with their own `toolbarHeight`
/// keep it.
class IonToolbarMetrics extends StatelessWidget {
  const IonToolbarMetrics({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!useIosLook(context)) return child;
    final theme = Theme.of(context);
    final height = ionToolbarHeight(MediaQuery.paddingOf(context).top);
    return Theme(
      data: theme.copyWith(
        appBarTheme: theme.appBarTheme.copyWith(toolbarHeight: height),
      ),
      child: child,
    );
  }
}
