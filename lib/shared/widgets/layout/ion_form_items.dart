import 'package:flutter/material.dart';
import 'package:attendix/core/theme/app_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/l10n.dart';
import '../adaptive/adaptive_platform.dart';
import '../adaptive/app_select.dart' show IonSelectIcon, IonMdSelectIcon;
import '../adaptive/app_spinner.dart';
import '../adaptive/app_toolbar.dart' show IosCircleIcon;
import '../adaptive/app_dialog.dart' show showAppDialog;
import 'ionic_ios.dart' as ios27;
import 'ionic_md.dart';

// KP2_EINSTELLUNGEN_B: Ionic form items for the classic design in BOTH
// looks (iOS and md): `ion-item` + stacked label + `ion-input` /
// `ion-textarea`, `ion-item` + `ion-select`, the custom arrow-back header
// button, `ion-button expand="full"` and `ion-loading`.
//
// These widgets are classic-only: callers that can render under the Beta
// skin keep their previous widgets behind `context.rdSkin != null`.

/// `ion-item` line: iOS 0.55px hairline (ios27 step-100), md 1px
/// `rgba(0,0,0,.13)`; inset from the item padding-start (16).
BorderSide _itemLine(BuildContext context, {bool focused = false}) {
  final ios = useIosLook(context);
  final dark = Theme.of(context).brightness == Brightness.dark;
  // md `.item-has-focus`: 2px highlight in the primary colour (iOS has
  // `--highlight-height: 0`).
  if (focused && !ios) return const BorderSide(color: AppColors.primary, width: 2);
  if (ios) return BorderSide(color: ios27.IonIos.line(Theme.of(context).brightness), width: 0.55);
  return BorderSide(color: dark ? const Color(0xFF222222) : const Color(0x21000000), width: 1);
}

/// Metrics of a legacy `<ion-label position="stacked">` item (measured on
/// the Ionic app, see `IonStackedItemMetrics.legacy` of the login page):
/// iOS label 14.875 (18 high) above a 17px input, md label 12px (15 high)
/// above a 16px input; 20px text line.
class _StackedMetrics {
  const _StackedMetrics(this.ios)
      : labelSize = ios ? 14.875 : 12,
        labelHeight = ios ? 18 : 15,
        inputTop = ios ? 10 : 7,
        inputBottom = ios ? 10 : 10,
        inputSize = ios ? 17 : 16;

  final bool ios;
  final double labelSize;
  final double labelHeight;
  final double inputTop;
  final double inputBottom;
  final double inputSize;

  static const double lineHeight = 20;
  static const double itemTop = 10;
}

/// Ionic `ion-item` with `<ion-label position="stacked">` and an
/// `ion-input` / `ion-textarea` below it, in both looks: label above the
/// value, borderless input, the item line below (md: 2px primary highlight
/// and primary label while focused), optional `helperText` and an end slot
/// (e.g. `<ion-button slot="end" fill="clear">`).
///
/// ```dart
/// IonStackedInputItem(
///   label: l10n.typeSettingsName,
///   controller: nameController,
///   placeholder: l10n.instrumentsGroupPh,
/// )
/// IonStackedInputItem(label: l10n.peopleNotes, controller: notes, textarea: true)
/// ```
class IonStackedInputItem extends StatefulWidget {
  const IonStackedInputItem({
    super.key,
    required this.label,
    required this.controller,
    this.placeholder,
    this.helper,
    this.textarea = false,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.sentences,
    this.autofocus = false,
    this.enabled = true,
    this.readOnly = false,
    this.onTap,
    this.onChanged,
    this.validator,
    this.end,
    this.lines = true,
    this.obscureText = false,
  });

  final String label;
  final TextEditingController controller;

  /// Ionic `placeholder`.
  final String? placeholder;

  /// Ionic `helperText` (12px below the input).
  final String? helper;

  /// `ion-textarea autoGrow`: grows with its text.
  final bool textarea;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final bool autofocus;
  final bool enabled;

  /// Ionic `readonly` (e.g. a date input that opens a picker on [onTap]).
  final bool readOnly;
  final VoidCallback? onTap;
  final ValueChanged<String>? onChanged;

  /// Form validation (the error text shows below the input in danger).
  final FormFieldValidator<String>? validator;

  /// `slot="end"` content, vertically centred in the item.
  final Widget? end;

  /// False = `lines="none"`.
  final bool lines;
  final bool obscureText;

  @override
  State<IonStackedInputItem> createState() => _IonStackedInputItemState();
}

class _IonStackedInputItemState extends State<IonStackedInputItem> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ios = useIosLook(context);
    final m = _StackedMetrics(ios);
    final dark = theme.brightness == Brightness.dark;
    final text = ios ? (theme.brightness == Brightness.dark ? Colors.white : Colors.black) : IonMd.text(theme.brightness);
    final helperColor = dark ? const Color(0xFF8C8C8C) : const Color(0xFF737373);
    final inputStyle = TextStyle(
      fontSize: m.inputSize,
      height: _StackedMetrics.lineHeight / m.inputSize,
      color: text,
      letterSpacing: 0,
    );
    final decoration = InputDecoration(
      hintText: widget.placeholder,
      hintStyle: inputStyle.copyWith(color: text.withValues(alpha: 0.6)),
      helperText: widget.helper,
      helperMaxLines: 4,
      helperStyle: TextStyle(fontSize: 12, color: helperColor, height: 1.3),
      errorMaxLines: 3,
      errorStyle: const TextStyle(fontSize: 12, color: AppColors.danger),
      isDense: true,
      filled: false,
      contentPadding: EdgeInsets.only(top: m.inputTop, bottom: m.inputBottom),
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      errorBorder: InputBorder.none,
      focusedErrorBorder: InputBorder.none,
      disabledBorder: InputBorder.none,
    );
    final multiline = widget.textarea;
    final Widget field = widget.validator != null
        ? TextFormField(
            controller: widget.controller,
            decoration: decoration,
            style: inputStyle,
            autofocus: widget.autofocus,
            enabled: widget.enabled,
            readOnly: widget.readOnly,
            onTap: widget.onTap,
            onChanged: widget.onChanged,
            validator: widget.validator,
            obscureText: widget.obscureText,
            keyboardType: widget.keyboardType ?? (multiline ? TextInputType.multiline : null),
            textCapitalization: widget.textCapitalization,
            minLines: multiline ? 1 : null,
            maxLines: multiline ? null : 1,
          )
        : TextField(
            controller: widget.controller,
            decoration: decoration,
            style: inputStyle,
            autofocus: widget.autofocus,
            enabled: widget.enabled,
            readOnly: widget.readOnly,
            onTap: widget.onTap,
            onChanged: widget.onChanged,
            obscureText: widget.obscureText,
            keyboardType: widget.keyboardType ?? (multiline ? TextInputType.multiline : null),
            textCapitalization: widget.textCapitalization,
            minLines: multiline ? 1 : null,
            maxLines: multiline ? null : 1,
          );
    final labelColor = _focused && !ios ? AppColors.primary : text;
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: (f) => setState(() => _focused = f),
      child: _IonItemFrame(
        lines: widget.lines,
        focused: _focused,
        child: Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: _StackedMetrics.itemTop),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: m.labelHeight,
                      child: Text(
                        widget.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: m.labelSize,
                          height: m.labelHeight / m.labelSize,
                          color: labelColor,
                        ),
                      ),
                    ),
                    // Ionic metrics are absolute: no compact desktop density.
                    Theme(
                      data: theme.copyWith(visualDensity: VisualDensity.standard),
                      child: field,
                    ),
                  ],
                ),
              ),
            ),
            if (widget.end != null) ...[const SizedBox(width: 8), widget.end!],
          ],
        ),
      ),
    );
  }
}

/// `ion-item` box: padding-start 16, the inner part (label … end slot)
/// carries the inset bottom line and padding-end 16 (iOS native
/// padding-end: 16 as well).
class _IonItemFrame extends StatelessWidget {
  const _IonItemFrame({
    required this.child,
    this.lines = true,
    this.focused = false,
    this.minHeight = 0,
  });

  final Widget child;
  final bool lines;
  final bool focused;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16),
      child: Container(
        constraints: BoxConstraints(minHeight: minHeight),
        padding: const EdgeInsets.only(right: 16),
        // The 2px md focus highlight is painted over the 1px line so the
        // item height never changes.
        foregroundDecoration: lines || focused
            ? BoxDecoration(border: Border(bottom: _itemLine(context, focused: focused)))
            : null,
        child: child,
      ),
    );
  }
}

/// Ionic `ion-item` with an `ion-select` in both looks:
///
/// * [stacked] (`<ion-label position="stacked">` + `ion-select`, or
///   `labelPlacement="stacked"`): label above, the value below followed by
///   the select icon,
/// * otherwise (`[label]` with the default `labelPlacement="start"`): label
///   at the start, the value at the end, then the icon.
///
/// [onOpen] gets the value's context to anchor a popover; it should
/// open [showAppSelect] / `showAppMultiSelect`. The md caret turns while
/// the select is open.
class IonSelectItem extends StatefulWidget {
  const IonSelectItem({
    super.key,
    required this.label,
    required this.value,
    required this.onOpen,
    this.placeholder,
    this.stacked = false,
    this.lines = true,
  });

  final String label;

  /// The display text of the selection (Ionic joins multiple values with
  /// ", "); empty or null shows [placeholder].
  final String? value;
  final String? placeholder;
  final Future<void> Function(BuildContext anchor)? onOpen;
  final bool stacked;
  final bool lines;

  @override
  State<IonSelectItem> createState() => _IonSelectItemState();
}

class _IonSelectItemState extends State<IonSelectItem> {
  bool _open = false;

  Future<void> _tap(BuildContext anchor) async {
    final onOpen = widget.onOpen;
    if (onOpen == null) return;
    setState(() => _open = true);
    try {
      await onOpen(anchor);
    } finally {
      if (mounted) setState(() => _open = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ios = useIosLook(context);
    final m = _StackedMetrics(ios);
    final text = ios ? (theme.brightness == Brightness.dark ? Colors.white : Colors.black) : IonMd.text(theme.brightness);
    final hasValue = widget.value != null && widget.value!.isNotEmpty;
    final enabled = widget.onOpen != null;
    final valueText = Text(
      hasValue ? widget.value! : (widget.placeholder ?? ''),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: widget.stacked ? TextAlign.start : TextAlign.end,
      style: TextStyle(
        fontSize: m.inputSize,
        height: _StackedMetrics.lineHeight / m.inputSize,
        color: hasValue ? text : text.withValues(alpha: 0.6),
      ),
    );
    final icon = ios
        ? const IonSelectIcon()
        : IonMdSelectIcon(expanded: _open, color: _open && widget.stacked ? AppColors.primary : null);
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Semantics(
        button: true,
        enabled: enabled,
        label: widget.label,
        value: widget.value,
        child: Builder(
          builder: (anchor) => InkWell(
            onTap: enabled ? () => _tap(anchor) : null,
            splashFactory: ios ? NoSplash.splashFactory : null,
            child: _IonItemFrame(
              lines: widget.lines,
              focused: _open && widget.stacked,
              minHeight: widget.stacked ? 0 : (ios ? 44 : IonMd.itemMinHeight),
              child: widget.stacked
                  ? Padding(
                      padding: EdgeInsets.only(
                          top: _StackedMetrics.itemTop, bottom: m.inputBottom),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            height: m.labelHeight,
                            child: Text(
                              widget.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: m.labelSize,
                                height: m.labelHeight / m.labelSize,
                                color: _open && !ios ? AppColors.primary : text,
                              ),
                            ),
                          ),
                          SizedBox(height: m.inputTop),
                          Row(
                            children: [
                              Expanded(child: valueText),
                              const SizedBox(width: 8),
                              icon,
                            ],
                          ),
                        ],
                      ),
                    )
                  : Row(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Text(
                            widget.label,
                            style: TextStyle(
                              fontSize: ios ? 17 : 16,
                              color: text,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(child: valueText),
                        const SizedBox(width: 8),
                        icon,
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Ionic `ion-button expand="full"`: full width, no radius, no side
/// margin (e.g. the "Hinzufügen" button of the add sheets).
class IonFullButton extends StatelessWidget {
  const IonFullButton({super.key, required this.child, required this.onPressed});

  final Widget child;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).filledButtonTheme.style ?? const ButtonStyle();
    return Padding(
      // ion-button margin: 4px 0 (expand="full" drops the inline margin).
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: onPressed,
          style: base.copyWith(
            shape: const WidgetStatePropertyAll(RoundedRectangleBorder()),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// The custom Ionic header button
/// `<ion-buttons slot="start"><ion-button><ion-icon name="arrow-back">`
/// (help, delete account, role permissions, handover …): iOS the glass
/// circle with the arrow (like the files page), md a plain arrow icon
/// button. Use with `leadingWidth: IonArrowBackButton.leadingWidth(context)`.
class IonArrowBackButton extends StatelessWidget {
  const IonArrowBackButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  /// `AppBar.leadingWidth`: iOS 12 + 48 + 12, md the default.
  static double? leadingWidth(BuildContext context) => useIosLook(context) ? 72 : null;

  @override
  Widget build(BuildContext context) {
    if (!useIosLook(context)) {
      return IconButton(
        icon: Icon(AppIcons.arrowBack, semanticLabel: context.l10n.commonBack),
        onPressed: onPressed,
      );
    }
    return Center(
      child: Semantics(
        button: true,
        label: MaterialLocalizations.of(context).backButtonTooltip,
        child: GestureDetector(
          onTap: onPressed,
          // Ionic `ion-buttons` glass around a clear icon-only
          // `ion-button` (28px ionicon) – larger than the 44pt circle.
          child: IosCircleIcon(icon: AppIcons.arrowBack, size: 48, iconSize: 24),
        ),
      ),
    );
  }
}

/// Handle of an open [showIonLoading] overlay.
class IonLoadingHandle {
  IonLoadingHandle._();

  Route<dynamic>? _route;
  bool _open = true;

  /// Closes exactly this overlay (also when other routes were pushed on
  /// top or it is not built yet).
  void dismiss() {
    if (!_open) return;
    _open = false;
    final route = _route;
    if (route != null && route.isActive) route.navigator?.removeRoute(route);
  }
}

/// Ionic `loadingController.create({ message })` (`ion-loading`): a
/// blocking overlay with a spinner and the [message] until
/// [IonLoadingHandle.dismiss] is called.
///
/// iOS: #f9f9f9 box (dark #1e1e1e) with radius 8, padding 24 / 34, bold
/// message; md: #f2f2f2 box (dark #1e1e1e) with radius 2, padding 24 and the
/// md shadow, primary spinner. Backdrop .3 (iOS) / .32 (md).
IonLoadingHandle showIonLoading(BuildContext context, {String? message}) {
  final handle = IonLoadingHandle._();
  showAppDialog<void>(
    context: context,
    barrierDismissible: false,
    useRootNavigator: true,
    builder: (ctx) {
      handle._route ??= ModalRoute.of(ctx);
      if (!handle._open) {
        // Dismissed before the first frame.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final route = handle._route;
          if (route != null && route.isActive) route.navigator?.removeRoute(route);
        });
      }
      return IonLoadingBox(message: message);
    },
  );
  return handle;
}

/// Runs [task] while an [showIonLoading] overlay with [message] is shown.
Future<T> withIonLoading<T>(
  BuildContext context,
  Future<T> Function() task, {
  String? message,
}) async {
  final handle = showIonLoading(context, message: message);
  try {
    return await task();
  } finally {
    handle.dismiss();
  }
}

/// The box of [showIonLoading] (`.loading-wrapper`).
class IonLoadingBox extends StatelessWidget {
  const IonLoadingBox({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final ios = useIosLook(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = dark ? const Color(0xFF1E1E1E) : (ios ? const Color(0xFFF9F9F9) : const Color(0xFFF2F2F2));
    final fg = dark ? const Color(0xFFDBDBDB) : const Color(0xFF262626);
    return PopScope(
      canPop: false,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: ios ? 270 : 280),
          child: Material(
            color: bg,
            elevation: ios ? 0 : 24,
            shadowColor: Colors.black,
            borderRadius: BorderRadius.circular(ios ? 8 : 2),
            child: Padding(
              padding: ios
                  ? const EdgeInsets.symmetric(horizontal: 34, vertical: 24)
                  : const EdgeInsets.all(24),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: AppSpinner(color: ios ? null : AppColors.primary),
                  ),
                  if (message != null && message!.isNotEmpty) ...[
                    const SizedBox(width: 16),
                    Flexible(
                      child: Text(
                        message!,
                        style: TextStyle(
                          fontSize: ios ? 14 : 15,
                          fontWeight: ios ? FontWeight.w600 : FontWeight.w400,
                          color: fg,
                          decoration: TextDecoration.none,
                        ),
                      ),
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
