import 'package:flutter/material.dart';

import '../../../core/theme/redesign/rd_theme.dart';

/// Keeps the whole app clear of the left/right safe areas (classic design).
///
/// A phone with a notch / Dynamic Island held sideways reports a left and a
/// right inset (62pt each on an iPhone 17). Ionic keeps rows, toolbars, list
/// headers and the search field out of them (`--ion-safe-area-left/right`
/// in `ion-item`, `ion-toolbar`, `ion-list-header`, `ion-searchbar`); the
/// Flutter rows started at the screen edge, so names sat under the Dynamic
/// Island. Here the app as a whole moves in between the two insets (pages,
/// modals and sheets alike) on the page colour.
///
/// The window size stays as it is, so the layout breakpoints (tab bar vs
/// menu at 768pt) keep following the window like in Ionic. Without side
/// insets (portrait, tablets, desktop) nothing changes; the new design is
/// left as it is.
class SideSafeArea extends StatelessWidget {
  const SideSafeArea({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    if (padding.left == 0 && padding.right == 0) return child;
    if (context.rdSkin != null) return child;
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(top: false, bottom: false, child: child),
    );
  }
}
