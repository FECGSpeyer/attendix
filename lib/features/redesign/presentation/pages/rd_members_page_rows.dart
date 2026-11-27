part of 'rd_members_page.dart';

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.section, this.onSelectAll});

  final RdMemberSection section;

  /// "Auswählen": selects the whole section (or none when all are).
  final VoidCallback? onSelectAll;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                section.title.isEmpty
                    ? ''
                    : l10n.redesignMembersSection(section.title, section.people.length).toUpperCase(),
                style: RdType.eyebrow(p.text2),
              ),
            ),
          ),
          if (onSelectAll != null)
            RdTextLink(
              label: section.title.isEmpty
                  ? l10n.redesignBulkSelectAll
                  : l10n.redesignBulkSelectGroup(section.title),
              onTap: onSelectAll!,
            )
          else if (section.average != null)
            Text(l10n.redesignMembersAverage(section.average!), style: RdType.meta(p, size: 13)),
        ],
      ),
    );
  }
}

/// Date of the latest past Termin whose type counts for the attendance
/// rate; null while the list loads or nothing counted yet.
final _lastCountedTerminProvider = Provider.autoDispose<DateTime?>((ref) {
  final attendances = ref.watch(realtimeAttendanceListProvider).valueOrNull;
  final types = ref.watch(attendanceTypesProvider).valueOrNull;
  if (attendances == null || types == null) return null;
  final counted = {
    for (final t in types)
      if (t.includeInAverage && t.id != null) t.id!,
  };
  final now = DateTime.now();
  DateTime? last;
  for (final a in attendances) {
    if (a.typeId == null || !counted.contains(a.typeId)) continue;
    final date = DateTime.tryParse(a.date)?.toLocal();
    if (date == null || !date.isBefore(now)) continue;
    if (last == null || date.isAfter(last)) last = date;
  }
  return last;
});

/// Color of an attendance percentage (≥ 75 present, ≥ 50 late, else absent).
Color rdPercentColor(RdPalette p, int percent) =>
    percent >= 75 ? p.present : (percent >= 50 ? p.late : p.absent);

class _MemberRow extends StatelessWidget {
  const _MemberRow({
    super.key,
    required this.person,
    required this.showGroup,
    required this.percent,
    required this.absence,
    required this.onTap,
    this.lastCounted,
    this.seasonRate = false,
    this.selected = false,
    this.checked,
    this.readOnly = false,
    this.einteilung,
    this.sortHint,
    this.reason,
  });

  /// Why the person is a Problemfall ("4-mal unentschuldigt gefehlt").
  final String? reason;

  /// Date of the chosen sort order (birthday, joined).
  final String? sortHint;

  /// Spieler/Helfer view: no birthdays, absences, pauses or mail addresses.
  final bool readOnly;

  /// "Nord" / "Süd" while all are shown (read-only view).
  final String? einteilung;

  final Person person;
  final bool showGroup;
  final int? percent;

  /// For "neu" instead of 0 % (see [rdShownRate]).
  final DateTime? lastCounted;
  final bool seasonRate;
  final PlayerAbsence? absence;
  final VoidCallback? onTap;

  /// Open on the right of the split view.
  final bool selected;

  /// "Auswählen": whether the person is in the selection (null: not
  /// selecting). Shows a selection circle instead of the initials.
  final bool? checked;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final locale = currentIntlLocale();
    final short = DateFormat.Md(locale);
    final name = '${person.firstName} ${person.lastName}'.trim();

    final hints = <String>[
      if (showGroup && (person.groupName ?? '').isNotEmpty) person.groupName!,
      if (einteilung != null) einteilung!,
      if (sortHint != null) sortHint!,
    ];
    // A placeholder birthday (correctBirthday false, e.g. "today" of a new
    // person) is no birthday.
    final birthdayIn = readOnly || !person.correctBirthday ? null : rdDaysToBirthday(person.birthday);
    if (birthdayIn != null && birthdayIn <= 7) {
      hints.add(switch (birthdayIn) {
        0 => l10n.redesignMembersBirthdayToday,
        1 => l10n.redesignMembersBirthdayTomorrow,
        _ => l10n.redesignMembersBirthdayIn(birthdayIn),
      });
    }
    if (readOnly) {
      // Names only, like the old list.
    } else if (person.paused) {
      final until = DateTime.tryParse(person.pausedUntil ?? '');
      if (until != null) hints.add(l10n.redesignMembersPausedUntil(short.format(until)));
    } else if (absence != null) {
      final from = DateTime.tryParse(absence!.fromDate);
      final until = DateTime.tryParse(absence!.untilDate);
      final today = DateTime.now();
      final running = from != null && !from.isAfter(DateTime(today.year, today.month, today.day));
      if (running && until != null) {
        hints.add(l10n.redesignMembersAbsentUntil(short.format(until)));
      } else if (from != null) {
        hints.add(l10n.redesignMembersAbsentFrom(short.format(from)));
      }
    }
    final parentReg = person.pending ? parentRegistrationOf(person) : null;
    final handover = handoverRequestOf(person);
    if (!readOnly && handover != null) {
      // Another group of the organisation asks to hand the person over.
      hints.add(l10n.peopleFlutterHandoverRequestFrom(handover.fromTenantName));
    } else if (!readOnly && parentReg != null) {
      // Registered by an Elternteil via the link ("Mein Kind").
      hints.add(l10n.parentRegisterChildOf(parentReg.fullName));
    } else if (!readOnly && person.pending && (person.email ?? '').isNotEmpty) {
      hints.add(person.email!);
    }
    final helperLastDay = readOnly ? null : helperUntil(person);
    if (helperLastDay != null) hints.add(l10n.rdHelperUntil(short.format(DateTime.parse(helperLastDay))));

    final rate = rdShownRate(person, percent, lastCounted: lastCounted, seasonRate: seasonRate);
    final pct = rate.percent;
    final low = pct != null && pct < 50;
    final color = pct == null ? p.text2 : rdPercentColor(p, pct);

    final isChecked = checked;
    return Semantics(
      button: onTap != null && isChecked == null,
      selected: selected,
      checked: isChecked,
      child: Material(
        color: selected || isChecked == true ? p.soft : Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 60),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                children: [
                  if (isChecked != null)
                    SizedBox(
                      width: 36,
                      child: Icon(
                        isChecked ? Icons.check_circle : Icons.radio_button_unchecked,
                        color: isChecked ? p.primary : p.text2,
                      ),
                    )
                  else
                    RdInitials(rdInitialsOf(name.isEmpty ? '?' : name)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: p.text),
                              ),
                            ),
                            if (person.isLeader) ...[
                              const SizedBox(width: 6),
                              const RdLeaderTag(),
                            ],
                          ],
                        ),
                        if (hints.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              hints.join(' · '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: RdType.meta(p, size: 13),
                            ),
                          ),
                        if (reason != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              reason!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 13, color: p.absent),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (rate.isNew) ...[
                    const SizedBox(width: 8),
                    Text(l10n.redesignMembersNew, style: TextStyle(fontSize: 15, color: p.text2)),
                  ],
                  if (pct != null) ...[
                    const SizedBox(width: 8),
                    if (low) ...[
                      Icon(Icons.warning_amber_rounded, size: 16, color: color, semanticLabel: l10n.redesignMembersLow),
                      const SizedBox(width: 2),
                    ],
                    Text(
                      l10n.redesignMembersPercent(pct),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: color,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                  if (onTap != null && isChecked == null) ...[
                    const SizedBox(width: 4),
                    Icon(Icons.chevron_right, size: 20, color: p.text2),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
