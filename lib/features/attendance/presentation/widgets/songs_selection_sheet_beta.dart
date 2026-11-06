part of 'songs_selection_sheet.dart';

/// Beta (redesign) layout of "Werk(e) hinzufügen": Werke row, conductor
/// chips and the primary button.
extension _RdSongsSelection on _SongsSelectionSheetState {
  Widget _rdBuild(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    const otherValue = -1;
    final conductors = ref.watch(activeConductorsProvider).valueOrNull ?? const <Person>[];
    final current = _useOtherConductor ? otherValue : _selectedConductorId;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.8),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          children: [
            Semantics(header: true, child: Text(l10n.attListAddSongs, style: RdType.cardTitle(p))),
            const SizedBox(height: 16),
            RdGroupedList(
              children: [
                RdListRow(
                  key: const Key('rd-songs-pick'),
                  leading: const RdRowIcon(Icons.music_note_outlined),
                  title: l10n.attListSongsLabel,
                  value:
                      _selectedSongIds.isEmpty
                          ? l10n.attListNoSongsSelected
                          : l10n.attListSongsSelected(_selectedSongIds.length),
                  onTap: _openSongPicker,
                ),
              ],
            ),
            const SizedBox(height: 20),
            RdGroupLabel(l10n.attListConductor),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in conductors)
                  if (c.id != null)
                    RdChoiceChip(label: c.fullName, selected: current == c.id, onTap: () => _onConductorChanged(c.id)),
                RdChoiceChip(
                  label: l10n.attListOtherConductor,
                  selected: current == otherValue,
                  onTap: () => _onConductorChanged(otherValue),
                ),
              ],
            ),
            if (_useOtherConductor && _otherConductorSaved) ...[
              const SizedBox(height: 12),
              RdCard(
                padding: EdgeInsets.zero,
                child: RdFieldRow(
                  label: l10n.attListConductor,
                  child: TextField(
                    controller: _otherConductorController,
                    textCapitalization: TextCapitalization.words,
                    style: TextStyle(fontSize: 17, color: p.text),
                    decoration: rdInputDecoration(p, l10n.attListConductor),
                    onChanged: (value) => _update(() => _otherConductorName = value),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            RdPrimaryButton(
              key: const Key('rd-songs-add'),
              label: l10n.attListAddSongs,
              onPressed: _canAdd() ? _addSongs : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// Beta "Werke auswählen": search plus a multi-select list, "Übernehmen" at the end.
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
    final songs = songsAsync.valueOrNull ?? const <Song>[];
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
            RdCircleButton(
              key: const Key('rd-songs-picker-apply'),
              icon: Icons.check,
              label: l10n.commonApply,
              onPressed: () => Navigator.of(context).pop(_selected),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Semantics(header: true, child: Text(l10n.attListChooseSongs, style: RdType.title(p))),
        if (_selected.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(l10n.attListSongsSelected(_selected.length), style: RdType.meta(p, size: 15)),
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
        if (songsAsync.isLoading && songs.isEmpty)
          const Padding(padding: EdgeInsets.all(24), child: Center(child: AppSpinner()))
        else if (songsAsync.hasError && songs.isEmpty)
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
                  subtitle: (song.composer?.isNotEmpty ?? false) ? song.composer : null,
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
        RdPrimaryButton(label: l10n.commonApply, onPressed: () => Navigator.of(context).pop(_selected)),
      ],
    );
  }
}
