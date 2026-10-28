import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../../core/config/supabase_config.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../data/models/person/person.dart';
import '../../../../../l10n/l10n.dart';
import '../../../../../core/utils/error_message.dart';

/// Result of [showPersonNoteSheet]: `null` = cancelled, `''` = delete note,
/// anything else = the new note.
///
/// Ionic `attendance.page.ts#addNote`: preset reasons, "Eigene Notiz...",
/// "Notiz löschen" (destructive) under the header "Notiz hinzufügen".
Future<String?> showPersonNoteSheet(
  BuildContext context, {
  required String? currentNote,
  required List<String> presetReasons,
}) async {
  const custom = '__custom__';
  const delete = '__delete__';
  final hasNote = currentNote?.isNotEmpty == true;

  final choice = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.l10n.attendanceAddNote, style: Theme.of(ctx).textTheme.titleMedium),
                  if (hasNote)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        context.l10n.attendanceCurrentNote(currentNote ?? ''),
                        style: const TextStyle(color: AppColors.medium),
                      ),
                    ),
                ],
              ),
            ),
            for (final reason in presetReasons)
              ListTile(
                title: Text(reason),
                onTap: () => Navigator.pop(ctx, reason),
              ),
            ListTile(
              title: Text(context.l10n.attendanceCustomNoteEllipsis),
              onTap: () => Navigator.pop(ctx, custom),
            ),
            if (hasNote)
              ListTile(
                title: Text(context.l10n.attendanceDeleteNote, style: const TextStyle(color: AppColors.danger)),
                onTap: () => Navigator.pop(ctx, delete),
              ),
            ListTile(
              title: Text(context.l10n.commonCancel),
              onTap: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    ),
  );

  if (choice == null) return null;
  if (choice == delete) return '';
  if (choice != custom) return choice;
  if (!context.mounted) return null;

  // Custom note: prefill only when the current note is not a preset reason.
  final isPreset = hasNote && presetReasons.contains(currentNote);
  final controller = TextEditingController(text: isPreset ? '' : (currentNote ?? ''));
  final result = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(context.l10n.attendanceCustomNote),
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLines: 4,
        minLines: 2,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(hintText: context.l10n.attendanceEnterNote),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.l10n.commonCancel)),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, controller.text.trim()),
          child: Text(context.l10n.commonSave),
        ),
      ],
    ),
  );
  controller.dispose();
  return result;
}

/// Selected conductor from [showConductorChangeDialog].
class ConductorChoice {
  const ConductorChoice({this.person, this.otherConductor});

  final Person? person;
  final String? otherConductor;
}

/// "Dirigent ändern": radio list of active conductors plus "Anderer Dirigent"
/// (asks for a name via "Dirigent eingeben").
Future<ConductorChoice?> showConductorChangeDialog(
  BuildContext context, {
  required List<Person> conductors,
  int? currentConductorId,
  String? currentOtherConductor,
}) async {
  const otherValue = -1;
  final hasOther = currentOtherConductor?.isNotEmpty == true;
  int? selected = hasOther ? otherValue : currentConductorId;

  final picked = await showDialog<int>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: Text(context.l10n.attendanceChangeConductor),
        contentPadding: const EdgeInsets.only(top: 12),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final con in conductors)
                RadioListTile<int>(
                  value: con.id!,
                  groupValue: selected,
                  onChanged: (v) => setState(() => selected = v),
                  title: Text(con.fullName),
                ),
              RadioListTile<int>(
                value: otherValue,
                groupValue: selected,
                onChanged: (v) => setState(() => selected = v),
                title: Text(context.l10n.attListOtherConductor),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.l10n.commonCancel)),
          FilledButton(
            onPressed: selected == null ? null : () => Navigator.pop(ctx, selected),
            child: Text(context.l10n.commonSave),
          ),
        ],
      ),
    ),
  );

  if (picked == null) return null;
  if (picked != otherValue) {
    final person = conductors.where((c) => c.id == picked).firstOrNull;
    return person == null ? null : ConductorChoice(person: person);
  }
  if (!context.mounted) return null;

  final controller = TextEditingController(text: currentOtherConductor ?? '');
  final name = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(context.l10n.attListEnterConductor),
      content: TextField(
        controller: controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(hintText: context.l10n.attListConductor),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.l10n.commonCancel)),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, controller.text.trim()),
          child: Text(context.l10n.commonSave),
        ),
      ],
    ),
  );
  controller.dispose();
  if (name == null || name.isEmpty) return null;
  return ConductorChoice(otherConductor: name);
}

/// Folder picker for the Dateiablage (Ionic `FilesFolderPickerComponent`).
///
/// Lists the storage bucket `files` below the tenant prefix `{tenantId}/`
/// and returns the selected folder relative to that prefix.
Future<String?> showFilesFolderPicker(
  BuildContext context, {
  required int tenantId,
  String initialPath = '',
}) {
  final supabase = ProviderScope.containerOf(context, listen: false).read(supabaseClientProvider);
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => _FilesFolderPicker(
      supabase: supabase,
      tenantId: tenantId,
      initialPath: initialPath,
    ),
  );
}

class _FilesFolderPicker extends StatefulWidget {
  const _FilesFolderPicker({
    required this.supabase,
    required this.tenantId,
    required this.initialPath,
  });

  final SupabaseClient supabase;
  final int tenantId;
  final String initialPath;

  @override
  State<_FilesFolderPicker> createState() => _FilesFolderPickerState();
}

class _FilesFolderPickerState extends State<_FilesFolderPicker> {
  String _path = '';
  List<String> _folders = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _navigate(widget.initialPath);
  }

  Future<void> _navigate(String path) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Storage is namespaced per tenant: every key starts with "{tenantId}/".
      final prefix = path.isEmpty ? '${widget.tenantId}' : '${widget.tenantId}/$path';
      final items = await widget.supabase.storage.from('files').list(
            path: prefix,
            searchOptions: const SearchOptions(
              limit: 1000,
              sortBy: SortBy(column: 'name', order: 'asc'),
            ),
          );
      if (!mounted) return;
      setState(() {
        _path = path;
        // Folders are the placeholder entries without an object id.
        _folders = items.where((i) => i.id == null && i.name != '.keep').map((i) => i.name).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      if (path.isNotEmpty) {
        // The folder may no longer exist – back to the root.
        await _navigate('');
        return;
      }
      setState(() {
        _loading = false;
        _error = context.l10n.folderPickerLoadFailed(friendlyErrorMessage(e));
      });
    }
  }

  List<String> get _segments => _path.split('/').where((s) => s.isNotEmpty).toList();

  @override
  Widget build(BuildContext context) {
    final segments = _segments;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(context.l10n.folderPickerTitle, style: Theme.of(context).textTheme.titleMedium),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  TextButton(onPressed: () => _navigate(''), child: const Icon(Icons.home_outlined)),
                  for (var i = 0; i < segments.length; i++) ...[
                    const Icon(Icons.chevron_right, size: 16, color: AppColors.medium),
                    TextButton(
                      onPressed: () => _navigate(segments.sublist(0, i + 1).join('/')),
                      child: Text(segments[i]),
                    ),
                  ],
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: _loading
                  ? const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : ListView(
                      shrinkWrap: true,
                      children: [
                        if (_error != null)
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(_error!, style: const TextStyle(color: AppColors.danger)),
                          ),
                        if (segments.isNotEmpty)
                          ListTile(
                            leading: const Icon(Icons.arrow_upward),
                            title: Text(context.l10n.folderPickerParent),
                            onTap: () => _navigate(segments.sublist(0, segments.length - 1).join('/')),
                          ),
                        for (final folder in _folders)
                          ListTile(
                            leading: const Icon(Icons.folder_outlined),
                            title: Text(folder),
                            trailing: TextButton(
                              onPressed: () => Navigator.pop(
                                context,
                                _path.isEmpty ? folder : '$_path/$folder',
                              ),
                              child: Text(context.l10n.folderPickerChoose),
                            ),
                            onTap: () => _navigate(_path.isEmpty ? folder : '$_path/$folder'),
                          ),
                        if (_folders.isEmpty && _error == null)
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              context.l10n.folderPickerNoSubfolders,
                              style: const TextStyle(color: AppColors.medium),
                            ),
                          ),
                      ],
                    ),
            ),
            if (_path.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(12),
                child: FilledButton.icon(
                  onPressed: () => Navigator.pop(context, _path),
                  icon: const Icon(Icons.check),
                  label: Text(context.l10n.folderPickerChooseThis),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
