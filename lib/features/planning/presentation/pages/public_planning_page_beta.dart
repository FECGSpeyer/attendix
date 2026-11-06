part of 'public_planning_page.dart';

/// REDESIGN (Termin-Werkzeuge T2): the Ad-hoc-Planung in the Beta look. Plan
/// details in one card that saves right away, the Beta Ablauf rows below,
/// sharing via the link button and everything else behind •••. Loading,
/// saving, templates and exports are the classic page's.
extension _PublicPlanningBeta on _PublicPlanningPageState {
  Widget _rdBuild(BuildContext context, {required bool loggedIn, required Organisation? org}) {
    final p = context.rd;
    final l10n = context.l10n;
    final orgTemplates = org?.planningTemplates ?? const <Plan>[];
    String? templateName;
    final id = _templateId;
    if (id != null && id.startsWith('org:')) {
      final i = int.tryParse(id.substring(4));
      if (i != null && i < orgTemplates.length) templateName = l10n.plansOrgSuffix(orgTemplates[i].title ?? '');
    } else {
      templateName = publicPlanningTemplates.where((t) => t.id == id).firstOrNull?.name;
    }
    final branding = publicBrandings.where((b) => b.id == _brandingId).firstOrNull;
    final brandingName = branding == null || branding.id == 'none' ? l10n.coreFlutterNoBranding : branding.name;

    return RdPage(
      children: [
        Row(
          children: [
            Expanded(
              child:
                  widget.inApp
                      ? RdBackLink(
                        label: widget.fromOrgPlans ? l10n.plansOrgPlans : l10n.redesignTabEvents,
                        onTap: () => Navigator.of(context).maybePop(),
                      )
                      : const SizedBox.shrink(),
            ),
            RdCircleButton(icon: Icons.ios_share, label: l10n.plansShareExport, onPressed: _shareCurrentPlan),
            if (loggedIn) ...[
              const SizedBox(width: 8),
              RdCircleButton(
                key: const Key('rd-adhoc-more'),
                icon: Icons.more_horiz,
                label: l10n.redesignPlanMore,
                onPressed: _rdMore,
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Semantics(header: true, child: Text(l10n.plansPlanning, style: RdType.title(p))),
        const SizedBox(height: 16),
        if (!_ready)
          const Padding(padding: EdgeInsets.all(32), child: Center(child: AppSpinner()))
        else ...[
          RdGroupedList(
            children: [
              Focus(
                onFocusChange: (f) {
                  if (!f) _changed();
                },
                child: RdPlanTextRow(label: l10n.plansTitle, hint: l10n.plansRunSheet, controller: _titleController),
              ),
              RdListRow(
                leading: const RdRowIcon(Icons.event_outlined),
                title: l10n.plansDate,
                value: DateFormat(dateFmt()).format(_date),
                onTap: _pickDate,
              ),
              RdListRow(
                key: const Key('rd-adhoc-template'),
                leading: const RdRowIcon(Icons.view_list_outlined),
                title: l10n.plansTemplate,
                value: templateName ?? '–',
                onTap: () => _rdPickTemplate(orgTemplates),
              ),
              RdListRow(
                leading: const RdRowIcon(Icons.palette_outlined),
                title: l10n.plansBranding,
                value: brandingName,
                onTap: _rdPickBranding,
              ),
              if (org != null)
                RdListRow(
                  leading: const RdRowIcon(Icons.business_outlined),
                  title: l10n.plansInOrg(org.name),
                  showChevron: false,
                  onTap: _toggleOrg,
                  trailing: Switch.adaptive(value: _isOrgPlan, onChanged: (_) => _toggleOrg()),
                ),
            ],
          ),
          const SizedBox(height: 16),
          RdPlanSummaryBar(time: _time, totalMinutes: PlanUtils.totalMinutes(_fields), onPickTime: _pickTime),
          const SizedBox(height: 12),
          RdCard(
            padding: EdgeInsets.zero,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: PlanFieldsEditor(
                fields: _fields,
                startTime: _time,
                publicFieldDialog: true,
                onChanged: (f) {
                  _update(() => _fields = f);
                  _changed();
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          Builder(
            builder:
                (anchor) => RdPrimaryButton(
                  key: const Key('rd-adhoc-add'),
                  icon: Icons.add,
                  label: l10n.redesignPlanAdd,
                  onPressed: () => _showAddMenu(anchor),
                ),
          ),
        ],
      ],
    );
  }

  Future<void> _rdPickTemplate(List<Plan> orgTemplates) async {
    final l10n = context.l10n;
    final id = await showPlanActionSheet<String>(
      context,
      title: l10n.plansTemplate,
      actions: [
        for (final t in publicPlanningTemplates)
          PlanSheetAction(t.id, t.name, icon: t.id == _templateId ? Icons.check_circle : Icons.view_list_outlined),
        for (var i = 0; i < orgTemplates.length; i++)
          PlanSheetAction(
            'org:$i',
            l10n.plansOrgSuffix(orgTemplates[i].title ?? ''),
            icon: 'org:$i' == _templateId ? Icons.check_circle : Icons.business_outlined,
          ),
      ],
    );
    if (id == null || !mounted) return;
    await _onTemplateChange(id);
  }

  Future<void> _rdPickBranding() async {
    final l10n = context.l10n;
    final id = await showPlanActionSheet<String>(
      context,
      title: l10n.plansBranding,
      actions: [
        for (final b in publicBrandings)
          PlanSheetAction(
            b.id,
            b.id == 'none' ? l10n.coreFlutterNoBranding : b.name,
            icon: b.id == _brandingId ? Icons.check_circle : Icons.palette_outlined,
          ),
      ],
    );
    if (id == null || !mounted) return;
    _update(() => _brandingId = id);
    _changed();
  }

  /// •••: Meine Pläne, Neuer Plan, Vorlage wiederherstellen, Exportieren.
  Future<void> _rdMore() async {
    final l10n = context.l10n;
    final action = await showPlanActionSheet<String>(
      context,
      title: l10n.plansPlanning,
      actions: [
        PlanSheetAction('mine', l10n.plansMyPlans, icon: Icons.list),
        PlanSheetAction('new', l10n.plansNewPlan, icon: Icons.add_circle_outline),
        PlanSheetAction('restore', l10n.plansRestoreTemplate, icon: Icons.refresh),
        PlanSheetAction('export', l10n.planningExport, icon: Icons.picture_as_pdf_outlined),
      ],
    );
    if (!mounted) return;
    switch (action) {
      case 'mine':
        await _openMyPlans();
      case 'new':
        await _newPlan();
      case 'restore':
        await _resetToTemplate();
      case 'export':
        await _showExportOptions();
    }
  }

  /// Meine Pläne as a Beta sheet; ••• per plan deletes after a confirm.
  Future<SharedPlan?> _rdMyPlansSheet() {
    return showRdPlanSheet<SharedPlan>(
      context,
      title: context.l10n.plansMyPlans,
      builder: (ctx, pop) => [_RdMyPlansList(openPlanId: _planId, onOpen: pop)],
    );
  }
}

class _RdMyPlansList extends ConsumerWidget {
  const _RdMyPlansList({required this.openPlanId, required this.onOpen});

  final String? openPlanId;
  final void Function(SharedPlan plan) onOpen;

  Future<void> _more(BuildContext context, WidgetRef ref, SharedPlan plan, String title) async {
    final action = await showPlanActionSheet<String>(
      context,
      title: title,
      actions: [
        PlanSheetAction('open', context.l10n.redesignPlanEdit, icon: Icons.edit_outlined),
        PlanSheetAction('delete', context.l10n.planningDeletePlan, icon: Icons.delete_outline, destructive: true),
      ],
    );
    if (!context.mounted) return;
    if (action == 'open') onOpen(plan);
    if (action != 'delete') return;
    final ok = await showPlanConfirm(
      context,
      title: context.l10n.planningDeletePlan,
      message: context.l10n.plansDeletePlanForever(title),
      confirmText: context.l10n.commonDelete,
      destructive: true,
    );
    if (!ok) return;
    try {
      await ref.read(planRepositoryWithTenantProvider).deleteMySharedPlan(plan.id);
      ref.invalidate(mySharedPlansProvider);
    } catch (_) {
      if (context.mounted) ToastHelper.showError(context, context.l10n.plansDeleteFailed);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.rd;
    final l10n = context.l10n;
    final plansAsync = ref.watch(mySharedPlansProvider);
    return plansAsync.when(
      loading: () => const Padding(padding: EdgeInsets.all(24), child: Center(child: AppSpinner())),
      error: (e, _) => Text(l10n.planningFlutterErrorWith(friendlyErrorMessage(e)), style: RdType.meta(p, size: 15)),
      data: (plans) {
        if (plans.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(l10n.plansNoPlans, textAlign: TextAlign.center, style: RdType.meta(p, size: 15)),
          );
        }
        return RdGroupedList(
          children: [
            for (final plan in plans)
              () {
                final d = DateTime.tryParse(plan.date ?? '');
                final title = (plan.planTitle?.isNotEmpty ?? false) ? plan.planTitle! : l10n.plansRunSheet;
                final sub = [
                  if (d != null) DateFormat(dateFmt()).format(d),
                  if (plan.fields.isNotEmpty) l10n.plansFlutterFieldsCount(plan.fields.length),
                  if (plan.orgId != null) l10n.plansOrgPlans,
                ].join(' · ');
                return RdListRow(
                  key: ValueKey('rd-myplan-${plan.id}'),
                  leading: const RdRowIcon(Icons.description_outlined),
                  title: title,
                  subtitle: sub.isEmpty ? null : sub,
                  selected: plan.id == openPlanId,
                  showChevron: false,
                  onTap: () => onOpen(plan),
                  trailing: IconButton(
                    tooltip: l10n.redesignPlanMore,
                    icon: Icon(Icons.more_horiz, color: p.text2),
                    onPressed: () => _more(context, ref, plan, title),
                  ),
                );
              }(),
          ],
        );
      },
    );
  }
}
