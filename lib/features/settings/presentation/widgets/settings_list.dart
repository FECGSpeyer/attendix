import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/redesign/rd_theme.dart';
import '../../../../shared/widgets/display/ion_badge_text.dart';

/// Horizontal page padding around inset settings lists.
double ionListMargin(BuildContext context) => AppDimensions.paddingM;

Widget _listTileTheme(BuildContext context, {required Widget child}) {
  final rd = context.rd;
  return ListTileTheme.merge(
    contentPadding: const EdgeInsets.symmetric(horizontal: 14),
    minTileHeight: 52,
    minVerticalPadding: 8,
    horizontalTitleGap: 12,
    minLeadingWidth: 22,
    iconColor: rd.text2,
    titleTextStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: rd.text),
    subtitleTextStyle: RdType.meta(rd, size: 13),
    leadingAndTrailingTextStyle: RdType.meta(rd, size: 15),
    child: IconTheme.merge(data: const IconThemeData(size: 22), child: child),
  );
}

/// Grouped settings section with an optional eyebrow header and card list.
class SettingsListSection extends StatelessWidget {
  const SettingsListSection({
    super.key,
    this.title,
    this.icon,
    this.headerAction,
    required this.children,
    this.footer,
    this.dividerIndent,
    this.icons = true,
  });

  final String? title;
  final IconData? icon;
  final Widget? headerAction;
  final List<Widget> children;
  final Widget? footer;
  final double? dividerIndent;
  final bool icons;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty && footer == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null)
            _ListHeader(title: title!, icon: icon, action: headerAction),
          if (children.isNotEmpty) _InsetGroup(children: children),
          if (footer != null) footer!,
        ],
      ),
    );
  }
}

class _ListHeader extends StatelessWidget {
  const _ListHeader({required this.title, this.icon, this.action});

  final String title;
  final IconData? icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final rd = context.rd;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 4, action == null ? 20 : 4, 6),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: rd.primary),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: Semantics(
              header: true,
              child: Text(title.toUpperCase(), style: RdType.eyebrow(rd.text2)),
            ),
          ),
          if (action != null)
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 32),
              child: action!,
            ),
        ],
      ),
    );
  }
}

class _InsetGroup extends StatelessWidget {
  const _InsetGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final rd = context.rd;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: rd.surface,
        borderRadius: BorderRadius.circular(rd.listRadius),
        boxShadow: rd.cardShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(rd.listRadius),
        child: Material(
          type: MaterialType.transparency,
          child: _listTileTheme(
            context,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0) Divider(height: 1, thickness: 1, color: rd.line),
                  children[i],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailChevron extends StatelessWidget {
  const _DetailChevron();

  @override
  Widget build(BuildContext context) =>
      Icon(Icons.chevron_right, size: 20, color: context.rd.text2);
}

/// Settings list row with optional leading icon, subtitle, trailing widget and chevron.
class SettingsListTile extends StatelessWidget {
  const SettingsListTile({
    super.key,
    this.icon,
    this.iconWidget,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.detail,
    this.color,
    this.iconColor,
    this.background,
    this.titleWidget,
  });

  final IconData? icon;
  final Widget? iconWidget;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool? detail;
  final Color? color;
  final Color? iconColor;
  final Color? background;
  final Widget? titleWidget;

  @override
  Widget build(BuildContext context) {
    final rd = context.rd;
    final onColor = background != null ? Colors.white : null;
    final fg = onColor ?? color;
    final iconFg = onColor ?? iconColor ?? color ?? rd.text2;
    final showChevron = onTap != null && (detail ?? true);
    final tile = ListTile(
      leading: iconWidget != null
          ? IconTheme.merge(
              data: IconThemeData(color: iconFg, size: 22),
              child: iconWidget!,
            )
          : icon != null
              ? Icon(icon, color: iconFg, size: 22)
              : null,
      title: titleWidget ?? Text(title, style: TextStyle(color: fg)),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: TextStyle(
                fontSize: 13,
                color: background != null ? Colors.white70 : rd.text2,
              ),
            )
          : null,
      trailing: (trailing != null || showChevron)
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (trailing != null) trailing!,
                if (showChevron) ...[
                  if (trailing != null) const SizedBox(width: 8),
                  const _DetailChevron(),
                ],
              ],
            )
          : null,
      onTap: onTap,
    );
    if (background == null) return tile;
    return Material(color: background, child: tile);
  }
}

/// Rounded badge pill (13px bold).
class IonBadge extends StatelessWidget {
  const IonBadge({
    super.key,
    required this.text,
    this.color = AppColors.primary,
    this.textColor = Colors.white,
  });

  final String text;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 26),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: ionBadgeTextStyle(color: textColor),
      ),
    );
  }
}

/// Card with a header icon and centred hint text (used above Admins/Eltern/Beobachter lists).
class SettingsHintCard extends StatelessWidget {
  const SettingsHintCard({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final rd = context.rd;
    return Container(
      margin: const EdgeInsets.only(bottom: AppDimensions.paddingM),
      decoration: BoxDecoration(
        color: rd.surface,
        borderRadius: BorderRadius.circular(rd.cardRadius),
        boxShadow: rd.cardShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(icon, size: 40, color: rd.primary),
            const SizedBox(height: AppDimensions.paddingS),
            Text(text, textAlign: TextAlign.center, style: RdType.meta(rd)),
          ],
        ),
      ),
    );
  }
}

/// Stacked label + input field for settings forms.
///
/// iOS: plain borderless row inside a grouped card; other platforms: filled Material field.
class IonStackedField extends StatelessWidget {
  const IonStackedField({
    super.key,
    this.label,
    this.helper,
    this.hint,
    required this.builder,
    this.flush = false,
  });

  final String? label;
  final String? helper;
  final String? hint;
  final bool flush;
  final Widget Function(InputDecoration decoration) builder;

  @override
  Widget build(BuildContext context) {
    final rd = context.rd;
    if (Theme.of(context).platform != TargetPlatform.iOS) {
      return Padding(
        padding: EdgeInsets.symmetric(
          horizontal: flush ? 0 : AppDimensions.paddingM,
          vertical: AppDimensions.paddingS,
        ),
        child: builder(InputDecoration(
          labelText: label,
          helperText: helper,
          helperMaxLines: 4,
          hintText: hint,
        )),
      );
    }
    final base = (Theme.of(context).textTheme.bodyLarge ?? const TextStyle())
        .copyWith(letterSpacing: 0);
    return Padding(
      padding: flush
          ? const EdgeInsets.symmetric(vertical: 8)
          : const EdgeInsets.fromLTRB(16, 10, 18, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (label != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                label!,
                style: base.copyWith(fontSize: 14, color: rd.text),
              ),
            ),
          Theme(
            data: Theme.of(context).copyWith(
              textTheme: Theme.of(context).textTheme.copyWith(
                    bodyLarge: base.copyWith(fontSize: 16),
                    titleMedium: base.copyWith(fontSize: 16),
                  ),
            ),
            child: builder(InputDecoration(
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              filled: false,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 6),
              hintText: hint,
              hintStyle: base.copyWith(fontSize: 16, color: rd.text2),
              helperText: helper,
              helperMaxLines: 4,
              helperStyle: base.copyWith(fontSize: 12, color: rd.text2),
              errorStyle: base.copyWith(fontSize: 12, color: AppColors.danger),
            )),
          ),
        ],
      ),
    );
  }
}

/// Stacked label + read-only value row (e.g. date picker trigger).
class IonStackedValue extends StatelessWidget {
  const IonStackedValue({
    super.key,
    required this.label,
    required this.value,
    this.helper,
    this.onTap,
    this.trailing,
    this.flush = false,
  });

  final bool flush;
  final String label;
  final String value;
  final String? helper;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final rd = context.rd;
    if (Theme.of(context).platform != TargetPlatform.iOS) {
      return ListTile(
        contentPadding: flush ? EdgeInsets.zero : null,
        title: Text(label),
        subtitle: Text(helper == null ? value : '$value\n$helper'),
        isThreeLine: helper != null,
        trailing: trailing,
        onTap: onTap,
      );
    }
    final base = (Theme.of(context).textTheme.bodyLarge ?? const TextStyle())
        .copyWith(letterSpacing: 0);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: flush
            ? const EdgeInsets.symmetric(vertical: 10)
            : const EdgeInsets.fromLTRB(16, 10, 18, 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: base.copyWith(fontSize: 14, color: rd.text)),
                  const SizedBox(height: 4),
                  Text(value, style: base.copyWith(fontSize: 16, color: rd.text)),
                  if (helper != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      helper!,
                      style: base.copyWith(fontSize: 12, color: rd.text2),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}
