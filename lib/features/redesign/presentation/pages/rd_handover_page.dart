import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/theme/redesign/rd_theme.dart';
import '../../../../core/utils/handover_request.dart';
import '../../../../data/models/person/person.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';
import '../../../settings/presentation/pages/handover_page.dart';
import '../../data/rd_words.dart';
import '../widgets/manage/rd_settings_sheets.dart';
import '../widgets/rd_widgets.dart';

/// Wide step button at the bottom of a Beta step page.
class RdStepButton extends StatelessWidget {
  const RdStepButton({super.key, required this.label, required this.onPressed, this.loading = false});

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: RdPrimaryButton(label: label, onPressed: onPressed, loading: loading),
        ),
      );
}

/// REDESIGN: Organisation › Personen übergeben, step 1 (canvas "Beta: Gruppe
/// und Daten", board "G2 Übergabe"). Same rules as the old page
/// ([HandoverSelectionLogic]): target and options on top, filters as chips,
/// the people to tick below; the button at the bottom counts along.
class RdHandoverPage extends ConsumerStatefulWidget {
  const RdHandoverPage({super.key});

  @override
  ConsumerState<RdHandoverPage> createState() => _RdHandoverPageState();
}

class _RdHandoverPageState extends ConsumerState<RdHandoverPage> with HandoverSelectionLogic {
  /// "Bleiben auch hier" (true) or "Wechseln ganz" (false). Nothing is
  /// chosen at first: archiving people here is decided, never a default
  /// somebody overlooked (the old page keeps the Ionic switch).
  bool? _keep;

  void _setKeep(bool value) => setState(() {
        _keep = value;
        stayInInstance = value;
      });

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/settings/org-settings');
    }
  }

  Future<void> _pickTarget(HandoverView view) async {
    final picked = await showRdChoiceSheet<int>(
      context,
      title: context.l10n.rdOrgHandoverTarget,
      selected: targetTenantId,
      options: [
        for (final t in view.tenants)
          if (t.id != null) (t.id!, t.longName),
      ],
    );
    if (picked != null && mounted) setState(() => targetTenantId = picked);
  }

  Future<void> _pickGroup(HandoverView view) async {
    final picked = await showRdChoiceSheet<int>(
      context,
      title: context.l10n.rdWordsGroup(ref.read(rdGroupKindProvider)),
      selected: groupId,
      options: [
        for (final g in view.groups)
          if (g.id != null) (g.id!, g.name),
      ],
    );
    if (picked != null && mounted) setState(() => groupId = picked);
  }

  Future<void> _addFilter(HandoverView view) async {
    final l10n = context.l10n;
    final hasAge = filters.contains('younger') || filters.contains('older');
    final picked = await showAppActionSheet<String>(
      context,
      title: l10n.handoverAddFilter,
      actions: [
        if (!hasAge) ...[
          AppActionSheetAction(value: 'younger', label: l10n.handoverYoungerThanDots),
          AppActionSheetAction(value: 'older', label: l10n.handoverOlderThanDots),
        ],
        if (!filters.contains('group')) AppActionSheetAction(value: 'group', label: l10n.rdWordsGroupFilter(ref.read(rdGroupKindProvider))),
      ],
    );
    if (picked == null || !mounted) return;
    setState(() => filters.add(picked));
    if (picked == 'group') {
      await _pickGroup(view);
    } else {
      await pickDate();
    }
  }

  Future<void> _editFilter(String filter, HandoverView view) async {
    final l10n = context.l10n;
    final action = await showAppActionSheet<String>(
      context,
      actions: [
        AppActionSheetAction(value: 'edit', label: l10n.commonEdit, icon: Icons.edit_outlined),
        AppActionSheetAction(value: 'remove', label: l10n.commonDelete, icon: Icons.close, destructive: true),
      ],
    );
    if (!mounted) return;
    if (action == 'remove') {
      setState(() => filters.remove(filter));
    } else if (action == 'edit') {
      filter == 'group' ? await _pickGroup(view) : await pickDate();
    }
  }

  String _filterLabel(String filter, HandoverView view) {
    final l10n = context.l10n;
    return switch (filter) {
      'younger' => l10n.rdOrgFilterYounger(dateFormat.format(date)),
      'older' => l10n.rdOrgFilterOlder(dateFormat.format(date)),
      _ => l10n.rdOrgFilterGroup(view.groupNames[groupId] ?? ''),
    };
  }

  String _subtitle(Person p, HandoverView view) => [
        p.groupName ?? view.groupNames[p.instrument] ?? '',
        if (p.birthday != null && DateTime.tryParse(p.birthday!) != null) dateFormat.format(DateTime.parse(p.birthday!)),
      ].where((s) => s.isNotEmpty).join(' · ');

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final view = handoverView();
    final target = view.tenants.where((t) => t.id == targetTenantId).firstOrNull;
    final count = view.selectedPersons.length;
    const gap = SizedBox(height: 24);
    // No lead of the target group: the people only wait in its Freigaben.
    final request = target?.id != null &&
        handoverNeedsRequest(tenants: ref.watch(userTenantsProvider).valueOrNull, targetTenantId: target!.id!);

    Widget keepRow(bool value, String title, String hint) => RdListRow(
          key: Key(value ? 'rd-handover-stay' : 'rd-handover-move'),
          title: title,
          subtitle: hint,
          showChevron: false,
          selected: _keep == value,
          trailing: RdSheetCheck(_keep == value),
          onTap: () => _setKeep(value),
        );

    return RdPage(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: RdStepButton(
        label: l10n.rdOrgNext(count),
        onPressed: target == null || count == 0 || _keep == null
            ? null
            : () => openHandoverDetail(view, '/settings/handover/detail'),
      ),
      children: [
        RdBackLink(label: l10n.rdOrgBack, onTap: _back),
        const SizedBox(height: 4),
        Semantics(header: true, child: Text(l10n.rdOrgHandover, style: RdType.largeTitle(p))),
        const SizedBox(height: 8),
        Text(l10n.rdOrgHandoverIntro, style: RdType.meta(p)),
        const SizedBox(height: 18),
        RdGroupedList(children: [
          RdListRow(
            title: l10n.rdOrgHandoverTarget,
            value: target?.longName ?? '–',
            onTap: view.tenants.isEmpty ? null : () => _pickTarget(view),
          ),
          RdSwitchRow(
            title: l10n.rdOrgMainGroup,
            subtitle: l10n.rdOrgMainGroupHint,
            value: includeMainGroup,
            onChanged: (v) => setState(() => includeMainGroup = v),
          ),
        ]),
        if (view.tenants.isEmpty && !view.loading) RdListNote(l10n.rdOrgNoOtherGroups),
        if (request) RdListNote(l10n.rdOrgRequestNote(target.longName)),
        const SizedBox(height: 18),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
          child: Semantics(
            header: true,
            child: Text(l10n.rdOrgKeepQuestion, style: RdType.title(p).copyWith(fontSize: 18)),
          ),
        ),
        RdGroupedList(children: [
          keepRow(true, l10n.rdOrgKeepStay, l10n.rdOrgKeepStayHint),
          keepRow(false, l10n.rdOrgKeepMove, request ? l10n.rdOrgKeepMoveHintRequest : l10n.rdOrgKeepMoveHint),
        ]),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final f in filters)
              RdChoiceChip(label: '${_filterLabel(f, view)}  ✕', selected: true, onTap: () => _editFilter(f, view)),
            if (filters.length < 2)
              RdChoiceChip(label: '+ ${l10n.rdOrgFilter}', selected: false, onTap: () => _addFilter(view)),
          ],
        ),
        gap,
        if (view.loading)
          Center(child: Padding(padding: const EdgeInsets.all(24), child: CircularProgressIndicator(color: p.primary)))
        else if (view.filtered.isEmpty)
          RdListNote(l10n.handoverNoneSelected)
        else ...[
          Row(
            children: [
              Expanded(child: RdGroupLabel(l10n.rdOrgPeopleCount(view.filtered.length))),
              TextButton(
                onPressed: () => setState(() {
                  selected
                    ..clear()
                    ..addAll(view.filtered.where((p) => p.id != null).map((p) => p.id!));
                }),
                child: Text(l10n.handoverSelectAll, style: TextStyle(color: p.primary)),
              ),
            ],
          ),
          RdGroupedList(children: [
            for (final person in view.filtered)
              RdListRow(
                leading: Icon(
                  selected.contains(person.id) ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: selected.contains(person.id) ? p.primary : p.text2,
                ),
                title: '${person.firstName} ${person.lastName}',
                subtitle: _subtitle(person, view),
                showChevron: false,
                selected: selected.contains(person.id),
                onTap: person.id == null
                    ? null
                    : () => setState(() {
                          if (!selected.remove(person.id)) selected.add(person.id!);
                        }),
              ),
          ]),
        ],
      ],
    );
  }
}
