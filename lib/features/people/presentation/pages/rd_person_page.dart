import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/providers/attendance_providers.dart';
import '../../../../core/providers/debug_providers.dart';
import '../../../../core/providers/church_providers.dart';
import '../../../../core/providers/group_providers.dart';
import '../../../../core/providers/person_detail_providers.dart'
    show personAttendanceStatsProvider, personHistoryProvider, personProvider;
import '../../../../core/providers/profile_providers.dart'
    show personExtraFieldsProvider, personListExtraFieldsProvider, profileRepositoryWithTenantProvider;
import '../../../../core/providers/player_absence_providers.dart';
import '../../../../core/providers/player_providers.dart';
import '../../../../core/providers/realtime_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/router/redesign_routes.dart';
import '../../../../core/theme/redesign/rd_theme.dart';
import '../../../../core/utils/contact_links.dart';
import '../../../../core/utils/demo_guard.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../core/utils/extra_field_utils.dart' show formatExtraFieldValue;
import '../../../../core/utils/tenant_label_utils.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/church/church.dart';
import '../../../../data/models/person/person.dart';
import '../../../../l10n/l10n.dart';
import '../../person_write.dart' show organisationPersonKey;
import '../widgets/pause_person_sheet.dart' show pausePersonFlow;
import '../../../settings/data/left_players_actions.dart' show leftPlayersProvider, reactivatePersonWithConfirmation;
import '../../data/rd_members_logic.dart';
import '../widgets/members/rd_critical_talk.dart' show RdCriticalTalkCard, rdCanRecordTalk;
import '../widgets/members/rd_pause_sheets.dart' show showRdArchiveSheet;
import '../../../settings/presentation/widgets/manage/rd_settings_sheets.dart' show RdListNote;
import '../../../attendance/presentation/widgets/event/rd_record_widgets.dart' show rdStatusLook;
import '../../../../shared/widgets/redesign/rd_split_view.dart';
import '../../../../shared/widgets/redesign/rd_widgets.dart';
import '../../../today/presentation/widgets/rd_today_common.dart' show RdInfoCard;
import 'rd_members_page.dart' show rdPercentColor;
import '../../../../core/utils/helper_member.dart';

part 'rd_person_page_details.dart';
part 'rd_person_page_sections.dart';

/// Person detail page: shows critical-rule follow-up ("Gespräch eintragen"),
/// contact links, attendance stats and recent history, personal details, and
/// pause/archive actions. Supports active, pending, and archived states.
class RdPersonPage extends ConsumerWidget {
  const RdPersonPage({super.key, required this.personId, this.onClose});

  final int personId;

  /// Closes the page after "Archivieren" instead of popping the route
  /// (embedded on the right of another list, e.g. the Problemfälle).
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.rd;
    final l10n = context.l10n;
    final role = ref.watch(effectiveRoleProvider);
    final async = ref.watch(personProvider(personId));
    final person = async.valueOrNull;

    final header = Row(
      children: [
        Expanded(
          child: RdSplitScope.of(context)?.isDetail ?? false
              ? const SizedBox(height: 44)
              : RdBackLink(
                  label: l10n.redesignTabMembers,
                  onTap: () => context.canPop() ? context.pop() : context.go(RedesignRoutes.members),
                ),
        ),
        // A person who left is only restored (below), not edited.
        if (person != null && person.left == null && role.canEdit)
          RdTextLink(label: l10n.redesignPersonEdit, onTap: () => context.push(RedesignRoutes.personEdit(personId))),
      ],
    );

    if (person == null) {
      return RdPage(children: [
        header,
        const SizedBox(height: 8),
        async.isLoading
            ? RdInfoCard(text: l10n.redesignTodayLoading, loading: true)
            : RdInfoCard(
                text: async.hasError ? l10n.redesignTodayLoadFailed : l10n.redesignPersonNotFound,
                icon: Icons.person_off_outlined,
                // Retry only helps after an error, not when it is gone.
                action: async.hasError
                    ? RdOutlineButton(
                      label: l10n.redesignCommonRetry,
                      onPressed: () => ref.invalidate(personProvider(personId)),
                    )
                    : null,
              ),
      ]);
    }

    final name = '${person.firstName} ${person.lastName}'.trim();
    final left = person.left != null;
    final joined = DateTime.tryParse(person.joined ?? '');
    final meta = [
      if ((person.groupName ?? '').isNotEmpty) person.groupName!,
      if (person.isLeader) l10n.redesignMembersLeader,
      if (joined != null) l10n.redesignPersonSince('${joined.year}'),
    ].join(' · ');

    return RdPage(
      onRefresh: () async {
        ref.invalidate(personProvider(personId));
        ref.invalidate(personAttendanceStatsProvider(personId));
        ref.invalidate(personHistoryProvider(personId));
        ref.invalidate(playerAbsencesByPersonIdProvider(personId));
      },
      children: [
        header,
        const SizedBox(height: 8),
        Row(
          children: [
            RdInitials(rdInitialsOf(name.isEmpty ? '?' : name), size: 64),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    child: Text(name, style: RdType.title(p).copyWith(fontSize: 24)),
                  ),
                  if (meta.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(meta, style: RdType.meta(p, size: 15)),
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        // Archived (Verwaltung › Archiv or a link): the same page as for an
        // active member, the "Ausgetreten" state on top with "Wiederherstellen"
        // as the one main action, the data to read (no Bearbeiten, no
        // Pausieren/Archivieren), like the old read-only page of a person who left.
        if (left) ...[
          _LeftCard(person: person, canRestore: role.isAdmin || role.isResponsible),
          const SizedBox(height: 12),
        ],
        // A Problemfall: why, and "Gespräch eintragen" right here (before
        // only in Bearbeiten). Like Bearbeiten: Admins and Verantwortliche.
        if (person.isCritical && !left && !person.pending && rdCanRecordTalk(role)) ...[
          RdCriticalTalkCard(person: person),
          const SizedBox(height: 12),
        ],
        _ContactGrid(phone: person.phone, email: person.email, firstName: person.firstName),
        if (person.pending) ...[
          RdInfoCard(
            text: l10n.redesignPersonPending,
            icon: Icons.hourglass_top_rounded,
            action: role.isAdmin || role.isResponsible
                ? RdPrimaryButton(
                    label: l10n.redesignPersonReview,
                    onPressed: () => context.push(RedesignRoutes.membersReview(personId)),
                  )
                : null,
          ),
          const SizedBox(height: 12),
        ] else ...[
          _AttendanceCard(personId: personId),
          const SizedBox(height: 12),
        ],
        // The full data to read only for the leads (they would see it in
        // Bearbeiten); others keep the usual info rows.
        if (left && (role.isAdmin || role.isResponsible))
          _LeftDetails(person: person)
        else if (left)
          _InfoList(person: person)
        else ...[
          _InfoList(person: person),
          if (role.canEdit && !person.pending) ...[
            const SizedBox(height: 12),
            _Actions(person: person, onClose: onClose),
          ],
        ],
      ],
    );
  }
}

/// "Ausgetreten am …" like the old archive list.
String _formatLeft(String left) {
  final date = DateTime.tryParse(left);
  return date == null ? left : DateFormat(dateFmt()).format(date);
}

/// The reason given when the person was archived (last "archived" history
/// entry); null when none was given.
String? rdLeftReason(Person person) {
  final entries = person.history.where((e) => e.type == PlayerHistoryType.archived.value);
  final text = entries.isEmpty ? '' : (entries.last.text ?? '').trim();
  // archivePlayer writes this placeholder when no reason was entered.
  if (text.isEmpty || text == 'Kein Grund angegeben') return null;
  return text;
}

/// "Ausgetreten: …" with the reason and "Wiederherstellen" (Admins and
/// Verantwortliche) as the page's main action.
class _LeftCard extends ConsumerWidget {
  const _LeftCard({required this.person, required this.canRestore});

  final Person person;
  final bool canRestore;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.rd;
    final l10n = context.l10n;
    // The reason only for the leads: the Verlauf hides archive entries
    // from everyone else too.
    final reason = canRestore ? rdLeftReason(person) : null;
    return RdCard(
      key: const Key('rd-person-left'),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.archive_outlined, color: p.softText),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.settingsLeftOn(_formatLeft(person.left!)),
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: p.text),
                ),
              ),
            ],
          ),
          if (reason != null) ...[
            const SizedBox(height: 4),
            Text(reason, style: RdType.meta(p, size: 14)),
          ],
          if (canRestore) ...[
            const SizedBox(height: 12),
            RdPrimaryButton(
              key: const Key('rd-person-restore'),
              icon: Icons.restore,
              label: l10n.redesignArchiveListRestore,
              onPressed: () async {
                await reactivatePersonWithConfirmation(context, ref, person);
                if (!context.mounted) return;
                if (person.id != null) ref.invalidate(personProvider(person.id!));
                ref.invalidate(archivedPlayersProvider);
              },
            ),
          ],
        ],
      ),
    );
  }
}

/// Zusatzfeld values of a person who left: the person's own values, the
/// organisation fields from `tenant_group_person_fields` (like the old
/// person page; their copy in `additionalFields` may be stale).
final _leftFieldValuesProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, Person>((ref, person) async {
  final values = <String, dynamic>{...?person.additionalFields};
  final fields = await ref.watch(personExtraFieldsProvider.future);
  final orgIds = fields.where((f) => f.isOrganisationField).map((f) => f.id).toSet();
  if (orgIds.isEmpty) return values;
  values.removeWhere((id, _) => orgIds.contains(id));
  final repo = ref.watch(profileRepositoryWithTenantProvider);
  final key = organisationPersonKey(person);
  final orgId = await repo.getOrganisationId();
  if (orgId == null || key == null) return values;
  final shared = await repo.getSharedFieldValues(orgId, key);
  for (final e in shared.entries) {
    if (orgIds.contains(e.key)) values[e.key] = e.value;
  }
  return values;
});
