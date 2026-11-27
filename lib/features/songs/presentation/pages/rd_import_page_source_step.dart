part of 'rd_import_page.dart';

extension _RdImportSourceStep on _RdImportPageState {
  // -------------------------------------------------------------------------
  // 1 Quelle

  Widget _source(BuildContext context) => switch (_mode) {
        null => _sourceChoice(context),
        _Source.drive => _sourceDrive(context),
        _Source.zip => _sourceZip(context),
      };

  Widget _sourceChoice(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    return RdImportFrame(
      backLabel: l10n.redesignTabWorks,
      onBack: _back,
      title: l10n.redesignImportTitle,
      step: 1,
      children: [
        // Also when the page is opened by its address.
        if (ref.watch(rdImportOwnLibraryProvider).valueOrNull == false)
          RdInfoCard(text: l10n.redesignImportErrorOtherLibrary, icon: Icons.info_outline)
        else ...[
          RdSectionHeader(l10n.redesignImportSourceWhere),
          RdGroupedList(
            children: [
              RdListRow(
                leading: const RdRowIcon(Icons.add_to_drive_outlined),
                title: l10n.redesignImportSourceDrive,
                subtitle: l10n.redesignImportSourceDriveDetail,
                trailing: RdPill(l10n.redesignImportSourceRecommended, tone: RdTone.primary),
                onTap: () => _update(() => _mode = _Source.drive),
              ),
              RdListRow(
                leading: const RdRowIcon(Icons.folder_zip_outlined),
                title: l10n.redesignImportSourceZip,
                subtitle: l10n.redesignImportSourceZipDetail,
                onTap: () => _update(() => _mode = _Source.zip),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 12, 4, 0),
            child: Text(l10n.redesignImportSourceSafe, style: RdType.meta(p, size: 13)),
          ),
          ..._collectionChoice(context, ref.watch(rdImportProvider)),
        ],
      ],
    );
  }

  /// "In welche Sammlung?": Repertoire and every Sammlung, as on "Neues
  /// Werk"; nothing while the group has no Sammlungen.

  /// "+ Neue Sammlung" in the choice: made as on the Sammlungen page (name,
  /// suggested Kürzel) and chosen for the import right away.
  Future<void> _addCollection() async {
    if (_addingCollection) return;
    final l10n = context.l10n;
    // A sheet like "Neue Kategorie" (was a dialog with a wrapping button).
    final name = await showRdTextSheet(
      context,
      title: l10n.collectionsAddTitle,
      hint: l10n.collectionsAddHint,
      required: true,
    );
    final trimmed = name?.trim() ?? '';
    if (trimmed.isEmpty || !mounted) return;
    // A Kürzel no other Sammlung and no Werk uses yet.
    final first = rdCollectionPrefixSuggestion(trimmed);
    final prefix = rdCollectionPrefixSuggestion(
      trimmed,
      taken: rdTakenPrefixes(
        ref.read(songCollectionsProvider).valueOrNull ?? const [],
        ref.read(songsProvider).valueOrNull ?? const [],
      ),
    );
    _update(() => _addingCollection = true);
    final created = await ref
        .read(songCollectionNotifierProvider.notifier)
        .add(SongCollection(name: trimmed, prefix: prefix));
    if (!mounted) return;
    // Its Kürzel counts for the new Werke: chosen only once the list has it.
    final loaded = created?.id == null
        ? null
        : await ref
            .read(songCollectionsProvider.future)
            .then<List<SongCollection>?>((list) => list)
            .catchError((_) => null);
    if (!mounted) return;
    _update(() => _addingCollection = false);
    if (created?.id == null) {
      ToastHelper.showError(context, l10n.collectionsAddFailed);
      return;
    }
    if (prefix != first) ToastHelper.showInfo(context, l10n.rdTextCollectionPrefixWhy(prefix, first));
    if (loaded == null || !loaded.any((c) => c.id == created!.id)) {
      ToastHelper.showError(context, l10n.redesignImportCollectionNotLoaded);
      return;
    }
    // Only before the review: afterwards the target stays as it is.
    final step = ref.read(rdImportProvider).step;
    if (step != RdImportStep.source && step != RdImportStep.reading && step != RdImportStep.questions) return;
    _controller.setCollection(created!.id);
  }

  List<Widget> _collectionChoice(BuildContext context, RdImportState state) {
    final p = context.rd;
    final l10n = context.l10n;
    final collections = [...?ref.watch(songCollectionsProvider).valueOrNull?.where((c) => c.id != null)];
    final role = ref.watch(effectiveRoleProvider);
    // Who may make Sammlungen on their page may make one here too.
    final canAdd = role.isAdmin || role.isResponsible;
    if (collections.isEmpty && !canAdd) return const [];
    final chosen = rdCollectionById(collections, state.collectionId);
    return [
      const SizedBox(height: 20),
      RdSectionHeader(l10n.redesignImportCollectionTitle),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final c in [null, ...collections])
            RdChoiceChip(
              key: Key('rd-import-collection-${c?.id ?? 'repertoire'}'),
              label: c?.name ?? l10n.collectionsRepertoire,
              icon: rdCollectionIcon(c),
              selected: c?.id == chosen?.id,
              onTap: _addingCollection ? null : () => _controller.setCollection(c?.id),
            ),
          if (canAdd)
            RdChoiceChip(
              key: const Key('rd-import-collection-new'),
              label: l10n.collectionsAddTitle,
              icon: Icons.add,
              selected: false,
              onTap: _addingCollection ? null : _addCollection,
            ),
        ],
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
        child: Text(
          [
            l10n.redesignImportCollectionHint,
            // Groups are only read for a Sammlung that not everybody sees.
            if (chosen != null)
              if (rdCollectionBanner(l10n, chosen, ref.watch(groupsProvider).valueOrNull ?? const [])
                  case final audience?)
                audience,
          ].join(' '),
          style: RdType.meta(p, size: 13),
        ),
      ),
    ];
  }

  Widget _sourceDrive(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final check = _check;
    final error = _error ?? check?.error;
    final ready = check?.folder != null && _error == null && !_checking;
    return RdImportFrame(
      backLabel: l10n.redesignImportStepSource,
      onBack: _back,
      title: l10n.redesignImportTitle,
      step: 1,
      children: [
        RdSectionHeader(l10n.redesignImportSourceDrive),
        RdCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (i, text) in [
                l10n.redesignImportDriveStep1,
                l10n.redesignImportDriveStep2,
                l10n.redesignImportDriveStep3,
              ].indexed) ...[
                if (i > 0) const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ExcludeSemantics(child: RdCountBadge(i + 1)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Text(text, style: RdType.body(p)),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              RdOutlineButton(label: l10n.redesignImportDriveOpen, icon: Icons.open_in_new, onPressed: _openDrive),
            ],
          ),
        ),
        const SizedBox(height: 20),
        RdSectionHeader(l10n.redesignImportDriveLinkLabel),
        RdCard(
          padding: const EdgeInsets.fromLTRB(16, 6, 6, 6),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _link,
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  enableSuggestions: false,
                  textInputAction: TextInputAction.go,
                  style: TextStyle(fontSize: 16, color: p.text),
                  decoration: InputDecoration(
                    isDense: true,
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    hintText: l10n.redesignImportDriveLinkHint,
                    hintStyle: TextStyle(color: p.text2),
                  ),
                  onChanged: _linkChanged,
                  onSubmitted: _linkSubmitted,
                ),
              ),
              const SizedBox(width: 8),
              RdPillButton(icon: Icons.content_paste, label: l10n.redesignImportDrivePaste, onPressed: _paste),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (_checking)
          Row(
            children: [
              SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: p.primary)),
              const SizedBox(width: 10),
              Text(l10n.redesignImportDriveChecking, style: RdType.meta(p)),
            ],
          )
        else if (error != null)
          _errorCard(context, error)
        else if (_link.text.trim().isNotEmpty && rdParseDriveLink(_link.text) == null)
          // Why "Einlesen starten" stays grey.
          Text(l10n.rdTextImportNotDrive, style: RdType.meta(p, size: 14).copyWith(color: p.absent))
        else if (check?.folder != null)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: p.presentSoft, borderRadius: BorderRadius.circular(14)),
            child: Row(
              children: [
                Icon(Icons.check, color: p.present),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.redesignImportDriveFound(check!.name ?? ''),
                    style: RdType.body(p).copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        // Right below the link, so it stays in reach with the keyboard open.
        const SizedBox(height: 16),
        RdPrimaryButton(label: l10n.redesignImportDriveStart, onPressed: ready ? _readLink : null),
        const SizedBox(height: 12),
        Text(l10n.redesignImportDriveUnshareNote, style: RdType.meta(p, size: 13)),
      ],
    );
  }

  Widget _sourceZip(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final error = _error;
    return RdImportFrame(
      backLabel: l10n.redesignImportStepSource,
      onBack: _back,
      title: l10n.redesignImportTitle,
      step: 1,
      children: [
        RdSectionHeader(l10n.redesignImportSourceZip),
        RdCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.redesignImportSourceIntro, style: RdType.body(p)),
              const SizedBox(height: 16),
              RdPrimaryButton(label: l10n.redesignImportSourcePick, icon: Icons.folder_zip_outlined, onPressed: _pick),
            ],
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 12),
          _errorCard(context, error),
        ],
        const SizedBox(height: 20),
        RdSectionHeader(l10n.redesignImportSourceHowTitle),
        RdCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (i, (icon, text)) in [
                (Icons.add_to_drive_outlined, l10n.redesignImportSourceHowDrive),
                (Icons.cloud_download_outlined, l10n.redesignImportSourceHowDropbox),
                (Icons.computer_outlined, l10n.redesignImportSourceHowComputer),
              ].indexed) ...[
                if (i > 0) const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, size: 20, color: p.text2),
                    const SizedBox(width: 12),
                    Expanded(child: Text(text, style: RdType.body(p))),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // 2 Einlesen und Stimmen

  Widget _reading(BuildContext context, RdImportState state) {
    final p = context.rd;
    final l10n = context.l10n;
    return RdImportFrame(
      // After the questions the back link leads to them.
      backLabel: state.plan != null ? l10n.redesignImportStepRead : l10n.redesignTabWorks,
      onBack: _back,
      title: l10n.redesignImportTitle,
      step: 2,
      children: [
        RdCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.redesignImportReadingTitle, style: RdType.section(p)),
              if (state.sourceName != null) ...[
                const SizedBox(height: 4),
                Text('${state.sourceName} · ${l10n.redesignImportFoundFiles(state.fileCount)}', style: RdType.meta(p)),
              ],
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: state.progress <= 0 ? null : state.progress,
                  minHeight: 8,
                  color: p.primary,
                  backgroundColor: p.track,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _mode == _Source.drive && state.progress <= 0
                    ? l10n.redesignImportDriveReading
                    : l10n.redesignImportReadingDetail,
                style: RdType.meta(p, size: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
