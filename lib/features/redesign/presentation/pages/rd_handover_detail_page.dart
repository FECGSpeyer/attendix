import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/theme/redesign/rd_theme.dart';
import '../../../../data/models/person/person.dart';
import '../../../../l10n/l10n.dart';
import '../../../settings/presentation/pages/handover_detail_page.dart';
import '../../../settings/presentation/pages/handover_page.dart';
import '../widgets/today/rd_today_common.dart' show RdInfoCard;
import '../widgets/manage/rd_settings_sheets.dart';
import '../widgets/rd_widgets.dart';
import 'rd_handover_page.dart' show RdStepButton;

/// REDESIGN: Personen übergeben, step 2 (canvas "Beta: Gruppe und Daten",
/// board "G2 Übergabe"). Per person the group in the target; what happens to
/// them here stands right above the button. Same transfer as the old page
/// ([HandoverDetailLogic]).
class RdHandoverDetailPage extends ConsumerStatefulWidget {
  const RdHandoverDetailPage({super.key, required this.data});

  final HandoverData? data;

  @override
  ConsumerState<RdHandoverDetailPage> createState() => _RdHandoverDetailPageState();
}

class _RdHandoverDetailPageState extends ConsumerState<RdHandoverDetailPage> with HandoverDetailLogic {
  @override
  HandoverData? get handoverData => widget.data;

  @override
  String get handoverDoneRoute => '/settings/org-settings';

  @override
  String handoverConfirmMessage(HandoverData data) => context.l10n.rdOrgHandoverConfirm(
    data.persons.length,
    data.tenant.longName,
    handoverNote(data, stay: context.l10n.rdOrgStayNote, archive: context.l10n.rdOrgArchiveNote),
  );

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/settings/handover');
    }
  }

  Future<void> _changeGroup(Person person) async {
    final picked = await showRdChoiceSheet<int>(
      context,
      title: context.l10n.rdWordsGroup(widget.data?.tenant.type ?? ''),
      selected: groupMapping[person.id],
      options: [
        for (final g in targetGroups)
          if (g.id != null) (g.id!, g.name),
      ],
    );
    if (picked != null && mounted) setState(() => groupMapping[person.id!] = picked);
  }

  String _initials(Person p) =>
      '${p.firstName.isNotEmpty ? p.firstName[0] : ''}${p.lastName.isNotEmpty ? p.lastName[0] : ''}'.toUpperCase();

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    // The people were picked in one group: after a switch they are not shown
    // any more and the selection starts over (a running transfer stops by
    // itself, see [HandoverDetailLogic.proceed]).
    final tenantId = ref.watch(currentTenantIdProvider);
    // Request or direct handover follows the viewer's role in the target.
    ref.watch(userTenantsProvider);
    final source = widget.data?.sourceTenantId;
    final otherGroup = source != null && tenantId != source;
    if (otherGroup && !transferring) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/settings/handover');
      });
    }
    final data = otherGroup ? null : widget.data;
    final ready = data != null && !loading;
    return PopScope(
      // No leaving while people are being transferred.
      canPop: !transferring,
      child: RdPage(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButton:
            ready
                ? RdStepButton(
                  label: asRequest ? l10n.rdOrgRequest(data.persons.length) : l10n.rdOrgTransfer(data.persons.length),
                  loading: transferring,
                  onPressed: transferring ? null : confirmProceed,
                )
                : null,
        children: [
          RdBackLink(label: l10n.rdOrgBackSelection, onTap: () => transferring ? null : _back()),
          const SizedBox(height: 4),
          Semantics(header: true, child: Text(l10n.rdOrgStep2Title(widget.data?.tenant.type ?? ''), style: RdType.largeTitle(p))),
          if (!ready)
            RdInfoCard(text: l10n.redesignTodayLoading, loading: true)
          else ...[
            const SizedBox(height: 4),
            Text(l10n.rdOrgStep2Sub(data.tenant.longName, data.persons.length), style: RdType.meta(p)),
            const SizedBox(height: 18),
            RdGroupedList(
              children: [
                for (final person in data.persons)
                  RdListRow(
                    leading: RdInitials(_initials(person), size: 36),
                    title: '${person.firstName} ${person.lastName}',
                    subtitle: l10n.rdOrgHere(person.groupName ?? '–'),
                    value: targetGroupName(groupMapping[person.id]),
                    onTap: targetGroups.isEmpty ? null : () => _changeGroup(person),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            RdListNote(handoverNote(data, stay: l10n.rdOrgStayNote, archive: l10n.rdOrgArchiveNote)),
          ],
        ],
      ),
    );
  }
}
