import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../../core/theme/redesign/rd_theme.dart';
import '../../../../../core/utils/choir_file_utils.dart';
import '../../../../../l10n/l10n.dart';
import '../../../data/import/rd_import_logic.dart';
import '../rd_widgets.dart';

/// REDESIGN: pieces shared by the pages of "Noten importieren".

/// Page frame of the assistant on [RdPage]: back link, title, step line
/// and bar, then the content. Buttons sit in the content (like "Neuer
/// Termin"); there is no bar of its own at the bottom.
class RdImportFrame extends StatelessWidget {
  const RdImportFrame({
    super.key,
    required this.title,
    required this.children,
    this.backLabel,
    this.onBack,
    this.step,
    this.subtitle,
    this.compactTitle = false,
  });

  /// Null = no back link (while uploading and when done).
  final String? backLabel;
  final VoidCallback? onBack;
  final String title;
  final String? subtitle;

  /// Smaller title for a long name (a Werk, like the Werk page).
  final bool compactTitle;

  /// 1–4, null = no step line (Werk page).
  final int? step;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final names = [l10n.redesignImportStepSource, l10n.redesignImportStepRead, l10n.redesignImportStepReview, l10n.redesignImportStepUpload];
    final step = this.step;
    return RdPage(
      children: [
        if (backLabel != null && onBack != null) ...[
          RdBackLink(label: backLabel!, onTap: onBack!),
          const SizedBox(height: 4),
        ],
        Semantics(
          header: true,
          child: Text(title, style: compactTitle ? RdType.title(p).copyWith(fontSize: 28) : RdType.largeTitle(p)),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(subtitle!, style: RdType.meta(p)),
        ],
        if (step != null) ...[
          const SizedBox(height: 10),
          Text(l10n.redesignImportStepOf(step, names[step - 1]), style: RdType.meta(p, size: 13)),
          const SizedBox(height: 6),
          ExcludeSemantics(
            child: Row(
              children: [
                for (var i = 1; i <= 4; i++) ...[
                  if (i > 1) const SizedBox(width: 4),
                  Expanded(
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: i <= step ? p.primary : p.track,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
        const SizedBox(height: 18),
        ...children,
      ],
    );
  }
}

/// Every category a file can get: the groups, the [newGroups] still to be
/// created, Aufnahme, Liedtext, the types, "Chor" for choirs and "Sonstige".
List<(RdImportCategory, String)> rdImportCategoryOptions(
  BuildContext context,
  RdImportPlan plan, {
  List<String> newGroups = const [],
}) {
  final l10n = context.l10n;
  return [
    for (final g in plan.instruments) (RdImportCategory(instrumentId: g.id), g.name),
    for (final name in newGroups) (RdImportCategory(newGroup: name), l10n.redesignImportCategoryNewGroup(name)),
    (const RdImportCategory(instrumentId: 1), l10n.songsRecording),
    (const RdImportCategory(instrumentId: 2), l10n.songsLyrics),
    (const RdImportCategory(note: 'Partitur'), 'Partitur'),
    (const RdImportCategory(note: 'Klavierauszug'), 'Klavierauszug'),
    (const RdImportCategory(note: 'Sibelius'), 'Sibelius'),
    (const RdImportCategory(note: 'MIDI'), 'MIDI'),
    if (plan.isChoir) (const RdImportCategory(note: kChoirAllNote), kChoirAllNote),
    (RdImportCategory.other, l10n.redesignImportCategoryOther),
  ];
}

/// Name of [c] as shown.
String rdImportCategoryLabel(BuildContext context, RdImportPlan plan, RdImportCategory c) {
  final l10n = context.l10n;
  if (c.newGroup != null) return l10n.redesignImportCategoryNewGroup(c.newGroup!);
  if (c.instrumentId == 1) return l10n.songsRecording;
  if (c.instrumentId == 2) return l10n.songsLyrics;
  if (c.instrumentId != null) {
    return plan.instruments.where((g) => g.id == c.instrumentId).firstOrNull?.name ?? l10n.redesignImportCategoryOther;
  }
  return c.note ?? l10n.redesignImportCategoryOther;
}

/// Sheet with every category, the groups ("Stimmen", with the [newGroups]
/// still to be created) apart from the other kinds of files; returns the
/// one picked. [header] stands above them (the file's first page).
Future<RdImportCategory?> rdPickImportCategory(
  BuildContext context,
  RdImportPlan plan, {
  required String title,
  RdImportCategory? current,
  List<String> newGroups = const [],
  Widget? header,
}) {
  final options = rdImportCategoryOptions(context, plan, newGroups: newGroups);
  final partCount = plan.instruments.length + newGroups.length;
  final parts = options.take(partCount).toList();
  final files = options.skip(partCount).toList();
  return showRdSheet<RdImportCategory>(
    context,
    Builder(builder: (context) {
      final l10n = context.l10n;
      Widget row((RdImportCategory, String) o) => RdListRow(
            title: o.$2,
            selected: o.$1 == current,
            showChevron: false,
            trailing: RdSheetCheck(o.$1 == current),
            onTap: () => Navigator.of(context).pop(o.$1),
          );
      return ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 16),
        children: [
          RdSheetTitle(title),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (header != null) ...[header, const SizedBox(height: 16)],
                if (parts.isNotEmpty) ...[
                  RdGroupLabel(l10n.redesignImportCategoryParts),
                  RdGroupedList(children: [for (final o in parts) row(o)]),
                  const SizedBox(height: 16),
                ],
                RdGroupLabel(l10n.redesignImportCategoryFiles),
                RdGroupedList(children: [for (final o in files) row(o)]),
              ],
            ),
          ),
        ],
      );
    }),
  );
}

/// The first page of a file to decide its part: [page] loads it, [link]
/// opens the file elsewhere when there is none to show (Drive), [read] is
/// the part name the KI read on it. A tap shows the page large, to zoom.
class RdImportPagePreview extends StatefulWidget {
  const RdImportPagePreview({super.key, required this.name, required this.page, this.link, this.read});

  final String name;
  final Future<Uint8List?> Function() page;
  final Uri? link;
  final String? read;

  @override
  State<RdImportPagePreview> createState() => _RdImportPagePreviewState();
}

class _RdImportPagePreviewState extends State<RdImportPagePreview> {
  late final Future<Uint8List?> _page = widget.page().catchError((Object _) => null);

  Future<void> _open(Uri link) async {
    try {
      await launchUrl(link, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  void _enlarge(Uint8List bytes) {
    showDialog<void>(
      context: context,
      useRootNavigator: true,
      builder: (context) => Dialog.fullscreen(
        backgroundColor: Colors.white,
        child: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                maxScale: 6,
                child: Center(
                  child: Image.memory(bytes, fit: BoxFit.contain, semanticLabel: context.l10n.redesignImportPreviewOf(widget.name)),
                ),
              ),
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: IconButton.filledTonal(
                    tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final read = widget.read;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FutureBuilder<Uint8List?>(
          future: _page,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const SizedBox(height: 160, child: Center(child: CircularProgressIndicator.adaptive()));
            }
            final bytes = snapshot.data;
            if (bytes == null) {
              final link = widget.link;
              return RdCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.redesignImportPreviewNone, style: RdType.meta(p)),
                    if (link != null)
                      TextButton.icon(
                        onPressed: () => _open(link),
                        icon: const Icon(Icons.open_in_new, size: 18),
                        label: Text(l10n.redesignImportPreviewDrive),
                      ),
                  ],
                ),
              );
            }
            return Semantics(
              button: true,
              label: '${l10n.redesignImportPreviewOf(widget.name)}, ${l10n.redesignImportPreviewZoom}',
              child: ExcludeSemantics(
                child: GestureDetector(
                  onTap: () => _enlarge(bytes),
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 340),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: p.track),
                    ),
                    clipBehavior: Clip.antiAlias,
                    // The top of the page: the part name is printed there.
                    child: Image.memory(bytes, fit: BoxFit.fitWidth, alignment: Alignment.topCenter),
                  ),
                ),
              ),
            );
          },
        ),
        if (read != null) ...[
          const SizedBox(height: 8),
          Text(l10n.redesignImportPageRead(read), style: RdType.meta(p, size: 13)),
        ],
      ],
    );
  }
}

/// Date as the app shows it ("12.3.2024").
String rdImportDate(BuildContext context, DateTime date) =>
    DateFormat.yMd(Localizations.localeOf(context).toLanguageTag()).format(date);

/// Text of a reason a file is left out.
String rdImportReason(BuildContext context, RdSkipReason reason) {
  final l10n = context.l10n;
  return switch (reason) {
    RdSkipReason.unsupported => l10n.redesignImportReasonUnsupported,
    RdSkipReason.tooLarge => l10n.redesignImportReasonTooLarge,
    RdSkipReason.duplicate => l10n.redesignImportReasonDuplicate,
    RdSkipReason.workSkipped => l10n.redesignImportReasonWorkSkipped,
    RdSkipReason.otherFassung => l10n.redesignImportReasonOtherFassung,
    RdSkipReason.sameName => l10n.redesignImportReasonSameName,
    RdSkipReason.wordNextToPdf => l10n.redesignImportReasonWord,
    RdSkipReason.partExists => l10n.redesignImportReasonPartExists,
    RdSkipReason.byHand => l10n.redesignImportReasonByHand,
  };
}

/// Pills of a Werk in the review list.
List<Widget> rdImportFlagPills(BuildContext context, RdWorkState state) {
  final l10n = context.l10n;
  if (state.target.skip) return [RdPill(l10n.redesignImportFlagSkipped)];
  return [
    if (state.target.isNew) RdPill(l10n.redesignImportFlagNew, tone: RdTone.primary),
    if (state.confirmed && state.flags.isNotEmpty)
      RdPill(l10n.redesignImportFlagConfirmed, tone: RdTone.present, icon: Icons.check)
    else ...[
      if (state.recheck) RdPill(l10n.redesignImportFlagRecheck, tone: RdTone.late),
      if (state.flags.contains(RdWorkFlag.unsureMatch)) RdPill(l10n.redesignImportFlagMatch, tone: RdTone.late),
      if (state.flags.contains(RdWorkFlag.fassungen)) RdPill(l10n.redesignImportFlagFassungen, tone: RdTone.late),
      if (state.flags.contains(RdWorkFlag.partExists)) RdPill(l10n.redesignImportFlagPartExists, tone: RdTone.late),
      if (state.flags.contains(RdWorkFlag.unclear)) RdPill(l10n.redesignImportFlagUnclear, tone: RdTone.late),
    ],
  ];
}

/// "In Attendix: 120 Wie wunderbar", "Neues Werk: …", "Wird nicht übernommen".
String rdImportTargetText(BuildContext context, RdImportPlan plan, RdWorkTarget target) {
  final l10n = context.l10n;
  if (target.skip) return l10n.redesignImportTargetSkip;
  if (target.isNew) {
    final number = [if ((target.prefix ?? '').isNotEmpty) target.prefix, if (target.number != null) '${target.number}'].join();
    return l10n.redesignImportTargetNew([if (number.isNotEmpty) number, target.name].join(' '));
  }
  return l10n.redesignImportTargetExisting(plan.songs[target.songId]?.label ?? '');
}

/// Subtitle of a Werk in the review list: the files taken, those left out
/// and the target only when it is not the folder's own name
/// ("4 Dateien · 2 weggelassen · → 66 Du großer Gott").
String rdImportWorkSubtitle(BuildContext context, RdImportPlan plan, RdImportWork work, RdWorkState state) {
  final l10n = context.l10n;
  if (state.target.skip) return '';
  final target = state.target;
  final String? name;
  if (target.isNew) {
    final number = [if ((target.prefix ?? '').isNotEmpty) target.prefix, if (target.number != null) '${target.number}'].join();
    name = [if (number.isNotEmpty) number, target.name].join(' ');
  } else {
    name = plan.songs[target.songId]?.label;
  }
  String plain(String s) => s.toLowerCase().replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), '');
  return [
    l10n.redesignImportFoundFiles(state.takeCount),
    if (state.skipCount > 0) l10n.redesignImportReviewCounts(state.skipCount),
    if (name != null && name.isNotEmpty && plain(name) != plain(work.folderName)) l10n.redesignImportReviewTarget(name),
  ].join(' · ');
}
