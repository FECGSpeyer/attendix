import 'package:flutter/material.dart';
import '../adaptive/adaptive.dart'; // IOS_LOOK

/// Ionic `ion-modal` breakpoint: on screens at least 768 × 600 a modal is a
/// centred card (600 × 500), below that it covers the whole screen.
bool isIonModalCard(Size size) => size.width >= 768 && size.height >= 600;

/// Ionic `ion-modal` card height: 500px, 600px from a 768px high screen
/// (`@media (min-width: 768px) and (min-height: 768px)`).
double ionModalCardHeight(Size size) => size.height >= 768 ? 600 : 500;

/// Presents [builder] like a default Ionic `ion-modal`
/// (`modalController.create({ component })`):
/// - desktop/tablet ([isIonModalCard]): a centred [width] × [height] card over
///   the dimmed current page ([height] defaults to [ionModalCardHeight]),
/// - phone: a full-screen dialog route.
///
/// The built widget is usually a [Scaffold] with its own app bar and close
/// button; it pops itself via `Navigator.pop(context, result)`.
Future<T?> showIonModal<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  double width = 600,
  double? height,
}) {
  final size = MediaQuery.sizeOf(context);
  final cardHeight = height ?? ionModalCardHeight(size);
  if (isIonModalCard(size)) {
    return showAppDialog<T>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: SizedBox(
            width: width, height: cardHeight, child: builder(ctx)),
      ),
    );
  }
  return Navigator.of(context, rootNavigator: true).push<T>(
    MaterialPageRoute<T>(fullscreenDialog: true, builder: builder),
  );
}
