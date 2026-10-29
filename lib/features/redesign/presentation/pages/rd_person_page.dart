import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/providers/attendance_providers.dart';
import '../../../../core/providers/debug_providers.dart';
import '../../../../core/providers/player_absence_providers.dart';
import '../../../../core/providers/player_providers.dart';
import '../../../../core/providers/realtime_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/router/redesign_routes.dart';
import '../../../../core/theme/redesign/rd_theme.dart';
import '../../../../core/utils/contact_links.dart';
import '../../../../core/utils/demo_guard.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/person/person.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart' show showAppDatePicker;
import '../../../people/presentation/pages/person_detail_page.dart'
    show personProvider, personAttendanceStatsProvider, personHistoryProvider;
import '../../../people/presentation/widgets/pause_person_sheet.dart' show pausePersonFlow;
import '../../data/rd_members_logic.dart';
import '../widgets/event/rd_record_widgets.dart' show rdStatusLook;
import '../widgets/rd_widgets.dart';
import '../widgets/today/rd_today_common.dart' show RdInfoCard;
import 'rd_members_page.dart' show rdPercentColor;

/// REDESIGN: a person (canvas "PersonDetail"): contact, attendance with
/// the last ten Termine, birthday, absence, note, Pausieren / Archivieren.
/// "Bearbeiten" and the full history open the existing person page.
class RdPersonPage extends ConsumerWidget {
  const RdPersonPage({super.key, required this.personId});

  final int personId;

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
          child: RdBackLink(
            label: l10n.redesignTabMembers,
            onTap: () => context.canPop() ? context.pop() : context.go(RedesignRoutes.members),
          ),
        ),
        if (person != null && role.canEdit)
          RdTextLink(label: l10n.redesignPersonEdit, onTap: () => context.push('/people/$personId')),
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
                action: RdOutlineButton(
                  label: l10n.redesignCommonRetry,
                  onPressed: () => ref.invalidate(personProvider(personId)),
                ),
              ),
      ]);
    }

    final name = '${person.firstName} ${person.lastName}'.trim();
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
        _ContactGrid(phone: person.phone, email: person.email, firstName: person.firstName),
        if (person.pending) ...[
          RdInfoCard(
            text: l10n.redesignPersonPending,
            icon: Icons.hourglass_top_rounded,
            action: role.isAdmin || role.isResponsible
                ? RdPrimaryButton(
                    label: l10n.redesignPersonReview,
                    onPressed: () => context.push('/people/$personId'),
                  )
                : null,
          ),
          const SizedBox(height: 12),
        ] else ...[
          _AttendanceCard(personId: personId),
          const SizedBox(height: 12),
        ],
        _InfoList(person: person),
        if (role.canEdit && !person.pending) ...[
          const SizedBox(height: 12),
          _Actions(person: person),
        ],
      ],
    );
  }
}

/// Anrufen · WhatsApp · Telegram · E-Mail as white tiles (only the ones
/// the person's phone / mail allow).
class _ContactGrid extends StatelessWidget {
  const _ContactGrid({required this.phone, required this.email, required this.firstName});

  final String? phone;
  final String? email;
  final String firstName;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final call = phoneCallUri(phone);
    final whatsApp = whatsAppUri(phone);
    final telegram = telegramUri(phone);
    final mail = mailUri(email);
    final tiles = [
      if (call != null) (Icons.call_outlined, l10n.peopleFlutterContactCall, call),
      if (whatsApp != null) (Icons.chat_outlined, 'WhatsApp', whatsApp),
      if (telegram != null) (Icons.send_outlined, 'Telegram', telegram),
      if (mail != null) (Icons.mail_outline, l10n.peopleFlutterContactMail, mail),
    ];
    if (tiles.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          for (var i = 0; i < tiles.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(child: _ContactTile(icon: tiles[i].$1, label: tiles[i].$2, uri: tiles[i].$3)),
          ],
        ],
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  const _ContactTile({required this.icon, required this.label, required this.uri});

  final IconData icon;
  final String label;
  final Uri uri;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: p.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => launchContactUri(uri),
          child: SizedBox(
            height: 56,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 20, color: p.softText),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: p.softText),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Anwesenheit": percentage of the season, attended of total, the last
/// ten Termine (newest right).
class _AttendanceCard extends ConsumerWidget {
  const _AttendanceCard({required this.personId});

  final int personId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.rd;
    final l10n = context.l10n;
    final stats = ref.watch(personAttendanceStatsProvider(personId)).valueOrNull;
    final history = ref.watch(personHistoryProvider(personId)).valueOrNull;
    final seasonStart = DateTime.tryParse(ref.watch(currentTenantProvider)?.seasonStart ?? '');
    final total = (stats?['total'] as int?) ?? 0;
    final attended = (stats?['attended'] as int?) ?? 0;
    final percent = (stats?['percentage'] as int?) ?? 0;
    final last = history == null ? const <AttendanceStatus>[] : rdLastStatuses(history);

    return RdCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.redesignPersonAttendance,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: p.text),
                ),
              ),
              Text(
                seasonStart == null
                    ? l10n.redesignPersonOverall
                    : l10n.redesignPersonSinceDate(DateFormat.yMMMd(currentIntlLocale()).format(seasonStart)),
                style: RdType.meta(p, size: 13),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (stats == null)
            const SizedBox(height: 40, child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
          else if (total == 0)
            Text(l10n.redesignPersonNoTermine, style: RdType.meta(p, size: 14))
          else
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.end,
              spacing: 8,
              children: [
                Text(
                  l10n.redesignPersonPercent(percent),
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w700,
                    color: rdPercentColor(p, percent),
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(l10n.redesignPersonOfTermine(attended, total), style: RdType.meta(p, size: 14)),
                ),
              ],
            ),
          if (last.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(l10n.redesignPersonLastTermine(last.length), style: RdType.meta(p, size: 13)),
            const SizedBox(height: 6),
            Row(
              children: [
                for (var i = 0; i < 10; i++) ...[
                  if (i > 0) const SizedBox(width: 4),
                  Expanded(
                    child: i < last.length ? _StatusTile(status: last[i]) : const SizedBox(height: 28),
                  ),
                ],
              ],
            ),
          ],
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              style: TextButton.styleFrom(
                foregroundColor: p.link,
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 40),
                textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              onPressed: () => context.push('/people/$personId'),
              child: Text(l10n.redesignPersonAllTermine),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusTile extends StatelessWidget {
  const _StatusTile({required this.status});

  final AttendanceStatus status;

  @override
  Widget build(BuildContext context) {
    final look = rdStatusLook(context.rd, status);
    return Semantics(
      label: status.label,
      excludeSemantics: true,
      child: Tooltip(
        message: status.label,
        child: Container(
          height: 28,
          decoration: BoxDecoration(color: look.soft, borderRadius: BorderRadius.circular(8)),
          alignment: Alignment.center,
          child: Icon(look.icon, size: 15, color: look.color),
        ),
      ),
    );
  }
}

/// Geburtstag, Dabei seit, Abwesenheit, Pause, Notiz.
class _InfoList extends ConsumerWidget {
  const _InfoList({required this.person});

  final Person person;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.rd;
    final l10n = context.l10n;
    final locale = currentIntlLocale();
    final long = DateFormat.yMMMd(locale);
    final rows = <Widget>[];

    final birthday = DateTime.tryParse(person.birthday ?? '');
    if (birthday != null) {
      final days = rdDaysToBirthday(person.birthday);
      final when = switch (days) {
        0 => ' · ${l10n.redesignPersonToday}',
        1 => ' · ${l10n.redesignPersonTomorrow}',
        final d? when d <= 7 => ' · ${l10n.redesignPersonInDays(d)}',
        _ => '',
      };
      rows.add(RdListRow(
        title: l10n.redesignPersonBirthday,
        value: '${DateFormat.MMMd(locale).format(birthday)}$when',
        showChevron: false,
      ));
    }
    final joined = DateTime.tryParse(person.joined ?? '');
    if (joined != null) {
      rows.add(RdListRow(title: l10n.redesignPersonJoined, value: long.format(joined), showChevron: false));
    }
    if (person.paused) {
      final until = DateTime.tryParse(person.pausedUntil ?? '');
      rows.add(RdListRow(
        title: l10n.redesignPersonPaused,
        value: until == null ? l10n.redesignPersonPausedOpen : l10n.redesignMembersPausedUntil(long.format(until)),
        showChevron: false,
      ));
    } else if (person.id != null) {
      final absences = ref.watch(playerAbsencesByPersonIdProvider(person.id!)).valueOrNull ?? const [];
      final absence = rdCurrentAbsence(absences, person.id!);
      final from = DateTime.tryParse(absence?.fromDate ?? '');
      final until = DateTime.tryParse(absence?.untilDate ?? '');
      if (absence != null && from != null && until != null) {
        rows.add(RdListRow(
          title: l10n.redesignPersonAbsence,
          subtitle: absence.reason.isEmpty ? null : absence.reason,
          value: l10n.redesignPersonAbsenceRange(DateFormat.Md(locale).format(from), DateFormat.Md(locale).format(until)),
          showChevron: false,
        ));
      }
    }
    final notes = (person.notes ?? '').trim();
    if (notes.isNotEmpty) {
      rows.add(SizedBox(
        width: double.infinity,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.redesignPersonNotes, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: p.text)),
              const SizedBox(height: 2),
              Text(notes, style: RdType.meta(p, size: 14)),
            ],
          ),
        ),
      ));
    }
    if (rows.isEmpty) return const SizedBox.shrink();
    return RdGroupedList(children: rows);
  }
}

/// Pausieren / Wieder aktiv and Archivieren (old person page's actions).
class _Actions extends ConsumerWidget {
  const _Actions({required this.person});

  final Person person;

  void _refresh(WidgetRef ref) {
    if (person.id != null) ref.invalidate(personProvider(person.id!));
    ref.invalidate(realtimePlayersProvider);
    ref.invalidate(playerAttendancePercentagesProvider);
  }

  Future<void> _togglePause(BuildContext context, WidgetRef ref) async {
    if (DemoGuard.blocked()) return; // DEMO_GUARD
    final repo = ref.read(playerRepositoryWithTenantProvider);
    if (!person.paused) {
      // PEOPLE2: Ionic confirmPause incl. "Pausiert ab" and other instances
      final paused = await pausePersonFlow(context, ref, person);
      if (paused && context.mounted) _refresh(ref);
      return;
    }
    final l10n = context.l10n;
    try {
      await repo.unpausePlayer(person, historyText: l10n.peopleActiveAgain);
      if (!context.mounted) return;
      _refresh(ref);
      ToastHelper.showSuccess(context, l10n.personReactivated);
    } catch (e) {
      if (context.mounted) ToastHelper.showError(context, l10n.peopleFlutterErrorWith(friendlyErrorMessage(e)));
    }
  }

  Future<void> _archive(BuildContext context, WidgetRef ref) async {
    if (DemoGuard.blocked()) return; // DEMO_GUARD
    final repo = ref.read(playerRepositoryWithTenantProvider);
    final l10n = context.l10n;
    final result = await showDialog<({DateTime date, String note})>(
      context: context,
      builder: (_) => _ArchiveDialog(name: '${person.firstName} ${person.lastName}'.trim()),
    );
    if (result == null || !context.mounted) return;
    try {
      await repo.archivePlayer(
        person,
        result.date.toIso8601String(),
        result.note.trim().isEmpty ? null : result.note.trim(),
      );
      if (!context.mounted) return;
      _refresh(ref);
      ToastHelper.showSuccess(context, l10n.personArchived);
      context.canPop() ? context.pop() : context.go(RedesignRoutes.members);
    } catch (e) {
      if (context.mounted) ToastHelper.showError(context, l10n.peopleFlutterErrorWith(friendlyErrorMessage(e)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.rd;
    final l10n = context.l10n;
    return Row(
      children: [
        Expanded(
          child: RdOutlineButton(
            label: person.paused ? l10n.redesignPersonResume : l10n.redesignPersonPause,
            onPressed: () => _togglePause(context, ref),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: RdOutlineButton(
            label: l10n.redesignPersonArchive,
            color: p.absent,
            onPressed: () => _archive(context, ref),
          ),
        ),
      ],
    );
  }
}

class _ArchiveDialog extends StatefulWidget {
  const _ArchiveDialog({required this.name});

  final String name;

  @override
  State<_ArchiveDialog> createState() => _ArchiveDialogState();
}

class _ArchiveDialogState extends State<_ArchiveDialog> {
  DateTime _date = DateTime.now();
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.peopleArchiveTitle(widget.name)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.peopleLeaveDate),
            subtitle: Text(DateFormat.yMMMd(currentIntlLocale()).format(_date)),
            trailing: const Icon(Icons.calendar_today_outlined),
            onTap: () async {
              final picked = await showAppDatePicker(
                context: context,
                initialDate: _date,
                firstDate: DateTime(2000),
                lastDate: DateTime.now(),
              );
              if (picked != null && mounted) setState(() => _date = picked);
            },
          ),
          TextField(
            controller: _note,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: l10n.dutyReasonOptional,
              hintText: l10n.personFlutterArchiveReasonHint,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.commonCancel)),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: p.absent),
          onPressed: () => Navigator.of(context).pop((date: _date, note: _note.text)),
          child: Text(l10n.peopleArchive),
        ),
      ],
    );
  }
}
