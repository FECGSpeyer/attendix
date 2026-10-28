import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';

/// Ionic `ion-list [inset]="true" class="category-list"` with an
/// `ion-list-header` (optional icon + label) and one item group.
///
/// Used by the settings page and its admin sub pages so they share the
/// Ionic look: grey header label above a rounded card with plain list items.
class SettingsListSection extends StatelessWidget {
  const SettingsListSection({
    super.key,
    this.title,
    this.icon,
    this.headerAction,
    required this.children,
    this.footer,
  });

  final String? title;
  final IconData? icon;

  /// Optional button at the end of the header (Ionic header "+" button).
  final Widget? headerAction;
  final List<Widget> children;

  /// Optional widget below the card (e.g. Ionic "Konto löschen" link).
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty && footer == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.paddingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimensions.paddingS,
                AppDimensions.paddingXS,
                AppDimensions.paddingS,
                AppDimensions.paddingXS,
              ),
              child: Row(
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18, color: AppColors.medium),
                    const SizedBox(width: 6),
                  ],
                  Expanded(
                    child: Text(
                      title!,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: AppColors.medium,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (headerAction != null) headerAction!,
                ],
              ),
            ),
          if (children.isNotEmpty)
            Card(
              margin: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (var i = 0; i < children.length; i++) ...[
                    if (i > 0) const Divider(height: 1, indent: 56),
                    children[i],
                  ],
                ],
              ),
            ),
          if (footer != null) footer!,
        ],
      ),
    );
  }
}

/// Ionic `ion-item button` with an `ion-icon slot="start"`, a label and an
/// optional note/badge at the end. [detail] shows the chevron (Ionic
/// `detail="true"`, the default for router links).
class SettingsListTile extends StatelessWidget {
  const SettingsListTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.detail = true,
    this.color,
    this.iconColor,
    this.background,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool detail;

  /// Label color (Ionic `ion-label color="..."`).
  final Color? color;

  /// Icon color (Ionic `ion-icon color="..."`), defaults to [color].
  final Color? iconColor;

  /// Item background (Ionic `ion-item color="danger"`).
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final fg = background != null ? Colors.white : color;
    final tile = ListTile(
      leading: Icon(icon, color: background != null ? Colors.white : (iconColor ?? color ?? AppColors.medium)),
      title: Text(title, style: TextStyle(color: fg)),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: TextStyle(
                fontSize: 13,
                color: background != null ? Colors.white70 : AppColors.medium,
              ),
            )
          : null,
      trailing: (trailing != null || (detail && onTap != null))
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (trailing != null) trailing!,
                if (detail && onTap != null) ...[
                  if (trailing != null) const SizedBox(width: 4),
                  Icon(Icons.chevron_right, color: fg ?? AppColors.medium),
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

/// Ionic `ion-badge` used as count in settings items.
class SettingsCountBadge extends StatelessWidget {
  const SettingsCountBadge(this.count, {super.key, this.color = AppColors.medium});

  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$count',
        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}
