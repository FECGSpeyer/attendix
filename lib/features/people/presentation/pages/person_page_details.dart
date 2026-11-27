part of 'person_page.dart';

/// Read-only archived details, contact action grid, and personal info rows
/// for [RdPersonPage].
class _LeftDetails extends ConsumerWidget {
  const _LeftDetails({required this.person});

  final Person person;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.rd;
    final l10n = context.l10n;
    final tenant = ref.watch(currentTenantProvider);
    final groups = ref.watch(groupsMapProvider).valueOrNull ?? const <int, String>{};
    final churches = ref.watch(churchesProvider).valueOrNull ?? const <Church>[];
    final churchNames = {
      for (final c in churches)
        if (c.id != null) c.id!: c.name,
    };
    final role = ref.watch(effectiveRoleProvider);
    final long = DateFormat.yMMMd(currentIntlLocale());

    String? text(String? s) => (s ?? '').trim().isEmpty ? null : s!.trim();
    String? date(String? s) {
      final d = DateTime.tryParse(s ?? '');
      return d == null ? null : long.format(d);
    }

    // Full width, so a long value starts on the left (like _InfoList).
    Widget block(String title, String value) => SizedBox(
          width: double.infinity,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: p.text)),
                const SizedBox(height: 2),
                Text(value, style: RdType.meta(p, size: 14)),
              ],
            ),
          ),
        );
    Widget info(String title, String value) => value.length > 28 || value.contains('\n')
        ? block(title, value)
        : RdListRow(title: title, value: value, showChevron: false);

    final group = person.groupName ?? (person.instrument == null ? null : groups[person.instrument]);
    // Zusatzfelder with the organisation's values (shown once loaded).
    final additional = ref.watch(_leftFieldValuesProvider(person)).valueOrNull ?? const <String, dynamic>{};
    final orgFieldIds = {
      for (final f in ref.watch(personExtraFieldsProvider).valueOrNull ?? const [])
        if (f.isOrganisationField) f.id,
    };
    final pausedUntil = DateTime.tryParse(person.pausedUntil ?? '');
    // Internal note: only Admins and Verantwortliche (like _InfoList).
    final notes = role.isAdmin || role.isResponsible ? text(person.notes) : null;
    final rows = <Widget>[
      if (text(group) case final v?) info(groupLabel(tenant?.type), v),
      // Archiving keeps a pause; restoring brings it back.
      if (person.paused)
        info(
          l10n.redesignPersonPaused,
          pausedUntil == null ? l10n.redesignPersonPausedOpen : l10n.redesignMembersPausedUntil(long.format(pausedUntil)),
        ),
      if (date(person.correctBirthday ? person.birthday : null) case final v?) info(l10n.redesignPersonBirthday, v),
      if (date(person.joined) case final v?) info(l10n.redesignPersonJoined, v),
      if (date(person.playsSince) case final v?) info(l10n.personPlaysSince, v),
      if (text(person.range) case final v?) info(l10n.personVocalRange, v),
      if (text(person.instruments) case final v?) info(l10n.peopleInstruments, v),
      if (text(person.otherExercise) case final v?) info(l10n.peopleOtherDuties, v),
      if ((person.otherOrchestras ?? const <String>[]).isNotEmpty)
        info(l10n.personOtherOrchestras, person.otherOrchestras!.join(', ')),
      if (person.examinee) info(l10n.peopleCandidate, l10n.commonYes),
      if (text(person.testResult) case final v?) info(l10n.peopleTestResult, v),
      for (final f in ref.watch(personListExtraFieldsProvider))
        if (additional[f.id] != null)
          if (formatExtraFieldValue(additional, f, churchNames: churchNames).trim() case final v when v.isNotEmpty)
            orgFieldIds.contains(f.id)
                ? RdListRow(
                    title: f.name,
                    subtitle: l10n.rdOrgFieldSharedHint,
                    leading: RdOrgPill(l10n.rdOrgBadge, compact: true),
                    value: v,
                    showChevron: false,
                  )
                : info(f.name, v),
      if (notes != null) block(l10n.redesignPersonNotes, notes),
    ];
    if (rows.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RdGroupLabel(l10n.rdPeopleReviewDetails),
        RdGroupedList(children: rows),
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

    // A placeholder birthday (correctBirthday false) is not shown.
    final birthday = person.correctBirthday ? DateTime.tryParse(person.birthday ?? '') : null;
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
    if (helperUntil(person) case final until?) {
      rows.add(RdListRow(
        title: l10n.rdHelperTitle,
        // "Aushilfe · bis 30. Nov. 2026"; what it means stands below the list.
        value: l10n.rdTextHelperUntil(long.format(DateTime.parse(until))),
        showChevron: false,
      ));
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
    // Internal note: only Admins and Verantwortliche.
    final role = ref.watch(effectiveRoleProvider);
    final notes = role.isAdmin || role.isResponsible ? (person.notes ?? '').trim() : '';
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
    if (helperUntil(person) == null) return RdGroupedList(children: rows);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [RdGroupedList(children: rows), RdListNote(l10n.rdHelperPersonHint)],
    );
  }
}
