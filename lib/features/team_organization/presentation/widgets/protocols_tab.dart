import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/providers/team_org_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/team_org/team_org.dart';
import '../../../../l10n/l10n.dart';
import '../../team_org_utils.dart';
import '../../../planning/presentation/widgets/ion_items.dart';
import 'tasks_tab.dart' show TeamOrgBadge;
import '../../../../shared/widgets/adaptive/adaptive.dart'; // IOS_LOOK
import 'package:attendix/shared/widgets/layout/ios_tab_bar.dart'; // IOS_SHELL2

class _ProtocolRow {
  _ProtocolRow({
    required this.protocol,
    required this.attendanceId,
    required this.date,
    required this.title,
    required this.subtitle,
    required this.dateText,
    required this.isDraft,
    required this.edited,
  });
  final Protocol protocol;
  final int attendanceId;
  final String? date;
  final String title;
  final String subtitle;
  final String dateText;
  final bool isDraft;
  final bool edited;
}

/// Tab "Protokolle": leadership sees drafts and published ones, members the
/// published ones of their circle (RLS).
class ProtocolsTab extends ConsumerStatefulWidget {
  const ProtocolsTab({super.key});

  @override
  ConsumerState<ProtocolsTab> createState() => _ProtocolsTabState();
}

class _ProtocolsTabState extends ConsumerState<ProtocolsTab> {
  String _search = '';

  List<_ProtocolRow> _rows(List<Protocol> protocols, List<ProtocolType> types) {
    return protocols.where((p) => p.attendanceId != null).map((p) {
      final att = p.attendance;
      String typeName = '';
      for (final t in types) {
        if (t.id == att?.typeId) typeName = t.name;
      }
      final d = DateTime.tryParse(att?.date ?? '')?.toLocal();
      final title = (att?.typeInfo?.isNotEmpty == true)
          ? att!.typeInfo!
          : (typeName.isNotEmpty ? typeName : context.l10n.attendanceEventFallback);
      return _ProtocolRow(
        protocol: p,
        attendanceId: p.attendanceId!,
        date: att?.date,
        title: title,
        subtitle: att?.typeInfo?.isNotEmpty == true && typeName.isNotEmpty && typeName != title ? typeName : '',
        dateText: d != null ? '${weekdayShort(d)}, ${DateFormat(dateFmt()).format(d)}' : '',
        isDraft: p.status != 'published',
        edited: isEditedAfterPublish(p),
      );
    }).toList();
  }

  String _publishedText(_ProtocolRow row) {
    final p = row.protocol;
    if (row.isDraft || p.publishedAt == null) return '';
    final fmt = DateFormat(dateFmt(DateFmtKind.dayMonth));
    final pub = DateTime.tryParse(p.publishedAt!)?.toLocal();
    if (pub == null) return '';
    final l10n = context.l10n;
    final text = l10n.teamOrgPublishedOn(fmt.format(pub));
    final upd = DateTime.tryParse(p.updatedAt ?? '')?.toLocal();
    return row.edited && upd != null ? l10n.teamOrgEditedOn(text, fmt.format(upd)) : text;
  }

  @override
  Widget build(BuildContext context) {
    final isLeader = ref.watch(isTeamLeaderProvider);
    final protocolsAsync = ref.watch(protocolsProvider);
    final types = ref.watch(protocolTypesProvider).valueOrNull ?? const <ProtocolType>[];
    final l10n = context.l10n;

    return protocolsAsync.when(
      loading: () => const Center(child: AppSpinner()),
      error: (_, __) => Center(child: Text(l10n.protocolLoadFailed)),
      data: (protocols) {
        final rows = _rows(protocols, types);
        final query = _search.trim();
        final filtered = rows
            .where((r) => matchesSearch(query, [
                  r.title,
                  r.subtitle,
                  r.dateText,
                  r.isDraft ? l10n.teamOrgDraft : l10n.teamOrgPublished,
                ]))
            .toList();
        final groups = groupByMonth(filtered, (r) => r.date);

        Widget state(IconData icon, String title, String text) =>
            IonEmptyState(icon: icon, title: title, text: text);

        return RefreshIndicator.adaptive(
          onRefresh: () async => ref.invalidate(protocolsProvider),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.only(bottom: scrollEndPadding(context, base: 16, fabRoom: 64)),
            children: [
              if (rows.isNotEmpty || _search.isNotEmpty)
                IonSearchbar(
                  placeholder: l10n.teamOrgSearchProtocols,
                  onChanged: (v) => setState(() => _search = v),
                ),
              if (rows.isEmpty)
                isLeader
                    ? state(Icons.description_outlined, l10n.teamOrgNoProtocols, l10n.teamOrgNoProtocolsHint)
                    : state(Icons.description_outlined, l10n.teamOrgNoPublished, l10n.teamOrgNoPublishedHint)
              else if (groups.isEmpty)
                state(Icons.search, l10n.teamOrgNoHits, l10n.teamOrgNoProtocolMatch(_search))
              else
                // Ionic: one ion-list [inset] per month with an ion-list-header.
                for (final group in groups)
                  IonInsetList(
                    header: group.label,
                    dividerIndent: 74,
                    children: [
                      for (final row in group.items)
                        ListTile(
                          leading: _DateBadge(date: row.date),
                          title: Text(row.title, style: const TextStyle(fontSize: 15)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                [row.dateText, if (row.subtitle.isNotEmpty) row.subtitle].join(' · '),
                                style: const TextStyle(color: AppColors.medium),
                              ),
                              if (_publishedText(row).isNotEmpty)
                                Text(_publishedText(row),
                                    style: const TextStyle(fontSize: 12, color: AppColors.medium)),
                            ],
                          ),
                          // Ionic: badge (draft / published for leaders) + detail chevron.
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (row.isDraft)
                                TeamOrgBadge(label: l10n.teamOrgDraft, color: AppColors.warning)
                              else if (isLeader)
                                TeamOrgBadge(label: l10n.teamOrgPublished, color: AppColors.success),
                              const SizedBox(width: 4),
                              const IonDetailIcon(),
                            ],
                          ),
                          onTap: () => context.push('/settings/protocol/${row.attendanceId}'),
                        ),
                    ],
                  ),
            ],
          ),
        );
      },
    );
  }
}

/// Ionic `.date-badge`: 42×42 rounded tile (primary 12 %) with day and weekday.
class _DateBadge extends StatelessWidget {
  const _DateBadge({this.date});
  final String? date;

  @override
  Widget build(BuildContext context) {
    final d = DateTime.tryParse(date ?? '')?.toLocal();
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(d != null ? d.day.toString().padLeft(2, '0') : '–',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17, height: 1, color: AppColors.primaryDark)),
          const SizedBox(height: 2),
          Text(d != null ? weekdayShort(d) : '',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11, height: 1, color: AppColors.primaryDark)),
        ],
      ),
    );
  }
}
