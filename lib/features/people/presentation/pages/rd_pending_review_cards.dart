part of 'rd_pending_review_page.dart';

/// Header, duplicate-candidate card, and registration detail cards for
/// [RdPendingReviewPage].
extension _RdPendingReviewCards on _RdPendingReviewPageState {
  Widget _head(BuildContext context, Person person) {
    final p = context.rd;
    final l10n = context.l10n;
    final name = '${person.firstName} ${person.lastName}'.trim();
    final groups = ref.watch(groupsMapProvider).valueOrNull ?? const <int, String>{};
    final group = person.groupName ?? (person.instrument == null ? null : groups[person.instrument]);
    final created = person.createdAt;
    final meta = [
      if (created != null) l10n.rdPeopleReviewRequestedOn(DateFormat(dateFmt()).format(created.toLocal())),
      if ((group ?? '').isNotEmpty) group!,
    ].join(' · ');
    return Row(
      children: [
        RdInitials(rdInitialsOf(name.isEmpty ? '?' : name), size: 64),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(header: true, child: Text(name, style: RdType.title(p).copyWith(fontSize: 24))),
              if (meta.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(meta, style: RdType.meta(p, size: 15)),
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// "Mögliche Doppelung" card with merge actions.
  Widget _duplicates(BuildContext context, Person person) {
    final p = context.rd;
    final l10n = context.l10n;
    // A child registered by an Elternteil is never merged: the merge would
    // move the parent's account onto the existing person.
    if (parentRegistrationOf(person) != null) return const SizedBox.shrink();
    // A handover request is taken in or declined as it is (a merge would
    // leave the asking group without its answer).
    if (handoverRequestOf(person) != null) return const SizedBox.shrink();
    final matches = ref.watch(duplicateCandidatesProvider(person)).valueOrNull ?? const [];
    if (matches.isEmpty) return const SizedBox.shrink();
    final groups = ref.watch(groupsMapProvider).valueOrNull ?? const <int, String>{};
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: RdCard(
        key: const Key('rd-review-duplicates'),
        color: p.excusedSoft,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.people_alt_outlined, color: p.text),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.rdPeopleReviewDuplicateTitle,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: p.text),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(l10n.rdPeopleReviewDuplicateHint, style: RdType.meta(p, size: 13)),
            for (final m in matches) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${m.candidate.firstName} ${m.candidate.lastName}',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: p.text),
                        ),
                        Text(
                          [
                            if (m.candidate.instrument != null && groups[m.candidate.instrument] != null)
                              groups[m.candidate.instrument]!,
                            m.reason,
                          ].join(' · '),
                          style: RdType.meta(p, size: 13),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  RdOutlineButton(
                    key: Key('rd-review-merge-${m.candidate.id}'),
                    label: l10n.personMerge,
                    height: 40,
                    onPressed: _busy ? null : () => _merge(m.candidate),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// What the registration holds, to read: e-mail, phone, group (the only
  /// thing to change here), dates, filled columns, extra fields, and note.
  Widget _details(BuildContext context, Person draft, bool extrasReady) {
    final p = context.rd;
    final l10n = context.l10n;
    final tenant = ref.watch(currentTenantProvider);
    final groups = ref.watch(groupsMapProvider).valueOrNull ?? const <int, String>{};
    final long = DateFormat.yMMMd(currentIntlLocale());

    String? text(String? s) => _textOrNull(s);
    String? date(String? s) {
      final d = DateTime.tryParse(s ?? '');
      return d == null ? null : long.format(d);
    }

    // Short values at the end of the row; long or multi-line ones (a note,
    // a text Zusatzfeld) in full below the label, so nothing is cut off.
    Widget block(String title, String value, {Key? key}) => SizedBox(
          key: key,
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
    Widget info(String title, String value, {Key? key}) => value.length > 28 || value.contains('\n')
        ? block(title, value, key: key)
        : RdListRow(key: key, title: title, value: value, showChevron: false);

    // Registered by an Elternteil ("Mein Kind"): the e-mail is the parent's,
    // shown in its own block below.
    final parent = parentRegistrationOf(_person ?? draft);
    final rows = <Widget>[
      if (parent == null)
        if (text(draft.email) case final v?) info(l10n.peopleEmail, v, key: const Key('rd-review-email')),
      if (text(draft.phone) case final v?) info(l10n.peoplePhone, v, key: const Key('rd-review-phone')),
      RdListRow(
        key: const Key('rd-review-group'),
        title: groupLabel(tenant?.type),
        value: draft.instrument == null ? l10n.redesignPersonFormNotSet : groups[draft.instrument] ?? '',
        onTap: _busy ? null : _pickGroup,
      ),
      if (date(draft.birthday) case final v?) info(l10n.redesignPersonBirthday, v),
      if (date(draft.playsSince) case final v?) info(l10n.personPlaysSince, v),
      if (text(draft.range) case final v?) info(l10n.personVocalRange, v),
      if (text(draft.instruments) case final v?) info(l10n.peopleInstruments, v),
      if (text(draft.otherExercise) case final v?) info(l10n.peopleOtherDuties, v),
      if ((draft.otherOrchestras ?? const <String>[]).isNotEmpty)
        info(l10n.personOtherOrchestras, draft.otherOrchestras!.join(', ')),
      if (draft.examinee) info(l10n.peopleCandidate, l10n.commonYes),
      if (text(draft.testResult) case final v?) info(l10n.peopleTestResult, v),
      if (extrasReady) ..._extraRows(info),
    ];
    final notes = text(draft.notes);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RdGroupedList(
          children: [
            ...rows,
            if (notes != null) block(l10n.redesignPersonNotes, notes, key: const Key('rd-review-notes')),
          ],
        ),
        if (parent != null) ...[
          const SizedBox(height: 18),
          RdSectionHeader(l10n.parentRegisterReviewParent),
          RdGroupedList(
            children: [
              block(parent.fullName, parent.email, key: const Key('rd-review-parent')),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
            child: Text(parentReviewHint(ref, l10n, parent), style: RdType.meta(p, size: 13)),
          ),
        ],
        if (!extrasReady) ...[
          const SizedBox(height: 12),
          RdInfoCard(text: l10n.redesignTodayLoading, loading: true),
        ],
      ],
    );
  }

  /// Zusatzfelder the registration filled (defaults added for the approval
  /// are not shown).
  List<Widget> _extraRows(Widget Function(String title, String value, {Key? key}) info) {
    final churches = ref.watch(churchesProvider).valueOrNull ?? const <Church>[];
    final churchNames = {
      for (final c in churches)
        if (c.id != null) c.id!: c.name,
    };
    return [
      for (final f in ref.watch(personListExtraFieldsProvider))
        if (_additional[f.id] != null && !_defaulted.contains(f.id))
          if (formatExtraFieldValue(_additional, f, churchNames: churchNames).trim() case final v when v.isNotEmpty)
            info(f.name, v),
    ];
  }
}
