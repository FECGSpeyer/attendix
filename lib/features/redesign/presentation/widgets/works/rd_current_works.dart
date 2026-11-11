import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../../core/router/redesign_routes.dart';
import '../../../../../core/theme/redesign/rd_theme.dart';
import '../../../../../core/utils/toast_helper.dart';
import '../../../../../data/models/instrument/instrument.dart';
import '../../../../../data/models/song/song.dart';
import '../../../../../l10n/l10n.dart';
import '../../../../songs/data/song_print_service.dart';
import '../../../../songs/presentation/utils/song_utils.dart';
import '../../../data/rd_works_logic.dart';
import '../rd_split_view.dart';
import '../rd_widgets.dart';

/// REDESIGN: "Aktuell" of the Werke tab (canvas "Aktuelle Noten im
/// Werke-Tab", variant A): one row of cards with the Werke of the coming
/// Termine ([rdCurrentWorkCards]), for members and leads. A tap opens the
/// Werk page ([rdOpenCurrentWork]), which shows the own part on top;
/// "Alle als PDF" puts all own parts (without a group the scores) into one
/// PDF.
/// On the desktop (list next to the Werk) ‹ › page through the row.
class RdCurrentWorksStrip extends ConsumerStatefulWidget {
  const RdCurrentWorksStrip({super.key, required this.works, required this.ownGroup, required this.choir});

  final List<RdCurrentWork> works;

  /// The viewer's own group (null: none, e.g. the conductor; the cards open
  /// the score then).
  final Group? ownGroup;
  final bool choir;

  @override
  ConsumerState<RdCurrentWorksStrip> createState() => _RdCurrentWorksStripState();
}

class _RdCurrentWorksStripState extends ConsumerState<RdCurrentWorksStrip> {
  final _scroll = ScrollController();

  /// "Alle als PDF" is building its PDF (no second one on a double tap).
  bool _printing = false;

  static const double _cardWidth = 136;
  static const double _gap = 10;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  List<SongPrintEntry> _printable() => [
    for (final w in widget.works)
      for (final f in rdCurrentWorkFiles(w.song, widget.ownGroup?.id, choir: widget.choir))
        if (SongUtils.isPdf(f) || SongUtils.isImage(f)) SongPrintEntry(song: w.song, file: f),
  ];

  Future<void> _openAll(List<SongPrintEntry> entries) async {
    if (_printing) return;
    final l10n = context.l10n;
    setState(() => _printing = true);
    try {
      final date = DateTime.now().toIso8601String().substring(0, 10);
      final name = widget.ownGroup?.name ?? l10n.redesignWorkScore;
      final result = await ref.read(songPrintServiceProvider).printEntries(entries, 'Noten_${name}_$date.pdf');
      if (!mounted || result == null) return;
      if (result.pageCount == 0) {
        ToastHelper.showWarning(context, l10n.svcNoPrintableScores);
      } else if (result.skipped > 0) {
        ToastHelper.showWarning(context, l10n.songsFlutterFilesSkipped(result.skipped));
      }
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  static (int?, DateTime?, String) _eventKey(RdCurrentWork w) => (w.event.attendanceId, w.event.date, w.event.type);

  void _page(int direction) {
    if (!_scroll.hasClients) return;
    final pos = _scroll.position;
    final target = (pos.pixels + direction * (pos.viewportDimension - _cardWidth / 2)).clamp(0.0, pos.maxScrollExtent);
    _scroll.animateTo(target, duration: const Duration(milliseconds: 250), curve: Curves.easeOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final desktop = RdSplitScope.of(context) != null;
    final printable = _printable();
    // All cards for one Termin: it is named once above the row; otherwise
    // the first card of each Termin names it.
    final events = widget.works.map(_eventKey).toSet();
    final single = events.length == 1;
    // Two Termine on one day: the cards name the type too ("So. 29.11. ·
    // Probe"), else the day is enough.
    final days = events.map((e) => e.$2).toList();
    final sameDay = days.toSet().length < days.length;
    // The cards grow with the text size (fixed height for the row).
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    // Padding and gaps stay, the number, three title lines and the hint grow
    // with the text (128 at 100 %).
    final height = 34 + 94 * scale.clamp(1.0, double.infinity);
    final width = _cardWidth * scale.clamp(1.0, 1.4);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(header: true, child: Text(l10n.redesignWorksCurrent, style: RdType.section(p))),
                  if (single)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        l10n.redesignWorksCurrentFor(rdCurrentWorkWhen(widget.works.first)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: RdType.meta(p, size: 13),
                      ),
                    ),
                ],
              ),
            ),
            if (printable.isNotEmpty)
              _printing
                  ? Padding(
                    padding: const EdgeInsets.all(12),
                    child: SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: p.link),
                    ),
                  )
                  : RdTextLink(
                    key: const Key('rd-works-current-pdf'),
                    label: l10n.redesignWorksCurrentAllPdf,
                    onTap: () => _openAll(printable),
                  ),
            if (desktop && widget.works.length > 2) ...[
              IconButton(
                tooltip: l10n.redesignWorksCurrentBack,
                icon: Icon(Icons.chevron_left, color: p.text2),
                onPressed: () => _page(-1),
              ),
              IconButton(
                tooltip: l10n.redesignWorksCurrentForward,
                icon: Icon(Icons.chevron_right, color: p.text2),
                onPressed: () => _page(1),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: height,
          // A mouse may drag the row too (no horizontal wheel on most mice).
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(context).copyWith(
              dragDevices: {
                PointerDeviceKind.touch,
                PointerDeviceKind.mouse,
                PointerDeviceKind.trackpad,
                PointerDeviceKind.stylus,
              },
            ),
            child: ListView.separated(
              key: const Key('rd-works-current'),
              controller: _scroll,
              scrollDirection: Axis.horizontal,
              itemCount: widget.works.length,
              separatorBuilder: (_, _) => const SizedBox(width: _gap),
              itemBuilder:
                  (context, i) => SizedBox(
                    width: width,
                    child: _CurrentCard(
                      work: widget.works[i],
                      ownGroup: widget.ownGroup,
                      choir: widget.choir,
                      shortWhen: !sameDay,
                      showWhen: !single && (i == 0 || _eventKey(widget.works[i]) != _eventKey(widget.works[i - 1])),
                    ),
                  ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Number, title (up to three lines), the Termin when it is not named above
/// the row, and a hint when the own part is missing.
class _CurrentCard extends StatelessWidget {
  const _CurrentCard({
    required this.work,
    required this.ownGroup,
    required this.choir,
    required this.showWhen,
    required this.shortWhen,
  });

  final RdCurrentWork work;
  final Group? ownGroup;
  final bool choir;

  /// First card of its Termin while the row holds several Termine.
  final bool showWhen;

  /// The day alone names the Termin (no second Termin on that day).
  final bool shortWhen;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final song = work.song;
    final number = song.fullNumber;
    final when = rdCurrentWorkWhen(work);
    // Only a missing part is news; "Deine Stimme" / "Partitur" on every
    // card said nothing (the card opens the whole Werk).
    final missing = rdCurrentWorkFiles(song, ownGroup?.id, choir: choir).isEmpty;
    void open() => rdOpenCurrentWork(context, song);
    // One label for the whole card; the tap stays reachable for screen
    // readers (the excluded InkWell no longer offers it).
    return Semantics(
      button: true,
      label: [if (number.isNotEmpty) number, song.name, when, if (missing) l10n.redesignWorksCurrentNoPart].join(', '),
      onTap: open,
      excludeSemantics: true,
      child: RdCard(
        padding: const EdgeInsets.all(12),
        onTap: open,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (number.isNotEmpty || showWhen) ...[
              Row(
                children: [
                  if (number.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(color: p.soft, borderRadius: BorderRadius.circular(8)),
                      child: Text(
                        number,
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: p.softText,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  if (showWhen)
                    Expanded(
                      child: Text(rdCurrentWorkWhen(work, short: shortWhen), maxLines: 1, overflow: TextOverflow.ellipsis, style: RdType.meta(p, size: 12)),
                    ),
                ],
              ),
              const SizedBox(height: 6),
            ],
            Text(
              song.name,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 15, height: 1.25, fontWeight: FontWeight.w600, color: p.text),
            ),
            if (missing) ...[
              const Spacer(),
              Text(
                l10n.redesignWorksCurrentNoPart,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: p.text2),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// "Do. 12.11. · Probe": the Termin a current Werk is planned for; [short]
/// only the day (a card is too narrow for the type).
String rdCurrentWorkWhen(RdCurrentWork work, {bool short = false}) {
  final event = work.event;
  final day = event.date == null ? null : DateFormat('E d.M.', currentIntlLocale()).format(event.date!);
  if (short && day != null) return day;
  return [if (day != null) day, if (event.type.isNotEmpty) event.type].join(' · ');
}

/// What a card of [song] stands for: the Noten of the own part, without a
/// group ([groupId] null, e.g. the conductor) the score.
List<SongFile> rdCurrentWorkFiles(Song song, int? groupId, {required bool choir}) => groupId == null
    ? [if (rdScore(song) case final score?) score]
    : rdMemberPartFiles(song, groupId, choir: choir).where(rdIsNotes).toList();

/// A tap on a current Werk: its Werk page (the own part, without a group
/// the score, is on top there).
void rdOpenCurrentWork(BuildContext context, Song song) {
  if (song.id != null) RdSplitScope.open(context, RedesignRoutes.work(song.id!));
}
