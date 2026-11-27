part of 'work_files.dart';

// File table UI: toolbar button, drop hint, header/file rows, category
// picker menu, and upload queue progress card.

class _ToolButton extends StatelessWidget {
  const _ToolButton({required this.icon, required this.label, required this.onPressed, this.color});

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      label: Text(label),
      style: TextButton.styleFrom(
        foregroundColor: color ?? p.link,
        minimumSize: const Size(0, 40),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// Empty Werk: a frame to drop files into or to click for the picker.
class _DropHint extends StatelessWidget {
  const _DropHint({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    return RdCard(
      onTap: onTap,
      border: Border.all(color: p.offBorder, width: 1.5),
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      child: Column(
        children: [
          Icon(Icons.cloud_upload_outlined, size: 36, color: p.text2),
          const SizedBox(height: 8),
          Text(
            isFileDropSupported ? context.l10n.redesignFilesDropHint : context.l10n.redesignFilesPickHint,
            textAlign: TextAlign.center,
            style: RdType.meta(p, size: 15),
          ),
        ],
      ),
    );
  }
}

const double _checkWidth = 44;

/// Left gap of the rows outside selection mode (no checkbox column).
const double _checkGap = 8;
const double _partWidth = 200;
const double _partWidthCompact = 140;
const double _typeWidth = 64;
const double _menuWidth = 44;

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({
    required this.compact,
    required this.selecting,
    required this.allSelected,
    required this.someSelected,
    required this.onSelectAll,
  });

  final bool compact;
  final bool selecting;
  final bool allSelected;
  final bool someSelected;
  final ValueChanged<bool?> onSelectAll;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final style = TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: p.text2, letterSpacing: 0.3);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: selecting ? _checkWidth : _checkGap,
            child:
                !selecting
                    ? null
                    : Checkbox(
                      tristate: true,
                      value: allSelected ? true : (someSelected ? null : false),
                      activeColor: p.primary,
                      semanticLabel: l10n.redesignFilesSelectAll,
                      onChanged: (_) => onSelectAll(!allSelected),
                    ),
          ),
          const SizedBox(width: 36),
          Expanded(child: Text(l10n.redesignFilesColName.toUpperCase(), style: style)),
          SizedBox(
            width: compact ? _partWidthCompact : _partWidth,
            child: Text(l10n.redesignFilesColPart.toUpperCase(), style: style),
          ),
          if (!compact) SizedBox(width: _typeWidth, child: Text(l10n.redesignFilesColType.toUpperCase(), style: style)),
          const SizedBox(width: _menuWidth),
        ],
      ),
    );
  }
}

enum _RowAction { select, sibelius, sibeliusPlugin, word, share, download, replace, rename, delete }

enum _ListAction { select, downloadAll }

PopupMenuItem<T> _menuItem<T>(T value, IconData icon, String label, {Color? color, bool enabled = true}) =>
    PopupMenuItem(
      value: value,
      enabled: enabled,
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 12),
          Flexible(child: Text(label, style: TextStyle(color: color), overflow: TextOverflow.ellipsis)),
        ],
      ),
    );

class _FileRow extends StatelessWidget {
  const _FileRow({
    super.key,
    required this.compact,
    required this.selecting,
    required this.file,
    required this.groups,
    required this.instruments,
    this.onlyOnMac = false,
    this.offerPlugin = false,
    required this.selected,
    required this.cursor,
    required this.renaming,
    required this.renameController,
    required this.renameFocus,
    required this.onTap,
    required this.onToggle,
    required this.onCategory,
    required this.onRenameDone,
    required this.onAction,
  });

  final SongFile file;
  final List<Group> groups;

  /// Groups a file can be moved to (as the old category dialog).
  final List<Group> instruments;

  /// A save from Sibelius is only on the Mac so far (offline): it goes up by
  /// itself once online again.
  final bool onlyOnMac;

  /// "Sibelius-Plugin installieren" in the menu of a .sib (not installed yet).
  final bool offerPlugin;
  final bool selected;
  final bool cursor;
  final bool compact;

  /// Selection mode: the checkbox column shows.
  final bool selecting;
  final bool renaming;
  final TextEditingController renameController;
  final FocusNode renameFocus;
  final VoidCallback onTap;
  final ValueChanged<bool?> onToggle;

  /// null: "Sonstige …" (free text).
  final ValueChanged<_Category?> onCategory;
  final ValueChanged<bool> onRenameDone;

  /// The row's context comes along as anchor for the share sheet.
  final void Function(_RowAction action, BuildContext row) onAction;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final isAudio = SongUtils.isAudio(file);
    final icon =
        isAudio
            ? Icons.graphic_eq
            : (SongUtils.isPdf(file) ? Icons.description_outlined : Icons.insert_drive_file_outlined);

    final name =
        renaming
            ? CallbackShortcuts(
              bindings: {const SingleActivator(LogicalKeyboardKey.escape): () => onRenameDone(false)},
              child: TextField(
                controller: renameController,
                focusNode: renameFocus,
                autofocus: true,
                style: TextStyle(fontSize: 15, color: p.text),
                decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
                onSubmitted: (_) => onRenameDone(true),
                onTapOutside: (_) => onRenameDone(true),
              ),
            )
            : Text(
              file.fileName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: p.text),
            );

    return Semantics(
      selected: selected,
      child: Material(
        color: selected ? p.soft : (cursor ? p.track.withValues(alpha: 0.5) : Colors.transparent),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(
              children: [
                SizedBox(
                  width: selecting ? _checkWidth : _checkGap,
                  child:
                      !selecting
                          ? null
                          : Checkbox(
                            value: selected,
                            activeColor: p.primary,
                            semanticLabel: file.fileName,
                            onChanged: onToggle,
                          ),
                ),
                SizedBox(width: 36, child: Icon(icon, size: 22, color: p.text2)),
                Expanded(child: name),
                if (onlyOnMac && !renaming)
                  Tooltip(
                    message: l10n.redesignFilesSibeliusWaiting,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Icon(
                        Icons.cloud_off_outlined,
                        size: 20,
                        color: p.late,
                        semanticLabel: l10n.redesignFilesSibeliusWaiting,
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                SizedBox(
                  width: compact ? _partWidthCompact : _partWidth,
                  child: _CategoryButton(file: file, groups: groups, instruments: instruments, onSelected: onCategory),
                ),
                if (!compact)
                  SizedBox(width: _typeWidth, child: Text(rdFileKind(file), style: RdType.meta(p, size: 13))),
                SizedBox(
                  width: _menuWidth,
                  child: PopupMenuButton<_RowAction>(
                    tooltip: l10n.redesignFilesActions(file.fileName),
                    icon: Icon(Icons.more_horiz, color: p.text2),
                    onSelected: (action) => onAction(action, context),
                    itemBuilder:
                        (_) => [
                          if (!selecting)
                            _menuItem(_RowAction.select, Icons.check_circle_outline, l10n.redesignFilesSelectOne),
                          if (rdOpensInSibelius(file)) ...[
                            _menuItem(_RowAction.sibelius, Icons.edit_note, l10n.redesignFilesSibeliusEdit),
                            if (offerPlugin)
                              _menuItem(
                                _RowAction.sibeliusPlugin,
                                Icons.extension_outlined,
                                l10n.redesignFilesSibeliusPlugin,
                              ),
                          ],
                          if (rdEditsInWord(file)) _menuItem(_RowAction.word, Icons.edit_note, l10n.redesignFilesWordEdit),
                          _menuItem(_RowAction.share, Icons.ios_share, l10n.redesignWorkShare),
                          _menuItem(_RowAction.download, Icons.download_outlined, l10n.redesignFilesDownload),
                          if (!rdIsAudioFile(file))
                            _menuItem(_RowAction.replace, Icons.upload_file_outlined, l10n.redesignFilesReplace),
                          if (rdCanRename(file))
                            _menuItem(_RowAction.rename, Icons.drive_file_rename_outline, l10n.redesignFilesRename),
                          _menuItem(_RowAction.delete, Icons.delete_outline, l10n.redesignFilesDelete, color: p.absent),
                        ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Stimme" cell: the current part; a click opens the parts to move to.
class _CategoryButton extends StatelessWidget {
  const _CategoryButton({
    required this.file,
    required this.groups,
    required this.instruments,
    required this.onSelected,
  });

  final SongFile file;
  final List<Group> groups;
  final List<Group> instruments;
  final ValueChanged<_Category?> onSelected;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final options = <(_Category, String)>[
      for (final g in instruments)
        if (g.id != null) ((id: g.id, note: null), g.name),
      ((id: 1, note: null), l10n.songsRecording),
      ((id: 2, note: null), l10n.songsLyrics),
      ((id: null, note: 'Partitur'), 'Partitur'),
      ((id: null, note: 'Klavierauszug'), 'Klavierauszug'),
      ((id: null, note: 'Sibelius'), 'Sibelius'),
      ((id: null, note: 'MIDI'), 'MIDI'),
    ];
    return PopupMenuButton<int>(
      tooltip: l10n.songsChangeCategory,
      position: PopupMenuPosition.under,
      onSelected: (i) => onSelected(i < 0 ? null : options[i].$1),
      itemBuilder:
          (_) => [
            for (var i = 0; i < options.length; i++)
              CheckedPopupMenuItem(
                value: i,
                checked:
                    options[i].$1.id == file.instrumentId &&
                    (options[i].$1.id != null || options[i].$1.note == file.note),
                child: Text(options[i].$2),
              ),
            const PopupMenuDivider(),
            PopupMenuItem(value: -1, child: Text(l10n.redesignFilesOtherCategory)),
          ],
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Flexible(
              child: Text(
                SongUtils.fileLabel(file, groups),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 14, color: p.link, fontWeight: FontWeight.w500),
              ),
            ),
            Icon(Icons.arrow_drop_down, color: p.link),
          ],
        ),
      ),
    );
  }
}

/// The upload queue: "Hochladen: 3 von 7", a bar and one row per file.
class RdUploadQueue extends StatelessWidget {
  const RdUploadQueue({
    super.key,
    required this.state,
    required this.groups,
    required this.onRetry,
    required this.onDismiss,
  });

  final RdWorkFilesState state;
  final List<Group> groups;
  final ValueChanged<int> onRetry;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final finished = state.doneCount + state.failedCount;
    return RdCard(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    state.busy
                        ? l10n.redesignFilesQueueTitle(finished, state.total)
                        : l10n.redesignFilesQueueDone(state.doneCount),
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: p.text),
                  ),
                ),
              ),
              if (!state.busy) RdTextLink(label: l10n.redesignFilesDismiss, onTap: onDismiss),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 4,
              value: state.total == 0 ? 0 : finished / state.total,
              color: state.failedCount > 0 ? p.late : p.primary,
              backgroundColor: p.track,
            ),
          ),
          const SizedBox(height: 4),
          for (final u in state.uploads)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: LayoutBuilder(
                builder: (context, c) {
                  final part = SongUtils.fileLabel(
                    SongFile(fileName: u.file.name, fileType: '', url: '', instrumentId: u.instrumentId, note: u.note),
                    groups,
                  );
                  // Phones: the part goes under the name, the status gets
                  // only the room it needs.
                  final compact = c.maxWidth < 520;
                  final name = Text(
                    u.file.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14, color: p.text),
                  );
                  return Row(
                    children: [
                      SizedBox(width: 28, child: _statusIcon(p, u.status)),
                      Expanded(
                        child:
                            compact
                                ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    name,
                                    Text(
                                      part,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: RdType.meta(p, size: 13),
                                    ),
                                  ],
                                )
                                : name,
                      ),
                      const SizedBox(width: 8),
                      if (!compact)
                        SizedBox(
                          width: 160,
                          child: Text(
                            part,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: RdType.meta(p, size: 13),
                          ),
                        ),
                      SizedBox(
                        width: compact ? null : 150,
                        child:
                            u.status == RdUploadStatus.failed
                                ? Align(
                                  alignment: Alignment.centerRight,
                                  child: Tooltip(
                                    message: u.error ?? '',
                                    child: RdTextLink(label: l10n.redesignCommonRetry, onTap: () => onRetry(u.id)),
                                  ),
                                )
                                : Text(
                                  switch (u.status) {
                                    RdUploadStatus.waiting => l10n.redesignFilesWaiting,
                                    RdUploadStatus.uploading => l10n.redesignFilesUploading,
                                    _ => l10n.redesignFilesDone,
                                  },
                                  textAlign: TextAlign.end,
                                  style: RdType.meta(p, size: 13),
                                ),
                      ),
                      const SizedBox(width: 6),
                    ],
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _statusIcon(RdPalette p, RdUploadStatus status) => switch (status) {
    RdUploadStatus.waiting => Icon(Icons.schedule, size: 18, color: p.text2),
    // Same 18px box as the icons, the ring inset like their glyphs, so
    // it sits centred in the column exactly where the check and clock do.
    RdUploadStatus.uploading => Center(
      child: SizedBox(
        width: 18,
        height: 18,
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: CircularProgressIndicator(strokeWidth: 2, color: p.primary),
        ),
      ),
    ),
    RdUploadStatus.done => Icon(Icons.check_circle, size: 18, color: p.present),
    RdUploadStatus.failed => Icon(Icons.error_outline, size: 18, color: p.absent),
  };
}
