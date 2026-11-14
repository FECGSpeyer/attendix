import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:attendix/core/theme/app_icons.dart';

import '../../../core/theme/redesign/rd_palette.dart';
import '../../../core/theme/redesign/rd_theme.dart';
import '../../../l10n/l10n.dart';
import '../layout/ionic_md.dart' show IonMd;
import 'adaptive_platform.dart';
import 'app_action_sheet.dart';
import '../dialogs/ion_modal.dart' show showIonModal;
import 'app_dialog.dart';
import 'app_toolbar.dart' show ionModalToolbarHeight;
import 'ion_button_label.dart';

/// IOS_THEME2: `ion-select` as Ionic renders it in **iOS mode**
/// (@rdlabo/ionic-theme-ios26):
///
/// - the value is followed by the iOS `chevron-expand` (⇅) toggle icon
///   ([IonSelectIcon]) instead of a Material ▾ arrow;
/// - `interface="popover"`: a frosted popover (radius 24, 200pt wide) right
///   below the value – centred on it and kept on screen, so a value at the
///   end of a row opens the popover at the RIGHT – with a ✓ (primary) on the
///   current option and no pre-highlighted row. With a floating / stacked
///   label the popover covers the field's width (Ionic `size="cover"`);
/// - `interface="alert"` (Ionic default): an iOS alert with radio rows
///   (✓ + primary label on the checked one) and "Abbrechen" / "OK";
/// - `interface="action-sheet"`: an iOS action sheet with one button per
///   option.
///
/// KP_SELECTS: the md look (Android / desktop / web, Ionic **md mode**)
/// mirrors `ion-select` md the same way – one select implementation for the
/// classic design:
///
/// - the value is followed by the md caret (`caret-down`, 13px, step-500)
///   which turns while the select is open ([IonMdSelectIcon]);
/// - `interface="popover"`: the md popover (surface, radius 4, md shadow,
///   250px wide or as wide as a field with a floating label, no backdrop)
///   below the value with 48px rows, the current option tinted
///   `rgba(primary, .08)` (`ion-select-popover` md hides the radios);
/// - `interface="alert"`: the md alert with a radio list (radio at the
///   start, 48px rows between two hairlines) and "ABBRECHEN" / "OK";
/// - `interface="action-sheet"`: the md action sheet with one button per
///   option and the cancel button.
///
/// The Beta design (`context.rdSkin != null`) keeps its own select menu.

/// Ionic `ion-select` `interface`.
enum AppSelectInterface {
  /// `interface="popover"`.
  popover,

  /// `interface="alert"` – Ionic's default when no interface is set.
  alert,

  /// `interface="action-sheet"`.
  actionSheet,

  /// `interface="modal"` (`ion-select-modal`, for long lists): a modal with
  /// the header as its title and the cancel button at the end; a tap on an
  /// option chooses it and closes the modal.
  modal,
}

/// The picked value of [showAppSelect] (wrapped so that a `null` option can
/// be told apart from a dismissed select).
class AppSelection<T> {
  const AppSelection(this.value);
  final T value;
}

/// One `ion-select-option`.
class AppSelectOption<T> {
  const AppSelectOption({
    required this.value,
    this.label,
    this.child,
    this.enabled = true,
  }) : assert(label != null || child != null);

  final T value;

  /// Plain label (used by the alert / action sheet and as popover text).
  final String? label;

  /// Custom row content (e.g. the `child` of a [DropdownMenuItem]).
  final Widget? child;

  final bool enabled;

  /// Options from Material [DropdownMenuItem]s (label = the item's [Text]).
  static List<AppSelectOption<T>> fromMenuItems<T>(
    List<DropdownMenuItem<T>> items,
  ) => [
    for (final i in items)
      // A disabled header item without a value (e.g. a section caption in a
      // `String` select) is no option: `ion-select` has no such rows, and
      // the cast below would throw for a non-nullable T.
      if (i.value is T)
        AppSelectOption<T>(
          value: i.value as T,
          label: _plainText(i.child),
          child: i.child,
          enabled: i.enabled,
        ),
  ];

  String textOr(String fallback) => label ?? _plainText(child) ?? fallback;
}

String? _plainText(Widget? w) {
  if (w is Text) return w.data ?? w.textSpan?.toPlainText();
  if (w is RichText) return w.text.toPlainText();
  return null;
}

/// iOS radius of popovers (ionic-theme-ios26 `ion-popover::part(content)`).
/// IOS27_SWEEP: ionic-theme-ios27 `ion-popover::part(content)` radius 34.
const double kIosPopoverRadius = 34;

/// Ionic iOS popover default `--width: 200px`.
const double kIosSelectPopoverWidth = 200;

/// Ionic `ion-select` iOS toggle icon (`chevron-expand`, 1.125rem,
/// `--ion-color-step-650`).
class IonSelectIcon extends StatelessWidget {
  const IonSelectIcon({super.key, this.size = 18, this.color});

  final double size;
  final Color? color;

  /// `--ion-color-step-650`: #595959 (light) / #a6a6a6 (dark).
  static Color colorOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFFA6A6A6)
          : const Color(0xFF595959);

  @override
  Widget build(BuildContext context) => Icon(
    AppIcons.cupertinoChevronUpChevronDown,
    size: size,
    color: color ?? colorOf(context),
  );
}

/// Opens the select for [options] (current value [value]).
///
/// [context] is the trigger (the select's value); its box anchors the iOS
/// popover. [cover] makes the popover as wide as the trigger (Ionic
/// floating / stacked label). [header] is the alert / action sheet / modal
/// title.
///
/// The same three interfaces exist in the md look (see the library comment).
Future<AppSelection<T>?> showAppSelect<T>({
  required BuildContext context,
  required List<AppSelectOption<T>> options,
  required T? value,
  AppSelectInterface interface = AppSelectInterface.popover,
  String? header,
  bool cover = false,
}) async {
  final box = context.findRenderObject() as RenderBox?;
  final navigator = Navigator.of(context, rootNavigator: true);
  final overlay = navigator.overlay!.context.findRenderObject()! as RenderBox;
  final anchor = box != null && box.hasSize
      ? Rect.fromPoints(
          box.localToGlobal(Offset.zero, ancestor: overlay),
          box.localToGlobal(box.size.bottomRight(Offset.zero), ancestor: overlay),
        )
      : Rect.fromCenter(
          center: overlay.size.center(Offset.zero),
          width: 0,
          height: 0,
        );

  // BETA_SELECT: the Beta design has its own select menu (surface card
  // below the value, ✓ at the current option) on every platform instead of
  // the Ionic glass popover / iOS alert. The action-sheet interface is
  // already Beta-styled by [showAppActionSheet].
  final rd = context.rdSkin;
  if (rd != null && interface == AppSelectInterface.actionSheet) {
    return _showSelectActionSheet<T>(context, options, header);
  }
  if (rd != null) {
    return _showRdSelectMenu<T>(
      context: context,
      palette: rd,
      anchor: anchor,
      overlaySize: overlay.size,
      options: options,
      value: value,
    );
  }

  final ios = useIosLook(context);
  switch (interface) {
    case AppSelectInterface.popover:
      return navigator.push<AppSelection<T>>(
        _SelectPopoverRoute<T>(
          ios: ios,
          anchor: anchor,
          overlaySize: overlay.size,
          options: options,
          value: value,
          cover: cover,
          barrierLabel: context.l10n.commonClose,
          capturedThemes: InheritedTheme.capture(
            from: context,
            to: navigator.context,
          ),
        ),
      );
    case AppSelectInterface.alert:
      return showAppDialog<AppSelection<T>>(
        context: context,
        builder: (_) => ios
            ? _IosSelectAlert<T>(header: header, options: options, value: value)
            : _MdSelectAlert<T>(header: header, options: options, value: value),
      );
    case AppSelectInterface.actionSheet:
      // md: Ionic adds the cancel button (`cancelText`, role cancel) after
      // the options; only the ios27 theme hides it.
      return _showSelectActionSheet<T>(context, options, header,
          showCancel: !ios, value: value, markValue: true);
    case AppSelectInterface.modal:
      return showIonModal<AppSelection<T>>(
        context,
        builder: (_) => _SelectModal<T>(ios: ios, header: header, options: options, value: value),
      );
  }
}

/// `interface="action-sheet"` (Beta-styled by [showAppActionSheet] itself).
Future<AppSelection<T>?> _showSelectActionSheet<T>(
  BuildContext context,
  List<AppSelectOption<T>> options,
  String? header, {
  bool showCancel = false,
  T? value,
  bool markValue = false,
}) {
  return showAppActionSheet<AppSelection<T>>(
    context,
    title: header,
    // IOS27_SWEEP: ios27 hides the cancel button of
    // `ion-select[interface=action-sheet]` (`.select-action-sheet`).
    showCancel: showCancel,
    actions: [
      for (final o in options)
        AppActionSheetAction<AppSelection<T>>(
          value: AppSelection<T>(o.value),
          label: o.textOr('${o.value}'),
          enabled: o.enabled,
          // F-EINST-32: Ionic marks the current value (classic only).
          selected: markValue && o.value == value,
        ),
    ],
  );
}

// ---------------------------------------------------------------------------
// Beta select menu
// ---------------------------------------------------------------------------

/// BETA_SELECT: the Beta select – the same menu card as the Beta row menus
/// (surface, radius 16, hairline border, see `_showRdAnchoredMenu`), placed
/// right below the value and at least as wide as it, the current option
/// tinted with a ✓ in the primary colour.
Future<AppSelection<T>?> _showRdSelectMenu<T>({
  required BuildContext context,
  required RdPalette palette,
  required Rect anchor,
  required Size overlaySize,
  required List<AppSelectOption<T>> options,
  required T? value,
}) {
  const margin = 8.0;
  final maxW = math.max(0.0, overlaySize.width - 2 * margin);
  final width = math.min(math.max(anchor.width, 220.0), math.min(360.0, maxW));
  final p = palette;
  return showMenu<AppSelection<T>>(
    context: context,
    useRootNavigator: true,
    position: RelativeRect.fromRect(
      Rect.fromLTWH(anchor.left, anchor.bottom + 6, anchor.width, 0),
      Offset.zero & overlaySize,
    ),
    color: p.surface,
    surfaceTintColor: Colors.transparent,
    elevation: 8,
    constraints: BoxConstraints.tightFor(width: width).copyWith(maxHeight: 368),
    menuPadding: const EdgeInsets.symmetric(vertical: 6),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(color: p.line),
    ),
    items: [
      for (final o in options)
        PopupMenuItem<AppSelection<T>>(
          value: AppSelection<T>(o.value),
          enabled: o.enabled,
          padding: EdgeInsets.zero,
          height: 44,
          child: Semantics(
            selected: o.value == value,
            child: Container(
              constraints: const BoxConstraints(minHeight: 44),
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 6),
              padding: const EdgeInsets.fromLTRB(12, 8, 10, 8),
              decoration: BoxDecoration(
                color: o.value == value ? p.soft : null,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: DefaultTextStyle.merge(
                      style: TextStyle(
                        fontSize: 15,
                        color: o.value == value ? p.softText : p.text,
                        fontWeight: o.value == value ? FontWeight.w600 : FontWeight.w400,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      child: o.child ?? Text(o.label!),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 20,
                    child: o.value == value ? Icon(Icons.check, size: 18, color: p.primary) : null,
                  ),
                ],
              ),
            ),
          ),
        ),
    ],
  );
}

/// Ionic `ion-select` md toggle icon (`caret-down`, `.select-icon`:
/// 0.8125rem wide, `--ion-color-step-500`). While the select is open
/// ([expanded]) it is turned by 180° and, outside an item, shown in the
/// highlight colour.
class IonMdSelectIcon extends StatelessWidget {
  const IonMdSelectIcon({super.key, this.expanded = false, this.color});

  final bool expanded;
  final Color? color;

  /// `--ion-color-step-500`: #808080 (the same grey in dark mode).
  static const Color defaultColor = Color(0xFF808080);

  @override
  Widget build(BuildContext context) => AnimatedRotation(
    turns: expanded ? 0.5 : 0,
    duration: const Duration(milliseconds: 150),
    curve: const Cubic(0.4, 0, 0.2, 1),
    child: Icon(AppIcons.arrowDropDown, size: 13, color: color ?? defaultColor),
  );
}

/// Whether the select around is open (its popover / alert / action sheet is
/// showing): Ionic `.select-expanded`.
class _SelectExpanded extends InheritedWidget {
  const _SelectExpanded({required this.expanded, required super.child});

  final bool expanded;

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_SelectExpanded>()?.expanded ?? false;

  @override
  bool updateShouldNotify(_SelectExpanded old) => old.expanded != expanded;
}

/// The toggle icon after a select's value: the Ionic `chevron-expand` (iOS)
/// or caret (md), in the Beta design its own ▾ (like the "Stimme" cells of
/// the file table). [highlightExpanded]: md colours the caret primary while
/// the select is open (a select with a field decoration, not one in an item).
Widget _selectToggleIcon(
  BuildContext context, {
  required bool enabled,
  bool highlightExpanded = false,
}) {
  final rd = context.rdSkin;
  final Widget icon;
  if (rd != null) {
    icon = Icon(Icons.keyboard_arrow_down, size: 20, color: rd.text2);
  } else if (useIosLook(context)) {
    icon = const IonSelectIcon();
  } else {
    icon = Builder(
      builder: (context) {
        final expanded = _SelectExpanded.of(context);
        return IonMdSelectIcon(
          expanded: expanded,
          color: expanded && highlightExpanded ? Theme.of(context).colorScheme.primary : null,
        );
      },
    );
  }
  // md: `:host(.select-disabled) { opacity: .38 }`.
  return Opacity(opacity: enabled ? 1 : 0.4, child: icon);
}

/// Gap between a select's value and its toggle icon (md `.select-icon`
/// `margin-inline-start: 4px`).
double _selectIconGap(BuildContext context) =>
    context.rdSkin == null && !useIosLook(context) ? 4 : 6;

// ---------------------------------------------------------------------------
// Popover (interface="popover"): iOS glass / md surface
// ---------------------------------------------------------------------------

/// Ionic md popover default `--width: 250px`.
const double kMdSelectPopoverWidth = 250;

class _SelectPopoverRoute<T> extends PopupRoute<AppSelection<T>> {
  _SelectPopoverRoute({
    required this.ios,
    required this.anchor,
    required this.overlaySize,
    required this.options,
    required this.value,
    required this.cover,
    required this.barrierLabel,
    required this.capturedThemes,
  });

  /// iOS look (glass popover) or md look (Ionic md popover).
  final bool ios;
  final Rect anchor;
  final Size overlaySize;
  final List<AppSelectOption<T>> options;
  final T? value;
  final bool cover;
  final CapturedThemes capturedThemes;

  @override
  final String barrierLabel;

  /// ionic-theme-ios26 `ion-popover.ios { --backdrop-opacity: .2 }`; the md
  /// select popover has no backdrop (`showBackdrop: false`).
  @override
  Color? get barrierColor => ios ? const Color(0x33000000) : Colors.transparent;

  @override
  bool get barrierDismissible => true;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 220);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 150);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    final media = MediaQuery.of(context);
    // Ionic keeps a popover `bodyPadding` away from the edges: md 12px.
    final margin = ios ? 8.0 : 12.0;
    final defaultWidth = ios ? kIosSelectPopoverWidth : kMdSelectPopoverWidth;
    // The md popover sits right at the value (no arrow, no gap).
    final gap = ios ? 6.0 : 0.0;
    final maxW = overlaySize.width - 2 * margin;
    final w = cover
        ? math.min(math.max(anchor.width, defaultWidth), maxW)
        : math.min(defaultWidth, maxW);
    // Centred on the value (cover: aligned with the field), kept on screen.
    final preferredLeft = cover ? anchor.left : anchor.center.dx - w / 2;
    final left = preferredLeft
        .clamp(margin, math.max(margin, overlaySize.width - w - margin))
        .toDouble();
    // Above an open keyboard (a select does not take the focus away from
    // a text field).
    final spaceBelow = overlaySize.height -
        anchor.bottom -
        math.max(media.padding.bottom, media.viewInsets.bottom) -
        margin;
    final spaceAbove = anchor.top - media.padding.top - margin;
    // global.scss: `ion-select-popover ion-list { max-height: 23rem }`.
    const listMax = 368.0;
    final rowsHeight = math.min(
      listMax,
      ios ? options.length * 45.0 + 12 : options.length * 48.0 + 16,
    );
    final below = spaceBelow >= math.min(rowsHeight, 160) || spaceBelow >= spaceAbove;
    final maxHeight = math.max(
      88.0,
      math.min(listMax, (below ? spaceBelow : spaceAbove) - gap),
    );
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeIn,
    );
    final card = FadeTransition(
      opacity: curved,
      child: ScaleTransition(
        // md `.popover-content { transform-origin: left top }`, scale .8.
        scale: Tween<double>(begin: ios ? 0.85 : 0.8, end: 1).animate(curved),
        alignment: ios
            ? (below ? Alignment.topCenter : Alignment.bottomCenter)
            : (below ? Alignment.topLeft : Alignment.bottomLeft),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: ios
              ? _IosSelectPopoverCard<T>(options: options, value: value)
              : _MdSelectPopoverCard<T>(options: options, value: value),
        ),
      ),
    );

    return capturedThemes.wrap(
      MediaQuery.removePadding(
        context: context,
        removeTop: true,
        removeBottom: true,
        child: Stack(
          children: [
            if (below)
              Positioned(top: anchor.bottom + gap, left: left, width: w, child: card)
            else
              Positioned(
                bottom: overlaySize.height - anchor.top + gap,
                left: left,
                width: w,
                child: card,
              ),
          ],
        ),
      ),
    );
  }
}

class _IosSelectPopoverCard<T> extends StatelessWidget {
  const _IosSelectPopoverCard({required this.options, required this.value});

  final List<AppSelectOption<T>> options;
  final T? value;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < options.length; i++) {
      if (i > 0) {
        rows.add(const Divider(height: 0.5, thickness: 0.5, indent: 16));
      }
      rows.add(_IosSelectRow<T>(
        option: options[i],
        checked: options[i].value == value,
        onTap: () => Navigator.of(context).pop(
          AppSelection<T>(options[i].value),
        ),
      ));
    }
    // IOS27_SWEEP: ios27 popover glass; `ion-select-popover` items are
    // transparent, the last one without a line.
    return IosGlassSurface.popover(
      brightness: Theme.of(context).brightness,
      child: Material(
        type: MaterialType.transparency,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: rows,
          ),
        ),
      ),
    );
  }
}

/// `ion-item` + `ion-radio` (iOS: label start, checkmark at the end).
class _IosSelectRow<T> extends StatelessWidget {
  const _IosSelectRow({
    required this.option,
    required this.checked,
    required this.onTap,
    this.primaryLabelWhenChecked = false,
    this.minHeight = 44,
    this.checkAtStart = false,
  });

  final AppSelectOption<T> option;
  final bool checked;
  final VoidCallback onTap;
  final bool primaryLabelWhenChecked;
  final double minHeight;

  /// `ion-select-modal` (iOS): the radio's checkmark stands before the
  /// label (`labelPlacement="end"`, `justify="start"`).
  final bool checkAtStart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final fg = checked && primaryLabelWhenChecked
        ? primary
        : theme.colorScheme.onSurface;
    return Semantics(
      selected: checked,
      button: true,
      enabled: option.enabled,
      child: Opacity(
        opacity: option.enabled ? 1 : 0.4,
        child: InkWell(
          // iOS: no ripple, nothing highlighted before a touch.
          splashFactory: NoSplash.splashFactory,
          highlightColor: IosGlass.itemActivated(theme.brightness),
          hoverColor: Colors.transparent,
          focusColor: Colors.transparent,
          onTap: option.enabled ? onTap : null,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: minHeight),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 14, 10),
              child: Row(
                children: [
                  if (checkAtStart) ...[
                    SizedBox(
                      width: 20,
                      child: checked ? Icon(AppIcons.check, size: 20, color: primary) : null,
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: DefaultTextStyle.merge(
                      // ion-item 1rem = 17pt on the iPhone
                      style: TextStyle(fontSize: 17, color: fg),
                      child: IconTheme.merge(
                        data: IconThemeData(color: fg, size: 20),
                        child: option.child ?? Text(option.label!),
                      ),
                    ),
                  ),
                  if (!checkAtStart) ...[
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 20,
                      child: checked
                          ? Icon(AppIcons.check, size: 20, color: primary)
                          : null,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// iOS alert (interface="alert")
// ---------------------------------------------------------------------------

class _IosSelectAlert<T> extends StatefulWidget {
  const _IosSelectAlert({
    required this.header,
    required this.options,
    required this.value,
  });

  final String? header;
  final List<AppSelectOption<T>> options;
  final T? value;

  @override
  State<_IosSelectAlert<T>> createState() => _IosSelectAlertState<T>();
}

class _IosSelectAlertState<T> extends State<_IosSelectAlert<T>> {
  late AppSelection<T>? _selected = widget.options
          .any((o) => o.value == widget.value)
      ? AppSelection<T>(widget.value as T)
      : null;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < widget.options.length; i++) {
      final o = widget.options[i];
      if (i > 0) rows.add(const Divider(height: 0.5, thickness: 0.5));
      rows.add(_IosSelectRow<T>(
        option: o,
        checked: _selected != null && _selected!.value == o.value,
        primaryLabelWhenChecked: true,
        onTap: () => setState(() => _selected = AppSelection<T>(o.value)),
      ));
    }
    return IosAlertCard(
      title: widget.header == null ? null : Text(widget.header!),
      scrollable: true,
      contentPadding: const EdgeInsets.fromLTRB(0, 0, 0, 14),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: rows,
      ),
      actions: [
        IosAlertButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.commonCancel),
        ),
        IosAlertButton(
          onPressed: () => Navigator.of(context).pop(_selected),
          child: Text(context.l10n.commonOk),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// md popover + md alert (Ionic md mode)
// ---------------------------------------------------------------------------

/// `ion-select-popover` in an md `ion-popover`: surface card (radius 4, md
/// shadow), an `ion-list` (8px padding) of 48px items without lines; the
/// radios are hidden and the checked item is tinted `rgba(primary, .08)`.
class _MdSelectPopoverCard<T> extends StatelessWidget {
  const _MdSelectPopoverCard({required this.options, required this.value});

  final List<AppSelectOption<T>> options;
  final T? value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      borderRadius: BorderRadius.circular(4),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final o in options)
              _MdSelectRow<T>(
                option: o,
                checked: o.value == value,
                onTap: () => Navigator.of(context).pop(AppSelection<T>(o.value)),
              ),
          ],
        ),
      ),
    );
  }
}

/// md `ion-item` of `ion-select-popover` / `ion-select-modal`: 48px, no
/// line, the radio hidden and the checked item tinted `rgba(primary, .08)`.
class _MdSelectRow<T> extends StatelessWidget {
  const _MdSelectRow({required this.option, required this.checked, required this.onTap});

  final AppSelectOption<T> option;
  final bool checked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      selected: checked,
      button: true,
      enabled: option.enabled,
      child: Opacity(
        // md `ion-item` disabled: opacity .3.
        opacity: option.enabled ? 1 : 0.3,
        child: Material(
          color: checked ? theme.colorScheme.primary.withValues(alpha: 0.08) : Colors.transparent,
          child: InkWell(
            onTap: option.enabled ? onTap : null,
            child: Container(
              constraints: const BoxConstraints(minHeight: IonMd.itemMinHeight),
              alignment: AlignmentDirectional.centerStart,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: DefaultTextStyle.merge(
                // `.select-option-label`: one line, ellipsis.
                style: TextStyle(
                  fontSize: IonMd.itemFontSize,
                  color: theme.colorScheme.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                child: option.child ?? Text(option.label!),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// `ion-select-modal` (`interface="modal"`): `ion-header` with the title
/// and the cancel button in `ion-buttons slot="end"`, below it the options
/// as an `ion-list` – iOS rows with the checkmark before the label, md rows
/// without radio and the checked one tinted. A tap chooses and closes
/// (`closeModal`).
class _SelectModal<T> extends StatelessWidget {
  const _SelectModal({
    required this.ios,
    required this.header,
    required this.options,
    required this.value,
  });

  final bool ios;
  final String? header;
  final List<AppSelectOption<T>> options;
  final T? value;

  @override
  Widget build(BuildContext context) {
    void pick(AppSelectOption<T> o) => Navigator.of(context).pop(AppSelection<T>(o.value));
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: ionModalToolbarHeight(context),
        automaticallyImplyLeading: false,
        title: header == null ? null : Text(header!),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: IonButtonLabel(context.l10n.commonCancel),
          ),
        ],
      ),
      body: ListView(
        // md `ion-list`: 8px padding.
        padding: EdgeInsets.only(
          top: ios ? 0 : 8,
          bottom: (ios ? 0 : 8) + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          for (final o in options)
            if (ios) ...[
              _IosSelectRow<T>(
                option: o,
                checked: o.value == value,
                checkAtStart: true,
                onTap: () => pick(o),
              ),
              // `ion-radio::after`: hairline from the label to the end.
              const Divider(height: 0.5, thickness: 0.5, indent: 48),
            ] else
              _MdSelectRow<T>(option: o, checked: o.value == value, onTap: () => pick(o)),
        ],
      ),
    );
  }
}

/// Ionic md `ion-alert` of an `ion-select` (`interface="alert"`, the Ionic
/// default): the header, the options as `.alert-radio-group` (hairline
/// above and below, at most 266px high on a phone) with 48px rows – a 20px
/// radio 24px from the edge, the 16px step-850 label 32px after it – and
/// the flat buttons "ABBRECHEN" / "OK". The choice counts with OK.
class _MdSelectAlert<T> extends StatefulWidget {
  const _MdSelectAlert({
    required this.header,
    required this.options,
    required this.value,
  });

  final String? header;
  final List<AppSelectOption<T>> options;
  final T? value;

  @override
  State<_MdSelectAlert<T>> createState() => _MdSelectAlertState<T>();
}

class _MdSelectAlertState<T> extends State<_MdSelectAlert<T>> {
  late AppSelection<T>? _selected = widget.options
          .any((o) => o.value == widget.value)
      ? AppSelection<T>(widget.value as T)
      : null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final b = theme.brightness;
    final primary = theme.colorScheme.primary;
    // `--ion-color-step-150`: #d9d9d9, md dark #363636.
    final line = b == Brightness.dark ? const Color(0xFF363636) : const Color(0xFFD9D9D9);
    final size = MediaQuery.sizeOf(context);
    // Phones: `.alert-radio-group { max-height: 266px }`; from 768px the
    // whole alert may grow to min(100vh - 96px, 560px).
    final groupMax = size.width < 768
        ? 266.0
        : math.max(144.0, math.min(size.height - 96, 560.0) - 120);
    return AppAlertDialog(
      title: widget.header == null ? null : Text(widget.header!),
      contentPadding: EdgeInsets.zero,
      content: Container(
        constraints: BoxConstraints(maxHeight: groupMax),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: line),
            bottom: BorderSide(color: line),
          ),
        ),
        // The radio rows ripple on the alert's surface.
        child: Material(
          type: MaterialType.transparency,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final o in widget.options)
                  _MdAlertRadioRow(
                    checked: _selected != null && _selected!.value == o.value,
                    enabled: o.enabled,
                    primary: primary,
                    onTap: () => setState(() => _selected = AppSelection<T>(o.value)),
                    child: o.child ?? Text(o.label!),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.commonCancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_selected),
          child: Text(context.l10n.commonOk),
        ),
      ],
    );
  }
}

/// `.alert-radio` (md): `.alert-tappable` min-height 48, `.alert-radio-icon`
/// 20px (2px step-550 border, checked: primary border + 10px primary dot)
/// at `inset-inline-start: 24px`, `.alert-radio-label` 16px step-850 with
/// 13px vertical padding, 32px after the radio and 24px before the edge.
class _MdAlertRadioRow extends StatelessWidget {
  const _MdAlertRadioRow({
    required this.checked,
    required this.enabled,
    required this.primary,
    required this.onTap,
    required this.child,
  });

  final bool checked;
  final bool enabled;
  final Color primary;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Semantics(
      checked: checked,
      inMutuallyExclusiveGroup: true,
      enabled: enabled,
      child: Opacity(
        // `.alert-radio-button-disabled .alert-button-inner { opacity: .5 }`
        opacity: enabled ? 1 : 0.5,
        child: InkWell(
          onTap: enabled ? onTap : null,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 280),
                    curve: const Cubic(0.4, 0, 0.2, 1),
                    width: 20,
                    height: 20,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        width: 2,
                        color: checked ? primary : IonMd.step550(b),
                      ),
                    ),
                    child: AnimatedScale(
                      scale: checked ? 1 : 0,
                      duration: const Duration(milliseconds: 280),
                      curve: const Cubic(0.4, 0, 0.2, 1),
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(color: primary, shape: BoxShape.circle),
                      ),
                    ),
                  ),
                  const SizedBox(width: 32),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      child: DefaultTextStyle.merge(
                        style: TextStyle(fontSize: 16, color: IonMd.step850(b)),
                        child: child,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Drop-in dropdowns
// ---------------------------------------------------------------------------

Widget? _selectedChild<T>(
  BuildContext context,
  List<DropdownMenuItem<T>>? items,
  T? value,
  DropdownButtonBuilder? selectedItemBuilder,
) {
  if (items == null) return null;
  // Like Material's DropdownButton: no value = no selection, unless an
  // enabled option really has the value null (a "Keine" option of a
  // nullable select) – a disabled caption item never counts.
  var index = items.indexWhere((i) => i.enabled && i.value == value);
  if (index < 0 && value != null) {
    index = items.indexWhere((i) => i.value == value);
  }
  if (index < 0) return null;
  if (selectedItemBuilder != null) {
    final built = selectedItemBuilder(context);
    if (index < built.length) return built[index];
  }
  return items[index].child;
}

/// The tappable value of a custom select: tap, or Tab + Enter / Space
/// (`ActivateIntent`) like the Material dropdowns it replaces; a focus ring
/// shows in keyboard mode. While [onTap] runs (the select is open) the
/// subtree sees [_SelectExpanded] (md: turned caret, highlighted field).
class _SelectTrigger extends StatefulWidget {
  const _SelectTrigger({
    required this.onTap,
    required this.focusNode,
    required this.autofocus,
    required this.child,
  });

  final Future<void> Function()? onTap;
  final FocusNode? focusNode;
  final bool autofocus;
  final Widget child;

  @override
  State<_SelectTrigger> createState() => _SelectTriggerState();
}

class _SelectTriggerState extends State<_SelectTrigger> {
  bool _focused = false;
  bool _expanded = false;

  Future<void> _open() async {
    final onTap = widget.onTap;
    if (onTap == null || _expanded) return;
    setState(() => _expanded = true);
    try {
      await onTap();
    } finally {
      if (mounted) setState(() => _expanded = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return FocusableActionDetector(
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      enabled: enabled,
      mouseCursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
      onShowFocusHighlight: (v) => setState(() => _focused = v),
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            _open();
            return null;
          },
        ),
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? _open : null,
        child: DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: _focused
                ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2)
                : null,
          ),
          child: _SelectExpanded(expanded: _expanded, child: widget.child),
        ),
      ),
    );
  }
}

/// IOS_THEME2 / KP_SELECTS: drop-in replacement for
/// [DropdownButtonFormField] – the one select field of the classic design.
///
/// The field keeps its [decoration] (label, borders, errors, validator) but
/// shows the value with the Ionic toggle icon (iOS `chevron-expand`, md
/// caret) and opens [showAppSelect] with [interface] (match the Ionic
/// page's `ion-select interface`; an `ion-select` without `interface` is
/// [AppSelectInterface.alert]). In the Beta design it opens the Beta menu.
class AppDropdownFormField<T> extends StatelessWidget {
  const AppDropdownFormField({
    super.key,
    required this.items,
    this.selectedItemBuilder,
    this.value,
    this.hint,
    this.disabledHint,
    required this.onChanged,
    this.onTap,
    this.style,
    this.icon,
    this.isDense = true,
    this.isExpanded = false,
    this.itemHeight,
    this.focusNode,
    this.autofocus = false,
    this.dropdownColor,
    this.decoration,
    this.onSaved,
    this.validator,
    this.autovalidateMode,
    this.menuMaxHeight,
    this.alignment = AlignmentDirectional.centerStart,
    this.borderRadius,
    this.padding,
    AppSelectInterface? interface,
    this.header,
    @Deprecated('Use interface') AppSelectInterface? iosInterface,
  }) : interface = interface ?? iosInterface ?? AppSelectInterface.popover;

  final List<DropdownMenuItem<T>>? items;
  final DropdownButtonBuilder? selectedItemBuilder;
  final T? value;
  final Widget? hint;
  final Widget? disabledHint;
  final ValueChanged<T?>? onChanged;
  final VoidCallback? onTap;
  final TextStyle? style;

  /// Unused: the toggle icon is the Ionic one of the current look. (Kept so
  /// the widget stays a drop-in for [DropdownButtonFormField]; the same
  /// holds for [isDense], [isExpanded], [itemHeight], [dropdownColor],
  /// [menuMaxHeight], [alignment] and [borderRadius].)
  final Widget? icon;
  final bool isDense;
  final bool isExpanded;
  final double? itemHeight;
  final FocusNode? focusNode;
  final bool autofocus;
  final Color? dropdownColor;
  final InputDecoration? decoration;
  final FormFieldSetter<T>? onSaved;
  final FormFieldValidator<T>? validator;
  final AutovalidateMode? autovalidateMode;
  final double? menuMaxHeight;
  final AlignmentGeometry alignment;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;

  /// Ionic `ion-select interface` (both looks).
  final AppSelectInterface interface;

  /// Alert / action sheet header (default: the decoration's label) or the
  /// title of the modal (no default).
  final String? header;

  @override
  Widget build(BuildContext context) {
    final field = _SelectFormField<T>(
      items: items,
      selectedItemBuilder: selectedItemBuilder,
      value: value,
      hint: hint,
      disabledHint: disabledHint,
      onChanged: onChanged,
      onTap: onTap,
      style: style,
      decoration: decoration ?? const InputDecoration(),
      onSaved: onSaved,
      validator: validator,
      autovalidateMode: autovalidateMode,
      interface: interface,
      header: header,
      focusNode: focusNode,
      autofocus: autofocus,
    );
    final padding = this.padding;
    // md: [DropdownButtonFormField] applied [padding] around its button.
    if (padding != null && !useIosLook(context) && context.rdSkin == null) {
      return Padding(padding: padding, child: field);
    }
    return field;
  }
}

class _SelectFormField<T> extends FormField<T> {
  _SelectFormField({
    required List<DropdownMenuItem<T>>? items,
    required DropdownButtonBuilder? selectedItemBuilder,
    required T? value,
    required Widget? hint,
    required Widget? disabledHint,
    required ValueChanged<T?>? onChanged,
    required VoidCallback? onTap,
    required TextStyle? style,
    required InputDecoration decoration,
    required super.onSaved,
    required super.validator,
    required AutovalidateMode? autovalidateMode,
    required AppSelectInterface interface,
    required String? header,
    required FocusNode? focusNode,
    required bool autofocus,
  }) : super(
         initialValue: value,
         autovalidateMode: autovalidateMode ?? AutovalidateMode.disabled,
         builder: (field) {
           final context = field.context;
           final theme = Theme.of(context);
           final md = !useIosLook(context) && context.rdSkin == null;
           final enabled = onChanged != null && items != null && items.isNotEmpty;
           final current = field.value;
           final selected =
               _selectedChild<T>(context, items, current, selectedItemBuilder);
           final placeholder = enabled ? hint : (disabledHint ?? hint);
           final effective = decoration
               .applyDefaults(theme.inputDecorationTheme)
               .copyWith(errorText: field.errorText, enabled: enabled);
           final labelText = decoration.labelText;
           final cover = labelText != null || decoration.label != null;
           final textStyle = (style ?? theme.textTheme.titleMedium ?? const TextStyle())
               .copyWith(fontSize: style?.fontSize ?? 16);
           return Builder(
             builder: (triggerContext) => _SelectTrigger(
               focusNode: focusNode,
               autofocus: autofocus,
               onTap: !enabled
                   ? null
                   : () async {
                       onTap?.call();
                       final picked = await showAppSelect<T>(
                         context: triggerContext,
                         options: AppSelectOption.fromMenuItems<T>(items),
                         value: current,
                         interface: interface,
                         // `ion-select-modal` only has a title when
                         // `interfaceOptions.header` is set.
                         header: header ??
                             (interface == AppSelectInterface.modal ? null : labelText),
                         cover: cover,
                       );
                       if (picked == null || !field.mounted) return;
                       field.didChange(picked.value);
                       if (picked.value != current) onChanged(picked.value);
                     },
               child: Semantics(
                 button: true,
                 enabled: enabled,
                 // md `.select-expanded`: the open select is highlighted
                 // like a focused field (primary border / label).
                 child: Builder(
                   builder: (context) => InputDecorator(
                     decoration: effective,
                     isEmpty: selected == null && placeholder == null,
                     isFocused: md && _SelectExpanded.of(context),
                     child: Row(
                       children: [
                         Expanded(
                           child: DefaultTextStyle.merge(
                             style: selected == null
                                 ? textStyle.copyWith(
                                     color: theme.hintColor,
                                   )
                                 : textStyle,
                             maxLines: 1,
                             overflow: TextOverflow.ellipsis,
                             child: selected ?? placeholder ?? const SizedBox.shrink(),
                           ),
                         ),
                         SizedBox(width: _selectIconGap(context)),
                         _selectToggleIcon(context, enabled: enabled, highlightExpanded: true),
                       ],
                     ),
                   ),
                 ),
               ),
             ),
           );
         },
       );

  @override
  FormFieldState<T> createState() => _SelectFormFieldState<T>();
}

class _SelectFormFieldState<T> extends FormFieldState<T> {
  @override
  void didUpdateWidget(covariant _SelectFormField<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialValue != widget.initialValue) {
      setValue(widget.initialValue);
    }
  }
}

/// IOS_THEME2 / KP_SELECTS: drop-in replacement for [DropdownButton]
/// (inline selects, e.g. an `ion-select` at the end of an `ion-item`).
///
/// It shows the selected value + the Ionic toggle icon of the current look
/// (iOS `chevron-expand`, md caret; no underline) and opens [showAppSelect]
/// ([interface], popover by default) anchored on the value. In the Beta
/// design it opens the Beta menu.
class AppDropdownButton<T> extends StatelessWidget {
  const AppDropdownButton({
    super.key,
    required this.items,
    this.selectedItemBuilder,
    this.value,
    this.hint,
    this.disabledHint,
    required this.onChanged,
    this.onTap,
    this.elevation = 8,
    this.style,
    this.underline,
    this.icon,
    this.iconSize = 24.0,
    this.isDense = false,
    this.isExpanded = false,
    this.itemHeight,
    this.focusColor,
    this.focusNode,
    this.autofocus = false,
    this.dropdownColor,
    this.menuMaxHeight,
    this.alignment = AlignmentDirectional.centerStart,
    this.borderRadius,
    this.padding,
    AppSelectInterface? interface,
    this.header,
    @Deprecated('Use interface') AppSelectInterface? iosInterface,
  }) : interface = interface ?? iosInterface ?? AppSelectInterface.popover;

  final List<DropdownMenuItem<T>>? items;
  final DropdownButtonBuilder? selectedItemBuilder;
  final T? value;
  final Widget? hint;
  final Widget? disabledHint;
  final ValueChanged<T?>? onChanged;
  final VoidCallback? onTap;

  /// Unused, like [underline], [icon], [iconSize], [itemHeight],
  /// [focusColor], [dropdownColor], [menuMaxHeight], [alignment] and
  /// [borderRadius] (kept so the widget stays a drop-in for
  /// [DropdownButton]).
  final int elevation;
  final TextStyle? style;
  final Widget? underline;
  final Widget? icon;
  final double iconSize;
  final bool isDense;
  final bool isExpanded;
  final double? itemHeight;
  final Color? focusColor;
  final FocusNode? focusNode;
  final bool autofocus;
  final Color? dropdownColor;
  final double? menuMaxHeight;
  final AlignmentGeometry alignment;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;

  /// Ionic `ion-select interface` (both looks).
  final AppSelectInterface interface;

  /// Alert / action sheet header, title of the modal.
  final String? header;

  @override
  Widget build(BuildContext context) {
    final md = !useIosLook(context) && context.rdSkin == null;
    final theme = Theme.of(context);
    final enabled = onChanged != null && items != null && items!.isNotEmpty;
    final selected =
        _selectedChild<T>(context, items, value, selectedItemBuilder);
    final placeholder = enabled ? hint : (disabledHint ?? hint);
    final baseStyle = style ??
        TextStyle(fontSize: 16, color: theme.colorScheme.onSurface);
    final label = DefaultTextStyle.merge(
      style: selected == null
          ? baseStyle.copyWith(color: theme.hintColor)
          : baseStyle,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      child: selected ?? placeholder ?? const SizedBox.shrink(),
    );
    final trigger = Builder(
      builder: (triggerContext) => _SelectTrigger(
        focusNode: focusNode,
        autofocus: autofocus,
        onTap: !enabled
            ? null
            : () async {
                onTap?.call();
                final picked = await showAppSelect<T>(
                  context: triggerContext,
                  options: AppSelectOption.fromMenuItems<T>(items!),
                  value: value,
                  interface: interface,
                  header: header,
                );
                if (picked != null && picked.value != value) {
                  onChanged!(picked.value);
                }
              },
        child: Semantics(
          button: true,
          enabled: enabled,
          child: ConstrainedBox(
            // md: the 48px of the Material button it replaces (an md
            // `ion-item` is 48px high).
            constraints: BoxConstraints(minHeight: isDense ? 24 : (md ? 48 : 44)),
            child: Row(
              mainAxisSize: isExpanded ? MainAxisSize.max : MainAxisSize.min,
              children: [
                if (isExpanded) Expanded(child: label) else Flexible(child: label),
                SizedBox(width: _selectIconGap(context)),
                _selectToggleIcon(context, enabled: enabled),
              ],
            ),
          ),
        ),
      ),
    );
    // md: [DropdownButton] applied [padding] around the button.
    final padding = this.padding;
    if (md && padding != null) return Padding(padding: padding, child: trigger);
    return trigger;
  }
}
