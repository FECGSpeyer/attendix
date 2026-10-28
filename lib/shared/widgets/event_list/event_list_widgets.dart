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

/// Date tile with weekday and day ("Di" / "20"), Ionic `.ev-tile`:
/// 46 × 50, radius 12, primary tint (highlight: solid primary, past: 70 %
/// opacity). [today] is the bigger solid tile of the "Heute" card.
class EventDateTile extends StatelessWidget {
  const EventDateTile({
    super.key,
    required this.date,
    this.highlight = false,
    this.past = false,
    this.today = false,
    this.size = 46,
  });

  final String? date;
  final bool highlight;
  final bool past;

  /// `.ev-today .ev-tile`: 54 × 58, radius 14, solid primary.
  final bool today;
  final double size;

  @override
  Widget build(BuildContext context) {
    final solid = highlight || today;
    final bg = solid ? AppColors.primary : AppColors.primary.withValues(alpha: 0.13);
    final fg = solid ? Colors.white : AppColors.primaryDark;
    final width = today ? 54.0 : size;
    final height = today ? 58.0 : size + 4;
    final tile = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(today ? 14 : 12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            EventListUtils.weekday(date).toUpperCase(),
            style: TextStyle(
              fontSize: 10.9,
              height: 1,
              letterSpacing: 0.65,
              color: fg,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            EventListUtils.day(date),
            style: TextStyle(
              fontSize: today ? 24 : 20,
              height: 1.15,
              color: fg,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
    return past ? Opacity(opacity: 0.7, child: tile) : tile;
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

  /// Ionic `.ev-pill.ion-color-*`: base color at 20 % with the text color.
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 1,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontSize: 12.8,
          fontWeight: FontWeight.w700,
          fontFeatures: const [FontFeature.tabularFigures()],
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

  /// Ionic `.ev-chip`: primary tint (danger tint for the deadline),
  /// radius 6, 12px medium weight.
  @override
  Widget build(BuildContext context) {
    final bg = danger
        ? AppColors.danger.withValues(alpha: 0.15)
        : AppColors.primary.withValues(alpha: 0.13);
    final fg = danger ? AppColors.dangerDark : AppColors.primaryDark;
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: fg),
            const SizedBox(width: 3),
          ],
          Flexible(
            child: Text(
              label,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: fg),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return chip;
    return InkWell(
      borderRadius: BorderRadius.circular(6),
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
    // Ionic `.ev-section`: padding 22 20 0, h2 1.35rem bold, count medium.
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 8)],
          Flexible(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 21.6,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          if (count != null) ...[
            const SizedBox(width: 8),
            Text(
              '$count',
              style: const TextStyle(color: AppColors.medium, fontSize: 15.2),
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
    // Ionic `.ev-month`: padding 14 20 0, 0.8rem semibold uppercase.
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontSize: 12.8,
          letterSpacing: 0.64,
          fontWeight: FontWeight.w600,
          color: AppColors.medium,
        ),
      ),
    );
  }
}

/// Inset rounded card holding Termin rows (Ionic `ion-list inset ev-list`).
class EventListCard extends StatelessWidget {
  const EventListCard({super.key, required this.children, this.dividers = true});

  final List<Widget> children;

  /// false for Ionic `ion-item lines="none"` (parents upcoming cards).
  final bool dividers;

  @override
  Widget build(BuildContext context) {
    // Ionic `ion-list inset ev-list`: margin 6 16 0, inset lines starting
    // at the label (16 + 46 tile + 12).
    final ios = Theme.of(context).platform == TargetPlatform.iOS;
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0 && dividers) {
        rows.add(const Divider(height: 0.5, thickness: 0.5, indent: 74));
      }
      rows.add(children[i]);
    }
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ios ? 10 : 14)),
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
    // Ionic `ion-item` in `.ev-list`: min height 64, tile margin 7 12 7 0,
    // label h2 1rem semibold, p 14px step-400 grey, end slot centered.
    final dark = Theme.of(context).brightness == Brightness.dark;
    final content = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 64),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 7, 16, 7),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            EventDateTile(date: date, highlight: highlight, past: past),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
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
                          style: TextStyle(
                            color: dark ? const Color(0xFF999999) : const Color(0xFF666666),
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ...extra,
                  ],
                ),
              ),
            ),
            if (trailing.isNotEmpty) ...[
              const SizedBox(width: 8),
              Row(mainAxisSize: MainAxisSize.min, children: trailing),
            ],
          ],
        ),
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
    this.bordered = false,
    this.rows = const [],
    this.footer = const [],
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

  /// Ionic `.ev-today` (signout / overview / parents): 2px primary border.
  final bool bordered;

  /// Ionic `.ev-today__rows`: rows separated by hairlines below the head
  /// (parents: one row per child).
  final List<Widget> rows;

  /// Widgets at the end of the card (parents: "Alle Kinder an-/abmelden").
  final List<Widget> footer;

  @override
  Widget build(BuildContext context) {
    final hairline = BorderSide(
      color: Theme.of(context).dividerColor,
      width: 0.5,
    );
    return Opacity(
      opacity: dimmed ? 0.7 : 1,
      child: Card(
        // Ionic `.ev-today`: margin 8 16 0, padding 16, radius 18.
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: bordered
              ? const BorderSide(color: AppColors.primary, width: 2)
              : BorderSide.none,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  EventDateTile(date: date, today: true),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 18.4,
                            height: 1.25,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (meta != null && meta!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              meta!,
                              style: const TextStyle(color: AppColors.medium, fontSize: 14),
                            ),
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
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Icon(Icons.location_on_outlined, size: 16, color: AppColors.medium),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          place!,
                          style: const TextStyle(color: AppColors.medium, fontSize: 14),
                        ),
                      ),
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
              if (rows.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  decoration: BoxDecoration(border: Border(top: hairline)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < rows.length; i++)
                        Container(
                          decoration: i == rows.length - 1
                              ? null
                              : BoxDecoration(border: Border(bottom: hairline)),
                          child: rows[i],
                        ),
                    ],
                  ),
                ),
              if (actions.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 14),
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
                // Ionic `.ev-today .ev-more-link`: padding 10 0 0, semibold.
                TextButton(
                  onPressed: onMore,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.only(top: 10, bottom: 0),
                    minimumSize: const Size.fromHeight(34),
                    textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                  ),
                  child: Text(moreLabel ?? context.l10n.signoutMoreOptions),
                ),
              ...footer,
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
    // Ionic `.ev-today__actions ion-button`: radius 12, min height 44,
    // padding 4, no uppercase; outline in primary.
    final style = ButtonStyle(
      padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 4, vertical: 10)),
      minimumSize: const WidgetStatePropertyAll(Size(0, 44)),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      textStyle: const WidgetStatePropertyAll(
        TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
      ),
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

  /// Ionic `.ev-summary` (+ `.ev-dots`): "87 % Anwesenheit" in the text
  /// color, late count on the right, 14px rounded squares per Termin.
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$percentage%',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 6),
              Text(
                context.l10n.signoutAttendance,
                style: const TextStyle(color: AppColors.medium, fontSize: 14),
              ),
              if (lateCount > 0) ...[
                const Spacer(),
                Text(
                  context.l10n.signoutLateCount(lateCount),
                  style: const TextStyle(color: AppColors.medium, fontSize: 14),
                ),
              ],
            ],
          ),
        ),
        if (dots.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                for (final s in dots)
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: EventListUtils.statusColor(s),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
              ],
            ),
          ),
      ],
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
    // Ionic `.ev-more-link`: full width, padding 14, semibold primary.
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.all(14),
        minimumSize: const Size.fromHeight(48),
        shape: const RoundedRectangleBorder(),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
      ),
      child: Text(label),
    );
  }
}

/// Legend sheet of the status pills (Ionic signout legend).
Future<void> showEventLegendSheet(BuildContext context) {
  // Ionic legend modal: light content, inset list with list header and
  // `ev-pill` (slot start) + label rows.
  Widget row(String pill, Color color, String text) => ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              EventPill(label: pill, color: color),
              const SizedBox(width: 16),
              Expanded(child: Text(text, style: const TextStyle(fontSize: 16))),
            ],
          ),
        ),
      );
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    builder: (ctx) => FractionallySizedBox(
      heightFactor: 0.5,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                child: Text(
                  ctx.l10n.signoutLegend,
                  style: const TextStyle(
                    fontSize: 14.4,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF9D9FA6),
                  ),
                ),
              ),
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    row(ctx.l10n.signoutLegendAccepted, AppColors.success, ctx.l10n.signoutLegendAcceptedPresent),
                    row(ctx.l10n.commonStatusExcused, AppColors.warning, ctx.l10n.commonStatusExcused),
                    row(ctx.l10n.commonStatusAbsent, AppColors.danger, ctx.l10n.commonStatusAbsent),
                    row(ctx.l10n.signoutLegendLate, AppColors.tertiary, ctx.l10n.commonStatusLate),
                    row(ctx.l10n.signoutLegendLateReported, EventListUtils.rosa, ctx.l10n.signoutLegendLateReportedExcused),
                    row(ctx.l10n.commonStatusNeutral, AppColors.medium, ctx.l10n.commonStatusNeutral),
                  ],
                ),
              ),
            ],
          ),
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
