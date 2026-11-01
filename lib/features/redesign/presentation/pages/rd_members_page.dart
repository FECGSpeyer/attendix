import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/providers/attendance_providers.dart';
import '../../../../core/providers/debug_providers.dart';
import '../../../../core/providers/group_providers.dart';
import '../../../../core/providers/player_absence_providers.dart';
import '../../../../core/providers/player_providers.dart';
import '../../../../core/providers/realtime_providers.dart';
import '../../../../core/router/redesign_routes.dart';
import '../../../../core/theme/redesign/rd_palette.dart';
import '../../../../core/theme/redesign/rd_theme.dart';
import '../../../../data/models/person/person.dart';
import '../../../../data/models/player_absence/player_absence.dart';
import '../../../../l10n/l10n.dart';
import '../../data/providers/rd_members_providers.dart';
import '../../data/rd_members_logic.dart';
import '../widgets/members/rd_invite_sheet.dart';
import '../widgets/rd_split_view.dart';
import '../widgets/rd_widgets.dart';
import '../widgets/today/rd_today_common.dart' show RdInfoCard;

/// REDESIGN: tab "Mitglieder" for Dirigent and Beobachter (canvas
/// "Menschen"): Aktiv / Pausiert / Wartet (also by swiping the list),
/// search, registers with Ø attendance, birthdays and absences in the rows.
class RdMembersPage extends ConsumerStatefulWidget {
  const RdMembersPage({super.key});

  @override
  ConsumerState<RdMembersPage> createState() => _RdMembersPageState();
}

class _RdMembersPageState extends ConsumerState<RdMembersPage> {
  RdMembersFilter _filter = RdMembersFilter.active;
  String _query = '';

  /// Thumb of Aktiv / Pausiert / Wartet while swiping the list.
  /// Notifier so only the segmented control rebuilds while swiping, not
  /// the whole page with every row.
  final _swipePos = ValueNotifier<double?>(null);
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    // DB_REVIEW_REST (F3) like the old list: admins/responsibles lift
    // expired pauses (paused_until reached) when opening the list.
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkAndUnpause());
  }

  Future<void> _checkAndUnpause() async {
    if (!mounted) return;
    final role = ref.read(effectiveRoleProvider);
    if (!(role.isAdmin || role.isResponsible)) return;
    final repo = ref.read(playerRepositoryWithTenantProvider);
    if (!repo.hasTenantId) return;
    try {
      await repo.checkAndUnpausePlayers();
    } catch (_) {
      return;
    }
    if (mounted) ref.invalidate(realtimePlayersProvider);
  }

  @override
  void dispose() {
    _search.dispose();
    _swipePos.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final role = ref.watch(effectiveRoleProvider);
    final canApprove = role.isAdmin || role.isResponsible;
    final peopleAsync = ref.watch(realtimePlayersProvider);
    final people = peopleAsync.valueOrNull ?? const <Person>[];
    final pending = canApprove
        ? ref.watch(realtimePendingPlayersProvider).valueOrNull ?? const <Person>[]
        : const <Person>[];
    final percentages = ref.watch(playerAttendancePercentagesProvider).valueOrNull ?? const <int, int>{};
    final groups = ref.watch(groupsProvider).valueOrNull ?? const [];
    final absences = ref.watch(playerAbsencesProvider).valueOrNull ?? const <PlayerAbsence>[];

    final active = people.where((x) => !x.paused).toList();
    final paused = people.where((x) => x.paused).toList();
    final filter = _filter == RdMembersFilter.pending && pending.isEmpty ? RdMembersFilter.active : _filter;
    final filters = [
      RdMembersFilter.active,
      RdMembersFilter.paused,
      if (pending.isNotEmpty) RdMembersFilter.pending,
    ];
    // UX D3: "Fehlen oft · N" narrows Aktiv to the critical members.
    final critical = rdCriticalMembers(active);
    // An empty filter stays on (shows nobody) instead of silently showing all.
    final criticalOnly = filter == RdMembersFilter.active && ref.watch(rdMembersCriticalOnlyProvider);
    final shown = switch (filter) {
      RdMembersFilter.active => criticalOnly ? critical : active,
      RdMembersFilter.paused => paused,
      RdMembersFilter.pending => pending,
    };

    final sections = rdMemberSections(
      shown,
      groups: groups,
      percentages: percentages,
      noGroupLabel: l10n.attendanceNoGroup,
    );
    final filtered = [
      for (final s in sections)
        if (s.people.any((x) => rdPersonMatches(x, _query, register: s.title)))
          RdMemberSection(
            title: s.title,
            people: s.people.where((x) => rdPersonMatches(x, _query, register: s.title)).toList(),
            average: s.average,
            isRegister: s.isRegister,
          ),
    ];

    final children = <Widget>[
      Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(l10n.redesignTabMembers, style: RdType.largeTitle(p)),
            ),
          ),
          // UX D1: invite right here (Dirigent, Verantwortlich).
          if (canApprove) ...[
            RdPillButton(
              icon: Icons.person_add_alt_outlined,
              label: l10n.redesignInviteButton,
              onPressed: () => showRdInviteSheet(context),
            ),
            const SizedBox(width: 8),
          ],
          if (canApprove)
            RdCircleButton(
              icon: Icons.bar_chart_rounded,
              label: l10n.redesignMembersStats,
              onPressed: () => context.push(RedesignRoutes.stats),
            ),
        ],
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _search,
        onChanged: (v) => setState(() => _query = v),
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: l10n.redesignMembersSearch,
          prefixIcon: Icon(Icons.search, color: p.text2),
          suffixIcon: _query.isEmpty
              ? null
              : IconButton(
                  icon: Icon(Icons.close, color: p.text2),
                  tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
                  onPressed: () => setState(() {
                    _search.clear();
                    _query = '';
                  }),
                ),
          filled: true,
          fillColor: p.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(p.buttonRadius),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(p.buttonRadius),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      const SizedBox(height: 12),
      ValueListenableBuilder<double?>(
        valueListenable: _swipePos,
        builder: (context, pos, _) => RdSegmented<RdMembersFilter>(
          values: filters,
          selected: filter,
          position: pos,
          labelOf: (f) => switch (f) {
            RdMembersFilter.active => l10n.redesignMembersActive(active.length),
            RdMembersFilter.paused => l10n.redesignMembersPaused(paused.length),
            RdMembersFilter.pending => l10n.redesignMembersPending(pending.length),
          },
          onChanged: (f) => setState(() => _filter = f),
        ),
      ),
      if (filter == RdMembersFilter.active && (critical.isNotEmpty || criticalOnly)) ...[
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: RdChoiceChip(
            label: l10n.redesignMembersCritical(critical.length),
            selected: criticalOnly,
            onTap: () => ref.read(rdMembersCriticalOnlyProvider.notifier).state = !criticalOnly,
          ),
        ),
      ],
      const SizedBox(height: 16),
    ];

    final body = <Widget>[];
    if (peopleAsync.isLoading && people.isEmpty) {
      body.add(RdInfoCard(text: l10n.redesignTodayLoading, loading: true));
    } else if (peopleAsync.hasError && people.isEmpty) {
      body.add(RdInfoCard(
        text: l10n.redesignTodayLoadFailed,
        icon: Icons.cloud_off_outlined,
        action: RdOutlineButton(
          label: l10n.redesignCommonRetry,
          onPressed: () => ref.invalidate(realtimePlayersProvider),
        ),
      ));
    } else if (filtered.isEmpty && people.isEmpty && _query.trim().isEmpty && canApprove) {
      // UX D1: a new group starts with the invitation.
      body.add(RdInfoCard(
        icon: Icons.people_outline,
        text: l10n.redesignInviteEmptyMembers,
        action: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            RdPrimaryButton(
              label: l10n.redesignInviteButton,
              icon: Icons.person_add_alt_outlined,
              onPressed: () => showRdInviteSheet(context),
            ),
            if (role.canEdit) ...[
              const SizedBox(height: 8),
              RdOutlineButton(
                label: l10n.redesignInviteAddPerson,
                onPressed: () => context.push('/people/new'),
              ),
            ],
          ],
        ),
      ));
    } else if (filtered.isEmpty) {
      body.add(RdInfoCard(
        icon: Icons.people_outline,
        text: _query.trim().isNotEmpty || criticalOnly
            ? l10n.redesignMembersNoMatch
            : switch (filter) {
                RdMembersFilter.active => l10n.redesignMembersEmpty,
                RdMembersFilter.paused => l10n.redesignMembersEmptyPaused,
                RdMembersFilter.pending => l10n.redesignMembersEmptyPending,
              },
      ));
    } else {
      if (filter == RdMembersFilter.pending) {
        body.add(Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
          child: Text(l10n.redesignMembersPendingHint, style: RdType.meta(p, size: 13)),
        ));
      }
      for (final s in filtered) {
        body.add(_SectionHeader(section: s));
        body.add(RdGroupedList(children: [
          for (final person in s.people)
            _MemberRow(
              person: person,
              showGroup: s.isRegister,
              percent: filter == RdMembersFilter.pending || person.id == null ? null : percentages[person.id],
              absence: person.id == null ? null : rdCurrentAbsence(absences, person.id!),
              selected: person.id != null && RdSplitScope.of(context)?.selectedId == person.id,
              onTap: person.id == null
                  ? null
                  : () => filter == RdMembersFilter.pending
                      ? context.push('/people/${person.id}')
                      : RdSplitScope.open(context, RedesignRoutes.person(person.id!)),
            ),
        ]));
        body.add(const SizedBox(height: 18));
      }
    }

    children.add(RdSwipeSwitch<RdMembersFilter>(
      values: filters,
      selected: filter,
      onChanged: (f) => setState(() => _filter = f),
      onDrag: (pos) => _swipePos.value = pos,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: body),
    ));

    return RdPage(
      onRefresh: () async {
        ref.invalidate(realtimePlayersProvider);
        ref.invalidate(playerAttendancePercentagesProvider);
        ref.invalidate(playerAbsencesProvider);
        if (canApprove) ref.invalidate(realtimePendingPlayersProvider);
      },
      floatingActionButton: role.canEdit
          ? FloatingActionButton(
              tooltip: l10n.redesignMembersAdd,
              backgroundColor: p.primary,
              foregroundColor: p.onPrimary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              onPressed: () => context.push('/people/new'),
              child: const Icon(Icons.person_add_alt_1_outlined, size: 26),
            )
          : null,
      children: children,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.section});

  final RdMemberSection section;

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
                l10n.redesignMembersSection(section.title, section.people.length).toUpperCase(),
                style: RdType.eyebrow(p.text2),
              ),
            ),
          ),
          if (section.average != null)
            Text(l10n.redesignMembersAverage(section.average!), style: RdType.meta(p, size: 13)),
        ],
      ),
    );
  }
}

/// Color of an attendance percentage (≥ 75 present, ≥ 50 late, else absent).
Color rdPercentColor(RdPalette p, int percent) =>
    percent >= 75 ? p.present : (percent >= 50 ? p.late : p.absent);

class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.person,
    required this.showGroup,
    required this.percent,
    required this.absence,
    required this.onTap,
    this.selected = false,
  });

  final Person person;
  final bool showGroup;
  final int? percent;
  final PlayerAbsence? absence;
  final VoidCallback? onTap;

  /// Open on the right of the split view.
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final locale = currentIntlLocale();
    final short = DateFormat.Md(locale);
    final name = '${person.firstName} ${person.lastName}'.trim();

    final hints = <String>[
      if (showGroup && (person.groupName ?? '').isNotEmpty) person.groupName!,
    ];
    final birthdayIn = rdDaysToBirthday(person.birthday);
    if (birthdayIn != null && birthdayIn <= 7) {
      hints.add(switch (birthdayIn) {
        0 => l10n.redesignMembersBirthdayToday,
        1 => l10n.redesignMembersBirthdayTomorrow,
        _ => l10n.redesignMembersBirthdayIn(birthdayIn),
      });
    }
    if (person.paused) {
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
    if (person.pending && (person.email ?? '').isNotEmpty) hints.add(person.email!);

    final pct = percent;
    final low = pct != null && pct < 50;
    final color = pct == null ? p.text2 : rdPercentColor(p, pct);

    return Semantics(
      button: onTap != null,
      selected: selected,
      child: Material(
        color: selected ? p.soft : Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 60),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                children: [
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
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: p.soft,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  l10n.redesignMembersLeader,
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: p.softText),
                                ),
                              ),
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
                      ],
                    ),
                  ),
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
                  if (onTap != null) ...[
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
