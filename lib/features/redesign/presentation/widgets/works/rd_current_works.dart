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
import '../work/rd_work_file_actions.dart' show rdOpenWorkFile;

/// REDESIGN: "Aktuell" of the Werke tab (canvas "Aktuelle Noten im
/// Werke-Tab", variant A): one row of cards with the Werke a member plays
/// right now ([rdCurrentWorkCards]). A tap opens the own part directly
/// ([rdOpenCurrentWork]); "Alle als PDF" puts every own part into one PDF.
/// On the desktop (list next to the Werk) ‹ › page through the row.
class RdCurrentWorksStrip extends ConsumerStatefulWidget {
  const RdCurrentWorksStrip({super.key, required this.works, required this.ownGroup, required this.choir});

  final List<RdCurrentWork> works;

  /// The member's own group (null: none yet, every card opens the Werk).
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
    if (widget.ownGroup?.id case final groupId?)
      for (final w in widget.works)
        for (final f in rdMemberPartFiles(w.song, groupId, choir: widget.choir))
          if (rdIsNotes(f) && (SongUtils.isPdf(f) || SongUtils.isImage(f))) SongPrintEntry(song: w.song, file: f),
  ];

  Future<void> _openAll(List<SongPrintEntry> entries) async {
    if (_printing) return;
    final l10n = context.l10n;
    setState(() => _printing = true);
    try {
      final date = DateTime.now().toIso8601String().substring(0, 10);
      final name = widget.ownGroup?.name ?? '';
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
    // The cards grow with the text size (fixed height for the row).
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final height = 128 * scale.clamp(1.0, 1.8);
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
                  if (widget.ownGroup != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        l10n.redesignWorksCurrentPart(widget.ownGroup!.name),
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
                    child: _CurrentCard(work: widget.works[i], ownGroup: widget.ownGroup, choir: widget.choir),
                  ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Number, when (Termin or last played), title and whether the own part
/// is there.
class _CurrentCard extends ConsumerWidget {
  const _CurrentCard({required this.work, required this.ownGroup, required this.choir});

  final RdCurrentWork work;
  final Group? ownGroup;
  final bool choir;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.rd;
    final l10n = context.l10n;
    final song = work.song;
    final number = song.fullNumber;
    final when = rdCurrentWorkWhen(l10n, work);
    final part = ownGroup != null && rdMemberPartFiles(song, ownGroup!.id, choir: choir).any(rdIsNotes);
    final foot = part ? l10n.redesignWorksStatusPart : l10n.redesignWorksCurrentNoPart;
    return Semantics(
      button: true,
      label: [if (number.isNotEmpty) number, song.name, when, foot].join(', '),
      excludeSemantics: true,
      child: RdCard(
        padding: const EdgeInsets.all(12),
        onTap: () => rdOpenCurrentWork(context, ref, song, ownGroup?.id, choir: choir),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                Expanded(
                  child: Text(when, maxLines: 1, overflow: TextOverflow.ellipsis, style: RdType.meta(p, size: 12)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              song.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 15, height: 1.25, fontWeight: FontWeight.w600, color: p.text),
            ),
            const Spacer(),
            Row(
              children: [
                if (part) ...[
                  Icon(Icons.picture_as_pdf_outlined, size: 14, color: p.softText),
                  const SizedBox(width: 4),
                ],
                Expanded(
                  child: Text(
                    foot,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: part ? FontWeight.w600 : FontWeight.w500,
                      color: part ? p.softText : p.text2,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// "Do. 12.11. · Probe" for a planned Werk, "zuletzt 5. Nov." for one
/// played lately.
String rdCurrentWorkWhen(AppLocalizations l10n, RdCurrentWork work) {
  final locale = currentIntlLocale();
  final event = work.event;
  if (event != null) {
    return [
      if (event.date != null) DateFormat('E d.M.', locale).format(event.date!),
      if (event.type.isNotEmpty) event.type,
    ].join(' · ');
  }
  final played = work.lastPlayed;
  return played == null ? '' : l10n.redesignWorksCurrentLast(DateFormat.MMMd(locale).format(played));
}

/// A tap on a current Werk: the own part when it is one file, else the
/// Werk page (no part, or several files to pick from).
Future<void> rdOpenCurrentWork(
  BuildContext context,
  WidgetRef ref,
  Song song,
  int? groupId, {
  required bool choir,
}) async {
  final file = rdSingleOwnNotes(song, groupId, choir: choir);
  if (file != null) return rdOpenWorkFile(context, ref, song, file);
  if (song.id != null) RdSplitScope.open(context, RedesignRoutes.work(song.id!));
}
