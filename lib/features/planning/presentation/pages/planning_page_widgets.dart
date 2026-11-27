part of 'planning_page.dart';

/// Timeline helper widgets, inline duration editor, and block frame painter.

/// Preset durations of the inline duration field (concept board 12): one
/// tap also for long items such as a Predigt.
const _rdDurationPresets = [5, 10, 15, 20, 30, 40, 45, 60];


/// Same row; the Gemeinde App uid a write may add meanwhile does not count.
bool _rdSame(PlanField a, PlanField b) => a.copyWith(uid: null) == b.copyWith(uid: null);

/// Duration pill at the end of a row ("20 Min"); tap opens the field.
class _RdDurationPill extends StatelessWidget {
  const _RdDurationPill({super.key, required this.label, required this.selected, this.onTap});

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: selected ? p.primary : p.soft, borderRadius: BorderRadius.circular(999)),
      child: Text(
        label,
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: selected ? p.onPrimary : p.softText),
      ),
    );
    if (onTap == null) return pill;
    return InkWell(
      onTap: onTap,
      customBorder: const StadiumBorder(),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Center(widthFactor: 1, child: pill),
      ),
    );
  }
}

/// Inline duration field under a row (concept board 12): typical
/// durations as chips, a number field for anything else, −/+ in steps of
/// five and "bis HH:MM". A tap on a chip (or "Fertig" on the keyboard)
/// is the choice: the field closes ([onDone]); −/+ and typing leave it open.
class _RdDurationEditor extends StatefulWidget {
  const _RdDurationEditor({
    super.key,
    required this.value,
    required this.start,
    required this.onChanged,
    required this.onDone,
  });

  /// Stored minutes ("20"; may be empty while typing).
  final String value;

  /// Start of the item (minutes of the day), for "bis HH:MM".
  final int? start;
  final ValueChanged<String> onChanged;

  /// The duration is chosen: the field closes.
  final VoidCallback onDone;

  @override
  State<_RdDurationEditor> createState() => _RdDurationEditorState();
}

class _RdDurationEditorState extends State<_RdDurationEditor> {
  late final TextEditingController _controller = TextEditingController(text: widget.value.trim());
  final FocusNode _focus = FocusNode();

  @override
  void didUpdateWidget(covariant _RdDurationEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focus.hasFocus && widget.value.trim() != _controller.text) _controller.text = widget.value.trim();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  int get _minutes => int.tryParse(widget.value.trim()) ?? 0;

  void _set(int minutes) {
    final m = minutes.clamp(0, 999);
    _controller.text = '$m';
    widget.onChanged('$m');
  }

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final m = _minutes;
    final start = widget.start;
    Widget step(IconData icon, String label, int to) => Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: p.soft,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => _set(to),
          child: SizedBox(width: 44, height: 44, child: Icon(icon, color: p.softText)),
        ),
      ),
    );
    return Container(
      color: p.bg,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('${l10n.redesignPlanDuration} · ${l10n.redesignPlanDurationHint}', style: RdType.meta(p, size: 13)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final v in _rdDurationPresets)
                RdChoiceChip(
                  key: ValueKey('rd-plan-preset-$v'),
                  label: '$v',
                  selected: v == m && widget.value.trim().isNotEmpty,
                  onTap: () {
                    _set(v);
                    widget.onDone();
                  },
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              step(Icons.remove, l10n.redesignPlanLess, m % 5 == 0 ? m - 5 : m - m % 5),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  key: const Key('rd-plan-dur-input'),
                  controller: _controller,
                  focusNode: _focus,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)],
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: p.text),
                  decoration: InputDecoration(
                    isDense: true,
                    filled: true,
                    fillColor: p.surface,
                    suffixText: l10n.redesignPlanMinUnit,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  textInputAction: TextInputAction.done,
                  onChanged: widget.onChanged,
                  onSubmitted: (_) => widget.onDone(),
                ),
              ),
              const SizedBox(width: 8),
              step(Icons.add, l10n.redesignPlanMore5, m + (5 - m % 5)),
            ],
          ),
          if (start != null) ...[
            const SizedBox(height: 6),
            Text(
              l10n.redesignPlanUntil(PlanUtils.formatMinutes(start + m)),
              textAlign: TextAlign.center,
              style: RdType.meta(p, size: 13),
            ),
          ],
        ],
      ),
    );
  }
}

/// One row of the timeline: a field ([index] in the plan) or the
/// "+ Punkt in „…“" end row of the open block [footer] ([index]: its head).
class _RdSlot {
  const _RdSlot(this.index, {this.footer});

  final int index;
  final String? footer;

  bool get isFooter => footer != null;
}

/// Which part of a block's frame a row draws.
enum _RdPart { none, top, middle, bottom, single }

/// The frame of a block, drawn row by row (see `_rdFramed`).
class _RdBlockFramePainter extends CustomPainter {
  const _RdBlockFramePainter({required this.part, required this.color, required this.width});

  final _RdPart part;
  final Color color;
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = width;
    final h = width / 2;
    final left = h;
    final right = size.width - h;
    final top = h;
    final bottom = size.height - h;
    const r = 12.0;
    const radius = Radius.circular(r);
    switch (part) {
      case _RdPart.none:
        return;
      case _RdPart.single:
        canvas.drawRRect(RRect.fromLTRBR(left, top, right, bottom, radius), paint);
      case _RdPart.top:
        canvas.drawPath(
          Path()
            ..moveTo(left, size.height)
            ..lineTo(left, top + r)
            ..arcToPoint(Offset(left + r, top), radius: radius)
            ..lineTo(right - r, top)
            ..arcToPoint(Offset(right, top + r), radius: radius)
            ..lineTo(right, size.height),
          paint,
        );
      case _RdPart.middle:
        canvas
          ..drawLine(Offset(left, 0), Offset(left, size.height), paint)
          ..drawLine(Offset(right, 0), Offset(right, size.height), paint);
      case _RdPart.bottom:
        canvas.drawPath(
          Path()
            ..moveTo(left, 0)
            ..lineTo(left, bottom - r)
            ..arcToPoint(Offset(left + r, bottom), radius: radius, clockwise: false)
            ..lineTo(right - r, bottom)
            ..arcToPoint(Offset(right, bottom - r), radius: radius, clockwise: false)
            ..lineTo(right, 0),
          paint,
        );
    }
  }

  @override
  bool shouldRepaint(_RdBlockFramePainter old) => old.part != part || old.color != color || old.width != width;
}

