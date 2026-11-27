part of 'work_files.dart';

// File workspace dialogs: conflict resolution, Sibelius exported parts,
// AI part-review table, and keyboard shortcuts help.

/// "Schon vorhanden": the files that clash, "Ersetzen" (true) or "Beide
/// behalten" (false).
class _ConflictDialog extends StatelessWidget {
  const _ConflictDialog({required this.items, required this.groups});

  final List<_UploadItem> items;
  final List<Group> groups;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppAlertDialog(
      title: Text(l10n.redesignFilesConflictTitle),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.redesignFilesConflictMessage(items.length)),
              const SizedBox(height: 12),
              for (final i in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '${i.file.name} → ${i.conflicts.map((c) => c.fileName).join(', ')}',
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.commonCancel)),
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.redesignFilesKeepBoth)),
        TextButton(onPressed: () => Navigator.pop(context, true), child: Text(l10n.redesignFilesReplace)),
      ],
    );
  }
}

/// One part of [_SibeliusPartsDialog] as it is taken over.
typedef _SibeliusPart = ({PlatformFile file, int? instrumentId, String? note, List<SongFile> replace});

/// "Neue Stimmen aus Sibelius": one row per exported part PDF with a
/// checkbox, its part and the PDF it replaces (or "neu"); both can be
/// changed. "Übernehmen" returns the checked parts.
class _SibeliusPartsDialog extends StatefulWidget {
  const _SibeliusPartsDialog({
    required this.items,
    required this.existing,
    required this.groups,
    required this.workName,
    required this.isChoir,
  });

  final List<({PlatformFile file, int? instrumentId, String? note})> items;
  final List<SongFile> existing;
  final List<Group> groups;
  final String workName;
  final bool isChoir;

  @override
  State<_SibeliusPartsDialog> createState() => _SibeliusPartsDialogState();
}

class _SibeliusPartsDialogState extends State<_SibeliusPartsDialog> {
  late final List<_Category> _parts = [for (final i in widget.items) (id: i.instrumentId, note: i.note)];
  late final List<SongFile?> _replace = rdPartReplacements([
    for (final i in widget.items) (name: i.file.name, instrumentId: i.instrumentId, note: i.note),
  ], widget.existing);
  late final List<bool> _take = List.filled(widget.items.length, true);

  RdPartPdf _pdf(int i) => (name: widget.items[i].file.name, instrumentId: _parts[i].id, note: _parts[i].note);

  void _choosePart(int i, _Category part) {
    setState(() {
      _parts[i] = part;
      // The file it replaces follows the part (unless taken by another).
      final others = {
        for (var j = 0; j < _replace.length; j++)
          if (j != i && _replace[j] != null) _replace[j]!,
      };
      _replace[i] = rdPartReplacements([_pdf(i)], widget.existing.where((f) => !others.contains(f)).toList()).single;
    });
  }

  void _chooseReplace(int i, SongFile? file) {
    setState(() {
      // A file is replaced by one part only.
      if (file != null) {
        for (var j = 0; j < _replace.length; j++) {
          if (_replace[j] == file) _replace[j] = null;
        }
      }
      _replace[i] = file;
    });
  }

  String _partName(PlatformFile file) {
    final dot = file.name.lastIndexOf('.');
    return dot > 0 ? file.name.substring(0, dot) : file.name;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.rd;
    final count = _take.where((t) => t).length;
    final head = TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: p.text2, letterSpacing: 0.3);
    final options = <(_Category, String)>[
      for (final g in widget.groups)
        if (g.id != null) ((id: g.id, note: null), g.name),
      ((id: null, note: 'Partitur'), 'Partitur'),
      ((id: null, note: 'Klavierauszug'), 'Klavierauszug'),
      if (widget.isChoir) ((id: null, note: kChoirAllNote), kChoirAllNote),
    ];
    return AppAlertDialog(
      title: Text(l10n.redesignFilesSibeliusPartsTitle),
      content: SizedBox(
        width: 640,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.redesignFilesSibeliusPartsMessage(widget.items.length, widget.workName)),
            const SizedBox(height: 12),
            Row(
              children: [
                SizedBox(
                  width: 40,
                  child: Checkbox(
                    tristate: true,
                    value: count == _take.length ? true : (count == 0 ? false : null),
                    activeColor: p.primary,
                    semanticLabel: l10n.redesignFilesSelectAll,
                    onChanged: (_) => setState(() => _take.fillRange(0, _take.length, count != _take.length)),
                  ),
                ),
                Expanded(child: Text(l10n.redesignFilesSibeliusColFile.toUpperCase(), style: head)),
                SizedBox(width: 168, child: Text(l10n.redesignFilesColPart.toUpperCase(), style: head)),
                const SizedBox(width: 12),
                SizedBox(width: 200, child: Text(l10n.redesignFilesSibeliusColReplaces.toUpperCase(), style: head)),
              ],
            ),
            Divider(height: 1, color: p.line),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [for (var i = 0; i < widget.items.length; i++) _row(context, i, options)],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, const <_SibeliusPart>[]), child: Text(l10n.commonCancel)),
        TextButton(
          onPressed:
              count == 0
                  ? null
                  : () => Navigator.pop<List<_SibeliusPart>>(context, [
                    for (var i = 0; i < widget.items.length; i++)
                      if (_take[i])
                        (
                          file: widget.items[i].file,
                          instrumentId: _parts[i].id,
                          note: _parts[i].id == null ? _parts[i].note : null,
                          replace: [if (_replace[i] case final f?) f],
                        ),
                  ]),
          child: Text(l10n.redesignFilesSibeliusPartsApplyCount(count)),
        ),
      ],
    );
  }

  Widget _row(BuildContext context, int i, List<(_Category, String)> options) {
    final l10n = context.l10n;
    final p = context.rd;
    final on = _take[i];
    final part = _parts[i];
    final partOptions = [
      ...options,
      if (part != (id: null, note: null) && !options.any((o) => o.$1 == part))
        (part, part.note ?? l10n.redesignFilesSibeliusPartNone),
      ((id: null, note: null) as _Category, l10n.redesignFilesSibeliusPartNone),
    ];
    final replaceOptions = rdPartReplaceOptions(_pdf(i), widget.existing);
    final dense = TextStyle(fontSize: 14, color: on ? p.text : p.text2);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Checkbox(value: on, activeColor: p.primary, onChanged: (v) => setState(() => _take[i] = v ?? false)),
          ),
          Expanded(
            child: Text(
              _partName(widget.items[i].file),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: dense.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
          SizedBox(
            width: 168,
            child: AppDropdownButton<_Category>(
              value: part,
              isExpanded: true,
              isDense: true,
              style: dense,
              items: [
                for (final o in partOptions)
                  DropdownMenuItem(value: o.$1, child: Text(o.$2, overflow: TextOverflow.ellipsis)),
              ],
              onChanged: on ? (v) => _choosePart(i, v ?? (id: null, note: null)) : null,
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 200,
            child: AppDropdownButton<SongFile?>(
              value: _replace[i],
              isExpanded: true,
              isDense: true,
              style: dense,
              items: [
                DropdownMenuItem(
                  value: null,
                  child: Text(l10n.redesignFilesSibeliusPartNew, style: TextStyle(color: p.present)),
                ),
                for (final f in replaceOptions)
                  DropdownMenuItem(value: f, child: Text(f.fileName, overflow: TextOverflow.ellipsis)),
              ],
              onChanged: on ? (f) => _chooseReplace(i, f) : null,
            ),
          ),
        ],
      ),
    );
  }
}

typedef _ReviewResult = ({Map<PlatformFile, RdImportCategory> categories, Map<int, List<String>> terms});

/// "Zuordnung prüfen": the dropped files whose part was not recognised for
/// sure (or that need a new group), each with a part menu and "künftig so
/// erkennen" once changed.
class _ReviewDialog extends StatefulWidget {
  const _ReviewDialog({
    required this.items,
    required this.groups,
    required this.instruments,
    required this.isChoir,
    required this.workName,
  });

  final List<({PlatformFile file, RdUploadRead read, _Proposal proposal})> items;
  final List<Group> groups;
  final List<InstrumentInfo> instruments;
  final bool isChoir;
  final String workName;

  @override
  State<_ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<_ReviewDialog> {
  late final Map<PlatformFile, RdImportCategory> _chosen = {for (final i in widget.items) i.file: i.proposal.category};

  /// The import's labels and options need only the groups.
  late final RdImportPlan _plan = RdImportPlan(
    works: const [],
    questions: const [],
    songs: const {},
    instruments: widget.instruments,
    junk: 0,
    isChoir: widget.isChoir,
  );

  /// An unsure part (by name or by the KI) can be confirmed for learning
  /// right away (unchecked).
  late final Map<PlatformFile, String> _terms = {
    for (final i in widget.items)
      if (i.proposal.why != _Why.page && !i.proposal.knownName && i.proposal.category.instrumentId != null)
        if (_term(i.file, i.proposal.category) case final term?) i.file: term,
  };
  final Set<PlatformFile> _learn = {};

  String? _term(PlatformFile file, RdImportCategory c) {
    final id = c.instrumentId;
    if (id == null || id <= InstrumentMatcher.lyricsId) return null;
    return learnableTerm(file.name, chosenId: id, instruments: widget.instruments, workName: widget.workName);
  }

  void _choose(PlatformFile file, RdImportCategory c) {
    setState(() {
      _chosen[file] = c;
      final term = _term(file, c);
      if (term == null) {
        _terms.remove(file);
        _learn.remove(file);
      } else {
        _terms[file] = term;
        _learn.add(file);
      }
    });
  }

  void _submit() {
    Navigator.pop<_ReviewResult>(context, (categories: Map.of(_chosen), terms: _learnedTerms()));
  }

  Map<int, List<String>> _learnedTerms() {
    final terms = <int, List<String>>{};
    for (final f in _learn) {
      final id = _chosen[f]?.instrumentId;
      final term = _terms[f];
      if (id != null && term != null) (terms[id] ??= []).add(term);
    }
    return terms;
  }

  /// Why the file is shown, and how sure the proposal is.
  String _status(BuildContext context, _Proposal p) {
    final l10n = context.l10n;
    switch (p.why) {
      case _Why.page:
        return p.sure
            ? l10n.songsFlutterVisionSure(p.label ?? rdImportCategoryLabel(context, _plan, p.category))
            : l10n.songsFlutterVisionUnsure;
      case _Why.ai:
        return l10n.songsFlutterAiSuggested;
      case _Why.name:
        if (p.category.isSeveral) return l10n.rdWordsSeveralGroups(rdGroupKindOf(context));
        if (p.category.newGroup != null) return l10n.redesignImportNewGroupMessage(rdGroupKindOf(context));
        return p.category.instrumentId != null || p.category.note != null
            ? l10n.songsFlutterDetectUnsure
            : l10n.songsFlutterDetectNone;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.rd;
    final proposed = {for (final i in widget.items) i.proposal.category};
    final newGroups = rdUploadNewGroups(proposed.where((c) => !c.isSeveral));
    final options = [
      // A part for several groups ("Posaune + Tuba") first.
      for (final c in proposed)
        if (c.isSeveral) (c, rdImportCategoryLabel(context, _plan, c)),
      ...rdImportCategoryOptions(context, _plan, newGroups: newGroups),
    ];
    final menu = <DropdownMenuItem<RdImportCategory>>[
      for (final (c, label) in options) DropdownMenuItem(value: c, child: Text(label, overflow: TextOverflow.ellipsis)),
    ];
    return AppAlertDialog(
      title: Text(l10n.songsFlutterReviewTitle),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.songsFlutterReviewHint),
              const SizedBox(height: 12),
              for (final i in widget.items) ...[
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            i.file.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                          ),
                          Text(
                            _status(context, i.proposal),
                            style: TextStyle(
                              fontSize: 12,
                              color:
                                  i.proposal.sure || i.proposal.knownName
                                      ? p.present
                                      : i.proposal.category != RdImportCategory.other
                                      ? p.late
                                      : p.absent,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 180,
                      child: AppDropdownButton<RdImportCategory>(
                        value: _chosen[i.file],
                        items: menu,
                        isExpanded: true,
                        onChanged: (c) {
                          if (c != null) _choose(i.file, c);
                        },
                      ),
                    ),
                  ],
                ),
                if (_terms[i.file] != null && _chosen[i.file]?.instrumentId != null)
                  CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: _learn.contains(i.file),
                    title: Text(
                      l10n.songsFlutterLearnTerm(
                        _terms[i.file]!,
                        widget.groups.where((g) => g.id == _chosen[i.file]!.instrumentId).firstOrNull?.name ?? '',
                      ),
                      style: const TextStyle(fontSize: 13),
                    ),
                    onChanged: (v) => setState(() => v == true ? _learn.add(i.file) : _learn.remove(i.file)),
                  ),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.commonCancel)),
        TextButton(onPressed: _submit, child: Text(l10n.songsFlutterReviewUpload)),
      ],
    );
  }
}

/// Shows the file table's keyboard shortcuts (Ich › Hilfe, or "?" in
/// the file table). Kept out of the toolbar so the main UI stays calm.
Future<void> showRdWorkFilesShortcuts(BuildContext context) {
  final isMac = defaultTargetPlatform == TargetPlatform.macOS || defaultTargetPlatform == TargetPlatform.iOS;
  final modLabel = isMac ? '⌘' : (Localizations.localeOf(context).languageCode == 'de' ? 'Strg' : 'Ctrl');
  return showAppDialog<void>(
    context: context,
    builder: (_) => _ShortcutsDialog(help: context.l10n.redesignFilesShortcutsHelp(modLabel)),
  );
}

/// The shortcuts of the file table, one per line.
class _ShortcutsDialog extends StatelessWidget {
  const _ShortcutsDialog({required this.help});

  /// `redesignFilesShortcutsHelp`: the shortcuts separated by " · ".
  final String help;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppAlertDialog(
      title: Text(l10n.redesignFilesShortcuts),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final line in help.split(' · '))
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(line, style: const TextStyle(fontSize: 14)),
                ),
              // Mac app: how to give the Attendix plug-in a shortcut.
              if (rdSibeliusSupported) ...[
                const SizedBox(height: 10),
                Text(
                  l10n.redesignFilesSibeliusShortcutTitle,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(l10n.redesignFilesSibeliusShortcutTip, style: const TextStyle(fontSize: 14)),
              ],
            ],
          ),
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.commonOk))],
    );
  }
}
