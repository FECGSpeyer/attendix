import 'package:flutter/material.dart';

import '../../../../core/theme/redesign/rd_theme.dart';

/// Design-system surface and container primitives: cards, grouped lists,
/// list rows, switches, hint boxes, and the standard [RdPage] frame.

/// White (dark: surface) card with the Farbwelt radius and shadow.
class RdCard extends StatelessWidget {
  const RdCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.onTap,
    this.color,
    this.border,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final BoxBorder? border;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final radius = BorderRadius.circular(p.cardRadius);
    final content = Padding(padding: padding, child: child);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color ?? p.surface,
        borderRadius: radius,
        boxShadow: p.cardShadow,
        border: border,
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: onTap == null ? content : InkWell(onTap: onTap, child: content),
      ),
    );
  }
}

/// Grouped list (rows separated by hairlines).
class RdGroupedList extends StatelessWidget {
  const RdGroupedList({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      rows.add(children[i]);
      if (i < children.length - 1) {
        rows.add(Divider(height: 1, thickness: 1, color: p.line));
      }
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(p.listRadius),
        boxShadow: p.cardShadow,
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: BorderRadius.circular(p.listRadius),
        clipBehavior: Clip.antiAlias,
        child: Column(mainAxisSize: MainAxisSize.min, children: rows),
      ),
    );
  }
}

/// One row of a [RdGroupedList]: at least 44 px high.
class RdListRow extends StatelessWidget {
  const RdListRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.value,
    this.onTap,
    this.showChevron = true,
    this.titleColor,
    this.selected = false,
    this.footer,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;

  /// Below the subtitle (e.g. the pills of a Werk in "Noten importieren").
  final Widget? footer;

  /// Grey value at the end ("Petrol · Automatisch").
  final String? value;
  final VoidCallback? onTap;
  final bool showChevron;
  final Color? titleColor;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    return Material(
      color: selected ? p.soft : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: LayoutBuilder(
              builder: (context, constraints) => Row(
                children: [
                  if (leading != null) ...[leading!, const SizedBox(width: 12)],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: titleColor ?? p.text,
                          ),
                        ),
                        if (subtitle != null && subtitle!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(subtitle!, style: RdType.meta(p, size: 13)),
                          ),
                        if (footer != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: footer!,
                          ),
                      ],
                    ),
                  ),
                  if (value != null) ...[
                    const SizedBox(width: 8),
                    // Right-aligned next to the chevron; the title keeps at
                    // least 40 % of the row.
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: constraints.maxWidth.isFinite
                            ? constraints.maxWidth * 0.6
                            : 240,
                      ),
                      child: Text(
                        value!,
                        textAlign: TextAlign.end,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: RdType.meta(p, size: 15),
                      ),
                    ),
                  ],
                  if (trailing != null) ...[const SizedBox(width: 8), trailing!],
                  if (showChevron && onTap != null) ...[
                    const SizedBox(width: 4),
                    Icon(Icons.chevron_right, size: 20, color: p.text2),
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

/// Rounded icon tile in front of a list row.
class RdRowIcon extends StatelessWidget {
  const RdRowIcon(this.icon, {super.key, this.color, this.background});

  final IconData icon;
  final Color? color;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: background ?? p.soft,
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: 18, color: color ?? p.softText),
    );
  }
}

/// A list row with a switch (Benachrichtigungen, "Noten importieren"): the
/// whole row toggles, the switch keeps the theme's white knob.
class RdSwitchRow extends StatelessWidget {
  const RdSwitchRow({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final onChanged = this.onChanged;
    return RdListRow(
      title: title,
      subtitle: subtitle,
      showChevron: false,
      trailing: Switch.adaptive(value: value, activeTrackColor: p.primary, onChanged: onChanged),
      onTap: onChanged == null ? null : () => onChanged(!value),
    );
  }
}

/// Soft box with a short note ("Lass diese Seite offen …", the summary of
/// "Neuer Termin").
class RdHintBox extends StatelessWidget {
  const RdHintBox(this.text, {super.key, this.liveRegion = false});

  final String text;

  /// Read out again when the text changes.
  final bool liveRegion;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    return Semantics(
      liveRegion: liveRegion,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(color: p.soft, borderRadius: BorderRadius.circular(14)),
        child: Text(text, style: TextStyle(fontSize: 14, color: p.softText, height: 1.35)),
      ),
    );
  }
}

/// Page frame of the new design: page background, safe area, pull to
/// refresh and a scrolling column with the large title.
class RdPage extends StatelessWidget {
  const RdPage({
    super.key,
    required this.children,
    this.onRefresh,
    this.padding = const EdgeInsets.fromLTRB(20, 12, 20, 32),
    this.maxWidth = 720,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.controller,
  });

  final List<Widget> children;
  final Future<void> Function()? onRefresh;
  final EdgeInsets padding;

  /// Scroll position kept elsewhere (the Verwaltung list on wide screens).
  final ScrollController? controller;

  /// "Neuer Termin" etc.
  final Widget? floatingActionButton;

  /// E.g. `centerFloat` for a wide step button ("Weiter", "Übergeben").
  final FloatingActionButtonLocation? floatingActionButtonLocation;

  /// Content width on tablets and desktops.
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    Widget list = ListView(
      controller: controller,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: padding,
      children: [
        Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
      ],
    );
    if (onRefresh != null) {
      list = RefreshIndicator(
        color: p.primary,
        backgroundColor: p.surface,
        onRefresh: onRefresh!,
        child: list,
      );
    }
    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(bottom: false, child: list),
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
    );
  }
}
