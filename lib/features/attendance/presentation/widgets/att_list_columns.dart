import 'package:flutter/material.dart';

/// Ionic 4.19.0 att-list `.att-layout` (container query): from 760px
/// content width (next to the side panel) the next Termin and the upcoming
/// ones stand left, the past ones with the average right (1.35fr / 1fr,
/// max 1280px). Without past Termine, or for single-list views: one column,
/// max 760px. Narrower: the plain list.
class AttListColumns extends StatelessWidget {
  const AttListColumns({
    super.key,
    required this.twoColumns,
    required this.main,
    required this.side,
  });

  /// Ionic `att-grid--two`.
  final bool twoColumns;
  final List<Widget> main;
  final List<Widget> side;

  static const double minWidth = 760;
  static const double maxWidth = 1280;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final all = [...main, ...side];
      if (constraints.maxWidth < minWidth) {
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: all);
      }
      if (!twoColumns) {
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: minWidth),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: all),
          ),
        );
      }
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: maxWidth),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 135,
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: main),
              ),
              const SizedBox(width: 4),
              Expanded(
                flex: 100,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  // Heading "Vergangen" level with the first row on the left.
                  children: [const SizedBox(height: 10), ...side],
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}
