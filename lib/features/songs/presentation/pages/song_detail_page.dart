import 'dart:io' show Platform;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/organisation_providers.dart';
import '../../../../core/providers/player_providers.dart';
import '../../../../core/providers/song_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/services/audio_player/audio_player_service.dart';
import '../../../../core/services/song_file_service.dart';
import '../../../../core/services/telegram_service.dart';
import '../../../../core/services/zip_service.dart';
import '../../../../core/services/zip_service_stub.dart'
    if (dart.library.io) '../../../../core/services/zip_service_io.dart'
    if (dart.library.html) '../../../../core/services/zip_service_web.dart'
    as file_saver;
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/dialog_helper.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/instrument/instrument.dart';
import '../../../../data/models/song/song.dart';
import '../../../../data/models/song/song_additional_field.dart';
import '../../../../data/models/tenant/tenant.dart';
import '../../../../shared/widgets/audio_player/audio_player_widget.dart';
import '../../data/song_print_service.dart';
import '../utils/song_utils.dart';
import '../widgets/copy_to_tenant_sheet.dart';
import '../widgets/file_drop/file_drop_target.dart';
import '../widgets/file_upload_sheet.dart';
import '../widgets/single_file_upload_sheet.dart';
import '../widgets/song_file_opener.dart';
import '../../../../core/services/tracking/tracking_event.dart';
import '../../../../core/services/tracking/tracking_service.dart';

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
  bool _saving = false;

  int? get _songId => int.tryParse(widget.songId);

  SongDetailParams get _params =>
      (songId: _songId ?? 0, sharingId: widget.songSharingId);

  @override
  void dispose() {
    _prefix.dispose();
    _number.dispose();
    _name.dispose();
    _link.dispose();
    for (final c in _fieldControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _init(SongDetailData data) {
    final song = data.song;
    if (_initializedFor == song.id) return;
    _initializedFor = song.id;
    _prefix.text = song.prefix ?? '';
    _number.text = song.number?.toString() ?? '';
    _name.text = song.name;
    _link.text = song.link ?? '';
    _withChoir = song.withChoir;
    _withSolo = song.withSolo;
    _difficulty = song.difficulty;
    _instrumentIds = {...?song.instrumentIds, ..._idsFromFiles(song)}.toList();
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
  }

  /// Ionic `instrumentIdsFromFiles`: groups that have files (id > 2)
  List<int> _idsFromFiles(Song song) => {
        for (final f in song.files ?? const <SongFile>[])
          if (f.instrumentId != null && f.instrumentId! > 2) f.instrumentId!,
      }.toList();

  /// Ionic `update()`: save the whole form
  Future<void> _update(SongDetailData data) async {
    if (data.readOnly || _saving) return;
    final id = data.song.id;
    if (id == null) return;
    final merged = {..._instrumentIds, ..._idsFromFiles(data.song)}.toList();
    _instrumentIds = merged;
    for (final field in data.additionalFields) {
      final c = _fieldControllers[field.id];
      if (c == null) continue;
      _additional[field.id] = field.isNumber ? num.tryParse(c.text) ?? 0 : c.text;
    }

    setState(() => _saving = true);
    final result = await ref.read(songNotifierProvider.notifier).updateSong(id, {
      'prefix': _prefix.text.trim(),
      'number': int.tryParse(_number.text.trim()),
      'name': _name.text.trim(),
      'link': _link.text.trim().isEmpty ? null : _link.text.trim(),
      'difficulty': _difficulty,
      'withChoir': _withChoir,
      'withSolo': _withSolo,
      'instrument_ids': merged,
      'category_ids': _categoryIds,
      'additional_fields': _additional,
    });
    if (!mounted) return;
    setState(() => _saving = false);
    if (result == null) {
      ToastHelper.showError(context, 'Fehler beim Speichern');
    }
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
    ToastHelper.showSuccess(context, 'Der Link wurde in die Zwischenablage kopiert');
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
      title: 'Werk löschen',
      message: names.isNotEmpty
          ? 'Die Werke werden mit ${names.join(', ')} geteilt. Das Werk wird dort ebenfalls gelöscht, inklusive der Historie aller beteiligten Instanzen. Soll das Werk wirklich gelöscht werden?'
          : 'Soll das Werk wirklich gelöscht werden?',
      confirmText: 'Löschen',
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;
    final ok = await ref.read(songNotifierProvider.notifier).deleteSong(data.song.id!);
    if (!mounted) return;
    if (ok) {
      context.go('/settings/songs');
    } else {
      ToastHelper.showError(context, 'Werk konnte nicht gelöscht werden');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_songId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Werk')),
        body: const Center(child: Text('Ungültige Werk-ID')),
      );
    }
    final dataAsync = ref.watch(songDetailDataProvider(_params));
    final data = dataAsync.valueOrNull;

    if (data == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Werk')),
        body: Center(
          child: dataAsync.isLoading
              ? const CircularProgressIndicator()
              : Text(dataAsync.hasError
                  ? 'Fehler: ${dataAsync.error}'
                  : widget.songSharingId != null
                      ? 'Ungültiger Freigabe-Link.'
                      : 'Werk nicht gefunden'),
        ),
      );
    }

    _init(data);
    final song = data.song;
    final sharingId = data.songSharingId;
    final aufnahme = song.files
        ?.where((f) => f.instrumentId == 1 && SongUtils.isAudio(f))
        .firstOrNull;

    return Scaffold(
      appBar: AppBar(
        title: Text(data.readOnly
            ? '${song.number ?? ''} ${song.name}'.trim()
            : 'Werk bearbeiten'),
        actions: [
          if (sharingId != null && sharingId.isNotEmpty)
            IconButton(
              tooltip: 'Link kopieren',
              icon: const Icon(Icons.link),
              onPressed: () => _copyShareLink(sharingId, song.id!),
            ),
          if (!data.readOnly)
            IconButton(
              tooltip: 'Werk löschen',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _confirmDelete(data),
            ),
        ],
      ),
      floatingActionButton: aufnahme == null
          ? null
          : FloatingActionButton(
              tooltip: 'Aufnahme abspielen',
              onPressed: () => ref
                  .read(audioPlayerServiceProvider.notifier)
                  .playFromUrl(aufnahme.url, aufnahme.fileName, song.name),
              child: const Icon(Icons.play_arrow),
            ),
      bottomNavigationBar: data.isPublic ? const AudioPlayerWidget() : null,
      body: RefreshIndicator(
        onRefresh: () async {
          _refresh();
          await ref.read(songDetailDataProvider(_params).future);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
              AppDimensions.paddingM, AppDimensions.paddingM, AppDimensions.paddingM, 96),
          children: [
            if (_saving) const LinearProgressIndicator(minHeight: 2),
            if (!data.readOnly) _buildEditForm(data),
            if (data.readOnly && (song.categoryIds?.isNotEmpty ?? false)) ...[
              const _SectionHeader('Kategorien'),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final id in song.categoryIds!)
                    Chip(
                      label: Text(
                        data.categories.where((c) => c.id == id).firstOrNull?.name ??
                            'Unbekannte Kategorie',
                      ),
                      backgroundColor: AppColors.secondary.withAlpha(40),
                    ),
                ],
              ),
            ],
            if (data.readOnly &&
                (song.withChoir ||
                    song.withSolo ||
                    (data.isOrchestra && (song.instrumentIds?.isNotEmpty ?? false))))
              _buildReadOnlyInstrumentation(data),
            if (data.additionalFields.isNotEmpty) _buildAdditionalFields(data),
            if (data.history.isNotEmpty) _buildHistory(data),
            _FilesSection(
              data: data,
              onChanged: _refresh,
            ),
            const SizedBox(height: AppDimensions.paddingM),
            if (data.readOnly && (song.link?.isNotEmpty ?? false))
              Card(
                child: ListTile(
                  title: const Text('Externen Noten-Link öffnen',
                      style: TextStyle(color: AppColors.primary)),
                  trailing: const Icon(Icons.open_in_new),
                  onTap: () => launchUrl(Uri.parse(song.link!),
                      mode: LaunchMode.externalApplication),
                ),
              ),
            if (!data.readOnly)
              Focus(
                onFocusChange: (has) {
                  if (!has) _update(data);
                },
                child: TextField(
                  controller: _link,
                  minLines: 1,
                  maxLines: 5,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(labelText: 'Link'),
                ),
              ),
            if (!data.isPublic) _CopyToOtherInstance(song: song),
          ],
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
    final fileIds = _idsFromFiles(data.song);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _blurSaver(
              data,
              TextField(
                controller: _prefix,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Präfix (optional)',
                  helperText:
                      'Bspw. um Weihnachtslieder kennzeichnen zu können (z.B. W für Weihnachten -> W1)',
                  helperMaxLines: 2,
                ),
              ),
            ),
            const SizedBox(height: AppDimensions.paddingS),
            _blurSaver(
              data,
              TextField(
                controller: _number,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Nummer'),
              ),
            ),
            const SizedBox(height: AppDimensions.paddingS),
            _blurSaver(
              data,
              TextField(
                controller: _name,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
            ),
            const SizedBox(height: AppDimensions.paddingS),
            DropdownButtonFormField<int?>(
              value: _difficulty,
              decoration: const InputDecoration(labelText: 'Schwierigkeitsgrad'),
              items: const [
                DropdownMenuItem(value: null, child: Text('Nicht definiert')),
                DropdownMenuItem(value: 1, child: Text('1 - Leicht')),
                DropdownMenuItem(value: 2, child: Text('2 - Mittel')),
                DropdownMenuItem(value: 3, child: Text('3 - Schwer')),
              ],
              onChanged: (v) {
                setState(() => _difficulty = v);
                _update(data);
              },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Chor & Orchester'),
              value: _withChoir,
              onChanged: (v) {
                setState(() => _withChoir = v);
                _update(data);
              },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Mit Solo-Gesang'),
              value: _withSolo,
              onChanged: (v) {
                setState(() => _withSolo = v);
                _update(data);
              },
            ),
            if (data.isOrchestra)
              _MultiSelectTile<int>(
                title: 'Besetzung',
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
            _MultiSelectTile<String>(
              title: 'Kategorien',
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
    );
  }

  Widget _buildReadOnlyInstrumentation(SongDetailData data) {
    final song = data.song;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader('Besetzung'),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            if (song.withChoir)
              Chip(
                label: const Text('Chor & Orchester'),
                backgroundColor: AppColors.primary.withAlpha(40),
              ),
            if (song.withSolo)
              Chip(
                label: const Text('Mit Solo-Gesang'),
                backgroundColor: AppColors.primary.withAlpha(40),
              ),
          ],
        ),
        if (data.isOrchestra && (song.instrumentIds?.isNotEmpty ?? false))
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final g in data.instruments)
                  Builder(builder: (context) {
                    final has = song.instrumentIds!.contains(g.id);
                    final color = has ? AppColors.success : AppColors.danger;
                    return Chip(
                      label: Text(g.name, style: TextStyle(color: color, fontSize: 12)),
                      backgroundColor: color.withAlpha(30),
                      side: BorderSide(color: color.withAlpha(90)),
                      visualDensity: VisualDensity.compact,
                    );
                  }),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildAdditionalFields(SongDetailData data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionHeader('Zusatzfelder'),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingM),
            child: Column(
              children: [
                for (final field in data.additionalFields) _buildField(data, field),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildField(SongDetailData data, SongAdditionalField field) {
    final value = _additional[field.id];
    if (field.isBoolean) {
      return SwitchListTile(
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
      return DropdownButtonFormField<String>(
        value: current,
        decoration: InputDecoration(labelText: field.name),
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
          decoration: InputDecoration(labelText: field.name),
        ),
      ),
    );
  }

  Widget _buildHistory(SongDetailData data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeader('Historie (${data.history.length}x)'),
        Card(
          child: Column(
            children: [
              for (final entry in data.history)
                ListTile(
                  dense: true,
                  title: Text(
                    '${SongUtils.formatDate(entry.attendanceDate ?? entry.date)}'
                    '${(entry.typeTitle?.isNotEmpty ?? false) ? ' · ${entry.typeTitle}' : ''}',
                  ),
                  subtitle: (entry.conductorName?.isNotEmpty ?? false)
                      ? Text(entry.conductorName!)
                      : null,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppDimensions.paddingM, bottom: 6, left: 4),
      child: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.medium),
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
    final result = await showDialog<List<T>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(title),
          content: SizedBox(
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
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Abbrechen'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, selection),
              child: const Text('OK'),
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
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      subtitle: Text(names.isEmpty ? '-' : names, maxLines: 3, overflow: TextOverflow.ellipsis),
      trailing: const Icon(Icons.arrow_drop_down),
      onTap: options.isEmpty ? null : () => _open(context),
    );
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

    return Card(
      margin: const EdgeInsets.only(top: AppDimensions.paddingM),
      child: ListTile(
        leading: const Icon(Icons.copy_outlined),
        title: const Text('Werk in andere Instanz kopieren'),
        onTap: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          builder: (_) => CopyToTenantSheet(song: song, availableTenants: allowed),
        ),
      ),
    );
  }
}

// ============================================================================
// Files
// ============================================================================

class _FilesSection extends ConsumerStatefulWidget {
  const _FilesSection({required this.data, required this.onChanged});

  final SongDetailData data;
  final VoidCallback onChanged;

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
      if (mounted) ToastHelper.showError(context, 'Fehler: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _upload([List<PlatformFile> initialFiles = const []]) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      isDismissible: false,
      builder: (_) => FileUploadSheet(
        songId: song.id!,
        groups: data.instruments,
        existingFiles: files,
        mainGroupId: data.mainGroupId,
        isChoir: data.isChoir,
        initialFiles: initialFiles,
      ),
    );
    if (result == true) widget.onChanged();
  }

  /// Ionic `handlePageDrop`: one file -> single-file modal, several files ->
  /// upload modal with the files preselected.
  Future<void> _onFilesDropped(List<PlatformFile> dropped) async {
    if (dropped.isEmpty || _busy) return;
    if (dropped.length > 1) return _upload(dropped);
    final file = dropped.first;
    if (file.size > 20 * 1024 * 1024) {
      ToastHelper.showError(
        context,
        'Die Datei ${file.name} überschreitet die maximale Größe von 20MB.',
      );
      return;
    }
    final result = await showModalBottomSheet<SingleFileUploadResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => SingleFileUploadSheet(
        songId: song.id!,
        file: file,
        groups: data.instruments,
        existingFiles: files,
        mainGroupId: data.mainGroupId,
        isChoir: data.isChoir,
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
      title: 'Alle Dateien löschen',
      message: 'Möchten Sie wirklich alle Dateien dieses Werks löschen?',
      confirmText: 'Löschen',
      isDestructive: true,
    );
    if (!ok) return;
    await _run(() async {
      await ref.read(songFileServiceProvider).deleteAllFiles(songId: song.id!);
      await ref
          .read(songNotifierProvider.notifier)
          .updateSong(song.id!, {'instrument_ids': <int>[]});
      widget.onChanged();
    });
  }

  /// Ionic `printSongFiles`: group PDFs with copies per player count
  Future<void> _printGroupPdfs() async {
    final groupPdfs = files
        .where((f) => f.instrumentId != null && f.instrumentId! > 2 && SongUtils.isPdf(f))
        .toList();
    if (groupPdfs.isEmpty) {
      ToastHelper.showWarning(context, 'Keine Gruppen-PDFs zum Drucken gefunden');
      return;
    }
    final counts = await ref.read(playerCountByInstrumentProvider.future);
    if (!mounted) return;
    final withPlayers =
        groupPdfs.where((f) => (counts[f.instrumentId] ?? 0) > 0).toList();
    if (withPlayers.isEmpty) {
      ToastHelper.showWarning(context, 'Keine Gruppen mit zugewiesenen Personen gefunden');
      return;
    }

    final ratio = await showDialog<int>(
      context: context,
      builder: (ctx) => _RatioDialog(),
    );
    if (ratio == null || !mounted) return;

    final entries = [
      for (final f in withPlayers)
        SongPrintEntry(
          song: song,
          file: f,
          copies: ratio == 0 ? 1 : ((counts[f.instrumentId] ?? 0) / ratio).ceil(),
        ),
    ];
    final result = await ref
        .read(songPrintServiceProvider)
        .printEntries(entries, '${song.name.isEmpty ? 'song' : song.name}_print.pdf');
    if (!mounted || result == null || result.pageCount == 0) return;
    final summary = entries
        .where((e) => e.copies > 0)
        .map((e) => '${SongUtils.fileLabel(e.file, data.instruments)}: ${e.copies}x')
        .join(', ');
    ToastHelper.showSuccess(context, 'Druck vorbereitet: $summary');
  }

  @override
  Widget build(BuildContext context) {
    final sorted = SongUtils.sortedFiles(files, data.instruments);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(child: _SectionHeader('Dateien')),
            if (data.readOnly && files.isNotEmpty)
              IconButton(
                tooltip: 'Alle Dateien herunterladen',
                icon: const Icon(Icons.download_outlined),
                onPressed: _busy ? null : _downloadAll,
              ),
            if (!data.readOnly)
              IconButton(
                tooltip: 'Dateien hochladen',
                icon: const Icon(Icons.cloud_upload_outlined),
                onPressed: _busy ? null : () => _upload(),
              ),
            if (!data.readOnly && files.isNotEmpty)
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_horiz),
                onSelected: (v) {
                  switch (v) {
                    case 'print':
                      _printGroupPdfs();
                    case 'download':
                      _downloadAll();
                    case 'delete':
                      _deleteAll();
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'print',
                    child: ListTile(
                      leading: Icon(Icons.print_outlined),
                      title: Text('Gruppen-PDFs drucken'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'download',
                    child: ListTile(
                      leading: Icon(Icons.download_outlined),
                      title: Text('Alle Dateien herunterladen'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      leading: Icon(Icons.delete_outline),
                      title: Text('Alle Dateien löschen'),
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
          builder: (context, hovering) => Card(
            shape: hovering
                ? RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: AppColors.primary, width: 2),
                  )
                : null,
            color: hovering ? Color.alphaBlend(AppColors.primary.withAlpha(13), Theme.of(context).cardColor) : null,
            child: files.isEmpty
                ? const ListTile(title: Text('Keine Dateien vorhanden.'))
                : Column(
                    children: [
                      for (final file in sorted)
                        ListTile(
                          title: Text(file.fileName),
                          trailing: SongBadge(
                            color: SongUtils.fileBadgeColor(file),
                            label: SongUtils.fileLabel(file, data.instruments),
                          ),
                          onTap: () => _openActions(file),
                        ),
                    ],
                  ),
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

    final action = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text('Datei Aktionen', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            ListTile(
              leading: Icon(isAudio ? Icons.play_circle_outline : Icons.open_in_new),
              title: Text(isAudio ? 'Aufnahme abspielen' : 'Datei öffnen'),
              onTap: () => Navigator.pop(ctx, 'open'),
            ),
            if (!isAudio)
              ListTile(
                leading: const Icon(Icons.print_outlined),
                title: const Text('Datei drucken'),
                onTap: () => Navigator.pop(ctx, 'print'),
              ),
            if (!_isIos || isAudio)
              ListTile(
                leading: const Icon(Icons.download_outlined),
                title: Text(isAudio ? 'Aufnahme herunterladen' : 'Datei herunterladen'),
                onTap: () => Navigator.pop(ctx, 'download'),
              ),
            if (!data.readOnly)
              ListTile(
                leading: const Icon(Icons.swap_horiz),
                title: const Text('Kategorie ändern'),
                onTap: () => Navigator.pop(ctx, 'category'),
              ),
            if (telegramChatId != null && telegramChatId.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.send_outlined),
                title: const Text('Per Telegram senden'),
                onTap: () => Navigator.pop(ctx, 'telegram'),
              ),
            if (!data.readOnly)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: AppColors.danger),
                title: const Text('Datei löschen', style: TextStyle(color: AppColors.danger)),
                onTap: () => Navigator.pop(ctx, 'delete'),
              ),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('Abbrechen'),
              onTap: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
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
          ToastHelper.showWarning(context, 'Datei konnte nicht gedruckt werden');
        }
      case 'download':
        await _run(() async {
          final bytes = await ref.read(songFileServiceProvider).downloadFileBytes(file.url);
          if (bytes == null) throw Exception('Datei konnte nicht heruntergeladen werden');
          await file_saver.saveZipFile(bytes, file.fileName);
        });
      case 'category':
        await _changeCategory(file);
      case 'telegram':
        await _run(() async {
          await ref
              .read(telegramServiceProvider)
              .sendDocumentPerTelegram(url: file.url, chatId: telegramChatId!);
          if (mounted) ToastHelper.showSuccess(context, 'Datei per Telegram gesendet');
        });
      case 'delete':
        final ok = await DialogHelper.showConfirmation(
          context,
          title: 'Datei löschen',
          message: 'Möchten Sie die Datei "${file.fileName}" wirklich löschen?',
          confirmText: 'Löschen',
          isDestructive: true,
        );
        if (!ok) return;
        await _run(() async {
          await ref.read(songFileServiceProvider).deleteFile(
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

  /// Ionic category modal: Sonstige (Freitext) / Aufnahme / Liedtext / groups
  Future<void> _changeCategory(SongFile file) async {
    final result = await showDialog<({int? instrumentId, String? note})>(
      context: context,
      builder: (_) => FileCategoryDialog(
        instruments: data.instruments,
        initialInstrumentId: file.instrumentId,
        initialNote: file.note ??
            (file.instrumentId == null && data.isChoir ? 'Chor' : ''),
      ),
    );
    if (result == null) return;
    await _run(() async {
      await ref.read(songFileServiceProvider).updateFileCategory(
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

class _RatioDialog extends StatefulWidget {
  @override
  State<_RatioDialog> createState() => _RatioDialogState();
}

class _RatioDialogState extends State<_RatioDialog> {
  int _ratio = 1;

  @override
  Widget build(BuildContext context) {
    const options = [
      (1, 'Alle Personen (1 pro Person)'),
      (2, 'Jede 2. Person'),
      (3, 'Jede 3. Person'),
      (4, 'Jede 4. Person'),
      (0, '1 pro Gruppe'),
    ];
    return AlertDialog(
      title: const Text('Druckoptionen'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Wie viele Ausdrucke pro Gruppe?'),
          for (final o in options)
            RadioListTile<int>(
              contentPadding: EdgeInsets.zero,
              value: o.$1,
              groupValue: _ratio,
              title: Text(o.$2),
              onChanged: (v) => setState(() => _ratio = v ?? 1),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Abbrechen'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _ratio),
          child: const Text('Drucken'),
        ),
      ],
    );
  }
}

/// Category picker for a song file (also used by the upload sheet).
class FileCategoryDialog extends StatefulWidget {
  const FileCategoryDialog({
    super.key,
    required this.instruments,
    required this.initialInstrumentId,
    required this.initialNote,
  });

  final List<Group> instruments;
  final int? initialInstrumentId;
  final String initialNote;

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
      (null, 'Sonstige (Freitext)'),
      (1, 'Aufnahme'),
      (2, 'Liedtext'),
      for (final g in widget.instruments) (g.id, g.name),
    ];
    return AlertDialog(
      title: const Text('Kategorie ändern'),
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
                onChanged: (v) => setState(() => _id = v),
              ),
            if (_id == null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _note,
                  decoration: const InputDecoration(
                    labelText: 'Freitext',
                    hintText: 'Kategorie eingeben...',
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Abbrechen'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(
            context,
            (instrumentId: _id, note: _id == null ? _note.text.trim() : null),
          ),
          child: const Text('Speichern'),
        ),
      ],
    );
  }
}
