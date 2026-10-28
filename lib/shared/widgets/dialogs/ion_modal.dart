import 'package:flutter/material.dart';
import '../adaptive/adaptive.dart'; // IOS_LOOK

/// Ionic `ion-modal` breakpoint: on screens at least 768 × 600 a modal is a
/// centred card (600 × 500), below that it covers the whole screen.
bool isIonModalCard(Size size) => size.width >= 768 && size.height >= 600;

/// Presents [builder] like a default Ionic `ion-modal`
/// (`modalController.create({ component })`):
/// - desktop/tablet ([isIonModalCard]): a centred [width] × [height] card over
///   the dimmed current page,
/// - phone: a full-screen dialog route.
///
/// The built widget is usually a [Scaffold] with its own app bar and close
/// button; it pops itself via `Navigator.pop(context, result)`.
Future<T?> showIonModal<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  double width = 600,
  double height = 500,
}) {
  final size = MediaQuery.sizeOf(context);
  if (isIonModalCard(size)) {
    final ios = useIosLook(context);
    return showAppDialog<T>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        clipBehavior: Clip.antiAlias,
        // PARITY_R3: Ionic md desktop modal `--border-radius: 2px` with a
        // `0 28px 48px rgba(0,0,0,.4)` shadow; iOS 10px.
        elevation: ios ? null : 24,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ios ? 10 : 2)),
        child: SizedBox(width: width, height: height, child: builder(ctx)),
      ),
    );
  }
  return Navigator.of(context, rootNavigator: true).push<T>(
    MaterialPageRoute<T>(fullscreenDialog: true, builder: builder),
  );
}

/// PARITY_R3: Ionic `ion-modal` sizes for sheet modals (and
/// `showModalBottomSheet`) app-wide. Wraps the app's navigator
/// (`MaterialApp.builder`).
///
/// - Ionic md/iOS at ≥ 768 × 600 (`@media (min-width: 768px) and
///   (min-height: 600px) { --width: 600px }`): sheets are 600 px wide,
///   centred and anchored at the bottom; md uses `--border-radius: 2px`
///   there.
/// - below: sheets span the full width (Ionic `--width: 100%`; Material 3
///   would cap them at 640).
class IonModalTheme extends StatelessWidget {
  const IonModalTheme({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final wide = isIonModalCard(MediaQuery.sizeOf(context));
    final sheet = theme.bottomSheetTheme;
    final ios = theme.platform == TargetPlatform.iOS;
    return Theme(
      data: theme.copyWith(
        bottomSheetTheme: sheet.copyWith(
          constraints: wide
              ? const BoxConstraints(maxWidth: 600)
              : const BoxConstraints(),
          shape: !ios && wide
              ? const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(2)))
              : sheet.shape,
          clipBehavior: !ios && wide ? Clip.antiAlias : sheet.clipBehavior,
        ),
      ),
      child: child,
    );
  }
}
