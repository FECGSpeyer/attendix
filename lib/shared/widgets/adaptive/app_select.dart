import 'dart:math' as math;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import 'adaptive_platform.dart';
import 'app_action_sheet.dart';
import 'app_dialog.dart';

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
/// Material (Android / desktop, Ionic md mode) keeps the Flutter dropdowns:
/// [AppDropdownFormField] / [AppDropdownButton] are drop-in replacements for
/// [DropdownButtonFormField] / [DropdownButton] that build exactly those
/// widgets outside iOS.

/// Ionic `ion-select` `interface`.
enum AppSelectInterface {
  /// `interface="popover"`.
  popover,

  /// `interface="alert"` – Ionic's default when no interface is set.
  alert,

  /// `interface="action-sheet"`.
  actionSheet,
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
const double kIosPopoverRadius = 24;

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
    CupertinoIcons.chevron_up_chevron_down,
    size: size,
    color: color ?? colorOf(context),
  );
}

/// Opens the select for [options] (current value [value]).
///
/// [context] is the trigger (the select's value); its box anchors the iOS
/// popover. [cover] makes the popover as wide as the trigger (Ionic
/// floating / stacked label). [header] is the alert / action sheet title.
///
/// Outside iOS a Material menu opens at the trigger.
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

  if (!useIosLook(context)) {
    final picked = await showMenu<AppSelection<T>>(
      context: context,
      position: RelativeRect.fromRect(anchor, Offset.zero & overlay.size),
      items: [
        for (final o in options)
          PopupMenuItem<AppSelection<T>>(
            value: AppSelection<T>(o.value),
            enabled: o.enabled,
            child: o.child ?? Text(o.label!),
          ),
      ],
    );
    return picked;
  }

  switch (interface) {
    case AppSelectInterface.popover:
      return navigator.push<AppSelection<T>>(
        _IosSelectPopoverRoute<T>(
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
        builder: (_) =>
            _IosSelectAlert<T>(header: header, options: options, value: value),
      );
    case AppSelectInterface.actionSheet:
      return showAppActionSheet<AppSelection<T>>(
        context,
        title: header,
        actions: [
          for (final o in options)
            AppActionSheetAction<AppSelection<T>>(
              value: AppSelection<T>(o.value),
              label: o.textOr('${o.value}'),
              enabled: o.enabled,
            ),
        ],
      );
  }
}

// ---------------------------------------------------------------------------
// iOS popover
// ---------------------------------------------------------------------------

class _IosSelectPopoverRoute<T> extends PopupRoute<AppSelection<T>> {
  _IosSelectPopoverRoute({
    required this.anchor,
    required this.overlaySize,
    required this.options,
    required this.value,
    required this.cover,
    required this.barrierLabel,
    required this.capturedThemes,
  });

  final Rect anchor;
  final Size overlaySize;
  final List<AppSelectOption<T>> options;
  final T? value;
  final bool cover;
  final CapturedThemes capturedThemes;

  @override
  final String barrierLabel;

  /// ionic-theme-ios26 `ion-popover.ios { --backdrop-opacity: .2 }`.
  @override
  Color? get barrierColor => const Color(0x33000000);

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
    const margin = 8.0;
    final maxW = overlaySize.width - 2 * margin;
    final w = cover
        ? math.min(math.max(anchor.width, kIosSelectPopoverWidth), maxW)
        : math.min(kIosSelectPopoverWidth, maxW);
    // Centred on the value (cover: aligned with the field), kept on screen.
    final preferredLeft = cover ? anchor.left : anchor.center.dx - w / 2;
    final left = preferredLeft
        .clamp(margin, math.max(margin, overlaySize.width - w - margin))
        .toDouble();
    final spaceBelow =
        overlaySize.height - anchor.bottom - media.padding.bottom - margin;
    final spaceAbove = anchor.top - media.padding.top - margin;
    // global.scss: `ion-select-popover ion-list { max-height: 23rem }`.
    const listMax = 368.0;
    final rowsHeight = math.min(listMax, options.length * 45.0 + 12);
    final below = spaceBelow >= math.min(rowsHeight, 160) || spaceBelow >= spaceAbove;
    final maxHeight = math.max(
      88.0,
      math.min(listMax, (below ? spaceBelow : spaceAbove) - 6),
    );
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeIn,
    );
    final card = FadeTransition(
      opacity: curved,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.85, end: 1).animate(curved),
        alignment: below ? Alignment.topCenter : Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: _IosSelectPopoverCard<T>(options: options, value: value),
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
              Positioned(top: anchor.bottom + 6, left: left, width: w, child: card)
            else
              Positioned(
                bottom: overlaySize.height - anchor.top + 6,
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
    return IosGlassSurface(
      borderRadius: const BorderRadius.all(Radius.circular(kIosPopoverRadius)),
      opacity: 0.9,
      blur: 20,
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
  });

  final AppSelectOption<T> option;
  final bool checked;
  final VoidCallback onTap;
  final bool primaryLabelWhenChecked;
  final double minHeight;

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
          highlightColor: IosGlass.overlayButton(theme.brightness),
          hoverColor: Colors.transparent,
          focusColor: Colors.transparent,
          onTap: option.enabled ? onTap : null,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: minHeight),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 14, 10),
              child: Row(
                children: [
                  Expanded(
                    child: DefaultTextStyle.merge(
                      style: TextStyle(fontSize: 16, color: fg),
                      child: IconTheme.merge(
                        data: IconThemeData(color: fg, size: 20),
                        child: option.child ?? Text(option.label!),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 20,
                    child: checked
                        ? Icon(Icons.check, size: 20, color: primary)
                        : null,
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
// Drop-in dropdowns
// ---------------------------------------------------------------------------

Widget? _selectedChild<T>(
  BuildContext context,
  List<DropdownMenuItem<T>>? items,
  T? value,
  DropdownButtonBuilder? selectedItemBuilder,
) {
  if (items == null) return null;
  final index = items.indexWhere((i) => i.value == value);
  if (index < 0) return null;
  if (selectedItemBuilder != null) {
    final built = selectedItemBuilder(context);
    if (index < built.length) return built[index];
  }
  return items[index].child;
}

/// IOS_THEME2: drop-in replacement for [DropdownButtonFormField].
///
/// Outside iOS it builds a [DropdownButtonFormField] with the same
/// parameters. On iOS the field keeps its [decoration] (label, borders,
/// errors, validator) but shows the value with the `chevron-expand` icon and
/// opens [showAppSelect] with [iosInterface] (match the Ionic page's
/// `ion-select interface`).
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
    this.iosInterface = AppSelectInterface.popover,
    this.iosHeader,
  });

  final List<DropdownMenuItem<T>>? items;
  final DropdownButtonBuilder? selectedItemBuilder;
  final T? value;
  final Widget? hint;
  final Widget? disabledHint;
  final ValueChanged<T?>? onChanged;
  final VoidCallback? onTap;
  final TextStyle? style;
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

  /// Ionic `ion-select interface` on iOS.
  final AppSelectInterface iosInterface;

  /// Alert / action sheet header (default: the decoration's label).
  final String? iosHeader;

  @override
  Widget build(BuildContext context) {
    if (!useIosLook(context)) {
      return DropdownButtonFormField<T>(
        items: items,
        selectedItemBuilder: selectedItemBuilder,
        value: value,
        hint: hint,
        disabledHint: disabledHint,
        onChanged: onChanged,
        onTap: onTap,
        style: style,
        icon: icon,
        isDense: isDense,
        isExpanded: isExpanded,
        itemHeight: itemHeight,
        focusNode: focusNode,
        autofocus: autofocus,
        dropdownColor: dropdownColor,
        decoration: decoration,
        onSaved: onSaved,
        validator: validator,
        autovalidateMode: autovalidateMode,
        menuMaxHeight: menuMaxHeight,
        alignment: alignment,
        borderRadius: borderRadius,
        padding: padding,
      );
    }
    return _IosSelectFormField<T>(
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
      interface: iosInterface,
      header: iosHeader,
    );
  }
}

class _IosSelectFormField<T> extends FormField<T> {
  _IosSelectFormField({
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
  }) : super(
         initialValue: value,
         autovalidateMode: autovalidateMode ?? AutovalidateMode.disabled,
         builder: (field) {
           final context = field.context;
           final theme = Theme.of(context);
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
             builder: (triggerContext) => GestureDetector(
               behavior: HitTestBehavior.opaque,
               onTap: !enabled
                   ? null
                   : () async {
                       onTap?.call();
                       final picked = await showAppSelect<T>(
                         context: triggerContext,
                         options: AppSelectOption.fromMenuItems<T>(items),
                         value: current,
                         interface: interface,
                         header: header ?? labelText,
                         cover: cover,
                       );
                       if (picked == null) return;
                       field.didChange(picked.value);
                       if (picked.value != current) onChanged(picked.value);
                     },
               child: Semantics(
                 button: true,
                 enabled: enabled,
                 child: InputDecorator(
                   decoration: effective,
                   isEmpty: selected == null && placeholder == null,
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
                       const SizedBox(width: 6),
                       Opacity(
                         opacity: enabled ? 1 : 0.4,
                         child: const IonSelectIcon(),
                       ),
                     ],
                   ),
                 ),
               ),
             ),
           );
         },
       );

  @override
  FormFieldState<T> createState() => _IosSelectFormFieldState<T>();
}

class _IosSelectFormFieldState<T> extends FormFieldState<T> {
  @override
  void didUpdateWidget(covariant _IosSelectFormField<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialValue != widget.initialValue) {
      setValue(widget.initialValue);
    }
  }
}

/// IOS_THEME2: drop-in replacement for [DropdownButton] (inline selects,
/// e.g. an `ion-select` at the end of an `ion-item`).
///
/// Outside iOS it builds a [DropdownButton] with the same parameters. On iOS
/// it shows the selected value + `chevron-expand` and opens [showAppSelect]
/// ([iosInterface], popover by default) anchored on the value.
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
    this.iosInterface = AppSelectInterface.popover,
    this.iosHeader,
  });

  final List<DropdownMenuItem<T>>? items;
  final DropdownButtonBuilder? selectedItemBuilder;
  final T? value;
  final Widget? hint;
  final Widget? disabledHint;
  final ValueChanged<T?>? onChanged;
  final VoidCallback? onTap;
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

  /// Ionic `ion-select interface` on iOS.
  final AppSelectInterface iosInterface;

  /// Alert / action sheet header.
  final String? iosHeader;

  @override
  Widget build(BuildContext context) {
    if (!useIosLook(context)) {
      return DropdownButton<T>(
        items: items,
        selectedItemBuilder: selectedItemBuilder,
        value: value,
        hint: hint,
        disabledHint: disabledHint,
        onChanged: onChanged,
        onTap: onTap,
        elevation: elevation,
        style: style,
        underline: underline,
        icon: icon,
        iconSize: iconSize,
        isDense: isDense,
        isExpanded: isExpanded,
        itemHeight: itemHeight,
        focusColor: focusColor,
        focusNode: focusNode,
        autofocus: autofocus,
        dropdownColor: dropdownColor,
        menuMaxHeight: menuMaxHeight,
        alignment: alignment,
        borderRadius: borderRadius,
        padding: padding,
      );
    }
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
    return Builder(
      builder: (triggerContext) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: !enabled
            ? null
            : () async {
                onTap?.call();
                final picked = await showAppSelect<T>(
                  context: triggerContext,
                  options: AppSelectOption.fromMenuItems<T>(items!),
                  value: value,
                  interface: iosInterface,
                  header: iosHeader,
                );
                if (picked != null && picked.value != value) {
                  onChanged!(picked.value);
                }
              },
        child: Semantics(
          button: true,
          enabled: enabled,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: isDense ? 24 : 44),
            child: Row(
              mainAxisSize: isExpanded ? MainAxisSize.max : MainAxisSize.min,
              children: [
                if (isExpanded) Expanded(child: label) else Flexible(child: label),
                const SizedBox(width: 6),
                Opacity(
                  opacity: enabled ? 1 : 0.4,
                  child: const IonSelectIcon(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
