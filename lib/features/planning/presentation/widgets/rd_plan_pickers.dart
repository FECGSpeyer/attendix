part of 'rd_plan_widgets.dart';

// Song picker, event-works checklist, new-plan sheet, and multi-plan share sheet.

/// What the Werke picker returned: one Werk, or "Alle aktuellen Werke".
typedef PlanWorksPick = ({Song? song, bool allCurrent});

/// Beta "Werke": sheet with search, current Werke first, then all.
/// [offerAllCurrent]: "Alle aktuellen Werke" on top of the current ones.
Future<PlanWorksPick?> showRdPlanSongPicker(
  BuildContext context,
  List<Song> songs, {
  Set<int> currentIds = const {},
  Set<int> inPlanIds = const {},
  List<SongCollection>? collections,
  bool offerAllCurrent = false,
}) {
  return showModalBottomSheet<PlanWorksPick>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: context.rd.bg,
    builder:
        (ctx) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
          child: SizedBox(
            height: MediaQuery.sizeOf(ctx).height * 0.85,
            child: _RdSongPicker(
              songs: songs,
              currentIds: currentIds,
              inPlanIds: inPlanIds,
              collections: collections,
              offerAllCurrent: offerAllCurrent,
            ),
          ),
        ),
  );
}

class _RdSongPicker extends StatefulWidget {
  const _RdSongPicker({
    required this.songs,
    required this.currentIds,
    required this.inPlanIds,
    this.collections,
    this.offerAllCurrent = false,
  });

  final List<Song> songs;
  final Set<int> currentIds;
  final Set<int> inPlanIds;
  final bool offerAllCurrent;

  /// Sammlungen, to name the one of a Werk (none for the Repertoire).
  final List<SongCollection>? collections;

  @override
  State<_RdSongPicker> createState() => _RdSongPickerState();
}

class _RdSongPickerState extends State<_RdSongPicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final q = _query.trim().toLowerCase();
    final filtered =
        widget.songs.where((s) {
          if (q.isEmpty) return true;
          final label = '${s.prefix ?? ''}${s.number ?? ''} ${s.name} ${s.composer ?? ''}'.toLowerCase();
          return label.contains(q);
        }).toList();
    final current = filtered.where((s) => widget.currentIds.contains(s.id)).toList();
    final rest = filtered.where((s) => !widget.currentIds.contains(s.id)).toList();
    // All current Werke at once: only before searching, and only for more than one.
    final allCurrent = widget.offerAllCurrent && q.isEmpty && current.length > 1;

    Widget row(Song s) {
      final inPlan = widget.inPlanIds.contains(s.id);
      final composer = (s.composer ?? '').trim();
      final subtitle = [
        if (rdCollectionById(widget.collections ?? const [], s.collectionId) case final c?) c.name,
        if (composer.isNotEmpty) composer,
      ].join(' · ');
      return RdListRow(
        leading: RdRowIcon(Icons.music_note_outlined),
        title: '${s.prefix ?? ''}${s.number ?? ''} ${s.name}'.trim(),
        subtitle: subtitle.isEmpty ? null : subtitle,
        showChevron: false,
        trailing:
            inPlan ? Text(l10n.redesignPlanSongInPlan, style: RdType.meta(p, size: 13)) : Icon(Icons.add_circle_outline, color: p.link),
        onTap: () => Navigator.of(context).pop((song: s, allCurrent: false)),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        Semantics(header: true, child: Text(l10n.planningChooseSong, style: RdType.cardTitle(p))),
        const SizedBox(height: 12),
        TextField(
          key: const Key('rd-plan-song-search'),
          style: TextStyle(fontSize: 17, color: p.text),
          decoration: rdInputDecoration(p, l10n.attListSearchSong).copyWith(prefixIcon: Icon(Icons.search, color: p.text2)),
          onChanged: (v) => setState(() => _query = v),
        ),
        const SizedBox(height: 16),
        if (filtered.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(l10n.attListNoSongsFound, textAlign: TextAlign.center, style: RdType.meta(p, size: 15)),
          ),
        if (current.isNotEmpty) ...[
          RdGroupLabel(l10n.songsCurrent),
          RdGroupedList(
            children: [
              if (allCurrent)
                RdListRow(
                  key: const Key('rd-plan-song-all-current'),
                  leading: RdRowIcon(Icons.library_music_outlined),
                  title: l10n.redesignPlanAllCurrent,
                  showChevron: false,
                  trailing: Icon(Icons.add_circle_outline, color: p.link),
                  onTap: () => Navigator.of(context).pop((song: null, allCurrent: true)),
                ),
              for (final s in current) row(s),
            ],
          ),
          const SizedBox(height: 16),
        ],
        if (rest.isNotEmpty) ...[
          if (current.isNotEmpty) RdGroupLabel(l10n.songsAllSongs),
          RdGroupedList(children: [for (final s in rest) row(s)]),
        ],
      ],
    );
  }
}

/// One Werk planned for a Termin, with the conductor planned there.
typedef PlanEventWork = ({Song song, String conductor});

/// What was chosen in [showRdEventWorksSheet]: the ticked [works], [other]
/// for "Anderes Werk" (the Werk list), or [follow] for "Wieder dem
/// Auftritt folgen".
typedef PlanEventWorksChoice = ({List<PlanEventWork> works, bool other, bool follow});

/// Beta "Werke übernehmen": the Werke planned for the Termine in [groups]
/// as a checklist. Those of the first Termin are ticked, except the ones
/// already [inPlanIds]. Returns the ticked Werke in the listed order.
/// [offerOther]: a row "Anderes Werk" below them.
///
/// The Werke of a Termin (Überblick, "Ändern") use the same sheet with
/// their own [title], the ticks in [initial], [confirmLabel] ("6 Werke
/// übernehmen") and [followLabel] for a row "Wieder dem Auftritt folgen".
Future<PlanEventWorksChoice?> showRdEventWorksSheet(
  BuildContext context, {
  required List<({String label, List<PlanEventWork> works})> groups,
  Set<int> inPlanIds = const {},
  String? title,
  String? subtitle,
  Set<int>? initial,
  bool offerOther = false,
  String Function(int count)? confirmLabel,
  String? followLabel,
}) {
  final selected = ValueNotifier<Set<int>>(
    initial ??
        {
          if (groups.isNotEmpty)
            for (final w in groups.first.works)
              if (!inPlanIds.contains(w.song.id)) w.song.id!,
        },
  );
  List<PlanEventWork> chosen() => [
    for (final g in groups)
      for (final w in g.works)
        if (selected.value.contains(w.song.id)) w,
  ];

  return showRdPlanSheet<PlanEventWorksChoice>(
    context,
    title: title ?? context.l10n.redesignPlanEventWorksTitle,
    subtitle: subtitle,
    builder:
        (ctx, pop) => [
          ValueListenableBuilder<Set<int>>(
            valueListenable: selected,
            builder: (ctx, value, _) => _RdEventWorksList(groups: groups, inPlanIds: inPlanIds, selected: selected),
          ),
          if (offerOther) ...[
            const SizedBox(height: 12),
            RdGroupedList(
              children: [
                RdListRow(
                  key: const Key('rd-plan-event-works-other'),
                  leading: const RdRowIcon(Icons.search),
                  title: ctx.l10n.redesignPlanEventWorksOther,
                  subtitle: ctx.l10n.redesignPlanEventWorksOtherHint,
                  onTap: () => pop((works: const [], other: true, follow: false)),
                ),
              ],
            ),
          ],
          if (followLabel != null) ...[
            const SizedBox(height: 12),
            RdGroupedList(
              children: [
                RdListRow(
                  key: const Key('rd-plan-event-works-follow'),
                  leading: const RdRowIcon(Icons.event_repeat_outlined),
                  title: followLabel,
                  showChevron: false,
                  onTap: () => pop((works: const [], other: false, follow: true)),
                ),
              ],
            ),
          ],
        ],
    footer:
        (ctx, pop) => ValueListenableBuilder<Set<int>>(
          valueListenable: selected,
          builder:
              (ctx, value, _) => RdPrimaryButton(
                key: const Key('rd-plan-event-works-add'),
                label: confirmLabel?.call(value.length) ?? ctx.l10n.redesignPlanEventWorksAdd(value.length),
                onPressed: value.isEmpty ? null : () => pop((works: chosen(), other: false, follow: false)),
              ),
        ),
  ).whenComplete(selected.dispose);
}

class _RdEventWorksList extends StatelessWidget {
  const _RdEventWorksList({required this.groups, required this.inPlanIds, required this.selected});

  final List<({String label, List<PlanEventWork> works})> groups;
  final Set<int> inPlanIds;
  final ValueNotifier<Set<int>> selected;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final chosen = selected.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, g) in groups.indexed) ...[
          if (i > 0) const SizedBox(height: 12),
          Builder(
            builder: (context) {
              final ids = {for (final w in g.works) w.song.id!};
              final all = chosen.containsAll(ids);
              return Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(child: RdGroupLabel(g.label)),
                  // Several Werke at once: all of this Termin, or none.
                  if (ids.length > 1)
                    Semantics(
                      button: true,
                      child: InkWell(
                        key: ValueKey('rd-plan-event-works-all-$i'),
                        borderRadius: BorderRadius.circular(10),
                        onTap: () {
                          final now = selected.value;
                          selected.value = now.containsAll(ids) ? now.difference(ids) : now.union(ids);
                        },
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 44),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(8, 0, 4, 8),
                            child: Align(
                              alignment: Alignment.bottomRight,
                              widthFactor: 1,
                              child: Text(
                                all ? l10n.redesignPlanEventWorksNone : l10n.redesignPlanEventWorksAll,
                                style: TextStyle(fontSize: 15, color: p.link),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          RdGroupedList(
            children: [
              for (final w in g.works)
                RdListRow(
                  key: ValueKey('rd-plan-event-work-$i-${w.song.id}'),
                  leading: Icon(
                    chosen.contains(w.song.id) ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: chosen.contains(w.song.id) ? p.primary : p.text2,
                  ),
                  title: '${w.song.prefix ?? ''}${w.song.number ?? ''} ${w.song.name}'.trim(),
                  subtitle: w.conductor.isEmpty ? null : w.conductor,
                  value: inPlanIds.contains(w.song.id) ? l10n.redesignPlanSongInPlan : null,
                  showChevron: false,
                  onTap: () {
                    // The value now, not the one this row was built with.
                    final id = w.song.id!;
                    final now = selected.value;
                    selected.value = now.contains(id) ? now.difference({id}) : now.union({id});
                  },
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Result of the Beta "Neuer Plan" sheet.
typedef RdNewPlanChoice = ({bool copy, int? day, String label});

/// Beta "+ Plan": name, day (multi-day Termine) and empty or as a copy.
Future<RdNewPlanChoice?> showRdNewPlanSheet(
  BuildContext context, {
  required List<({int day, String label})> days,
  int? initialDay,
  required String copyOf,
}) {
  return showRdPlanSheet<RdNewPlanChoice>(
    context,
    title: context.l10n.redesignPlanNewPlan,
    builder: (ctx, pop) => [_RdNewPlanBody(days: days, initialDay: initialDay, copyOf: copyOf, onDone: pop)],
  );
}

class _RdNewPlanBody extends StatefulWidget {
  const _RdNewPlanBody({required this.days, required this.initialDay, required this.copyOf, required this.onDone});

  final List<({int day, String label})> days;
  final int? initialDay;
  final String copyOf;
  final void Function(RdNewPlanChoice value) onDone;

  @override
  State<_RdNewPlanBody> createState() => _RdNewPlanBodyState();
}

class _RdNewPlanBodyState extends State<_RdNewPlanBody> {
  final _name = TextEditingController();
  late int? _day = widget.initialDay;
  bool _copy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RdGroupedList(
          children: [
            RdFieldRow(
              label: l10n.planningName,
              child: TextField(
                key: const Key('rd-plan-new-name'),
                controller: _name,
                textCapitalization: TextCapitalization.sentences,
                style: TextStyle(fontSize: 17, color: p.text),
                decoration: rdInputDecoration(p, l10n.redesignPlanNameHint),
              ),
            ),
          ],
        ),
        if (widget.days.isNotEmpty) ...[
          const SizedBox(height: 16),
          RdGroupLabel(l10n.redesignPlanDay),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final d in widget.days) RdChoiceChip(label: d.label, selected: d.day == _day, onTap: () => setState(() => _day = d.day)),
            ],
          ),
        ],
        const SizedBox(height: 16),
        RdGroupLabel(l10n.redesignPlanContent),
        RdSegmented<bool>(
          values: const [false, true],
          selected: _copy,
          labelOf: (v) => v ? l10n.redesignPlanCopyOf(widget.copyOf) : l10n.planningEmpty,
          onChanged: (v) => setState(() => _copy = v),
        ),
        const SizedBox(height: 20),
        RdPrimaryButton(
          key: const Key('rd-plan-new-confirm'),
          label: l10n.redesignPlanCreatePlan,
          onPressed: () => widget.onDone((copy: _copy, day: _day, label: _name.text.trim())),
        ),
      ],
    );
  }
}

/// Beta "Ablaufplan teilen" of a Termin with several plans: which plan on
/// top, then download and Telegram.
Future<PlanShareChoice?> showRdPlanShareSheet(
  BuildContext context, {
  required String currentLabel,
  required int planCount,
  required bool hasChatId,
}) {
  return showRdPlanSheet<PlanShareChoice>(
    context,
    title: context.l10n.attendanceShareRunSheet,
    builder: (ctx, pop) => [_RdShareBody(currentLabel: currentLabel, planCount: planCount, hasChatId: hasChatId, onDone: pop)],
  );
}

class _RdShareBody extends StatefulWidget {
  const _RdShareBody({required this.currentLabel, required this.planCount, required this.hasChatId, required this.onDone});

  final String currentLabel;
  final int planCount;
  final bool hasChatId;
  final void Function(PlanShareChoice value) onDone;

  @override
  State<_RdShareBody> createState() => _RdShareBodyState();
}

class _RdShareBodyState extends State<_RdShareBody> {
  bool _all = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    Widget option(IconData icon, String label, PlanExportAction action) =>
        RdListRow(leading: RdRowIcon(icon), title: label, showChevron: false, onTap: () => widget.onDone((all: _all, action: action)));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RdGroupLabel(l10n.redesignPlanViewWhich),
        RdSegmented<bool>(
          values: const [false, true],
          selected: _all,
          labelOf: (v) => v ? l10n.planningAllPlans(widget.planCount) : l10n.planningOnlyLabel(widget.currentLabel),
          onChanged: (v) => setState(() => _all = v),
        ),
        const SizedBox(height: 16),
        RdGroupLabel(l10n.redesignPlanDownload),
        RdGroupedList(
          children: [
            option(Icons.description_outlined, l10n.attendanceExportPdf, PlanExportAction.pdf),
            option(Icons.file_copy_outlined, l10n.attendanceExportPdfA5, PlanExportAction.pdf2x),
          ],
        ),
        if (widget.hasChatId) ...[
          const SizedBox(height: 16),
          RdGroupLabel(l10n.redesignPlanTelegram),
          RdGroupedList(
            children: [
              option(Icons.send_outlined, l10n.attendanceTelegramPdf, PlanExportAction.telegram),
              option(Icons.send_outlined, l10n.attendanceTelegramPdfA5, PlanExportAction.telegram2x),
              if (!_all) option(Icons.image_outlined, l10n.attendanceTelegramImage, PlanExportAction.telegramImage),
            ],
          ),
        ],
      ],
    );
  }
}

