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
        onBack: () => Navigator.of(context).pop(),
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
                      label: l10n.redesignImportCategoryLabel,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () async {
                          final picked = await rdPickImportCategory(context, plan, current: fs.category, title: f.name);
                          if (picked != null) controller.setCategory(f.path, picked);
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  rdImportCategoryLabel(context, plan, fs.category),
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: p.link),
                                ),
                              ),
                              Icon(Icons.arrow_drop_down, color: p.link, size: 20),
                            ],
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
      onBack: () => Navigator.of(context).pop(),
      title: work.folderName,
      subtitle: work.folders.length > 1 ? work.folders.join('\n') : (work.folders.isEmpty ? null : work.folders.first),
      bottom: ws.target.skip
          ? null
          : ws.confirmed
              ? RdOutlineButton(
                  label: l10n.redesignImportUndoConfirm,
                  onPressed: () => controller.confirm(work.key, value: false),
                )
              : RdPrimaryButton(
                  label: l10n.redesignImportConfirmWork,
                  icon: Icons.check,
                  onPressed: () {
                    controller.confirm(work.key);
                    Navigator.of(context).pop();
                  },
                ),
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
                  final target = await _pickTarget(context, plan, work);
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
      ],
    );
  }

  /// Sub-folder of [f] inside the Werk ("Alt", "Dirigenten › Stimmen").
  static String _folderOf(RdImportWork work, RdImportFile f) =>
      work.fassungen.where((x) => x.key == f.fassungKey).firstOrNull?.label ?? f.fassungKey.split('|').last;

  /// Sheet: an existing Werk (search), a new Werk or "Nicht übernehmen".
  Future<RdWorkTarget?> _pickTarget(BuildContext context, RdImportPlan plan, RdImportWork work) {
    return showModalBottomSheet<RdWorkTarget>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => _TargetSheet(plan: plan, work: work),
    );
  }
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

class _TargetSheet extends StatefulWidget {
  const _TargetSheet({required this.plan, required this.work});

  final RdImportPlan plan;
  final RdImportWork work;

  @override
  State<_TargetSheet> createState() => _TargetSheetState();
}

class _TargetSheetState extends State<_TargetSheet> {
  String _query = '';

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
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(l10n.redesignImportPickTitle, style: RdType.section(p)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  autofocus: false,
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    hintText: l10n.redesignImportPickSearch,
                    prefixIcon: Icon(Icons.search, color: p.text2),
                    isDense: true,
                  ),
                ),
              ),
              ListTile(
                leading: Icon(Icons.add, color: p.primary),
                title: Text(l10n.redesignImportPickNew),
                subtitle: Text(widget.work.folderName),
                onTap: () => Navigator.of(context).pop(
                  fallback.isNew
                      ? fallback
                      : RdWorkTarget.create(
                          name: rdParseWorkName(widget.work.folderName).title.isEmpty
                              ? widget.work.folderName
                              : rdParseWorkName(widget.work.folderName).title,
                        ),
                ),
              ),
              ListTile(
                leading: Icon(Icons.block, color: p.text2),
                title: Text(l10n.redesignImportPickSkip),
                onTap: () => Navigator.of(context).pop(const RdWorkTarget.skip()),
              ),
              const Divider(height: 1),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: songs.length,
                  itemBuilder: (_, i) => ListTile(
                    title: Text(songs[i].label),
                    onTap: () => Navigator.of(context).pop(RdWorkTarget.song(songs[i].id)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
