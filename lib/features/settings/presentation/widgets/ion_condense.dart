import 'package:flutter/material.dart';

import 'settings_list.dart';

/// UX_SETTINGS (WAVE 8): Ionic iOS `<ion-header collapse="condense">`.
///
/// On iOS the page shows a large title (34pt bold) as the first scroll item
/// and the small toolbar title only fades in once the large title has
/// scrolled away. Elsewhere (Ionic md) the toolbar title is always visible
/// and no large title is rendered.
///
/// ```dart
/// return IonCondense(
///   builder: (context, collapsed) => Scaffold(
///     appBar: AppBar(title: IonCondenseTitle(title, collapsed: collapsed)),
///     body: ListView(children: [IonLargeTitle(title), ...]),
///   ),
/// );
/// ```
class IonCondense extends StatefulWidget {
  const IonCondense({super.key, required this.builder});

  final Widget Function(BuildContext context, bool collapsed) builder;

  @override
  State<IonCondense> createState() => _IonCondenseState();
}

class _IonCondenseState extends State<IonCondense> {
  bool _collapsed = false;

  bool _onScroll(ScrollNotification n) {
    if (n.depth != 0 || n.metrics.axis != Axis.vertical) return false;
    final collapsed = n.metrics.pixels > IonLargeTitle.height - 8;
    if (collapsed != _collapsed) setState(() => _collapsed = collapsed);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final ios = ionIsIos(context);
    if (!ios) return widget.builder(context, true);
    return NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: widget.builder(context, _collapsed),
    );
  }
}

/// Toolbar title that is hidden on iOS while the large title is visible.
class IonCondenseTitle extends StatelessWidget {
  const IonCondenseTitle(this.title, {super.key, required this.collapsed});

  final String title;
  final bool collapsed;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: collapsed ? 1 : 0,
      duration: const Duration(milliseconds: 150),
      child: Text(title, overflow: TextOverflow.ellipsis),
    );
  }
}

/// Ionic iOS `ion-title size="large"` inside the condense header.
/// Renders nothing outside iOS.
class IonLargeTitle extends StatelessWidget {
  const IonLargeTitle(this.title, {super.key, this.padding});

  /// Height of the condense toolbar (used for the collapse threshold).
  static const double height = 52;

  final String title;

  /// Override when the scroll view already has horizontal padding.
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    if (!ionIsIos(context)) return const SizedBox.shrink();
    final base = Theme.of(context).textTheme.headlineLarge ?? const TextStyle();
    return Container(
      constraints: const BoxConstraints(minHeight: height),
      alignment: Alignment.bottomLeft,
      padding: padding ?? const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: Text(
        title,
        style: base.copyWith(
          fontSize: 34,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
          height: 1.2,
          color: IonIos.text(context),
        ),
      ),
    );
  }
}
