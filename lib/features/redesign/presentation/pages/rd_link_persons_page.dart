import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/theme/redesign/rd_theme.dart';
import '../../../../data/models/person/person.dart';
import '../../../../l10n/l10n.dart';
import '../../../settings/presentation/pages/link_persons_page.dart';
import '../widgets/today/rd_today_common.dart' show RdInfoCard;
import '../widgets/rd_widgets.dart';

/// REDESIGN: Organisation › Personen verknüpfen (canvas "Beta: Gruppe und
/// Daten", board "G2 Personen verknüpfen"). Same suggestions, linking and
/// ignoring as the old page ([LinkPersonsLogic]); one card per suggestion,
/// matches to tick with the reason below, "Verknüpfen" as main button.
class RdLinkPersonsPage extends ConsumerStatefulWidget {
  const RdLinkPersonsPage({super.key});

  @override
  ConsumerState<RdLinkPersonsPage> createState() => _RdLinkPersonsPageState();
}

class _RdLinkPersonsPageState extends ConsumerState<RdLinkPersonsPage> with LinkPersonsLogic {
  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/settings/org-settings');
    }
  }

  String _initials(Person p) =>
      '${p.firstName.isNotEmpty ? p.firstName[0] : ''}${p.lastName.isNotEmpty ? p.lastName[0] : ''}'.toUpperCase();

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    // Suggestions belong to one group: reload them after a group switch.
    ref.listen(currentTenantIdProvider, (prev, next) {
      if (prev != next) reload();
    });
    return RdPage(
      children: [
        RdBackLink(label: l10n.rdOrgBack, onTap: _back),
        const SizedBox(height: 4),
        Semantics(header: true, child: Text(l10n.linkPersonsTitle, style: RdType.largeTitle(p))),
        const SizedBox(height: 8),
        if (loading)
          RdInfoCard(text: l10n.redesignTodayLoading, loading: true)
        else if (groups.isEmpty) ...[
          const SizedBox(height: 10),
          RdCard(
            child: Column(
              children: [
                Icon(Icons.check_circle_outline, color: p.present, size: 40),
                const SizedBox(height: 8),
                Text(l10n.linkPersonsNoMore, style: RdType.body(p), textAlign: TextAlign.center),
                if (linkedCount > 0) ...[
                  const SizedBox(height: 4),
                  Text(l10n.linkPersonsLinkedCount(linkedCount), style: RdType.meta(p), textAlign: TextAlign.center),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          RdOutlineButton(label: l10n.rdOrgBack, onPressed: _back),
        ] else ...[
          Text(l10n.rdOrgLinkIntro, style: RdType.meta(p)),
          const SizedBox(height: 16),
          for (final group in [...groups]) ...[
            _card(context, group),
            const SizedBox(height: 14),
          ],
        ],
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _card(BuildContext context, PersonLinkGroup group) {
    final p = context.rd;
    final l10n = context.l10n;
    final rep = group.representative;
    return RdCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              RdInitials(_initials(rep)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${rep.firstName} ${rep.lastName}', style: RdType.section(p)),
                    Text('${tenantName(rep.tenantId)} · ${formatBirthday(rep.birthday)}', style: RdType.meta(p)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final m in group.matches)
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => setState(() => m.selected = !m.selected),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      m.selected ? Icons.check_circle : Icons.radio_button_unchecked,
                      color: m.selected ? p.primary : p.text2,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${m.match.candidate.firstName} ${m.match.candidate.lastName}', style: RdType.body(p)),
                          Text(
                            '${tenantName(m.match.candidate.tenantId)} · ${formatBirthday(m.match.candidate.birthday)}',
                            style: RdType.meta(p),
                          ),
                          Text(linkReasonLabel(l10n, m.match.reason), style: RdType.meta(p).copyWith(color: p.primary)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: RdOutlineButton(label: l10n.linkPersonsIgnore, onPressed: () => ignore(group))),
              const SizedBox(width: 8),
              Expanded(child: RdPrimaryButton(label: l10n.linkPersonsLink, onPressed: () => link(group))),
            ],
          ),
        ],
      ),
    );
  }
}
