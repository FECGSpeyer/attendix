import 'package:flutter/material.dart';

/// PARITY_R5: top corner radius of an iOS sheet / card modal
/// (ionic-theme-ios27 `.modal-card, .modal-sheet { --border-radius: 32px }`).
const double kIonModalSheetRadius = 32;

/// IOS_SHEETS: the grabber of an Ionic sheet modal (`ion-modal` with
/// breakpoints → `.modal-handle`), drawn *over* the sheet content (it does
/// not take layout space like Material's `showDragHandle`).
/// PARITY_R5: ionic-theme-ios27 `::part(handle)`: 60 × 4pt, radius 2,
/// 6pt below the top edge, step-250 grey.
///
/// Size and colour follow the app's [BottomSheetThemeData] so all iOS sheets
/// share one grabber look.
class IonModalHandle extends StatelessWidget {
  const IonModalHandle({super.key});

  /// Distance of the grabber from the top edge of the sheet (ios27 `top: 6px`).
  static const double top = 6;

  /// ios27 handle size.
  static const Size size = Size(60, 4);

  @override
  Widget build(BuildContext context) {
    final sheetTheme = Theme.of(context).bottomSheetTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final size = sheetTheme.dragHandleSize ?? IonModalHandle.size;
    final color = sheetTheme.dragHandleColor ??
        (dark ? const Color(0xFF404040) : const Color(0xFFC0C0BE));
    return ExcludeSemantics(
      child: Container(
        width: size.width,
        height: size.height,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(2),
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
