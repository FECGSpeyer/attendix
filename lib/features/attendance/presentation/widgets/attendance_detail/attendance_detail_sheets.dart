import 'package:flutter/material.dart';
import 'package:attendix/shared/widgets/dialogs/ion_sheet.dart';
import 'package:attendix/core/theme/app_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../../core/config/supabase_config.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/redesign/rd_theme.dart';
import '../../../../../data/models/person/person.dart';
import '../../../../../l10n/l10n.dart';
import '../../../../../core/utils/error_message.dart';
import '../../../../../shared/widgets/adaptive/adaptive.dart';
import '../../../../planning/presentation/widgets/rd_plan_widgets.dart';
import '../../../../redesign/presentation/widgets/rd_widgets.dart';

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

  final choice = await showAppActionSheet<String>(
    context,
    title: context.l10n.attendanceAddNote,
    message: hasNote ? context.l10n.attendanceCurrentNote(currentNote ?? '') : null,
    actions: [
      for (final reason in presetReasons)
        AppActionSheetAction(value: reason, label: reason),
      AppActionSheetAction(
        value: custom,
        label: context.l10n.attendanceCustomNoteEllipsis,
      ),
      if (hasNote)
        AppActionSheetAction(
          value: delete,
          label: context.l10n.attendanceDeleteNote,
          destructive: true,
        ),
    ],
  );

  if (choice == null) return null;
  if (choice == delete) return '';
  if (choice != custom) return choice;
  if (!context.mounted) return null;

  // Custom note: prefill only when the current note is not a preset reason.
  final isPreset = hasNote && presetReasons.contains(currentNote);
  final controller = TextEditingController(text: isPreset ? '' : (currentNote ?? ''));
  final result = await showAppDialog<String>(
    context: context,
    builder: (ctx) => AppAlertDialog(
      title: Text(context.l10n.attendanceCustomNote),
      // Ionic alert input `type: 'textarea'` (attendance.page.ts).
      content: AppAlertInput(
        controller: controller,
        autofocus: true,
        maxLines: 4,
        minLines: 2,
        textarea: true,
        textCapitalization: TextCapitalization.sentences,
        placeholder: context.l10n.attendanceEnterNote,
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
  if (context.rdSkin != null) {
    return _rdConductorChange(
      context,
      conductors: conductors,
      selected: selected,
      currentOtherConductor: currentOtherConductor,
    );
  }

  final picked = await showAppDialog<int>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AppAlertDialog(
        title: Text(context.l10n.attendanceChangeConductor),
        // Ionic alert with `type: 'radio'` inputs (attendance.page.ts
        // changeConductor).
        content: AppAlertRadioGroup<int>(
          options: [
            for (final con in conductors) AppAlertOption(con.id!, con.fullName),
            AppAlertOption(otherValue, context.l10n.attListOtherConductor),
          ],
          groupValue: selected,
          onChanged: (v) => setState(() => selected = v),
          // Beta design: the list as before (12 px above, full width).
          beta: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: SizedBox(
              width: double.maxFinite,
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final con in conductors)
                    // ignore: deprecated_member_use
                    RadioListTile<int>(
                      value: con.id!,
                      // ignore: deprecated_member_use
                      groupValue: selected,
                      // ignore: deprecated_member_use
                      onChanged: (v) => setState(() => selected = v),
                      title: Text(con.fullName),
                    ),
                  // ignore: deprecated_member_use
                  RadioListTile<int>(
                    value: otherValue,
                    // ignore: deprecated_member_use
                    groupValue: selected,
                    // ignore: deprecated_member_use
                    onChanged: (v) => setState(() => selected = v),
                    title: Text(context.l10n.attListOtherConductor),
                  ),
                ],
              ),
            ),
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
  final name = await showAppDialog<String>(
    context: context,
    builder: (ctx) => AppAlertDialog(
      title: Text(context.l10n.attListEnterConductor),
      content: AppAlertInput(
        controller: controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        placeholder: context.l10n.attListConductor,
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

/// Beta (redesign) "Dirigent ändern": tapping a row picks it; "Anderer
/// Dirigent" asks for the name in a Beta text sheet.
Future<ConductorChoice?> _rdConductorChange(
  BuildContext context, {
  required List<Person> conductors,
  required int? selected,
  required String? currentOtherConductor,
}) async {
  const otherValue = -1;
  final picked = await showRdPlanSheet<int>(
    context,
    title: context.l10n.attendanceChangeConductor,
    builder:
        (ctx, pop) => [
          RdGroupedList(
            children: [
              for (final con in conductors)
                RdListRow(
                  title: con.fullName,
                  selected: selected == con.id,
                  trailing: RdSheetCheck(selected == con.id),
                  showChevron: false,
                  onTap: () => pop(con.id!),
                ),
              RdListRow(
                title: ctx.l10n.attListOtherConductor,
                subtitle: selected == otherValue ? currentOtherConductor : null,
                selected: selected == otherValue,
                trailing: RdSheetCheck(selected == otherValue),
                showChevron: false,
                onTap: () => pop(otherValue),
              ),
            ],
          ),
        ],
  );
  if (picked == null) return null;
  if (picked != otherValue) {
    final person = conductors.where((c) => c.id == picked).firstOrNull;
    return person == null ? null : ConductorChoice(person: person);
  }
  if (!context.mounted) return null;
  final name = await showRdPlanTextSheet(
    context,
    title: context.l10n.attListEnterConductor,
    initialValue: currentOtherConductor ?? '',
    hint: context.l10n.attListConductor,
  );
  if (name == null || name.trim().isEmpty) return null;
  return ConductorChoice(otherConductor: name.trim());
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
  if (context.rdSkin == null) {
    // Ionic files-folder-picker: [breakpoints]="[0, 1]" [initialBreakpoint]="1".
    return showIonSheet<String>(
      context,
      builder: (ctx, controller) => _FilesFolderPicker(
        supabase: supabase,
        tenantId: tenantId,
        initialPath: initialPath,
        scrollController: controller,
      ),
    );
  }
  return showModalBottomSheet<String>(
    backgroundColor: context.rdSkin != null ? context.rd.bg : null,
    context: context,
    useRootNavigator: true, // IOS_SHELL2: above the tab bar
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
    this.scrollController,
  });

  final SupabaseClient supabase;
  final int tenantId;
  final String initialPath;

  /// Classic design: the controller of the breakpoint sheet.
  final ScrollController? scrollController;

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

  String _child(String folder) => _path.isEmpty ? folder : '$_path/$folder';

  /// Beta (redesign) layout: breadcrumb chips, one grouped list of folders.
  Widget _buildBeta(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final segments = _segments;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          children: [
            Semantics(header: true, child: Text(l10n.folderPickerTitle, style: RdType.cardTitle(p))),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                RdChoiceChip(label: l10n.filesTitle, selected: segments.isEmpty, onTap: () => _navigate('')),
                for (var i = 0; i < segments.length; i++)
                  RdChoiceChip(
                    label: segments[i],
                    selected: i == segments.length - 1,
                    onTap: () => _navigate(segments.sublist(0, i + 1).join('/')),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (segments.isNotEmpty) ...[
              RdPrimaryButton(
                key: const Key('rd-folder-choose-this'),
                label: '${l10n.folderPickerChooseThis}: ${segments.last}',
                icon: Icons.check,
                onPressed: _loading ? null : () => Navigator.pop(context, _path),
              ),
              const SizedBox(height: 16),
            ],
            RdGroupedList(
              children: [
                if (segments.isNotEmpty)
                  RdListRow(
                    title: l10n.folderPickerParent,
                    leading: const RdRowIcon(Icons.arrow_upward),
                    showChevron: false,
                    onTap: () => _navigate(segments.sublist(0, segments.length - 1).join('/')),
                  ),
                if (_loading)
                  const Padding(padding: EdgeInsets.all(24), child: Center(child: AppSpinner()))
                else ...[
                  for (final folder in _folders)
                    RdListRow(
                      title: folder,
                      leading: const RdRowIcon(Icons.folder_outlined),
                      trailing: TextButton(
                        onPressed: () => Navigator.pop(context, _child(folder)),
                        child: Text(l10n.folderPickerChoose, style: TextStyle(color: p.link)),
                      ),
                      showChevron: false,
                      onTap: () => _navigate(_child(folder)),
                    ),
                  if (_folders.isEmpty)
                    RdListRow(
                      title: _error ?? l10n.folderPickerNoSubfolders,
                      titleColor: _error != null ? p.absent : p.text2,
                      showChevron: false,
                    ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (context.rdSkin != null) return _buildBeta(context);
    final segments = _segments;
    // Ionic: ion-toolbar with ✕ (start), title, checkmark (end, disabled at
    // the root or while loading); second toolbar with the breadcrumbs.
    return IonSheetScaffold(
      title: context.l10n.folderPickerTitle,
      start: [
        IconButton(
          tooltip: context.l10n.commonCancel,
          icon: Icon(AppIcons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ],
      end: [
        IconButton(
          tooltip: context.l10n.folderPickerChooseThis,
          icon: Icon(AppIcons.check),
          onPressed: _path.isEmpty || _loading ? null : () => Navigator.pop(context, _path),
        ),
      ],
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  TextButton(onPressed: () => _navigate(''), child: Icon(AppIcons.homeOutlined)),
                  for (var i = 0; i < segments.length; i++) ...[
                    Icon(AppIcons.chevronRight, size: 16, color: AppColors.medium),
                    TextButton(
                      onPressed: () => _navigate(segments.sublist(0, i + 1).join('/')),
                      child: Text(segments[i]),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
                controller: widget.scrollController,
                padding: EdgeInsets.zero,
                children: [
                  if (segments.isNotEmpty) ...[
                    // Ionic files-folder-picker: first row in primary,
                    // "Diesen Ordner wählen: {Ordner}", disabled while loading.
                    ListTile(
                      enabled: !_loading,
                      tileColor: AppColors.primary,
                      iconColor: Colors.white,
                      textColor: Colors.white,
                      leading: Icon(AppIcons.checkCircleOutline),
                      title: Text('${context.l10n.folderPickerChooseThis}: ${segments.last}'),
                      onTap: () => Navigator.pop(context, _path),
                    ),
                    ListTile(
                      leading: Icon(AppIcons.arrowUpward),
                      title: Text(context.l10n.folderPickerParent),
                      onTap: () => _navigate(segments.sublist(0, segments.length - 1).join('/')),
                    ),
                  ],
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: AppSpinner()),
                    )
                  else ...[
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(_error!, style: const TextStyle(color: AppColors.danger)),
                      ),
                    for (final folder in _folders)
                      ListTile(
                        leading: Icon(AppIcons.folderOutlined, color: AppColors.primary),
                        title: Text(folder),
                        trailing: TextButton(
                          onPressed: () => Navigator.pop(
                            context,
                            _path.isEmpty ? folder : '$_path/$folder',
                          ),
                          child: IonButtonLabel(context.l10n.folderPickerChoose),
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
                ],
        ),
      ),
    );
  }
}
