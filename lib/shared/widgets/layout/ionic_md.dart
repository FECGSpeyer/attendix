import 'package:flutter/material.dart';

/// MD_SWEEP: Ionic **md mode** metrics as the desktop / Android web build
/// renders them: @ionic/core 9.0.10 `*.md.css`, the app's
/// src/theme/variables.scss (md dark: #121212 page, #1e1e1e items, #1f1f1f
/// toolbar / tab bar, #222222 borders, md step colours) and the
/// `md-ion-list-inset` part of @rdlabo/ionic-theme-ios27 1.1.0 that
/// src/global.scss loads for md too. On md 1rem = 16px.
///
/// Counterpart of `IonIos` (ionic_ios.dart); every widget that has an md
/// branch takes its numbers from here so the shared widgets and the
/// feature-local Ion* copies stay identical.
class IonMd {
  IonMd._();

  /// Root font size in md mode.
  static const double rem = 16;

  // ── colours ──────────────────────────────────────────────────────────

  /// `--ion-text-color`: not set in light mode (black), #fff in dark.
  static Color text(Brightness b) =>
      b == Brightness.dark ? Colors.white : Colors.black;

  /// `--ion-toolbar-color` fallback (`--ion-text-color`, #424242): toolbar
  /// title and buttons – #424242 light, #fff dark.
  static Color toolbarText(Brightness b) =>
      b == Brightness.dark ? Colors.white : const Color(0xFF424242);

  /// `--ion-background-color`: #fff, dark #121212.
  static Color background(Brightness b) =>
      b == Brightness.dark ? const Color(0xFF121212) : Colors.white;

  /// `--ion-item-background`: #fff, dark #1e1e1e.
  static Color itemBackground(Brightness b) =>
      b == Brightness.dark ? const Color(0xFF1E1E1E) : Colors.white;

  /// `--ion-border-color` (item lines, list header, tab bar): unset in light
  /// → `rgba(0,0,0,.13)`; dark #222222.
  static Color line(Brightness b) =>
      b == Brightness.dark ? const Color(0xFF222222) : const Color(0x21000000);

  /// `--ion-color-medium`: Ionic 9 #636469, the app's dark #989aa2.
  static Color medium(Brightness b) =>
      b == Brightness.dark ? const Color(0xFF989AA2) : const Color(0xFF636469);

  /// `--ion-color-medium-tint`: #737478, dark #a2a4ab.
  static Color mediumTint(Brightness b) =>
      b == Brightness.dark ? const Color(0xFFA2A4AB) : const Color(0xFF737478);

  /// `ion-label p` / `ion-note` (`--ion-color-step-600`, fallback #666666;
  /// md dark step-600 #a0a0a0).
  static Color labelP(Brightness b) =>
      b == Brightness.dark ? const Color(0xFFA0A0A0) : const Color(0xFF666666);

  /// `ion-note` colour (same variable as [labelP]).
  static Color note(Brightness b) => labelP(b);

  /// `ion-item-divider` text (`--ion-color-step-400`: #999999, dark
  /// #717171).
  static Color dividerText(Brightness b) =>
      b == Brightness.dark ? const Color(0xFF717171) : const Color(0xFF999999);

  /// `--ion-color-step-850` (#262626, dark #dbdbdb): searchbar text, action
  /// sheet buttons, card title.
  static Color step850(Brightness b) =>
      b == Brightness.dark ? const Color(0xFFDBDBDB) : const Color(0xFF262626);

  /// `--ion-color-step-550` (#737373, dark #949494): alert message, card
  /// text.
  static Color step550(Brightness b) =>
      b == Brightness.dark ? const Color(0xFF949494) : const Color(0xFF737373);

  /// `--ion-color-step-650` (#595959, dark #acacac): tab bar labels.
  static Color step650(Brightness b) =>
      b == Brightness.dark ? const Color(0xFFACACAC) : const Color(0xFF595959);

  /// `rgba(text, .54)`: icons slotted into items / action sheet icons.
  static Color iconColor(Brightness b) => text(b).withValues(alpha: 0.54);

  /// The overlay backdrop (`--backdrop-opacity: .32`) of alert, action
  /// sheet, modal, popover and loading.
  static const Color backdrop = Color(0x52000000);

  // ── ion-item / ion-label / ion-note ──────────────────────────────────

  /// `ion-item --min-height`.
  static const double itemMinHeight = 48;

  /// `ion-item --padding-start`.
  static const double itemPaddingStart = 16;

  /// `ion-item --inner-padding-end`.
  static const double itemPaddingEnd = 16;

  /// `ion-item` font size (1rem).
  static const double itemFontSize = 16;

  /// `ion-label` margin top / bottom inside an item.
  static const double labelMargin = 10;

  /// `::slotted(ion-icon[slot=start])` margin-inline-end.
  static const double startIconGap = 32;

  /// `::slotted([slot=start])` (avatar, thumbnail …) margin-inline-end.
  static const double startGap = 16;

  /// `::slotted([slot=end])` margin-inline-start.
  static const double endGap = 16;

  /// `::slotted(ion-icon)` 1.5em of the 16px item.
  static const double itemIconSize = 24;

  /// md item lines are 1px (`--inner-border-width: 0 0 1px 0`).
  static const double lineWidth = 1;

  /// `ion-label h2` 1rem / `h3` .875rem / `p` .875rem (line-height
  /// 1.25rem).
  static const double h2FontSize = 16;
  static const double h3FontSize = 14;
  static const double pFontSize = 14;
  static const double pLineHeight = 20 / 14;

  /// `ion-note` slotted into an `ion-item`: .6875rem (item.md.css
  /// `::slotted(ion-note)`, which wins over the note's own .875rem), with
  /// 18px / 10px padding.
  static const double itemNoteFontSize = 11;

  /// A free-standing `ion-note` (note.md.css .875rem).
  static const double noteFontSize = 14;

  // ── ion-list / ion-list-header ───────────────────────────────────────

  /// `ion-list inset` margin (list.md.css `.list-md.list-inset`).
  static const double insetMargin = 16;

  /// `md-ion-list-inset` (ionic-theme-ios27): `ion-item-group` radius in
  /// an inset list.
  static const double groupRadius = 16;

  /// PARITY_R9: shape of an `ion-item-group` in an md inset list – a flat
  /// block (no md card shadow) with the [groupRadius]. Use it with
  /// `Card(elevation: 0, shape: IonMd.insetGroupShape)` for sections that
  /// are item-groups in Ionic, not `ion-card`s.
  static const ShapeBorder insetGroupShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(groupRadius)),
  );

  /// Ionic core `.list-md.list-inset` radius (inset list without group).
  static const double listRadius = 2;

  /// `ion-list-header` md min-height.
  static const double listHeaderMinHeight = 45;

  /// Plain `ion-list-header` font size (.875rem, text colour).
  static const double listHeaderFontSize = 14;

  /// `md-ion-list-inset`: inset `ion-list-header ion-label` 1rem, weight
  /// 600, line-height 1.29rem, medium-tint, margin 8 4 4.
  static const double insetListHeaderFontSize = 16;
  static const double insetListHeaderLineHeight = 1.29;

  /// Label start of an inset list header: list margin 16 + header padding
  /// 16 + label margin 4.
  static const double insetListHeaderStart = 36;

  /// Inset `ion-list-header ion-label` style.
  static TextStyle insetListHeaderStyle(Brightness b, {Color? color}) =>
      TextStyle(
        fontSize: insetListHeaderFontSize,
        fontWeight: FontWeight.w600,
        height: insetListHeaderLineHeight,
        color: color ?? mediumTint(b),
      );

  /// Plain `ion-list-header` style (.875rem, `--ion-text-color`).
  static TextStyle listHeaderStyle(Brightness b, {Color? color}) => TextStyle(
        fontSize: listHeaderFontSize,
        fontWeight: FontWeight.w400,
        color: color ?? text(b),
      );

  // ── ion-item-divider ─────────────────────────────────────────────────

  static const double dividerMinHeight = 30;
  static const double dividerFontSize = 14;

  /// `ion-item-divider ::slotted(ion-label)` margin 13 / 10.
  static const EdgeInsets dividerPadding = EdgeInsets.fromLTRB(16, 13, 16, 10);

  // ── ion-badge ────────────────────────────────────────────────────────

  /// badge.md.css padding 3 4 4 4.
  static const EdgeInsets badgePadding = EdgeInsets.fromLTRB(4, 3, 4, 4);
  static const double badgeRadius = 4;
  static const double badgeFontSize = 13;

  /// global.scss `ion-badge { margin-left: .25rem }`.
  static const double badgeMarginStart = 4;

  // ── ion-chip ─────────────────────────────────────────────────────────

  static const double chipRadius = 16;
  static const double chipMinHeight = 32;
  static const double chipFontSize = 14;
  static const EdgeInsets chipPadding =
      EdgeInsets.symmetric(horizontal: 12, vertical: 6);

  /// Coloured chip (`.ion-color`): base at .08, text in the shade colour.
  static Color chipTint(Color c) => c.withValues(alpha: 0.08);

  /// Ionic `-shade` of a colour (12 % towards black).
  static Color shade(Color c) => Color.lerp(c, Colors.black, 0.12)!;

  // ── ion-searchbar ────────────────────────────────────────────────────

  /// `.searchbar-input`: 6px padding + 30px line-height.
  static const double searchbarHeight = 42;
  static const double searchbarRadius = 2;
  static const double searchbarFontSize = 16;

  /// `.searchbar-search-icon`: 1.3125rem, 16px from the start.
  static const double searchIconSize = 21;
  static const double searchIconStart = 16;

  /// `.searchbar-input` padding-inline 3.4375rem.
  static const double searchTextInset = 55;

  /// `.searchbar-clear-icon` 1.375rem, 13px from the end.
  static const double clearIconSize = 22;
  static const double clearIconEnd = 13;

  /// Host padding in the content (8) and in a toolbar (7 / 3).
  static const EdgeInsets searchbarPadding = EdgeInsets.all(8);
  static const EdgeInsets searchbarToolbarPadding =
      EdgeInsets.symmetric(horizontal: 7, vertical: 3);

  /// `--background: var(--ion-background-color)`.
  static Color searchbarBackground(Brightness b) => background(b);

  /// `--color` (step-850) and `--icon-color` (step-600).
  static Color searchbarText(Brightness b) => step850(b);
  static Color searchbarIcon(Brightness b) => labelP(b);

  /// `--placeholder-opacity: .6` of the text colour.
  static const double placeholderOpacity = 0.6;

  /// md elevation 2 (`0 2px 2px 0 .14, 0 3px 1px -2px .2, 0 1px 5px 0
  /// .12`): searchbar, card, solid button.
  static const List<BoxShadow> elevation2 = [
    BoxShadow(color: Color(0x24000000), offset: Offset(0, 2), blurRadius: 2),
    BoxShadow(
        color: Color(0x33000000),
        offset: Offset(0, 3),
        blurRadius: 1,
        spreadRadius: -2),
    BoxShadow(color: Color(0x1F000000), offset: Offset(0, 1), blurRadius: 5),
  ];

  // ── ion-toolbar / ion-title / ion-button ─────────────────────────────

  static const double toolbarHeight = 56;
  static const double titleFontSize = 20;

  /// `letter-spacing: .0125em` of the 20px title.
  static const double titleLetterSpacing = 0.25;

  /// ion-title padding-inline 20.
  static const double titleSpacing = 20;

  /// ion-buttons first / last slot margin 4.
  static const double toolbarButtonsMargin = 4;

  /// Toolbar icon-only button icon: 1.8em of the 14px button.
  static const double toolbarIconSize = 25.2;

  /// ion-button md: 36px min height, radius 4, .875rem medium,
  /// `letter-spacing: .06em`, padding 8 / 1.1em.
  static const double buttonMinHeight = 36;
  static const double buttonRadius = 4;
  static const double buttonFontSize = 14;
  static const double buttonLetterSpacing = 0.84;
  static const EdgeInsets buttonPadding =
      EdgeInsets.symmetric(horizontal: 15.4, vertical: 8);

  // ── ion-segment ──────────────────────────────────────────────────────

  static const double segmentHeight = 48;
  static const double segmentFontSize = 14;
  static const double segmentLetterSpacing = 0.84;

  // ── ion-card ─────────────────────────────────────────────────────────

  static const double cardRadius = 4;
  static const double cardMargin = 10;
  static const double cardElevation = 2;

  // ── ion-tab-bar ──────────────────────────────────────────────────────

  static const double tabBarHeight = 56;
  static const double tabIconSize = 22;
  static const double tabLabelSize = 12;
  static const double tabLetterSpacing = 0.36;

  /// `--border`: 1px `rgba(0,0,0,.07)` (light, no border colour set), dark
  /// `--ion-border-color` #222222.
  static Color tabBarBorder(Brightness b) =>
      b == Brightness.dark ? const Color(0xFF222222) : const Color(0x12000000);

  /// `--ion-tab-bar-background`: #fff, dark #1f1f1f.
  static Color tabBarBackground(Brightness b) =>
      b == Brightness.dark ? const Color(0xFF1F1F1F) : Colors.white;

  // ── overlays ─────────────────────────────────────────────────────────

  /// ion-alert / ion-popover / ion-toast radius.
  static const double alertRadius = 4;

  /// ion-toast md: `--background: step-800` (#333333; md dark #d0d0d0),
  /// `--color: step-50` (#f2f2f2; md dark #1e1e1e).
  static Color toastBackground(Brightness b) =>
      b == Brightness.dark ? const Color(0xFFD0D0D0) : const Color(0xFF333333);
  static Color toastText(Brightness b) =>
      b == Brightness.dark ? const Color(0xFF1E1E1E) : const Color(0xFFF2F2F2);
}

/// MD_SWEEP: the Ionic md `ion-searchbar` – a white (dark #121212) 42px
/// field with radius 2 and the md elevation-2 shadow, no border; the 21px
/// grey magnifier 16px in, 16px step-850 text from 55px with the
/// placeholder at 60 %, and the 22px clear ✕ 13px from the end once there
/// is text. [padding] is the host padding (8 in the content,
/// [IonMd.searchbarToolbarPadding] in a toolbar).
class IonMdSearchbar extends StatelessWidget {
  const IonMdSearchbar({
    super.key,
    required this.controller,
    required this.hintText,
    required this.onChanged,
    this.onClear,
    this.padding = IonMd.searchbarPadding,
    this.focusNode,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onChanged;
  final VoidCallback? onClear;
  final EdgeInsetsGeometry padding;
  final FocusNode? focusNode;
  final bool autofocus;

  void _clear() {
    controller.clear();
    onChanged('');
    onClear?.call();
  }

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final text = IonMd.searchbarText(b);
    final icon = IonMd.searchbarIcon(b);
    return Padding(
      padding: padding,
      child: Container(
        height: IonMd.searchbarHeight,
        decoration: BoxDecoration(
          color: IonMd.searchbarBackground(b),
          borderRadius: BorderRadius.circular(IonMd.searchbarRadius),
          boxShadow: IonMd.elevation2,
        ),
        child: ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) => Row(
            children: [
              const SizedBox(width: IonMd.searchIconStart),
              Icon(Icons.search, size: IonMd.searchIconSize, color: icon),
              const SizedBox(
                  width: IonMd.searchTextInset -
                      IonMd.searchIconStart -
                      IonMd.searchIconSize),
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  autofocus: autofocus,
                  onChanged: onChanged,
                  textAlignVertical: TextAlignVertical.center,
                  style: TextStyle(
                      fontSize: IonMd.searchbarFontSize, color: text),
                  decoration: InputDecoration(
                    hintText: hintText,
                    hintStyle: TextStyle(
                      fontSize: IonMd.searchbarFontSize,
                      color: text.withValues(alpha: IonMd.placeholderOpacity),
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    isCollapsed: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 6),
                  ),
                ),
              ),
              if (value.text.isNotEmpty)
                Semantics(
                  button: true,
                  child: InkResponse(
                    onTap: _clear,
                    radius: 20,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                          8, 0, IonMd.clearIconEnd, 0),
                      child: SizedBox(
                        height: IonMd.searchbarHeight,
                        child: Icon(Icons.close,
                            size: IonMd.clearIconSize, color: icon),
                      ),
                    ),
                  ),
                )
              else
                const SizedBox(width: IonMd.clearIconEnd),
            ],
          ),
        ),
      ),
    );
  }
}

/// MD_SWEEP: Ionic md `ion-list-header`. [inset] (default) is the header
/// inside an `ion-list [inset]` (md-ion-list-inset: 16px semibold
/// medium-tint label, 36px from the screen edge); otherwise the plain list
/// header (14px in the text colour, 16px in). Both 45px high.
class IonMdListHeader extends StatelessWidget {
  const IonMdListHeader(
    this.label, {
    super.key,
    this.inset = true,
    this.trailing,
    this.color,
    this.start,
  });

  final String label;
  final bool inset;
  final List<Widget>? trailing;
  final Color? color;

  /// Label start; defaults to [IonMd.insetListHeaderStart] (inset) or 16.
  final double? start;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final style = inset
        ? IonMd.insetListHeaderStyle(b, color: color)
        : IonMd.listHeaderStyle(b, color: color);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: IonMd.listHeaderMinHeight),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          start ?? (inset ? IonMd.insetListHeaderStart : 16),
          inset ? 8 : 0,
          trailing == null ? 20 : 8,
          inset ? 4 : 0,
        ),
        child: Row(
          children: [
            Expanded(child: Text(label, style: style)),
            if (trailing != null) ...trailing!,
          ],
        ),
      ),
    );
  }
}
