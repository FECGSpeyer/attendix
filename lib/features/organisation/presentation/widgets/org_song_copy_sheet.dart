import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/org_song_providers.dart';
import '../../../../core/providers/song_providers.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/design_theme.dart';
import '../../../../core/utils/demo_guard.dart';
import '../../../../core/utils/dialog_helper.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../core/utils/song_copy.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/instrument/instrument.dart';
import '../../../../data/models/song/org_song.dart';
import '../../../../data/models/song/song.dart';
import '../../../../data/models/tenant/tenant.dart' show ExtraField;
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart' show AppActionSheetAction, showAppActionSheet;
import '../../../../shared/widgets/components/components.dart';
import '../../../attendance/presentation/widgets/event/form_widgets.dart' show RdFieldRow, rdInputDecoration;
import '../../../settings/presentation/widgets/manage/settings_sheets.dart' show RdListNote, RdSheetHead;
import '../../../songs/presentation/utils/song_utils.dart';

part 'org_song_copy_actions.dart';

/// Opens the copy sheet for an organisation-wide Werk match.
/// [onCopied] receives the target library id once the copy completes.
Future<void> showOrgSongCopySheet(
  BuildContext context, {
  required OrgSongResult source,
  required List<OrgSongCopyTarget> targets,
  required List<OrgSongTenant> orgTenants,
  void Function(int libraryId)? onCopied,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: context.rd.bg,
    builder: (sheetCtx) => SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(sheetCtx).height * 0.90),
        child: OrgSongCopySheet(
          source: source,
          targets: targets,
          orgTenants: orgTenants,
          onCopied: onCopied,
        ),
      ),
    ),
  );
}

/// Redesign modal sheet for copying a shared organisation Werk into a target
/// library, either merging into an existing match or creating a new entry.
class OrgSongCopySheet extends ConsumerStatefulWidget {
  const OrgSongCopySheet({
    super.key,
    required this.source,
    required this.targets,
    required this.orgTenants,
    this.onCopied,
  });

  final OrgSongResult source;
  final List<OrgSongCopyTarget> targets;
  final List<OrgSongTenant> orgTenants;
  final void Function(int libraryId)? onCopied;

  @override
  ConsumerState<OrgSongCopySheet> createState() => _OrgSongCopySheetState();
}

class _OrgSongCopySheetState extends ConsumerState<OrgSongCopySheet> {
  late int _targetLibraryId = widget.targets.first.libraryId;
  bool _loadingTarget = false;
  List<Song> _targetSongs = const [];
  Map<int, Map<String, dynamic>> _targetRows = const {};
  List<Group> _targetGroups = const [];
  List<Song> _duplicates = const [];
  _Mode _mode = _Mode.created;
  int? _existingSongId;
  final _prefix = TextEditingController();
  final _number = TextEditingController();
  List<_FieldOption> _fieldOptions = const [];
  List<_FileOption> _fileOptions = const [];
  bool _copying = false;
  String? _progress;

  OrgSongResult get _song => widget.source;

  void _update(VoidCallback fn) => setState(fn);

  @override
  void initState() {
    super.initState();
    _loadTarget();
  }

  @override
  void dispose() {
    _prefix.dispose();
    _number.dispose();
    super.dispose();
  }

  OrgSongCopyTarget? get _currentTarget =>
      widget.targets.where((t) => t.libraryId == _targetLibraryId).firstOrNull;

  int? get _numberValue => int.tryParse(_number.text.trim());

  bool get _numberTaken => isSongNumberTaken(_numberValue, _prefix.text, _targetSongs);

  int get _nextFreeNumber => nextFreeSongNumber(_prefix.text, _targetSongs);

  Song? get _existingSong =>
      _mode == _Mode.existing ? _targetSongs.where((s) => s.id == _existingSongId).firstOrNull : null;

  int get _selectedFileCount => _fileOptions.where((f) => f.checked).length;

  bool get _canCopy {
    if (_copying || _loadingTarget) return false;
    if (_mode == _Mode.existing) {
      return _existingSong != null && (_selectedFileCount > 0 || _fieldOptions.any((f) => f.checked));
    }
    return _numberValue != null && !_numberTaken;
  }

  /// Song extra field definitions of the target library.
  List<ExtraField> get _targetFieldDefs =>
      widget.orgTenants.where((t) => t.id == _targetLibraryId).firstOrNull?.songAdditionalFields ??
      _currentTarget?.tenant.songAdditionalFields ??
      const [];

  List<Group> get _availableTargetGroups =>
      _targetGroups.where((g) => g.id != null && !reservedFileGroupIds.contains(g.id)).toList();

  int? _validTargetGroupId(int? instrumentId, List<Group> groups) {
    final valid = <int?>{null, 1, 2, for (final g in groups) g.id};
    return valid.contains(instrumentId) ? instrumentId : null;
  }

  static bool _isEmpty(dynamic value) =>
      value == null || value == '' || (value is List && value.isEmpty) || (value is Map && value.isEmpty);

  void _toggleAllFiles() {
    _update(() {
      final selectAll = _selectedFileCount < _fileOptions.length;
      for (final f in _fileOptions) {
        f.checked = selectAll;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    return PopScope(
      canPop: !_copying,
      child: Column(
        children: [
          RdSheetHead(title: l10n.songsCopySong, cancel: !_copying),
          if (_copying) LinearProgressIndicator(minHeight: 2, color: p.primary, backgroundColor: p.track),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              children: [
                _buildSourceCard(p, l10n),
                const SizedBox(height: 16),
                _buildTargetSection(l10n),
                if (_loadingTarget)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Center(child: CircularProgressIndicator(color: p.primary)),
                  )
                else
                  ..._buildTargetDetails(context),
                if (_progress != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(_progress!, textAlign: TextAlign.center, style: RdType.meta(p, size: 13)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSourceCard(RdPalette p, AppLocalizations l10n) {
    return RdCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(orgSongLabel(_song.prefix, _song.number, _song.name), style: RdType.cardTitle(p)),
          const SizedBox(height: 2),
          Text(l10n.orgSongsFromTenant(_song.tenantName), style: RdType.meta(p, size: 13)),
        ],
      ),
    );
  }

  Widget _buildTargetSection(AppLocalizations l10n) {
    final target = _currentTarget;
    final canSwitch = !_copying && widget.targets.length > 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RdGroupLabel(l10n.orgSongsTarget),
        RdGroupedList(
          children: [
            RdListRow(
              key: const Key('org-copy-target'),
              title: l10n.personTargetInstance,
              value: target?.tenant.shortName ?? '',
              showChevron: canSwitch,
              onTap: canSwitch ? _pickTarget : null,
            ),
            if (target?.libraryName != null)
              RdListRow(
                leading: const RdRowIcon(Icons.sync),
                title: l10n.orgSongsSyncedTarget(target!.tenant.shortName, target.libraryName!),
                showChevron: false,
              ),
          ],
        ),
      ],
    );
  }

  List<Widget> _buildTargetDetails(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    return [
      if (_duplicates.isNotEmpty) ...[
        const SizedBox(height: 16),
        _buildDuplicateSection(p, l10n),
      ],
      if (_mode == _Mode.created) ...[
        const SizedBox(height: 16),
        _buildNumberSection(p, l10n),
      ],
      if (_fieldOptions.isNotEmpty) ...[
        const SizedBox(height: 16),
        RdGroupLabel(l10n.orgSongsFields),
        RdGroupedList(children: [for (final option in _fieldOptions) _buildFieldRow(p, l10n, option)]),
      ],
      if (_fileOptions.isNotEmpty) ...[
        const SizedBox(height: 16),
        _buildFilesHeader(p, l10n),
        RdGroupedList(children: [for (final option in _fileOptions) _buildFileRow(p, l10n, option)]),
      ],
      RdListNote(l10n.orgSongsCopyHint),
      const SizedBox(height: 12),
      RdPrimaryButton(
        key: const Key('org-copy-submit'),
        label: _mode == _Mode.existing ? l10n.orgSongsCopyIntoExisting : l10n.orgSongsCopyAsNew,
        loading: _copying,
        onPressed: _canCopy ? _copy : null,
      ),
    ];
  }

  Widget _buildDuplicateSection(RdPalette p, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(color: p.lateSoft, borderRadius: BorderRadius.circular(p.cardRadius)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: p.late),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.orgSongsDuplicateWarning(_duplicates.length),
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: p.text),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        RdGroupedList(
          children: [
            RdListRow(
              key: const Key('org-copy-mode-existing'),
              leading: Icon(
                _mode == _Mode.existing ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                color: _mode == _Mode.existing ? p.primary : p.text2,
              ),
              title: l10n.orgSongsModeExisting,
              selected: _mode == _Mode.existing,
              showChevron: false,
              onTap: _copying ? null : () => _onModeChange(_Mode.existing),
            ),
            if (_mode == _Mode.existing && _duplicates.length > 1)
              RdListRow(
                key: const Key('org-copy-existing-song'),
                title: l10n.orgSongsExistingSong,
                value: _existingSong != null
                    ? orgSongLabel(_existingSong!.prefix, _existingSong!.number, _existingSong!.name)
                    : '',
                showChevron: !_copying,
                onTap: _copying ? null : _pickExistingSong,
              ),
            RdListRow(
              key: const Key('org-copy-mode-new'),
              leading: Icon(
                _mode == _Mode.created ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                color: _mode == _Mode.created ? p.primary : p.text2,
              ),
              title: l10n.orgSongsModeNew,
              selected: _mode == _Mode.created,
              showChevron: false,
              onTap: _copying ? null : () => _onModeChange(_Mode.created),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNumberSection(RdPalette p, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RdGroupLabel(l10n.orgSongsNumber),
        RdGroupedList(
          children: [
            RdFieldRow(
              label: l10n.orgSongsPrefix,
              child: TextField(
                key: const Key('org-copy-prefix'),
                controller: _prefix,
                enabled: !_copying,
                maxLength: 5,
                style: RdType.body(p),
                decoration: rdInputDecoration(p, '').copyWith(counterText: ''),
                onChanged: (_) => _update(() {}),
              ),
            ),
            RdFieldRow(
              label: l10n.orgSongsNumber,
              child: TextField(
                key: const Key('org-copy-number'),
                controller: _number,
                enabled: !_copying,
                keyboardType: TextInputType.number,
                style: RdType.body(p).copyWith(color: _numberTaken ? p.absent : p.text),
                decoration: rdInputDecoration(p, ''),
                onChanged: (_) => _update(() {}),
              ),
            ),
            if (_numberTaken)
              RdListRow(
                key: const Key('org-copy-next-free'),
                leading: RdRowIcon(Icons.error_outline, color: p.absent, background: p.absentSoft),
                title: l10n.orgSongsNumberTaken,
                titleColor: p.absent,
                subtitle: l10n.orgSongsUseNextFree('${_prefix.text}$_nextFreeNumber'),
                showChevron: false,
                onTap: () => _update(() => _number.text = '$_nextFreeNumber'),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildFieldRow(RdPalette p, AppLocalizations l10n, _FieldOption option) {
    return InkWell(
      onTap: _copying ? null : () => _update(() => option.checked = !option.checked),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: option.checked,
              activeColor: p.primary,
              onChanged: _copying ? null : (v) => _update(() => option.checked = v ?? false),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 10, right: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(option.label, style: RdType.body(p).copyWith(fontWeight: FontWeight.w500)),
                    const SizedBox(height: 2),
                    Text(option.value, style: RdType.meta(p, size: 13)),
                    if (option.currentValue != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          l10n.orgSongsCurrentValue(option.currentValue!),
                          style: TextStyle(fontSize: 13, color: p.late),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilesHeader(RdPalette p, AppLocalizations l10n) {
    final linkLabel = _selectedFileCount < _fileOptions.length ? l10n.orgSongsSelectAll : l10n.orgSongsSelectNone;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                l10n.orgSongsFiles(_selectedFileCount, _fileOptions.length).toUpperCase(),
                style: RdType.eyebrow(p.text2),
              ),
            ),
          ),
          if (!_copying) ...[
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 160),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: RdTextLink(label: linkLabel, onTap: _toggleAllFiles),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFileRow(RdPalette p, AppLocalizations l10n, _FileOption option) {
    final groups = _availableTargetGroups;
    final selectedGroupId = _validTargetGroupId(option.instrumentId, groups);
    final groupLabel = _targetGroupLabel(selectedGroupId, l10n);
    final canPickGroup = option.checked && !_copying;

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 14, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: option.checked,
            activeColor: p.primary,
            onChanged: _copying ? null : (v) => _update(() => option.checked = v ?? false),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(option.file.fileName, style: RdType.body(p).copyWith(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text(l10n.orgSongsSourceGroup(_sourceGroupLabel(option.file)), style: RdType.meta(p, size: 13)),
                  if (option.existsInTarget)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(l10n.orgSongsFileExists, style: TextStyle(fontSize: 13, color: p.late)),
                    ),
                  const SizedBox(height: 8),
                  _FileGroupChip(
                    label: '${l10n.orgSongsTargetGroup}: $groupLabel',
                    enabled: canPickGroup,
                    onTap: canPickGroup ? () => _pickFileGroup(option) : null,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FileGroupChip extends StatelessWidget {
  const _FileGroupChip({required this.label, required this.enabled, required this.onTap});

  final String label;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    return Material(
      color: p.track,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: enabled ? p.text : p.text2,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.expand_more, size: 16, color: p.text2),
            ],
          ),
        ),
      ),
    );
  }
}
