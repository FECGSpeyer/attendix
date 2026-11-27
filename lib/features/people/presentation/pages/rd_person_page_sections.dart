part of 'rd_person_page.dart';

/// Attendance summary card, status tiles, and pause/archive actions for
/// [RdPersonPage].
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
    // The percentage only counts Termine of types that count for the
    // average, so "von" names the same Termine.
    final counted = (stats?['counted'] as int?) ?? total;
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
                  child: Text(l10n.redesignPersonOfTermine(attended, counted), style: RdType.meta(p, size: 14)),
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
              onPressed: () => context.push(RedesignRoutes.personHistory(personId)),
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

/// Pausieren / Wieder aktiv and Archivieren actions.
class _Actions extends ConsumerWidget {
  const _Actions({required this.person, this.onClose});

  final Person person;
  final VoidCallback? onClose;

  void _refresh(WidgetRef ref) {
    if (person.id != null) ref.invalidate(personProvider(person.id!));
    ref.invalidate(realtimePlayersProvider);
    ref.invalidate(playerAttendancePercentagesProvider);
    // Not realtime: an archived person must leave the lists that offer
    // "Fehlende Accounts anlegen" and show up in the Archiv right away.
    ref.invalidate(playersProvider);
    ref.invalidate(leftPlayersProvider);
    ref.invalidate(archivedPlayersProvider);
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
    final result = await showRdArchiveSheet(context, name: '${person.firstName} ${person.lastName}'.trim());
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
      if (onClose != null) return onClose!();
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
