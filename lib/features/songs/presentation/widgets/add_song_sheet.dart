import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/song_providers.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/song/song.dart';
import '../utils/song_utils.dart';
import '../../../../l10n/l10n.dart';

/// "Werk hinzufügen" (Ionic addSongsModal). Returns the id of the new song.
class AddSongSheet extends ConsumerStatefulWidget {
  const AddSongSheet({super.key, required this.data, this.onCreated});

  final SongsListData data;

  /// Called instead of popping with the new id (used by the full page route)
  final ValueChanged<int>? onCreated;

  @override
  ConsumerState<AddSongSheet> createState() => _AddSongSheetState();
}

class _AddSongSheetState extends ConsumerState<AddSongSheet> {
  final _prefix = TextEditingController();
  final _number = TextEditingController();
  final _name = TextEditingController();
  final _link = TextEditingController();
  bool _withChoir = false;
  bool _withSolo = false;
  late List<int> _instrumentIds;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // Ionic: selectedInstruments = all groups (orchestra)
    _instrumentIds = widget.data.isOrchestra
        ? widget.data.groups.map((g) => g.id).whereType<int>().toList()
        : <int>[];
    _number.addListener(_onChanged);
    _name.addListener(_onChanged);
  }

  void _onChanged() => setState(() {});

  @override
  void dispose() {
    _prefix.dispose();
    _number.dispose();
    _name.dispose();
    _link.dispose();
    super.dispose();
  }

  bool get _canSave =>
      _number.text.trim().isNotEmpty && _name.text.trim().isNotEmpty && !_saving;

  Future<void> _save() async {
    final number = int.tryParse(_number.text.trim());
    if (number == null) return;
    final prefix = _prefix.text.trim();
    final link = _link.text.trim();
    final key = '$prefix$number';

    if (widget.data.songs.any((s) => '${s.prefix ?? ''}${s.number}' == key)) {
      ToastHelper.showError(context, context.l10n.songsNumberTaken);
      return;
    }
    if (link.isNotEmpty && !SongUtils.isValidHttpUrl(link)) {
      ToastHelper.showError(context, context.l10n.songsInvalidLink);
      return;
    }

    setState(() => _saving = true);
    final created = await ref.read(songNotifierProvider.notifier).createSong(Song(
          number: number,
          name: _name.text.trim(),
          link: link.isEmpty ? null : link,
          withChoir: _withChoir,
          withSolo: _withSolo,
          instrumentIds: _instrumentIds,
          prefix: prefix,
        ));
    if (!mounted) return;
    setState(() => _saving = false);
    if (created == null) {
      ToastHelper.showError(context, context.l10n.songsFlutterCreateFailed);
      return;
    }
    if (widget.onCreated != null && created.id != null) {
      widget.onCreated!(created.id!);
    } else {
      Navigator.of(context).pop(created.id);
    }
  }

  Future<void> _pickInstruments() async {
    final groups = widget.data.instruments;
    final selection = [..._instrumentIds];
    final result = await showDialog<List<int>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(context.l10n.songsInstrumentation),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final g in groups)
                  CheckboxListTile(
                    title: Text(g.name),
                    value: selection.contains(g.id),
                    onChanged: (v) => setLocal(() {
                      v == true ? selection.add(g.id!) : selection.remove(g.id);
                    }),
                  ),
              ],
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
    if (result != null) setState(() => _instrumentIds = result);
  }

  @override
  Widget build(BuildContext context) {
    final instruments = widget.data.instruments;
    final selectedNames = instruments
        .where((g) => _instrumentIds.contains(g.id))
        .map((g) => g.name)
        .join(', ');

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimensions.paddingM),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    context.l10n.songsAddSong,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            TextField(
              controller: _prefix,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: context.l10n.songsPrefixOptional,
                helperText: context.l10n.songsPrefixHelper,
                helperMaxLines: 2,
              ),
            ),
            const SizedBox(height: AppDimensions.paddingS),
            TextField(
              controller: _number,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: context.l10n.songsNumber),
            ),
            const SizedBox(height: AppDimensions.paddingS),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: context.l10n.songsName),
            ),
            const SizedBox(height: AppDimensions.paddingS),
            TextField(
              controller: _link,
              minLines: 1,
              maxLines: 4,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(labelText: context.l10n.songsLink),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(context.l10n.songsChoirOrchestra),
              value: _withChoir,
              onChanged: (v) => setState(() => _withChoir = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(context.l10n.songsWithSoloSinging),
              value: _withSolo,
              onChanged: (v) => setState(() => _withSolo = v),
            ),
            if (widget.data.isOrchestra)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(context.l10n.songsInstrumentation),
                subtitle: Text(
                  selectedNames.isEmpty ? '-' : selectedNames,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.arrow_drop_down),
                onTap: _pickInstruments,
              ),
            const SizedBox(height: AppDimensions.paddingM),
            ElevatedButton(
              onPressed: _canSave ? _save : null,
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(context.l10n.attendanceAdd),
            ),
          ],
        ),
      ),
    );
  }
}

Future<int?> showAddSongSheet(BuildContext context, SongsListData data) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => AddSongSheet(data: data),
  );
}
