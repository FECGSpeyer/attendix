import 'package:flutter/material.dart';
import 'package:attendix/core/theme/app_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/conductor_providers.dart';
import '../../../../core/providers/song_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/redesign/rd_theme.dart';
import '../../../../data/models/person/person.dart';
import '../../../../data/models/song/song.dart';
import '../../../../l10n/l10n.dart';
import '../../../../core/utils/dialog_helper.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';
import '../../../../shared/widgets/dialogs/ion_sheet.dart';
import '../../../../shared/widgets/layout/ionic_ios.dart' as ion;
import '../../../planning/presentation/widgets/rd_plan_widgets.dart';
import '../../../redesign/data/rd_collections_logic.dart';
import '../../../redesign/presentation/widgets/event/rd_form_widgets.dart';
import '../../../redesign/presentation/widgets/rd_widgets.dart';
import '../../../redesign/presentation/widgets/today/rd_today_common.dart';

part 'songs_selection_sheet.freezed.dart';
part 'songs_selection_sheet.g.dart';
part 'songs_selection_sheet_beta.dart';

/// Entry representing a song-conductor pair to be saved with attendance
@freezed
class SongHistoryEntry with _$SongHistoryEntry {
  const factory SongHistoryEntry({
    required int songId,
    required String songName,
    int? conductorId,
    String? conductorName,
    String? otherConductor,
  }) = _SongHistoryEntry;

  factory SongHistoryEntry.fromJson(Map<String, dynamic> json) => _$SongHistoryEntryFromJson(json);
}

/// Extension for SongHistoryEntry
extension SongHistoryEntryExtension on SongHistoryEntry {
  /// Get display name for conductor
  String get displayConductor {
    if (otherConductor != null && otherConductor!.isNotEmpty) {
      return otherConductor!;
    }
    return conductorName ?? l10nWithoutContext.commonUnknown;
  }
}

/// Bottom sheet for selecting songs to add to attendance
class SongsSelectionSheet extends ConsumerStatefulWidget {
  final List<SongHistoryEntry> existingEntries;
  final ValueChanged<List<SongHistoryEntry>> onEntriesChanged;

  const SongsSelectionSheet({
    super.key,
    required this.existingEntries,
    required this.onEntriesChanged,
    this.scrollController,
  });

  /// Classic design: the controller of the breakpoint sheet.
  final ScrollController? scrollController;

  /// Show the bottom sheet and return updated entries
  static Future<List<SongHistoryEntry>?> show(
    BuildContext context, {
    required List<SongHistoryEntry> existingEntries,
  }) async {
    List<SongHistoryEntry>? result;

    if (context.rdSkin == null) {
      // TER-13: Ionic addHisModal – [breakpoints]="[0, 0.7]"
      // [initialBreakpoint]="0.7", toolbar with only the title,
      // `ion-content color="light"`.
      await showIonSheet<void>(
        context,
        breakpoints: const [0, 0.7],
        initialBreakpoint: 0.7,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        builder: (ctx, controller) => SongsSelectionSheet(
          existingEntries: existingEntries,
          scrollController: controller,
          onEntriesChanged: (entries) => result = entries,
        ),
      );
      return result;
    }

    await showModalBottomSheet(
      context: context,
      useRootNavigator: true, // IOS_SHELL2: above the tab bar
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      showDragHandle: context.rdSkin != null,
      backgroundColor: context.rdSkin != null ? context.rd.bg : null,
      builder:
          (context) => SongsSelectionSheet(
            existingEntries: existingEntries,
            onEntriesChanged: (entries) {
              result = entries;
            },
          ),
    );

    return result;
  }

  @override
  ConsumerState<SongsSelectionSheet> createState() => _SongsSelectionSheetState();
}

class _SongsSelectionSheetState extends ConsumerState<SongsSelectionSheet> {
  final Set<int> _selectedSongIds = {};
  int? _selectedConductorId;
  String? _otherConductorName;
  bool _useOtherConductor = false;

  /// Whether a name was saved in the „Dirigent eingeben“ alert. Controls the
  /// visibility of the name field independently of its current text.
  bool _otherConductorSaved = false;
  final _otherConductorController = TextEditingController();

  /// Beta: conductor of single Werke that differs from "Dirigent für alle".
  final Map<int, _RdConductor> _rdOverrides = {};

  /// Beta: Werk whose conductor chips are open.
  int? _rdExpandedSongId;

  @override
  void dispose() {
    _otherConductorController.dispose();
    super.dispose();
  }

  /// Ionic onConChange: alert „Dirigent eingeben“ (placeholder „Dirigent“,
  /// Abbrechen / Speichern). On cancel or an empty name the previous
  /// conductor selection is restored, so „Anderer Dirigent“ can be chosen
  /// again.
  Future<void> _askOtherConductor({
    required int? previousConductorId,
    required bool previousUseOther,
    required String? previousName,
    required bool previousSaved,
  }) async {
    final l10n = context.l10n;
    final String? raw;
    if (context.rdSkin != null) {
      raw = await showRdPlanTextSheet(context, title: l10n.attListEnterConductor, hint: l10n.attListConductor);
    } else {
      raw = await DialogHelper.showTextInput(
        context,
        title: l10n.attListEnterConductor,
        hint: l10n.attListConductor,
        confirmText: l10n.commonSave,
      );
    }
    final name = raw?.trim();
    if (!mounted || !_useOtherConductor) return;
    if (name == null || name.isEmpty) {
      setState(() {
        _useOtherConductor = previousUseOther;
        _selectedConductorId = previousConductorId;
        _otherConductorName = previousName;
        _otherConductorSaved = previousSaved;
        _otherConductorController.text = previousName ?? '';
      });
      return;
    }
    setState(() {
      _otherConductorName = name;
      _otherConductorSaved = true;
      _otherConductorController.text = name;
    });
  }

  @override
  void initState() {
    super.initState();
    // Pre-select first conductor if available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final conductors = ref.read(activeConductorsProvider).valueOrNull;
      if (conductors != null && conductors.isNotEmpty) {
        setState(() {
          _selectedConductorId = conductors.first.id;
        });
      }
      // Beta: straight into "Werke auswählen" (all Werke at once, the
      // conductor is set per Werk afterwards); cancelling closes the sheet.
      if (context.rdSkin != null) _rdOpenPickerFirst();
    });
  }

  void _update(VoidCallback fn) => setState(fn);

  void _onConductorChanged(int? v) {
    const otherValue = -1;
    if (v == otherValue) {
      final previousConductorId = _selectedConductorId;
      final previousUseOther = _useOtherConductor;
      final previousName = _otherConductorName;
      final previousSaved = _otherConductorSaved;
      setState(() {
        _useOtherConductor = true;
        _selectedConductorId = null;
      });
      _askOtherConductor(
        previousConductorId: previousConductorId,
        previousUseOther: previousUseOther,
        previousName: previousName,
        previousSaved: previousSaved,
      );
    } else {
      setState(() {
        _useOtherConductor = false;
        _otherConductorSaved = false;
        _selectedConductorId = v;
        _otherConductorName = null;
      });
    }
  }

  // UX_ATT: Ionic addHisModal: inset group with the "Werk(e)" picker row
  // (opens "Werke auswählen" with search) and the "Dirigent" select
  // (+ "Anderer Dirigent" input), then the primary "Werk(e) hinzufügen" row.
  /// TER-13: Ionic addHisModal content – one inset list: an item group with
  /// "Werk(e)" (detail chevron) and the "Dirigent" select (+ the name of the
  /// other conductor), then an item group with the primary "Werk(e)
  /// hinzufügen" item.
  Widget _buildClassic(BuildContext context) {
    final conductors = ref.watch(activeConductorsProvider).valueOrNull ?? const <Person>[];
    const otherValue = -1;
    final conductorValue = _useOtherConductor ? otherValue : _selectedConductorId;
    final canAdd = _canAdd();
    return IonSheetScaffold(
      title: context.l10n.attListAddSongs,
      body: ListView(
        controller: widget.scrollController,
        padding: EdgeInsets.only(top: 12, bottom: 16 + MediaQuery.paddingOf(context).bottom),
        children: [
          ion.IonInsetList(
            children: [
              ion.IonItem(
                title: Text(context.l10n.attListSongsLabel),
                subtitle: Text(
                  _selectedSongIds.isEmpty
                      ? context.l10n.attListNoSongsSelected
                      : context.l10n.attListSongsSelected(_selectedSongIds.length),
                ),
                detail: true,
                onTap: _openSongPicker,
              ),
              ion.IonItem(
                title: Text(context.l10n.attListConductor),
                trailing: Flexible(
                  child: DropdownButtonHideUnderline(
                    child: AppDropdownButton<int>(
                      interface: AppSelectInterface.alert,
                      header: context.l10n.attListConductor,
                      value: conductorValue,
                      hint: Text(context.l10n.attendanceChoose),
                      alignment: AlignmentDirectional.centerEnd,
                      items: [
                        for (final c in conductors)
                          if (c.id != null) DropdownMenuItem(value: c.id, child: Text(c.fullName)),
                        DropdownMenuItem(value: otherValue, child: Text(context.l10n.attListOtherConductor)),
                      ],
                      onChanged: _onConductorChanged,
                    ),
                  ),
                ),
              ),
              if (_useOtherConductor && _otherConductorSaved)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: TextField(
                    controller: _otherConductorController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                    ),
                    onChanged: (value) => setState(() => _otherConductorName = value),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          ion.IonInsetList(
            children: [
              ion.IonItem(
                title: Opacity(
                  opacity: canAdd ? 1 : 0.4,
                  child: Text(context.l10n.attListAddSongs),
                ),
                titleColor: AppColors.primary,
                onTap: canAdd ? _addSongs : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (context.rdSkin != null) return _rdBuild(context);
    if (widget.scrollController != null) return _buildClassic(context);
    final conductorsAsync = ref.watch(activeConductorsProvider);
    final conductors = conductorsAsync.valueOrNull ?? const <Person>[];
    const otherValue = -1;
    final conductorValue = _useOtherConductor ? otherValue : _selectedConductorId;

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
      color: Theme.of(context).brightness == Brightness.dark ? null : AppColors.light,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    context.l10n.attListAddSongs,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: Icon(AppIcons.close),
                  tooltip: context.l10n.commonClose,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppDimensions.paddingM),
              child: Column(
                children: [
                  Card(
                    margin: EdgeInsets.zero,
                    elevation: 0,
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        ListTile(
                          title: Text(context.l10n.attListSongsLabel),
                          subtitle: Text(
                            _selectedSongIds.isEmpty
                                ? context.l10n.attListNoSongsSelected
                                : context.l10n.attListSongsSelected(_selectedSongIds.length),
                          ),
                          trailing: Icon(AppIcons.chevronRight),
                          onTap: _openSongPicker,
                        ),
                        const Divider(height: 1, indent: 16),
                        ListTile(
                          title: Text(context.l10n.attListConductor),
                          trailing: DropdownButtonHideUnderline(
                            child: AppDropdownButton<int>(
                              interface: AppSelectInterface.alert,
                              value: conductorValue,
                              hint: Text(context.l10n.attendanceChoose),
                              alignment: AlignmentDirectional.centerEnd,
                              items: [
                                for (final c in conductors)
                                  if (c.id != null) DropdownMenuItem(value: c.id, child: Text(c.fullName)),
                                DropdownMenuItem(value: otherValue, child: Text(context.l10n.attListOtherConductor)),
                              ],
                              onChanged: _onConductorChanged,
                            ),
                          ),
                        ),
                        // Ionic: the field only shows the name saved in the
                        // „Dirigent eingeben“ alert; it stays visible while
                        // editing, even when the text becomes empty.
                        if (_useOtherConductor && _otherConductorSaved) ...[
                          const Divider(height: 1, indent: 16),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            child: TextField(
                              controller: _otherConductorController,
                              textCapitalization: TextCapitalization.words,
                              decoration: const InputDecoration(border: InputBorder.none),
                              onChanged: (value) => setState(() => _otherConductorName = value),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: AppDimensions.paddingM),
                  Card(
                    margin: EdgeInsets.zero,
                    elevation: 0,
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      enabled: _canAdd(),
                      title: Text(
                        context.l10n.attListAddSongs,
                        style: TextStyle(color: _canAdd() ? AppColors.primary : AppColors.medium),
                      ),
                      onTap: _canAdd() ? _addSongs : null,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Full-screen "Werke auswählen" with "Werk suchen..." (Ionic songSelectModal).
  /// Returns false when it was cancelled.
  Future<bool> _openSongPicker() async {
    final result = context.rdSkin == null
        // TER-14: Ionic default `ion-modal` – full screen on phones, the
        // centred card on tablet / desktop.
        ? await showIonCardModal<Set<int>>(
            context,
            builder: (ctx) => _SongPickerPage(initialSelection: _selectedSongIds),
          )
        : await Navigator.of(context, rootNavigator: true).push<Set<int>>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder:
            (ctx) =>
                ctx.rdSkin != null
                    ? _RdSongMultiPicker(initialSelection: _selectedSongIds)
                    : _SongPickerPage(initialSelection: _selectedSongIds),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _selectedSongIds
          ..clear()
          ..addAll(result);
        _rdOverrides.removeWhere((id, _) => !_selectedSongIds.contains(id));
        if (!_selectedSongIds.contains(_rdExpandedSongId)) _rdExpandedSongId = null;
      });
    }
    return result != null;
  }

  bool _canAdd() {
    if (_selectedSongIds.isEmpty) return false;
    if (context.rdSkin != null) {
      final conductors = ref.read(activeConductorsProvider).valueOrNull ?? const <Person>[];
      return _selectedSongIds.every((id) => _rdConductorFor(id, conductors) != null);
    }
    if (_useOtherConductor) {
      return _otherConductorName != null && _otherConductorName!.isNotEmpty;
    }
    return _selectedConductorId != null;
  }

  void _addSongs() {
    final songsAsync = ref.read(songsProvider);
    final conductorsAsync = ref.read(activeConductorsProvider);

    final songs = songsAsync.valueOrNull ?? [];
    final conductors = conductorsAsync.valueOrNull ?? [];

    // Create entries for each selected song
    final newEntries = <SongHistoryEntry>[];
    final beta = context.rdSkin != null;
    for (final songId in _selectedSongIds) {
      final song = songs.firstWhere((s) => s.id == songId, orElse: () => Song(name: context.l10n.commonUnknown));

      // Beta: conductor per Werk; classic: one conductor for all (Ionic).
      final choice =
          beta
              ? _rdConductorFor(songId, conductors)
              : (
                id: _useOtherConductor ? null : _selectedConductorId,
                other: _useOtherConductor ? _otherConductorName : null,
              );
      if (choice == null) continue;

      String? conductorName;
      if (choice.other == null && choice.id != null) {
        final conductor = conductors.firstWhere((c) => c.id == choice.id, orElse: () => const Person());
        conductorName = conductor.fullName;
      }

      newEntries.add(
        SongHistoryEntry(
          songId: songId,
          songName: song.displayName,
          conductorId: choice.other == null ? choice.id : null,
          conductorName: conductorName,
          otherConductor: choice.other,
        ),
      );
    }

    // Add to existing entries
    final allEntries = [...widget.existingEntries, ...newEntries];
    widget.onEntriesChanged(allEntries);

    Navigator.of(context).pop();
  }
}

/// UX_ATT: Ionic "Werke auswählen" modal with search and checkbox list.
class _SongPickerPage extends ConsumerStatefulWidget {
  const _SongPickerPage({required this.initialSelection});

  final Set<int> initialSelection;

  @override
  ConsumerState<_SongPickerPage> createState() => _SongPickerPageState();
}

class _SongPickerPageState extends ConsumerState<_SongPickerPage> {
  late final Set<int> _selected = {...widget.initialSelection};
  String _search = '';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggle(int id) => setState(() {
        if (!_selected.remove(id)) _selected.add(id);
      });

  /// TER-14: Ionic songSelectModal – toolbar with title + checkmark, a
  /// second toolbar with `ion-searchbar`, `ion-content color="light"` with
  /// an inset list of `ion-checkbox slot="start"` items.
  Widget _buildClassic(BuildContext context) {
    final songsAsync = ref.watch(songsProvider);
    final collectionsAsync = ref.watch(songCollectionsProvider);
    final collections = collectionsAsync.valueOrNull;
    final Widget body = songsAsync.when(
      loading: () => const Center(child: AppSpinner()),
      error: (e, _) => Center(child: Text(context.l10n.attendanceFlutterErrorWith(friendlyErrorMessage(e)))),
      data: (allSongs) {
        if (!collectionsAsync.hasValue && !collectionsAsync.hasError) {
          return const Center(child: AppSpinner());
        }
        final songs = collectionsAsync.hasValue ? rdPlannableWorks(allSongs, collections) : rdWorksIn(allSongs, null);
        final filtered = _search.isEmpty
            ? songs
            : songs
                .where((s) => '${s.prefix ?? ''}${s.number ?? ''} ${s.name}'.toLowerCase().contains(_search))
                .toList();
        final bottom = MediaQuery.paddingOf(context).bottom;
        if (filtered.isEmpty) {
          return ListView(
            padding: EdgeInsets.only(top: 12, bottom: bottom),
            children: [
              ion.IonInsetList(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      context.l10n.attListNoSongsFound,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.medium, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ],
          );
        }
        return ListView(
          padding: EdgeInsets.only(top: 12, bottom: 16 + bottom),
          children: [
            ion.IonInsetList(
              dividerIndent: 56,
              children: [
                for (final song in filtered)
                  ion.IonItem(
                    leading: Checkbox(
                      value: song.id != null && _selected.contains(song.id),
                      onChanged: song.id == null ? null : (_) => _toggle(song.id!),
                    ),
                    title: Text('${song.prefix ?? ''}${song.number ?? ''} ${song.name}'.trim()),
                    subtitle: (song.composer?.isNotEmpty ?? false) ? Text(song.composer!) : null,
                    onTap: song.id == null ? null : () => _toggle(song.id!),
                  ),
              ],
            ),
          ],
        );
      },
    );
    return IonSheetScaffold(
      title: context.l10n.attListChooseSongs,
      end: [
        IconButton(
          icon: Icon(AppIcons.check),
          tooltip: context.l10n.commonApply,
          onPressed: () => Navigator.of(context).pop(_selected),
        ),
      ],
      bottom: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: ion.IonSearchbar(
          controller: _searchController,
          hintText: context.l10n.attListSearchSong,
          onChanged: (v) => setState(() => _search = v.trim().toLowerCase()),
        ),
      ),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: body,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (context.rdSkin == null) return _buildClassic(context);
    final songsAsync = ref.watch(songsProvider);
    // Sammlungen (Beta): Werke of a Sammlung that is not "planbar" stay out
    // (while they load nothing is offered, after an error only the
    // Repertoire).
    final collectionsAsync = ref.watch(songCollectionsProvider);
    final collections = collectionsAsync.valueOrNull;
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.attListChooseSongs),
        actions: [
          IconButton(
            icon: Icon(AppIcons.check),
            tooltip: context.l10n.commonApply,
            onPressed: () => Navigator.of(context).pop(_selected),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: SearchBar(
              hintText: context.l10n.attListSearchSong,
              leading: Icon(AppIcons.search),
              elevation: const WidgetStatePropertyAll(0),
              onChanged: (v) => setState(() => _search = v.trim().toLowerCase()),
            ),
          ),
        ),
      ),
      body: songsAsync.when(
        loading: () => const Center(child: AppSpinner()),
        error: (e, _) => Center(child: Text(context.l10n.attendanceFlutterErrorWith(friendlyErrorMessage(e)))),
        data: (allSongs) {
          if (!collectionsAsync.hasValue && !collectionsAsync.hasError) {
            return const Center(child: AppSpinner());
          }
          final songs = collectionsAsync.hasValue ? rdPlannableWorks(allSongs, collections) : rdWorksIn(allSongs, null);
          final filtered =
              _search.isEmpty
                  ? songs
                  : songs
                      .where((s) => '${s.prefix ?? ''}${s.number ?? ''} ${s.name}'.toLowerCase().contains(_search))
                      .toList();
          if (filtered.isEmpty) {
            return Center(
              child: Text(context.l10n.attListNoSongsFound, style: const TextStyle(color: AppColors.medium)),
            );
          }
          return ListView.builder(
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final song = filtered[index];
              final id = song.id;
              return CheckboxListTile(
                value: id != null && _selected.contains(id),
                controlAffinity: ListTileControlAffinity.leading,
                title: Text('${song.prefix ?? ''}${song.number ?? ''} ${song.name}'.trim()),
                subtitle: switch ([
                  if (rdCollectionById(collections ?? const [], song.collectionId) case final c?) c.name,
                  if (song.composer?.isNotEmpty ?? false) song.composer!,
                ]) {
                  final parts when parts.isNotEmpty => Text(parts.join(' · ')),
                  _ => null,
                },
                onChanged:
                    id == null
                        ? null
                        : (v) => setState(() {
                          if (v == true) {
                            _selected.add(id);
                          } else {
                            _selected.remove(id);
                          }
                        }),
              );
            },
          );
        },
      ),
    );
  }
}

/// Widget to display selected songs in a list
class SelectedSongsList extends StatelessWidget {
  final List<SongHistoryEntry> entries;
  final ValueChanged<List<SongHistoryEntry>>? onEntriesChanged;
  final bool readOnly;

  const SelectedSongsList({super.key, required this.entries, this.onEntriesChanged, this.readOnly = false});

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return Padding(padding: const EdgeInsets.all(16), child: Text(context.l10n.attListNoSongsSelected));
    }

    return Column(
      children:
          entries.asMap().entries.map((entry) {
            final index = entry.key;
            final songEntry = entry.value;

            return ListTile(
              title: Text(songEntry.songName),
              subtitle: Text(songEntry.displayConductor),
              trailing:
                  readOnly
                      ? null
                      : IconButton(
                        icon: Icon(AppIcons.close, semanticLabel: context.l10n.commonClose),
                        onPressed: () {
                          final newEntries = List<SongHistoryEntry>.from(entries);
                          newEntries.removeAt(index);
                          onEntriesChanged?.call(newEntries);
                        },
                      ),
              // TER-15: theme item size in the classic design.
              dense: context.rdSkin != null,
            );
          }).toList(),
    );
  }
}
