import 'package:flutter/material.dart';
import 'package:attendix/core/theme/app_icons.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/dialog_helper.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/storage/storage_entry.dart';
import '../../../../data/repositories/files_repository.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';
import '../../../../shared/widgets/dialogs/ion_modal.dart' show showIonModal;
import '../../../../shared/widgets/layout/ionic_ios.dart' show IonInsetList;
import '../../../../core/theme/redesign/rd_theme.dart' show RdSkinContext;
import '../../data/file_move.dart';
import 'settings_list.dart';

/// Ionic 4.19.1 `FilesMoveModalComponent`: picks the target folder for
/// moving entries of the Dateiablage from the folder structure shown as an
/// expandable tree (plus "new folder" right in the dialog). Returns the
/// target path (relative to the tenant root, '' = root) or null.
Future<String?> showFilesMoveModal(
  BuildContext context, {
  required FilesRepository repo,
  required List<StorageEntry> items,
  required String currentPath,
}) {
  Widget build(BuildContext _) =>
      FilesMoveModal(repo: repo, items: items, currentPath: currentPath);
  if (useIosLook(context)) {
    return showIosCardModal<String>(
      context,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? null
          : AppColors.light,
      builder: build,
    );
  }
  return showIonModal<String>(context, builder: build);
}

class _FolderNode {
  _FolderNode(this.name, this.path, this.depth);

  final String name;
  final String path;
  final int depth;
  bool expanded = false;
  bool loaded = false;
  bool loading = false;
  List<_FolderNode> children = [];
}

class FilesMoveModal extends StatefulWidget {
  const FilesMoveModal({
    super.key,
    required this.repo,
    required this.items,
    required this.currentPath,
  });

  final FilesRepository repo;
  final List<StorageEntry> items;

  /// Folder the entries are moved from – expanded when the dialog opens.
  final String currentPath;

  @override
  State<FilesMoveModal> createState() => _FilesMoveModalState();
}

class _FilesMoveModalState extends State<FilesMoveModal> {
  final _root = _FolderNode('', '', 0);
  String? _selectedPath;

  late final List<MoveItem> _moveItems = [
    for (final e in widget.items) MoveItem(path: e.path, isFolder: e.isFolder),
  ];

  @override
  void initState() {
    super.initState();
    _expandToCurrent();
  }

  /// Expands the path down to the current folder, so one sees where one is.
  Future<void> _expandToCurrent() async {
    final chain = ancestorFilePaths(widget.currentPath);
    _FolderNode? node = _root;
    for (var i = 0; node != null && i < chain.length; i++) {
      node.expanded = true;
      await _loadChildren(node);
      if (i + 1 >= chain.length) break;
      final next = chain[i + 1];
      node = node.children.where((c) => c.path == next).firstOrNull;
    }
    if (mounted) setState(() {});
  }

  Future<void> _loadChildren(_FolderNode node) async {
    if (node.loaded || node.loading) return;
    setState(() => node.loading = true);
    try {
      final entries = await widget.repo.listEntries(node.path);
      final folders = entries.where((e) => e.isFolder).toList()
        ..sort((a, b) => a.name.compareTo(b.name));
      node.children = [
        for (final f in folders)
          _FolderNode(f.name, normalizeFilePath(f.path), node.depth + 1),
      ];
      node.loaded = true;
    } catch (e) {
      if (mounted) {
        ToastHelper.showError(
            context, context.l10n.folderPickerLoadFailed(friendlyErrorMessage(e)));
      }
    } finally {
      if (mounted) setState(() => node.loading = false);
    }
  }

  List<_FolderNode> get _visibleNodes {
    final result = <_FolderNode>[];
    void walk(_FolderNode node) {
      result.add(node);
      if (node.expanded) node.children.forEach(walk);
    }

    walk(_root);
    return result;
  }

  bool _isBlocked(_FolderNode node) => isBlockedTarget(node.path, _moveItems);

  bool _isMovedItem(_FolderNode node) => _moveItems
      .any((item) => item.isFolder && normalizeFilePath(item.path) == node.path);

  bool get _canConfirm =>
      _selectedPath != null && canMoveInto(_selectedPath!, _moveItems);

  String _selectedLabel(BuildContext context) {
    final segments =
        normalizeFilePath(_selectedPath).split('/').where((s) => s.isNotEmpty);
    return [context.l10n.filesMoveRoot, ...segments].join(' / ');
  }

  Future<void> _toggle(_FolderNode node) async {
    if (_isBlocked(node)) return;
    setState(() => node.expanded = !node.expanded);
    if (node.expanded) await _loadChildren(node);
  }

  _FolderNode? _findNode(String path, [_FolderNode? node]) {
    final current = node ?? _root;
    if (current.path == normalizeFilePath(path)) return current;
    for (final child in current.children) {
      final found = _findNode(path, child);
      if (found != null) return found;
    }
    return null;
  }

  Future<void> _createFolder() async {
    final parent = _findNode(_selectedPath ?? widget.currentPath) ?? _root;
    final name = await DialogHelper.showTextInput(
      context,
      title: context.l10n.filesCreateFolder,
      hint: context.l10n.filesFolderName,
      confirmText: context.l10n.filesCreate,
    );
    if (name == null || name.trim().isEmpty || !mounted) return;
    try {
      final before = {for (final c in parent.children) c.path};
      await widget.repo.createFolder(parent.path, name);
      parent.loaded = false;
      parent.expanded = true;
      await _loadChildren(parent);
      final created = parent.children.where((c) => !before.contains(c.path)).firstOrNull;
      if (mounted) setState(() => _selectedPath = created?.path ?? _selectedPath);
    } catch (e) {
      if (mounted) {
        ToastHelper.showError(context, context.l10n.filesFolderFailed(friendlyErrorMessage(e)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final ios = ionIsIos(context);
    final count = widget.items.length;
    final nodes = _visibleNodes;

    final tiles = [for (final node in nodes) _buildNode(context, node)];
    return Scaffold(
      backgroundColor: ios ? Colors.transparent : null,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        // WERKE-75: 110 was too narrow, "Abbrechen" wrapped inside the button.
        leadingWidth: 132,
        leading: Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: IonButtonLabel(l10n.commonCancel, maxLines: 1, softWrap: false),
          ),
        ),
        title: Text(l10n.filesMoveTitle(count)),
        // WER-16: Ionic title centred in iOS, at the start in md.
        centerTitle: ios || context.rdSkin != null,
        actions: [
          IconButton(
            tooltip: l10n.filesCreateFolder,
            // Ionic `folder-open-outline` (Beta: as before).
            icon: Icon(context.rdSkin != null
                ? AppIcons.createNewFolderOutlined
                : AppIcons.folderOpenOutlined),
            onPressed: _createFolder,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 16),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Text(
              l10n.filesMoveHint,
              style: const TextStyle(color: AppColors.medium, fontSize: 14),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppDimensions.paddingM),
            child: ios
                ? IonInsetGroup(children: tiles)
                : context.rdSkin == null
                // WER-16: md `ion-list [inset]` instead of a Material card.
                ? IonInsetList(
                    margin: EdgeInsets.zero,
                    dividerIndent: 56,
                    children: tiles,
                  )
                : Card(
                    margin: EdgeInsets.zero,
                    child: Column(children: [
                      for (var i = 0; i < tiles.length; i++) ...[
                        tiles[i],
                        if (i < tiles.length - 1) const Divider(height: 1, indent: 56),
                      ],
                    ]),
                  ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _selectedPath != null
                    ? l10n.filesMoveTarget(_selectedLabel(context))
                    : l10n.filesMoveChooseTarget,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.medium, fontSize: 13),
              ),
              const SizedBox(height: 6),
              ElevatedButton.icon(
                onPressed: _canConfirm
                    ? () => Navigator.of(context).pop(_selectedPath)
                    : null,
                icon: Icon(AppIcons.swapHoriz),
                label: Text(l10n.filesMoveMoveHere(count)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNode(BuildContext context, _FolderNode node) {
    final l10n = context.l10n;
    final blocked = _isBlocked(node);
    final selected = _selectedPath == node.path;
    final isRoot = node.path.isEmpty;

    final Widget toggle;
    if (node.loading) {
      toggle = const SizedBox(width: 18, height: 18, child: AppSpinner(strokeWidth: 2));
    } else if (node.loaded && node.children.isEmpty) {
      toggle = Icon(AppIcons.circle, size: 6, color: AppColors.medium);
    } else {
      toggle = Icon(
        node.expanded ? AppIcons.expandMore : AppIcons.chevronRight,
        color: AppColors.medium,
      );
    }

    String? note;
    if (_isMovedItem(node)) {
      note = l10n.filesMoveBeingMoved;
    } else if (isCurrentLocation(node.path, _moveItems)) {
      note = l10n.filesMoveCurrentFolder;
    }

    return Opacity(
      opacity: blocked ? 0.4 : 1,
      child: Material(
        color: selected ? AppColors.primary.withValues(alpha: 0.1) : Colors.transparent,
        child: InkWell(
          onTap: blocked ? null : () => setState(() => _selectedPath = node.path),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Row(children: [
              SizedBox(width: 8.0 + node.depth * 18),
              Semantics(
                button: true,
                label: node.expanded ? l10n.filesMoveCollapse : l10n.filesMoveExpand,
                child: InkResponse(
                  onTap: blocked ? null : () => _toggle(node),
                  radius: 20,
                  child: SizedBox(width: 36, height: 44, child: Center(child: toggle)),
                ),
              ),
              Icon(
                isRoot
                    ? AppIcons.homeOutlined
                    : (node.expanded ? AppIcons.folderOpenOutlined : AppIcons.folderOutlined),
                color: selected ? AppColors.primary : AppColors.medium,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(isRoot ? l10n.filesMoveRoot : node.name,
                          style: const TextStyle(fontSize: 16)),
                      if (note != null)
                        Text(note,
                            style: const TextStyle(color: AppColors.medium, fontSize: 13)),
                    ],
                  ),
                ),
              ),
              if (selected)
                Padding(
                  padding: EdgeInsets.only(right: 16),
                  child: Icon(AppIcons.checkCircle, color: AppColors.primary),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}
