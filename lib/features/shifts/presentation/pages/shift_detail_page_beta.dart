part of 'shift_detail_page.dart';

/// REDESIGN (Termin-Werkzeuge T3): "Schichtplan bearbeiten" in the Beta look.
/// Saves right away; Abschnitte and feste Schichten are rows that open a
/// sheet; the Beispiel-Rechnung is a row; "In Gruppe kopieren" sits behind
/// •••, Löschen at the bottom. Data and update are the classic page's.
extension _ShiftDetailBeta on _ShiftDetailPageState {
  Widget _rdBuild(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final shiftAsync = ref.watch(shiftByIdProvider(widget.shiftId));
    final usageCount = ref.watch(shiftUsageCountProvider(widget.shiftId));
    final targets = ref.watch(shiftCopyTargetTenantsProvider).valueOrNull ?? const [];
    final shift = shiftAsync.valueOrNull;
    if (shift != null) _initializeFromShift(shift);
    final isUsed = _rdLocked(usageCount);

    final children = <Widget>[
      Row(
        children: [
          Expanded(child: RdBackLink(label: l10n.generalSettingsShiftPlans, onTap: _goBack)),
          if (shift != null)
            Text(_isLoading ? l10n.redesignPlanSaving : l10n.redesignPlanSaved, style: RdType.meta(p, size: 14)),
          if (targets.isNotEmpty && shift != null) ...[
            const SizedBox(width: 8),
            RdCircleButton(
              icon: Icons.more_horiz,
              label: l10n.redesignPlanMore,
              onPressed: () async {
                final a = await showRdPlanActionSheet<String>(
                  context,
                  title: _nameController.text.trim(),
                  actions: [PlanSheetAction('copy', l10n.shiftsCopyToTenant, icon: Icons.copy_outlined)],
                );
                if (a == 'copy' && context.mounted) await _copyToTenant(context, shift);
              },
            ),
          ],
        ],
      ),
      const SizedBox(height: 4),
      Semantics(
        header: true,
        child: Text(
          _nameController.text.trim().isEmpty ? l10n.shiftsEdit : _nameController.text.trim(),
          style: RdType.title(p),
        ),
      ),
      const SizedBox(height: 16),
    ];

    if (shift == null) {
      children.add(
        shiftAsync.hasError
            ? RdInfoCard(
              icon: Icons.error_outline,
              text: l10n.shiftsFlutterErrorWith(friendlyErrorMessage(shiftAsync.error!)),
            )
            : shiftAsync.isLoading
            ? RdInfoCard(text: l10n.redesignTodayLoading, loading: true)
            : RdInfoCard(icon: Icons.error_outline, text: l10n.shiftsFlutterNotFound),
      );
      return RdPage(children: children);
    }

    children.addAll([
      RdInfoCard(icon: Icons.warning_amber_outlined, text: l10n.shiftsWarning),
      const SizedBox(height: 16),
      RdGroupedList(
        children: [
          RdPlanTextRow(label: l10n.typeSettingsName, controller: _nameController, onChanged: (_) => _rdTyped()),
          RdPlanTextRow(label: l10n.tasksDescription, controller: _descriptionController, onChanged: (_) => _rdTyped()),
        ],
      ),
      const SizedBox(height: 16),
      RdGroupLabel(l10n.shiftsDefinition),
      RdGroupedList(
        children: [
          for (var i = 0; i < _definitions.length; i++)
            RdListRow(
              key: ValueKey('rd-seg-$i'),
              leading: RdRowIcon(_definitions[i].free ? Icons.weekend_outlined : Icons.work_outline),
              title: l10n.shiftsSection(i + 1),
              subtitle: _rdSegmentSummary(_definitions[i]),
              onTap: () => _rdSegmentSheet(i),
            ),
          RdListRow(
            leading: Icon(Icons.add, color: p.link),
            title: l10n.shiftsFlutterAddSegment,
            titleColor: p.link,
            showChevron: false,
            onTap: () {
              _addSegment();
              _rdChanged();
              _rdSegmentSheet(_definitions.length - 1);
            },
          ),
        ],
      ),
      if (_definitions.isNotEmpty) ...[
        const SizedBox(height: 12),
        RdGroupedList(
          children: [
            RdListRow(
              leading: const RdRowIcon(Icons.calculate_outlined),
              title: l10n.shiftsExample,
              onTap: () => _showPreview(context, shift, null),
            ),
          ],
        ),
      ],
      const SizedBox(height: 16),
      RdGroupLabel(l10n.shiftsFixedOptional),
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
        child: Text(l10n.shiftsFixedIntro, style: RdType.meta(p, size: 14)),
      ),
      RdGroupedList(
        children: [
          for (var i = 0; i < _shifts.length; i++)
            RdListRow(
              key: ValueKey('rd-fixed-$i'),
              leading: const RdRowIcon(Icons.event_repeat),
              title: _shifts[i].name.isEmpty ? l10n.redesignShiftUnnamed : _shifts[i].name,
              subtitle: [
                l10n.redesignShiftFrom(_rdDate(_shifts[i].date)),
                if (isUsed) l10n.redesignShiftLocked,
              ].join(' · '),
              onTap: () => _rdFixedSheet(i, shift, isUsed),
            ),
          if (!isUsed)
            RdListRow(
              leading: Icon(Icons.add, color: p.link),
              title: l10n.shiftsFlutterAddShift,
              titleColor: p.link,
              showChevron: false,
              onTap: () {
                _addShiftInstance();
                _rdChanged();
                _rdFixedSheet(_shifts.length - 1, shift, isUsed);
              },
            ),
        ],
      ),
      const SizedBox(height: 24),
      RdGroupedList(
        children: [
          RdListRow(
            leading: RdRowIcon(Icons.delete_outline, color: p.absent, background: p.absentSoft),
            title: l10n.shiftsDelete,
            titleColor: p.absent,
            showChevron: false,
            onTap: () => _confirmDelete(context),
          ),
        ],
      ),
    ]);
    return RdPage(children: children);
  }

  String _rdDate(String iso) {
    final d = DateTime.tryParse(iso);
    return d == null ? '' : DateFormat.yMMMd(currentIntlLocale()).format(d);
  }

  String _rdSegmentSummary(ShiftDefinition d) {
    final l10n = context.l10n;
    return [
      if (d.free)
        l10n.shiftsFree
      else ...[
        l10n.redesignShiftFrom(d.startTime),
        l10n.redesignShiftHours(_ShiftDetailPageState._formatNumber(d.duration)),
      ],
      l10n.redesignShiftTimes(d.repeatCount),
    ].join(' · ');
  }

  void _rdTyped() {
    _update(() => _hasChanges = true);
    _rdChanged();
  }

  /// Every change is saved shortly after (typing in the name).
  void _rdChanged() {
    _rdNotifier ??= ref.read(shiftNotifierProvider.notifier);
    _rdSaveTimer?.cancel();
    _rdSaveTimer = Timer(const Duration(milliseconds: 700), _rdSave);
  }

  Future<void> _rdSave() async {
    if (!mounted || !_hasChanges) return;
    if (_isLoading) return _rdChanged();
    if (_nameController.text.trim().isEmpty) {
      ToastHelper.showError(context, context.l10n.shiftsEnterName);
      return;
    }
    final notifier = ref.read(shiftNotifierProvider.notifier);
    _update(() {
      _isLoading = true;
      _hasChanges = false;
    });
    final save = _rdChain.then((_) => notifier.updateShift(_rdPlan()));
    _rdChain = save.then((_) {}, onError: (_) {});
    final result = await save;
    if (!mounted) return;
    _update(() => _isLoading = false);
    if (result == null) {
      _update(() => _hasChanges = true);
      final error = ref.read(shiftNotifierProvider);
      if (error.hasError) {
        ToastHelper.showError(context, context.l10n.shiftsFlutterErrorWith(friendlyErrorMessage(error.error)));
      }
    }
  }

  ShiftPlan _rdPlan() => ShiftPlan(
    id: widget.shiftId,
    name: _nameController.text.trim(),
    description: _descriptionController.text.trim(),
    definition: _numberedDefinitions(),
    shifts: _shifts,
  );

  /// Abschnitt: Schicht / Frei, Startzeit, Dauer and Wiederholungen with
  /// steps; Entfernen at the bottom. Applied right away.
  Future<void> _rdSegmentSheet(int index) async {
    final l10n = context.l10n;
    final remove = await showRdPlanSheet<bool>(
      context,
      title: l10n.shiftsSection(index + 1),
      builder:
          (ctx, pop) => [
            StatefulBuilder(
              builder: (ctx, setSheet) {
                if (index >= _definitions.length) return const SizedBox.shrink();
                final p = ctx.rd;
                final d = _definitions[index];
                void set(ShiftDefinition next) {
                  _updateSegment(index, next);
                  _durationControllers[index].text = _ShiftDetailPageState._formatNumber(next.duration);
                  _repeatControllers[index].text = '${next.repeatCount}';
                  _rdChanged();
                  setSheet(() {});
                }

                Widget stepper(String value, VoidCallback? less, VoidCallback? more) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: l10n.redesignPlanLess,
                      icon: Icon(Icons.remove_circle_outline, color: p.link),
                      onPressed: less,
                    ),
                    Text(value, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: p.text)),
                    IconButton(
                      tooltip: l10n.redesignPlanMore5,
                      icon: Icon(Icons.add_circle_outline, color: p.link),
                      onPressed: more,
                    ),
                  ],
                );
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    RdSegmented<bool>(
                      values: const [false, true],
                      selected: d.free,
                      labelOf: (v) => v ? l10n.shiftsFree : l10n.redesignShiftWork,
                      onChanged: (v) => set(d.copyWith(free: v)),
                    ),
                    const SizedBox(height: 16),
                    RdGroupedList(
                      children: [
                        if (!d.free) ...[
                          RdListRow(
                            title: l10n.shiftsStartTime,
                            value: d.startTime,
                            onTap: () async {
                              await _pickStartTime(index);
                              _rdChanged();
                              setSheet(() {});
                            },
                          ),
                          RdListRow(
                            title: l10n.shiftsDurationHours,
                            showChevron: false,
                            trailing: stepper(
                              l10n.redesignShiftHours(_ShiftDetailPageState._formatNumber(d.duration)),
                              d.duration <= 0 ? null : () => set(d.copyWith(duration: (d.duration - 0.5).clamp(0, 24))),
                              d.duration >= 24
                                  ? null
                                  : () => set(d.copyWith(duration: (d.duration + 0.5).clamp(0, 24))),
                            ),
                          ),
                        ],
                        RdListRow(
                          title: l10n.shiftsRepetitions,
                          subtitle: l10n.shiftsRepetitionsHelper,
                          showChevron: false,
                          trailing: stepper(
                            '${d.repeatCount}',
                            d.repeatCount <= 1 ? null : () => set(d.copyWith(repeatCount: d.repeatCount - 1)),
                            d.repeatCount >= 365 ? null : () => set(d.copyWith(repeatCount: d.repeatCount + 1)),
                          ),
                        ),
                      ],
                    ),
                    if (!d.free) ...[
                      const SizedBox(height: 6),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(l10n.redesignShiftHalfHourHint, style: RdType.meta(p, size: 13)),
                      ),
                    ],
                    const SizedBox(height: 16),
                    RdGroupedList(
                      children: [
                        RdListRow(
                          leading: RdRowIcon(Icons.delete_outline, color: p.absent, background: p.absentSoft),
                          title: l10n.redesignShiftRemoveSegment,
                          titleColor: p.absent,
                          showChevron: false,
                          onTap: () => pop(true),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ],
    );
    if (remove == true && mounted && index < _definitions.length) {
      _deleteSegment(index);
      _rdChanged();
    }
  }

  /// Locked while the usage is unknown (loading or failed) or persons use it.
  bool _rdLocked(AsyncValue<int> usage) => usage.isLoading || usage.hasError || (usage.valueOrNull ?? 0) > 0;

  /// Checked again right before a change of a Feste Schicht.
  bool get _rdLockedNow => _rdLocked(ref.read(shiftUsageCountProvider(widget.shiftId)));

  /// Feste Schicht: name and start date; locked once persons use the plan.
  /// The lock follows the usage check while the sheet is open.
  Future<void> _rdFixedSheet(int index, ShiftPlan shift, bool openedLocked) async {
    if (index >= _shifts.length) return;
    final l10n = context.l10n;
    final controller = TextEditingController(text: _shifts[index].name);
    final remove = await showRdPlanSheet<bool>(
      context,
      title: _shifts[index].name.isEmpty ? l10n.shiftsFlutterAddShift : _shifts[index].name,
      subtitle: openedLocked ? l10n.redesignShiftLocked : null,
      builder:
          (ctx, pop) => [
            Consumer(
              builder: (ctx, sheetRef, _) {
                final isUsed = _rdLocked(sheetRef.watch(shiftUsageCountProvider(widget.shiftId)));
                return StatefulBuilder(
                  builder: (ctx, setSheet) {
                    if (index >= _shifts.length) return const SizedBox.shrink();
                    final p = ctx.rd;
                    final s = _shifts[index];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        RdGroupedList(
                          children: [
                            RdFieldRow(
                              label: l10n.typeSettingsName,
                              child: TextField(
                                controller: controller,
                                enabled: !isUsed,
                                style: TextStyle(fontSize: 17, color: p.text),
                                decoration: rdInputDecoration(p, l10n.typeSettingsName),
                                onChanged: (v) {
                                  if (_rdLockedNow) return;
                                  _updateShiftName(index, v);
                                  _rdChanged();
                                },
                              ),
                            ),
                            RdListRow(
                              title: l10n.shiftsStartDate,
                              value: _rdDate(s.date),
                              showChevron: !isUsed,
                              onTap:
                                  isUsed
                                      ? null
                                      : () async {
                                        final current = DateTime.tryParse(s.date) ?? DateTime.now();
                                        final picked = await showAppDatePicker(
                                          context: ctx,
                                          initialDate: current,
                                          firstDate: DateTime(2000),
                                          lastDate: DateTime(2100),
                                        );
                                        if (picked == null || !mounted || _rdLockedNow) return;
                                        _updateShiftDate(index, picked);
                                        _rdChanged();
                                        setSheet(() {});
                                      },
                            ),
                            RdListRow(
                              leading: const RdRowIcon(Icons.calculate_outlined),
                              title: l10n.shiftsExample,
                              onTap: () => _showPreview(context, shift, _shifts[index]),
                            ),
                          ],
                        ),
                        if (!isUsed) ...[
                          const SizedBox(height: 16),
                          RdGroupedList(
                            children: [
                              RdListRow(
                                leading: RdRowIcon(Icons.delete_outline, color: p.absent, background: p.absentSoft),
                                title: l10n.redesignShiftRemoveFixed,
                                titleColor: p.absent,
                                showChevron: false,
                                onTap: () => pop(true),
                              ),
                            ],
                          ),
                        ],
                      ],
                    );
                  },
                );
              },
            ),
          ],
    );
    controller.dispose();
    if (remove == true && mounted && index < _shifts.length && !_rdLockedNow) {
      _deleteShiftInstance(index);
      _rdChanged();
    }
  }
}
