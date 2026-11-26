import 'package:flutter/material.dart';

import '../../../core/theme/redesign/rd_theme.dart';
import '../adaptive/app_dialog.dart' show showAppDialog;

/// Breakpoint at which a modal is shown as a centred card (600 × 500/600)
/// instead of a full-screen dialog route.
bool isIonModalCard(Size size) => size.width >= 768 && size.height >= 600;

/// Modal card height: 500px, or 600px on screens at least 768px tall.
double ionModalCardHeight(Size size) => size.height >= 768 ? 600 : 500;

/// Window size seen by modal breakpoints.
Size ionModalWindowSize(BuildContext context) =>
    context.getInheritedWidgetOfExactType<IonWindowSizeScope>()?.size ??
    MediaQuery.sizeOf(context);

/// Carries the window size below a shell that narrows [MediaQuery].
class IonWindowSizeScope extends InheritedWidget {
  const IonWindowSizeScope({super.key, required this.size, required super.child});

  final Size size;

  @override
  bool updateShouldNotify(IonWindowSizeScope oldWidget) => size != oldWidget.size;
}

/// Presents [builder] as a centred card on wide screens (>= 768 × 600) or a
/// full-screen dialog route on phones.
Future<T?> showIonModal<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  double width = 600,
  double? height,
  bool barrierDismissible = true,
}) {
  final size = ionModalWindowSize(context);
  final cardHeight = height ?? ionModalCardHeight(size);
  if (isIonModalCard(size)) {
    final rd = context.rd;
    return showAppDialog<T>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: barrierDismissible,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        clipBehavior: Clip.antiAlias,
        backgroundColor: rd.bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: SizedBox(width: width, height: cardHeight, child: builder(ctx)),
      ),
    );
  }
  return Navigator.of(context, rootNavigator: true).push<T>(
    MaterialPageRoute<T>(fullscreenDialog: true, builder: builder),
  );
}

/// Applies responsive sheet modal widths (600px on wide screens, full width on
/// phones) app-wide. Wraps the app's navigator (`MaterialApp.builder`).
class IonModalTheme extends StatelessWidget {
  const IonModalTheme({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final wide = isIonModalCard(MediaQuery.sizeOf(context));
    final sheet = theme.bottomSheetTheme;
    return Theme(
      data: theme.copyWith(
        bottomSheetTheme: sheet.copyWith(
          constraints: wide
              ? const BoxConstraints(maxWidth: 600)
              : const BoxConstraints(),
        ),
      ),
      child: child,
    );
  }
}
