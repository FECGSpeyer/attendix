part of 'protocol_page.dart';

extension _ProtocolPageSections on _ProtocolPageState {
  // ── Loading ────────────────────────────────────────────────

  Future<void> _load() async {
    _update(() {
      _loading = true;
      _loadFailed = false;
    });
    try {
      final types = await ref.read(protocolTypesProvider.future);
      final results = await Future.wait([
        _repo.getAttendance(widget.attendanceId),
        _repo.getProtocolForAttendance(widget.attendanceId),
        _taskRepo.getTasksForAttendance(widget.attendanceId).catchError((_) => <TeamTask>[]),
      ]);
      final attendance = results[0] as ProtocolAttendance?;
      final protocol = results[1] as Protocol?;
      _attendance = attendance;
      _protocol = protocol;
      _tasks = results[2] as List<TeamTask>;
      _type = null;
      for (final t in types) {
        if (t.id == attendance?.typeId) _type = t;
      }
      if (!_isLeader && protocol == null) {
        _notAvailable = true;
        return;
      }
      if (attendance == null) {
        _loadFailed = true;
        return;
      }
      _docs = {
        for (final e in (protocol?.content ?? const <String, dynamic>{}).entries)
          if (e.value is Map) e.key: Map<String, dynamic>.from(e.value as Map),
      };
      _outcomes = {for (final e in (protocol?.outcomes ?? const {}).entries) e.key: e.value.toString()};
      _buildSections();
      await _buildLeftovers();
      _updateLive();
      _activeId = _live?.fieldId ?? (_sections.isNotEmpty ? _sections.first.id : null);
      _startLiveTimer();
    } catch (_) {
      _loadFailed = true;
    } finally {
      if (mounted) _update(() => _loading = false);
    }
  }

  String? get _planStart {
    final t = _attendance?.plan?['time']?.toString();
    if (t != null && t.isNotEmpty) return t;
    if (_attendance?.startTime?.isNotEmpty == true) return _attendance!.startTime;
    return _type?.startTime;
  }

  DateTime? get _planStartDateTime {
    final start = _planStart;
    final day = DateTime.tryParse(_attendance?.date ?? '')?.toLocal();
    if (start == null) return null;
    if (RegExp(r'^\d{1,2}:\d{2}').hasMatch(start) && !start.contains('T')) {
      if (day == null) return null;
      return parsePlanTime(start, day: day);
    }
    return DateTime.tryParse(start)?.toLocal();
  }

  void _buildSections() {
    final fields = protocolSections(_attendance?.fields);
    final numbers = topNumbers(fields);
    final times = fieldStartTimes(_planStart, fields);
    _sections = [
      for (final f in fields)
        _Section(
          id: fieldId(f),
          field: f,
          title: fieldDisplayName(f, numbers),
          name: fieldName(f),
          topNumber: numbers[fieldId(f)],
          start: times[fieldId(f)],
          duration: fieldMinutes(f),
          conductor: fieldConductor(f),
        ),
    ];
  }

  Future<void> _buildLeftovers() async {
    final known = {..._sections.map((s) => s.id), protocolGeneralSectionId, agendaItemsPlaceholderId};
    final entries = _docs.entries.where((e) => !known.contains(e.key) && !isDocEmpty(e.value)).toList();
    const legacy = '__agenda__';
    final ids = entries.where((e) => e.key.startsWith(legacy)).map((e) => e.key.substring(legacy.length)).toList();
    var items = <AgendaItem>[];
    if (ids.isNotEmpty) {
      try {
        items = await _agendaRepo.getAgendaItemsByIds(ids);
      } catch (e, st) {
        ErrorReporter.report(e, st, where: 'protocol_page');
      }
    }
    _leftovers = entries.map((e) {
      String title = l10nWithoutContext.protocolEarlierItem;
      if (e.key.startsWith(legacy)) {
        final id = e.key.substring(legacy.length);
        title = l10nWithoutContext.protocolAgendaItem;
        for (final i in items) {
          if (i.id == id) title = i.title;
        }
      }
      return _Leftover(e.key, title, e.value);
    }).toList();
  }

  // ── Live mode ──────────────────────────────────────────────

  void _updateLive() {
    _live = liveSection(_sections.map((s) => s.field).toList(), _planStartDateTime, DateTime.now());
  }

  void _startLiveTimer() {
    _liveTimer?.cancel();
    final d = DateTime.tryParse(_attendance?.date ?? '')?.toLocal();
    final now = DateTime.now();
    if (!_isLeader || d == null || d.year != now.year || d.month != now.month || d.day != now.day) return;
    _liveTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted) _update(_updateLive);
    });
  }

  // ── Editors & saving ───────────────────────────────────────

  /// [initialDoc]: content to show instead of `_docs[id]` (read-only
  /// leftovers are cached under `leftover:<key>` but their notes are stored
  /// under the original section key — SOL_FIX12, Ionic `[content]="l.doc"`).
  QuillController _controllerFor(String id, {bool readOnly = false, Map<String, dynamic>? initialDoc}) {
    final existing = _controllers[id];
    if (existing != null) return existing;
    final parts = tiptapToDelta(initialDoc ?? _docs[id]);
    Document document;
    try {
      document = Document.fromJson(parts.ops);
    } catch (_) {
      document = Document();
    }
    final controller = QuillController(
      document: document,
      selection: const TextSelection.collapsed(offset: 0),
      readOnly: readOnly || !_isLeader,
    );
    if (_isLeader && !readOnly) {
      _subscriptions[id] = _listenLocalChanges(id, document);
    }
    _controllers[id] = controller;
    return controller;
  }

  StreamSubscription<DocChange> _listenLocalChanges(String id, Document document) {
    return document.changes.listen((change) {
      if (change.source != ChangeSource.local) return;
      _editCount[id] = (_editCount[id] ?? 0) + 1;
      _queueSave(id);
    });
  }

  /// Shows [doc] (saved by another leader) in the open editor of [id]
  /// without queueing a save.
  void _replaceEditorDoc(String id, QuillController controller, Map<String, dynamic> doc) {
    Document document;
    try {
      document = Document.fromJson(tiptapToDelta(doc).ops);
    } catch (_) {
      return;
    }
    _subscriptions.remove(id)?.cancel();
    controller.document = document;
    if (_isLeader && !controller.readOnly) {
      _subscriptions[id] = _listenLocalChanges(id, document);
    }
  }

  Map<String, dynamic>? _currentDoc(String id) {
    final c = _controllers[id];
    if (c == null || _disposed) return _docs[id];
    return deltaToTiptap(c.document.toDelta().toJson());
  }

  void _queueSave(String id) {
    _pending.add(id);
    _timers[id]?.cancel();
    _timers[id] = Timer(_saveDebounce, () => _flush(id));
  }

  /// Saves section [id] now (after a save of the same section that is still
  /// running). Returns false when the save failed (the section stays pending).
  Future<bool> _flush(String id) {
    _timers.remove(id)?.cancel();
    return chainProtocolSectionSave(_inFlight, id, () => _saveSectionNow(id));
  }

  Future<bool> _saveSectionNow(String id) async {
    if (!_pending.remove(id)) return true;
    final doc = _currentDoc(id);
    if (doc == null) return true;
    if (mounted) {
      _update(() {
        _docs[id] = doc;
        _savingCount++;
      });
    } else {
      _docs[id] = doc;
      _savingCount++;
    }
    try {
      final row = await _repo.saveSection(widget.attendanceId, id, doc: doc);
      _applyRow(row);
      _lastSavedAt = DateTime.now();
      return true;
    } catch (_) {
      _pending.add(id);
      if (mounted && DateTime.now().difference(_lastErrorToast).inSeconds > 10) {
        _lastErrorToast = DateTime.now();
        ToastHelper.showError(context, context.l10n.protocolNotesSaveFailed);
      }
      return false;
    } finally {
      if (mounted) {
        _update(() => _savingCount--);
      } else {
        _savingCount--;
      }
    }
  }

  /// Saves everything that is still waiting and awaits saves already running
  /// (SOL_FIX2). Returns false when any section could not be saved.
  Future<bool> _flushAll() async {
    if (!_isLeader) return true;
    // Running saves first: a failure puts the section back into _pending,
    // the retry below decides the result.
    await Future.wait(_inFlight.values.toList());
    final ids = {..._pending, ..._inFlight.keys};
    final results = await Future.wait(ids.map(_flush));
    return results.every((ok) => ok);
  }

  /// Takes over meta data of the saved row; local notes and results stay.
  void _applyRow(Protocol? row) {
    if (row == null) return;
    _protocol = (_protocol ?? row).copyWith(
      id: row.id,
      status: row.status,
      publishedAt: row.publishedAt,
      publishedBy: row.publishedBy,
      updatedAt: row.updatedAt,
    );
  }

  Future<void> _setOutcome(String id, String outcome) async {
    final previous = _outcomes[id];
    final next = previous == outcome ? null : outcome;
    _update(() {
      if (next == null) {
        _outcomes.remove(id);
      } else {
        _outcomes[id] = next;
      }
      _savingCount++;
    });
    try {
      final row = await _repo.saveSection(widget.attendanceId, id, outcome: next, clearOutcome: next == null);
      _applyRow(row);
      _lastSavedAt = DateTime.now();
    } catch (_) {
      _update(() {
        if (previous == null) {
          _outcomes.remove(id);
        } else {
          _outcomes[id] = previous;
        }
      });
      if (mounted) ToastHelper.showError(context, context.l10n.protocolOutcomeSaveFailed);
    } finally {
      if (mounted) _update(() => _savingCount--);
    }
  }

  /// Tasks need the protocol id; saving an empty change creates the protocol row.
  Future<String?> _ensureProtocol() async {
    if (_protocol?.id != null) return _protocol!.id;
    final row = await _repo.saveSection(widget.attendanceId, protocolGeneralSectionId);
    _applyRow(row);
    return row?.id;
  }

  // ── Tasks ──────────────────────────────────────────────────

  Map<String, String> get _taskSectionMap {
    final result = <String, String>{};
    final ids = {..._docs.keys, ..._controllers.keys};
    for (final id in ids) {
      if (id.startsWith('leftover:')) continue;
      for (final tid in taskRefIds(_currentDoc(id))) {
        result.putIfAbsent(tid, () => id);
      }
    }
    for (final t in _tasks) {
      if (t.id == null || result.containsKey(t.id) || t.agendaItemId == null) continue;
      for (final s in _sections) {
        if (s.agendaItemId == t.agendaItemId) {
          result[t.id!] = s.id;
          break;
        }
      }
    }
    return result;
  }

  List<TeamTask> _tasksFor(String sectionId, Map<String, String> map) =>
      _tasks.where((t) => t.id != null && map[t.id] == sectionId).toList();

  List<TeamTask> _unassignedTasks(Map<String, String> map) {
    final ids = _sections.map((s) => s.id).toSet();
    return _tasks.where((t) => t.id == null || !ids.contains(map[t.id])).toList();
  }

  Future<void> _createTask(String sectionId) async {
    _Section? section;
    for (final s in _sections) {
      if (s.id == sectionId) section = s;
    }
    String? protocolId;
    try {
      protocolId = await _ensureProtocol();
    } catch (_) {
      if (mounted) ToastHelper.showError(context, context.l10n.protocolCreateFailed);
      return;
    }
    if (!mounted) return;
    final task = await showTaskFormSheet(
      context,
      attendanceId: widget.attendanceId,
      protocolId: protocolId,
      agendaItemId: section?.agendaItemId,
      contextLabel: section?.title ?? context.l10n.protocolGeneralNotes,
    );
    if (task?.id == null || !mounted) return;
    // Put a task reference into the section's notes (at the cursor) so it maps to the section.
    final node = taskRefNode(id: task!.id!, title: task.title, status: task.status);
    insertRefEmbed(_controllerFor(sectionId), taskRefEmbedType, Map<String, dynamic>.from(node['attrs'] as Map));
    _update(() => _tasks = [..._tasks.where((t) => t.id != task.id), task]);
    _pending.add(sectionId);
    await _flush(sectionId);
    try {
      final tasks = await _taskRepo.getTasksForAttendance(widget.attendanceId);
      if (mounted) _update(() => _tasks = tasks);
    } catch (_) {
      // P10_SONGS_ORG: Ionic keeps the local list (the task is already in
      // it – adding it again duplicated the row).
    }
  }
}
