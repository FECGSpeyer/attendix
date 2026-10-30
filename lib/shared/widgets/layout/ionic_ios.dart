import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/redesign/rd_palette.dart';
import '../../../core/theme/redesign/rd_theme.dart';
import '../adaptive/adaptive_platform.dart';
import '../../../l10n/l10n.dart';
import '../adaptive/app_toolbar.dart'
    show kIonModalToolbarHeight, kIonTitleFontSize; // PARITY_R5, IOS27_SWEEP
import 'ion_modal_handle.dart' show kIonModalSheetRadius;
import 'ionic_md.dart';

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

/// PARITY_R5: background of an `ion-content` without `color` (pages with
/// plain `ion-list`s or white inset lists, e.g. Team-Organisation, Export,
/// Lehrer, Gruppen): `--ion-background-color` – white, iOS dark #000, md
/// dark #121212 (MD_SWEEP: the md scaffold default is the `color="light"`
/// #222428 now). Pages with `ion-content color="light"` keep the scaffold
/// default (#f4f5f8).
Color? ionPlainContentBackground(BuildContext context) {
  final theme = Theme.of(context);
  if (theme.brightness == Brightness.dark) {
    return useIosLook(context)
        ? AppColors.iosPlainPageDark
        : AppColors.mdPageDark;
  }
  return theme.colorScheme.surface;
}

/// Ionic iOS metrics as the iPhone renders them: @ionic/core 9 iOS mode
/// with @rdlabo/ionic-theme-ios27 1.1.0 (src/global.scss loads it under
/// `@supports (overflow-anchor: auto)`, which iOS 27 WebKit matches).
///
/// IOS27_SWEEP: on the iPhone Ionic sets `html { font: -apple-system-body }`
/// (`--ion-dynamic-font`), so **1rem = 17px**; rem values below are
/// converted with [rem].
class IonIos {
  IonIos._();

  /// Root font size on the iPhone (`-apple-system-body`).
  static const double rem = 17;

  /// `ion-list inset` horizontal margin: ios27 keeps the Ionic core
  /// `.list-ios.list-inset { margin: 16px }` (ios26 had 20pt).
  static const double insetMargin = 16;

  /// `ion-list inset > ion-item-group` corner radius (structured-list
  /// `layout(20px, 28px)`).
  static const double groupRadius = 28;

  /// `ion-list inset` without item group (plain inset list, Ionic core).
  static const double listRadius = 10;

  /// ios27: `ion-item --min-height` inside inset groups (52px; ios26 53).
  static const double itemMinHeight = 52;

  /// Ionic core `ion-item` min height in plain lists.
  static const double plainItemMinHeight = 44;

  /// `ion-item --padding-start`.
  static const double itemPaddingStart = 16;

  /// ios27: `ion-item::part(native)` padding-right inside inset groups
  /// (`calc(safe-area-right + 18px)`; ios26 16).
  static const double itemPaddingEnd = 18;

  /// ios27: `ion-item { font-size: 1rem }` inside inset groups (17pt).
  static const double itemFontSize = rem;

  /// ios27: `line-height: 1.29rem` of items in inset groups, as a factor.
  static const double itemLineHeight = 1.29;

  /// `ion-list-header` min-height.
  static const double listHeaderMinHeight = 40;

  /// ios27 `ion-list-header ion-label`: 1rem, weight 600, line-height
  /// 1.29rem, margin 8px 4px 4px.
  static const double listHeaderFontSize = rem;

  /// Label start of an inset `ion-list-header`: list margin 16 + header
  /// padding-start 16 + label margin 4.
  static const double listHeaderStart = 36;

  /// ios27 `ion-list-header ion-note` / outer `ion-list > ion-note`:
  /// 0.76rem, line-height 1.06rem.
  static const double listNoteFontSize = 0.76 * rem;

  /// `ion-note` in an item: `max(14px, 1rem)`.
  static const double noteFontSize = rem;

  /// `ion-label h2`: 1.0625rem.
  static const double h2FontSize = 1.0625 * rem;

  /// `ion-label h3` / `p`: 0.875rem.
  static const double pFontSize = 0.875 * rem;

  /// Item detail chevron: `--detail-icon-font-size: 1.25em` of the 17pt
  /// item font.
  static const double detailIconSize = 1.25 * rem;

  /// The detail icon's `margin-inline-end: -6px`.
  static const double detailIconMarginEnd = -6;

  /// `ion-title size="large"`: `min(2.125rem, 61.2px)` = 36.125pt bold,
  /// no letter spacing (Ionic core title.ios).
  static const double largeTitleFontSize = 2.125 * rem;

  /// `--ion-color-medium-tint` (Ionic 9 light).
  static const Color mediumTint = Color(0xFF737478);

  /// `--ion-color-medium`: Ionic 9 light #636469, the app's dark palette
  /// #989aa2 (variables.scss attendix-dark-theme-body).
  static Color medium(Brightness b) => b == Brightness.dark
      ? const Color(0xFF989AA2)
      : const Color(0xFF636469);

  /// `--ion-color-medium-tint`: #737478, dark #a2a4ab.
  static Color mediumTintOf(Brightness b) =>
      b == Brightness.dark ? const Color(0xFFA2A4AB) : mediumTint;

  /// ios27 `structured-list.colors(.75, .38)` (dark `(.93, .5)`): inset
  /// `ion-list-header` label colour `rgba(medium, .75)`.
  static Color listHeaderColor(Brightness b) => b == Brightness.dark
      ? const Color(0xFF989AA2).withValues(alpha: 0.93)
      : const Color(0xFF636469).withValues(alpha: 0.75);

  /// ios27 item detail icon: `rgb(medium)` at `--detail-icon-opacity` .38
  /// (dark .5).
  static Color detailIconColor(Brightness b) => b == Brightness.dark
      ? const Color(0xFF989AA2).withValues(alpha: 0.5)
      : const Color(0xFF636469).withValues(alpha: 0.38);

  /// ios27 `ion-list.ios { --ion-border-color: step-100 }`: item lines in
  /// lists – #e8e8e8 (no light step colours), dark step-100 #1a1a1a.
  static Color line(Brightness b) =>
      b == Brightness.dark ? const Color(0xFF1A1A1A) : const Color(0xFFE8E8E8);

  /// `ion-note` (`--ion-color-step-350`): #a6a6a6, dark #595959.
  static Color note(Brightness b) =>
      b == Brightness.dark ? const Color(0xFF595959) : const Color(0xFFA6A6A6);

  /// `ion-label p` (Ionic 9 `--ion-color-step-400`): #999999, dark #666666.
  static Color labelP(Brightness b) =>
      b == Brightness.dark ? const Color(0xFF666666) : const Color(0xFF999999);

  /// `ion-title size="large"`: 36.125pt bold.
  static const TextStyle largeTitle = TextStyle(
    fontSize: largeTitleFontSize,
    fontWeight: FontWeight.w700,
    height: 1.2,
  );

  /// ios27 inset `ion-list-header ion-label` text style.
  static TextStyle listHeaderStyle(BuildContext context, {Color? color}) =>
      TextStyle(
        fontSize: listHeaderFontSize,
        fontWeight: FontWeight.w600,
        height: itemLineHeight,
        color: color ?? listHeaderColor(Theme.of(context).brightness),
      );
}

/// IOS27_SWEEP: the iOS item detail chevron (`detail="true"`): ionicons
/// chevron-forward, 1.25em (21.25pt), `rgba(medium, .38)` / dark `.5`.
class IonDetailChevron extends StatelessWidget {
  const IonDetailChevron({super.key});

  @override
  Widget build(BuildContext context) {
    // Beta-Skin: the chevron of the new design's list rows.
    final rd = context.rdSkin;
    if (rd != null) return Icon(Icons.chevron_right, size: 20, color: rd.text2);
    return _ionChevron(context);
  }

  Widget _ionChevron(BuildContext context) => Icon(
        CupertinoIcons.chevron_forward,
        size: IonIos.detailIconSize,
        color: IonIos.detailIconColor(Theme.of(context).brightness),
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

/// PARITY_R5: Ionic `ion-header translucent` over `ion-content fullscreen`
/// (ionic-theme-ios27 `utils/translucent`): on iOS the content scrolls
/// under the toolbar (use with `Scaffold.extendBodyBehindAppBar` and
/// [ionTranslucentTopPadding]); once the large title is condensed the
/// toolbar shows the page colour at 20 % over an 8pt backdrop blur with a
/// hairline in `rgba(text, .08)`. Use as `AppBar.flexibleSpace` with a
/// transparent app bar background. Renders nothing outside iOS or while
/// the large title is visible.
class IonTranslucentBarBackground extends StatelessWidget {
  const IonTranslucentBarBackground(
      {super.key, required this.visible, this.color});

  /// true once the large title is condensed.
  final bool visible;

  /// IOS_R6: the page (`ion-content`) colour the 20 % tint is made of;
  /// default white (dark: black) like the Termin pages.
  final Color? color;

  /// ios27 `backdrop-filter: blur(8px)`.
  static const double blurSigma = 8;

  /// ios27 `rgba(content background, .2)`.
  static const double tintOpacity = 0.2;

  @override
  Widget build(BuildContext context) {
    if (!visible || !isIosLook(context)) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final rd = context.rdSkin;
    if (rd != null) {
      // Beta-Skin: the page colour, nearly opaque, with a hairline.
      return DecoratedBox(
        decoration: BoxDecoration(
          color: rd.bg.withValues(alpha: 0.96),
          border: Border(bottom: BorderSide(color: rd.line)),
        ),
        child: const SizedBox.expand(),
      );
    }
    final dark = theme.brightness == Brightness.dark;
    return ClipRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: (color ?? (dark ? Colors.black : Colors.white))
                .withValues(alpha: tintOpacity),
            border: Border(
              bottom: BorderSide(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
                width: 0.5,
              ),
            ),
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

/// PARITY_R5: top padding of a scroll view in the body of a Scaffold with
/// `extendBodyBehindAppBar` (the app bar incl. status bar); 0 otherwise.
/// [bodyContext] must be below the Scaffold (e.g. a [Builder] in `body`).
double ionTranslucentTopPadding(BuildContext bodyContext, bool extended) =>
    extended ? MediaQuery.paddingOf(bodyContext).top : 0;

/// IOS_R6: the shared Ionic iOS `ion-header translucent` toolbar for every
/// page with `ion-content fullscreen` (songs, settings, parents, …).
///
/// Wrap the page's [AppBar] (which must not set its own `backgroundColor`
/// or `shape` on iOS) and set `Scaffold.extendBodyBehindAppBar` to
/// [isIosLook]; put [IonContentTopInset] / [SliverIonContentTopInset] first
/// in the scroll view and use [IonRefresher] for `ion-refresher`.
///
/// iOS: transparent toolbar without hairline while the large title is
/// visible; once [condensed] (pages without `collapse="condense"`: always)
/// the [background] colour at 20 % over an 8pt backdrop blur with a
/// hairline ([IonTranslucentBarBackground]). Light and dark follow the
/// page colour. Elsewhere (Ionic md) [child] is returned unchanged.
class IonTranslucentAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const IonTranslucentAppBar({
    super.key,
    required this.child,
    this.condensed = true,
    this.condensedListenable,
    this.background,
  });

  final PreferredSizeWidget child;

  /// true once the large title has scrolled away (always true for pages
  /// without a large title).
  final bool condensed;

  /// Alternative to [condensed] for pages that track the large title with
  /// a [ValueListenable] (rebuilds only the bar background).
  final ValueListenable<bool>? condensedListenable;

  /// `ion-content` colour; default the scaffold background (Ionic
  /// `color="light"` pages).
  final Color? background;

  @override
  Size get preferredSize => child.preferredSize;

  @override
  Widget build(BuildContext context) {
    if (!isIosLook(context)) return child;
    final theme = Theme.of(context);
    final tint = background ?? theme.scaffoldBackgroundColor;
    return Stack(
      children: [
        Positioned.fill(
          child: condensedListenable == null
              ? IonTranslucentBarBackground(visible: condensed, color: tint)
              : ValueListenableBuilder<bool>(
                  valueListenable: condensedListenable!,
                  builder: (context, value, _) =>
                      IonTranslucentBarBackground(visible: value, color: tint),
                ),
        ),
        Theme(
          data: theme.copyWith(
            appBarTheme: theme.appBarTheme.copyWith(
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              // the hairline comes with the blurred background
              shape: const Border(),
            ),
          ),
          child: child,
        ),
      ],
    );
  }
}

/// IOS_R6: room for the translucent toolbar at the top of a scroll view in
/// the body of a Scaffold with `extendBodyBehindAppBar` (status bar +
/// toolbar). 0 when the body does not extend behind the app bar (md) or the
/// scroll view already consumed the inset (ListView without padding).
class IonContentTopInset extends StatelessWidget {
  const IonContentTopInset({super.key});

  @override
  Widget build(BuildContext context) =>
      SizedBox(height: MediaQuery.paddingOf(context).top);
}

/// IOS_R6: [IonContentTopInset] as the first sliver of a [CustomScrollView].
class SliverIonContentTopInset extends StatelessWidget {
  const SliverIonContentTopInset({super.key});

  @override
  Widget build(BuildContext context) =>
      const SliverToBoxAdapter(child: IonContentTopInset());
}

/// IOS_R6: Ionic `ion-refresher slot="fixed"`: the platform refresher
/// ([RefreshIndicator.adaptive] – the iOS activity indicator on iOS) that
/// appears below a translucent toolbar the content scrolls under. Must sit
/// in the Scaffold body.
class IonRefresher extends StatelessWidget {
  const IonRefresher({super.key, required this.onRefresh, required this.child});

  final RefreshCallback onRefresh;
  final Widget child;

  @override
  Widget build(BuildContext context) => RefreshIndicator.adaptive(
        onRefresh: onRefresh,
        edgeOffset: MediaQuery.paddingOf(context).top,
        child: child,
      );
}

/// PARITY_R5: search icon of an iOS `ion-searchbar` (ionic-theme-ios27):
/// the outline magnifier (ionicons search-outline) 1.375rem wide – 23.4pt
/// with the iPhone root font (IOS27_SWEEP) – in the text colour
/// (`--icon-color: var(--ion-text-color)`), not the grey system glyph.
class IonSearchIcon extends StatelessWidget {
  const IonSearchIcon({super.key});

  static const double size = 1.375 * IonIos.rem;

  @override
  Widget build(BuildContext context) {
    final rd = context.rdSkin;
    if (rd != null) return Icon(Icons.search, size: 20, color: rd.text2);
    return Icon(
      CupertinoIcons.search,
      size: size,
      color: Theme.of(context).colorScheme.onSurface,
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
///
/// IOS_THEME2: pass [pageBackground] when the page does not use the
/// scaffold default (e.g. the white Termin pages, `eventPageBackground`) so
/// the toolbar matches the page instead of showing the grouped grey.
Color? condenseBarColor(
  BuildContext context,
  bool condensed, {
  Color? pageBackground,
}) {
  if (condensed || !isIosLook(context)) return null;
  return pageBackground ?? Theme.of(context).scaffoldBackgroundColor;
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
    final rd = context.rdSkin;
    if (rd != null) {
      // Beta-Skin: sub page title of the new design.
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
        child: Semantics(
          header: true,
          child: Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: RdType.title(rd),
          ),
        ),
      );
    }
    return Padding(
      // IOS27_SWEEP / AUDIT_R4: the condense header's first toolbar has
      // padding-top 0 (core header.ios + ios27), so: toolbar padding-start
      // 4 + title-large padding 12, top 0 + 2, bottom 4 + toolbar 3.
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 7),
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

/// Ionic `ion-searchbar`. iOS (IOS27_SWEEP, ionic-theme-ios27): a 44pt
/// glass pill (radius 22, [IonSearchbarGlass]), the 23.4pt magnifier 12pt
/// from the start in the text colour, 18pt text (1.0625rem) with the
/// placeholder at 40 % and – once there is text – the clear ✕ in its own
/// 44pt glass circle 11pt to the right. md: [IonMdSearchbar] (MD_SWEEP).
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

  /// `.searchbar-input` min-height.
  static const double height = 44;

  /// `.searchbar-input` font size (1.0625rem).
  static const double fontSize = 1.0625 * IonIos.rem;

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
        final rd = context.rdSkin;
        if (rd != null) return _rdField(context, rd, hasText);
        if (!isIosLook(context)) {
          // MD_SWEEP: the Ionic md searchbar (white, shadow, no border);
          // the caller keeps its host padding.
          return IonMdSearchbar(
            controller: controller,
            hintText: hintText,
            onChanged: onChanged,
            onClear: onClear,
            padding: EdgeInsets.zero,
          );
        }
        final text = Theme.of(context).colorScheme.onSurface;
        final field = IonSearchbarGlass(
          child: Row(
            children: [
              const SizedBox(width: 12),
              const IonSearchIcon(),
              // input padding-start 1.375rem + 17.67px
              const SizedBox(width: 17.67 - 12),
              Expanded(
                child: TextField(
                  controller: controller,
                  onChanged: onChanged,
                  style: TextStyle(fontSize: fontSize, color: text),
                  textAlignVertical: TextAlignVertical.center,
                  decoration: InputDecoration(
                    hintText: hintText,
                    // ios27 --placeholder-opacity: .4
                    hintStyle: TextStyle(
                      color: text.withValues(alpha: 0.4),
                      fontSize: fontSize,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    isCollapsed: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
        );
        return SizedBox(
          height: height,
          child: Row(
            children: [
              Expanded(child: field),
              if (hasText) ...[
                // ios27: the clear button is its own 44pt glass circle,
                // 11pt from the field.
                const SizedBox(width: 11),
                Semantics(
                  button: true,
                  label: context.l10n.a11yClearInput,
                  child: GestureDetector(
                    onTap: _clear,
                    child: IonSearchbarGlass(
                      width: height,
                      child: Icon(Icons.close, size: 22, color: text),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

extension on IonSearchbar {
  /// Beta-Skin: the search field of the new design (white field, hairline,
  /// radius 12) on every platform.
  Widget _rdField(BuildContext context, RdPalette rd, bool hasText) {
    return SizedBox(
      height: IonSearchbar.height,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textAlignVertical: TextAlignVertical.center,
        style: TextStyle(fontSize: 16, color: rd.text),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(fontSize: 16, color: rd.text2),
          filled: true,
          fillColor: rd.surface,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          prefixIcon: const IonSearchIcon(),
          suffixIcon: hasText
              ? IconButton(
                  tooltip: context.l10n.a11yClearInput,
                  icon: Icon(Icons.close, size: 20, color: rd.text2),
                  onPressed: _clear,
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: rd.offBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: rd.offBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: rd.primary, width: 2),
          ),
        ),
      ),
    );
  }
}

/// IOS27_SWEEP: the glass of the ios27 searchbar input and its clear /
/// cancel circle (`searchbar-glass`): `rgba(glass, .52)`, a 0.5pt
/// `rgba(text, .25)` ring, `0 3px 8px rgba(0,0,0,.035)`, radius 22.
class IonSearchbarGlass extends StatelessWidget {
  const IonSearchbarGlass({super.key, required this.child, this.width});

  final Widget child;
  final double? width;

  static const BorderRadius radius = BorderRadius.all(Radius.circular(22));

  /// `rgba(--ios26-glass-background-rgb, .52)`.
  static Color background(Brightness b) =>
      (b == Brightness.dark ? const Color(0xFF3E3E3E) : Colors.white)
          .withValues(alpha: 0.52);

  /// The 0.5pt ring `rgba(text, .25)`.
  static Color ring(Brightness b) =>
      (b == Brightness.dark ? Colors.white : Colors.black)
          .withValues(alpha: 0.25);

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return CustomPaint(
      painter: IosOuterShadowPainter(
        borderRadius: radius,
        shadows: [
          BoxShadow(color: ring(b), spreadRadius: 0.5),
          const BoxShadow(
              color: Color(0x09000000), blurRadius: 8, offset: Offset(0, 3)),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 2, sigmaY: 2),
          child: Container(
            width: width,
            height: IonSearchbar.height,
            alignment: Alignment.center,
            color: background(b),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Ionic `ion-list-header` inside an inset list.
/// IOS27_SWEEP (ionic-theme-ios27 structured-list): label 1rem (17pt)
/// semibold, line-height 1.29rem, `rgba(medium, .75)` (dark .93), margin
/// 8 4 4 in a 40pt header – 36pt from the screen edge (list margin 16 +
/// header padding 16 + label margin 4).
class IonListHeader extends StatelessWidget {
  const IonListHeader(this.label, {super.key, this.trailing, this.color});

  final String label;
  final List<Widget>? trailing;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final rd = context.rdSkin;
    if (rd != null) return _rdHeader(rd);
    final ios = isIosLook(context);
    // MD_SWEEP: md-ion-list-inset header label – 16px semibold
    // medium-tint, line-height 1.29rem.
    final style =
        ios
            ? IonIos.listHeaderStyle(context, color: color)
            : IonMd.insetListHeaderStyle(Theme.of(context).brightness,
                color: color);
    final row = Row(
      children: [
        Expanded(child: Text(label, style: style)),
        // Ionic `ion-button fill="clear"` in the header: primary icons.
        if (trailing != null)
          _PrimaryIconButtons(
            child: Row(mainAxisSize: MainAxisSize.min, children: trailing!),
          ),
      ],
    );
    if (!ios) {
      // MD_SWEEP: 45px header, label margin 8 4 4, 36px from the edge
      // (list margin 16 + header padding 16 + label margin 4).
      return ConstrainedBox(
        constraints:
            const BoxConstraints(minHeight: IonMd.listHeaderMinHeight),
        child: Padding(
          padding: EdgeInsets.fromLTRB(IonMd.insetListHeaderStart, 8,
              trailing == null ? 20 : 8, 4),
          child: Align(alignment: Alignment.centerLeft, child: row),
        ),
      );
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: IonIos.listHeaderMinHeight),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          IonIos.listHeaderStart,
          8,
          trailing == null ? 20 : 8,
          4,
        ),
        child: Align(alignment: Alignment.centerLeft, child: row),
      ),
    );
  }
}

extension on IonListHeader {
  /// Beta-Skin: the uppercase group label of the new design.
  Widget _rdHeader(RdPalette rd) => Padding(
        padding: EdgeInsets.fromLTRB(20, 16, trailing == null ? 20 : 8, 6),
        child: Row(
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text(label.toUpperCase(), style: RdType.eyebrow(color ?? rd.text2)),
              ),
            ),
            if (trailing != null)
              _PrimaryIconButtons(child: Row(mainAxisSize: MainAxisSize.min, children: trailing!)),
          ],
        ),
      );
}

/// `--ion-item-background` of rows in inset lists / item groups: iOS dark
/// #000 on the grouped #222428 page (IOS_R4), otherwise the theme surface
/// (white; md dark #1e1e1e).
Color ionItemBackground(BuildContext context) {
  final theme = Theme.of(context);
  final rd = context.rdSkin;
  if (rd != null) return rd.surface;
  if (isIosLook(context) && theme.brightness == Brightness.dark) {
    return AppColors.iosInsetItemDark;
  }
  return theme.colorScheme.surface;
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
    final rd = context.rdSkin;
    if (rd != null) return rd.listRadius;
    // MD_SWEEP: md-ion-list-inset groups radius 16, a plain md inset list
    // the core 2px.
    if (!isIosLook(context)) {
      return grouped ? IonMd.groupRadius : IonMd.listRadius;
    }
    return grouped ? IonIos.groupRadius : IonIos.listRadius;
  }

  @override
  Widget build(BuildContext context) {
    final radius = radiusOf(context, grouped: grouped);
    final rd = context.rdSkin;
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        // MD_SWEEP: md item lines are 1px. Beta-Skin: full-width 1px lines.
        final w = rd != null ? 1.0 : (isIosLook(context) ? 0.5 : IonMd.lineWidth);
        rows.add(Divider(height: w, thickness: w, indent: rd != null ? 0 : dividerIndent, color: rd?.line));
      }
      rows.add(children[i]);
    }
    return Container(
      margin: margin,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: color ?? ionItemBackground(context),
        borderRadius: BorderRadius.circular(radius),
        border: border,
        boxShadow: rd?.cardShadow,
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

/// Ionic `ion-item` row inside an [IonInsetList]: IOS27_SWEEP – min height
/// 52, 17pt label (line-height 1.29rem), 18pt end padding and the 21.25pt
/// detail chevron 6pt further out (`margin-inline-end: -6px`) when
/// [detail] (Ionic `detail` / button items on iOS).
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
    final rd = context.rdSkin;
    if (rd != null) return _rdRow(rd);
    final ios = isIosLook(context);
    final chevron = ios && detail && onTap != null;
    final b = Theme.of(context).brightness;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: ios ? IonIos.itemMinHeight : 48),
        child: Padding(
          // MD_SWEEP: md ion-label margin 10 top / bottom.
          padding: EdgeInsets.fromLTRB(
            16,
            ios ? 8 : IonMd.labelMargin,
            ios
                ? IonIos.itemPaddingEnd +
                    (chevron ? IonIos.detailIconMarginEnd : 0)
                : IonMd.itemPaddingEnd,
            ios ? 8 : IonMd.labelMargin,
          ),
          child: Row(
            children: [
              // MD_SWEEP: md start icons keep 32px to the label.
              if (leading != null) ...[
                leading!,
                SizedBox(
                    width: !ios && leading is Icon
                        ? IonMd.startIconGap
                        : IonMd.startGap),
              ],
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DefaultTextStyle.merge(
                      style: TextStyle(
                        fontSize: ios ? IonIos.itemFontSize : 16,
                        height: ios ? IonIos.itemLineHeight : null,
                        color: titleColor,
                      ),
                      child: title,
                    ),
                    if (subtitle != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: DefaultTextStyle.merge(
                          // ion-label p: .875rem, step-400
                          style: ios
                              ? TextStyle(
                                  fontSize: IonIos.pFontSize,
                                  color: IonIos.labelP(b),
                                )
                              // MD_SWEEP: ion-label p 14/20 step-600.
                              : TextStyle(
                                  fontSize: IonMd.pFontSize,
                                  height: IonMd.pLineHeight,
                                  color: IonMd.labelP(b),
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
                const IonDetailChevron(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

extension on IonItem {
  /// Beta-Skin: a list row of the new design (`RdListRow`): 52 high, 16pt
  /// title, 13pt grey subtitle, chevron when [detail].
  Widget _rdRow(RdPalette rd) {
    final chevron = detail && onTap != null;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            children: [
              if (leading != null) ...[
                IconTheme.merge(data: IconThemeData(color: rd.text2, size: 22), child: leading!),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DefaultTextStyle.merge(
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: titleColor ?? rd.text),
                      child: title,
                    ),
                    if (subtitle != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: DefaultTextStyle.merge(
                          style: RdType.meta(rd, size: 13),
                          child: subtitle!,
                        ),
                      ),
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 8), trailing!],
              if (chevron) ...[const SizedBox(width: 4), const IonDetailChevron()],
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
    final rd = context.rdSkin;
    final ios = rd != null || isIosLook(context);
    final titleWidget = Text(
      title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: ios ? TextAlign.center : TextAlign.start,
      style: TextStyle(
        fontSize: ios ? kIonTitleFontSize : IonMd.titleFontSize,
        fontWeight: ios ? FontWeight.w600 : FontWeight.w500,
        // MD_SWEEP: md ion-title – toolbar colour, .0125em tracking.
        letterSpacing: ios ? null : IonMd.titleLetterSpacing,
        color: rd?.text ??
            (ios
                ? Theme.of(context).colorScheme.onSurface
                : IonMd.toolbarText(Theme.of(context).brightness)),
      ),
    );
    final header = Container(
      // PARITY_R5: iOS sheet toolbar 64pt (ionic-theme-ios27 modal-sheet
      // `--min-height: 64px`, no padding); md toolbar 56.
      height: ios ? kIonModalToolbarHeight : 56,
      decoration: BoxDecoration(
        // Beta-Skin: the sheet colour of the new design (page background).
        color: rd?.bg ?? Theme.of(context).colorScheme.surface,
        // Matches the bottom sheet's rounded top corners (ios27
        // `.modal-sheet --border-radius: 32px`; PARITY_R3: md sheets are
        // square like Ionic md modals).
        borderRadius: ios
            ? BorderRadius.vertical(
                top: Radius.circular(rd != null ? 24 : kIonModalSheetRadius))
            : null,
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
                  // MD_SWEEP: ion-title padding-start 20.
                  if (start.isEmpty)
                    const SizedBox(width: IonMd.titleSpacing)
                  else ...[
                    const SizedBox(width: IonMd.toolbarButtonsMargin),
                    ...start,
                  ],
                  Expanded(child: titleWidget),
                  ...end,
                  const SizedBox(width: 4),
                ],
              ),
      ),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        header,
        Divider(height: rd != null ? 1 : 0.5, thickness: rd != null ? 1 : 0.5, color: rd?.line),
      ],
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
  // Beta-Skin: the theme's field of the new design on every platform.
  if (context.rdSkin != null || !isIosLook(context)) {
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
    final color = context.rdSkin?.link ?? AppColors.primary;
    return IconButtonTheme(
      data: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: color),
      ),
      child: IconTheme.merge(
        data: IconThemeData(color: color),
        child: child,
      ),
    );
  }
}
