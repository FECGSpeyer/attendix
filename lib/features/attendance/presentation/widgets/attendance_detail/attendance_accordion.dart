import 'package:flutter/material.dart';

import '../../../../../core/constants/app_constants.dart';
import '../../../../../shared/widgets/adaptive/adaptive_platform.dart';

/// IOS_DETAIL: one `ion-accordion` of the attendance detail page (an
/// `ion-item-group` inside Ionic's inset list).
///
/// Material keeps the Card + [ExpansionTile] look. iOS (Ionic iOS mode):
/// 52 pt header row, 17 pt label, white header also while expanded and a
/// black chevron that turns on open.
///
/// The open state lives only as long as the widget (Ionic re-creates the
/// accordion group collapsed whenever the page is built): a private
/// [PageStorageBucket] keeps [ExpansionTile] from restoring an old state
/// from the route's page storage.
class AttendanceAccordion extends StatelessWidget {
  const AttendanceAccordion({
    super.key,
    required this.title,
    required this.children,
    this.controller,
    this.initiallyExpanded = false,
    this.clipBehavior = Clip.antiAlias,
  });

  final Widget title;
  final List<Widget> children;
  final ExpansionTileController? controller;
  final bool initiallyExpanded;
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    final ios = useIosLook(context);
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingM,
        vertical: AppDimensions.paddingXS,
      ),
      clipBehavior: clipBehavior,
      child: PageStorage(
        bucket: PageStorageBucket(),
        child: ios
            ? ExpansionTile(
                controller: controller,
                initiallyExpanded: initiallyExpanded,
                shape: const Border(),
                collapsedShape: const Border(),
                minTileHeight: 52,
                tilePadding: const EdgeInsets.only(left: 16, right: 14),
                backgroundColor: scheme.surface,
                collapsedBackgroundColor: scheme.surface,
                textColor: scheme.onSurface,
                collapsedTextColor: scheme.onSurface,
                iconColor: scheme.onSurface,
                collapsedIconColor: scheme.onSurface,
                title: DefaultTextStyle.merge(
                  style: const TextStyle(fontSize: 17),
                  child: title,
                ),
                children: children,
              )
            : ExpansionTile(
                controller: controller,
                initiallyExpanded: initiallyExpanded,
                shape: const Border(),
                collapsedShape: const Border(),
                title: title,
                children: children,
              ),
      ),
    );
  }
}
