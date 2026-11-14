import 'dart:convert';
import 'dart:io' show Platform;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:attendix/core/theme/app_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/services/native/native_file_service.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/organisation_providers.dart';
import '../../../../core/providers/song_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/services/audio_player/audio_player_service.dart';
import '../../../../core/services/song_file_service.dart';
import '../../../../core/services/telegram_service.dart';
import '../../../../core/services/zip_service.dart';
import '../../../../core/services/zip_service_stub.dart'
    if (dart.library.io) '../../../../core/services/zip_service_io.dart'
    if (dart.library.js_interop) '../../../../core/services/zip_service_web.dart'
    as file_saver;
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/choir_file_utils.dart';
import '../../../../core/utils/dialog_helper.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/instrument/instrument.dart';
import '../../../../data/models/song/song.dart';
import '../../../../data/models/song/song_additional_field.dart';
import '../../../../data/models/tenant/tenant.dart';
import '../../../../shared/widgets/audio_player/audio_player_widget.dart';
import '../../../../shared/widgets/layout/ionic_ios.dart';
import '../../data/song_print_service.dart';
import '../utils/song_utils.dart';
import '../widgets/copy_to_tenant_sheet.dart';
import '../widgets/file_drop/file_drop_target.dart';
import '../widgets/file_upload_sheet.dart';
import '../widgets/group_pdf_print.dart';
import '../widgets/single_file_upload_sheet.dart';
import '../widgets/song_beamer_file_section.dart';
import '../widgets/song_file_opener.dart';
import '../../../../core/services/tracking/tracking_event.dart';
import '../../../../core/services/tracking/tracking_service.dart';
import '../../../../l10n/l10n.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../shared/widgets/common/error_state_view.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';
import 'package:attendix/shared/widgets/layout/ios_tab_bar.dart';
import '../../../../core/theme/redesign/rd_theme.dart' show RdSkinContext;
import '../../../../core/router/redesign_routes.dart';
import '../../../settings/presentation/widgets/settings_sheet.dart'
    show settingsSheetBar, showSettingsSheet;

/// Song detail page (Ionic `songs/song`): inline editing for admins and
/// responsibles, read-only view for everybody else and for the public share
/// link `/<song_sharing_id>/<songId>` ([songSharingId] set, no login needed).
class SongDetailPage extends ConsumerStatefulWidget {
  final String songId;
  final String? songSharingId;

  const SongDetailPage({super.key, required this.songId, this.songSharingId});

  @override
  ConsumerState<SongDetailPage> createState() => _SongDetailPageState();
}

class _SongDetailPageState extends ConsumerState<SongDetailPage> {
  final _prefix = TextEditingController();
  final _number = TextEditingController();
  final _name = TextEditingController();
  final _link = TextEditingController();
  final Map<String, TextEditingController> _fieldControllers = {};

  int? _initializedFor;
  bool _withChoir = false;
  bool _withSolo = false;
  int? _difficulty;
  List<int> _instrumentIds = [];
  List<String> _categoryIds = [];
  Map<String, dynamic> _additional = {};
  /// Saves queued or running. Ionic saves on every ionBlur/ionChange; here
  /// every change is queued and written in order, so a change made while a
  /// save is running is not lost and an older save never lands last.
  int _saving = 0;
  Future<void> _saveQueue = Future.value();

  /// Form values of the last queued save (or as loaded): text typed last is
  /// still saved when the page closes without a focus change.
  String? _lastQueued;
  SongNotifier? _notifier;
  bool _disposed = false;

  /// Files the form was last synced with (url + group per file).
  String? _filesKey;

  /// Latest loaded data; a queued save uses it instead of an older copy.
  SongDetailData? _data;

  /// Files state at "Alle löschen": until the reload shows the empty list,
  /// the deleted files must not add their groups back to the Besetzung.
  String? _clearedFilesKey;

  /// Instance the form was loaded for and the container to check it in a
  /// queued save (also after dispose, where `ref` is gone).
  int? _tenantId;
  ProviderContainer? _container;

  int? get _songId => int.tryParse(widget.songId);

  SongDetailParams get _params =>
      (songId: _songId ?? 0, sharingId: widget.songSharingId);

  @override
  void initState() {
    super.initState();
    // Ionic ngOnInit loads the Werk and its Werkhistorie on every open, so
    // changes from other people / devices or the Termin page show up.
    final id = _songId;
    _container = ProviderScope.containerOf(context, listen: false);
    // Invalidated before the first build, so the form starts with fresh data
    // (`ref` cannot be used in initState).
    if (id != null && widget.songSharingId == null) {
      _container!
        ..invalidate(songByIdProvider(id))
        ..invalidate(songHistoryProvider(id));
    }
  }

  @override
  void dispose() {
    _disposed = true;
    final data = _data;
    if (data != null && !data.readOnly && _snapshot(_formValues(data)) != _lastQueued) {
      _update(data);
    }
    _prefix.dispose();
    _number.dispose();
    _name.dispose();
    _link.dispose();
    for (final c in _fieldControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  static String _filesKeyOf(Song song) => [
        for (final f in song.files ?? const <SongFile>[]) '${f.url}|${f.instrumentId}',
      ].join(',');

  void _init(SongDetailData data) {
    final song = data.song;
    _data = data;
    final filesKey = _filesKeyOf(song);
    if (_initializedFor == song.id) {
      // Ionic reloads the Werk after upload, file delete, delete all and
      // category change (syncInstrumentIdsFromFiles): the Besetzung shows the
      // instrument_ids the file service wrote, so the next save does not
      // write the old selection back.
      // After "Alle löschen" a reload of an older save may still carry the
      // old instrument_ids: the emptied Besetzung stays until a reload
      // (whatever its files) confirms the empty list.
      if (_clearedFilesKey != null && (song.instrumentIds?.isEmpty ?? true)) {
        _clearedFilesKey = null;
      }
      if (filesKey != _filesKey) {
        _filesKey = filesKey;
        final cleared = _clearedFilesKey != null;
        _instrumentIds = {
          ...(cleared ? _instrumentIds : song.instrumentIds ?? const <int>[]),
          ..._idsFromFiles(data),
        }.toList();
      }
      return;
    }
    _initializedFor = song.id;
    _filesKey = filesKey;
    _notifier = ref.read(songNotifierProvider.notifier);
    _tenantId = ref.read(currentTenantIdProvider);
    _prefix.text = song.prefix ?? '';
    _number.text = song.number?.toString() ?? '';
    _name.text = song.name;
    _link.text = song.link ?? '';
    _withChoir = song.withChoir;
    _withSolo = song.withSolo;
    _difficulty = song.difficulty;
    _instrumentIds = {...?song.instrumentIds, ..._idsFromFiles(data)}.toList();
    _categoryIds = [...?song.categoryIds];
    _additional = {...?song.additionalFields};
    for (final field in data.additionalFields) {
      if (_additional[field.id] == null) {
        _additional[field.id] = field.effectiveDefault;
      }
      if (!field.isBoolean && !field.isSelect) {
        _fieldControllers[field.id] =
            TextEditingController(text: _additional[field.id]?.toString() ?? '');
      }
    }
    _lastQueued = _snapshot(_formValues(data));
  }

  /// Ionic `instrumentIdsFromFiles`: groups that have files, without
  /// Aufnahme (1), Liedtext (2) and the main group (as the file service).
  List<int> _idsFromFiles(SongDetailData data) =>
      _clearedFilesKey == _filesKeyOf(data.song)
          ? const []
          : SongFileService.instrumentIdsFromFiles(
        [
          for (final f in data.song.files ?? const <SongFile>[])
            {'instrumentId': f.instrumentId},
        ],
        mainGroupId: data.mainGroupId,
        excludeLyrics: true,
      );

  /// Queues a write behind all saves queued before it.
  Future<Song?> _enqueue(
    SongNotifier notifier,
    int id,
    Map<String, dynamic> values,
  ) {
    final tenantId = _tenantId;
    final container = _container;
    final run = _saveQueue.then((_) {
      // Instance switched meanwhile: the save would run against the new
      // instance; drop it (counts as failed).
      if (container != null && container.read(currentTenantIdProvider) != tenantId) {
        return Future<Song?>.value();
      }
      return notifier.updateSong(id, values);
    });
    _saveQueue = run.then((_) {}, onError: (_) {});
    return run;
  }

  /// "Alle löschen": empties the Besetzung through the save queue, so it
  /// lands after a running save and is not overwritten by it.
  Future<void> _clearInstrumentIds() async {
    final data = _data;
    final id = data?.song.id;
    final notifier = _notifier;
    if (data == null || id == null || notifier == null) return;
    final values = _formValues(data);
    final before = _lastQueued;
    // Nothing else pending: the form as saved now has an empty Besetzung,
    // so closing the page does not save again.
    final pending = _snapshot(values) != before;
    _instrumentIds = [];
    _clearedFilesKey = _filesKeyOf(data.song);
    values['instrument_ids'] = <int>[];
    final result = await _enqueue(notifier, id, {'instrument_ids': <int>[]});
    if (result != null && !pending && _lastQueued == before) {
      _lastQueued = _snapshot(values);
    }
  }

  /// Ionic `update()`: save the whole form. Saves run one after another in
  /// the order of the changes.
  Future<void> _update(SongDetailData built) async {
    final data = _data ?? built;
    final id = data.song.id;
    final notifier = _notifier;
    if (data.readOnly || id == null || notifier == null) return;
    final values = _formValues(data);
    final snapshot = _snapshot(values);
    _lastQueued = snapshot;
    if (!_disposed) setState(() => _saving++);
    final run = _enqueue(notifier, id, values);
    Song? result;
    try {
      result = await run;
    } catch (_) {
      result = null;
    }
    // A failed save counts as not saved: closing the page tries again.
    if (result == null && _lastQueued == snapshot) _lastQueued = null;
    if (!mounted || _disposed) return;
    setState(() => _saving--);
    if (result == null) {
      ToastHelper.showError(context, context.l10n.extraFieldsSaveFailed);
    }
  }

  /// Comparable form state; a state that cannot be encoded never equals
  /// another one, so it is always saved.
  static String _snapshot(Map<String, dynamic> values) {
    try {
      return jsonEncode(values);
    } catch (_) {
      return '!${identityHashCode(values)}';
    }
  }

  /// The whole form as written by Ionic `editSong`.
  Map<String, dynamic> _formValues(SongDetailData data) {
    final merged = {..._instrumentIds, ..._idsFromFiles(data)}.toList();
    _instrumentIds = merged;
    for (final field in data.additionalFields) {
      final c = _fieldControllers[field.id];
      if (c == null) continue;
      _additional[field.id] = field.isNumber ? num.tryParse(c.text) ?? 0 : c.text;
    }
    return {
      'prefix': _prefix.text.trim(),
      'number': int.tryParse(_number.text.trim()),
      'name': _name.text.trim(),
      'link': _link.text.trim().isEmpty ? null : _link.text.trim(),
      'difficulty': _difficulty,
      'withChoir': _withChoir,
      'withSolo': _withSolo,
      'instrument_ids': merged,
      'category_ids': [..._categoryIds],
      'additional_fields': {..._additional},
    };
  }

  void _refresh() {
    ref.invalidate(songDetailDataProvider(_params));
    if (widget.songSharingId == null && _songId != null) {
      ref.invalidate(songByIdProvider(_songId!));
      ref.invalidate(songsProvider);
    }
  }

  void _copyShareLink(String sharingId, int songId) {
    Clipboard.setData(ClipboardData(text: SongUtils.shareLink(sharingId, songId)));
    ref.read(trackingServiceProvider).track(TrackingEvent.songShared);
    ToastHelper.showSuccess(context, context.l10n.songsLinkCopied);
  }

  Future<void> _confirmDelete(SongDetailData data) async {
    List<String> names;
    try {
      names = await ref.read(songSyncedTenantNamesProvider.future);
    } catch (_) {
      names = const [];
    }
    if (!mounted) return;
    final confirmed = await DialogHelper.showConfirmation(
      context,
      title: context.l10n.songsDeleteSong,
      message: names.isNotEmpty
          ? context.l10n.songsDeleteSyncedMessage(names.join(', '))
          : context.l10n.songsDeleteConfirm,
      confirmText: context.l10n.commonDelete,
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;
    final ok = await ref.read(songNotifierProvider.notifier).deleteSong(data.song.id!);
    if (!mounted) return;
    if (ok) {
      // Beta: back to the Werke of the new design, not the old list.
      context.go(context.rdSkin != null ? RedesignRoutes.works : '/settings/songs');
    } else {
      ToastHelper.showError(context, context.l10n.songsFlutterDeleteFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final publicId = widget.songSharingId;
    if (publicId != null && !SongUtils.isValidSharingId(publicId)) {
      // No UUID: no such public link, without a database round trip (its
      // error would be shown raw).
      return Scaffold(
        appBar: AppBar(
          title: Text(context.l10n.songsFlutterSong),
          leading: BackButton(
            onPressed: () => context.canPop() ? context.pop() : context.go('/login'),
          ),
        ),
        body: ErrorStateView(
          icon: AppIcons.linkOff,
          message: context.l10n.songsInvalidShareLink,
        ),
      );
    }
    if (_songId == null) {
      return Scaffold(
        appBar: AppBar(title: Text(context.l10n.songsFlutterSong)),
        body: Center(child: Text(context.l10n.songsFlutterInvalidId)),
      );
    }
    final dataAsync = ref.watch(songDetailDataProvider(_params));
    // Is the same Werk still open below in the stack, the provider keeps the
    // old value while it reloads after initState: the form starts only with
    // the fresh data (spinner until then, as on a first open).
    final data = _initializedFor == null && dataAsync.isLoading
        ? null
        : dataAsync.valueOrNull;

    if (data == null) {
      final sharingId = widget.songSharingId;
      return Scaffold(
        appBar: AppBar(
          title: Text(context.l10n.songsFlutterSong),
          // Ionic: back button with defaultHref = the share link's list.
          leading: sharingId != null
              ? BackButton(
                  onPressed: () => context.canPop()
                      ? context.pop()
                      : context.go('/$sharingId'),
                )
              : null,
        ),
        body: dataAsync.isLoading
            ? const Center(child: AppSpinner())
            : dataAsync.hasError
                ? ErrorStateView(
                    error: dataAsync.error,
                    onRetry: () => ref.invalidate(songDetailDataProvider(_params)),
                  )
                : ErrorStateView(
                    icon: AppIcons.linkOff,
                    message: widget.songSharingId != null
                        ? context.l10n.songsInvalidShareLink
                        : context.l10n.songsFlutterNotFound,
                  ),
      );
    }

    _init(data);
    final song = data.song;
    final sharingId = data.songSharingId;
    final aufnahme = song.files
        ?.where((f) => f.instrumentId == 1 && SongUtils.isAudio(f))
        .firstOrNull;

    final title = data.readOnly
        ? '${song.number ?? ''} ${song.name}'.trim()
        : context.l10n.songsEditSong;
    // UX_SONGS_SELF: Ionic `ion-header collapse="condense"` (large title on iOS)
    return CondenseHeader(
      builder: (context, condensed) => Scaffold(
      // IOS_R6: Ionic `ion-content fullscreen` under the translucent header
      extendBodyBehindAppBar: isIosLook(context),
      // IOS_R6: `ion-header [translucent]` (blur once condensed)
      appBar: IonTranslucentAppBar(
        condensed: condensed,
        child: AppBar(
        title: CondenseTitle(condensed: condensed, child: Text(title)),
        // IOS_FORMS2: iOS → the end ion-buttons share one glass capsule
        actions: [
          if ((sharingId != null && sharingId.isNotEmpty) || !data.readOnly)
            ToolbarButtonGroup(children: [
              if (sharingId != null && sharingId.isNotEmpty)
                IconButton(
                  tooltip: context.l10n.songsCopyLink,
                  icon: Icon(AppIcons.link),
                  onPressed: () => _copyShareLink(sharingId, song.id!),
                ),
              if (!data.readOnly)
                IconButton(
                  tooltip: context.l10n.songsDeleteSong,
                  icon: Icon(AppIcons.deleteOutline),
                  onPressed: () => _confirmDelete(data),
                ),
            ]),
        ],
      ),
      ),
      floatingActionButton: TabBarFab.wrap(aufnahme == null
          ? null
          : FloatingActionButton(
              tooltip: context.l10n.songsPlayRecording,
              onPressed: () => ref
                  .read(audioPlayerServiceProvider.notifier)
                  .playFromUrl(aufnahme.url, aufnahme.fileName, song.name),
              child: Icon(AppIcons.playArrow),
            )),
      bottomNavigationBar: data.isPublic ? const AudioPlayerWidget() : null,
      body: IonRefresher(
        onRefresh: () async {
          _refresh();
          await ref.read(songDetailDataProvider(_params).future);
        },
        // Ionic: one `ion-list inset` with item groups and list headers.
        child: ListView(
          padding: EdgeInsets.fromLTRB(0, AppDimensions.paddingS, 0, scrollEndPadding(context, base: 16, fabRoom: 80)),
          children: [
            const IonContentTopInset(),
            IonLargeTitle(title),
            if (_saving > 0) const LinearProgressIndicator(minHeight: 2),
            if (!data.readOnly) _buildEditForm(data),
            if (data.readOnly && (song.categoryIds?.isNotEmpty ?? false)) ...[
              IonListHeader(context.l10n.songsCategories),
              IonInsetList(children: [
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      for (final id in song.categoryIds!)
                        _IonChip(
                          label: data.categories.where((c) => c.id == id).firstOrNull?.name ??
                              context.l10n.songsUnknownCategory,
                          color: AppColors.secondary,
                        ),
                    ],
                  ),
                ),
              ]),
            ],
            if (data.readOnly &&
                (song.withChoir ||
                    song.withSolo ||
                    (data.isOrchestra && (song.instrumentIds?.isNotEmpty ?? false))))
              _buildReadOnlyInstrumentation(data),
            // Ionic: only with the logged-in tenant's fields, never on the
            // public share page (values are not public).
            if (data.additionalFields.isNotEmpty && !data.isPublic)
              _buildAdditionalFields(data),
            if (data.history.isNotEmpty) _buildHistory(data),
            _FilesSection(
              data: data,
              onChanged: _refresh,
              onClearInstrumentIds: _clearInstrumentIds,
            ),
            // Ionic 4.17.10: SongBeamer-Datei (Gemeinde App)
            if (!data.isPublic) SongBeamerFileSection(song: song),
            const SizedBox(height: AppDimensions.paddingM),
            if (data.readOnly && (song.link?.isNotEmpty ?? false))
              IonInsetList(children: [
                IonItem(
                  title: Text(context.l10n.songsOpenExternalLink),
                  titleColor: AppColors.primary,
                  detail: true,
                  // Ionic 4.17.18 openLink: web → Utils.openInNewTab.
                  onTap: () =>
                      NativeFileService.openLinkInApp(Uri.parse(song.link!)),
                ),
              ]),
            if (!data.readOnly)
              IonInsetList(children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Focus(
                    onFocusChange: (has) {
                      if (!has) _update(data);
                    },
                    child: TextField(
                      controller: _link,
                      minLines: 1,
                      maxLines: 5,
                      keyboardType: TextInputType.url,
                      decoration: ionInputDecoration(context, label: context.l10n.songsLink),
                    ),
                  ),
                ),
              ]),
            // Ionic 4.17.13: origin of a Werk copied from another instance
            if (!data.readOnly && song.copiedFrom != null)
              _SongOrigin(origin: song.copiedFrom!),
            if (!data.isPublic) _CopyToOtherInstance(song: song),
          ],
        ),
      ),
      ),
    );
  }

  Widget _blurSaver(SongDetailData data, Widget child) => Focus(
        onFocusChange: (has) {
          if (!has) _update(data);
        },
        child: child,
      );

  Widget _buildEditForm(SongDetailData data) {
    final fileIds = _idsFromFiles(data);
    return IonInsetList(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _blurSaver(
              data,
              TextField(
                controller: _prefix,
                textCapitalization: TextCapitalization.sentences,
                decoration: ionInputDecoration(
                  context,
                  label: context.l10n.songsPrefixOptional,
                  helperText: context.l10n.songsPrefixHelper,
                ),
              ),
            ),
            const SizedBox(height: AppDimensions.paddingS),
            _blurSaver(
              data,
              TextField(
                controller: _number,
                keyboardType: TextInputType.number,
                decoration: ionInputDecoration(context, label: context.l10n.songsNumber),
              ),
            ),
            const SizedBox(height: AppDimensions.paddingS),
            _blurSaver(
              data,
              TextField(
                controller: _name,
                textCapitalization: TextCapitalization.sentences,
                decoration: ionInputDecoration(context, label: context.l10n.songsName),
              ),
            ),
            // IOS_PAGES3: Ionic `ion-select [label]` (popover): label at
            // the start, value + toggle icon at the end, item line below.
            _InlineSelect<int?>(
              label: context.l10n.songsDifficulty,
              value: _difficulty,
              items: [
                DropdownMenuItem(value: null, child: Text(context.l10n.songsNotDefined)),
                DropdownMenuItem(value: 1, child: Text(context.l10n.songsEasy)),
                DropdownMenuItem(value: 2, child: Text(context.l10n.songsMedium)),
                DropdownMenuItem(value: 3, child: Text(context.l10n.songsHard)),
              ],
              onChanged: (v) {
                setState(() => _difficulty = v);
                _update(data);
              },
            ),
            const Divider(height: 0.5, thickness: 0.5),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: Text(context.l10n.songsChoirOrchestra),
              value: _withChoir,
              onChanged: (v) {
                setState(() => _withChoir = v);
                _update(data);
              },
            ),
            const Divider(height: 0.5, thickness: 0.5),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: Text(context.l10n.songsWithSoloSinging),
              value: _withSolo,
              onChanged: (v) {
                setState(() => _withSolo = v);
                _update(data);
              },
            ),
            const Divider(height: 0.5, thickness: 0.5),
            if (data.isOrchestra) ...[
              _MultiSelectTile<int>(
                title: context.l10n.songsInstrumentation,
                options: [
                  for (final g in data.instruments)
                    if (g.id != null) (g.id!, g.name, fileIds.contains(g.id)),
                ],
                selected: _instrumentIds,
                onChanged: (v) {
                  setState(() => _instrumentIds = v);
                  _update(data);
                },
              ),
              const Divider(height: 0.5, thickness: 0.5),
            ],
            _MultiSelectTile<String>(
              title: context.l10n.songsCategories,
              options: [
                for (final c in data.categories)
                  if (c.id != null) (c.id!, c.name, false),
              ],
              selected: _categoryIds,
              onChanged: (v) {
                setState(() => _categoryIds = v);
                _update(data);
              },
            ),
          ],
        ),
      ),
    ]);
  }

  Widget _buildReadOnlyInstrumentation(SongDetailData data) {
    final song = data.song;
    // Ionic: list header + item group with ion-chips (primary; groups in
    // success / danger).
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        IonListHeader(context.l10n.songsInstrumentation),
        IonInsetList(children: [
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (song.withChoir || song.withSolo)
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      if (song.withChoir)
                        _IonChip(label: context.l10n.songsChoirOrchestra, color: AppColors.primary),
                      if (song.withSolo)
                        _IonChip(label: context.l10n.songsWithSoloSinging, color: AppColors.primary),
                    ],
                  ),
                if (data.isOrchestra && (song.instrumentIds?.isNotEmpty ?? false))
                  Padding(
                    padding: EdgeInsets.only(top: song.withChoir || song.withSolo ? 4 : 0),
                    child: Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        for (final g in data.instruments)
                          _IonChip(
                            label: g.name,
                            color: song.instrumentIds!.contains(g.id)
                                ? AppColors.success
                                : AppColors.danger,
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ]),
      ],
    );
  }

  Widget _buildAdditionalFields(SongDetailData data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        IonListHeader(context.l10n.peopleExtraFields),
        IonInsetList(children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingM),
            child: Column(
              children: [
                // IOS_PAGES3: one ion-item per field, item lines between
                for (var i = 0; i < data.additionalFields.length; i++) ...[
                  if (i > 0 &&
                      (data.additionalFields[i - 1].isBoolean ||
                          data.additionalFields[i - 1].isSelect))
                    const Divider(height: 0.5, thickness: 0.5),
                  _buildField(data, data.additionalFields[i]),
                ],
              ],
            ),
          ),
        ]),
      ],
    );
  }

  Widget _buildField(SongDetailData data, SongAdditionalField field) {
    final value = _additional[field.id];
    if (field.isBoolean) {
      return SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        title: Text(field.name),
        value: value == true,
        onChanged: data.readOnly
            ? null
            : (v) {
                setState(() => _additional[field.id] = v);
                _update(data);
              },
      );
    }
    if (field.isSelect) {
      final current = field.options.contains(value) ? value as String : null;
      // IOS_PAGES3: Ionic `ion-select interface="popover" [label]`
      return _InlineSelect<String>(
        label: field.name,
        value: current,
        items: [
          for (final o in field.options) DropdownMenuItem(value: o, child: Text(o)),
        ],
        onChanged: data.readOnly
            ? null
            : (v) {
                setState(() => _additional[field.id] = v);
                _update(data);
              },
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: _blurSaver(
        data,
        TextField(
          controller: _fieldControllers[field.id],
          readOnly: data.readOnly,
          keyboardType: field.isNumber ? TextInputType.number : TextInputType.text,
          decoration: ionInputDecoration(context, label: field.name),
        ),
      ),
    );
  }

  Widget _buildHistory(SongDetailData data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        IonListHeader(context.l10n.songsHistoryCount(data.history.length)),
        // Ionic: h3 date · title (14px), p conductor (grey)
        IonInsetList(
          children: [
            for (final entry in data.history)
              IonItem(
                title: Text(
                  '${SongUtils.formatDate(entry.attendanceDate ?? entry.date)}'
                  '${(entry.typeTitle?.isNotEmpty ?? false) ? ' · ${entry.typeTitle}' : ''}',
                  style: const TextStyle(fontSize: 14),
                ),
                subtitle: (entry.conductorName?.isNotEmpty ?? false)
                    ? Text(entry.conductorName!)
                    : null,
              ),
          ],
        ),
      ],
    );
  }
}

/// Ionic `ion-chip [color]`: tinted pill (iOS 32px high, radius 16).
class _IonChip extends StatelessWidget {
  const _IonChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 14)),
    );
  }
}

/// IOS_PAGES3: Ionic `ion-select [label]` inside an `ion-item`: label at
/// the start, the selected value (medium) with the toggle icon at the end.
class _InlineSelect<T> extends StatelessWidget {
  const _InlineSelect({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: isIosLook(context) ? 52 : 48),
      child: Row(
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(width: 16),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: AppDropdownButton<T>(
                value: value,
                isExpanded: true,
                alignment: AlignmentDirectional.centerEnd,
                items: items,
                selectedItemBuilder: (context) => [
                  for (final it in items)
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: DefaultTextStyle.merge(
                        style: const TextStyle(color: AppColors.medium),
                        overflow: TextOverflow.ellipsis,
                        child: it.child,
                      ),
                    ),
                ],
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Multi select (Ionic `ion-select multiple interface="modal"`).
/// Options: (value, label, disabled).
class _MultiSelectTile<T> extends StatelessWidget {
  const _MultiSelectTile({
    required this.title,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final String title;
  final List<(T, String, bool)> options;
  final List<T> selected;
  final ValueChanged<List<T>> onChanged;

  Future<void> _open(BuildContext context) async {
    final selection = [...selected];
    final result = await showAppDialog<List<T>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AppAlertDialog(
          title: Text(title),
          // Ionic alert with `type: 'checkbox'` inputs (`ion-select multiple`).
          content: AppAlertCheckboxGroup<T>(
            options: [
              for (final o in options) AppAlertOption(o.$1, o.$2, enabled: !o.$3),
            ],
            values: selection.toSet(),
            onChanged: (v, checked) => setLocal(() {
              checked ? selection.add(v) : selection.remove(v);
            }),
            beta: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final o in options)
                  CheckboxListTile(
                    title: Text(o.$2),
                    value: selection.contains(o.$1),
                    onChanged: o.$3
                        ? null
                        : (v) => setLocal(() {
                              v == true ? selection.add(o.$1) : selection.remove(o.$1);
                            }),
                  ),
              ],
            ),
          ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(context.l10n.commonCancel),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, selection),
              child: Text(context.l10n.commonOk),
            ),
          ],
        ),
      ),
    );
    if (result != null) onChanged(result);
  }

  @override
  Widget build(BuildContext context) {
    final names = options
        .where((o) => selected.contains(o.$1))
        .map((o) => o.$2)
        .join(', ');
    // IOS_PAGES3: Ionic `ion-select multiple [label]`: label at the
    // start, the selected names (ellipsised) and the toggle icon at the end.
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * 0.4,
            ),
            child: Text(
              names,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.medium),
            ),
          ),
          const SizedBox(width: 4),
          isIosLook(context)
              ? const IonSelectIcon()
              : Icon(AppIcons.arrowDropDown),
        ],
      ),
      onTap: options.isEmpty ? null : () => _open(context),
    );
  }
}

// ============================================================================
// Origin (copied from another instance, Ionic 4.17.13)
// ============================================================================

/// "Kopiert aus X am …" for Werke taken over from another instance of the
/// organisation (Ionic `copiedFromText`).
class _SongOrigin extends StatelessWidget {
  const _SongOrigin({required this.origin});

  final SongCopiedFrom origin;

  @override
  Widget build(BuildContext context) {
    return IonInsetList(children: [
      IonItem(
        leading: Icon(AppIcons.callSplit, color: AppColors.medium),
        title: Text(
          context.l10n.orgSongsCopiedFrom(origin.tenantName, SongUtils.formatDate(origin.copiedAt)),
          style: const TextStyle(fontSize: 14, color: AppColors.medium),
        ),
      ),
    ]);
  }
}

// ============================================================================
// Copy to other instance
// ============================================================================

/// Ionic: available to any logged-in user, limited to other instances of the
/// organisation where the user is admin or responsible.
class _CopyToOtherInstance extends ConsumerWidget {
  const _CopyToOtherInstance({required this.song});

  final Song song;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final linked = ref.watch(linkedTenantsProvider).valueOrNull ?? const <Tenant>[];
    final mine = ref.watch(userTenantsProvider).valueOrNull ?? const <Tenant>[];
    final currentId = ref.watch(currentTenantIdProvider);
    final allowed = linked.where((t) {
      if (t.id == null || t.id == currentId) return false;
      final role = mine.where((m) => m.id == t.id).firstOrNull?.role;
      return role == 1 || role == 5;
    }).toList();
    if (allowed.isEmpty) return const SizedBox.shrink();

    return IonInsetList(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      children: [
        IonItem(
          leading: Icon(AppIcons.copyOutlined, color: AppColors.medium),
          title: Text(context.l10n.songsCopyToOther),
          onTap: () => showModalBottomSheet(
            context: context,
            useRootNavigator: true, // IOS_SHELL2: above the tab bar
            isScrollControlled: true,
            useSafeArea: true,
            enableDrag: false, // not closable while copying
            clipBehavior: Clip.antiAlias,
            builder: (_) => CopyToTenantSheet(song: song, availableTenants: allowed),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// Files
// ============================================================================

class _FilesSection extends ConsumerStatefulWidget {
  const _FilesSection({
    required this.data,
    required this.onChanged,
    required this.onClearInstrumentIds,
  });

  final SongDetailData data;
  final VoidCallback onChanged;

  /// "Alle löschen": empty the Besetzung through the page's save queue.
  final Future<void> Function() onClearInstrumentIds;

  @override
  ConsumerState<_FilesSection> createState() => _FilesSectionState();
}

class _FilesSectionState extends ConsumerState<_FilesSection> {
  bool _busy = false;

  SongDetailData get data => widget.data;
  Song get song => data.song;
  List<SongFile> get files => song.files ?? const [];

  bool get _isIos => !kIsWeb && Platform.isIOS;

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) ToastHelper.showError(context, context.l10n.songsFlutterErrorWith(friendlyErrorMessage(e)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _upload([List<PlatformFile> initialFiles = const []]) async {
    await showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true, // IOS_SHELL2: above the tab bar
      isScrollControlled: true,
      useSafeArea: true,
      isDismissible: false,
      // Classic: the breakpoint sheet inside moves and closes itself.
      enableDrag: context.rdSkin != null,
      clipBehavior: Clip.antiAlias,
      builder: (_) => FileUploadSheet(
        songId: song.id!,
        groups: data.instruments,
        existingFiles: files,
        mainGroupId: data.mainGroupId,
        isChoir: data.isChoir,
        initialFiles: initialFiles,
        workName: song.name,
      ),
    );
    // Ionic performUpload reloads the Werk after every run, also when some
    // files failed and the sheet is closed afterwards.
    if (mounted) widget.onChanged();
  }

  /// Ionic `handlePageDrop`: one file -> single-file modal, several files ->
  /// upload modal with the files preselected.
  Future<void> _onFilesDropped(List<PlatformFile> dropped) async {
    if (dropped.isEmpty || _busy) return;
    if (dropped.length > 1) return _upload(dropped);
    final file = dropped.first;
    if (file.size > 20 * 1024 * 1024) {
      ToastHelper.showError(context, context.l10n.songsFileTooLarge(file.name));
      return;
    }
    final result = await showModalBottomSheet<SingleFileUploadResult>(
      context: context,
      useRootNavigator: true, // IOS_SHELL2: above the tab bar
      isScrollControlled: true,
      useSafeArea: true,
      // Classic: the breakpoint sheet inside moves and closes itself.
      enableDrag: context.rdSkin != null,
      clipBehavior: Clip.antiAlias,
      builder: (_) => SingleFileUploadSheet(
        songId: song.id!,
        file: file,
        groups: data.instruments,
        existingFiles: files,
        mainGroupId: data.mainGroupId,
        isChoir: data.isChoir,
        workName: song.name,
      ),
    );
    if (!mounted) return;
    switch (result) {
      case SingleFileUploadResult.uploaded:
        widget.onChanged();
      case SingleFileUploadResult.openUploadSheet:
        await _upload(dropped);
      case null:
        break;
    }
  }

  Future<void> _downloadAll() => _run(() async {
        await ref.read(zipServiceProvider).downloadSongFilesAsZip(
              files: files,
              songName: song.name.isEmpty ? 'songs' : song.name,
            );
      });

  Future<void> _deleteAll() async {
    final ok = await DialogHelper.showConfirmation(
      context,
      title: context.l10n.songsDeleteAll,
      message: context.l10n.songsDeleteAllConfirm,
      confirmText: context.l10n.commonDelete,
      isDestructive: true,
    );
    if (!ok) return;
    await _run(() async {
      await (await ref.read(readySongFileServiceProvider.future)).deleteAllFiles(songId: song.id!);
      await widget.onClearInstrumentIds();
      widget.onChanged();
    });
  }

  /// Ionic `printSongFiles`: group PDFs with copies per player count
  Future<void> _printGroupPdfs() => printGroupPdfs(
        context: context,
        ref: ref,
        song: song,
        files: files,
        groups: data.instruments,
      );

  void _onFilesMenu(String v) {
    switch (v) {
      case 'print':
        _printGroupPdfs();
      case 'download':
        _downloadAll();
      case 'delete':
        _deleteAll();
    }
  }

  @override
  Widget build(BuildContext context) {
    final sorted = SongUtils.sortedFiles(files, data.instruments);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        IonListHeader(
          context.l10n.songsFiles,
          trailing: [
            if (data.readOnly && files.isNotEmpty)
              IconButton(
                tooltip: context.l10n.songsDownloadAll,
                icon: Icon(AppIcons.downloadOutlined),
                onPressed: _busy ? null : _downloadAll,
              ),
            if (!data.readOnly)
              IconButton(
                tooltip: context.l10n.songsUploadFiles,
                icon: Icon(AppIcons.cloudUploadOutlined),
                onPressed: _busy ? null : () => _upload(),
              ),
            // Ionic `ion-popover #filesPopover` (trigger "files-button"):
            // `ion-list` with item lines, icons in slot start.
            if (!data.readOnly && files.isNotEmpty && context.rdSkin == null)
              Builder(
                builder: (buttonContext) => IconButton(
                  icon: Icon(AppIcons.moreHoriz),
                  tooltip: MaterialLocalizations.of(context).showMenuTooltip,
                  onPressed: () async {
                    final v = await showAppPopoverMenu<String>(
                      context: buttonContext,
                      lines: true,
                      items: [
                        AppPopoverMenuItem(
                          value: 'print',
                          icon: AppIcons.printOutlined,
                          label: context.l10n.songsPrintGroupPdfs,
                        ),
                        AppPopoverMenuItem(
                          value: 'download',
                          icon: AppIcons.downloadOutlined,
                          label: context.l10n.songsDownloadAll,
                        ),
                        AppPopoverMenuItem(
                          value: 'delete',
                          icon: AppIcons.deleteOutline,
                          label: context.l10n.songsDeleteAll,
                        ),
                      ],
                    );
                    if (v != null && mounted) _onFilesMenu(v);
                  },
                ),
              ),
            // Beta design: its Material menu as before.
            if (!data.readOnly && files.isNotEmpty && context.rdSkin != null)
              PopupMenuButton<String>(
                icon: Icon(AppIcons.moreHoriz),
                onSelected: _onFilesMenu,
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'print',
                    child: ListTile(
                      leading: Icon(AppIcons.printOutlined),
                      title: Text(context.l10n.songsPrintGroupPdfs),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'download',
                    child: ListTile(
                      leading: Icon(AppIcons.downloadOutlined),
                      title: Text(context.l10n.songsDownloadAll),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      leading: Icon(AppIcons.deleteOutline),
                      title: Text(context.l10n.songsDeleteAll),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
          ],
        ),
        if (_busy) const LinearProgressIndicator(minHeight: 2),
        // Ionic `.files-drop-area`: drop files from the desktop onto the list
        FileDropTarget(
          enabled: !data.readOnly && !_busy,
          onFiles: _onFilesDropped,
          builder: (context, hovering) => _FilesGroup(
            border: hovering ? Border.all(color: AppColors.primary, width: 2) : null,
            color: hovering
                ? Color.alphaBlend(
                    AppColors.primary.withAlpha(13), Theme.of(context).colorScheme.surface)
                : null,
            children: files.isEmpty
                ? [IonItem(title: Text(context.l10n.songsNoFiles))]
                : [
                    for (final file in sorted)
                      IonItem(
                        title: Text(file.fileName),
                        trailing: SongBadge(
                          color: SongUtils.fileBadgeColor(file),
                          label: SongUtils.fileLabel(file, data.instruments, isChoir: data.isChoir),
                        ),
                        onTap: () => _openActions(file),
                      ),
                  ],
          ),
        ),
      ],
    );
  }

  Future<void> _openActions(SongFile file) async {
    final isAudio = SongUtils.isAudio(file) ||
        AudioPlayerService.isAudioFile(file.fileName);
    final telegramChatId = data.isPublic
        ? null
        : ref.read(currentTenantUserProvider).valueOrNull?.telegramChatId;

    final action = await showAppActionSheet<String>(
      context,
      title: context.l10n.songsFileActions,
      actions: [
        AppActionSheetAction(value: 'open', icon: isAudio ? AppIcons.playCircleOutline : AppIcons.openInNew, label: isAudio ? context.l10n.songsPlayRecording : context.l10n.songsOpenFile),
        if (!isAudio) AppActionSheetAction(value: 'print', icon: AppIcons.printOutlined, label: context.l10n.songsPrintFile),
        if (!_isIos || isAudio) AppActionSheetAction(value: 'download', icon: AppIcons.downloadOutlined, label: isAudio ? context.l10n.songsDownloadRecording : context.l10n.songsDownloadFile),
        if (!data.readOnly) AppActionSheetAction(value: 'category', icon: AppIcons.swapHoriz, label: context.l10n.songsChangeCategory),
        if (telegramChatId != null && telegramChatId.isNotEmpty) AppActionSheetAction(value: 'telegram', icon: AppIcons.sendOutlined, label: context.l10n.songsSendTelegram),
        if (!data.readOnly) AppActionSheetAction(value: 'delete', icon: AppIcons.deleteOutline, label: context.l10n.songsDeleteFile, destructive: true),
      ],
    );
    if (!mounted || action == null) return;

    switch (action) {
      case 'open':
        if (isAudio) {
          await ref
              .read(audioPlayerServiceProvider.notifier)
              .playFromUrl(file.url, file.fileName, song.name);
        } else {
          await openSongFile(context, file);
        }
      case 'print':
        final baseName = (file.fileName.isNotEmpty ? file.fileName : song.name)
            .replaceAll(RegExp(r'\.[^.]+$'), '');
        final result = await ref
            .read(songPrintServiceProvider)
            .printEntries([SongPrintEntry(song: song, file: file)], '$baseName.pdf');
        if (mounted && result != null && result.pageCount == 0) {
          ToastHelper.showWarning(context, context.l10n.songsFlutterPrintFileFailed);
        }
      case 'download':
        // Ionic 4.17.23: iOS app on a Mac → the browser downloads the file.
        if (await NativeFileService.downloadInMacBrowser(file.url, file.fileName)) return;
        await _run(() async {
          final bytes = await ref.read(songFileServiceProvider).downloadFileBytes(file.url);
          if (bytes == null) throw Exception(l10nWithoutContext.songsFlutterDownloadFileFailed);
          await file_saver.saveZipFile(bytes, file.fileName);
        });
      case 'category':
        await _changeCategory(file);
      case 'telegram':
        await _run(() async {
          await ref
              .read(telegramServiceProvider)
              .sendDocumentPerTelegram(url: file.url, chatId: telegramChatId!);
          if (mounted) ToastHelper.showSuccess(context, context.l10n.songsFlutterTelegramSent);
        });
      case 'delete':
        final ok = await DialogHelper.showConfirmation(
          context,
          title: context.l10n.songsDeleteFile,
          message: context.l10n.songsDeleteFileConfirm(file.fileName),
          confirmText: context.l10n.commonDelete,
          isDestructive: true,
        );
        if (!ok) return;
        await _run(() async {
          await (await ref.read(readySongFileServiceProvider.future)).deleteFile(
                songId: song.id!,
                url: file.url,
                storageName: file.storageName,
                fileName: file.fileName,
                mainGroupId: data.mainGroupId,
              );
          widget.onChanged();
        });
    }
  }

  Future<({int? instrumentId, String? note})?> _showCategorySheet(Widget picker) =>
      showSettingsSheet<({int? instrumentId, String? note})>(
        context,
        useRootNavigator: true, // IOS_SHELL2: above the tab bar
        builder: (_) => picker,
      );

  Future<({int? instrumentId, String? note})?> _showCategoryDialog(Widget picker) =>
      showAppDialog<({int? instrumentId, String? note})>(
        context: context,
        builder: (_) => picker,
      );

  /// Ionic category modal: Chor (alle) (choirs) / Sonstige (Freitext) /
  /// Aufnahme / Liedtext / groups
  Future<void> _changeCategory(SongFile file) async {
    // Ionic: sheet modal (breakpoints [0, 1]); the Beta skin keeps its dialog.
    final asSheet = context.rdSkin == null;
    final result = await (asSheet ? _showCategorySheet : _showCategoryDialog)(
      FileCategoryDialog(
        asSheet: asSheet,
        instruments: data.instruments,
        isChoir: data.isChoir,
        // Ionic 4.17.16 changeCategory: in choirs a file without group and
        // note (or noted "Chor") preselects "Chor (alle)".
        initialInstrumentId: data.isChoir &&
                file.instrumentId == null &&
                ((file.note ?? '').isEmpty || isChoirAllFile(note: file.note))
            ? kChoirAllOptionValue
            : file.instrumentId,
        initialNote: isChoirAllFile(instrumentId: file.instrumentId, note: file.note) && data.isChoir
            ? ''
            : (file.note ?? ''),
      ),
    );
    if (result == null) return;
    await _run(() async {
      await (await ref.read(readySongFileServiceProvider.future)).updateFileCategory(
            songId: song.id!,
            url: file.url,
            storageName: file.storageName,
            instrumentId: result.instrumentId,
            note: result.instrumentId == null ? result.note : null,
            mainGroupId: data.mainGroupId,
          );
      widget.onChanged();
    });
  }
}

/// Category picker for a song file (also used by the upload sheet).
class FileCategoryDialog extends StatefulWidget {
  const FileCategoryDialog({
    super.key,
    required this.instruments,
    required this.initialInstrumentId,
    required this.initialNote,
    this.isChoir = false,
    this.asSheet = false,
  });

  final List<Group> instruments;

  /// Ionic sheet modal (normal design): toolbar with "Abbrechen", radio
  /// list, free text and a block "Speichern" button. Otherwise a dialog.
  final bool asSheet;

  /// Picker value: an instrumentId, null ("Sonstige (Freitext)") or
  /// [kChoirAllOptionValue] ("Chor (alle)").
  final int? initialInstrumentId;
  final String initialNote;

  /// Choirs get the option "Chor (alle)" on top (Ionic 4.17.16).
  final bool isChoir;

  @override
  State<FileCategoryDialog> createState() => _FileCategoryDialogState();
}

class _FileCategoryDialogState extends State<FileCategoryDialog> {
  late int? _id = widget.initialInstrumentId;
  late final _note = TextEditingController(text: widget.initialNote);

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final options = <(int?, String)>[
      if (widget.isChoir) (kChoirAllOptionValue, context.l10n.songsChoirAll),
      (null, context.l10n.songsOtherFreeText),
      (1, context.l10n.songsRecording),
      (2, context.l10n.songsLyrics),
      for (final g in widget.instruments) (g.id, g.name),
    ];
    if (widget.asSheet) return _buildSheet(context, options);
    return AppAlertDialog(
      title: Text(context.l10n.songsChangeCategory),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final o in options)
              RadioListTile<int?>(
                dense: true,
                value: o.$1,
                groupValue: _id,
                title: Text(o.$2),
                subtitle: o.$1 == kChoirAllOptionValue
                    ? Text(context.l10n.songsChoirAllHint)
                    : null,
                onChanged: (v) => setState(() => _id = v),
              ),
            if (_id == null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _note,
                  decoration: InputDecoration(
                    labelText: context.l10n.songsFreeText,
                    hintText: context.l10n.songsEnterCategory,
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.commonCancel),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(
            context,
            resolveFileCategoryOption(_id, _note.text.trim()),
          ),
          child: Text(context.l10n.commonSave),
        ),
      ],
    );
  }

  Widget _buildSheet(BuildContext context, List<(int?, String)> options) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: settingsSheetBar(
        context,
        title: context.l10n.songsChangeCategory,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.commonCancel),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 16),
        children: [
          for (final o in options)
            IonRadioItem<int?>(
              value: o.$1,
              groupValue: _id,
              title: Text(o.$2),
              subtitle: o.$1 == kChoirAllOptionValue
                  ? Text(context.l10n.songsChoirAllHint)
                  : null,
              onChanged: (v) => setState(() => _id = v),
            ),
          if (_id == null) ...[
            // Ionic `ion-item-divider` + `ion-input clearInput`
            Container(
              color: theme.colorScheme.surfaceContainerHighest,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Text(context.l10n.songsFreeText,
                  style: theme.textTheme.bodySmall),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ValueListenableBuilder<TextEditingValue>(
                valueListenable: _note,
                builder: (context, value, _) => TextField(
                  controller: _note,
                  decoration: InputDecoration(
                    hintText: context.l10n.songsEnterCategory,
                    border: InputBorder.none,
                    suffixIcon: value.text.isEmpty
                        ? null
                        : IconButton(
                            icon: Icon(AppIcons.cancel, size: 18),
                            tooltip: context.l10n.a11yClearInput,
                            onPressed: _note.clear,
                          ),
                  ),
                ),
              ),
            ),
          ],
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton(
              onPressed: () => Navigator.pop(
                context,
                resolveFileCategoryOption(_id, _note.text.trim()),
              ),
              child: IonButtonLabel(context.l10n.commonSave),
            ),
          ),
        ],
      ),
    );
  }
}

/// IOS_FORMS2: the files `ion-item-group` sits inside Ionic's
/// `.files-drop-area` div, so the iOS theme's rounded group corners do not
/// apply: on iOS the rows ("Keine Dateien vorhanden." / the files) form a
/// plain full-width block with square corners. Material keeps the inset card.
class _FilesGroup extends StatelessWidget {
  const _FilesGroup({required this.children, this.color, this.border});

  final List<Widget> children;
  final Color? color;
  final BoxBorder? border;

  @override
  Widget build(BuildContext context) {
    // Beta-Skin: the files are a card like every other group.
    if (!isIosLook(context) || context.rdSkin != null) {
      return IonInsetList(color: color, border: border, children: children);
    }
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) rows.add(const Divider(height: 0.5, thickness: 0.5, indent: 16));
      rows.add(children[i]);
    }
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: color ?? Theme.of(context).colorScheme.surface,
        border: border,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: rows,
        ),
      ),
    );
  }
}
