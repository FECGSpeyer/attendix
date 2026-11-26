import 'dart:async';

import 'package:flutter/material.dart';
import 'package:attendix/core/theme/app_icons.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/redesign/rd_theme.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';
import '../../../../shared/widgets/layout/ionic_ios.dart'
    show IonTranslucentAppBar, IonContentTopInset, IonLargeTitle;
import '../../../../shared/widgets/display/ion_badge_text.dart';

/// Section header with optional trailing note/button.
class IonListHeader extends StatelessWidget {
  const IonListHeader({
    super.key,
    this.title = '',
    this.titleWidget,
    this.trailing,
    this.color,
    this.padding = const EdgeInsets.fromLTRB(16, 0, 4, 6),
    this.inset = false,
  });

  final String title;
  final Widget? titleWidget;
  final Widget? trailing;
  final Color? color;
  final EdgeInsetsGeometry padding;
  final bool inset;

  @override
  Widget build(BuildContext context) {
    final rd = context.rd;
    final style = inset ? RdType.eyebrow(color ?? rd.text2) : RdType.section(rd).copyWith(color: color);
    return Padding(
      padding: inset ? const EdgeInsets.fromLTRB(4, 4, 4, 6) : const EdgeInsets.fromLTRB(20, 16, 4, 8),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: titleWidget != null
                  ? DefaultTextStyle.merge(style: style, child: titleWidget!)
                  : Text(inset ? title.toUpperCase() : title, style: style),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Inset grouped list with an optional [IonListHeader].
class IonInsetList extends StatelessWidget {
  const IonInsetList({
    super.key,
    this.header,
    this.headerTrailing,
    this.headerColor,
    required this.children,
    this.dividerIndent = 16,
    this.margin = const EdgeInsets.fromLTRB(16, 16, 16, 0),
    this.headerWidget,
  });

  final String? header;
  final Widget? headerTrailing;
  final Color? headerColor;
  final Widget? headerWidget;
  final List<Widget> children;
  final double? dividerIndent;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final rd = context.rd;
    final head = headerWidget ??
        (header != null
            ? IonListHeader(title: header!, trailing: headerTrailing, color: headerColor, inset: true)
            : null);
    return Padding(
      padding: margin,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (head != null) head,
          if (children.isNotEmpty)
            DecoratedBox(
              decoration: BoxDecoration(
                color: rd.surface,
                borderRadius: BorderRadius.circular(rd.listRadius),
                boxShadow: rd.cardShadow,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(rd.listRadius),
                child: Material(
                  type: MaterialType.transparency,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < children.length; i++) ...[
                        if (i > 0 && dividerIndent != null) Divider(height: 1, thickness: 1, color: rd.line),
                        children[i],
                      ],
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Coloured badge pill.
class IonBadge extends StatelessWidget {
  const IonBadge({super.key, required this.label, required this.color, this.textColor});

  final String label;
  final Color color;
  final Color? textColor;

  static Color contrastOf(Color color) =>
      color == AppColors.warning || color == AppColors.orange || color == AppColors.mint ? Colors.black : Colors.white;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: ionBadgeTextStyle(color: textColor ?? contrastOf(color)),
        ),
      );
}

/// Secondary note text in an item end slot.
class IonNote extends StatelessWidget {
  const IonNote(this.text, {super.key, this.style});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: TextStyle(color: context.rd.text2, fontSize: 14).merge(style),
      );
}

/// Trailing detail chevron of a tappable row.
class IonDetailIcon extends StatelessWidget {
  const IonDetailIcon({super.key});

  @override
  Widget build(BuildContext context) => Icon(
        AppIcons.chevronRight,
        size: 20,
        color: context.rd.text2.withValues(alpha: 0.6),
      );
}

/// Ionic empty/hint state (icon, optional bold line, grey text, optional action).
class IonEmptyState extends StatelessWidget {
  const IonEmptyState({
    super.key,
    required this.icon,
    this.title,
    required this.text,
    this.action,
    this.padding = const EdgeInsets.fromLTRB(24, 56, 24, 24),
    this.iconSize = 44,
  });

  final IconData icon;
  final String? title;
  final String text;
  final Widget? action;
  final EdgeInsetsGeometry padding;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: iconSize, color: AppColors.mediumOf(context)),
              const SizedBox(height: 12),
              if (title != null) ...[
                Text(
                  title!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
              ],
              if (text.isNotEmpty)
                Text(text, textAlign: TextAlign.center, style: TextStyle(color: AppColors.mediumOf(context))),
              if (action != null) ...[const SizedBox(height: 8), action!],
            ],
          ),
        ),
      ),
    );
  }
}

/// Ionic `ion-searchbar`: the iOS search field (grey rounded, magnifier,
/// clear button) on iOS, a Material search field elsewhere.
class IonSearchbar extends StatefulWidget {
  const IonSearchbar({
    super.key,
    required this.placeholder,
    required this.onChanged,
    this.controller,
    this.padding,
  });

  final String placeholder;

  /// Optional external controller (e.g. to clear the search programmatically).
  final TextEditingController? controller;
  final ValueChanged<String> onChanged;

  /// Optional host padding around the search field.
  final EdgeInsetsGeometry? padding;

  @override
  State<IonSearchbar> createState() => _IonSearchbarState();
}

class _IonSearchbarState extends State<IonSearchbar> {
  TextEditingController? _own;

  TextEditingController get _controller => widget.controller ?? (_own ??= TextEditingController());

  @override
  void dispose() {
    _own?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rd = context.rd;
    return Padding(
      padding: widget.padding ?? const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: _controller,
        builder: (context, value, _) => TextField(
          controller: _controller,
          onChanged: widget.onChanged,
          textAlignVertical: TextAlignVertical.center,
          decoration: InputDecoration(
            hintText: widget.placeholder,
            hintStyle: TextStyle(color: rd.text2),
            prefixIcon: Icon(AppIcons.search, size: 20, color: rd.text2),
            suffixIcon: value.text.isEmpty
                ? null
                : IconButton(
                    tooltip: context.l10n.commonClose,
                    icon: Icon(AppIcons.close, size: 18, color: rd.text2),
                    onPressed: () {
                      _controller.clear();
                      widget.onChanged('');
                    },
                  ),
            isDense: true,
            filled: true,
            fillColor: rd.soft,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ),
    );
  }
}

/// Segmented control in a header toolbar driving a [TabController].
class IonSegmentBar extends StatefulWidget implements PreferredSizeWidget {
  const IonSegmentBar({super.key, required this.controller, required this.labels});

  final TabController controller;
  final List<String> labels;

  @override
  Size get preferredSize => const Size.fromHeight(48);

  @override
  State<IonSegmentBar> createState() => _IonSegmentBarState();
}

class _IonSegmentBarState extends State<IonSegmentBar> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTab);
  }

  @override
  void didUpdateWidget(covariant IonSegmentBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onTab);
      widget.controller.addListener(_onTab);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTab);
    super.dispose();
  }

  void _onTab() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: IonSegment<int>(
        items: [
          for (var i = 0; i < widget.labels.length; i++)
            IonSegmentItem<int>(value: i, label: Text(widget.labels[i])),
        ],
        value: widget.controller.index,
        onChanged: (v) => widget.controller.animateTo(v),
      ),
    );
  }
}

/// Ionic `ion-chip` filter row item (`outline` when not selected).
class IonFilterChip extends StatelessWidget {
  const IonFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.selectedColor = AppColors.primaryDark,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color selectedColor;

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).cardTheme.color ?? Theme.of(context).colorScheme.surface;
    return Material(
      color: selected ? selectedColor : surface,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

/// Decoration of an `ion-input labelPlacement="stacked"` inside an item:
/// small label above the value, no field box.
InputDecoration ionStackedInputDecoration({required String label, String? hint}) => InputDecoration(
      labelText: label,
      hintText: hint,
      floatingLabelBehavior: FloatingLabelBehavior.always,
      filled: false,
      isDense: true,
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      disabledBorder: InputBorder.none,
      errorBorder: InputBorder.none,
      focusedErrorBorder: InputBorder.none,
      contentPadding: const EdgeInsets.only(top: 6, bottom: 4),
    );

/// Ionic `ion-item` > `ion-input`/`ion-textarea` with a stacked label.
class IonStackedInput extends StatelessWidget {
  const IonStackedInput({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.minLines,
    this.maxLines = 1,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.sentences,
    this.onChanged,
    this.onFocusLost,
    this.enabled = true,
    this.autofocus = false,
    this.helper,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final int? minLines;
  final int? maxLines;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final ValueChanged<String>? onChanged;

  /// Ionic `(ionBlur)`.
  final VoidCallback? onFocusLost;
  final bool enabled;
  final bool autofocus;

  /// Ionic `helperText` shown below the input.
  final String? helper;

  @override
  Widget build(BuildContext context) {
    Widget field = TextField(
      controller: controller,
      enabled: enabled,
      autofocus: autofocus,
      minLines: minLines,
      maxLines: maxLines,
      keyboardType: keyboardType ?? (maxLines == 1 ? null : TextInputType.multiline),
      textCapitalization: textCapitalization,
      decoration: ionStackedInputDecoration(label: label, hint: hint).copyWith(
        helperText: helper,
        helperMaxLines: 4,
      ),
      onChanged: onChanged,
    );
    if (onFocusLost != null) {
      field = Focus(
        onFocusChange: (f) {
          if (!f) onFocusLost!();
        },
        child: field,
      );
    }
    return Padding(padding: const EdgeInsets.fromLTRB(16, 10, 16, 6), child: field);
  }
}

/// Ionic `ion-item` > `ion-input` with the label on the left and the value
/// right aligned (`class="ion-text-end"`).
class IonInlineInput extends StatelessWidget {
  const IonInlineInput({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.keyboardType,
    this.onChanged,
    this.inputFormatters,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final List<TextInputFormatter>? inputFormatters;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(width: 16),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
              textAlign: TextAlign.end,
              inputFormatters: inputFormatters,
              decoration: ionStackedInputDecoration(label: '', hint: hint).copyWith(
                labelText: null,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

/// Ionic `ion-select` inside an `ion-item`: the label on the left, the
/// selected value (grey) with a caret on the right, no field box.
class IonSelect<T> extends StatelessWidget {
  const IonSelect({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.leading,
    this.interface = AppSelectInterface.popover,
  });

  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final Widget? leading;

  /// Ionic `ion-select interface` (the alert's header is [label]; the
  /// modal has no title, like an `ion-select` without `interfaceOptions`).
  final AppSelectInterface interface;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 12),
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 16)],
          Text(label, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(width: 16),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: AppDropdownButton<T>(
                interface: interface,
                header: interface == AppSelectInterface.modal ? null : label,
                value: value,
                isExpanded: true,
                alignment: AlignmentDirectional.centerEnd,
                items: items,
                selectedItemBuilder: (context) => [
                  for (final it in items)
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: DefaultTextStyle.merge(
                        style: TextStyle(color: AppColors.mediumOf(context)),
                        overflow: TextOverflow.ellipsis,
                        child: it.child,
                      ),
                    ),
                ],
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Ionic `ion-datetime-button`: grey rounded chip showing the date/time
/// (no "Uhr" suffix). Without [onTap] it is read-only (disabled datetime).
/// QUE-28: the shared [IonDatetimeButton] under its old name; [disabled]
/// is Ionic's `[disabled]` on the button (40 % opacity).
class IonDatetimeChip extends StatelessWidget {
  const IonDatetimeChip({super.key, required this.text, this.onTap, this.disabled = false});

  final String text;
  final FutureOr<void> Function()? onTap;
  final bool disabled;

  @override
  Widget build(BuildContext context) => IonDatetimeButton(
        date: text,
        onDateTap: onTap,
        disabled: disabled,
        betaStyle: Theme.of(context).textTheme.bodyLarge,
      );
}

/// Ionic `ion-header collapse="condense"`: on iOS the page shows a large
/// title at the top of the content that condenses into the toolbar title
/// when scrolled. Elsewhere it is a normal [AppBar] page.
class IonCondenseScaffold extends StatefulWidget {
  const IonCondenseScaffold({
    super.key,
    required this.title,
    required this.bodyBuilder,
    this.actions,
    this.leading,
    this.automaticallyImplyLeading = true,
    this.floatingActionButton,
    this.backgroundColor,
  });

  final String title;

  /// Builds the scrollable body; [largeTitle] (iOS only, else null) must be
  /// the first child of the scroll view.
  final Widget Function(BuildContext context, Widget? largeTitle) bodyBuilder;
  final List<Widget>? actions;
  final Widget? leading;
  final bool automaticallyImplyLeading;
  final Widget? floatingActionButton;
  final Color? backgroundColor;

  @override
  State<IonCondenseScaffold> createState() => _IonCondenseScaffoldState();
}

class _IonCondenseScaffoldState extends State<IonCondenseScaffold> {
  bool _condensed = false;

  bool _onScroll(ScrollNotification n) {
    if (n.depth != 0 || n.metrics.axis != Axis.vertical) return false;
    final condensed = n.metrics.pixels > 40;
    if (condensed != _condensed) setState(() => _condensed = condensed);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final ios = Theme.of(context).platform == TargetPlatform.iOS;
    return Scaffold(
      backgroundColor: widget.backgroundColor,
      floatingActionButton: widget.floatingActionButton,
      extendBodyBehindAppBar: ios,
      appBar: IonTranslucentAppBar(
        condensed: _condensed,
        background: widget.backgroundColor,
        child: AppBar(
          leading: widget.leading,
          automaticallyImplyLeading: widget.automaticallyImplyLeading,
          title: ios
              ? AnimatedOpacity(
                  opacity: _condensed ? 1 : 0,
                  duration: const Duration(milliseconds: 150),
                  child: Text(widget.title),
                )
              : Text(widget.title),
          actions: widget.actions,
        ),
      ),
      body: ios
          ? NotificationListener<ScrollNotification>(
              onNotification: _onScroll,
              child: widget.bodyBuilder(
                context,
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const IonContentTopInset(),
                    IonLargeTitle(widget.title),
                  ],
                ),
              ),
            )
          : widget.bodyBuilder(context, null),
    );
  }
}

/// Filled or outline chip.
class IonChip extends StatelessWidget {
  const IonChip({
    super.key,
    required this.label,
    required this.color,
    this.outline = false,
    this.disabled = false,
    this.icon,
    this.onTap,
  });

  final String label;
  final Color color;
  final bool outline;
  final bool disabled;
  final IconData? icon;
  final VoidCallback? onTap;

  Widget _label() => Text(
        label,
        style: TextStyle(fontSize: 14, height: 20 / 14, color: color),
      );

  @override
  Widget build(BuildContext context) {
    final shape = StadiumBorder(
      side: outline ? BorderSide(color: color.withValues(alpha: 0.32)) : BorderSide.none,
    );
    return Opacity(
      opacity: disabled ? 0.4 : 1,
      child: Material(
        color: outline ? Colors.transparent : color.withValues(alpha: 0.08),
        shape: shape,
        child: InkWell(
          customBorder: shape,
          onTap: disabled ? null : onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: icon == null
                ? _label()
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 20, color: color),
                      const SizedBox(width: 4),
                      Flexible(child: _label()),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
