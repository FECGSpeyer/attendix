import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/redesign/rd_theme.dart';
import '../../../../l10n/l10n.dart';
import '../../data/import/rd_import_controller.dart';
import '../../data/import/rd_import_logic.dart';
import '../widgets/import/rd_import_widgets.dart';
import '../widgets/rd_widgets.dart';

/// REDESIGN: "Noten importieren" › one Werk (canvas H7 "Werk prüfen"): where
/// its files go, which Fassung, each file with its part and whether it is
/// taken; "Passt so" lets it into the upload.
class RdImportWorkPage extends ConsumerWidget {
  const RdImportWorkPage({super.key, required this.workKey});

  final String workKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.rd;
    final l10n = context.l10n;
    final state = ref.watch(rdImportProvider);
    final controller = ref.read(rdImportProvider.notifier);
    final plan = state.plan;
    final work = plan?.work(workKey);
    if (plan == null || work == null) {
      return RdImportFrame(
        backLabel: l10n.redesignImportStepReview,
        onBack: () => Navigator.of(context).maybePop(),
        title: l10n.redesignImportTitle,
        children: const [],
      );
    }
    final d = state.decisions;
    final ws = rdWorkState(plan, d, work);
    final fassung = rdFassungOf(d, work);
    final taken = [for (final f in work.files) if (ws.files[f.path]!.take) f];
    final left = [for (final f in work.files) if (!ws.files[f.path]!.take) f];

    Widget fileRow(RdImportFile f) {
      final fs = ws.files[f.path]!;
      final reason = fs.reason;
      return Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 14, 4),
        child: Row(
          children: [
            Checkbox.adaptive(
              value: fs.take,
              activeColor: p.primary,
              semanticLabel: l10n.redesignImportTakeLabel(f.name),
              onChanged: fs.canToggle ? (v) => controller.setTake(f.path, v ?? false) : null,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    f.name,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: fs.take ? p.text : p.text2),
                  ),
                  if (_folderOf(work, f).isNotEmpty) Text(_folderOf(work, f), style: RdType.meta(p, size: 12)),
                  if (!fs.take && reason != null)
                    Text(rdImportReason(context, reason), style: RdType.meta(p, size: 13))
                  else
                    Semantics(
                      button: true,
                      label: '${l10n.redesignImportCategoryLabel}: ${rdImportCategoryLabel(context, plan, fs.category)}',
                      // The tap stays with the InkWell; only the text read
                      // out is replaced.
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () async {
                          final picked = await rdPickImportCategory(context, plan, current: fs.category, title: f.name);
                          if (picked != null) controller.setCategory(f.path, picked);
                        },
                        // 44 px to tap, like the other links of the new design.
                        child: ExcludeSemantics(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 44),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    rdImportCategoryLabel(context, plan, fs.category),
                                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: p.link),
                                  ),
                                ),
                                Icon(Icons.arrow_drop_down, color: p.link, size: 22),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (fs.unclear) ...[const SizedBox(width: 8), RdPill(l10n.redesignImportFlagUnclear, tone: RdTone.late)],
          ],
        ),
      );
    }

    final matchHint = d.targets.containsKey(work.key)
        ? null
        : switch (work.match.kind) {
            RdMatchKind.numberOnly => l10n.redesignImportMatchNumberOnly,
            RdMatchKind.titleOnly => l10n.redesignImportMatchTitleOnly,
            RdMatchKind.ambiguous => l10n.redesignImportMatchAmbiguous,
            _ => null,
          };

    return RdImportFrame(
      backLabel: l10n.redesignImportStepReview,
      onBack: () => Navigator.of(context).maybePop(),
      title: work.folderName,
      compactTitle: true,
      subtitle: _whereOf(work),
      children: [
        RdSectionHeader(l10n.redesignImportTargetTitle),
        RdCard(
          padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(rdImportTargetText(context, plan, ws.target), style: RdType.body(p).copyWith(fontWeight: FontWeight.w600)),
                    if (matchHint != null) ...[
                      const SizedBox(height: 4),
                      Text(matchHint, style: RdType.meta(p, size: 13).copyWith(color: p.late)),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              RdTextLink(
                label: l10n.redesignImportTargetChange,
                onTap: () async {
                  final target = await showRdSheet<RdWorkTarget>(context, _TargetSheet(plan: plan, work: work, current: ws.target));
                  if (target != null) controller.setTarget(work.key, target);
                },
              ),
            ],
          ),
        ),
        if (work.fassungen.length > 1 && !ws.target.skip) ...[
          const SizedBox(height: 20),
          RdSectionHeader(l10n.redesignImportFassungenTitle),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(l10n.redesignImportFassungenIntro, style: RdType.meta(p, size: 13)),
          ),
          RdGroupedList(
            children: [
              for (final f in work.fassungen)
                _RadioRow(
                  title: f.label.isEmpty ? l10n.redesignImportFassungMain : f.label,
                  subtitle: f.newest == null
                      ? l10n.redesignImportFassungMetaNoDate(f.fileCount)
                      : l10n.redesignImportFassungMeta(f.fileCount, rdImportDate(context, f.newest!)),
                  pill: f.isOld ? l10n.redesignImportFassungOld : null,
                  selected: fassung == f.key,
                  onTap: () => controller.setFassung(work.key, f.key),
                ),
              _RadioRow(
                title: l10n.redesignImportFassungAll,
                selected: fassung == null,
                onTap: () => controller.setFassung(work.key, null),
              ),
            ],
          ),
        ],
        const SizedBox(height: 20),
        RdSectionHeader(l10n.redesignImportFilesTake(taken.length)),
        if (taken.isNotEmpty) RdGroupedList(children: [for (final f in taken) fileRow(f)]),
        if (left.isNotEmpty) ...[
          const SizedBox(height: 20),
          RdSectionHeader(l10n.redesignImportFilesSkip(left.length)),
          RdGroupedList(children: [for (final f in left) fileRow(f)]),
        ],
        if (!ws.target.skip) ...[
          const SizedBox(height: 24),
          if (ws.confirmed)
            RdOutlineButton(
              label: l10n.redesignImportUndoConfirm,
              onPressed: () => controller.confirm(work.key, value: false),
            )
          else ...[
            // New dates may still change the suggested Fassung.
            if (state.readingDates) ...[
              Text(l10n.redesignImportDatesReading, style: RdType.meta(p, size: 13)),
              const SizedBox(height: 8),
            ],
            RdPrimaryButton(
              label: l10n.redesignImportConfirmWork,
              icon: Icons.check,
              onPressed: state.readingDates
                  ? null
                  : () {
                      controller.confirm(work.key);
                      Navigator.of(context).maybePop();
                    },
            ),
          ],
        ],
      ],
    );
  }

  /// Where the Werk lies: the folders above it ("Noten Speyer › Orchester"),
  /// or every folder when it comes from several.
  static String? _whereOf(RdImportWork work) {
    String path(String f) => f.split('/').where((s) => s.isNotEmpty).join(' › ');
    if (work.folders.length > 1) return work.folders.map(path).join('\n');
    final folder = work.folders.firstOrNull;
    if (folder == null || !folder.contains('/')) return null;
    final above = path(folder.substring(0, folder.lastIndexOf('/')));
    return above.isEmpty ? null : above;
  }

  /// Sub-folder of [f] inside the Werk ("Alt", "Dirigenten › Stimmen").
  static String _folderOf(RdImportWork work, RdImportFile f) =>
      work.fassungen.where((x) => x.key == f.fassungKey).firstOrNull?.label ?? f.fassungKey.split('|').last;
}

class _RadioRow extends StatelessWidget {
  const _RadioRow({required this.title, required this.selected, required this.onTap, this.subtitle, this.pill});

  final String title;
  final String? subtitle;
  final String? pill;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: RdListRow(
        title: title,
        subtitle: subtitle,
        showChevron: false,
        onTap: onTap,
        leading: Icon(selected ? Icons.radio_button_checked : Icons.radio_button_unchecked, color: selected ? p.primary : p.text2),
        trailing: pill == null ? null : RdPill(pill!),
      ),
    );
  }
}

/// "Werk wählen": a new Werk, "Nicht übernehmen" or an existing Werk
/// (search like the Werke list); the current target is checked.
class _TargetSheet extends StatefulWidget {
  const _TargetSheet({required this.plan, required this.work, required this.current});

  final RdImportPlan plan;
  final RdImportWork work;
  final RdWorkTarget current;

  @override
  State<_TargetSheet> createState() => _TargetSheetState();
}

class _TargetSheetState extends State<_TargetSheet> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final q = _query.trim();
    final songs = widget.plan.songs.values.where((s) {
      if (q.isEmpty) return true;
      return s.label.toLowerCase().contains(q.toLowerCase()) || rdImportTitleSimilarity(q, s.name) >= 0.5;
    }).toList()
      ..sort((a, b) {
        final na = a.number ?? 1 << 30;
        final nb = b.number ?? 1 << 30;
        return na != nb ? na.compareTo(nb) : a.name.compareTo(b.name);
      });
    final fallback = rdDefaultTarget(widget.plan, widget.work);
    final current = widget.current;
    final border = OutlineInputBorder(borderRadius: BorderRadius.circular(p.buttonRadius), borderSide: BorderSide.none);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RdSheetTitle(l10n.redesignImportPickTitle),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _search,
              onChanged: (v) => setState(() => _query = v),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: l10n.redesignImportPickSearch,
                prefixIcon: Icon(Icons.search, color: p.text2),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: Icon(Icons.close, color: p.text2),
                        tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
                        onPressed: () {
                          _search.clear();
                          setState(() => _query = '');
                        },
                      ),
                filled: true,
                fillColor: p.surface,
                border: border,
                enabledBorder: border,
              ),
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                RdGroupedList(
                  children: [
                    RdListRow(
                      leading: Icon(Icons.add, color: p.primary),
                      title: l10n.redesignImportPickNew,
                      subtitle: widget.work.folderName,
                      selected: current.isNew,
                      showChevron: false,
                      trailing: RdSheetCheck(current.isNew),
                      onTap: () => Navigator.of(context).pop(
                        current.isNew
                            ? current
                            : fallback.isNew
                                ? fallback
                                : RdWorkTarget.create(
                                    name: rdParseWorkName(widget.work.folderName).title.isEmpty
                                        ? widget.work.folderName
                                        : rdParseWorkName(widget.work.folderName).title,
                                  ),
                      ),
                    ),
                    RdListRow(
                      leading: Icon(Icons.block, color: p.text2),
                      title: l10n.redesignImportPickSkip,
                      selected: current.skip,
                      showChevron: false,
                      trailing: RdSheetCheck(current.skip),
                      onTap: () => Navigator.of(context).pop(const RdWorkTarget.skip()),
                    ),
                  ],
                ),
                if (songs.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  RdGroupedList(
                    children: [
                      for (final s in songs)
                        RdListRow(
                          title: s.label,
                          selected: current.songId == s.id,
                          showChevron: false,
                          trailing: RdSheetCheck(current.songId == s.id),
                          onTap: () => Navigator.of(context).pop(RdWorkTarget.song(s.id)),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
