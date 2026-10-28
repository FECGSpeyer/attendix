import 'package:flutter/material.dart';

/// UX_ATT: true when the page should render Ionic's iOS mode (iPhone app and
/// Flutter web in iPhone Safari). Elsewhere the Material (Ionic md) look stays.
bool isIosLook(BuildContext context) =>
    Theme.of(context).platform == TargetPlatform.iOS;

/// UX_ATT: Ionic `<ion-header collapse="condense">` + `<ion-title size="large">`
/// on iOS: the page starts with a large left-aligned title inside the content;
/// the small centered toolbar title only fades in once it has scrolled away.
///
/// Usage: keep one controller per page state, wrap the scroll view with
/// [CondenseHeaderController.listen], put [IosLargeTitle] as the first scroll
/// child and wrap the toolbar title with [CondenseHeaderController.toolbarTitle].
class CondenseHeaderController {
  CondenseHeaderController();

  /// Scroll offset after which the large title has scrolled away.
  static const double threshold = 44;

  final ValueNotifier<bool> collapsed = ValueNotifier<bool>(false);

  void dispose() => collapsed.dispose();

  /// Tracks the vertical scroll position of [child].
  Widget listen({required Widget child}) {
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.depth == 0 && n.metrics.axis == Axis.vertical) {
          final value = n.metrics.pixels > threshold;
          if (collapsed.value != value) collapsed.value = value;
        }
        return false;
      },
      child: child,
    );
  }

  /// Toolbar title that is hidden while the large title is visible.
  /// When [enabled] is false (md mode, multi tenant) [title] is shown as is.
  Widget toolbarTitle({required Widget title, required bool enabled}) {
    if (!enabled) return title;
    return ValueListenableBuilder<bool>(
      valueListenable: collapsed,
      builder: (context, value, child) => AnimatedOpacity(
        opacity: value ? 1 : 0,
        duration: const Duration(milliseconds: 150),
        child: child,
      ),
      child: title,
    );
  }
}

/// Large iOS title (`ion-title size="large"`: 34 px bold, 16 px inset).
class IosLargeTitle extends StatelessWidget {
  const IosLargeTitle(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
      child: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 34,
          height: 1.2,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.37,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }
}
