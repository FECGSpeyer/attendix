import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_icons.dart';
import '../../../core/theme/redesign/rd_theme.dart';
import 'adaptive_platform.dart';
import 'app_popover_menu.dart';
import 'app_select.dart';

/// One row of [showAppFilterPopover].
sealed class AppFilterRow {
  const AppFilterRow({required this.icon});

  /// `ion-icon slot="start" size="small"`.
  final IconData icon;
}

/// `ion-item` > `ion-select slot="end" interface="popover"`: the current
/// value with the select icon; a tap opens the options in a nested popover.
/// Choosing closes only that nested popover, the filter popover stays open.
class AppFilterSelect<T> extends AppFilterRow {
  const AppFilterSelect({
    required super.icon,
    required this.value,
    required this.options,
    required this.onSelected,
    this.placeholder,
  });

  final T value;
  final List<(T, String)> options;
  final FutureOr<void> Function(T value) onSelected;

  /// Shown in grey instead of the value (Ionic `placeholder`).
  final String? placeholder;

  String get _text {
    for (final o in options) {
      if (o.$1 == value) return o.$2;
    }
    return options.isEmpty ? '' : options.first.$2;
  }

  Future<void> _open(BuildContext trigger) async {
    final picked = await showAppSelect<T>(
      context: trigger,
      options: [for (final o in options) AppSelectOption<T>(value: o.$1, label: o.$2)],
      value: value,
    );
    if (picked != null) await onSelected(picked.value);
  }
}

/// `ion-select multiple interface="popover"`: the checked labels, comma
/// separated; a tap opens a nested popover with one checkbox per option
/// that stays open while options are switched.
class AppFilterMultiSelect<T> extends AppFilterRow {
  const AppFilterMultiSelect({
    required super.icon,
    required this.values,
    required this.options,
    required this.onChanged,
    this.popoverWidth,
  });

  /// Ionic `--width` of the nested popover when the page sets one (e.g.
  /// the Werke page: `ion-popover { --width: 18rem }`); default 200 / 250.
  final double? popoverWidth;

  /// Read again after every change, so the checkboxes follow.
  final List<T> Function() values;
  final List<(T, String)> options;
  final void Function(T value, bool selected) onChanged;

  String get _text {
    final current = values();
    return [
      for (final o in options)
        if (current.contains(o.$1)) o.$2,
    ].join(', ');
  }

  Future<void> _open(BuildContext trigger, VoidCallback changed) {
    return showAppPopover<void>(
      context: trigger,
      width: popoverWidth,
      // global.scss: `ion-select-popover ion-list { max-height: 23rem }`.
      maxHeight: 368,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) {
          final current = values();
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final o in options)
                _CheckRow(
                  label: o.$2,
                  checked: current.contains(o.$1),
                  onTap: () {
                    onChanged(o.$1, !current.contains(o.$1));
                    setLocal(() {});
                    changed();
                  },
                ),
            ],
          );
        },
      ),
    );
  }
}

/// `ion-item` with an `ion-toggle`.
class AppFilterToggle extends AppFilterRow {
  const AppFilterToggle({
    required super.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
}

/// `ion-item button detail="false"`: closes the popover and runs [onTap].
class AppFilterAction extends AppFilterRow {
  const AppFilterAction({
    required super.icon,
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;
}

/// The options popover behind a list's filter button (Ionic
/// `<ion-popover>` with an `ion-list lines="none"` of select, toggle and
/// button items, e.g. people `#filterPopover`, the Werke filter).
///
/// Like in Ionic the popover stays open while the selects are used: a
/// select opens its options in a nested popover, and a tap on an option or
/// beside the nested popover closes only that one. A tap beside the filter
/// popover closes it.
///
/// [context] must be the trigger button's context (use a [Builder]).
/// [rows] is read again after every change, so it has to build the rows
/// from the caller's current state. [width] is Ionic `--width` (people
/// list: 16rem).
Future<void> showAppFilterPopover({
  required BuildContext context,
  required List<AppFilterRow> Function() rows,
  double? width,
}) {
  final ios = useIosLook(context) && context.rdSkin == null;
  return showAppPopover<void>(
    context: context,
    // 16rem: 272pt with the 17pt iOS root font, 256px in md mode.
    width: width ?? (ios ? 272 : 256),
    builder: (_) => _FilterPopoverBody(rows: rows),
  );
}

class _FilterPopoverBody extends StatefulWidget {
  const _FilterPopoverBody({required this.rows});

  final List<AppFilterRow> Function() rows;

  @override
  State<_FilterPopoverBody> createState() => _FilterPopoverBodyState();
}

class _FilterPopoverBodyState extends State<_FilterPopoverBody> {
  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final row in widget.rows())
          switch (row) {
            AppFilterSelect() => _ValueRow(
              icon: row.icon,
              text: row.placeholder ?? row._text,
              placeholder: row.placeholder != null,
              onOpen: (trigger) async {
                await row._open(trigger);
                _changed();
              },
            ),
            AppFilterMultiSelect() => _ValueRow(
              icon: row.icon,
              text: row._text,
              onOpen: (trigger) => row._open(trigger, _changed),
            ),
            AppFilterToggle() => _Row(
              icon: row.icon,
              onTap: () {
                row.onChanged(!row.value);
                _changed();
              },
              end: Switch.adaptive(
                value: row.value,
                onChanged: (v) {
                  row.onChanged(v);
                  _changed();
                },
              ),
              child: _RowLabel(row.label),
            ),
            AppFilterAction() => _Row(
              icon: row.icon,
              onTap: () {
                Navigator.of(context).pop();
                row.onTap();
              },
              child: _RowLabel(row.label),
            ),
          },
      ],
    );
  }
}

bool _ios(BuildContext context) =>
    useIosLook(context) && context.rdSkin == null;

class _RowLabel extends StatelessWidget {
  const _RowLabel(this.text, {this.muted = false});

  final String text;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      // ion-item 1rem: 17pt on the iPhone, 16px in md mode.
      style: TextStyle(
        fontSize: _ios(context) ? 17 : 16,
        color: muted ? onSurface.withValues(alpha: 0.45) : onSurface,
      ),
    );
  }
}

/// `ion-item lines="none"` of the filter popover: the small start icon,
/// the content and an optional end slot.
class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.child,
    required this.onTap,
    this.end,
  });

  final IconData icon;
  final Widget child;
  final VoidCallback onTap;
  final Widget? end;

  @override
  Widget build(BuildContext context) {
    final ios = _ios(context);
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    return InkWell(
      splashFactory: ios ? NoSplash.splashFactory : null,
      highlightColor: ios ? IosGlass.itemActivated(theme.brightness) : null,
      onTap: onTap,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: ios ? 44 : 48),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              // `size="small"`: 18px; md icons in an item are rgba(text, .54).
              Icon(
                icon,
                size: 18,
                color: ios ? onSurface : onSurface.withValues(alpha: 0.54),
              ),
              // iOS: the label / select starts 76pt from the popover's edge.
              SizedBox(width: ios ? 42 : 32),
              Expanded(child: child),
              if (end != null) ...[const SizedBox(width: 8), end!],
            ],
          ),
        ),
      ),
    );
  }
}

/// A row whose value opens a nested popover anchored at the value.
class _ValueRow extends StatefulWidget {
  const _ValueRow({
    required this.icon,
    required this.text,
    required this.onOpen,
    this.placeholder = false,
  });

  final IconData icon;
  final String text;
  final bool placeholder;
  final Future<void> Function(BuildContext trigger) onOpen;

  @override
  State<_ValueRow> createState() => _ValueRowState();
}

class _ValueRowState extends State<_ValueRow> {
  /// The select itself (text + icon) is the anchor of its popover.
  final _selectKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return _Row(
      icon: widget.icon,
      onTap: () => widget.onOpen(_selectKey.currentContext ?? context),
      child: Row(
        key: _selectKey,
        children: [
          Expanded(child: _RowLabel(widget.text, muted: widget.placeholder)),
          const SizedBox(width: 6),
          if (_ios(context))
            const IonSelectIcon()
          else
            Icon(AppIcons.arrowDropDown, color: Theme.of(context).hintColor),
        ],
      ),
    );
  }
}

/// One option of a multiple select popover: checkbox and label; a tap
/// switches it and the popover stays open.
class _CheckRow extends StatelessWidget {
  const _CheckRow({
    required this.label,
    required this.checked,
    required this.onTap,
  });

  final String label;
  final bool checked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ios = _ios(context);
    final theme = Theme.of(context);
    return Semantics(
      checked: checked,
      child: InkWell(
        splashFactory: ios ? NoSplash.splashFactory : null,
        highlightColor: ios ? IosGlass.itemActivated(theme.brightness) : null,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: ios ? 44 : 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                ExcludeFocus(
                  child: IgnorePointer(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: Checkbox(
                        value: checked,
                        onChanged: (_) {},
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(child: _RowLabel(label)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
