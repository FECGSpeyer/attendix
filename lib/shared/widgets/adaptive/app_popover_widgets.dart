part of 'app_popover_menu.dart';

// Popover surface card, section headers, rows, dividers, and trailing buttons.

class _PopoverCard extends StatelessWidget {
  const _PopoverCard({
    required this.ios,
    required this.children,
    this.onBackgroundTap,
    this.opaque = false,
  });

  final bool ios;
  final List<Widget> children;
  final VoidCallback? onBackgroundTap;

  /// PARITY_R8: iOS only – an opaque surface (item background) instead of
  /// the translucent glass, used for the parent while a nested popover is
  /// open.
  final bool opaque;

  @override
  Widget build(BuildContext context) {
    Widget list = SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
    if (onBackgroundTap != null) {
      list = GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: onBackgroundTap,
        child: list,
      );
    }
    final rd = context.rd;
    return Material(
      color: rd.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: rd.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: list,
    );
  }
}

class _PopoverHeader extends StatelessWidget {
  const _PopoverHeader({
    required this.ios,
    required this.label,
    this.divider = true,
  });

  final bool ios;
  final String label;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (divider)
        Divider(height: 1, color: Theme.of(context).dividerColor),
        if (label.isNotEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}

class _PopoverRow extends StatelessWidget {
  const _PopoverRow({
    required this.ios,
    required this.label,
    required this.onTap,
    this.icon,
    this.checked,
    this.subtitle,
    this.color,
    this.chevron = false,
    this.focusNode,
    this.autofocus = false,
    this.iconColor,
    this.note,
    this.selected = false,
    this.line = false,
    this.end,
  });

  final bool ios;
  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final bool? checked;
  final String? subtitle;
  final Color? color;
  final bool chevron;
  final FocusNode? focusNode;
  final bool autofocus;

  /// See [AppPopoverMenuItem.iconColor], [AppPopoverMenuItem.note],
  /// [AppPopoverMenuItem.selected], [AppPopoverMenuItem.lines] and
  /// [AppPopoverMenuItem.end].
  final Color? iconColor;
  final String? note;
  final bool selected;
  final bool line;
  final Widget? end;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final fg = color ?? (selected ? AppColors.primary : onSurface);
    // md: `ion-icon` in an item = rgba(text, .54), 24 px, 32 px gap.
    final iconColor = this.iconColor ??
        color ??
        (ios ? onSurface : onSurface.withValues(alpha: 0.54));

    Widget? leading;
    if (checked != null) {
      // Purely decorative: IgnorePointer alone leaves it Tab-focusable, where
      // Enter / Space would hit the no-op onChanged. ExcludeFocus keeps the
      // focus on the row itself, which toggles (semantics stay for the state).
      leading = ExcludeFocus(
        child: IgnorePointer(
          child: SizedBox(
            width: 24,
            height: 24,
            child: Checkbox(
              value: checked,
              onChanged: (_) {},
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
          ),
        ),
      );
    } else if (icon != null) {
      leading = Icon(icon, size: 24, color: iconColor);
    }

    final row = InkWell(
      focusNode: focusNode,
      autofocus: autofocus,
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              if (leading != null) ...[
                leading,
                SizedBox(width: checked != null ? 16 : 32),
              ],
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _PopoverLabel(
                      ios: false,
                      label: label,
                      note: note,
                      style: TextStyle(fontSize: 16, color: fg),
                    ),
                    if (subtitle != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          subtitle!,
                          style: TextStyle(
                            fontSize: 14,
                            color: theme.brightness == Brightness.dark
                                ? const Color(0xFF999999)
                                : const Color(0xFF666666),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (selected)
                Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: Icon(
                    AppIcons.check,
                    size: 24,
                    color: AppColors.primary,
                  ),
                ),
              if (end != null) end!,
              if (chevron) ...[
                const SizedBox(width: 6),
                Icon(
                  AppIcons.chevronRight,
                  size: 20,
                  color: onSurface.withValues(alpha: 0.25),
                ),
              ],
            ],
          ),
        ),
      ),
    );
    if (!line) return row;
    return _PopoverLine(
      ios: false,
      inset: 16 +
          (leading == null
              ? 0
              : 24 + (checked != null ? 16 : 32)),
      child: row,
    );
  }
}

class _PopoverLabel extends StatelessWidget {
  const _PopoverLabel({
    required this.ios,
    required this.label,
    required this.style,
    this.note,
  });

  final bool ios;
  final String label;
  final String? note;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Text.rich(
      TextSpan(
        text: label,
        children: [
          if (note != null)
            TextSpan(
              text: ' $note',
              style: TextStyle(
                fontSize: 14,
                color: brightness == Brightness.dark
                    ? const Color(0xFF999999)
                    : const Color(0xFF666666),
              ),
            ),
        ],
      ),
      style: style,
    );
  }
}

/// Item line below [child]: Ionic `--inner-border-width` 0.55px (iOS) /
/// 1px (md) in the item border colour, from [inset] to the end edge.
class _PopoverLine extends StatelessWidget {
  const _PopoverLine({
    required this.ios,
    required this.inset,
    required this.child,
  });

  final bool ios;
  final double inset;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final w = ios ? 0.5 : 1.0;
    return Stack(
      children: [
        child,
        PositionedDirectional(
          start: inset,
          end: 0,
          bottom: 0,
          height: w,
          child: IgnorePointer(
            child: ColoredBox(color: Theme.of(context).dividerColor),
          ),
        ),
      ],
    );
  }
}

/// [AppPopoverMenuItem.info]: `ion-item` (no button) with an `ion-label`
/// holding `<h3>` and `<p>` (both .875rem; the `p` grey).
class _PopoverInfoRow extends StatelessWidget {
  const _PopoverInfoRow({
    required this.ios,
    required this.label,
    required this.subtitle,
    required this.line,
  });

  final bool ios;
  final String label;
  final String? subtitle;
  final bool line;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = AppPopoverText.paragraph(context);
    final row = ConstrainedBox(
      constraints: BoxConstraints(minHeight: ios ? 44 : 48),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: p.fontSize,
                color: theme.colorScheme.onSurface,
              ),
            ),
            if (subtitle != null)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(subtitle!, style: p),
              ),
          ],
        ),
      ),
    );
    if (!line) return row;
    return _PopoverLine(ios: ios, inset: 16, child: row);
  }
}

/// [AppPopoverMenuItem.end]: `ion-button slot="end" fill="clear"
/// size="small"` with an icon – a tap does not select the row.
class _PopoverEndButton extends StatelessWidget {
  const _PopoverEndButton({
    required this.ios,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.color,
  });

  final bool ios;
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      splashRadius: 18,
      color: color ?? AppColors.mediumOf(context),
      icon: Icon(icon, size: 20),
      onPressed: onTap,
    );
  }
}
