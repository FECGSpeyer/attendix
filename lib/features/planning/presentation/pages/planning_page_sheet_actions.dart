part of 'planning_page.dart';

/// Item, block, block-assignment, and add-action bottom sheets for
/// [PlanningPage].
extension _PlanningSheetActions on _PlanningPageState {
  /// "Block: …" in the item sheet: picks the block it belongs to from a list.
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

  /// Tap on an item: edit inline, insert after, move up/down, assign block,
  /// or delete.
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

  /// Tap on a block: edit inline, add sub-item, save template (admins),
  /// insert after, dissolve, or delete.
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
