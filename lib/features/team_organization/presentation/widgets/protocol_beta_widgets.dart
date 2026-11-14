import 'package:flutter/material.dart';

import '../../../../core/theme/redesign/rd_theme.dart';
import '../../../redesign/presentation/widgets/rd_widgets.dart';
import '../../team_org_utils.dart' show outcomeLabels;

/// Building blocks of the Beta protocol page (leadership view). All colours
/// come from the active Farbwelt.

/// Tone of a result: the chip in the notes and the pill in the Ablaufplan
/// share it, so the same result has the same colour in both places.
RdTone? protocolOutcomeTone(String? outcome) => switch (outcome) {
  'decided' => RdTone.present,
  'postponed' => RdTone.late,
  'discussed' => RdTone.primary,
  _ => null,
};

/// Result of a point: "Besprochen", "Beschlossen", "Vertagt". The picked
/// one is filled in its status colour with a check mark; a second tap takes
/// it back (the page toggles).
class ProtocolOutcomeChips extends StatelessWidget {
  const ProtocolOutcomeChips({super.key, required this.value, required this.onChanged, this.singleLine = false});

  final String? value;
  final ValueChanged<String> onChanged;

  /// Phone: the three chips always stay in one row (scaled down a little
  /// on a narrow screen) instead of wrapping.
  final bool singleLine;

  @override
  Widget build(BuildContext context) {
    final chips = _chips(context);
    if (!singleLine) return Wrap(spacing: 8, runSpacing: 8, children: chips);
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: AlignmentDirectional.centerStart,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < chips.length; i++) ...[if (i > 0) const SizedBox(width: 8), chips[i]],
        ],
      ),
    );
  }

  List<Widget> _chips(BuildContext context) {
    final p = context.rd;
    return [
      for (final o in const ['discussed', 'decided', 'postponed'])
        Semantics(
          button: true,
          selected: value == o,
          child: Material(
            color: value == o ? p.toneSoft(protocolOutcomeTone(o)!) : Colors.transparent,
            shape: StadiumBorder(side: BorderSide(color: value == o ? Colors.transparent : p.offBorder, width: 1.5)),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => onChanged(o),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (value == o) ...[
                        Icon(Icons.check, size: 18, color: p.toneColor(protocolOutcomeTone(o)!)),
                        const SizedBox(width: 4),
                      ],
                      Text(
                        outcomeLabels[o] ?? o,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: value == o ? p.toneColor(protocolOutcomeTone(o)!) : p.text,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
    ];
  }
}

/// One row of the Ablaufplan in the wide layout: time (or an icon), title,
/// a grey line and the status as a word.
class ProtocolAgendaRow extends StatelessWidget {
  const ProtocolAgendaRow({
    super.key,
    required this.leading,
    required this.title,
    this.meta,
    this.status,
    this.selected = false,
    this.titleColor,
    required this.onTap,
  });

  final Widget leading;
  final String title;
  final String? meta;
  final Widget? status;
  final bool selected;
  final Color? titleColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final hasSecondLine = (meta != null && meta!.isNotEmpty) || status != null;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? p.soft : Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                crossAxisAlignment: hasSecondLine ? CrossAxisAlignment.start : CrossAxisAlignment.center,
                children: [
                  // Grows with the text size so "19:00" never breaks.
                  SizedBox(width: MediaQuery.textScalerOf(context).scale(48), child: leading),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: titleColor ?? p.text),
                        ),
                        if (hasSecondLine)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    meta ?? '',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: RdType.meta(p, size: 13),
                                  ),
                                ),
                                if (status != null) ...[const SizedBox(width: 8), status!],
                              ],
                            ),
                          ),
                      ],
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

/// One of the three buttons above the points on the phone ("4 anwesend",
/// "Notizen", "2 Aufgaben"). [dot] marks existing notes.
class ProtocolStripButton extends StatelessWidget {
  const ProtocolStripButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.dot = false,
    this.semanticLabel,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool dot;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    return Semantics(
      button: true,
      label: semanticLabel,
      // The own label replaces the content, so the tap has to be named here.
      onTap: semanticLabel != null ? onTap : null,
      excludeSemantics: semanticLabel != null,
      child: Material(
        color: p.surface,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 18, color: p.softText),
                    const SizedBox(width: 6),
                    Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: p.text)),
                    if (dot)
                      Container(
                        width: 7,
                        height: 7,
                        margin: const EdgeInsets.only(left: 6),
                        decoration: BoxDecoration(color: p.primary, shape: BoxShape.circle),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A task below the notes: open circle or green check, title, grey line.
class ProtocolTaskRow extends StatelessWidget {
  const ProtocolTaskRow({super.key, required this.title, this.meta, required this.done, required this.onTap});

  final String title;
  final String? meta;
  final bool done;
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
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Icon(
                  done ? Icons.check_circle : Icons.radio_button_unchecked,
                  size: 22,
                  color: done ? p.present : p.text2,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: done ? p.text2 : p.text,
                          decoration: done ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      if (meta != null && meta!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(meta!, style: RdType.meta(p, size: 13)),
                        ),
                    ],
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

/// "Läuft: TOP 2 · noch 4 min" with a link to the next point.
class ProtocolLiveCard extends StatelessWidget {
  const ProtocolLiveCard({super.key, required this.label, this.nextLabel, this.onNext});

  final String label;
  final String? nextLabel;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    return Material(
      color: p.absentSoft,
      borderRadius: BorderRadius.circular(p.listRadius),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.only(left: 14, right: 6),
        child: Row(
          children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: p.absent, shape: BoxShape.circle)),
            const SizedBox(width: 10),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: p.text)),
              ),
            ),
            if (nextLabel != null && onNext != null)
              Semantics(
                button: true,
                child: InkWell(
                  onTap: onNext,
                  borderRadius: BorderRadius.circular(10),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 44),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Center(
                        widthFactor: 1,
                        child: Text(
                          nextLabel!,
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: p.link),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// "Nächster Punkt" with its keyboard shortcut as a small key cap.
class ProtocolNextButton extends StatelessWidget {
  const ProtocolNextButton({super.key, required this.label, required this.shortcut, required this.onPressed});

  final String label;
  final String shortcut;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    return Semantics(
      button: true,
      label: label,
      onTap: onPressed,
      excludeSemantics: true,
      child: Material(
        color: p.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(p.buttonRadius),
          side: BorderSide(color: p.offBorder, width: 1.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox(
            height: 44,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: p.text)),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      border: Border.all(color: p.offBorder),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(shortcut, style: RdType.meta(p, size: 12)),
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
