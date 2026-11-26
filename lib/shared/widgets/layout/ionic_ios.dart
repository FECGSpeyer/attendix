import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import '../../../core/theme/redesign/rd_theme.dart';
import '../adaptive/app_toolbar.dart'
    show kIonModalToolbarHeight, kIonTitleFontSize;

/// Collapsing large-title header on iOS: the page shows a large title at the
/// top of the scroll view ([IonLargeTitle]) and the toolbar title fades in
/// once scrolled past. Elsewhere the toolbar title is always visible.
class CondenseHeader extends StatefulWidget {
  const CondenseHeader({super.key, required this.builder, this.enabled = true});

  final Widget Function(BuildContext context, bool condensed) builder;
  final bool enabled;

  @override
  State<CondenseHeader> createState() => _CondenseHeaderState();
}

class _CondenseHeaderState extends State<CondenseHeader> {
  static const double _threshold = 40;
  bool _condensed = false;

  bool _onScroll(ScrollNotification n) {
    if (n.metrics.axis != Axis.vertical || n.depth != 0) return false;
    final condensed = n.metrics.pixels > _threshold;
    if (condensed != _condensed) setState(() => _condensed = condensed);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled || Theme.of(context).platform != TargetPlatform.iOS) {
      return widget.builder(context, true);
    }
    return NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: widget.builder(context, _condensed),
    );
  }
}

class _TranslucentBarBackground extends StatelessWidget {
  const _TranslucentBarBackground({required this.visible});

  final bool visible;

  @override
  Widget build(BuildContext context) {
    if (!visible || Theme.of(context).platform != TargetPlatform.iOS) {
      return const SizedBox.shrink();
    }
    final rd = context.rd;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: rd.bg.withValues(alpha: 0.96),
        border: Border(bottom: BorderSide(color: rd.line)),
      ),
      child: const SizedBox.expand(),
    );
  }
}

/// Translucent iOS toolbar wrapper for scrolling pages with `extendBodyBehindAppBar`.
/// On non-iOS platforms [child] is returned unchanged.
class IonTranslucentAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const IonTranslucentAppBar({
    super.key,
    required this.child,
    this.condensed = true,
    this.condensedListenable,
    this.background,
  });

  final PreferredSizeWidget child;
  final bool condensed;
  final ValueListenable<bool>? condensedListenable;
  final Color? background;

  @override
  Size get preferredSize => child.preferredSize;

  @override
  Widget build(BuildContext context) {
    if (Theme.of(context).platform != TargetPlatform.iOS) return child;
    final theme = Theme.of(context);
    return Stack(
      children: [
        Positioned.fill(
          child: condensedListenable == null
              ? _TranslucentBarBackground(visible: condensed)
              : ValueListenableBuilder<bool>(
                  valueListenable: condensedListenable!,
                  builder: (context, value, _) =>
                      _TranslucentBarBackground(visible: value),
                ),
        ),
        Theme(
          data: theme.copyWith(
            appBarTheme: theme.appBarTheme.copyWith(
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              shape: const Border(),
            ),
          ),
          child: child,
        ),
      ],
    );
  }
}

/// Top spacer for a scroll view inside a Scaffold with `extendBodyBehindAppBar`.
class IonContentTopInset extends StatelessWidget {
  const IonContentTopInset({super.key});

  @override
  Widget build(BuildContext context) =>
      SizedBox(height: MediaQuery.paddingOf(context).top);
}

/// [IonContentTopInset] as the first sliver of a [CustomScrollView].
class SliverIonContentTopInset extends StatelessWidget {
  const SliverIonContentTopInset({super.key});

  @override
  Widget build(BuildContext context) =>
      const SliverToBoxAdapter(child: IonContentTopInset());
}

/// Adaptive pull-to-refresh positioned below an extended translucent toolbar.
class IonRefresher extends StatelessWidget {
  const IonRefresher({super.key, required this.onRefresh, required this.child});

  final RefreshCallback onRefresh;
  final Widget child;

  @override
  Widget build(BuildContext context) => RefreshIndicator.adaptive(
        onRefresh: onRefresh,
        edgeOffset: MediaQuery.paddingOf(context).top,
        child: child,
      );
}

/// Toolbar title that fades in when the large title is condensed.
class CondenseTitle extends StatelessWidget {
  const CondenseTitle({
    super.key,
    required this.condensed,
    required this.child,
  });

  final bool condensed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: condensed ? 1 : 0,
      duration: const Duration(milliseconds: 150),
      child: child,
    );
  }
}

/// Large scrolling page title on iOS; renders nothing outside iOS.
class IonLargeTitle extends StatelessWidget {
  const IonLargeTitle(this.title, {super.key, this.enabled = true});

  final String title;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (!enabled || Theme.of(context).platform != TargetPlatform.iOS) {
      return const SizedBox.shrink();
    }
    final rd = context.rd;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: Semantics(
        header: true,
        child: Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: RdType.title(rd),
        ),
      ),
    );
  }
}

/// Uppercase eyebrow group header above an [IonInsetList].
class IonListHeader extends StatelessWidget {
  const IonListHeader(this.label, {super.key, this.trailing, this.color});

  final String label;
  final List<Widget>? trailing;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final rd = context.rd;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, trailing == null ? 20 : 8, 6),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                label.toUpperCase(),
                style: RdType.eyebrow(color ?? rd.text2),
              ),
            ),
          ),
          if (trailing != null)
            _PrimaryIconButtons(
              child: Row(mainAxisSize: MainAxisSize.min, children: trailing!),
            ),
        ],
      ),
    );
  }
}

/// Surface background colour for rows inside inset grouped lists.
Color ionItemBackground(BuildContext context) => context.rd.surface;

/// Rounded inset card list with full-width 1px dividers between rows.
class IonInsetList extends StatelessWidget {
  const IonInsetList({
    super.key,
    required this.children,
    this.grouped = true,
    this.dividerIndent = 16,
    this.margin = const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    this.color,
    this.border,
  });

  final List<Widget> children;
  final bool grouped;
  final double dividerIndent;
  final EdgeInsetsGeometry margin;
  final Color? color;
  final BoxBorder? border;

  static double radiusOf(BuildContext context, {bool grouped = true}) =>
      context.rd.listRadius;

  @override
  Widget build(BuildContext context) {
    final rd = context.rd;
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        rows.add(Divider(height: 1, thickness: 1, color: rd.line));
      }
      rows.add(children[i]);
    }
    return Container(
      margin: margin,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: color ?? rd.surface,
        borderRadius: BorderRadius.circular(rd.listRadius),
        border: border,
        boxShadow: rd.cardShadow,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: rows,
        ),
      ),
    );
  }
}

/// List row inside an [IonInsetList]: 52pt min height, 16pt title, 13pt subtitle,
/// optional trailing widget and chevron when [detail] is true.
class IonItem extends StatelessWidget {
  const IonItem({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.detail = false,
    this.titleColor,
  });

  final Widget? leading;
  final Widget title;
  final Widget? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool detail;
  final Color? titleColor;

  @override
  Widget build(BuildContext context) {
    final rd = context.rd;
    final chevron = detail && onTap != null;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            children: [
              if (leading != null) ...[
                IconTheme.merge(
                  data: IconThemeData(color: rd.text2, size: 22),
                  child: leading!,
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DefaultTextStyle.merge(
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: titleColor ?? rd.text,
                      ),
                      child: title,
                    ),
                    if (subtitle != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: DefaultTextStyle.merge(
                          style: RdType.meta(rd, size: 13),
                          child: subtitle!,
                        ),
                      ),
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 8), trailing!],
              if (chevron) ...[
                const SizedBox(width: 4),
                Icon(Icons.chevron_right, size: 20, color: rd.text2),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Header toolbar of a sheet modal: centred title, optional subtitle, start/end
/// action slots and a 1px divider below.
class IonSheetHeader extends StatelessWidget {
  const IonSheetHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.start = const [],
    this.end = const [],
    this.border = true,
  });

  final String title;
  final String? subtitle;
  final List<Widget> start;
  final List<Widget> end;
  final bool border;

  @override
  Widget build(BuildContext context) {
    final rd = context.rd;
    final mainTitle = Text(
      title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: kIonTitleFontSize,
        fontWeight: FontWeight.w600,
        color: rd.text,
      ),
    );
    final titleWidget = subtitle == null || subtitle!.isEmpty
        ? mainTitle
        : Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              mainTitle,
              Text(
                subtitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: rd.text2),
              ),
            ],
          );
    final header = Container(
      height: kIonModalToolbarHeight,
      decoration: BoxDecoration(
        color: rd.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: _PrimaryIconButtons(
        child: Stack(
          alignment: Alignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 96),
              child: titleWidget,
            ),
            Positioned(
              left: 4,
              top: 0,
              bottom: 0,
              child: Row(mainAxisSize: MainAxisSize.min, children: start),
            ),
            Positioned(
              right: 4,
              top: 0,
              bottom: 0,
              child: Row(mainAxisSize: MainAxisSize.min, children: end),
            ),
          ],
        ),
      ),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        header,
        if (border) Divider(height: 1, thickness: 1, color: rd.line),
      ],
    );
  }
}

class _PrimaryIconButtons extends StatelessWidget {
  const _PrimaryIconButtons({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final color = context.rd.link;
    return IconButtonTheme(
      data: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: color),
      ),
      child: IconTheme.merge(
        data: IconThemeData(color: color),
        child: child,
      ),
    );
  }
}
