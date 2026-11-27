import 'package:flutter/material.dart';

import '../../../../../core/theme/redesign/rd_theme.dart';

/// Design-system selection controls: segmented control, swipe switcher,
/// choice chips, removable filter chips, and horizontal chip scroller.

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
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  child: Center(
                                    // One line: with large text a second line
                                    // would be cut by the fixed height.
                                    child: Text(
                                      labelOf(values[i]),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
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
/// quarter of the width or with a fling it switches to the neighbour right
/// away: the new content slides in next to the old one like a page and the
/// segmented thumb moves along with it. The segmented control stays
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

  /// Horizontal offset of the content of [_base]. A notifier instead of
  /// setState so a frame only moves the cached layers of the content
  /// (RepaintBoundary) instead of rebuilding and repainting the list.
  final _dx = ValueNotifier<double>(0);
  double _from = 0;
  double _to = 0;
  double _width = 1;
  bool _tracking = false;

  /// Index the current swipe started on (its content sits at [_dx]).
  int _base = 0;

  /// Index a swipe switches to while its content slides in, and the
  /// content of [_base] that slides out next to it.
  int? _target;
  Widget? _outgoing;

  /// The segmented thumb follows the content (drag and settle animation).
  bool _reporting = false;
  double? _lastDrag;

  int get _index => widget.values.indexOf(widget.selected);

  double get _thumb => (_base - _dx.value / _width).clamp(0.0, widget.values.length - 1.0);

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 220))
      ..addListener(() {
        _dx.value = _from + (_to - _from) * Curves.easeOutCubic.transform(_anim.value);
        if (_reporting) _reportDrag(_thumb);
      });
  }

  @override
  void didUpdateWidget(covariant RdSwipeSwitch<T> old) {
    super.didUpdateWidget(old);
    if (_target != null) {
      // The rebuild after our own onChanged: keep the old content beside
      // the new one until it has slid out.
      if (_index == _target) {
        _outgoing ??= old.child;
        return;
      }
      _finishSwitch();
    }
    // A tap on the segmented control: slide the new content in briefly.
    final before = old.values.indexOf(old.selected);
    if (!_tracking && before != _index && before >= 0 && _index >= 0) {
      _base = _index;
      _slide(from: (_index > before ? 1 : -1) * _width * 0.25, to: 0);
    }
  }

  @override
  void dispose() {
    _anim.dispose();
    _dx.dispose();
    super.dispose();
  }

  /// Reports the thumb position, but only when it changed visibly, so the
  /// segmented control above does not rebuild for sub-pixel moves.
  void _reportDrag(double? pos) {
    if (pos != null && _lastDrag != null && (pos - _lastDrag!).abs() < 0.005) return;
    if (pos == null && _lastDrag == null) return;
    _lastDrag = pos;
    widget.onDrag?.call(pos);
  }

  Future<void> _slide({required double from, required double to}) async {
    if (MediaQuery.disableAnimationsOf(context)) {
      _dx.value = to;
      return;
    }
    _from = from;
    _to = to;
    _dx.value = from;
    try {
      await _anim.forward(from: 0).orCancel;
    } on TickerCanceled {
      // Disposed or restarted.
    }
  }

  void _finishSwitch() {
    if (_target == null) return;
    _anim.stop();
    _reporting = false;
    _base = _index;
    _dx.value = 0;
    setState(() {
      _target = null;
      _outgoing = null;
    });
    _reportDrag(null);
  }

  Future<void> _settle() async {
    _reporting = true;
    await _slide(from: _dx.value, to: 0);
    // A new drag took over meanwhile.
    if (!mounted || _tracking || _target != null) return;
    _reporting = false;
    _reportDrag(null);
  }

  void _start(DragStartDetails d) {
    _tracking = d.globalPosition.dx > _edge && _target == null;
    if (!_tracking) return;
    _anim.stop();
    _reporting = false;
    _base = _index;
  }

  void _update(DragUpdateDetails d) {
    if (!_tracking) return;
    final dx = _dx.value;
    final next = dx + d.delta.dx;
    // Rubber band where there is no neighbour.
    final blocked = (next < 0 && _base >= widget.values.length - 1) || (next > 0 && _base <= 0);
    _dx.value = blocked ? dx + d.delta.dx * 0.25 : next;
    _reportDrag(_thumb);
  }

  Future<void> _end(DragEndDetails d) async {
    if (!_tracking) return;
    _tracking = false;
    final i = _base;
    final dx = _dx.value;
    final v = d.primaryVelocity ?? 0;
    var target = i;
    if ((dx < -_width * 0.25 || v < -400) && i < widget.values.length - 1) target = i + 1;
    if ((dx > _width * 0.25 || v > 400) && i > 0) target = i - 1;
    if (target == i) {
      await _settle();
      return;
    }
    // Switch now, so the new content is built while the old one is still
    // moving, and slide both together like pages.
    final dir = target > i ? 1.0 : -1.0;
    _reporting = true;
    setState(() => _target = target);
    widget.onChanged(widget.values[target]);
    await _slide(from: dx, to: -dir * _width);
    if (!mounted) return;
    _finishSwitch();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        _width = c.maxWidth.isFinite && c.maxWidth > 0 ? c.maxWidth : MediaQuery.sizeOf(context).width;
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
            _settle();
          },
          // Short lists: the empty space below still takes the swipe.
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: MediaQuery.sizeOf(context).height * 0.55),
            child: ValueListenableBuilder<double>(
              valueListenable: _dx,
              builder: (context, dx, _) {
                final target = _target;
                final outgoing = _outgoing;
                // Same structure in every phase (keyed by index), so the old
                // content is neither rebuilt nor repainted when the new one
                // joins it: each is painted once and then only moved.
                Widget page(int index, Widget child, double offset, {bool ignoring = false}) => KeyedSubtree(
                      key: ValueKey(index),
                      child: IgnorePointer(
                        ignoring: ignoring,
                        child: Opacity(
                          opacity: (1 - (offset.abs() / _width) * 0.6).clamp(0.0, 1.0),
                          child: Transform.translate(
                            offset: Offset(offset, 0),
                            child: RepaintBoundary(child: child),
                          ),
                        ),
                      ),
                    );
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    if (target != null && outgoing != null) ...[
                      page(_base, outgoing, dx, ignoring: true),
                      page(target, widget.child, dx + (target > _base ? 1 : -1) * _width),
                    ] else
                      page(_index, widget.child, dx),
                  ],
                );
              },
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
    this.icon,
    this.semanticLabel,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  /// Small icon before the label (e.g. ✦ for a suggestion of the KI).
  final IconData? icon;

  /// Read out instead of [label] (e.g. "Saxophon, Vorschlag der KI" for
  /// the ✦).
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final text = Text(
      label,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: selected ? p.bg : p.text,
      ),
    );
    final Widget content = icon == null
        ? text
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: selected ? p.bg : p.primary),
              const SizedBox(width: 6),
              Flexible(child: text),
            ],
          );
    return Semantics(
      button: true,
      selected: selected,
      label: semanticLabel,
      child: Material(
        color: selected ? p.text : p.surface,
        shape: StadiumBorder(
          side: selected ? BorderSide.none : BorderSide(color: p.offBorder),
        ),
        // The tap stays with the InkWell; a [semanticLabel] only replaces
        // the text that is read out.
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 40),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: semanticLabel == null ? content : ExcludeSemantics(child: content),
            ),
          ),
        ),
      ),
    );
  }
}

/// An active filter or sort order above a list: tap removes it.
class RdRemovableChip extends StatelessWidget {
  const RdRemovableChip({super.key, required this.label, required this.onRemove, this.semanticLabel});

  final String label;
  final VoidCallback onRemove;

  /// Read out instead of [label] (e.g. "Sortierung „Titel“ entfernen").
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    return Semantics(
      button: true,
      label: semanticLabel ?? label,
      excludeSemantics: true,
      child: Material(
        color: p.soft,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onRemove,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 36),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: p.softText),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(Icons.close, size: 16, color: p.softText),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Chips in one line beside a fixed neighbour (the "Filter" link): they
/// scroll sideways inside their own space and never paint over the
/// neighbour. A soft fade marks the side where more chips wait.
class RdChipScroller extends StatefulWidget {
  const RdChipScroller({super.key, required this.children});

  /// The chips, with their own gaps.
  final List<Widget> children;

  @override
  State<RdChipScroller> createState() => _RdChipScrollerState();
}

class _RdChipScrollerState extends State<RdChipScroller> {
  static const _fade = 20.0;

  bool _before = false;
  bool _after = false;

  bool _onMetrics(ScrollMetrics m) {
    if (m.axis != Axis.horizontal) return false;
    final before = m.extentBefore > 0.5;
    final after = m.extentAfter > 0.5;
    if (before != _before || after != _after) {
      setState(() {
        _before = before;
        _after = after;
      });
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    const solid = Color(0xFF000000);
    const clear = Color(0x00000000);
    final direction = Directionality.of(context);
    return NotificationListener<ScrollMetricsNotification>(
      onNotification: (n) => _onMetrics(n.metrics),
      child: NotificationListener<ScrollUpdateNotification>(
        onNotification: (n) => _onMetrics(n.metrics),
        child: ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (rect) {
            final stop = rect.width <= 0 ? 0.0 : (_fade / rect.width).clamp(0.0, 0.5);
            return LinearGradient(
              begin: AlignmentDirectional.centerStart,
              end: AlignmentDirectional.centerEnd,
              colors: [_before ? clear : solid, solid, solid, _after ? clear : solid],
              stops: [0, stop, 1 - stop, 1],
            ).createShader(rect, textDirection: direction);
          },
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: widget.children),
          ),
        ),
      ),
    );
  }
}
