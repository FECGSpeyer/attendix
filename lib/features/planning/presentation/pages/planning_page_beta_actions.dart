part of 'planning_page.dart';

/// Adding items/works/templates, Registerprobe management, and item/block
/// editing sheets for the Beta Ablauf editor.
extension _PlanningBetaActions on _PlanningPageState {
  // ---------------------------------------------------------------------------
  // Adding
  // ---------------------------------------------------------------------------

  /// "+ Hinzufügen" (at the end) or "Punkt danach einfügen" ([after]:
  /// position in [_fields]; [group]: the block the new item joins).
  /// Every entry runs the classic action, which appends; the new rows are
  /// then moved to the chosen place.
  Future<void> _rdAdd({int? after, String? group}) async {
    final l10n = context.l10n;
    if (after != null && after >= _fields.length) after = null;
    final anchor = after == null ? null : _fields[after];
    final loadGen = _loadGen;
    final subtitle = anchor == null ? l10n.redesignPlanAddEnd : l10n.redesignPlanAddAfter(anchor.name);
    final action = await _rdAddSheet(subtitle);
    if (action == null || !mounted) return;
    // Another plan was loaded meanwhile (conflict, draft, other Termin): the
    // choice was made for the old one, so nothing is added or replaced.
    if (loadGen != _loadGen) return;
    final before = [..._fields];
    // The plan changed while the sheet was open: add at the end.
    if (after != null && (after >= before.length || !_rdSame(before[after], anchor!))) {
      after = null;
    }
    if (group != null && !before.any((f) => f.id == group)) group = null;
    // Programmpunkt (Punkt, Notiz, Werke) and Programmblock: one sheet that
    // stays open for several entries; the block starts with its name.
    if (action == 'field' || action == 'block') {
      await _rdQuickAdd(group: group, after: after == null ? null : before[after], block: action == 'block');
      return;
    }
    if (action == 'register') {
      await _rdInsertRegister(after: after == null ? null : before[after]);
      return;
    }
    await _runAddAction(action);
    if (!mounted || after == null || loadGen != _loadGen) return;
    final now = _fields;
    if (now.length <= before.length) return;
    for (var i = 0; i < before.length; i++) {
      if (!_rdSame(now[i], before[i])) return; // replaced (Vorlage): nothing to move
    }
    var tail = now.sublist(before.length);
    var pos = (after + 1).clamp(0, before.length);
    var join = group;
    // Blocks and the Tagesordnung marker never sit inside a block.
    if (join != null && tail.any((f) => PlanUtils.isGroupHead(f) || PlanUtils.isAgendaPlaceholder(f))) {
      // Blocks are never nested: behind the whole block.
      pos = PlanUtils.lastIndexOfGroup(before, join) + 1;
      join = null;
    }
    if (join != null) {
      tail = [
        for (final f in tail)
          // The Tagesordnung marker never sits inside a block.
          PlanUtils.isGroupHead(f) || PlanUtils.isAgendaPlaceholder(f) || f.groupId != null
              ? f
              : f.copyWith(groupId: join),
      ];
      _rdCollapsed.remove(join);
    }
    _rdApply([...now.sublist(0, pos), ...tail, ...now.sublist(pos, before.length)]);
  }

  /// "Werke": one picker for a Werk from the list or "Alle aktuellen
  /// Werke" (the rows to add; empty: nothing).
  Future<List<PlanField>> _rdPickWorksFields() async {
    final loadGen = _loadGen;
    final pick = await showPlanWorksPicker(
      context,
      _songs,
      currentIds: _history.map((h) => h.songId).whereType<int>().toSet(),
      inPlanIds: _fields.map((f) => f.songId).whereType<int>().toSet(),
      offerAllCurrent: true,
    );
    if (pick == null || !_samePlan(loadGen)) return const [];
    if (pick.allCurrent) return _currentSongFieldsOrAsk();
    final song = pick.song;
    if (song == null) return const [];
    return [
      PlanSongHelper.songField(
        song,
        history: _history,
        prefix: _songPrefix(_typeOf(_att)),
        time: PlanSongHelper.betaTime(song),
      ),
    ];
  }

  /// "+ Werke": the Werke planned for this Termin or the next Auftritt
  /// first (with "Anderes Werk"); the Werk list when there are none.
  Future<List<PlanField>> _rdPickAnyWorksFields() =>
      _rdEventWorks().isEmpty ? _rdPickWorksFields() : _rdPickEventWorksFields(null, offerOther: true);

  // ---------------------------------------------------------------------------
  // "Werke vom … übernehmen": the Werke planned for the next Auftritt
  // ---------------------------------------------------------------------------

  /// The Termine whose planned Werke the open Ablauf can take over: the
  /// Termin itself, then the Auftritte after it (see
  /// [PlanSongHelper.eventWorks]).
  List<PlanEventWorks> _rdEventWorks() {
    final att = _att;
    if (att == null || _songs.isEmpty || ref.read(currentTenantProvider)?.type == 'general') return const [];
    return PlanSongHelper.eventWorks(att, attendances: _attendances, types: _types, history: _history, songs: _songs);
  }

  /// "Adventskonzert": the Termin's own title, else its Terminart.
  String _rdAttName(PlanAttendance a) => (a.typeInfo?.isNotEmpty ?? false) ? a.typeInfo! : (_typeOf(a)?.name ?? '');

  /// "Werke übernehmen": the Werke of the Termine as a checklist (the
  /// nearest one ticked); the rows of the chosen ones, each with the
  /// conductor planned there (empty: nothing chosen).
  /// [offerOther]: with "Anderes Werk", which leads to the Werk list.
  Future<List<PlanField>> _rdPickEventWorksFields(String? subtitle, {bool offerOther = false}) async {
    final l10n = context.l10n;
    final sources = _rdEventWorks();
    if (sources.isEmpty) return const [];
    final loadGen = _loadGen;
    String label(PlanEventWorks s) {
      if (s.own) return l10n.redesignPlanEventWorksThis;
      final d = DateTime.tryParse(s.att.date);
      String date;
      try {
        date = d == null ? s.att.date : DateFormat('EEE, d. MMM', currentIntlLocale()).format(d);
      } catch (_) {
        date = _rdDate(s.att);
      }
      final name = _rdAttName(s.att);
      return [if (name.isNotEmpty) name, date].join(' · ');
    }

    final chosen = await showRdEventWorksSheet(
      context,
      groups: [for (final s in sources) (label: label(s), works: s.works)],
      inPlanIds: _fields.map((f) => f.songId).whereType<int>().toSet(),
      subtitle: subtitle,
      offerOther: offerOther,
    );
    if (chosen == null || !_samePlan(loadGen)) return const [];
    if (chosen.other) return _rdPickWorksFields();
    final prefix = _songPrefix(_typeOf(_att));
    return [
      for (final w in chosen.works)
        PlanSongHelper.songField(
          w.song,
          history: [SongHistory(songId: w.song.id, conductorName: w.conductor)],
          prefix: prefix,
          time: PlanSongHelper.betaTime(w.song),
        ),
    ];
  }

  /// The Werke of the Termin (its own, else those of the next Auftritt)
  /// that are not in the Ablauf yet, as Werk and conductor.
  Future<List<({Song song, String conductor})>> _rdOpenWorks() async {
    final id = _att?.id;
    if (id == null || ref.read(currentTenantProvider)?.type == 'general') return const [];
    final RdEventWorks works;
    final List<Song> songs;
    try {
      works = await _container.read(rdEventWorksProvider(id).future);
      songs = await _container.read(planSongsProvider.future);
    } catch (_) {
      return const []; // the Ablauf opens as it is
    }
    final inPlan = _fields.map((f) => f.songId).whereType<int>().toSet();
    return [
      for (final e in works.entries)
        if (inPlan.add(e.songId))
          if (songs.where((s) => s.id == e.songId).firstOrNull case final song?)
            (song: song, conductor: e.otherConductor != null || e.conductorName != null ? e.displayConductor : ''),
    ];
  }

  /// The row of [song] in the Ablauf, [time] minutes long.
  PlanField _rdWorkRow(Song song, String conductor, String time) => PlanSongHelper.songField(
        song,
        history: [SongHistory(songId: song.id, conductorName: conductor.isEmpty ? null : conductor)],
        prefix: _songPrefix(_typeOf(_att)),
        time: time,
      );

  /// "Mit den Werken dieser Probe" / "Einfügen" (Termin › Programm): the
  /// Werke of the Termin that are not in the Ablauf yet go to its end,
  /// with "Rückgängig".
  Future<void> _rdStartWorks() async {
    final l10n = context.l10n;
    final loadGen = _loadGen;
    final open = await _rdOpenWorks();
    if (open.isEmpty || !_samePlan(loadGen)) return;
    final rows = [for (final w in open) _rdWorkRow(w.song, w.conductor, PlanSongHelper.betaTime(w.song))];
    _rdApplyWithUndo([..._fields, ...rows], l10n.redesignPlanWorksInserted(rows.length));
  }

  // ---------------------------------------------------------------------------
  // Start of a new Ablauf: Vorlage, copy of the last Termin
  // ---------------------------------------------------------------------------

  /// The Vorlagen for the open Termin (see [rdPlanTemplates]).
  List<RdPlanTemplate> _rdTemplates(PlanAttendance att) => rdPlanTemplates(
        type: _typeOf(att),
        auftritt: PlanSongHelper.isAuftritt(att, _types),
        tenantType: ref.read(currentTenantProvider)?.type,
        orgTemplates: ref.read(currentOrganisationProvider).valueOrNull?.planningTemplates ?? const [],
        blockTemplates: ref.read(planBlockTemplatesProvider).valueOrNull ?? const [],
      );

  /// "Aus einer Vorlage": the Vorlagen in a sheet, the chosen one becomes
  /// the Ablauf.
  Future<void> _rdPickTemplate() async {
    final att = _att;
    if (att == null) return;
    final loadGen = _loadGen;
    final id = await showRdPlanTemplateSheet(context, _rdTemplates(att), startTime: _time);
    if (id == null || !_samePlan(loadGen)) return;
    await _rdApplyTemplate(id);
  }

  /// The Vorlage [id] as the rows of the Ablauf (it begins when the Termin
  /// begins). The Werke of the Termin take the places for Werke: the Werk
  /// placeholders of a saved Vorlage, then rows like "Chor/Orchester" or
  /// "Werk 1" (see [rdFillWorkSlots]); "Rückgängig" leaves those as they
  /// were.
  Future<void> _rdApplyTemplate(String id) async {
    final att = _att;
    if (att == null) return;
    final l10n = context.l10n;
    final loadGen = _loadGen;
    final tpl = _rdTemplates(att).where((t) => t.id == id).firstOrNull;
    if (tpl == null) return;
    final empty = _fields.isEmpty;
    final open = await _rdOpenWorks();
    if (!_samePlan(loadGen)) return;
    if (tpl.block) {
      _rdApply([..._fields, ...PlanUtils.cloneBlock(tpl.fields)]);
      return;
    }
    // A whole Vorlage replaces the rows: not over something added meanwhile.
    if (empty && _fields.isNotEmpty) return;
    final conductors = {for (final w in open) w.song.id: w.conductor};
    final songs = [for (final w in open) w.song];
    final prefix = _songPrefix(_typeOf(att));
    // Fresh ids: a Vorlage can be applied to many Termine.
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final ids = <String, String>{};
    String fresh(String id) => ids.putIfAbsent(id, () => '$stamp-${ids.length}');
    final plain = [
      for (final f in tpl.fields)
        if (f.id.startsWith('song-placeholder-') || PlanUtils.isAgendaPlaceholder(f))
          f.copyWith(groupId: f.groupId == null ? null : fresh(f.groupId!))
        else
          f.copyWith(
            id: PlanUtils.isNote(f) ? 'noteFld ${fresh(f.id)}' : fresh(f.id),
            groupId: f.groupId == null ? null : fresh(f.groupId!),
            uid: null,
            beamerFile: null,
          ),
    ];
    // Without the Werke: the Vorlage as it is (Werk placeholders drop out).
    final bare = PlanSongHelper.resolvePlaceholders(plain, history: const [], songs: const [], prefix: prefix);
    final resolved = PlanSongHelper.resolvePlaceholders(
      plain,
      history: [for (final w in open) SongHistory(songId: w.song.id, conductorName: w.conductor.isEmpty ? null : w.conductor)],
      songs: songs,
      prefix: prefix,
    );
    final used = resolved.map((f) => f.songId).whereType<int>().toSet();
    final filled = rdFillWorkSlots(
      resolved,
      [for (final s in songs) if (!used.contains(s.id)) s],
      row: (song, time) => _rdWorkRow(song, conductors[song.id] ?? '', time),
    );
    final placed = used.length + filled.placed;
    _rdApply(bare);
    if (placed > 0) _rdApplyWithUndo(filled.fields, l10n.redesignPlanWorksPlaced(placed));
  }

  /// What the editor does once the Termin is loaded ([PlanningPage.start]):
  /// "works", "copy", `tpl:<id>` or "empty".
  Future<void> _rdStart(String start) async {
    final att = _att;
    if (att == null) return;
    switch (start) {
      case 'works':
        await _rdStartWorks();
      case 'copy':
        final previous = rdPreviousPlan(att, _attendances);
        if (previous != null && _fields.isEmpty) _rdCopyPrevious(previous.att, previous.plan);
      case _ when start.startsWith('tpl:'):
        if (_fields.isEmpty || start.startsWith('tpl:block:')) await _rdApplyTemplate(start.substring(4));
    }
  }

  // ---------------------------------------------------------------------------
  // Registerprobe (a block whose rounds are Unterpunkte)
  // ---------------------------------------------------------------------------

  /// "Registerprobe": the calculator with a preview, then a block with one
  /// Unterpunkt per round behind [after] (behind its whole block when it
  /// is in one) or at the end.
  Future<void> _rdInsertRegister({PlanField? after}) async {
    final l10n = context.l10n;
    final loadGen = _loadGen;
    int pos() {
      if (after == null) return _fields.length;
      final i = _fields.indexWhere((f) => _rdSame(f, after));
      if (i < 0) return _fields.length;
      final block = PlanUtils.isGroupHead(after) ? after.id : after.groupId;
      return block == null ? i + 1 : PlanUtils.lastIndexOfGroup(_fields, block) + 1;
    }

    final start = PlanUtils.parseTimeToMinutes(_time);
    final at = start == null ? null : PlanUtils.startMinutesAt(start, _fields, pos());
    final choice = await showRegisterPlanInsertSheet(
      context,
      startMinutes: at,
      subtitle: at == null ? null : l10n.redesignPlanRegisterStarts(PlanUtils.formatMinutes(at)),
    );
    if (choice == null || !mounted || loadGen != _loadGen) return;
    final rows = RegisterPlanService.blockFields(
      name: l10n.redesignPlanRegister,
      roundName: (n) => l10n.redesignPlanRegisterRound(n),
      groups: choice.groups,
      conductors: choice.conductors,
      totalMinutes: choice.minutes,
      empty: l10n.redesignPlanRegisterSelf,
    );
    final i = pos();
    _rdApply([..._fields.sublist(0, i), ...rows, ..._fields.sublist(i)]);
  }

  /// "Gruppen und Dirigenten ändern": the same sheet with the block's
  /// groups, order and minutes; the rounds are built again.
  Future<void> _rdChangeRegister(String headId) async {
    final l10n = context.l10n;
    final loadGen = _loadGen;
    final index = _fields.indexWhere((f) => f.id == headId);
    if (index < 0) return;
    final head = _fields[index];
    final settings = head.registerPlan;
    if (settings == null) return;
    final start = PlanUtils.parseTimeToMinutes(_time);
    final at = start == null ? null : PlanUtils.startMinutesAt(start, _fields, index);
    final choice = await showRegisterPlanInsertSheet(
      context,
      initial: settings,
      initialMinutes: PlanUtils.groupDuration(_fields, head.id),
      startMinutes: at,
      subtitle: at == null ? null : l10n.redesignPlanRegisterStarts(PlanUtils.formatMinutes(at)),
    );
    if (choice == null || !mounted || !_rdStill(loadGen, index, head)) return;
    final rows = RegisterPlanService.blockFields(
      name: head.name,
      roundName: (n) => l10n.redesignPlanRegisterRound(n),
      groups: choice.groups,
      conductors: choice.conductors,
      totalMinutes: choice.minutes,
      empty: l10n.redesignPlanRegisterSelf,
    );
    final newHead = head.copyWith(registerPlan: rows.first.registerPlan);
    final rounds = [for (final r in rows.skip(1)) r.copyWith(groupId: head.id)];
    final rest = [for (final f in _fields) if (f.groupId != head.id) f];
    final at2 = rest.indexWhere((f) => f.id == head.id);
    _rdCollapsed.remove(head.id);
    _rdApply([...rest.sublist(0, at2), newHead, ...rounds, ...rest.sublist(at2 + 1)]);
  }

  /// "Als Tabelle teilen": the old Registerprobenplan (saved as PDF or as
  /// a picture) with the rounds' clock times.
  Future<void> _rdShareRegister(String headId) async {
    final l10n = context.l10n;
    final loadGen = _loadGen;
    var index = _fields.indexWhere((f) => f.id == headId);
    if (index < 0 || _fields[index].registerPlan == null) return;
    var head = _fields[index];
    final how = await _rdSheet<String>(
      title: l10n.redesignPlanRegisterShare,
      subtitle: head.name,
      builder:
          (ctx, pop) => [
            RdGroupedList(
              children: [
                _rdSheetRow(
                  Icons.picture_as_pdf_outlined,
                  l10n.planningExportPdf,
                  null,
                  () => pop('pdf'),
                  key: const Key('rd-plan-register-pdf'),
                ),
                _rdSheetRow(
                  Icons.image_outlined,
                  l10n.redesignPlanShareImage,
                  null,
                  () => pop('img'),
                  key: const Key('rd-plan-register-image'),
                ),
              ],
            ),
          ],
    );
    // Another plan was loaded or the block is gone: nothing to share.
    if (how == null || !mounted || loadGen != _loadGen) return;
    index = _fields.indexWhere((f) => f.id == headId);
    if (index < 0 || _fields[index].registerPlan == null) return;
    head = _fields[index];
    // The rounds as they are now (moved, deleted, edited), with clock
    // times, or minutes from the block's start without a start time.
    final start = PlanUtils.parseTimeToMinutes(_time);
    final blockStart = PlanUtils.startMinutesAt(0, _fields, index);
    final rounds = <({String start, String? info})>[
      for (var i = index + 1; i < _fields.length; i++)
        if (_fields[i].groupId == head.id)
          (
            start:
                start == null
                    ? '${PlanUtils.startMinutesAt(0, _fields, i) - blockStart}'
                    : PlanUtils.formatMinutes(PlanUtils.startMinutesAt(start, _fields, i)),
            info: _fields[i].info,
          ),
    ];
    final plan = RegisterPlanService.tableOf(head.registerPlan!.groups, rounds);
    await exportRegisterPlan(
      context,
      ref,
      plan,
      attendanceDate: DateTime.tryParse(_att?.date ?? ''),
      timeLabel: start == null ? null : l10n.redesignPlanRegisterTime,
      asImage: how == 'img',
    );
  }


  /// "Block: …" in the item sheet: the block it belongs to, from a list.
  Future<void> _rdPickBlock(int index) async {
    final l10n = context.l10n;
    final field = _fields[index];
    final heads = _fields.where(PlanUtils.isGroupHead).toList();
    final loadGen = _loadGen;
    final choice = await _rdSheet<String>(
      title: l10n.redesignPlanPickBlock,
      subtitle: field.name,
      builder:
          (ctx, pop) => [
            RdGroupedList(
              children: [
                for (final (id, name) in [('', l10n.redesignPlanNoBlock), for (final h in heads) (h.id, h.name)])
                  RdListRow(
                    key: ValueKey('rd-plan-pick-block-$id'),
                    title: name,
                    showChevron: false,
                    onTap: () => pop(id),
                    trailing: Icon(
                      (field.groupId ?? '') == id ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                      color: (field.groupId ?? '') == id ? ctx.rd.link : ctx.rd.text2,
                    ),
                  ),
              ],
            ),
          ],
    );
    if (choice == null || !_rdStill(loadGen, index, field) || choice == (field.groupId ?? '')) return;
    final PlanField? anchor;
    final String? group;
    if (choice.isEmpty) {
      // Out of the block: right behind it.
      anchor = _fields[PlanUtils.lastIndexOfGroup(_fields, field.groupId!)];
      group = null;
    } else {
      if (!_fields.any((f) => f.id == choice)) return;
      anchor = _fields[PlanUtils.lastIndexOfGroup(_fields, choice)];
      group = choice;
      _rdCollapsed.remove(choice);
    }
    // The item itself may be the anchor (last of its block): stays in place.
    final result =
        identical(anchor, field)
            ? PlanUtils.normalizeGroups([..._fields]..[index] = field.copyWith(groupId: group))
            : _rdPlace([field], anchor, group);
    _rdApply(result);
  }

  Future<String?> _rdAddSheet(String subtitle) {
    final l10n = context.l10n;
    final tenant = ref.read(currentTenantProvider);
    final isGeneral = tenant?.type == 'general';
    final isAdmin = ref.read(effectiveRoleProvider).isAdmin;
    final blockTemplates = ref.read(planBlockTemplatesProvider).valueOrNull ?? const <PlanBlockTemplate>[];
    final org = ref.read(currentOrganisationProvider).valueOrNull;
    final orgTemplates = org?.planningTemplates ?? const <Plan>[];
    final orgFields = org?.defaultFields ?? const <PlanField>[];
    final hasProtocol = ref.read(protocolTypeByIdProvider(_att?.typeId))?.enableProtocol ?? false;
    final canInsertAgenda = hasProtocol && _planIndex == 0 && !_fields.any(PlanUtils.isAgendaPlaceholder);
    final canAddTopics = _canAddTopics;
    final canRegister = tenant?.type == 'choir' || tenant?.type == 'orchestra';
    final withWorks = !isGeneral && _songs.isNotEmpty;
    return _rdSheet<String>(
      title: l10n.redesignPlanAddTitle,
      subtitle: subtitle,
      builder:
          (ctx, pop) => [
            RdGroupedList(
              children: [
                // Punkt, Notiz, Block and Werke share one sheet (`_rdQuickAdd`).
                RdListRow(
                  key: const Key('rd-plan-add-field'),
                  leading: const RdRowIcon(Icons.add),
                  title: l10n.redesignPlanAddPoint,
                  subtitle: withWorks ? l10n.redesignPlanAddPointHint : l10n.redesignPlanAddPointHintNoWorks,
                  onTap: () => pop('field'),
                ),
                RdListRow(
                  key: const Key('rd-plan-add-block'),
                  leading: const RdRowIcon(Icons.view_agenda_outlined),
                  title: l10n.redesignPlanAddBlockRow,
                  subtitle: l10n.redesignPlanAddBlockRowHint,
                  onTap: () => pop('block'),
                ),
                if (canRegister)
                  RdListRow(
                    key: const Key('rd-plan-add-register'),
                    leading: const RdRowIcon(Icons.groups_outlined),
                    title: l10n.redesignPlanRegister,
                    subtitle: l10n.redesignPlanRegisterHint,
                    onTap: () => pop('register'),
                  ),
                if (canAddTopics)
                  _rdSheetRow(Icons.playlist_add_circle_outlined, l10n.attendanceAddTopics, null, () => pop('topics')),
                if (canInsertAgenda) _rdSheetRow(Icons.commit, l10n.planningInsertAgenda, null, () => pop('agenda')),
              ],
            ),
            if (blockTemplates.isNotEmpty || orgTemplates.isNotEmpty || orgFields.isNotEmpty) ...[
              const SizedBox(height: 20),
              RdGroupLabel(l10n.planningTemplates),
              RdGroupedList(
                children: [
                  for (final tpl in blockTemplates)
                    RdListRow(
                      leading: const RdRowIcon(Icons.view_agenda_outlined),
                      title: tpl.name,
                      subtitle: l10n.redesignPlanBlockTemplateHint(PlanUtils.templateMinutes(tpl)),
                      showChevron: false,
                      onTap: () => pop('block:${tpl.id}'),
                      trailing:
                          isAdmin
                              ? IconButton(
                                tooltip: l10n.redesignPlanTemplateDelete,
                                icon: Icon(Icons.delete_outline, color: ctx.rd.text2),
                                onPressed: () => pop('delblock:${tpl.id}'),
                              )
                              : null,
                    ),
                  for (var i = 0; i < orgTemplates.length; i++)
                    _rdSheetRow(
                      Icons.account_balance_outlined,
                      orgTemplates[i].title ?? '',
                      l10n.redesignPlanOrgTemplateHint,
                      () => pop('tpl:$i'),
                    ),
                  for (var i = 0; i < orgFields.length; i++)
                    _rdSheetRow(
                      Icons.account_balance_outlined,
                      orgFields[i].name,
                      l10n.redesignPlanOrgFieldHint(orgFields[i].time),
                      () => pop('orgfield:$i'),
                    ),
                ],
              ),
            ],
          ],
    );
  }

  // ---------------------------------------------------------------------------
  // Item and block sheets
  // ---------------------------------------------------------------------------

  /// Tap on an item: Bearbeiten, Punkt danach einfügen, Nach oben / unten,
  /// in den Block / aus dem Block, Löschen.
  Future<void> _rdItemSheet(int index) async {
    final l10n = context.l10n;
    final field = _fields[index];
    final start = PlanUtils.parseTimeToMinutes(_time);
    final isNote = PlanUtils.isNote(field);
    final head = field.groupId == null ? null : _fields.where((f) => f.id == field.groupId).firstOrNull;
    final at = start == null ? null : PlanUtils.startMinutesAt(start, _fields, index);
    final meta = [
      if (at != null && !isNote)
        '${PlanUtils.formatMinutes(at)}–${PlanUtils.formatMinutes(at + PlanUtils.minutesOf(field))}',
      if (head != null) l10n.redesignPlanInBlock(head.name),
    ].join(' · ');
    final isAgenda = PlanUtils.isAgendaPlaceholder(field);
    // "Block: …" picks the block from a list (also far away ones); the
    // Tagesordnung marker never joins a block.
    final hasBlocks = !isAgenda && _fields.any(PlanUtils.isGroupHead);
    final org = ref.read(currentOrganisationProvider).valueOrNull;
    final showBeamer = PlanBeamer.active(org, _isOrgPlan) && !isNote;
    final loadGen = _loadGen;
    // Fields are edited right in the sheet (no second dialog) and saved when
    // the sheet closes.
    PlanFieldInput? edit;
    final action = await _rdSheet<String>(
      title: isAgenda ? l10n.planningAgendaInsertPos : field.name,
      subtitle: meta.isEmpty ? null : meta,
      builder:
          (ctx, pop) => [
            if (!isAgenda) ...[
              RdPlanFieldForm(
                key: const Key('rd-plan-item-form'),
                labels: RdPlanFieldLabels(
                  name: isNote ? l10n.planningNote : l10n.planningItem,
                  nameHint: isNote ? l10n.planningEnterNote : l10n.planningEnterItem,
                  infoHint: l10n.planningInfoOptionalEllipsis,
                ),
                initialName: field.name,
                initialConductor: field.conductor,
                initialInfo: field.info,
                initialMinutes: int.tryParse(field.time) ?? 20,
                withConductor: !isNote,
                withInfo: !isNote,
                withMinutes: !isNote,
                beamer:
                    showBeamer
                        ? PlanFieldBeamerOptions(
                          manual: field.needsBeamer,
                          songId: field.songId,
                          file: _beamerFileOf(field),
                        )
                        : null,
                onChanged: (v) => edit = v,
                onSubmitted: () => Navigator.of(ctx).pop(),
              ),
              const SizedBox(height: 16),
            ],
            RdGroupedList(
              children: [
                if (hasBlocks)
                  RdListRow(
                    key: const Key('rd-plan-item-block'),
                    leading: const RdRowIcon(Icons.view_agenda_outlined),
                    title: l10n.redesignPlanBlockRow,
                    subtitle: head?.name ?? l10n.redesignPlanNoBlock,
                    onTap: () => pop('block'),
                  ),
                if (!isAgenda) _rdSheetRow(Icons.add, l10n.redesignPlanInsertAfter, null, () => pop('insert')),
                // Without any other entry the Tagesordnung marker can still move.
                if (isAgenda && index > 0)
                  _rdSheetRow(Icons.arrow_upward, l10n.redesignPlanMoveUp, null, () => pop('up')),
                if (isAgenda && index < _fields.length - 1)
                  _rdSheetRow(Icons.arrow_downward, l10n.redesignPlanMoveDown, null, () => pop('down')),
              ],
            ),
            const SizedBox(height: 12),
            RdGroupedList(
              children: [
                RdListRow(
                  key: const Key('rd-plan-item-delete'),
                  leading: RdRowIcon(Icons.delete_outline, color: ctx.rd.absent, background: ctx.rd.absentSoft),
                  title: l10n.redesignPlanDelete,
                  titleColor: ctx.rd.absent,
                  subtitle: l10n.redesignPlanDeleteHint,
                  showChevron: false,
                  onTap: () => pop('delete'),
                ),
              ],
            ),
          ],
    );
    // The plan may have changed meanwhile (draft restored, reload).
    if (!mounted || !_rdStill(loadGen, index, field)) return;
    var current = field;
    if (edit != null) {
      final e = edit!;
      final name = e.name.isEmpty ? field.name : e.name;
      final updated =
          isNote
              ? field.copyWith(name: name)
              : field.copyWith(
                name: name,
                conductor: e.conductor,
                info: e.info,
                time: e.minutes?.toString() ?? field.time,
                needsBeamer: showBeamer ? e.needsBeamer : field.needsBeamer,
              );
      if (!_rdSame(updated, field)) {
        _rdApply([..._fields]..[index] = updated);
        current = updated;
      }
    }
    if (action == null || !_rdStill(loadGen, index, current)) return;
    switch (action) {
      case 'insert':
        await _rdAdd(after: index, group: current.groupId);
      case 'up':
        _rdMove(index, -1);
      case 'down':
        _rdMove(index, 1);
      case 'block':
        await _rdPickBlock(index);
      case 'delete':
        _rdRemove([..._fields]..removeAt(index), current.name);
    }
  }

  /// Tap on a block: bearbeiten, Unterpunkt, Vorlage (Admins), Punkt
  /// danach, Nach oben / unten, auflösen, löschen.
  Future<void> _rdBlockSheet(int index) async {
    final l10n = context.l10n;
    final head = _fields[index];
    final start = PlanUtils.parseTimeToMinutes(_time);
    final children = PlanUtils.childrenOf(_fields, head.id);
    final isAdmin = ref.read(effectiveRoleProvider).isAdmin;
    final exists = (ref.read(planBlockTemplatesProvider).valueOrNull ?? const <PlanBlockTemplate>[]).any(
      (t) => t.name == head.name,
    );
    final loadGen = _loadGen;
    PlanFieldInput? edit;
    final action = await _rdSheet<String>(
      title: head.name,
      subtitle: [
        if (start != null) PlanUtils.groupRange(start, _fields, index),
        l10n.redesignPlanItemCount(children.length),
      ].join(' · '),
      builder:
          (ctx, pop) => [
            RdPlanFieldForm(
              key: const Key('rd-plan-block-form'),
              labels: RdPlanFieldLabels(
                name: l10n.planningName,
                nameHint: l10n.planningName,
                conductor: l10n.planningPerformance,
                conductorHint: l10n.planningPerformanceOptional,
              ),
              initialName: head.name,
              initialConductor: head.conductor,
              initialInfo: head.info,
              withMinutes: false,
              onChanged: (v) => edit = v,
              onSubmitted: () => Navigator.of(ctx).pop(),
            ),
            const SizedBox(height: 16),
            RdGroupedList(
              children: [
                if (head.registerPlan != null) ...[
                  _rdSheetRow(
                    Icons.groups_outlined,
                    l10n.redesignPlanRegisterChange,
                    l10n.redesignPlanRegisterChangeHint,
                    () => pop('register'),
                    key: const Key('rd-plan-block-register'),
                  ),
                  _rdSheetRow(
                    Icons.ios_share,
                    l10n.redesignPlanRegisterShare,
                    l10n.redesignPlanRegisterShareHint,
                    () => pop('share'),
                    key: const Key('rd-plan-block-share'),
                  ),
                ] else
                  _rdSheetRow(
                    Icons.subdirectory_arrow_right,
                    l10n.planningAddSubItem,
                    null,
                    () => pop('sub'),
                    key: const Key('rd-plan-block-sub'),
                  ),
                _rdSheetRow(Icons.add, l10n.redesignPlanAfterBlock, null, () => pop('insert')),
                if (isAdmin && children.isNotEmpty)
                  _rdSheetRow(
                    Icons.bookmark_add_outlined,
                    exists ? l10n.planningUpdateTemplate : l10n.planningSaveAsTemplate,
                    null,
                    () => pop('template'),
                  ),
                _rdSheetRow(Icons.call_split, l10n.planningDissolveBlock, null, () => pop('dissolve')),
              ],
            ),
            const SizedBox(height: 12),
            RdGroupedList(
              children: [
                RdListRow(
                  leading: RdRowIcon(Icons.delete_outline, color: ctx.rd.absent, background: ctx.rd.absentSoft),
                  title: l10n.redesignPlanDelete,
                  titleColor: ctx.rd.absent,
                  subtitle: l10n.redesignPlanDeleteHint,
                  showChevron: false,
                  onTap: () => pop('delete'),
                ),
              ],
            ),
          ],
    );
    if (!mounted || !_rdStill(loadGen, index, head)) return;
    var current = head;
    if (edit != null) {
      final e = edit!;
      final updated = head.copyWith(name: e.name.isEmpty ? head.name : e.name, conductor: e.conductor, info: e.info);
      if (!_rdSame(updated, head)) {
        _rdApply([for (final f in _fields) f.id == head.id ? updated : f]);
        current = updated;
      }
    }
    if (action == null || !_rdStill(loadGen, index, current)) return;
    switch (action) {
      case 'sub':
        await _rdQuickAdd(group: head.id);
      case 'register':
        await _rdChangeRegister(head.id);
      case 'share':
        await _rdShareRegister(head.id);
      case 'insert':
        await _rdAdd(after: PlanUtils.lastIndexOfGroup(_fields, head.id));
      case 'template':
        await _saveBlockTemplate(head);
      case 'dissolve':
        _rdCollapsed.remove(head.id);
        _rdApply(PlanUtils.dissolveGroup(_fields, head.id));
      case 'delete':
        if (children.isEmpty) {
          _rdRemove(_fields.where((f) => f.id != head.id).toList(), current.name);
          return;
        }
        final choice = await showAppDialog<String>(
          context: context,
          builder:
              (ctx) => AppAlertDialog(
                title: Text(ctx.l10n.planningDeleteBlockConfirm),
                content: Text(ctx.l10n.planningBlockHasItems(current.name, children.length)),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: Text(ctx.l10n.commonCancel)),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, 'dissolve'),
                    child: Text(ctx.l10n.planningOnlyDissolve),
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: ctx.rd.absent, foregroundColor: ctx.rd.onStatus),
                    onPressed: () => Navigator.pop(ctx, 'all'),
                    child: Text(ctx.l10n.planningDeleteAll),
                  ),
                ],
              ),
        );
        if (!mounted || !_rdStill(loadGen, index, current)) return;
        _rdCollapsed.remove(head.id);
        if (choice == 'dissolve') {
          _rdApply(PlanUtils.dissolveGroup(_fields, head.id));
        } else if (choice == 'all') {
          _rdRemove(PlanUtils.deleteGroup(_fields, head.id), current.name);
        }
    }
  }
}
