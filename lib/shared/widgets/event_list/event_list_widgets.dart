import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/enums.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/event_list_utils.dart';
import '../../../l10n/l10n.dart';

/// Card layout building blocks of the Terminlisten (Ionic `ev-*` classes):
/// date tile, pills, chips, section and month headers, the "Heute" card and
/// inset list cards.

/// Date tile with weekday and day ("Di" / "20").
class EventDateTile extends StatelessWidget {
  const EventDateTile({
    super.key,
    required this.date,
    this.highlight = false,
    this.past = false,
    this.size = 44,
  });

  final String? date;
  final bool highlight;
  final bool past;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final Color bg;
    final Color fg;
    if (highlight) {
      bg = AppColors.warning.withValues(alpha: 0.2);
      fg = AppColors.warningDark;
    } else if (past) {
      bg = scheme.surfaceContainerHighest.withValues(alpha: 0.6);
      fg = AppColors.medium;
    } else {
      bg = AppColors.primary.withValues(alpha: 0.12);
      fg = AppColors.primary;
    }
    return Container(
      width: size,
      height: size + 4,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            EventListUtils.weekday(date),
            style: TextStyle(fontSize: 11, color: fg, fontWeight: FontWeight.w500),
          ),
          Text(
            EventListUtils.day(date),
            style: TextStyle(
              fontSize: 18,
              height: 1.1,
              color: fg,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

/// Colored status pill ("Zugesagt", "Entschuldigt", ...).
class EventPill extends StatelessWidget {
  const EventPill({super.key, required this.label, required this.color});

  /// Pill for an attendance status.
  factory EventPill.status(AttendanceStatus status, {bool past = false, Key? key}) {
    return EventPill(
      key: key,
      label: EventListUtils.statusLabel(status, past: past),
      color: EventListUtils.statusColor(status),
    );
  }

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color == AppColors.warning ? AppColors.warningDark : color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Small chip below a Termin (Notiz, Ablaufplan, Infos, Route, ...).
/// Chips with [onTap] are directly tappable and do not open the row's menu.
class EventChip extends StatelessWidget {
  const EventChip({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
    this.danger = false,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.danger : (onTap != null ? AppColors.primary : AppColors.medium);
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: color),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return chip;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: chip,
    );
  }
}

/// Section header ("Anstehend 12").
class EventSectionHeader extends StatelessWidget {
  const EventSectionHeader({
    super.key,
    required this.title,
    this.count,
    this.leading,
    this.trailing,
  });

  final String title;
  final int? count;
  final Widget? leading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 8)],
          Flexible(
            child: Text(
              title,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          if (count != null) ...[
            const SizedBox(width: 8),
            Text(
              '$count',
              style: const TextStyle(color: AppColors.medium, fontSize: 16),
            ),
          ],
          if (trailing != null) ...[const Spacer(), trailing!],
        ],
      ),
    );
  }
}

/// Month header ("Oktober 2026") or label like "Heute".
class EventMonthHeader extends StatelessWidget {
  const EventMonthHeader({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          letterSpacing: 0.6,
          fontWeight: FontWeight.w600,
          color: AppColors.medium,
        ),
      ),
    );
  }
}

/// Inset rounded card holding Termin rows (Ionic `ion-list inset ev-list`).
class EventListCard extends StatelessWidget {
  const EventListCard({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) rows.add(const Divider(height: 1, indent: 72));
      rows.add(children[i]);
    }
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Column(mainAxisSize: MainAxisSize.min, children: rows),
    );
  }
}

/// One Termin row inside an [EventListCard].
class EventRow extends StatelessWidget {
  const EventRow({
    super.key,
    required this.date,
    required this.title,
    this.subtitle,
    this.extra = const [],
    this.trailing = const [],
    this.highlight = false,
    this.past = false,
    this.dimmed = false,
    this.onTap,
    this.titleSuffix,
  });

  final String? date;
  final String title;
  final String? subtitle;
  final List<Widget> extra;
  final List<Widget> trailing;
  final bool highlight;
  final bool past;

  /// Termin the person is not part of (show_all_attendances)
  final bool dimmed;
  final VoidCallback? onTap;
  final Widget? titleSuffix;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EventDateTile(date: date, highlight: highlight, past: past),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                      ),
                    ),
                    if (titleSuffix != null) ...[const SizedBox(width: 6), titleSuffix!],
                  ],
                ),
                if (subtitle != null && subtitle!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      subtitle!,
                      style: const TextStyle(color: AppColors.medium, fontSize: 13),
                    ),
                  ),
                ...extra,
              ],
            ),
          ),
          if (trailing.isNotEmpty) ...[
            const SizedBox(width: 8),
            Row(mainAxisSize: MainAxisSize.min, children: trailing),
          ],
        ],
      ),
    );
    final child = Opacity(opacity: dimmed ? 0.6 : 1, child: content);
    if (onTap == null) return child;
    return InkWell(onTap: onTap, child: child);
  }
}

/// Chips row below a Termin.
class EventChips extends StatelessWidget {
  const EventChips({super.key, required this.chips});

  final List<Widget> chips;

  @override
  Widget build(BuildContext context) {
    if (chips.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Wrap(spacing: 6, runSpacing: 6, children: chips),
    );
  }
}

/// Full-width "Heute" / "Nächster Termin" card with direct actions.
class EventTodayCard extends StatelessWidget {
  const EventTodayCard({
    super.key,
    required this.date,
    required this.title,
    this.meta,
    this.status,
    this.place,
    this.infoText,
    this.chips = const [],
    this.actions = const [],
    this.moreLabel,
    this.onMore,
    this.dimmed = false,
    this.extraHeader = const [],
  });

  final String? date;
  final String title;
  final String? meta;
  final Widget? status;
  final String? place;
  final String? infoText;
  final List<Widget> chips;
  final List<Widget> actions;
  final String? moreLabel;
  final VoidCallback? onMore;
  final bool dimmed;
  final List<Widget> extraHeader;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: dimmed ? 0.7 : 1,
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  EventDateTile(date: date, size: 52),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        if (meta != null && meta!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(meta!, style: const TextStyle(color: AppColors.medium)),
                          ),
                        ...extraHeader,
                        if (status != null)
                          Padding(padding: const EdgeInsets.only(top: 6), child: status!),
                      ],
                    ),
                  ),
                ],
              ),
              if (place != null && place!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.location_on_outlined, size: 18, color: AppColors.medium),
                      const SizedBox(width: 6),
                      Expanded(child: Text(place!)),
                    ],
                  ),
                ),
              if (infoText != null && infoText!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    infoText!,
                    style: const TextStyle(fontStyle: FontStyle.italic, color: AppColors.medium),
                  ),
                ),
              EventChips(chips: chips),
              if (actions.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Row(
                    children: [
                      for (var i = 0; i < actions.length; i++) ...[
                        if (i > 0) const SizedBox(width: 8),
                        Expanded(child: actions[i]),
                      ],
                    ],
                  ),
                ),
              if (onMore != null)
                Align(
                  alignment: Alignment.center,
                  child: TextButton(onPressed: onMore, child: Text(moreLabel ?? context.l10n.signoutMoreOptions)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Toggle button of the "Heute" card (Zusagen / Verspätung / Absagen).
class EventActionButton extends StatelessWidget {
  const EventActionButton({
    super.key,
    required this.label,
    required this.active,
    required this.activeColor,
    this.onPressed,
  });

  final String label;
  final bool active;
  final Color activeColor;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final style = ButtonStyle(
      padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 4, vertical: 10)),
      visualDensity: VisualDensity.compact,
    );
    final text = FittedBox(fit: BoxFit.scaleDown, child: Text(label, maxLines: 1));
    if (active) {
      return FilledButton(
        style: style.copyWith(
          backgroundColor: WidgetStatePropertyAll(activeColor),
          foregroundColor: WidgetStatePropertyAll(
            activeColor == AppColors.warning ? Colors.black87 : Colors.white,
          ),
        ),
        onPressed: onPressed ?? () {},
        child: text,
      );
    }
    return OutlinedButton(style: style, onPressed: onPressed, child: text);
  }
}

/// Percentage summary with late count and dots of the last Termine.
class EventSummary extends StatelessWidget {
  const EventSummary({
    super.key,
    required this.percentage,
    this.lateCount = 0,
    this.dots = const [],
  });

  final int percentage;
  final int lateCount;
  final List<AttendanceStatus> dots;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$percentage%',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: EventListUtils.percentageColor(percentage),
                ),
              ),
              const SizedBox(width: 6),
              Text(context.l10n.signoutAttendance, style: const TextStyle(color: AppColors.medium)),
              if (lateCount > 0) ...[
                const Spacer(),
                Text(context.l10n.signoutLateCount(lateCount), style: const TextStyle(color: AppColors.medium)),
              ],
            ],
          ),
          if (dots.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(
                spacing: 4,
                children: [
                  for (final s in dots)
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: EventListUtils.statusColor(s),
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// "Alle 12 anzeigen" / "Weniger anzeigen" toggle.
class EventMoreLink extends StatelessWidget {
  const EventMoreLink({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Center(child: TextButton(onPressed: onTap, child: Text(label)));
  }
}

/// Legend sheet of the status pills (Ionic signout legend).
Future<void> showEventLegendSheet(BuildContext context) {
  Widget row(String pill, Color color, String text) => ListTile(
        dense: true,
        leading: SizedBox(width: 150, child: Align(alignment: Alignment.centerLeft, child: EventPill(label: pill, color: color))),
        title: Text(text),
      );
  return showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(title: Text(ctx.l10n.signoutLegend, style: const TextStyle(fontWeight: FontWeight.bold))),
            row(ctx.l10n.signoutLegendAccepted, AppColors.success, ctx.l10n.signoutLegendAcceptedPresent),
            row(ctx.l10n.commonStatusExcused, AppColors.warning, ctx.l10n.commonStatusExcused),
            row(ctx.l10n.commonStatusAbsent, AppColors.danger, ctx.l10n.commonStatusAbsent),
            row(ctx.l10n.signoutLegendLate, AppColors.tertiary, ctx.l10n.commonStatusLate),
            row(ctx.l10n.signoutLegendLateReported, EventListUtils.rosa, ctx.l10n.signoutLegendLateReportedExcused),
            row(ctx.l10n.commonStatusNeutral, AppColors.medium, ctx.l10n.commonStatusNeutral),
            const SizedBox(height: 12),
          ],
        ),
      ),
    ),
  );
}

/// Opens Google Maps (or Apple Karten on iOS after a choice) for a place.
Future<void> openEventNavigation(BuildContext context, String place) async {
  Future<void> open(Uri uri) async {
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (kDebugMode) debugPrint('openEventNavigation failed: $e');
    }
  }

  // Also true for iOS browsers (PWA)
  final isIos = defaultTargetPlatform == TargetPlatform.iOS;
  if (!isIos) {
    await open(EventListUtils.navigationUrl(place));
    return;
  }
  final apple = await showModalBottomSheet<bool>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(title: Text(ctx.l10n.commonAppleMaps), onTap: () => Navigator.pop(ctx, true)),
          ListTile(title: const Text('Google Maps'), onTap: () => Navigator.pop(ctx, false)),
          ListTile(title: Text(ctx.l10n.commonCancel), onTap: () => Navigator.pop(ctx)),
        ],
      ),
    ),
  );
  if (apple == null) return;
  await open(EventListUtils.navigationUrl(place, apple: apple));
}

/// Opens an attachment URL in the browser.
Future<void> openEventAttachment(String url) async {
  try {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  } catch (e) {
    if (kDebugMode) debugPrint('openEventAttachment failed: $e');
  }
}
