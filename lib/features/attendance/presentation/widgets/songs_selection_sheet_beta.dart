part of 'songs_selection_sheet.dart';

/// Conductor of one Werk: a group member ([id]) or a guest name ([other]).
typedef _RdConductor = ({int? id, String? other});

/// Beta (redesign) layout of "Werk(e) hinzufügen": all Werke are picked at
/// once, then "Dirigent für alle" plus a conductor per Werk (tap a Werk to
/// change only its conductor), so two conductors need one pass, not two.
extension _RdSongsSelection on _SongsSelectionSheetState {
  /// "Dirigent für alle"; without a choice yet the first conductor.
  _RdConductor? _rdForAll(List<Person> conductors) {
    if (_useOtherConductor) {
      final name = _otherConductorName?.trim();
      return name == null || name.isEmpty ? null : (id: null, other: name);
    }
    final id = _selectedConductorId ?? conductors.where((c) => c.id != null).firstOrNull?.id;
    return id == null ? null : (id: id, other: null);
  }

  _RdConductor? _rdConductorFor(int songId, List<Person> conductors) => _rdOverrides[songId] ?? _rdForAll(conductors);

  String _rdConductorLabel(_RdConductor? c, List<Person> conductors) {
    if (c == null) return context.l10n.redesignEventChooseConductor;
    if (c.other != null) return c.other!;
    return conductors.where((p) => p.id == c.id).firstOrNull?.fullName ?? context.l10n.commonUnknown;
  }

  Future<void> _rdOpenPickerFirst() async {
    final applied = await _openSongPicker();
    if (!mounted) return;
    if (!applied && _selectedSongIds.isEmpty) Navigator.of(context).pop();
  }

  /// "Dirigent für alle": sets every Werk to [c] (single changes are reset).
  void _rdSetForAll(_RdConductor c) => _update(() {
    _rdOverrides.clear();
    _rdExpandedSongId = null;
    _useOtherConductor = c.other != null;
    _otherConductorName = c.other;
    _otherConductorSaved = c.other != null;
    _otherConductorController.text = c.other ?? '';
    _selectedConductorId = c.other != null ? null : c.id;
  });

  void _rdSetFor(int songId, _RdConductor c, List<Person> conductors) => _update(() {
    if (_rdForAll(conductors) == c) {
      _rdOverrides.remove(songId);
    } else {
      _rdOverrides[songId] = c;
    }
    _rdExpandedSongId = null;
  });

  /// "Anderer Dirigent": asks for the name; null when cancelled or empty.
  Future<_RdConductor?> _rdAskOther() async {
    final l10n = context.l10n;
    final raw = await showRdPlanTextSheet(context, title: l10n.attListEnterConductor, hint: l10n.attListConductor);
    final name = raw?.trim();
    if (!mounted || name == null || name.isEmpty) return null;
    return (id: null, other: name);
  }

  List<Widget> _rdConductorChips(List<Person> conductors, _RdConductor? current, void Function(_RdConductor c) onPick) {
    final l10n = context.l10n;
    return [
      for (final c in conductors)
        if (c.id != null)
          RdChoiceChip(
            label: c.fullName,
            selected: current?.other == null && current?.id == c.id,
            onTap: () => onPick((id: c.id, other: null)),
          ),
      RdChoiceChip(
        label: current?.other ?? l10n.attListOtherConductor,
        selected: current?.other != null,
        onTap: () async {
          final c = await _rdAskOther();
          if (c != null && mounted) onPick(c);
        },
      ),
    ];
  }

  Widget _rdBuild(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final conductors = ref.watch(activeConductorsProvider).valueOrNull ?? const <Person>[];
    final songs = ref.watch(songsProvider).valueOrNull ?? const <Song>[];
    final forAll = _rdForAll(conductors);
    final count = _selectedSongIds.length;
    String songTitle(int id) {
      final song = songs.where((s) => s.id == id).firstOrNull;
      if (song == null) return l10n.commonUnknown;
      return '${song.prefix ?? ''}${song.number ?? ''} ${song.name}'.trim();
    }

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          children: [
            Semantics(
              header: true,
              child: Text(
                count == 0 ? l10n.attListAddSongs : l10n.redesignEventAddWorksTitle(count),
                style: RdType.cardTitle(p),
              ),
            ),
            const SizedBox(height: 16),
            if (count > 1) ...[
              RdGroupLabel(l10n.redesignEventConductorForAll),
              Wrap(spacing: 8, runSpacing: 8, children: _rdConductorChips(conductors, forAll, _rdSetForAll)),
              const SizedBox(height: 20),
              RdGroupLabel(l10n.redesignEventWorks),
            ],
            RdGroupedList(
              children: [
                for (final id in _selectedSongIds)
                  RdListRow(
                    key: Key('rd-songs-row-$id'),
                    title: songTitle(id),
                    showChevron: false,
                    selected: _rdExpandedSongId == id,
                    // Open: the chips below get the full width.
                    trailing:
                        _rdExpandedSongId == id
                            ? Icon(Icons.expand_less, size: 20, color: p.text2)
                            : _RdConductorPill(
                              label: _rdConductorLabel(_rdConductorFor(id, conductors), conductors),
                              exception: _rdOverrides.containsKey(id),
                            ),
                    onTap: () => _update(() => _rdExpandedSongId = _rdExpandedSongId == id ? null : id),
                    footer:
                        _rdExpandedSongId == id
                            ? Padding(
                              padding: const EdgeInsets.only(top: 4, bottom: 4),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(l10n.redesignEventConductorFor(songTitle(id)), style: RdType.meta(p, size: 13)),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: _rdConductorChips(
                                      conductors,
                                      _rdConductorFor(id, conductors),
                                      (c) => _rdSetFor(id, c, conductors),
                                    ),
                                  ),
                                ],
                              ),
                            )
                            : null,
                  ),
                RdListRow(
                  key: const Key('rd-songs-pick'),
                  leading: RdRowIcon(count == 0 ? Icons.music_note_outlined : Icons.add),
                  title: count == 0 ? l10n.attListChooseSongs : l10n.redesignEventMoreWorks,
                  titleColor: count == 0 ? null : p.link,
                  showChevron: count == 0,
                  onTap: _openSongPicker,
                ),
              ],
            ),
            const SizedBox(height: 24),
            RdPrimaryButton(
              key: const Key('rd-songs-add'),
              label: count == 0 ? l10n.attListAddSongs : l10n.redesignEventAddWorksTitle(count),
              onPressed: _canAdd() ? _addSongs : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// Conductor of a Werk at the end of its row; tap the row to change it.
class _RdConductorPill extends StatelessWidget {
  const _RdConductorPill({required this.label, required this.exception});

  final String label;

  /// Differs from "Dirigent für alle".
  final bool exception;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 160),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 5, 6, 5),
        decoration: BoxDecoration(color: exception ? p.text : p.soft, borderRadius: BorderRadius.circular(14)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: exception ? p.bg : p.softText),
              ),
            ),
            Icon(Icons.expand_more, size: 18, color: exception ? p.bg : p.softText),
          ],
        ),
      ),
    );
  }
}

/// Beta "Werke auswählen": search plus a multi-select list, "Weiter" at the
/// top right.
class _RdSongMultiPicker extends ConsumerStatefulWidget {
  const _RdSongMultiPicker({required this.initialSelection});

  final Set<int> initialSelection;

  @override
  ConsumerState<_RdSongMultiPicker> createState() => _RdSongMultiPickerState();
}

class _RdSongMultiPickerState extends ConsumerState<_RdSongMultiPicker> {
  late final Set<int> _selected = {...widget.initialSelection};
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final songsAsync = ref.watch(songsProvider);
    final collectionsAsync = ref.watch(songCollectionsProvider);
    final collections = collectionsAsync.valueOrNull;
    final allSongs = songsAsync.valueOrNull ?? const <Song>[];
    // Fail closed: ohne geladene Sammlungen nur das Repertoire anbieten.
    final songs = collectionsAsync.hasValue ? rdPlannableWorks(allSongs, collections) : rdWorksIn(allSongs, null);
    final collectionsLoading = !collectionsAsync.hasValue && !collectionsAsync.hasError;
    final filtered =
        _search.isEmpty
            ? songs
            : songs
                .where(
                  (s) => '${s.prefix ?? ''}${s.number ?? ''} ${s.name} ${s.composer ?? ''}'.toLowerCase().contains(
                    _search,
                  ),
                )
                .toList();
    return RdPage(
      children: [
        Row(
          children: [
            Expanded(child: RdBackLink(label: l10n.commonCancel, onTap: () => Navigator.of(context).pop())),
            // The only action of the sheet (the step after it asks for the
            // Dirigent): "Weiter" at the top right like in the forms.
            Semantics(
              button: true,
              child: InkWell(
                key: const Key('rd-songs-picker-apply'),
                onTap: () => Navigator.of(context).pop(_selected),
                borderRadius: BorderRadius.circular(10),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Center(
                      widthFactor: 1,
                      child: Text(
                        l10n.commonNext,
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: p.link),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Semantics(header: true, child: Text(l10n.attListChooseSongs, style: RdType.title(p))),
        if (_selected.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            switch (_selected.length == 1 ? allSongs.where((s) => s.id == _selected.first).firstOrNull?.name : null) {
              final name? => l10n.rdTextWorksSelectedOne(name),
              null => l10n.rdTextWorksSelected(_selected.length),
            },
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: RdType.meta(p, size: 15),
          ),
        ],
        const SizedBox(height: 16),
        RdCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: TextField(
            key: const Key('rd-songs-picker-search'),
            style: TextStyle(fontSize: 17, color: p.text),
            decoration: rdInputDecoration(
              p,
              l10n.attListSearchSong,
            ).copyWith(prefixIcon: Icon(Icons.search, color: p.text2)),
            onChanged: (v) => setState(() => _search = v.trim().toLowerCase()),
          ),
        ),
        const SizedBox(height: 16),
        if ((songsAsync.isLoading && allSongs.isEmpty) || collectionsLoading)
          const Padding(padding: EdgeInsets.all(24), child: Center(child: AppSpinner()))
        else if (songsAsync.hasError && allSongs.isEmpty)
          RdInfoCard(text: l10n.attendanceFlutterErrorWith(friendlyErrorMessage(songsAsync.error!)))
        else if (filtered.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(l10n.attListNoSongsFound, textAlign: TextAlign.center, style: RdType.meta(p, size: 15)),
          )
        else
          RdGroupedList(
            children: [
              for (final song in filtered)
                RdListRow(
                  title: '${song.prefix ?? ''}${song.number ?? ''} ${song.name}'.trim(),
                  subtitle: switch ([
                    if (rdCollectionById(collections ?? const [], song.collectionId) case final c?) c.name,
                    if (song.composer?.isNotEmpty ?? false) song.composer!,
                  ]) {
                    final parts when parts.isNotEmpty => parts.join(' · '),
                    _ => null,
                  },
                  selected: song.id != null && _selected.contains(song.id),
                  trailing: RdSheetCheck(song.id != null && _selected.contains(song.id)),
                  showChevron: false,
                  onTap:
                      song.id == null
                          ? null
                          : () => setState(() {
                            if (!_selected.remove(song.id)) _selected.add(song.id!);
                          }),
                ),
            ],
          ),
        const SizedBox(height: 20),
      ],
    );
  }
}
