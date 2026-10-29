import 'package:flutter/material.dart';

import '../../../../core/theme/redesign/rd_palette.dart';
import '../../../../core/theme/redesign/rd_theme.dart';

/// REDESIGN: building blocks of the new design (canvas "Designsystem").
/// All colours come from the active Farbwelt (`context.rd`).

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
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;

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

/// Tone of a count badge.
enum RdTone { primary, present, late, excused, absent }

extension RdToneColors on RdPalette {
  Color toneColor(RdTone tone) => switch (tone) {
        RdTone.primary => softText,
        RdTone.present => present,
        RdTone.late => late,
        RdTone.excused => excused,
        RdTone.absent => absent,
      };

  Color toneSoft(RdTone tone) => switch (tone) {
        RdTone.primary => soft,
        RdTone.present => presentSoft,
        RdTone.late => lateSoft,
        RdTone.excused => excusedSoft,
        RdTone.absent => absentSoft,
      };
}

/// Square number badge in front of a hint row ("3").
class RdCountBadge extends StatelessWidget {
  const RdCountBadge(this.count, {super.key, this.tone = RdTone.primary});

  final int count;
  final RdTone tone;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: p.toneSoft(tone),
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: Text(
        count > 99 ? '99+' : '$count',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: p.toneColor(tone),
        ),
      ),
    );
  }
}

/// Small rounded label ("in 2 Std.", "Dabei", "Offen").
class RdPill extends StatelessWidget {
  const RdPill(this.label, {super.key, this.tone, this.icon});

  final String label;

  /// null = neutral grey.
  final RdTone? tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final fg = tone == null ? p.text2 : p.toneColor(tone!);
    final bg = tone == null ? p.track : p.toneSoft(tone!);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: fg),
          ),
        ],
      ),
    );
  }
}

/// Uppercase eyebrow above a card title ("NÄCHSTER TERMIN · HEUTE").
class RdEyebrow extends StatelessWidget {
  const RdEyebrow(this.text, {super.key, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: RdType.eyebrow(color ?? context.rd.softText),
    );
  }
}

/// Section heading with an optional action on the right ("Alle").
class RdSectionHeader extends StatelessWidget {
  const RdSectionHeader(this.title, {super.key, this.action, this.trailing});

  final String title;
  final Widget? action;

  /// Grey text on the right ("Geburtstag: Lea (Sa)").
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(title, style: RdType.section(p)),
            ),
          ),
          if (trailing != null)
            Flexible(
              child: Text(
                trailing!,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: RdType.meta(p, size: 13),
              ),
            ),
          if (action != null) action!,
        ],
      ),
    );
  }
}

/// Uppercase group label above a list ("FARBWELT").
class RdGroupLabel extends StatelessWidget {
  const RdGroupLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
      child: Semantics(
        header: true,
        child: Text(text.toUpperCase(), style: RdType.eyebrow(context.rd.text2)),
      ),
    );
  }
}

/// Filled primary button, 48 px high.
class RdPrimaryButton extends StatelessWidget {
  const RdPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.color,
    this.foreground,
    this.height = 48,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? color;
  final Color? foreground;
  final double height;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    return SizedBox(
      height: height,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: color ?? p.primary,
          foregroundColor: foreground ?? p.onPrimary,
          disabledBackgroundColor: p.track,
          disabledForegroundColor: p.text2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(p.buttonRadius),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: 8)],
            Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
          ],
        ),
      ),
    );
  }
}

/// Outlined button, 48 px high ("Abmelden" while not chosen).
class RdOutlineButton extends StatelessWidget {
  const RdOutlineButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.color,
    this.height = 48,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  /// Text and border colour (default: secondary text / hairline).
  final Color? color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final fg = color ?? p.text;
    return SizedBox(
      height: height,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: fg,
          backgroundColor: p.surface,
          side: BorderSide(color: color ?? p.offBorder, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(p.buttonRadius),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          padding: const EdgeInsets.symmetric(horizontal: 12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: 6)],
            Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
          ],
        ),
      ),
    );
  }
}

/// Round 44 × 44 icon button on the page background (bell).
class RdCircleButton extends StatelessWidget {
  const RdCircleButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.dot = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  /// Red dot (unread notifications).
  final bool dot;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: p.surface,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(icon, size: 22, color: p.text),
                if (dot)
                  Positioned(
                    top: 9,
                    right: 10,
                    child: Container(
                      width: 11,
                      height: 11,
                      decoration: BoxDecoration(
                        color: p.absent,
                        shape: BoxShape.circle,
                        border: Border.all(color: p.surface, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One coloured part of a [RdStatusBar].
class RdBarSegment {
  const RdBarSegment(this.value, this.color);
  final int value;
  final Color color;
}

/// Thin bar with the share of each status ("24 zugesagt, 3 entschuldigt").
class RdStatusBar extends StatelessWidget {
  const RdStatusBar({
    super.key,
    required this.segments,
    required this.total,
    required this.semanticLabel,
  });

  final List<RdBarSegment> segments;
  final int total;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    return Semantics(
      label: semanticLabel,
      excludeSemantics: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: SizedBox(
          height: 8,
          child: LayoutBuilder(
            builder: (context, c) {
              final width = c.maxWidth;
              return Stack(
                children: [
                  Positioned.fill(child: ColoredBox(color: p.track)),
                  // Positioned.fill + stretch: a non-positioned Row gets
                  // loose constraints and its segments would be 0 px high.
                  if (total > 0)
                    Positioned.fill(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final s in segments)
                            if (s.value > 0)
                              SizedBox(
                                width: width * s.value / total,
                                child: ColoredBox(color: s.color),
                              ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Date tile of a list row ("SA" over "1").
class RdDateTile extends StatelessWidget {
  const RdDateTile({
    super.key,
    required this.weekday,
    required this.day,
    this.highlight = false,
  });

  final String weekday;
  final String day;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    return Container(
      width: 44,
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: highlight ? p.soft : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            weekday.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: highlight ? p.softText : p.text2,
            ),
          ),
          Text(
            day,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: highlight ? p.softText : p.text,
            ),
          ),
        ],
      ),
    );
  }
}

/// Round initials avatar.
class RdInitials extends StatelessWidget {
  const RdInitials(
    this.initials, {
    super.key,
    this.size = 40,
    this.square = false,
    this.filled = false,
  });

  final String initials;
  final double size;

  /// Rounded square (group logo) instead of a circle.
  final bool square;

  /// Primary background (group chip) instead of the soft tint.
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: filled ? p.primary : p.soft,
        shape: square ? BoxShape.rectangle : BoxShape.circle,
        borderRadius: square ? BorderRadius.circular(size * 0.28) : null,
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          fontSize: size * 0.4,
          fontWeight: FontWeight.w700,
          color: filled ? p.onPrimary : p.softText,
        ),
      ),
    );
  }
}

/// Initials of a name ("Leon Jäger" → "LJ", "Stadtorchester" → "ST").
String rdInitialsOf(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) {
    final w = parts.first;
    return (w.length >= 2 ? w.substring(0, 2) : w).toUpperCase();
  }
  return (parts.first[0] + parts[1][0]).toUpperCase();
}

/// Segmented control with equal parts (Hell / Dunkel / Automatisch). The
/// white thumb slides to the selected part and, while a [RdSwipeSwitch]
/// is dragged, follows the finger ([position]).
class RdSegmented<T> extends StatelessWidget {
  const RdSegmented({
    super.key,
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.onChanged,
    this.enabled = true,
    this.semanticLabel,
    this.position,
  });

  final List<T> values;
  final T selected;
  final String Function(T) labelOf;
  final ValueChanged<T> onChanged;
  final bool enabled;
  final String? semanticLabel;

  /// Fractional index of the thumb while swiping (null: [selected]).
  final double? position;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final n = values.length;
    final selectedIndex = values.indexOf(selected).clamp(0, n - 1);
    final thumb = (position ?? selectedIndex.toDouble()).clamp(0.0, n - 1.0);
    final highlighted = thumb.round();
    final animate = position == null && !MediaQuery.disableAnimationsOf(context);
    return Semantics(
      label: semanticLabel,
      container: true,
      child: Opacity(
        opacity: enabled ? 1 : 0.55,
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: p.track,
            borderRadius: BorderRadius.circular(14),
          ),
          child: LayoutBuilder(
            builder: (context, c) {
              final width = c.maxWidth / n;
              return Stack(
                children: [
                  AnimatedPositioned(
                    duration: animate ? const Duration(milliseconds: 200) : Duration.zero,
                    curve: Curves.easeOutCubic,
                    left: thumb * width,
                    top: 0,
                    bottom: 0,
                    width: width,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: p.surface,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x1F000000),
                            blurRadius: 2,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      for (var i = 0; i < n; i++)
                        Expanded(
                          child: Semantics(
                            button: true,
                            selected: i == selectedIndex,
                            enabled: enabled,
                            child: GestureDetector(
                              onTap: enabled ? () => onChanged(values[i]) : null,
                              behavior: HitTestBehavior.opaque,
                              child: SizedBox(
                                height: 44,
                                child: Center(
                                  child: Text(
                                    labelOf(values[i]),
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: i == highlighted ? FontWeight.w700 : FontWeight.w500,
                                      color: i == highlighted ? p.text : p.text2,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Horizontal swipe between the parts of a [RdSegmented] (Kommend /
/// Vergangen, Aktiv / Pausiert). The content follows the finger; past a
/// quarter of the width or with a fling it switches to the neighbour and
/// the new content slides in from that side. The segmented control stays
/// the main way: this is a shortcut for one-handed use. Swipes starting at
/// the left screen edge are left to the system back gesture.
class RdSwipeSwitch<T> extends StatefulWidget {
  const RdSwipeSwitch({
    super.key,
    required this.values,
    required this.selected,
    required this.onChanged,
    required this.child,
    this.onDrag,
  });

  final List<T> values;
  final T selected;
  final ValueChanged<T> onChanged;
  final Widget child;

  /// Fractional index while dragging (for [RdSegmented.position]), null
  /// once the swipe ends.
  final ValueChanged<double?>? onDrag;

  @override
  State<RdSwipeSwitch<T>> createState() => _RdSwipeSwitchState<T>();
}

class _RdSwipeSwitchState<T> extends State<RdSwipeSwitch<T>> with SingleTickerProviderStateMixin {
  static const _edge = 24.0;

  late final AnimationController _anim;
  double _dx = 0;
  double _from = 0;
  double _to = 0;
  double _width = 1;
  bool _tracking = false;
  bool _switching = false;

  /// Index this switch selected itself (its slide-in already runs).
  int? _switchedTo;

  int get _index => widget.values.indexOf(widget.selected);

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 180))
      ..addListener(() => setState(() => _dx = _from + (_to - _from) * Curves.easeOutCubic.transform(_anim.value)));
  }

  @override
  void didUpdateWidget(covariant RdSwipeSwitch<T> old) {
    super.didUpdateWidget(old);
    // A tap on the segmented control: slide the new content in briefly.
    final before = old.values.indexOf(old.selected);
    if (_switchedTo != null && _switchedTo == _index) {
      _switchedTo = null;
      return;
    }
    if (!_switching && !_tracking && before != _index && before >= 0 && _index >= 0) {
      _slide(from: (_index > before ? 1 : -1) * _width * 0.25, to: 0);
    }
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  Future<void> _slide({required double from, required double to}) async {
    if (MediaQuery.disableAnimationsOf(context)) {
      setState(() => _dx = to);
      return;
    }
    _from = from;
    _to = to;
    _dx = from;
    try {
      await _anim.forward(from: 0).orCancel;
    } on TickerCanceled {
      // Disposed or restarted.
    }
  }

  void _start(DragStartDetails d) {
    _tracking = d.globalPosition.dx > _edge && !_switching;
    if (_tracking) _anim.stop();
  }

  void _update(DragUpdateDetails d) {
    if (!_tracking) return;
    final i = _index;
    final next = _dx + d.delta.dx;
    // Rubber band where there is no neighbour.
    final blocked = (next < 0 && i >= widget.values.length - 1) || (next > 0 && i <= 0);
    setState(() => _dx = blocked ? _dx + d.delta.dx * 0.25 : next);
    widget.onDrag?.call((i - _dx / _width).clamp(0.0, widget.values.length - 1.0));
  }

  Future<void> _end(DragEndDetails d) async {
    if (!_tracking) return;
    _tracking = false;
    final i = _index;
    final v = d.primaryVelocity ?? 0;
    var target = i;
    if ((_dx < -_width * 0.25 || v < -400) && i < widget.values.length - 1) target = i + 1;
    if ((_dx > _width * 0.25 || v > 400) && i > 0) target = i - 1;
    if (target == i) {
      widget.onDrag?.call(null);
      await _slide(from: _dx, to: 0);
      return;
    }
    final dir = target > i ? -1.0 : 1.0;
    _switching = true;
    await _slide(from: _dx, to: dir * _width);
    if (!mounted) return;
    widget.onDrag?.call(null);
    _switchedTo = target;
    widget.onChanged(widget.values[target]);
    _switching = false;
    await _slide(from: -dir * _width * 0.4, to: 0);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        _width = c.maxWidth.isFinite && c.maxWidth > 0 ? c.maxWidth : MediaQuery.sizeOf(context).width;
        final fade = (1 - (_dx.abs() / _width) * 0.6).clamp(0.0, 1.0);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          // Screen readers use the segmented control.
          excludeFromSemantics: true,
          onHorizontalDragStart: _start,
          onHorizontalDragUpdate: _update,
          onHorizontalDragEnd: _end,
          onHorizontalDragCancel: () {
            if (!_tracking) return;
            _tracking = false;
            widget.onDrag?.call(null);
            _slide(from: _dx, to: 0);
          },
          // Short lists: the empty space below still takes the swipe.
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: MediaQuery.sizeOf(context).height * 0.55),
            child: Opacity(
              opacity: fade,
              child: Transform.translate(offset: Offset(_dx, 0), child: widget.child),
            ),
          ),
        );
      },
    );
  }
}

/// Selectable chip (reasons "Krank", "Arbeit" …), at least 36 px high.
class RdChoiceChip extends StatelessWidget {
  const RdChoiceChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? p.text : p.surface,
        shape: StadiumBorder(
          side: selected ? BorderSide.none : BorderSide(color: p.offBorder),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 40),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: selected ? p.bg : p.text,
                ),
              ),
            ),
          ),
        ),
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
  });

  final List<Widget> children;
  final Future<void> Function()? onRefresh;
  final EdgeInsets padding;

  /// "Neuer Termin" etc.
  final Widget? floatingActionButton;

  /// Content width on tablets and desktops.
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    Widget list = ListView(
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
    );
  }
}

/// White pill with icon and label ("Abwesend", "Dateien").
class RdPillButton extends StatelessWidget {
  const RdPillButton({super.key, required this.icon, required this.label, required this.onPressed, this.semanticLabel});

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  /// Longer label for screen readers ("Dateien der Gruppe").
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: semanticLabel != null,
      child: Material(
        color: p.surface,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onPressed,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 18, color: p.link),
                  const SizedBox(width: 6),
                  Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: p.link)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Text action in the top bar ("Bearbeiten").
class RdTextLink extends StatelessWidget {
  const RdTextLink({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Center(
              widthFactor: 1,
              child: Text(label, style: TextStyle(fontSize: 17, color: p.link)),
            ),
          ),
        ),
      ),
    );
  }
}

/// Back link of a sub page ("‹ Ich").
class RdBackLink extends StatelessWidget {
  const RdBackLink({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    return Align(
      alignment: Alignment.centerLeft,
      child: Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.chevron_left, size: 26, color: p.link),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 17, color: p.link),
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
