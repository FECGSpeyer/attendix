import 'package:flutter/material.dart';

import '../../../../../core/constants/app_constants.dart';
import '../../../../../core/theme/redesign/rd_theme.dart' show RdSkinContext;
import '../../../../../shared/widgets/adaptive/adaptive_platform.dart';
import '../../../../../shared/widgets/adaptive/ion_icons.dart';
import '../../../../../shared/widgets/layout/ionic_ios.dart';
import '../../../../../shared/widgets/layout/ionic_md.dart';

/// IOS_DETAIL: one `ion-accordion` of the attendance detail page (an
/// `ion-item-group` inside Ionic's inset list).
///
/// Material: a flat md inset item-group (radius 16, no shadow) with an
/// [ExpansionTile]. iOS (Ionic iOS mode):
/// 52 pt header row, 17 pt label, white header also while expanded and a
/// black chevron that turns on open.
///
/// PARITY_R3: the toggle is the ionicon `chevron-down` (iOS: bold 20 pt
/// black; md: thin 24 px grey `rgba(text, .54)`), rotating 180° when open;
/// on iOS the group has the inset-group radius (28).
///
/// The open state lives only as long as the widget (Ionic re-creates the
/// accordion group collapsed whenever the page is built): a private
/// [PageStorageBucket] keeps [ExpansionTile] from restoring an old state
/// from the route's page storage.
class AttendanceAccordion extends StatefulWidget {
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
  State<AttendanceAccordion> createState() => _AttendanceAccordionState();
}

class _AttendanceAccordionState extends State<AttendanceAccordion> {
  late bool _expanded = widget.initiallyExpanded;
  final _bucket = PageStorageBucket();

  @override
  Widget build(BuildContext context) {
    final ios = useIosLook(context);
    final scheme = Theme.of(context).colorScheme;
    final toggle = AnimatedRotation(
      turns: _expanded ? 0.5 : 0,
      duration: const Duration(milliseconds: 200),
      child: ios
          ? IonChevronDownIcon(
              size: 20,
              color: scheme.onSurface,
              strokeWidth: 64,
            )
          : IonChevronDownIcon(
              size: 24,
              color: scheme.onSurface.withValues(alpha: 0.54),
            ),
    );
    void onChanged(bool v) => setState(() => _expanded = v);

    // Beta-Skin: a card of the new design with a 16 pt semibold title.
    if (context.rdSkin case final rd?) {
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 6, 16, 6),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: rd.surface,
          borderRadius: BorderRadius.circular(rd.listRadius),
          boxShadow: rd.cardShadow,
        ),
        child: PageStorage(
          bucket: _bucket,
          child: ExpansionTile(
            controller: widget.controller,
            initiallyExpanded: widget.initiallyExpanded,
            onExpansionChanged: onChanged,
            shape: const Border(),
            collapsedShape: const Border(),
            minTileHeight: 52,
            tilePadding: const EdgeInsets.only(left: 16, right: 14),
            backgroundColor: rd.surface,
            collapsedBackgroundColor: rd.surface,
            textColor: rd.text,
            collapsedTextColor: rd.text,
            trailing: AnimatedRotation(
              turns: _expanded ? 0.5 : 0,
              duration: const Duration(milliseconds: 200),
              child: Icon(Icons.expand_more, size: 22, color: rd.text2),
            ),
            title: DefaultTextStyle.merge(
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              child: widget.title,
            ),
            children: widget.children,
          ),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingM,
        vertical: AppDimensions.paddingXS,
      ),
      // PARITY_R9: the accordion is an `ion-item-group` of Ionic's inset
      // list, not an ion-card: md shows a flat white block with the
      // md-ion-list-inset group radius (16) and no shadow.
      elevation: ios ? null : 0,
      color: ios ? null : scheme.surface,
      shape: ios
          ? const RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.all(Radius.circular(IonIos.groupRadius)),
            )
          : IonMd.insetGroupShape,
      // AUDIT_R4: the ion-item-group of the inset list clips its content
      // (structured list radius 28), so on iOS every accordion – also those
      // asking for Clip.none (run sheet, checklist) – keeps round corners
      // when the header or rows paint their background.
      clipBehavior: ios ? Clip.antiAlias : widget.clipBehavior,
      child: PageStorage(
        bucket: _bucket,
        child: ios
            ? ExpansionTile(
                controller: widget.controller,
                initiallyExpanded: widget.initiallyExpanded,
                onExpansionChanged: onChanged,
                shape: const Border(),
                collapsedShape: const Border(),
                minTileHeight: 52,
                tilePadding: const EdgeInsets.only(left: 16, right: 14),
                backgroundColor: scheme.surface,
                collapsedBackgroundColor: scheme.surface,
                textColor: scheme.onSurface,
                collapsedTextColor: scheme.onSurface,
                trailing: toggle,
                title: DefaultTextStyle.merge(
                  style: const TextStyle(fontSize: 17),
                  child: widget.title,
                ),
                children: widget.children,
              )
            : ExpansionTile(
                controller: widget.controller,
                initiallyExpanded: widget.initiallyExpanded,
                onExpansionChanged: onChanged,
                shape: const Border(),
                collapsedShape: const Border(),
                trailing: toggle,
                title: widget.title,
                children: widget.children,
              ),
      ),
    );
  }
}
