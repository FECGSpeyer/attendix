part of 'notification_bell.dart';

class _BellTarget {
  const _BellTarget(this.notification);
  final UserNotification notification;
}

class _NotificationCenter extends ConsumerStatefulWidget {
  const _NotificationCenter({required this.initialAllTenants, this.scrollController});

  final bool initialAllTenants;
  final ScrollController? scrollController;

  @override
  ConsumerState<_NotificationCenter> createState() => _NotificationCenterState();
}

class _NotificationCenterState extends ConsumerState<_NotificationCenter> {
  late bool _allTenants = widget.initialAllTenants;

  /// Local read-state overrides so toggled rows update in place.
  final Map<String, bool> _readOverrides = {};

  UserNotificationNotifier get _notifier => ref.read(userNotificationNotifierProvider.notifier);

  /// Reminders to answer an attendance event that the person has answered since
  /// (id -> accepted), see [bellAnsweredReminders]. They count as read.
  Map<String, bool> _answered = const {};

  /// Answered reminders already marked read on the server (once each).
  final Set<String> _autoRead = {};

  bool _isRead(UserNotification n) => _readOverrides[n.id] ?? (n.read || _answered.containsKey(n.id));

  /// Computes answered reminders of [list] and marks unread ones read on the server.
  Map<String, bool> _answeredReminders(List<UserNotification> list) {
    if (!list.any(bellAsksForAnswer)) return const {};
    final data = ref.watch(signoutDataProvider).valueOrNull;
    if (data == null) return const {};
    final own = [...data.allUpcoming, ...data.past];
    final answered = bellAnsweredReminders(list, (tenantId, attendanceId) {
      final matches = [
        for (final a in own)
          if (a.isMember && a.tenantId == tenantId && a.attendanceId == attendanceId) a,
      ];
      // Several entries (a parent's children): unclear whose answer is meant.
      return matches.length == 1 ? bellOwnAnswer(matches.single.status) : null;
    });
    final toMark = [
      for (final n in list)
        if (!n.read && answered.containsKey(n.id) && !_readOverrides.containsKey(n.id) && _autoRead.add(n.id)) n,
    ];
    if (toMark.isNotEmpty) {
      final notifier = _notifier;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        for (final n in toMark) {
          // Stays "Früher" in this sheet either way; a failed mark only
          // leaves the count as it was.
          notifier.setRead(n, true).catchError((Object _) {});
        }
      });
    }
    return answered;
  }

  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      if (mounted) ToastHelper.showError(context, context.l10n.svcSaveFailed);
    }
  }

  Future<void> _markAll() async {
    if (_allTenants) {
      final ok = await _confirm(
        title: context.l10n.bellMarkAllHeader,
        message: context.l10n.bellMarkAllMessage,
        confirmText: context.l10n.bellMark,
      );
      if (!ok) return;
    }
    _readOverrides.clear();
    await _guard(() => _notifier.markAllRead(allTenants: _allTenants));
  }

  Future<void> _deleteAll() async {
    final ok = await _confirm(
      title: context.l10n.bellDeleteAllHeader,
      message:
          _allTenants ? context.l10n.bellDeleteAllMessage : context.l10n.commonCannotUndo,
      confirmText: context.l10n.commonDelete,
      destructive: true,
    );
    if (!ok) return;
    await _guard(() => _notifier.deleteAll(allTenants: _allTenants));
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmText,
    bool destructive = false,
  }) async {
    final result = await showAppDialog<bool>(
      context: context,
      builder:
          (ctx) => AppAlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(ctx.l10n.commonCancel),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                style:
                    destructive
                        ? TextButton.styleFrom(foregroundColor: Theme.of(ctx).colorScheme.error)
                        : null,
                child: Text(confirmText),
              ),
            ],
          ),
    );
    return result ?? false;
  }

  Future<void> _toggleRead(UserNotification n) async {
    final newRead = !_isRead(n);
    setState(() => _readOverrides[n.id] = newRead);
    await _guard(() => _notifier.setRead(n, newRead));
  }

  Future<void> _onTap(UserNotification n) async {
    if (!_isRead(n)) {
      setState(() => _readOverrides[n.id] = true);
      await _guard(() => _notifier.setRead(n, true));
    }
    if (!mounted) return;
    Navigator.of(context).pop(_BellTarget(n));
  }

  String _tenantName(UserNotification n, List<Tenant> tenants) {
    for (final t in tenants) {
      if (t.id == n.tenantId) return t.shortName.isNotEmpty ? t.shortName : t.longName;
    }
    return '';
  }

  Future<void> _showMore(int unread, List<UserNotification> list) async {
    final l10n = context.l10n;
    final action = await showAppActionSheet<String>(
      context,
      actions: [
        if (unread > 0) AppActionSheetAction(value: 'read', icon: AppIcons.doneAll, label: l10n.bellMarkAllRead),
        if (list.isNotEmpty)
          AppActionSheetAction(value: 'delete', icon: AppIcons.deleteOutline, label: l10n.bellDeleteAll, destructive: true),
      ],
    );
    if (!mounted) return;
    if (action == 'read') await _markAll();
    if (action == 'delete') await _deleteAll();
  }

  Widget _buildView(
    AsyncValue<List<UserNotification>> listAsync,
    List<UserNotification> list,
    int unread,
    List<Tenant> tenants,
  ) {
    final p = context.rd;
    final l10n = context.l10n;
    _answered = _answeredReminders(list);
    final fresh = [for (final n in list) if (!_isRead(n)) n];
    final older = [for (final n in list) if (_isRead(n)) n];
    // Sign-in/out entries of one event form one block.
    final events = <(int, int)>{
      for (final item in groupBellEntries(list))
        if (item is BellEventGroup) (item.tenantId, item.attendanceId),
    };
    final labels = events.isEmpty
        ? const <(int, int), ({DateTime? date, String? name})>{}
        : ref.watch(bellEventLabelsProvider(bellEventLabelsKey(events))).valueOrNull ??
            const <(int, int), ({DateTime? date, String? name})>{};
    Widget group(String label, List<UserNotification> rows) {
      final blocks = <Widget>[];
      final singles = <Widget>[];
      void flush() {
        if (singles.isEmpty) return;
        blocks.add(RdGroupedList(children: [...singles]));
        singles.clear();
      }

      for (final item in groupBellEntries(rows)) {
        switch (item) {
          case BellSingle(:final notification):
            singles.add(_buildRow(notification, tenants));
          case BellEventGroup():
            flush();
            blocks.add(_buildEventGroup(item, tenants, labels[(item.tenantId, item.attendanceId)]));
        }
      }
      flush();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RdGroupLabel(label),
          for (var i = 0; i < blocks.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            blocks[i],
          ],
          const SizedBox(height: 18),
        ],
      );
    }

    final List<Widget> body;
    if (listAsync.isLoading && list.isEmpty) {
      body = [
        const SizedBox(height: 60),
        Center(child: CircularProgressIndicator(color: p.primary)),
      ];
    } else if (list.isEmpty) {
      body = [
        const SizedBox(height: 60),
        Icon(Icons.notifications_off_outlined, size: 44, color: p.text2),
        const SizedBox(height: 8),
        Text(l10n.bellNone, textAlign: TextAlign.center, style: RdType.meta(p, size: 15)),
      ];
    } else {
      body = [
        if (fresh.isNotEmpty) group(l10n.redesignMessagesBellNew, fresh),
        if (older.isNotEmpty) group(l10n.redesignMessagesBellEarlier, older),
      ];
    }
    // The group switch only matters with more than one group.
    final showGroupSwitch = tenants.length > 1 || _allTenants;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 16, 10),
          child: Row(
            children: [
              Expanded(
                child: Semantics(header: true, child: Text(l10n.bellTitle, style: RdType.section(p))),
              ),
              if (unread > 0 || list.isNotEmpty)
                RdCircleButton(
                  key: const Key('rd-bell-more'),
                  icon: Icons.more_horiz,
                  label: l10n.redesignManageListMore,
                  onPressed: () => _showMore(unread, list),
                ),
            ],
          ),
        ),
        if (showGroupSwitch)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: RdSegmented<bool>(
              values: const [false, true],
              selected: _allTenants,
              labelOf: (all) => all ? l10n.redesignMessagesBellAllGroups : l10n.redesignMessagesBellThisGroup,
              onChanged: (v) => setState(() {
                _allTenants = v;
                _readOverrides.clear();
              }),
            ),
          ),
        Expanded(
          child: RefreshIndicator(
            color: p.primary,
            backgroundColor: p.surface,
            onRefresh: () async {
              _readOverrides.clear();
              ref.invalidate(unreadNotificationCountProvider);
              ref.invalidate(userNotificationsProvider(_allTenants));
              await ref.read(userNotificationsProvider(_allTenants).future);
            },
            child: ListView(
              controller: widget.scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              children: body,
            ),
          ),
        ),
      ],
    );
  }

  /// Icon per kind of notification entry.
  static IconData _iconFor(String type) => switch (type) {
        'message' => Icons.mail_outline,
        'reminder' => Icons.event_outlined,
        'attendance' => Icons.how_to_reg_outlined,
        'pause' => Icons.pause_circle_outline,
        'birthday' => Icons.cake_outlined,
        'criticals' || 'CRITICAL_PERSON' => Icons.warning_amber_rounded,
        'registration' => Icons.person_add_alt_1_outlined,
        'task' || 'task_assigned' => Icons.task_alt,
        'checklist' => Icons.checklist,
        'protocol' || 'protocol_published' => Icons.description_outlined,
        'proposal' || 'proposal_decided' => Icons.lightbulb_outline,
        'assigned' || 'understaffed' || 'filled' || 'conjunction' || 'duty' => Icons.badge_outlined,
        _ => Icons.notifications_none,
      };

  Widget _unreadDot(bool read) {
    final p = context.rd;
    return SizedBox(
      width: 8,
      child: read
          ? null
          : Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: p.primary, shape: BoxShape.circle),
            ),
    );
  }

  /// Swipe right = read/unread, swipe left = delete.
  Widget _slidable(UserNotification n, Widget child) {
    final p = context.rd;
    final read = _isRead(n);
    return Slidable(
      key: ValueKey(n.id),
      startActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.22,
        children: [
          SlidableAction(
            onPressed: (_) => _toggleRead(n),
            backgroundColor: p.primary,
            foregroundColor: p.onPrimary,
            icon: read ? Icons.mark_email_unread_outlined : Icons.drafts_outlined,
          ),
        ],
      ),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.22,
        children: [
          SlidableAction(
            onPressed: (_) => _guard(() => _notifier.deleteOne(n)),
            backgroundColor: p.absent,
            foregroundColor: Colors.white,
            icon: Icons.delete_outline,
          ),
        ],
      ),
      child: child,
    );
  }

  String _relativeTime(UserNotification n) =>
      n.createdAt == null ? '' : bellRelativeTime(context.l10n, n.createdAt!, locale: currentIntlLocale());

  /// Single notification row with unread dot, icon, text, optional group and time.
  Widget _buildRow(UserNotification n, List<Tenant> tenants) {
    final read = _isRead(n);
    final tenantName = _allTenants ? _tenantName(n, tenants) : '';
    final body = n.body.replaceAll(RegExp(r'\s+'), ' ').trim();
    final l10n = context.l10n;
    final done = switch (_answered[n.id]) {
      null => null,
      true => l10n.redesignBellDoneAccepted,
      false => l10n.redesignBellDoneDeclined,
    };
    final subtitle = [if (done != null) done, if (tenantName.isNotEmpty) tenantName].join(' · ');
    return _slidable(
      n,
      RdListRow(
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [_unreadDot(read), const SizedBox(width: 8), RdRowIcon(_iconFor(n.type))],
        ),
        title: body,
        subtitle: subtitle.isEmpty ? null : subtitle,
        value: _relativeTime(n),
        showChevron: n.isNavigable,
        onTap: () => _onTap(n),
      ),
    );
  }

  /// Grouped attendance block for one event with per-person rows and open link.
  Widget _buildEventGroup(
    BellEventGroup group,
    List<Tenant> tenants,
    ({DateTime? date, String? name})? label,
  ) {
    final p = context.rd;
    final l10n = context.l10n;
    final locale = currentIntlLocale();
    final lines = [for (final n in group.entries) parseBellAttendanceBody(n.body)];
    BellAttendanceLine? firstLine;
    for (final line in lines) {
      firstLine ??= line;
    }
    final name = label?.name ?? firstLine?.eventInfo ?? l10n.redesignBellEvent;
    final date = label?.date ?? firstLine?.date;
    final title = [name, if (date != null) bellEventDay(l10n, date, locale: locale)].join(' · ');
    final tenantName = _allTenants ? _tenantName(group.entries.first, tenants) : '';
    final role = ref.watch(currentRoleProvider);
    final lead = role.isAdmin || role.isResponsible || role.isHelper || role.isVoiceLeaderHelper;

    final rows = <Widget>[
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: p.text),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              [if (tenantName.isNotEmpty) tenantName, l10n.redesignBellReports(group.entries.length)].join(' · '),
              style: RdType.meta(p, size: 13),
            ),
          ],
        ),
      ),
      for (var i = 0; i < group.entries.length; i++)
        _slidable(
          group.entries[i],
          RdListRow(
            leading: _unreadDot(_isRead(group.entries[i])),
            title: lines[i] == null
                ? group.entries[i].body.replaceAll(RegExp(r'\s+'), ' ').trim()
                : bellLineTitle(l10n, lines[i]!),
            subtitle: lines[i] == null ? null : bellLineDetail(l10n, lines[i]!),
            value: _relativeTime(group.entries[i]),
            showChevron: false,
            onTap: () => _onTap(group.entries[i]),
          ),
        ),
      Divider(height: 1, thickness: 1, color: p.line),
      RdListRow(
        key: ValueKey('rd-bell-open-${group.tenantId}-${group.attendanceId}'),
        title: lead ? l10n.redesignBellOpenAttendance : l10n.redesignBellOpenEvent,
        titleColor: p.link,
        onTap: () => _openGroup(group),
      ),
    ];
    return DecoratedBox(
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(p.listRadius),
        boxShadow: p.cardShadow,
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: BorderRadius.circular(p.listRadius),
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: rows),
      ),
    );
  }

  /// "Zur Anwesenheit": marks the block read and opens its Termin.
  Future<void> _openGroup(BellEventGroup group) async {
    final unread = [for (final n in group.entries) if (!_isRead(n)) n];
    if (unread.isNotEmpty) {
      setState(() {
        for (final n in unread) {
          _readOverrides[n.id] = true;
        }
      });
      // Captured before the first await: the marks finish even when the
      // sheet is closed meanwhile (no widget ref after dispose).
      final notifier = _notifier;
      final results = await Future.wait([
        for (final n in unread)
          notifier.setRead(n, true).then((_) => true, onError: (Object _) => false),
      ]);
      if (results.contains(false) && mounted) {
        ToastHelper.showError(context, context.l10n.svcSaveFailed);
      }
    }
    if (!mounted) return;
    Navigator.of(context).pop(_BellTarget(group.entries.first));
  }

  @override
  Widget build(BuildContext context) {
    final listAsync = ref.watch(userNotificationsProvider(_allTenants));
    final unread = ref.watch(unreadNotificationCountProvider).valueOrNull ?? 0;
    final tenants = ref.watch(userTenantsProvider).valueOrNull ?? const <Tenant>[];
    final list = listAsync.valueOrNull ?? const <UserNotification>[];
    return _buildView(listAsync, list, unread, tenants);
  }
}
