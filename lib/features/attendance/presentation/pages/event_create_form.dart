part of 'event_create_page.dart';

extension _RdEventCreateForm on _RdEventCreatePageState {
  Widget _form(
    BuildContext context, {
    required List<AttendanceType> types,
    required List<Attendance> history,
    required HolidayData holidays,
    required List<DateTime> dates,
  }) {
    final p = context.rd;
    final l10n = context.l10n;
    final locale = currentIntlLocale();
    final type = _type;
    final places = rdRecentPlaces(history).where((s) => s != _place.text.trim()).toList();
    final holidayHits = [
      for (final d in dates)
        if (rdHolidayOn(holidays, d) != null) d,
    ];
    return RdFormBody(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 12),
          child: Text(
            l10n.rdCreateFormWhat,
            style: TextStyle(fontSize: 25, fontWeight: FontWeight.w700, color: p.text),
          ),
        ),
        if (types.length <= 6)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in types)
                ChoiceChip(
                  key: ValueKey('rd-create-type-${t.id}'),
                  label: Text(t.name),
                  selected: t.id == type?.id,
                  selectedColor: p.primary,
                  backgroundColor: p.surface,
                  showCheckmark: false,
                  labelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontSize: 15,
                    color: t.id == type?.id ? p.onPrimary : p.text,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  side: BorderSide(color: t.id == type?.id ? Colors.transparent : p.line),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
                  onSelected: (selected) {
                    if (!selected || t.id == _type?.id) return;
                    _touch(() => _applyType(t));
                  },
                ),
            ],
          )
        else
          RdGroupedList(
            children: [
              RdListRow(
                title: l10n.redesignCreateType,
                value: type?.name ?? l10n.redesignCreateChooseType,
                onTap: () => _pickType(types),
              ),
            ],
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 6, 4, 16),
          child: Text(
            type?.allDay == true
                ? l10n.rdCreateFormAllDayHint
                : _timesEdited
                ? l10n.rdCreateFormCustomTimes
                : l10n.rdCreateFormTypeDefaults,
            style: RdType.meta(p, size: 12),
          ),
        ),
        RdGroupedList(
          children: [
            RdFieldRow(
              label: l10n.redesignCreateTitleLabel,
              child: TextField(
                controller: _title,
                textCapitalization: TextCapitalization.sentences,
                style: TextStyle(fontSize: 17, color: p.text),
                decoration: rdInputDecoration(p, type?.name ?? l10n.rdCreateFormTitleHint),
                onChanged:
                    (_) => _touch(() {
                      _titleEdited = true;
                    }),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _Label(l10n.rdCreateFormWhen),
        RdGroupedList(
          children: [
            RdListRow(
              title: l10n.redesignCreateDate,
              value: DateFormat.yMMMEd(locale).format(_date),
              onTap: _pickDate,
            ),
            if (type?.allDay == true)
              RdListRow(
                title: l10n.rdTypeAllDay,
                subtitle: l10n.redesignCreateDuration,
                showChevron: false,
                trailing: _Stepper(
                  value: l10n.redesignCreateDays(_durationDays),
                  lessLabel: l10n.redesignCreateFewerDays,
                  moreLabel: l10n.redesignCreateMoreDays,
                  onLess:
                      _durationDays > 1
                          ? () => _touch(() {
                            _durationEdited = true;
                            _durationDays--;
                          })
                          : null,
                  onMore:
                      _durationDays < 30
                          ? () => _touch(() {
                            _durationEdited = true;
                            _durationDays++;
                          })
                          : null,
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _timeField(l10n.redesignCreateStart, _start, () => _pickTime(start: true)),
                    ),
                    const SizedBox(width: 16),
                    Expanded(child: _timeField(l10n.redesignCreateEnd, _end, () => _pickTime(start: false))),
                  ],
                ),
              ),
            RdListRow(
              title: l10n.rdCreateFormRepeat,
              value: _repeatLabel(l10n, locale),
              onTap: () => _pickRepeat(holidays),
            ),
          ],
        ),
        if (dates.length > 1 || holidayHits.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: _Summary(text: _summary(l10n, locale, dates, holidayHits, holidays)),
          ),
        const SizedBox(height: 16),
        RdGroupedList(
          children: [
            RdFieldRow(
              label: l10n.redesignCreatePlace,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _place,
                    textCapitalization: TextCapitalization.sentences,
                    style: TextStyle(fontSize: 17, color: p.text),
                    decoration: rdInputDecoration(p, l10n.rdCreateFormPlaceHint),
                    onChanged: (_) => _touch(() {}),
                  ),
                  if (places.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final place in places)
                            RdPlaceChip(place, onTap: () => _touch(() => _place.text = place)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        if (type != null)
          Padding(padding: const EdgeInsets.symmetric(vertical: 14), child: _InvitedRow(type: type)),
        RdGroupedList(
          children: [
            RdListRow(
              key: const ValueKey('rd-create-options'),
              title: l10n.rdCreateFormOptions,
              titleColor: p.primary,
              showChevron: false,
              subtitle:
                  !_optionsExpanded && (_songs.isNotEmpty || _deadline != RdDeadline.none)
                      ? [
                        if (_deadline != RdDeadline.none) rdDeadlineLabel(l10n, _deadline),
                        if (_songs.isNotEmpty) l10n.redesignCreateSongsCount(_songs.length),
                      ].join(' · ')
                      : null,
              trailing: Icon(_optionsExpanded ? Icons.expand_less : Icons.expand_more, color: p.primary),
              onTap: () => _update(() => _optionsExpanded = !_optionsExpanded),
            ),
            if (_optionsExpanded) ...[
              RdListRow(
                title: l10n.redesignCreateDeadline,
                value: rdDeadlineLabel(l10n, _deadline),
                onTap: _pickDeadline,
              ),
              if (type != null && ref.watch(currentTenantProvider)?.type != 'general') ...[
                RdListRow(
                  title: l10n.redesignCreateSongs,
                  value:
                      _songs.isEmpty
                          ? l10n.redesignCreateSongsNone
                          : l10n.redesignCreateSongsCount(_songs.length),
                  onTap: _addSongs,
                ),
                for (final s in _songs)
                  RdListRow(
                    leading: const RdRowIcon(Icons.music_note_outlined),
                    title: s.songName,
                    subtitle: s.displayConductor,
                    showChevron: false,
                    trailing: IconButton(
                      icon: Icon(Icons.close, size: 20, color: p.text2),
                      tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
                      onPressed: () => _touch(() => _songs = [..._songs]..remove(s)),
                    ),
                  ),
              ],
              Padding(
                padding: const EdgeInsets.all(14),
                child: Text(l10n.redesignCreateLaterHint, style: RdType.meta(p, size: 12)),
              ),
            ],
          ],
        ),
        if (type?.dutyMode == true) ...[
          const SizedBox(height: 16),
          RdGroupedList(
            children: [
              for (final wd in _dutyWeekdays(type!, dates))
                RdListRow(
                  title: l10n.redesignCreateDuty(
                    DateFormat.EEEE(locale).format(DateTime(2024, 1, wd.weekday)),
                  ),
                  subtitle: l10n.redesignCreateDutyCount(wd.count),
                  showChevron: false,
                  trailing: _Stepper(
                    value: '${wd.required}',
                    lessLabel: l10n.redesignCreateFewer,
                    moreLabel: l10n.redesignCreateMore,
                    onLess: wd.required > 1 ? () => _touch(() => _duty[wd.weekday] = wd.required - 1) : null,
                    onMore: () => _touch(() => _duty[wd.weekday] = wd.required + 1),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _timeField(String label, String? value, VoidCallback onTap) {
    final p = context.rd;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: RdType.meta(p, size: 12)),
        const SizedBox(height: 5),
        Semantics(
          button: true,
          label: '$label ${value ?? '–'}',
          excludeSemantics: true,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(9),
            child: Container(
              constraints: const BoxConstraints(minHeight: 44),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(color: p.track, borderRadius: BorderRadius.circular(9)),
              child: Row(
                children: [
                  Expanded(child: Text(value ?? '–', style: TextStyle(fontSize: 16, color: p.text))),
                  Icon(Icons.schedule, size: 17, color: p.text2),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _repeatLabel(AppLocalizations l10n, String locale) {
    final until = DateFormat.Md(locale).format(_until);
    return switch (_repeat) {
      RdRepeat.once => l10n.redesignCreateRepeatOnce,
      RdRepeat.weekly => l10n.redesignCreateRepeatWeekly(DateFormat.E(locale).format(_date), until),
      RdRepeat.biweekly => l10n.redesignCreateRepeatBiweekly(until),
      RdRepeat.custom => l10n.redesignCreateRepeatCustom(_customDates.length - 1),
    };
  }

  String _summary(
    AppLocalizations l10n,
    String locale,
    List<DateTime> dates,
    List<DateTime> holidayHits,
    HolidayData holidays,
  ) {
    final parts = <String>[];
    if (dates.length > 1) {
      final fmt = DateFormat.Md(locale);
      final weekday = DateFormat.EEEE(locale).format(_date);
      final rule = switch (_repeat) {
        RdRepeat.weekly => ', ${l10n.redesignCreateSummaryWeekly(weekday)}',
        RdRepeat.biweekly => ', ${l10n.redesignCreateSummaryBiweekly(weekday)}',
        _ => '',
      };
      parts.add(
        '${l10n.redesignCreateSummaryCount(dates.length)}: '
        '${l10n.redesignCreateSummaryRange(fmt.format(dates.first), fmt.format(dates.last))}$rule.',
      );
    }
    if (holidayHits.isNotEmpty) {
      final names = {for (final d in holidayHits) rdHolidayOn(holidays, d)!}.join(', ');
      parts.add('${l10n.redesignCreateHolidayHits(holidayHits.length)}: $names.');
    }
    return parts.join(' ');
  }

  List<({int weekday, int count, int required})> _dutyWeekdays(AttendanceType type, List<DateTime> dates) {
    final counts = <int, int>{};
    for (final d in dates) {
      counts[d.weekday] = (counts[d.weekday] ?? 0) + 1;
    }
    final keys = counts.keys.toList()..sort();
    return [
      for (final wd in keys) (weekday: wd, count: counts[wd]!, required: _duty[wd] ?? type.dutyRequired ?? 1),
    ];
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
    child: Text(text, style: RdType.meta(context.rd, size: 13)),
  );
}

/// "− 2 Tage +".
class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.value,
    required this.lessLabel,
    required this.moreLabel,
    required this.onLess,
    required this.onMore,
  });

  final String value;
  final String lessLabel;
  final String moreLabel;
  final VoidCallback? onLess;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(icon: const Icon(Icons.remove), color: p.primary, tooltip: lessLabel, onPressed: onLess),
        Text(value, style: TextStyle(fontSize: 15, color: p.text, fontWeight: FontWeight.w600)),
        IconButton(icon: const Icon(Icons.add), color: p.primary, tooltip: moreLabel, onPressed: onMore),
      ],
    );
  }
}

/// "Wer ist eingeladen?": everyone or the type's groups, with the count of
/// persons the Termin is created for.
class _InvitedRow extends ConsumerWidget {
  const _InvitedRow({required this.type});

  final AttendanceType type;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final players = ref.watch(playersProvider).valueOrNull;
    final fields = ref.watch(personExtraFieldsProvider).valueOrNull ?? const [];
    final groups = ref.watch(groupsMapProvider).valueOrNull ?? const <int, String>{};
    final persons = ref.watch(typeCirclePersonsProvider).valueOrNull?[type.id] ?? const <int>[];
    final count =
        players == null ? '…' : '${rdInvitedPersons(players, type, fields, circlePersons: persons).length}';
    final relevant = type.relevantGroups ?? const <int>[];
    final value =
        typeCircleIsEveryone(relevant, persons)
            ? l10n.redesignCreateInvitedAll(count)
            : l10n.redesignCreateInvitedGroups(
              [
                for (final id in relevant)
                  if (groups[id] != null) groups[id]!,
                if (persons.isNotEmpty) l10n.rdTeamCirclePersonsCount(persons.length),
              ].join(', '),
              count,
            );
    final p = context.rd;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Icon(Icons.people_outline, size: 21, color: p.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.rdCreateFormInvited(value), style: TextStyle(fontSize: 13, color: p.text)),
                const SizedBox(height: 2),
                Text(l10n.redesignCreateInvitedHint, style: RdType.meta(p, size: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(color: p.soft, borderRadius: BorderRadius.circular(14)),
        child: Text(text, style: TextStyle(fontSize: 14, color: p.softText, height: 1.35)),
      ),
    );
  }
}
