import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:attendix/core/theme/app_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/song_providers.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/song/song.dart';
import '../utils/song_utils.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';
import '../../../../core/theme/redesign/rd_theme.dart' show RdSkinContext;
import '../../../../shared/widgets/dialogs/ion_sheet.dart';
import '../../../../shared/widgets/layout/ionic_ios.dart';
import 'song_form_items.dart';

/// "Werk hinzufügen" (Ionic addSongsModal). Returns the id of the new song.
class AddSongSheet extends ConsumerStatefulWidget {
  const AddSongSheet({
    super.key,
    required this.data,
    this.onCreated,
    this.scrollController,
  });

  final SongsListData data;

  /// The sheet's scroll controller ([showIonSheet]).
  final ScrollController? scrollController;

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
    if (number == null) {
      // WERKE-10: Ionic `type="number"` only takes digits; say why nothing
      // is saved instead of returning silently.
      ToastHelper.showError(context, context.l10n.coreFlutterImportNumberRequired);
      return;
    }
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
          // Ionic addSong writes link = '' for an empty field (not NULL).
          link: link,
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

  List<AppSelectOption<int>> get _instrumentOptions => [
        for (final g in widget.data.instruments)
          if (g.id != null) AppSelectOption(value: g.id!, label: g.name),
      ];

  /// Ionic `ion-select interface="modal" multiple`: every tick counts.
  Future<void> _pickInstruments() async {
    await showAppMultiSelectModal<int>(
      context: context,
      options: _instrumentOptions,
      values: _instrumentIds,
      onChanged: (v) => setState(() => _instrumentIds = v),
    );
  }

  /// Beta design: the alert with checkboxes as before.
  Future<void> _pickInstrumentsBeta() async {
    final groups = widget.data.instruments;
    final selection = [..._instrumentIds];
    final result = await showAppDialog<List<int>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AppAlertDialog(
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

  String get _selectedNames => widget.data.instruments
      .where((g) => _instrumentIds.contains(g.id))
      .map((g) => g.name)
      .join(', ');

  Widget _saveButton() => ElevatedButton(
        onPressed: _canSave ? _save : null,
        child: _saving
            ? const SizedBox(
                width: 18,
                height: 18,
                child: AppSpinner(strokeWidth: 2),
              )
            : IonButtonLabel(context.l10n.attendanceAdd),
      );

  /// Ionic `ion-input type="number"`: digits only.
  static final _digits = [FilteringTextInputFormatter.digitsOnly];

  @override
  Widget build(BuildContext context) {
    if (context.rdSkin != null) return _buildBeta(context);
    // UX_SONGS_SELF: Ionic addSongsModal: toolbar title, plain ion-items
    // (stacked inputs, toggles, the modal select) and the block button.
    final form = ListView(
      controller: widget.scrollController,
      padding: EdgeInsets.only(bottom: 16 + MediaQuery.paddingOf(context).bottom),
      children: [
        SongStackedInput(
          controller: _prefix,
          label: context.l10n.songsPrefixOptional,
          helperText: context.l10n.songsPrefixHelper,
        ),
        SongStackedInput(
          controller: _number,
          label: context.l10n.songsNumber,
          keyboardType: TextInputType.number,
          inputFormatters: _digits,
        ),
        SongStackedInput(controller: _name, label: context.l10n.songsName),
        SongStackedInput(
          controller: _link,
          label: context.l10n.songsLink,
          minLines: 1,
          maxLines: 4,
          keyboardType: TextInputType.url,
        ),
        SongToggleItem(
          label: context.l10n.songsChoirOrchestra,
          value: _withChoir,
          onChanged: (v) => setState(() => _withChoir = v),
        ),
        SongToggleItem(
          label: context.l10n.songsWithSoloSinging,
          value: _withSolo,
          onChanged: (v) => setState(() => _withSolo = v),
        ),
        if (widget.data.isOrchestra)
          SongSelectItem(
            label: context.l10n.songsInstrumentation,
            text: _selectedNames,
            onTap: _instrumentOptions.isEmpty ? null : _pickInstruments,
          ),
        // `ion-button expand="block"` (margin 4px 2px).
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 12, 2, 4),
          child: _saveButton(),
        ),
      ],
    );
    if (widget.onCreated != null) return form;
    return IonSheetScaffold(title: context.l10n.songsAddSong, body: form);
  }

  Widget _buildBeta(BuildContext context) {
    final selectedNames = _selectedNames;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          IonSheetHeader(title: context.l10n.songsAddSong),
          Flexible(
            child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimensions.paddingM),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _prefix,
              textCapitalization: TextCapitalization.sentences,
              decoration: ionInputDecoration(
                context,
                label: context.l10n.songsPrefixOptional,
                helperText: context.l10n.songsPrefixHelper,
              ),
            ),
            const SizedBox(height: AppDimensions.paddingS),
            TextField(
              controller: _number,
              keyboardType: TextInputType.number,
              inputFormatters: _digits,
              decoration: ionInputDecoration(context, label: context.l10n.songsNumber),
            ),
            const SizedBox(height: AppDimensions.paddingS),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.sentences,
              decoration: ionInputDecoration(context, label: context.l10n.songsName),
            ),
            const SizedBox(height: AppDimensions.paddingS),
            TextField(
              controller: _link,
              minLines: 1,
              maxLines: 4,
              keyboardType: TextInputType.url,
              decoration: ionInputDecoration(context, label: context.l10n.songsLink),
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: Text(context.l10n.songsChoirOrchestra),
              value: _withChoir,
              onChanged: (v) => setState(() => _withChoir = v),
            ),
            SwitchListTile.adaptive(
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
                trailing: Icon(AppIcons.arrowDropDown),
                onTap: _pickInstrumentsBeta,
              ),
            const SizedBox(height: AppDimensions.paddingM),
            _saveButton(),
          ],
        ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Werk hinzufügen": Ionic `ion-modal [breakpoints]="[0, 1]"
/// [initialBreakpoint]="1"` (Beta: the content-high sheet as before).
Future<int?> showAddSongSheet(BuildContext context, SongsListData data) {
  if (context.rdSkin != null) {
    return showModalBottomSheet<int>(
      context: context,
      useRootNavigator: true, // IOS_SHELL2: above the tab bar
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => AddSongSheet(data: data),
    );
  }
  return showIonSheet<int>(
    context,
    breakpoints: const [0, 1],
    initialBreakpoint: 1,
    builder: (_, controller) => AddSongSheet(data: data, scrollController: controller),
  );
}
