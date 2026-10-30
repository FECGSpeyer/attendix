import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';

/// Colour family of a dashboard tile / chip / header strip
/// (Ionic global.scss `.tile-*` and `.strip-*`, "Kachel" design).
enum DashTone {
  pink(Color(0xFFE91E8C), Color(0xFFC2185B), Color(0xFFF48FB1), 0.10, 0.22),
  blue(Color(0xFF3A6BFF), Color(0xFF1A3FC7), Color(0xFF8FA8FF), 0.11, 0.24),
  teal(Color(0xFF00838F), Color(0xFF006064), Color(0xFF4DD0E1), 0.11, 0.26),
  green(Color(0xFF43A047), Color(0xFF2E7D32), Color(0xFF81C784), 0.13, 0.24),
  red(Color(0xFFE53935), Color(0xFFC62828), Color(0xFFEF9A9A), 0.11, 0.24),
  orange(Color(0xFFF57C00), Color(0xFFE65100), Color(0xFFFFB74D), 0.12, 0.24),
  purple(Color(0xFF8E24AA), Color(0xFF6A1B9A), Color(0xFFCE93D8), 0.11, 0.28),
  muted(Color(0xFF8E8E93), Color(0xFF8E8E93), Color(0xFF8E8E93), 0.14, 0.22);

  const DashTone(this.from, this.to, this.darkFg, this.bgAlpha, this.darkBgAlpha);

  final Color from;
  final Color to;
  final Color darkFg;
  final double bgAlpha;
  final double darkBgAlpha;

  bool _dark(BuildContext context) => Theme.of(context).brightness == Brightness.dark;

  /// Foreground (text/icon) colour on the tinted background.
  Color fg(BuildContext context) {
    if (this == DashTone.muted) return AppColors.medium;
    return _dark(context) ? darkFg : to;
  }

  /// Tinted background.
  Color bg(BuildContext context) =>
      from.withAlpha(((_dark(context) ? darkBgAlpha : bgAlpha) * 255).round());

  LinearGradient get gradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [from, to],
      );
}

/// Header-strip gradients of the cards (Ionic `.strip-*`).
abstract class DashStrips {
  static const birthday = [Color(0xFFE91E8C), Color(0xFFC2185B)];
  static const event = [Color(0xFF3A6BFF), Color(0xFF1A3FC7)];
  static const members = [Color(0xFF00897B), Color(0xFF00695C)];
  static const absences = [Color(0xFFF57C00), Color(0xFFE65100)];
  static const critical = [Color(0xFFD32F2F), Color(0xFFB71C1C)];
  static const songs = [Color(0xFF7B1FA2), Color(0xFF4A148C)];
  static const plan = [Color(0xFF00838F), Color(0xFF006064)];
}

/// Rounded dashboard card with a coloured header strip (Ionic `.dashboard-card`).
class DashboardCard extends StatelessWidget {
  const DashboardCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.strip,
    required this.child,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> strip;
  final Widget child;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      elevation: 3,
      shadowColor: Colors.black26,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: strip,
                ),
              ),
              child: Row(
                children: [
                  Icon(icon, size: 28, color: Colors.white.withAlpha((0.92 * 255).round())),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withAlpha((0.82 * 255).round()),
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (trailing != null) trailing!,
                ],
              ),
            ),
            child,
          ],
        ),
      ),
    );
  }
}

/// Loading spinner inside a card body.
class DashLoading extends StatelessWidget {
  const DashLoading({super.key});

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.all(20),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: AppSpinner(strokeWidth: 2.5),
          ),
        ),
      );
}

/// Empty / error row inside a card body (Ionic `.empty-row`).
class DashEmptyRow extends StatelessWidget {
  const DashEmptyRow({
    super.key,
    required this.icon,
    required this.text,
    this.iconColor,
  });

  final IconData icon;
  final String text;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, size: 20, color: iconColor ?? AppColors.medium),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(color: AppColors.medium, fontSize: 14.5),
              ),
            ),
          ],
        ),
      );
}

/// Uppercase section divider (Ionic `ion-item-divider` in `.card-list`).
class DashDivider extends StatelessWidget {
  const DashDivider(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      constraints: const BoxConstraints(minHeight: 28),
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: dark ? Colors.white10 : const Color(0xFFE8E8E8),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
          color: AppColors.medium,
        ),
      ),
    );
  }
}

/// Calendar sheet / icon tile (Ionic `.date-tile` / `.icon-tile`).
class DashTile extends StatelessWidget {
  const DashTile({
    super.key,
    required this.tone,
    this.main,
    this.sub,
    this.icon,
    this.solid = false,
    this.smallMain = false,
  });

  /// Date tile: day number + short month.
  factory DashTile.date(DateTime date, {required DashTone tone, bool solid = false}) {
    const months = [
      'Jan', 'Feb', 'März', 'Apr', 'Mai', 'Juni',
      'Juli', 'Aug', 'Sept', 'Okt', 'Nov', 'Dez',
    ];
    // Ionic dashboard-date: dayjs 'MMM' in the UI language without dots.
    final month = currentLanguage() == 'de'
        ? months[date.month - 1]
        : DateFormat('MMM', currentIntlLocale()).format(date).replaceAll('.', '');
    return DashTile(
      tone: tone,
      main: '${date.day}',
      sub: month,
      solid: solid,
    );
  }

  final DashTone tone;
  final String? main;
  final String? sub;
  final IconData? icon;
  final bool solid;
  final bool smallMain;

  @override
  Widget build(BuildContext context) {
    final fg = solid ? Colors.white : tone.fg(context);
    return Container(
      width: 42,
      height: 44,
      decoration: BoxDecoration(
        color: solid ? null : tone.bg(context),
        gradient: solid ? tone.gradient : null,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) Icon(icon, size: 20, color: fg),
          if (main != null)
            Text(
              main!,
              maxLines: 1,
              style: TextStyle(
                color: fg,
                fontSize: smallMain ? 13 : 18,
                fontWeight: FontWeight.w700,
                height: 1,
              ),
            ),
          if (sub != null) ...[
            const SizedBox(height: 3),
            Text(
              sub!.toUpperCase(),
              style: TextStyle(
                color: fg,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.6,
                height: 1,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Tinted status pill (Ionic `.soft-chip`).
class DashChip extends StatelessWidget {
  const DashChip({
    super.key,
    required this.label,
    required this.tone,
    this.icon,
    this.solid = false,
  });

  final String label;
  final DashTone tone;
  final IconData? icon;
  final bool solid;

  @override
  Widget build(BuildContext context) {
    final fg = solid ? Colors.white : tone.fg(context);
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: solid ? null : tone.bg(context),
        gradient: solid ? tone.gradient : null,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

/// Subtle right-hand meta text (Ionic `.row-meta`).
class DashMeta extends StatelessWidget {
  const DashMeta(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 8),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.medium,
          ),
        ),
      );
}

/// Row of a dashboard card list (Ionic `ion-item.dash-row`).
class DashRow extends StatelessWidget {
  const DashRow({
    super.key,
    required this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.highlight,
    this.dim = false,
    this.showDivider = true,
  });

  final Widget leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  /// Background tint for highlighted rows (e.g. birthday today).
  final Color? highlight;
  final bool dim;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: highlight ?? Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 60),
          padding: const EdgeInsets.fromLTRB(14, 8, 12, 8),
          decoration: showDivider
              ? BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Theme.of(context).dividerColor.withAlpha((0.4 * 255).round())),
                  ),
                )
              : null,
          child: Row(
            children: [
              leading,
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                        color: dim ? AppColors.medium : null,
                      ),
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.3,
                          color: AppColors.medium,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ),
      ),
    );
  }
}
