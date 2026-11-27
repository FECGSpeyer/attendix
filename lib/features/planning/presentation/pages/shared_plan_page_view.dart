part of 'shared_plan_page.dart';

/// View and edit-list layout for [SharedPlanPage].
extension _SharedPlanView on _SharedPlanPageState {
  Widget _buildScaffold(BuildContext context) {
    final date = _dateTime;
    final liveNow = !_loading && !_notFound && _isLiveNow();
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(date != null ? PlanUtils.longDate(date) : _title),
        // IOS_PAGES3: iOS -> the end ion-buttons share one glass capsule
        actions: [
          ToolbarButtonGroup(
            children: [
              if (liveNow)
                IconButton(
                  tooltip: context.l10n.planningFlutterLive,
                  // Ionic: radio / radio-outline, danger while live.
                  color: _live ? AppColors.danger : AppColors.primary,
                  icon: Icon(_live ? AppIcons.sensors : AppIcons.sensorsOutlined),
                  onPressed: () => _update(() => _live = !_live),
                ),
              if (!_loading && !_notFound)
                IconButton(tooltip: context.l10n.planningExport, icon: Icon(AppIcons.iosShare), onPressed: _export),
            ],
          ),
        ],
      ),
      body: _buildBody(date),
    );
  }

  Widget _buildBody(DateTime? date) {
    if (_loading) return const Center(child: AppSpinner());
    if (_notFound) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(context.l10n.plansNotFound),
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        if (_labels.isNotEmpty)
          PlanChips(labels: _labels, selected: _planIndex, todayIndex: _todayIndex, onSelected: _selectPlan),
        // Ionic: ion-list [inset]; header = plan title (+ edit icon and the
        // "+" popover trigger in edit mode); start/end as ion-note.
        IonInsetList(
          // ABL-09: the inset-list header style (ion-list-header in an
          // ion-list [inset]).
          headerWidget: IonListHeader(
            inset: true,
            trailing:
                _editMode
                    ? Builder(
                      builder:
                          (anchor) => IconButton(
                            color: AppColors.primary,
                            tooltip: context.l10n.attendanceAdd,
                            icon: Icon(AppIcons.add),
                            onPressed: () => _showAddMenu(anchor),
                          ),
                    )
                    : null,
            titleWidget: GestureDetector(
              onTap: _editMode ? _editTitle : null,
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: _title),
                    if (_editMode)
                      WidgetSpan(
                        alignment: PlaceholderAlignment.middle,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Icon(AppIcons.editOutlined, size: 15, color: AppColors.mediumOf(context)),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          dividerIndent: _editMode ? 16 : null,
          children:
              _editMode
                  ? [
                    ListTile(
                      title: Text(context.l10n.attendanceStartLabel),
                      trailing: IonNote(context.l10n.attendanceTimeOClock(PlanUtils.formatTime(_time))),
                      onTap: _editStartTime,
                    ),
                    // Ionic: plain rows with trash + reorder handle.
                    SharedPlanEditList(
                      fields: _fields,
                      startTime: PlanUtils.formatTime(_time),
                      onChanged: (f) {
                        _update(() => _fields = PlanUtils.normalizeGroups(f));
                        unawaited(_save());
                      },
                    ),
                    if (_end.isNotEmpty)
                      ListTile(
                        title: Text(context.l10n.attendanceEnd),
                        trailing: IonNote(context.l10n.attendanceTimeOClock(PlanUtils.formatTime(_end))),
                      ),
                  ]
                  : [PlanViewList(plan: _plan, date: date, liveMode: _live, groupRange: false)],
        ),
      ],
    );
  }
}
