import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/debug_providers.dart';
import '../../../../core/providers/organisation_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/theme/design_theme.dart';
import '../../../../data/models/tenant/tenant.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/components/components.dart';

/// Opens a concise modal sheet explaining what the user's current Organisation
/// connects, which items are shared across groups, and what stays scoped to
/// each individual group (e.g. events, attendance, messages, team tasks).
Future<void> showRdOrgInfoSheet(
  BuildContext context, {
  bool showManageButton = true,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    useSafeArea: true,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: context.rd.bg,
    builder: (_) => RdSheetCap(
      child: _RdOrgInfoSheet(showManageButton: showManageButton),
    ),
  );
}

class _RdOrgInfoSheet extends ConsumerWidget {
  const _RdOrgInfoSheet({required this.showManageButton});

  final bool showManageButton;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.rd;
    final l10n = context.l10n;
    final org = ref.watch(currentOrganisationProvider).valueOrNull;
    final currentTenant = ref.watch(currentTenantProvider);
    final linked = ref.watch(allLinkedTenantsProvider).valueOrNull ?? const <Tenant>[];
    final groups = linked.isNotEmpty
        ? linked
        : [if (currentTenant != null) currentTenant];
    final role = ref.watch(effectiveRoleProvider);
    final isLead = role.isAdmin || role.isResponsible;
    final orgName = org?.name ?? l10n.orgTitle;

    return SingleChildScrollView(
      key: const Key('rd-org-info-sheet'),
      padding: EdgeInsets.fromLTRB(20, 4, 20, MediaQuery.paddingOf(context).bottom + 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RdOrgPill(orgName),
                    const SizedBox(height: 8),
                    Text(
                      l10n.rdOrgInfoSubtitle(groups.length),
                      style: RdType.meta(p, size: 13),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  l10n.redesignCommonDone,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: p.link),
                ),
              ),
            ],
          ),
          if (groups.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final t in groups)
                  RdPill(
                    t.id == currentTenant?.id
                        ? '${t.longName.isNotEmpty ? t.longName : t.shortName} · ${l10n.rdOrgThisGroup}'
                        : (t.longName.isNotEmpty ? t.longName : t.shortName),
                    tone: t.id == currentTenant?.id ? RdTone.primary : null,
                  ),
              ],
            ),
          ],
          const SizedBox(height: 18),
          RdGroupLabel(l10n.rdOrgInfoSharedLabel),
          RdGroupedList(
            children: [
              RdListRow(
                leading: const RdRowIcon(Icons.calendar_month_outlined),
                title: l10n.rdOrgInfoPlansTitle,
                subtitle: l10n.rdOrgInfoPlansBody,
                showChevron: false,
              ),
              RdListRow(
                leading: const RdRowIcon(Icons.library_music_outlined),
                title: l10n.rdOrgInfoWorksTitle,
                subtitle: l10n.rdOrgInfoWorksBody,
                showChevron: false,
              ),
              RdListRow(
                leading: const RdRowIcon(Icons.people_outline),
                title: l10n.rdOrgInfoPeopleTitle,
                subtitle: l10n.rdOrgInfoPeopleBody,
                showChevron: false,
              ),
            ],
          ),
          const SizedBox(height: 14),
          RdCard(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 18, color: p.text2),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.rdOrgInfoGroupBoundary,
                    style: RdType.meta(p, size: 13),
                  ),
                ),
              ],
            ),
          ),
          if (showManageButton && isLead) ...[
            const SizedBox(height: 16),
            RdOutlineButton(
              key: const Key('rd-org-info-manage'),
              icon: Icons.hub_outlined,
              label: l10n.rdOrgGroupsManageOrg,
              onPressed: () {
                final router = GoRouter.maybeOf(context);
                Navigator.of(context).pop();
                router?.push('/settings/org-settings');
              },
            ),
          ],
        ],
      ),
    );
  }
}
