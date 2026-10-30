import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/redesign/rd_theme.dart';
import 'package:attendix/shared/widgets/layout/ios_tab_bar.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';
import '../../../../shared/widgets/layout/ionic_ios.dart'
    show IonTranslucentAppBar, IonContentTopInset; // PARITY_R5, IOS_R6
import '../../../../shared/widgets/layout/ionic_ios.dart' as ios27
    show IonIos, IonDetailChevron, IonSearchbar, IonLargeTitle;
import '../../../../shared/widgets/display/ion_badge_text.dart';
import '../../../../shared/widgets/layout/ionic_md.dart';

// UX_PLANNING (wave 8): page-structure building blocks that mirror the Ionic
// components as rendered in iOS mode (the app on an iPhone). They are used by
// the planning, team organisation, duty and shift pages. On other platforms
// they keep the Material look (Ionic md mode).

/// True when the app renders like Ionic iOS mode (iPhone app and iPhone Safari).
/// Same as the shared adaptive [useIosLook]. `ion-segment` in the page
/// content is the shared adaptive [IonSegment].
bool isIonIos(BuildContext context) => useIosLook(context);

/// Ionic `ion-list-header` with optional trailing note/button. iOS
/// (IOS27_SWEEP): in a plain list the core header – min(1.375rem, 56.1px)
/// = 23.375pt bold in step-850 (#262626, dark #d9d9d9); in an inset list
/// ([inset], ionic-theme-ios27 structured list) the 17pt semibold label in
/// `rgba(medium, .75)` with margin 8 / 4 / 4.
class IonListHeader extends StatelessWidget {
  const IonListHeader({
    super.key,
    this.title = '',
    this.titleWidget,
    this.trailing,
    this.color,
    this.padding = const EdgeInsets.fromLTRB(16, 0, 4, 6),
    this.inset = false,
  });

  final String title;

  /// Custom label content (styled like [title]).
  final Widget? titleWidget;
  final Widget? trailing;

  /// Label color (Ionic e.g. `.is-overdue` → danger).
  final Color? color;
  final EdgeInsetsGeometry padding;

  /// Header of an `ion-list [inset]="true"` (see [IonInsetList]).
  final bool inset;

  @override
  Widget build(BuildContext context) {
    final rd = context.rdSkin;
    if (rd != null) {
      // Beta-Skin: uppercase group label (inset) / section heading.
      final style = inset ? RdType.eyebrow(color ?? rd.text2) : RdType.section(rd).copyWith(color: color);
      return Padding(
        padding: inset ? const EdgeInsets.fromLTRB(4, 4, 4, 6) : const EdgeInsets.fromLTRB(20, 16, 4, 8),
        child: Row(
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: titleWidget != null
                    ? DefaultTextStyle.merge(style: style, child: titleWidget!)
                    : Text(inset ? title.toUpperCase() : title, style: style),
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      );
    }
    final theme = Theme.of(context);
    final ios = isIonIos(context);
    final dark = theme.brightness == Brightness.dark;
    final style = ios
        ? (inset
            ? ios27.IonIos.listHeaderStyle(context, color: color)
            : TextStyle(
                fontSize: 1.375 * ios27.IonIos.rem,
                fontWeight: FontWeight.w700,
                color: color ?? (dark ? const Color(0xFFD9D9D9) : const Color(0xFF262626)),
              ))
        // MD_SWEEP: md-ion-list-inset header (16px semibold medium-tint)
        // / plain md list header (14px, text colour).
        : (inset
            ? IonMd.insetListHeaderStyle(theme.brightness, color: color)
            : IonMd.listHeaderStyle(theme.brightness, color: color));
    return ConstrainedBox(
      constraints: BoxConstraints(
          minHeight: ios ? 40 : IonMd.listHeaderMinHeight),
      child: Padding(
        // ios27 inset header: 16pt header padding + 4pt label margin
        // inside the 16pt list margin; label margin 8 / 4 (md the same).
        padding: inset ? const EdgeInsets.fromLTRB(20, 8, 4, 4) : padding,
        child: Row(
          crossAxisAlignment:
              ios ? CrossAxisAlignment.end : CrossAxisAlignment.center,
          children: [
            Expanded(
              child: titleWidget != null
                  ? DefaultTextStyle.merge(style: style, child: titleWidget!)
                  : Text(title, style: style),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

/// Ionic `ion-list [inset]="true"` with an optional `ion-list-header`:
/// the header sits on the grey page background, the items in a rounded white
/// group separated by inset lines.
class IonInsetList extends StatelessWidget {
  const IonInsetList({
    super.key,
    this.header,
    this.headerTrailing,
    this.headerColor,
    required this.children,
    this.dividerIndent = 16,
    this.margin = const EdgeInsets.fromLTRB(16, 16, 16, 0),
    this.headerWidget,
  });

  final String? header;
  final Widget? headerTrailing;
  final Color? headerColor;

  /// Replaces the default [IonListHeader] (e.g. a header with an edit icon).
  final Widget? headerWidget;
  final List<Widget> children;

  /// Start of the item lines (Ionic `lines="inset"` starts at the label).
  /// `null` hides the lines (Ionic `lines="none"`).
  final double? dividerIndent;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final head = headerWidget ??
        (header != null
            ? IonListHeader(title: header!, trailing: headerTrailing, color: headerColor, inset: true)
            : null);
    return Padding(
      padding: margin,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (head != null) head,
          if (children.isNotEmpty)
            // MD_SWEEP: md inset group – radius 16, item background, no
            // shadow, 1px lines.
            if (context.rdSkin case final rd?)
              // Beta-Skin: grouped list of the new design.
              DecoratedBox(
                decoration: BoxDecoration(
                  color: rd.surface,
                  borderRadius: BorderRadius.circular(rd.listRadius),
                  boxShadow: rd.cardShadow,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(rd.listRadius),
                  child: Material(
                    type: MaterialType.transparency,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var i = 0; i < children.length; i++) ...[
                          if (i > 0 && dividerIndent != null) Divider(height: 1, thickness: 1, color: rd.line),
                          children[i],
                        ],
                      ],
                    ),
                  ),
                ),
              )
            else
            Card(
              margin: EdgeInsets.zero,
              elevation: 0,
              color: isIonIos(context)
                  ? null
                  : IonMd.itemBackground(Theme.of(context).brightness),
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                      isIonIos(context) ? 10 : IonMd.groupRadius)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < children.length; i++) ...[
                    if (i > 0 && dividerIndent != null)
                      Divider(height: 1, thickness: isIonIos(context) ? 0.5 : 1, indent: dividerIndent),
                    children[i],
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Ionic `ion-badge` (iOS: max(13px, .8125rem) = 13.81pt bold, line-height
/// 1, radius 10). Text uses the color's contrast (black on warning, white
/// otherwise).
class IonBadge extends StatelessWidget {
  const IonBadge({super.key, required this.label, required this.color, this.textColor});

  final String label;
  final Color color;
  final Color? textColor;

  static Color contrastOf(Color color) =>
      color == AppColors.warning || color == AppColors.orange || color == AppColors.mint ? Colors.black : Colors.white;

  @override
  Widget build(BuildContext context) => Container(
        // MD_SWEEP: badge.md.css – padding 3 4 4 4, radius 4.
        padding: isIonIos(context)
            ? const EdgeInsets.symmetric(horizontal: 8, vertical: 3)
            : IonMd.badgePadding,
        decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(
                isIonIos(context) ? 10 : IonMd.badgeRadius)),
        child: Text(
          label,
          // PARITY_R8: ion-badge is bold (700) in both modes
          style: isIonIos(context)
              ? ionBadgeTextStyle(
                  color: textColor ?? contrastOf(color),
                  fontSize: 0.8125 * ios27.IonIos.rem,
                )
              : ionBadgeTextStyle(color: textColor ?? contrastOf(color)),
        ),
      );
}

/// Ionic `ion-note` in an item end slot: grey text (iOS: max(16px, 1rem)
/// = 17pt step-350, #a6a6a6 / dark #595959).
class IonNote extends StatelessWidget {
  const IonNote(this.text, {super.key, this.style});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: (isIonIos(context)
                ? TextStyle(
                    color: ios27.IonIos.note(Theme.of(context).brightness),
                    fontSize: ios27.IonIos.noteFontSize,
                  )
                // MD_SWEEP: md item note .6875rem step-600.
                : TextStyle(
                    color: IonMd.note(Theme.of(context).brightness),
                    fontSize: IonMd.itemNoteFontSize,
                  ))
            .merge(style),
      );
}

/// Ionic iOS `detail` chevron of a button item.
class IonDetailIcon extends StatelessWidget {
  const IonDetailIcon({super.key});

  @override
  Widget build(BuildContext context) => isIonIos(context)
      ? const ios27.IonDetailChevron()
      // MD_SWEEP: md detail icon – 20px, text colour at .25.
      : Icon(Icons.chevron_right,
          size: 20,
          color: IonMd.text(Theme.of(context).brightness)
              .withValues(alpha: 0.25));
}

/// Ionic empty/hint state (icon, optional bold line, grey text, optional action).
class IonEmptyState extends StatelessWidget {
  const IonEmptyState({
    super.key,
    required this.icon,
    this.title,
    required this.text,
    this.action,
    this.padding = const EdgeInsets.fromLTRB(24, 56, 24, 24),
    this.iconSize = 44,
  });

  final IconData icon;
  final String? title;
  final String text;
  final Widget? action;
  final EdgeInsetsGeometry padding;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: iconSize, color: AppColors.medium),
              const SizedBox(height: 12),
              if (title != null) ...[
                Text(
                  title!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
              ],
              if (text.isNotEmpty)
                Text(text, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.medium)),
              if (action != null) ...[const SizedBox(height: 8), action!],
            ],
          ),
        ),
      ),
    );
  }
}

/// Ionic `ion-searchbar`: the iOS search field (grey rounded, magnifier,
/// clear button) on iOS, a Material search field elsewhere.
class IonSearchbar extends StatefulWidget {
  const IonSearchbar({
    super.key,
    required this.placeholder,
    required this.onChanged,
    this.controller,
    this.padding,
  });

  final String placeholder;

  /// Optional external controller (e.g. to clear the search programmatically).
  final TextEditingController? controller;
  final ValueChanged<String> onChanged;

  /// Defaults to the ios27 host padding 8 (iOS) / 12, 8, 12, 4 (md).
  final EdgeInsetsGeometry? padding;

  @override
  State<IonSearchbar> createState() => _IonSearchbarState();
}

class _IonSearchbarState extends State<IonSearchbar> {
  TextEditingController? _own;

  TextEditingController get _controller => widget.controller ?? (_own ??= TextEditingController());

  @override
  void dispose() {
    _own?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ios = isIonIos(context);
    return Padding(
      padding: widget.padding ??
          (ios ? const EdgeInsets.all(8) : IonMd.searchbarPadding),
      child: ios
          // IOS27_SWEEP: the shared ios27 glass searchbar
          ? ios27.IonSearchbar(
              controller: _controller,
              hintText: widget.placeholder,
              onChanged: widget.onChanged,
            )
          // MD_SWEEP: the shared Ionic md searchbar.
          : IonMdSearchbar(
              controller: _controller,
              hintText: widget.placeholder,
              onChanged: widget.onChanged,
              padding: EdgeInsets.zero,
            ),
    );
  }
}

/// Ionic `ion-segment` in a header toolbar: the iOS segmented control on
/// iOS, a Material [TabBar] elsewhere. Drives a [TabController].
class IonSegmentBar extends StatefulWidget implements PreferredSizeWidget {
  const IonSegmentBar({super.key, required this.controller, required this.labels});

  final TabController controller;
  final List<String> labels;

  @override
  Size get preferredSize => const Size.fromHeight(48);

  @override
  State<IonSegmentBar> createState() => _IonSegmentBarState();
}

class _IonSegmentBarState extends State<IonSegmentBar> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTab);
  }

  @override
  void didUpdateWidget(covariant IonSegmentBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onTab);
      widget.controller.addListener(_onTab);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTab);
    super.dispose();
  }

  void _onTab() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (!isIonIos(context)) {
      // MD_SWEEP: the shared md ion-segment (UPPERCASE 14px medium labels,
      // 48px buttons at most 360 wide, centred, 2px primary indicator).
      return IonSegment<int>(
        items: [
          for (var i = 0; i < widget.labels.length; i++)
            IonSegmentItem<int>(value: i, label: Text(widget.labels[i])),
        ],
        value: widget.controller.index,
        onChanged: (v) => widget.controller.animateTo(v),
      );
    }
    // Shared adaptive `ion-segment` (IOS_LOOK).
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: IonSegment<int>(
        items: [
          for (var i = 0; i < widget.labels.length; i++)
            IonSegmentItem<int>(value: i, label: Text(widget.labels[i])),
        ],
        value: widget.controller.index,
        onChanged: (v) => widget.controller.animateTo(v),
      ),
    );
  }
}

/// Ionic `ion-chip` filter row item (`outline` when not selected).
class IonFilterChip extends StatelessWidget {
  const IonFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.selectedColor = AppColors.primaryDark,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color selectedColor;

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).cardTheme.color ?? Theme.of(context).colorScheme.surface;
    return Material(
      color: selected ? selectedColor : surface,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

/// Decoration of an `ion-input labelPlacement="stacked"` inside an item:
/// small label above the value, no field box.
InputDecoration ionStackedInputDecoration({required String label, String? hint}) => InputDecoration(
      labelText: label,
      hintText: hint,
      floatingLabelBehavior: FloatingLabelBehavior.always,
      filled: false,
      isDense: true,
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      disabledBorder: InputBorder.none,
      errorBorder: InputBorder.none,
      focusedErrorBorder: InputBorder.none,
      contentPadding: const EdgeInsets.only(top: 6, bottom: 4),
    );

/// Ionic `ion-item` > `ion-input`/`ion-textarea` with a stacked label.
class IonStackedInput extends StatelessWidget {
  const IonStackedInput({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.minLines,
    this.maxLines = 1,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.sentences,
    this.onChanged,
    this.onFocusLost,
    this.enabled = true,
    this.autofocus = false,
    this.helper,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final int? minLines;
  final int? maxLines;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final ValueChanged<String>? onChanged;

  /// Ionic `(ionBlur)`.
  final VoidCallback? onFocusLost;
  final bool enabled;
  final bool autofocus;

  /// Ionic `helperText` shown below the input.
  final String? helper;

  @override
  Widget build(BuildContext context) {
    Widget field = TextField(
      controller: controller,
      enabled: enabled,
      autofocus: autofocus,
      minLines: minLines,
      maxLines: maxLines,
      keyboardType: keyboardType ?? (maxLines == 1 ? null : TextInputType.multiline),
      textCapitalization: textCapitalization,
      decoration: ionStackedInputDecoration(label: label, hint: hint).copyWith(
        helperText: helper,
        helperMaxLines: 4,
      ),
      onChanged: onChanged,
    );
    if (onFocusLost != null) {
      field = Focus(
        onFocusChange: (f) {
          if (!f) onFocusLost!();
        },
        child: field,
      );
    }
    return Padding(padding: const EdgeInsets.fromLTRB(16, 10, 16, 6), child: field);
  }
}

/// Ionic `ion-item` > `ion-input` with the label on the left and the value
/// right aligned (`class="ion-text-end"`).
class IonInlineInput extends StatelessWidget {
  const IonInlineInput({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.keyboardType,
    this.onChanged,
    this.inputFormatters,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final List<TextInputFormatter>? inputFormatters;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(width: 16),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
              textAlign: TextAlign.end,
              inputFormatters: inputFormatters,
              decoration: ionStackedInputDecoration(label: '', hint: hint).copyWith(
                labelText: null,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

/// Ionic `ion-select` inside an `ion-item`: the label on the left, the
/// selected value (grey) with a caret on the right, no field box.
class IonSelect<T> extends StatelessWidget {
  const IonSelect({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.leading,
  });

  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 12),
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 16)],
          Text(label, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(width: 16),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: AppDropdownButton<T>(
                value: value,
                isExpanded: true,
                alignment: AlignmentDirectional.centerEnd,
                items: items,
                selectedItemBuilder: (context) => [
                  for (final it in items)
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: DefaultTextStyle.merge(
                        style: const TextStyle(color: AppColors.medium),
                        overflow: TextOverflow.ellipsis,
                        child: it.child,
                      ),
                    ),
                ],
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Ionic `ion-datetime-button`: grey rounded chip showing the date/time
/// (no "Uhr" suffix). Without [onTap] it is read-only (disabled datetime).
class IonDatetimeChip extends StatelessWidget {
  const IonDatetimeChip({super.key, required this.text, this.onTap});

  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = isDark ? const Color(0xFF2C2C2E) : const Color(0xFFEDEEF0);
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Text(text, style: Theme.of(context).textTheme.bodyLarge),
        ),
      ),
    );
  }
}

/// Ionic `ion-header collapse="condense"`: on iOS the page shows a large
/// title at the top of the content that condenses into the toolbar title
/// when scrolled. Elsewhere it is a normal [AppBar] page.
class IonCondenseScaffold extends StatefulWidget {
  const IonCondenseScaffold({
    super.key,
    required this.title,
    required this.bodyBuilder,
    this.actions,
    this.leading,
    this.automaticallyImplyLeading = true,
    this.floatingActionButton,
    this.backgroundColor,
  });

  final String title;

  /// Builds the scrollable body; [largeTitle] (iOS only, else null) must be
  /// the first child of the scroll view.
  final Widget Function(BuildContext context, Widget? largeTitle) bodyBuilder;
  final List<Widget>? actions;
  final Widget? leading;
  final bool automaticallyImplyLeading;
  final Widget? floatingActionButton;
  final Color? backgroundColor;

  @override
  State<IonCondenseScaffold> createState() => _IonCondenseScaffoldState();
}

class _IonCondenseScaffoldState extends State<IonCondenseScaffold> {
  bool _condensed = false;

  bool _onScroll(ScrollNotification n) {
    if (n.depth != 0 || n.metrics.axis != Axis.vertical) return false;
    final condensed = n.metrics.pixels > 40;
    if (condensed != _condensed) setState(() => _condensed = condensed);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final ios = isIonIos(context);
    return Scaffold(
      backgroundColor: widget.backgroundColor,
      floatingActionButton: TabBarFab.wrap(widget.floatingActionButton),
      // IOS_R6: Ionic `ion-content fullscreen` under the translucent header
      extendBodyBehindAppBar: ios,
      // IOS_R6: `ion-header translucent` (blur once condensed)
      appBar: IonTranslucentAppBar(
        condensed: _condensed,
        background: widget.backgroundColor,
        child: AppBar(
        leading: widget.leading,
        automaticallyImplyLeading: widget.automaticallyImplyLeading,
        title: ios
            ? AnimatedOpacity(
                opacity: _condensed ? 1 : 0,
                duration: const Duration(milliseconds: 150),
                child: Text(widget.title),
              )
            : Text(widget.title),
        actions: widget.actions,
      ),
      ),
      body: ios
          ? NotificationListener<ScrollNotification>(
              onNotification: _onScroll,
              child: widget.bodyBuilder(
                context,
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // IOS_R6: room for the translucent toolbar
                    const IonContentTopInset(),
                    // IOS27_SWEEP: ios27 large title (36.125pt bold)
                    ios27.IonLargeTitle(widget.title),
                  ],
                ),
              ),
            )
          : widget.bodyBuilder(context, null),
    );
  }
}

/// Ionic `ion-popover` opened from a trigger button: a menu anchored below
/// the widget of [anchorContext].
Future<T?> showIonPopover<T>(
  BuildContext anchorContext, {
  required List<PopupMenuEntry<T>> items,
  BoxConstraints? constraints,
}) {
  final box = anchorContext.findRenderObject() as RenderBox;
  final overlay = Navigator.of(anchorContext).overlay!.context.findRenderObject() as RenderBox;
  final topLeft = box.localToGlobal(Offset(0, box.size.height), ancestor: overlay);
  final bottomRight = box.localToGlobal(box.size.bottomRight(Offset.zero), ancestor: overlay);
  return showMenu<T>(
    context: anchorContext,
    position: RelativeRect.fromRect(Rect.fromPoints(topLeft, bottomRight), Offset.zero & overlay.size),
    constraints: constraints,
    items: items,
  );
}

/// Ionic `ion-chip` (filled tint or outline, 0.5 opacity when disabled).
/// iOS (IOS27_SWEEP, core ios chip): coloured fill 8 %, outline border
/// 32 %, 14.875pt (.875rem), disabled .4.
class IonChip extends StatelessWidget {
  const IonChip({
    super.key,
    required this.label,
    required this.color,
    this.outline = false,
    this.disabled = false,
    this.onTap,
  });

  final String label;
  final Color color;
  final bool outline;
  final bool disabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final shape = StadiumBorder(
      side: outline ? BorderSide(color: color.withValues(alpha: 0.32)) : BorderSide.none,
    );
    final ios = isIonIos(context);
    // MD_SWEEP: md coloured chip – base at .08, text in the shade colour,
    // disabled .4 (chip.md.css).
    return Opacity(
      opacity: disabled ? 0.4 : 1,
      child: Material(
        color: outline ? Colors.transparent : color.withValues(alpha: 0.08),
        shape: shape,
        child: InkWell(
          customBorder: shape,
          onTap: disabled ? null : onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Text(label,
                style: TextStyle(
                    fontSize: ios ? 0.875 * ios27.IonIos.rem : IonMd.chipFontSize,
                    height: ios ? null : 20 / 14,
                    color: ios ? color : IonMd.shade(color))),
          ),
        ),
      ),
    );
  }
}
