import 'package:flutter/material.dart';

/// IOS_SHEETS: the grabber of an Ionic sheet modal (`ion-modal` with
/// breakpoints → `.modal-handle`): a 5pt high rounded bar centred 5pt below
/// the top edge, drawn *over* the sheet content (it does not take layout
/// space like Material's `showDragHandle`).
///
/// Size and colour follow the app's [BottomSheetThemeData] so all iOS sheets
/// share one grabber look.
class IonModalHandle extends StatelessWidget {
  const IonModalHandle({super.key});

  /// Distance of the grabber from the top edge of the sheet (Ionic `top: 5px`).
  static const double top = 5;

  @override
  Widget build(BuildContext context) {
    final sheetTheme = Theme.of(context).bottomSheetTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final size = sheetTheme.dragHandleSize ?? const Size(36, 5);
    final color = sheetTheme.dragHandleColor ??
        (dark ? const Color(0xFF404040) : const Color(0xFFC0C0BE));
    return ExcludeSemantics(
      child: Container(
        width: size.width,
        height: size.height,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}

/// Places an [IonModalHandle] over the top of [child].
class IonModalHandleOverlay extends StatelessWidget {
  const IonModalHandleOverlay({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        const Positioned(
          top: IonModalHandle.top,
          left: 0,
          right: 0,
          child: Center(child: IonModalHandle()),
        ),
      ],
    );
  }
}
