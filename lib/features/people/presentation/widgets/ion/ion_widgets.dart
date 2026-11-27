import 'package:flutter/material.dart';

import '../../../../../core/theme/app_palette.dart';
import '../../../../../core/theme/design_theme.dart';

/// Expandable section heading with a chevron whose open content sits in a card.
class IonAccordion extends StatelessWidget {
  const IonAccordion({
    super.key,
    required this.title,
    required this.expanded,
    required this.onToggle,
    required this.child,
    this.headerColor,
  });

  final String title;
  final bool expanded;
  final VoidCallback onToggle;
  final Widget child;

  /// Optional tint for the heading.
  final Color? headerColor;

  @override
  Widget build(BuildContext context) {
    final rd = context.rd;
    final color = headerColor ?? rd.text2;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          expanded: expanded,
          child: InkWell(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: RdType.section(rd).copyWith(color: headerColor),
                    ),
                  ),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(Icons.expand_more, size: 22, color: color),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (expanded) ionBetaCard(rd, child),
      ],
    );
  }
}

/// Wraps [child] in a grouped card surface.
Widget ionBetaCard(
  RdPalette rd,
  Widget child, {
  EdgeInsets margin = const EdgeInsets.symmetric(horizontal: 16),
}) =>
    Container(
      margin: margin,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: rd.surface,
        borderRadius: BorderRadius.circular(rd.listRadius),
        boxShadow: rd.cardShadow,
      ),
      // FLUTTER347: rows paint their ink on this Material, not under the card.
      child: Material(type: MaterialType.transparency, child: child),
    );
