part of 'live_activity_service.dart';

/// Polling, sync loop, and running-plan matching for [LiveActivityService].
mixin _LiveActivitySyncMixin on _LiveActivityServiceCore {
  /// Called from the notification settings toggle.
  Future<void> setEnabled(bool enabled) async {
    _enabled = enabled;
    // SOL_FIX17: invalidate a sync that is still loading plans (it would
    // restart the activities that are ended here), and release its flag.
    _enableEpoch++;
    _syncing = false;
    if (!_supported) return;
    if (!enabled) {
      _lastKeys.clear();
      _ownedKeys.clear();
      try {
        await _channel.invokeMethod<void>('endAll');
      } catch (_) {}
    } else {
      await sync();
    }
  }

  /// Called from the notification settings sub-toggle "ORG-Pläne anderer Gruppen".
  Future<void> setOrgPlansEnabled(bool enabled) async {
    _orgPlansEnabled = enabled;
    _enableEpoch++;
    _syncing = false;
    if (!_supported || !_enabled) return;
    await sync();
  }

  /// Syncs now and every [LiveActivityService.syncInterval]; completes after the first sync.
  @override
  Future<void> startLoop() {
    stopLoop();
    _timer = Timer.periodic(LiveActivityService.syncInterval, (_) => sync());
    return sync();
  }

  @override
  void stopLoop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Starts, updates and ends Live Activities to match the plans running right now.
  Future<void> sync() async {
    if (!_supported || _syncing) return;
    // SOL_FIX19: no native changes while a session teardown runs.
    if (_teardowns.isNotEmpty) return;
    final generation = _generation;
    final epoch = _enableEpoch;
    // SOL_FIX16 session generation + SOL_FIX17 enable epoch.
    bool stale() => _isStale(generation) || epoch != _enableEpoch;
    if (_host.tenantId == null) {
      // SOL_FIX15: no tenant (logged out / cleared) → nothing may stay on lock screen.
      if (_lastKeys.isNotEmpty) {
        _lastKeys.clear();
        try {
          await _channel.invokeMethod<void>('endAll');
        } catch (_) {}
      }
      return;
    }
    _syncing = true;
    try {
      final running = _enabled ? await runningPlans() : null;
      if (stale()) return;
      final candidates = running?.candidates ?? const <LivePlanCandidate>[];
      final attendanceIds = running?.attendanceIds;
      final listed = await _channel.invokeMapMethod<String, dynamic>('list');
      if (stale()) return;
      final activities = ((listed?['activities'] as List?) ?? const [])
          .map(LiveActivityTarget.fromMap)
          .whereType<LiveActivityTarget>()
          .toList();
      final wanted = candidates.map((c) => c.key).toSet();

      for (final c in candidates) {
        if (!await _syncCandidate(c, activities, stale)) return;
      }
      await _endStaleActivities(activities, wanted, attendanceIds, stale);
    } catch (e) {
      _log('sync', e);
    } finally {
      // A stale sync must not release the flag of the next session's sync.
      if (!stale()) _syncing = false;
    }
  }

  /// Applies start/update/end for a single candidate; returns false if [stale] became true.
  Future<bool> _syncCandidate(
    LivePlanCandidate c,
    List<LiveActivityTarget> activities,
    bool Function() stale,
  ) async {
    final k = c.key;
    final stateKey = liveStateKey(c.state);
    final isRunning = activities.any((a) => a.key == k);
    if (isRunning && _lastKeys[k] == stateKey) {
      _ownedKeys.add(k);
      return true;
    }
    // Ionic: iOS gets iosLiveState, Android the raw state.
    final shown = (_isAndroid ? c.state : iosLiveState(c.state)).toMap();
    if (stale()) return false;
    if (c.state.phase == 'ended') {
      if (isRunning) {
        await _channel.invokeMethod<void>('end', {
          'attendanceId': c.attendanceId,
          'planKey': c.planKey,
          'state': shown,
        });
        _ownedKeys.remove(k);
      }
    } else if (isRunning) {
      await _channel.invokeMethod<void>('update', {
        'attendanceId': c.attendanceId,
        'planKey': c.planKey,
        'state': shown,
      });
      _ownedKeys.add(k);
    } else {
      if (!_enabled) return true;
      await _channel.invokeMethod<void>('start', {
        'attendanceId': c.attendanceId,
        'planKey': c.planKey,
        'title': c.title,
        'state': shown,
      });
      _ownedKeys.add(k);
    }
    _lastKeys[k] = stateKey;
    return true;
  }

  /// Ends activities that are over, deleted, archived, un-planned, or no longer visible.
  Future<void> _endStaleActivities(
    List<LiveActivityTarget> activities,
    Set<String> wanted,
    Set<int>? attendanceIds,
    bool Function() stale,
  ) async {
    for (final a in activities) {
      if (wanted.contains(a.key)) continue;
      final isDisabledAdHocOrg =
          !_orgPlansEnabled && a.attendanceId == 0 && a.planKey.startsWith('org-');
      var shouldEnd = attendanceIds == null ||
          attendanceIds.contains(a.attendanceId) ||
          _ownedKeys.contains(a.key) ||
          isDisabledAdHocOrg;
      if (!shouldEnd) {
        shouldEnd = !await _host.isActivityStillValid(a);
        if (stale()) return;
      }
      if (!shouldEnd) continue;
      if (stale()) return;
      await _channel.invokeMethod<void>('end', {
        'attendanceId': a.attendanceId,
        'planKey': a.planKey,
        'immediate': true,
      });
      _lastKeys.remove(a.key);
      _ownedKeys.remove(a.key);
    }
  }

  /// Plans of the current tenant whose live window contains now.
  Future<({List<LivePlanCandidate> candidates, Set<int> attendanceIds})>
      runningPlans() async {
    final role = _host.role;
    final isLeader = role.isAdmin || role.isResponsible;
    final timezone = _host.timezone.isNotEmpty ? _host.timezone : 'Europe/Berlin';
    final now = _now();
    final today = DateTime.fromMillisecondsSinceEpoch(now);
    final from = DateTime(
      today.year,
      today.month,
      today.day - LiveActivityService.lookbackDays,
    );
    final to = DateTime(today.year, today.month, today.day + 1, 23, 59, 59, 999);
    final attendances = await _host.loadAttendances(from, to);
    final types = await _host.termTypes();
    final attendanceIds = attendances.map((a) => a.id).whereType<int>().toSet();
    Set<int>? playerVisibleIds;
    if (!role.canSeeAttendanceTab &&
        !role.isViewer &&
        attendanceIds.isNotEmpty) {
      playerVisibleIds =
          await _host.loadVisiblePlayerAttendanceIds(attendanceIds.toList());
    }

    final result = <LivePlanCandidate>[];
    for (final att in attendances) {
      final id = att.id;
      if (id == null) continue;
      if (role.isViewer || (!isLeader && !att.sharePlan)) continue;
      if (playerVisibleIds != null && !playerVisibleIds.contains(id)) continue;
      final plans = PlanUtils.allPlans(att);
      final type = types[att.typeId];
      final typeName = type?.name ?? '';
      for (var index = 0; index < plans.length; index++) {
        if (!isPlanPublished(plans[index])) continue;
        final state = withLiveColor(
          liveStateAt(liveSchedule(att, index, timezone, plans), now),
          type?.color,
        );
        if (state == null) continue;
        result.add(LivePlanCandidate(
          attendanceId: id,
          planKey: livePlanKey(plans[index]),
          title: liveTitle(att, typeName, index, plans),
          state: state,
        ));
      }
    }
    if (isLeader && _orgPlansEnabled) {
      await _addOrgPlans(result, attendanceIds, timezone, now);
    }
    return (candidates: result, attendanceIds: attendanceIds);
  }

  /// ORG plans of the organisation (Termine of all its choirs marked as
  /// ORG plan, plan 1 only, and ad-hoc ORG plans), for admins and
  /// Verantwortliche like the ORG-Pläne page (Ionic 4.17.8 `addOrgPlans`).
  Future<void> _addOrgPlans(
    List<LivePlanCandidate> result,
    Set<int> attendanceIds,
    String timezone,
    int now,
  ) async {
    final today = DateTime.fromMillisecondsSinceEpoch(now);
    final from = DateTime(today.year, today.month, today.day - 1);
    final to = DateTime(today.year, today.month, today.day + 1, 23, 59, 59, 999);
    LiveOrgPlans? org;
    try {
      org = await _host.loadOrgPlans(from, to);
    } catch (e) {
      // Without the ORG plans their activities are left alone (not ended).
      _log('org plans', e);
      return;
    }
    if (org == null) return;

    for (final entry in org.attendances) {
      final att = entry.attendance;
      final id = att.id;
      final plan = att.plan;
      if (id == null) continue;
      attendanceIds.add(id);
      if (plan == null || !isPlanPublished(plan)) continue;
      if (result.any((c) => c.attendanceId == id && c.planKey == 'main')) continue;
      final state = withLiveColor(
        liveStateAt(liveSchedule(att, 0, timezone, [plan]), now),
        entry.typeColor,
      );
      if (state == null) continue;
      final baseTitle = liveTitle(att, entry.typeName, 0, [plan]);
      final group = entry.tenantName.trim();
      final orgTag = group.isNotEmpty ? 'ORG · $group' : 'ORG';
      result.add(LivePlanCandidate(
        attendanceId: id,
        planKey: 'main',
        title: '$baseTitle · $orgTag',
        state: state,
      ));
    }

    attendanceIds.add(0);
    for (final sp in org.sharedPlans) {
      final date = sp.date ?? '';
      final time = sp.time ?? '';
      if (date.isEmpty ||
          time.isEmpty ||
          sp.fields.isEmpty ||
          !isPlanPublished(sp)) {
        continue;
      }
      final state = liveStateAt(
        buildSchedule(
          date: date,
          planTime: time,
          fields: sp.fields,
          timezone: timezone,
        ),
        now,
      );
      if (state == null) continue;
      final rawTitle = sp.planTitle?.trim() ?? '';
      final title = rawTitle.isEmpty
          ? 'ORG-Plan'
          : (rawTitle.toUpperCase().contains('ORG') ? rawTitle : '$rawTitle · ORG');
      result.add(LivePlanCandidate(
        attendanceId: 0,
        planKey: 'org-${sp.id}',
        title: title,
        state: state,
      ));
    }
  }
}
