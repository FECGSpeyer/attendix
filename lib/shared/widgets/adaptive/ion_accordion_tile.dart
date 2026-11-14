import 'package:flutter/material.dart';

import '../layout/ionic_ios.dart' show IonIos;
import '../layout/ionic_md.dart' show IonMd;
import 'adaptive_platform.dart';
import 'ion_icons.dart';

/// Ionic `<ion-accordion>` that keeps its own open state – the drop-in for
/// Material's `ExpansionTile` in the classic design.
///
/// What it does like Ionic and `ExpansionTile` does not:
/// - the header is an `ion-item` (iOS 52 pt / md 48 px high, item padding)
///   whose label and toggle chevron keep the item text colour when open
///   (Material 3 tints both primary),
/// - opening and closing take 300 ms with `cubic-bezier(.25, .8, .5, 1)`,
///   the chevron (ionicon `chevron-down`) turns upside down with it,
/// - no divider lines appear around the open tile.
///
/// The header maps the slots of the Ionic header item: [leading]
/// (`ion-icon slot="start"`), [title] / [subtitle] (`ion-label` with `h2` +
/// `p`), [trailing] (an extra `slot="end"` control before the chevron) and
/// [headerColor] (`color="light"` etc.).
///
/// ```dart
/// IonAccordionTile(
///   leading: Icon(AppIcons.infoOutline),
///   title: Text(category.label),
///   children: [for (final a in articles) IonItem(...)],
/// )
/// ```
///
/// With a [PageStorageKey] the open state survives scrolling out of a lazy
/// list. For an accordion whose state lives in the parent use the
/// controlled `IonAccordion` of the people feature.
class IonAccordionTile extends StatefulWidget {
  const IonAccordionTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.headerColor,
    this.foregroundColor,
    this.chevronColor,
    this.headerPadding,
    this.minHeaderHeight,
    this.initiallyExpanded = false,
    this.onExpansionChanged,
    this.childrenPadding = EdgeInsets.zero,
    this.crossAxisAlignment = CrossAxisAlignment.stretch,
    required this.children,
  });

  final Widget title;
  final Widget? subtitle;
  final Widget? leading;

  /// Extra control at the end of the header, left of the toggle chevron.
  final Widget? trailing;

  /// Header background (`ion-item color="…"`); null = transparent.
  final Color? headerColor;

  /// Label / icon colour of the header; null = the item text colour.
  final Color? foregroundColor;

  /// Toggle chevron colour; null = item text colour (iOS) / md icon colour.
  final Color? chevronColor;

  /// null = the Ionic item padding (iOS 16/18, md 16/16).
  final EdgeInsetsGeometry? headerPadding;

  /// null = the Ionic item height (iOS 52, md 48).
  final double? minHeaderHeight;

  final bool initiallyExpanded;
  final ValueChanged<bool>? onExpansionChanged;
  final EdgeInsetsGeometry childrenPadding;
  final CrossAxisAlignment crossAxisAlignment;
  final List<Widget> children;

  /// Ionic: `transition: all 300ms cubic-bezier(0.25, 0.8, 0.5, 1)`.
  static const Duration duration = Duration(milliseconds: 300);
  static const Curve curve = Cubic(0.25, 0.8, 0.5, 1);

  @override
  State<IonAccordionTile> createState() => _IonAccordionTileState();
}

class _IonAccordionTileState extends State<IonAccordionTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final CurvedAnimation _animation;
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = (PageStorage.maybeOf(context)?.readState(context) as bool?) ??
        widget.initiallyExpanded;
    _controller = AnimationController(
      duration: IonAccordionTile.duration,
      value: _expanded ? 1 : 0,
      vsync: this,
    );
    _animation = CurvedAnimation(parent: _controller, curve: IonAccordionTile.curve);
  }

  @override
  void dispose() {
    _animation.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    if (_expanded) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
    PageStorage.maybeOf(context)?.writeState(context, _expanded);
    widget.onExpansionChanged?.call(_expanded);
  }

  @override
  Widget build(BuildContext context) {
    final ios = useIosLook(context);
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final fg = widget.foregroundColor ?? theme.colorScheme.onSurface;
    final iconColor = widget.foregroundColor ?? (ios ? fg : IonMd.iconColor(brightness));
    final chevronColor = widget.chevronColor ?? iconColor;
    final padding = widget.headerPadding ??
        (ios
            ? const EdgeInsets.only(
                left: IonIos.itemPaddingStart,
                right: IonIos.itemPaddingEnd,
              )
            : const EdgeInsets.symmetric(horizontal: IonMd.itemPaddingStart));

    final header = Semantics(
      button: true,
      expanded: _expanded,
      child: Material(
        color: widget.headerColor ?? Colors.transparent,
        child: InkWell(
          onTap: _toggle,
          splashFactory: ios ? NoSplash.splashFactory : null,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: widget.minHeaderHeight ??
                  (ios ? IonIos.itemMinHeight : IonMd.itemMinHeight),
            ),
            child: Padding(
              padding: padding,
              child: Row(
                children: [
                  if (widget.leading != null) ...[
                    IconTheme.merge(
                      data: IconThemeData(color: iconColor, size: 24),
                      child: widget.leading!,
                    ),
                    // ion-icon slot="start": margin-inline-end 16 (iOS) / 32 (md).
                    SizedBox(width: ios ? 16 : 32),
                  ],
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          DefaultTextStyle.merge(
                            style: TextStyle(
                              fontSize: ios ? 17 : 16,
                              fontWeight: FontWeight.w400,
                              color: fg,
                            ),
                            child: widget.title,
                          ),
                          if (widget.subtitle != null)
                            DefaultTextStyle.merge(
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                                color: widget.foregroundColor ??
                                    (ios
                                        ? IonIos.labelP(brightness)
                                        : IonMd.labelP(brightness)),
                              ),
                              child: widget.subtitle!,
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (widget.trailing != null) widget.trailing!,
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: RotationTransition(
                      turns: Tween<double>(begin: 0, end: 0.5).animate(_animation),
                      child: ios
                          ? IonChevronDownIcon(size: 20, color: chevronColor, strokeWidth: 64)
                          : IonChevronDownIcon(size: 24, color: chevronColor),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            // Closed: the content is not in the tree (Ionic `display: none`).
            if (_controller.isDismissed) return const SizedBox.shrink();
            return ClipRect(
              child: Align(
                alignment: Alignment.topCenter,
                heightFactor: _animation.value,
                child: child,
              ),
            );
          },
          child: Padding(
            padding: widget.childrenPadding,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: widget.crossAxisAlignment,
              children: widget.children,
            ),
          ),
        ),
      ],
    );
  }
}
