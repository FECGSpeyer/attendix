import 'package:flutter/material.dart';

import 'settings_list.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';

// IOS_SETTINGS2: the Ionic settings page opens "Ausstehende Personen",
// "Beobachter", "Eltern", "Archiv" and "Instanz wechseln" as inline
// `ion-modal` SHEETS (settings.page.html):
//   - pending / viewers / parents / admins: `[breakpoints]="[0, 1]"
//     [initialBreakpoint]="1" handle-behavior="none"` (full height sheet),
//   - archive / instances: `[breakpoints]="[0, 0.5, 1]"
//     [initialBreakpoint]="0.5"` (half height, can be dragged to full).
// No `presentingElement`, so they are sheets (not card modals) on iOS too;
// the default handle is shown, the toolbar holds only the `ion-title`
// (instances: "+" start, cog end). Ionic md mode renders the same sheets,
// so the helper is used on every platform.

/// Presents [builder] like an Ionic inline sheet `ion-modal` started from the
/// settings page. [initialBreakpoint] 1 opens the full height sheet
/// (iOS: 10pt below the safe area), 0.5 a half sheet that snaps to full.
///
/// The built widget is usually a [Scaffold] whose app bar is
/// [settingsSheetBar]; its scroll view must not set its own controller so
/// that the half sheet can be dragged up via the primary scroll controller.
Future<T?> showSettingsSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  double initialBreakpoint = 1,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    clipBehavior: Clip.antiAlias,
    builder: (sheetContext) {
      if (initialBreakpoint >= 1) {
        return LayoutBuilder(
          builder: (context, constraints) => SizedBox(
            // ion-modal.modal-sheet ios: `--height: calc(100% - (safe-area-top + 10px))`
            height: constraints.maxHeight - 10,
            child: _SheetHandle(child: builder(context)),
          ),
        );
      }
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: initialBreakpoint,
        minChildSize: initialBreakpoint,
        maxChildSize: 1,
        snap: true,
        builder: (context, controller) => PrimaryScrollController(
          controller: controller,
          // Make the inherited controller drive the sheet on every platform.
          automaticallyInheritForPlatforms: TargetPlatform.values.toSet(),
          child: _SheetHandle(child: builder(context)),
        ),
      );
    },
  );
}

/// Ionic sheet handle (`::part(handle)`), drawn on top of the content 5pt
/// below the top edge like `.modal-handle`.
class _SheetHandle extends StatelessWidget {
  const _SheetHandle({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sheetTheme = theme.bottomSheetTheme;
    final size = sheetTheme.dragHandleSize ?? const Size(32, 4);
    final color = sheetTheme.dragHandleColor ??
        theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4);
    return Stack(
      children: [
        Positioned.fill(child: child),
        Positioned(
          top: 5,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: Center(
              child: Container(
                width: size.width,
                height: size.height,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(size.height / 2),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Toolbar of an Ionic settings sheet: `ion-toolbar > ion-title` (centred,
/// no back/close button) with optional start/end buttons.
PreferredSizeWidget settingsSheetBar(
  BuildContext context, {
  required String title,
  Widget? leading,
  List<Widget> actions = const [],
}) {
  if (ionIsIos(context)) {
    return IonModalHeader(
      title: Text(title),
      leading: leading,
      trailing: actions.isEmpty
          ? null
          : Row(mainAxisSize: MainAxisSize.min, children: actions),
      showClose: false,
    );
  }
  return AppBar(
    title: Text(title),
    automaticallyImplyLeading: false,
    leading: leading,
    actions: actions,
  );
}
