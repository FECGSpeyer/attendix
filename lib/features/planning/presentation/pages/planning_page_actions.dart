part of 'planning_page.dart';

/// Adding items/works/templates and Registerprobe actions for [PlanningPage].
extension _PlanningActions on _PlanningPageState {
  // ---------------------------------------------------------------------------
  // Adding
  // ---------------------------------------------------------------------------

  /// "+ Hinzufügen" (at the end) or "Punkt danach einfügen" ([after]:
  /// position in [_fields]; [group]: the block the new item joins).
  /// Appended rows are moved to the chosen place afterwards.
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
  // Start of a new Ablauf: Vorlage
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

  /// What the editor does once the Termin is loaded: "works", "copy",
  /// `tpl:<id>` or "empty".
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

  /// "Als Tabelle teilen": exports the Registerprobenplan as PDF or picture
  /// with the rounds' clock times.
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
}
