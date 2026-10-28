import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/enums.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/event_list_utils.dart';
import '../../../l10n/l10n.dart';
import '../adaptive/adaptive.dart'; // IOS_LOOK
import '../layout/ion_modal_handle.dart'; // IOS_SHEETS
import '../layout/ionic_ios.dart'; // IOS_SHEETS

/// Card layout building blocks of the Terminlisten (Ionic `ev-*` classes):
/// date tile, pills, chips, section and month headers, the "Heute" card and
/// inset list cards.

/// IOS_ATT_PAGES: page background of the Termin pages (Meine Termine,
/// Übersicht, Termine). Ionic iOS renders their `ion-content` white (black in
/// dark mode) – not the grouped grey – so the `ev-list` rows sit directly on
/// the page ([EventListCard.iosPlain]). Material keeps the theme default.
/// IOS_THEME2: dark mode = the black page (cards stay #1c1c1d).
/// IOS_R4: explicit black – the scaffold default is the grouped #222428.
Color? eventPageBackground(BuildContext context) {
  if (!useIosLook(context)) return null;
  final theme = Theme.of(context);
  return theme.brightness == Brightness.dark
      ? AppColors.iosPlainPageDark
      : theme.colorScheme.surface;
}

/// Date tile with weekday and day ("DI" / "20") – Ionic `.ev-tile`:
/// 46x50, radius 12, primary 13 % background with primary-shade text;
/// highlighted types are solid primary, past Termine are faded (0.7).
class EventDateTile extends StatelessWidget {
  const EventDateTile({
    super.key,
    required this.date,
    this.highlight = false,
    this.past = false,
    this.today = false,
    this.size = 46,
    this.background,
    this.foreground,
  });

  final String? date;
  final bool highlight;
  final bool past;

  /// `.ev-today .ev-tile`: 54 × 58, radius 14, solid primary.
  final bool today;

  /// Tile width; the height is `size + 4` (Ionic 46x50, today card 54x58).
  final double size;

  /// UX_ATT: overrides for the today card (`.ev-today .ev-tile`).
  final Color? background;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;
    if (highlight || today) {
      bg = AppColors.primary;
      fg = Colors.white;
    } else {
      bg = AppColors.primary.withValues(alpha: 0.13);
      fg = AppColors.primaryDark;
    }
    final width = today ? 54.0 : size;
    final large = width > 50;
    final tile = Container(
      width: width,
      height: width + 4,
      decoration: BoxDecoration(
        color: background ?? bg,
        borderRadius: BorderRadius.circular(large ? 14 : 12),
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
              color: foreground ?? fg,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            EventListUtils.day(date),
            style: TextStyle(
              fontSize: large ? 24 : 20,
              height: 1.15,
              color: foreground ?? fg,
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

  // UX_ATT: Ionic `.ev-pill`: 4/10 padding, 0.8rem bold tabular figures,
  // 20 % tint of the color and the normal text color.
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        // IOS_THEME2: Ionic dark palette (brighter) in dark mode
        color: AppColors.adaptive(context, color).withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 1,
        softWrap: false,
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
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = danger
        ? AppColors.adaptive(context, AppColors.danger).withValues(alpha: 0.15)
        : AppColors.primary.withValues(alpha: 0.13);
    // IOS_THEME2: Ionic dark danger-shade #e04055 (primary-shade unchanged)
    final fg = danger
        ? (dark ? const Color(0xFFE04055) : AppColors.dangerDark)
        : AppColors.primaryDark;
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

/// Section header ("Anstehend 12") – Ionic `.ev-section`.
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
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 8)],
          Flexible(
            child: Text(
              title,
              style: const TextStyle(fontSize: 21.6, fontWeight: FontWeight.w700),
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

/// Month header ("OKTOBER 2026") or label like "Heute" – Ionic `.ev-month`.
class EventMonthHeader extends StatelessWidget {
  const EventMonthHeader({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
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

/// Inset rounded card holding Termin rows (Ionic iOS `ion-list inset ev-list`:
/// 16 px side margin, 10 px radius, inset lines starting at the label).
/// No line is drawn next to [EventSummaryRow] / [EventMoreLink] (plain divs
/// in Ionic, and the last item of an inset list has no line).
class EventListCard extends StatelessWidget {
  const EventListCard({
    super.key,
    required this.children,
    this.dividers = true,
    this.iosPlain = false,
  });

  final List<Widget> children;

  /// false for Ionic `ion-item lines="none"` (parents upcoming cards).
  final bool dividers;

  /// IOS_ATT_PAGES: on the white Termin pages (Meine Termine, Übersicht,
  /// Termine) Ionic iOS renders `ion-list inset ev-list` without a card:
  /// transparent list (ionic-theme-ios26 structured list), 20 px side
  /// margin, white items on the white page, inset lines starting at the
  /// label. Only with the iOS look; Material keeps the card.
  final bool iosPlain;

  static bool _isPlain(Widget w) => w is EventSummaryRow || w is EventMoreLink;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0 && dividers && !_isPlain(children[i]) && !_isPlain(children[i - 1])) {
        rows.add(const Divider(height: 0.5, thickness: 0.5, indent: 74));
      }
      rows.add(children[i]);
    }
    if (iosPlain && useIosLook(context)) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
        child: Column(mainAxisSize: MainAxisSize.min, children: rows),
      );
    }
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Column(mainAxisSize: MainAxisSize.min, children: rows),
    );
  }
}

/// One Termin row inside an [EventListCard] (Ionic `ion-item` with the
/// `ev-tile` in the start slot: min height 64, 16 px start padding).
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
    this.titleLeading,
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

  /// UX_ATT: inline icon before the title (Ionic duty headset icon).
  final Widget? titleLeading;

  @override
  Widget build(BuildContext context) {
    final content = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 64),
      child: Padding(
        padding: const EdgeInsets.only(left: 16, right: 16),
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: EventDateTile(date: date, highlight: highlight, past: past),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        if (titleLeading != null) ...[titleLeading!, const SizedBox(width: 4)],
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
                          style: const TextStyle(color: AppColors.medium, fontSize: 14),
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
                      color: AppColors.adaptive(
                          context, EventListUtils.statusColor(s)),
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

/// "Alle 12 anzeigen" / "Weniger anzeigen" toggle – Ionic `.ev-more-link`:
/// full-width plain button, 14 px padding, semibold primary text.
class EventMoreLink extends StatelessWidget {
  const EventMoreLink({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }
}

/// Legend sheet of the status pills (Ionic signout legend).
Future<void> showEventLegendSheet(BuildContext context) {
  // Ionic legend modal (breakpoints [0, 0.5, 1], initial 0.5): light
  // content, inset list with list header and an item group of
  // `ev-pill` (slot start) + label rows (lines="none").
  final ios = useIosLook(context);
  final l10n = context.l10n;
  final entries = <(String, Color, String)>[
    (l10n.signoutLegendAccepted, AppColors.success, l10n.signoutLegendAcceptedPresent),
    (l10n.commonStatusExcused, AppColors.warning, l10n.commonStatusExcused),
    (l10n.commonStatusAbsent, AppColors.danger, l10n.commonStatusAbsent),
    (l10n.signoutLegendLate, AppColors.tertiary, l10n.commonStatusLate),
    (l10n.signoutLegendLateReported, EventListUtils.rosa, l10n.signoutLegendLateReportedExcused),
    (l10n.commonStatusNeutral, AppColors.medium, l10n.commonStatusNeutral),
  ];

  if (ios) {
    // IOS_SHEETS: Ionic iOS sheet – grabber, sheet `100% - 10px` below the
    // safe area at breakpoint 0.5, list header + rounded item group with
    // 52pt rows (pill, 16pt gap, 17pt label).
    final available =
        MediaQuery.sizeOf(context).height - MediaQuery.paddingOf(context).top;
    final full = available > 100 ? (available - 10) / available : 1.0;
    return showModalBottomSheet(
      context: context,
      useRootNavigator: true, // IOS_SHELL2: above the tab bar
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: false,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder: (ctx) => FractionallySizedBox(
        heightFactor: 0.5 * full,
        child: IonModalHandleOverlay(
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              top: 16,
              bottom: 16 + MediaQuery.paddingOf(ctx).bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                IonListHeader(ctx.l10n.signoutLegend),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: Theme.of(ctx).colorScheme.surface,
                    borderRadius: BorderRadius.circular(IonIos.groupRadius),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final e in entries)
                        IonItem(
                          leading: EventPill(label: e.$1, color: e.$2),
                          title: Text(e.$3),
                        ),
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
    useRootNavigator: true, // IOS_SHELL2: above the tab bar
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
                    for (final e in entries) row(e.$1, e.$2, e.$3),
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
  final apple = await showAppActionSheet<bool>(
    context,
    actions: [
      AppActionSheetAction(value: true, label: context.l10n.commonAppleMaps),
      const AppActionSheetAction(value: false, label: 'Google Maps'),
    ],
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

/// UX_ATT: "Durchschnitt" row at the top of the past list (Ionic att-list
/// `.ev-summary` with `.ev-summary__label` and an `.ev-pill`).
class EventSummaryRow extends StatelessWidget {
  const EventSummaryRow({super.key, required this.label, required this.pill});

  final String label;
  final Widget pill;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(fontSize: 14, color: AppColors.medium)),
          ),
          const SizedBox(width: 12),
          pill,
        ],
      ),
    );
  }
}

/// UX_ATT: one stat bubble of [EventTodayFilledCard] (`.ev-today__stats span`).
class EventTodayStat {
  const EventTodayStat(this.text, {this.strong = false});

  final String text;

  /// `.ev-today__stat-strong`: bold on a stronger white tint.
  final bool strong;
}

/// UX_ATT: call to action of [EventTodayFilledCard] (`.ev-today__cta`).
class EventTodayCta {
  const EventTodayCta({
    required this.label,
    required this.icon,
    required this.onTap,
    this.secondary = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  /// `.ev-today__cta--secondary`: white tint with white text.
  final bool secondary;
}

/// UX_ATT: filled "Heute" / "Nächster Termin" card of the Termine tab
/// (Ionic att-list `.ev-today.ev-today--filled`): primary background, white
/// text, translucent date tile, stat bubbles and two equal-width buttons.
class EventTodayFilledCard extends StatelessWidget {
  const EventTodayFilledCard({
    super.key,
    required this.date,
    required this.title,
    this.meta,
    this.place,
    this.stats = const [],
    this.ctas = const [],
    this.onTap,
  });

  final String? date;
  final String title;
  final String? meta;
  final String? place;
  final List<EventTodayStat> stats;
  final List<EventTodayCta> ctas;
  final VoidCallback? onTap;

  static const _white18 = Color(0x2EFFFFFF);
  static const _white30 = Color(0x4DFFFFFF);

  @override
  Widget build(BuildContext context) {
    const onPrimary = Colors.white;
    final dimmed = onPrimary.withValues(alpha: 0.9);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Material(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: DefaultTextStyle.merge(
              style: const TextStyle(color: onPrimary),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      EventDateTile(
                        date: date,
                        size: 54,
                        background: _white18,
                        foreground: onPrimary,
                      ),
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
                                color: onPrimary,
                              ),
                            ),
                            if (meta != null && meta!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(meta!, style: TextStyle(fontSize: 14, color: dimmed)),
                              ),
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
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Icon(Icons.location_on_outlined, size: 16, color: dimmed),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(place!, style: TextStyle(fontSize: 14, color: dimmed)),
                          ),
                        ],
                      ),
                    ),
                  if (stats.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final stat in stats)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: stat.strong ? _white30 : _white18,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                stat.text,
                                style: TextStyle(
                                  fontSize: 12.8,
                                  color: onPrimary,
                                  fontWeight: stat.strong ? FontWeight.w700 : FontWeight.w400,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  if (ctas.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: Row(
                        children: [
                          for (var i = 0; i < ctas.length; i++) ...[
                            if (i > 0) const SizedBox(width: 8),
                            Expanded(child: _EventTodayCtaButton(cta: ctas[i])),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EventTodayCtaButton extends StatelessWidget {
  const _EventTodayCtaButton({required this.cta});

  final EventTodayCta cta;

  @override
  Widget build(BuildContext context) {
    final fg = cta.secondary ? Colors.white : AppColors.primaryDark;
    return Material(
      color: cta.secondary ? EventTodayFilledCard._white18 : Colors.white,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: cta.onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(cta.icon, size: 18, color: fg),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  cta.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 15.2, fontWeight: FontWeight.w600, color: fg),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
