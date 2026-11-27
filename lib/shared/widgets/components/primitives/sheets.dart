import 'package:flutter/material.dart';

import '../../../../core/theme/design_theme.dart';

/// Design-system bottom-sheet container, title, and selection checkmark.

/// Height cap of the new design's sheets: 85 % of the screen, so the drag
/// handle and a strip of the page above (tap closes the sheet) always stay
/// visible, however long the content is. Measured on every build, so it
/// follows rotation and window resizes. The cap includes the Material drag
/// handle (48 px, drawn above [child] by `showDragHandle`).
class RdSheetCap extends StatelessWidget {
  const RdSheetCap({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final max = MediaQuery.sizeOf(context).height * 0.85 - kMinInteractiveDimension;
    return ConstrainedBox(constraints: BoxConstraints(maxHeight: max < 0 ? 0 : max), child: child);
  }
}

/// Bottom sheet of the new design (page background, drag handle, at most
/// 85 % high). [child] usually starts with an [RdSheetTitle].
Future<T?> showRdSheet<T>(BuildContext context, Widget child) {
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: true,
    useSafeArea: true,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: context.rd.bg,
    builder: (_) => RdSheetCap(child: SafeArea(top: false, child: child)),
  );
}

/// Title of an [showRdSheet] sheet.
class RdSheetTitle extends StatelessWidget {
  const RdSheetTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: Semantics(header: true, child: Text(text, style: RdType.cardTitle(context.rd))),
      );
}

/// Check mark at the end of the picked row of a sheet (keeps its width
/// when not picked).
class RdSheetCheck extends StatelessWidget {
  const RdSheetCheck(this.selected, {super.key});

  final bool selected;

  @override
  Widget build(BuildContext context) =>
      selected ? Icon(Icons.check, size: 22, color: context.rd.primary) : const SizedBox(width: 22);
}
