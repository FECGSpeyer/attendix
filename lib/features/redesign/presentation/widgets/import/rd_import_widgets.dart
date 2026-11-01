import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../../core/theme/redesign/rd_theme.dart';
import '../../../../../core/utils/choir_file_utils.dart';
import '../../../../../l10n/l10n.dart';
import '../../../data/import/rd_import_logic.dart';
import '../rd_widgets.dart';

/// REDESIGN: pieces shared by the pages of "Noten importieren".

/// Page frame of the assistant: back link, title, step bar, the content in
/// the usual 720 px column and a button bar at the bottom.
class RdImportFrame extends StatelessWidget {
  const RdImportFrame({
    super.key,
    required this.backLabel,
    required this.onBack,
    required this.title,
    required this.children,
    this.step,
    this.subtitle,
    this.bottom,
  });

  final String backLabel;
  final VoidCallback onBack;
  final String title;
  final String? subtitle;

  /// 1–4, null = no step bar (Werk page).
  final int? step;
  final List<Widget> children;
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final names = [l10n.redesignImportStepSource, l10n.redesignImportStepRead, l10n.redesignImportStepReview, l10n.redesignImportStepUpload];
    Widget column(List<Widget> children) => Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
          ),
        );
    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(
        bottom: bottom == null,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
          children: [
            column([
              RdBackLink(label: backLabel, onTap: onBack),
              const SizedBox(height: 4),
              Semantics(header: true, child: Text(title, style: RdType.title(p))),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(subtitle!, style: RdType.meta(p)),
              ],
              if (step != null) ...[
                const SizedBox(height: 12),
                Text(l10n.redesignImportStepOf(step!, names[step! - 1]), style: RdType.meta(p, size: 13)),
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
                              color: i <= step! ? p.primary : p.track,
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              ...children,
            ]),
          ],
        ),
      ),
      bottomNavigationBar: bottom == null
          ? null
          : Material(
              color: p.surface,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                  child: column([bottom!]),
                ),
              ),
            ),
    );
  }
}

/// A switch row of the new design (title, detail, switch).
class RdImportSwitchRow extends StatelessWidget {
  const RdImportSwitchRow({super.key, required this.title, required this.detail, required this.value, required this.onChanged});

  final String title;
  final String detail;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    return MergeSemantics(
      child: InkWell(
        onTap: () => onChanged(!value),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: p.text)),
                    const SizedBox(height: 2),
                    Text(detail, style: RdType.meta(p, size: 13)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Switch.adaptive(value: value, activeColor: p.primary, onChanged: onChanged),
            ],
          ),
        ),
      ),
    );
  }
}

/// Every category a file can get: the groups, Aufnahme, Liedtext, the
/// types, "Chor" for choirs and "Sonstige".
List<(RdImportCategory, String)> rdImportCategoryOptions(BuildContext context, RdImportPlan plan) {
  final l10n = context.l10n;
  return [
    for (final g in plan.instruments) (RdImportCategory(instrumentId: g.id), g.name),
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

/// Bottom sheet with every category; returns the one picked.
Future<RdImportCategory?> rdPickImportCategory(BuildContext context, RdImportPlan plan, {RdImportCategory? current, String? title}) {
  final options = rdImportCategoryOptions(context, plan);
  return showModalBottomSheet<RdImportCategory>(
    context: context,
    useRootNavigator: true,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) {
      final p = ctx.rd;
      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.75),
          child: ListView(
            shrinkWrap: true,
            children: [
              if (title != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Text(title, style: RdType.section(p)),
                ),
              for (final (category, label) in options)
                ListTile(
                  title: Text(label),
                  trailing: category == current ? Icon(Icons.check, color: p.primary) : null,
                  onTap: () => Navigator.of(ctx).pop(category),
                ),
            ],
          ),
        ),
      );
    },
  );
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
