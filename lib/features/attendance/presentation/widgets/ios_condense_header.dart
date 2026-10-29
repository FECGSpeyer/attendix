import 'package:flutter/material.dart';

import '../../../../shared/widgets/layout/ionic_ios.dart' show IonSearchIcon, IonIos; // PARITY_R5, IOS27_SWEEP
import '../../../../shared/widgets/layout/ionic_md.dart' show IonMdSearchbar; // MD_SWEEP

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

/// Large iOS title (`ion-title size="large"`: min(2.125rem, 61.2px) =
/// 36.125pt bold, no letter spacing, 16pt inset; IOS27_SWEEP).
class IosLargeTitle extends StatelessWidget {
  const IosLargeTitle(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      // same box as the shared IonLargeTitle (title padding 2 / 4 +
      // toolbar padding-bottom 3)
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 7),
      child: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: IonIos.largeTitle.copyWith(
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }
}

/// UX_ATT: Ionic `ion-fab-button`. Material (md) keeps the round primary FAB;
/// iOS uses the ionic-theme-ios26 look: 61 px white glass circle with a dark
/// icon (dark mode: dark glass, white icon).
class IonFabButton extends StatelessWidget {
  const IonFabButton({
    super.key,
    required this.onPressed,
    required this.icon,
    this.tooltip,
    this.heroTag,
  });

  final VoidCallback? onPressed;
  final IconData icon;
  final String? tooltip;
  final Object? heroTag;

  @override
  Widget build(BuildContext context) {
    if (!isIosLook(context)) {
      return FloatingActionButton(
        heroTag: heroTag,
        onPressed: onPressed,
        tooltip: tooltip,
        shape: const CircleBorder(),
        child: Icon(icon),
      );
    }
    final dark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: 61,
      height: 61,
      child: FloatingActionButton(
        heroTag: heroTag,
        onPressed: onPressed,
        tooltip: tooltip,
        shape: const CircleBorder(),
        elevation: 4,
        highlightElevation: 2,
        backgroundColor: dark ? const Color(0xB8272727) : const Color(0xB8FFFFFF),
        foregroundColor: dark ? Colors.white : Colors.black,
        child: Icon(icon, size: 28),
      ),
    );
  }
}

/// UX_ATT: Ionic `ion-searchbar`. iOS (ionic-theme-ios26): 44 px glass pill
/// with the search icon at the start; md: the regular filled text field.
class IonSearchbar extends StatelessWidget {
  const IonSearchbar({
    super.key,
    required this.controller,
    required this.hintText,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final ios = isIosLook(context);
    // MD_SWEEP: the shared Ionic md searchbar (content host padding 8).
    if (!ios) {
      return IonMdSearchbar(
        controller: controller,
        hintText: hintText,
        onChanged: onChanged,
      );
    }
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final clear = value.text.isEmpty
            ? null
            : IconButton(
                icon: Icon(ios ? Icons.cancel : Icons.clear, size: ios ? 18 : null),
                color: ios ? Colors.grey : null,
                onPressed: () {
                  controller.clear();
                  onChanged('');
                },
              );
        final field = TextField(
          controller: controller,
          onChanged: onChanged,
          textAlignVertical: TextAlignVertical.center,
          decoration: InputDecoration(
            hintText: hintText,
            // PARITY_R5: ios27 search-outline in the text colour
            prefixIcon: ios ? const IonSearchIcon() : const Icon(Icons.search),
            suffixIcon: clear,
            filled: ios ? false : null,
            border: ios ? InputBorder.none : null,
            enabledBorder: ios ? InputBorder.none : null,
            focusedBorder: ios ? InputBorder.none : null,
            isDense: ios,
            contentPadding: ios ? const EdgeInsets.symmetric(vertical: 12) : null,
          ),
        );
        if (!ios) {
          return Padding(padding: const EdgeInsets.all(16), child: field);
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: dark ? const Color(0xB8272727) : const Color(0xB8FFFFFF),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: (dark ? Colors.black : const Color(0xFFDCDCDC)).withValues(alpha: 0.82),
                  blurRadius: 10,
                ),
              ],
            ),
            child: field,
          ),
        );
      },
    );
  }
}
