import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/redesign/rd_palette.dart';
import '../../../core/theme/redesign/rd_theme.dart';
import 'app_action_sheet.dart';

/// Select presentation style (`ion-select` interface compatibility).
enum AppSelectInterface {
  popover,
  alert,
  actionSheet,
  modal,
}

/// The picked value of [showAppSelect] (wrapped so that a `null` option can
/// be told apart from a dismissed select).
class AppSelection<T> {
  const AppSelection(this.value);
  final T value;
}

/// One option of [showAppSelect].
class AppSelectOption<T> {
  const AppSelectOption({
    required this.value,
    this.label,
    this.child,
    this.enabled = true,
  }) : assert(label != null || child != null);

  final T value;
  final String? label;
  final Widget? child;
  final bool enabled;

  /// Options from Material [DropdownMenuItem]s (label = the item's [Text]).
  static List<AppSelectOption<T>> fromMenuItems<T>(
    List<DropdownMenuItem<T>> items,
  ) => [
    for (final i in items)
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

/// Opens the select menu for [options] (current value [value]).
Future<AppSelection<T>?> showAppSelect<T>({
  required BuildContext context,
  required List<AppSelectOption<T>> options,
  required T? value,
  AppSelectInterface interface = AppSelectInterface.popover,
  String? header,
  bool cover = false,
}) async {
  if (interface == AppSelectInterface.actionSheet) {
    return _showSelectActionSheet<T>(context, options, header);
  }
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
  return _showRdSelectMenu<T>(
    context: context,
    palette: context.rd,
    anchor: anchor,
    overlaySize: overlay.size,
    options: options,
    value: value,
  );
}

Future<AppSelection<T>?> _showSelectActionSheet<T>(
  BuildContext context,
  List<AppSelectOption<T>> options,
  String? header,
) {
  return showAppActionSheet<AppSelection<T>>(
    context,
    title: header,
    showCancel: false,
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

Widget _selectToggleIcon(BuildContext context, {required bool enabled}) {
  return Opacity(
    opacity: enabled ? 1 : 0.4,
    child: Icon(Icons.keyboard_arrow_down, size: 20, color: context.rd.text2),
  );
}

const double _selectIconGap = 6;

Widget? _selectedChild<T>(
  BuildContext context,
  List<DropdownMenuItem<T>>? items,
  T? value,
  DropdownButtonBuilder? selectedItemBuilder,
) {
  if (items == null) return null;
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
          child: widget.child,
        ),
      ),
    );
  }
}

/// Drop-in replacement for [DropdownButtonFormField].
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
  final AppSelectInterface interface;
  final String? header;

  @override
  Widget build(BuildContext context) {
    return _SelectFormField<T>(
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
                 child: InputDecorator(
                   decoration: effective,
                   isEmpty: selected == null && placeholder == null,
                   isFocused: false,
                   child: Row(
                     children: [
                       Expanded(
                         child: DefaultTextStyle.merge(
                           style: selected == null
                               ? textStyle.copyWith(color: theme.hintColor)
                               : textStyle,
                           maxLines: 1,
                           overflow: TextOverflow.ellipsis,
                           child: selected ?? placeholder ?? const SizedBox.shrink(),
                         ),
                       ),
                       const SizedBox(width: _selectIconGap),
                       _selectToggleIcon(context, enabled: enabled),
                     ],
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

/// Drop-in replacement for [DropdownButton].
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
  final AppSelectInterface interface;
  final String? header;

  @override
  Widget build(BuildContext context) {
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
            constraints: BoxConstraints(minHeight: isDense ? 24 : 44),
            child: Row(
              mainAxisSize: isExpanded ? MainAxisSize.max : MainAxisSize.min,
              children: [
                if (isExpanded) Expanded(child: label) else Flexible(child: label),
                const SizedBox(width: _selectIconGap),
                _selectToggleIcon(context, enabled: enabled),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
