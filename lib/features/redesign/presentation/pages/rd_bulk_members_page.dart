import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/providers/group_providers.dart';
import '../../../../core/providers/player_providers.dart';
import '../../../../core/providers/realtime_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/providers/user_registration_providers.dart';
import '../../../../core/router/redesign_routes.dart';
import '../../../../core/theme/redesign/rd_theme.dart';
import '../../../../core/utils/demo_guard.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/person/person.dart';
import '../../../../data/repositories/player_repository.dart';
import '../../../../l10n/l10n.dart';
import '../../../people/presentation/widgets/pause_person_sheet.dart' show buildPauseHistoryText;
import '../../../settings/presentation/pages/pending_players_page.dart' show showPendingPersonsSheet;
import '../../data/rd_members_logic.dart';
import '../widgets/manage/rd_manage_entries.dart' show rdManagePendingProvider;
import '../widgets/rd_widgets.dart';

/// Runs [change] for every person and counts successes and failures, so
/// one failing row does not stop the rest.
Future<({int ok, int failed})> rdApplyToAll(
  List<Person> persons,
  Future<void> Function(Person person) change,
) async {
  var ok = 0;
  var failed = 0;
  for (final person in persons) {
    try {
      await change(person);
      ok++;
    } catch (_) {
      failed++;
    }
  }
  return (ok: ok, failed: failed);
}

/// REDESIGN: Verwaltung › Mitglieder bearbeiten (canvas "VerwMitglieder"):
/// waiting approvals on top, then every active member by Register with a
/// selection circle; the bar at the bottom moves the selection to another
/// Register, pauses or archives it. Writes through [PlayerRepository] like
/// the single person page.
class RdBulkMembersPage extends ConsumerStatefulWidget {
  const RdBulkMembersPage({super.key});

  @override
  ConsumerState<RdBulkMembersPage> createState() => _RdBulkMembersPageState();
}

class _RdBulkMembersPageState extends ConsumerState<RdBulkMembersPage> {
  final _search = TextEditingController();
  final Set<int> _selected = {};
  String _query = '';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // A group switch empties the selection.
    ref.listenManual(currentTenantIdProvider, (previous, next) {
      if (previous != next && mounted) setState(_selected.clear);
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _toggle(int id) => setState(() => _selected.contains(id) ? _selected.remove(id) : _selected.add(id));

  void _toggleSection(List<Person> people) {
    final ids = people.map((p) => p.id).whereType<int>().toSet();
    setState(() => _selected.containsAll(ids) ? _selected.removeAll(ids) : _selected.addAll(ids));
  }

  List<Person> _selection(List<Person> people) =>
      people.where((p) => p.id != null && _selected.contains(p.id)).toList();

  /// Applies [change] to the selection and reports the result.
  /// [boundRepo]: a repository the caller read before its own awaits.
  Future<void> _run(
    List<Person> persons,
    Future<void> Function(PlayerRepository repo, Person p) change, {
    PlayerRepository? boundRepo,
  }) async {
    if (persons.isEmpty || DemoGuard.blocked()) return; // DEMO_GUARD
    final l10n = context.l10n;
    // Bound before the first await (tenant switch safety).
    final PlayerRepository repo = boundRepo ?? ref.read(playerRepositoryWithTenantProvider);
    // The list may still show the previous group's people after a group
    // switch; never touch a person outside the bound tenant.
    persons = persons.where((p) => p.tenantId == repo.currentTenantId).toList();
    if (persons.isEmpty) return;
    setState(() => _busy = true);
    final result = await rdApplyToAll(persons, (p) => change(repo, p));
    ref.invalidate(realtimePlayersProvider);
    ref.invalidate(playersProvider);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _selected.clear();
    });
    if (result.failed > 0) {
      ToastHelper.showError(context, l10n.redesignBulkFailed(result.failed));
    } else {
      ToastHelper.showSuccess(context, l10n.redesignBulkDone(result.ok));
    }
  }

  Future<void> _moveToGroup(List<Person> persons) async {
    final l10n = context.l10n;
    // Bound before the first await (tenant switch safety).
    final repo = ref.read(playerRepositoryWithTenantProvider);
    final registration = ref.read(userRegistrationRepositoryWithTenantProvider);
    final mainGroup = ref.read(mainGroupProvider.future);
    final groups = ref.read(groupsProvider).valueOrNull ?? const [];
    final groupId = await showModalBottomSheet<int>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.7),
          child: ListView(
            shrinkWrap: true,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(l10n.redesignBulkPickGroup, style: RdType.section(ctx.rd)),
              ),
              for (final g in groups)
                if (g.id != null)
                  ListTile(title: Text(g.name), onTap: () => Navigator.pop(ctx, g.id)),
            ],
          ),
        ),
      ),
    );
    if (groupId == null || !mounted) return;
    final names = {for (final g in groups) g.id: g.name};
    final mainId = (await mainGroup)?.id;
    if (!mounted) return;
    await _run(boundRepo: repo, persons.where((p) => p.instrument != groupId).toList(), (repo, p) async {
      // Ionic continueUpdatingPlayer: joining or leaving the main group
      // makes the account Verantwortlicher or Spieler (admins stay). Done
      // before the Register change: if it fails the person stays in the old
      // Register and a retry repeats both steps; if the Register change
      // fails, the old role is restored.
      final appId = p.appId;
      Role? previousRole;
      if (appId != null && mainId != null && (groupId == mainId || p.instrument == mainId)) {
        final role = await registration.getTenantUserRole(appId);
        final next = groupId == mainId ? Role.responsible : Role.player;
        if (role != null && role != Role.admin && role != next) {
          await registration.updateTenantUserRole(appId, next);
          previousRole = role;
        }
      }
      try {
        await _changeGroup(repo, p, groupId, names);
      } catch (_) {
        if (appId != null && previousRole != null) {
          try {
            await registration.updateTenantUserRole(appId, previousRole);
          } catch (_) {
            // The failure below is reported; a retry sets the role again.
          }
        }
        rethrow;
      }
    });
  }

  /// Same history entry as the person page (Instrumentenwechsel).
  static Future<void> _changeGroup(PlayerRepository repo, Person p, int groupId, Map<int?, String> names) =>
      repo.updatePlayerFields(p.id!, {
        'instrument': groupId,
        'history': [
          ...p.history.map((h) => h.toJson()),
          {
            'date': DateTime.now().toUtc().toIso8601String(),
            'text': '${names[p.instrument] ?? 'Unbekannt'} -> ${names[groupId] ?? 'Unbekannt'}',
            'type': PlayerHistoryType.instrumentChange.value,
          },
        ],
      });

  Future<void> _pause(List<Person> persons) async {
    final l10n = context.l10n;
    // Bound before the dialog (tenant switch safety).
    final repo = ref.read(playerRepositoryWithTenantProvider);
    // Already paused members keep their pause (no second entry).
    final targets = persons.where((p) => !p.paused).toList();
    if (targets.isEmpty) return;
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.redesignBulkActionPause),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: l10n.redesignBulkPauseReason),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.commonCancel)),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(l10n.redesignBulkActionPause),
          ),
        ],
      ),
    );
    controller.dispose();
    if (reason == null || reason.isEmpty) return;
    await _run(boundRepo: repo, targets, (repo, p) => repo.pausePlayer(p, null, buildPauseHistoryText(reason)));
  }

  Future<void> _archive(List<Person> persons) async {
    final l10n = context.l10n;
    // Bound before the dialog (tenant switch safety).
    final repo = ref.read(playerRepositoryWithTenantProvider);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.redesignBulkArchiveConfirm(persons.length)),
        content: Text(l10n.redesignBulkArchiveHint),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.commonCancel)),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.redesignBulkActionArchive),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final today = DateTime.now().toIso8601String();
    await _run(boundRepo: repo, persons, (repo, p) => repo.archivePlayer(p, today, null));
  }

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final peopleAsync = ref.watch(realtimePlayersProvider);
    final people = peopleAsync.valueOrNull ?? const <Person>[];
    final groups = ref.watch(groupsProvider).valueOrNull ?? const [];
    final pending = ref.watch(rdManagePendingProvider).length;
    final sections = rdMemberSections(
      people,
      groups: groups,
      percentages: const {},
      noGroupLabel: l10n.redesignBulkNoGroup,
    );
    final selection = _selection(people);

    final list = RdPage(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 140),
      children: [
        Row(
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: RdBackLink(
                  label: l10n.redesignAdminTitle,
                  onTap: () => context.canPop() ? context.pop() : context.go(RedesignRoutes.manage),
                ),
              ),
            ),
            if (_selected.isNotEmpty)
              RdTextLink(label: l10n.redesignBulkClear, onTap: () => setState(_selected.clear)),
          ],
        ),
        const SizedBox(height: 4),
        Semantics(header: true, child: Text(l10n.redesignBulkTitle, style: RdType.largeTitle(p))),
        const SizedBox(height: 4),
        Text(l10n.redesignBulkHint, style: RdType.meta(p)),
        if (pending > 0) ...[
          const SizedBox(height: 14),
          RdGroupedList(children: [
            RdListRow(
              leading: const RdRowIcon(Icons.how_to_reg_outlined),
              title: l10n.redesignManagePending(pending),
              onTap: () => showPendingPersonsSheet(context),
            ),
          ]),
        ],
        const SizedBox(height: 14),
        TextField(
          controller: _search,
          onChanged: (v) => setState(() => _query = v),
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: l10n.redesignBulkSearch,
            prefixIcon: Icon(Icons.search, color: p.text2),
            filled: true,
            fillColor: p.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(p.buttonRadius),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (peopleAsync.isLoading && people.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 48),
            child: Center(child: CircularProgressIndicator(color: p.primary)),
          ),
        for (final s in sections)
          if (s.people.any((x) => rdPersonMatches(x, _query, register: s.title))) ...[
            const SizedBox(height: 12),
            Builder(builder: (context) {
              final shown = s.people.where((x) => rdPersonMatches(x, _query, register: s.title)).toList();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(child: RdGroupLabel(s.title)),
                      RdTextLink(
                        label: l10n.redesignBulkSelectGroup(s.title),
                        onTap: () => _toggleSection(shown),
                      ),
                    ],
                  ),
                  RdGroupedList(
                    children: [
                      for (final person in shown)
                        if (person.id != null)
                          Semantics(
                            checked: _selected.contains(person.id),
                            child: RdListRow(
                              leading: Icon(
                                _selected.contains(person.id) ? Icons.check_circle : Icons.radio_button_unchecked,
                                color: _selected.contains(person.id) ? p.primary : p.text2,
                              ),
                              title: '${person.firstName} ${person.lastName}'.trim(),
                              subtitle: person.paused ? l10n.redesignBulkActionPause : null,
                              selected: _selected.contains(person.id),
                              showChevron: false,
                              onTap: () => _toggle(person.id!),
                            ),
                          ),
                    ],
                  ),
                ],
              );
            }),
          ],
      ],
    );

    return Stack(
      children: [
        list,
        if (selection.isNotEmpty)
          Positioned(
            left: 12,
            right: 12,
            bottom: 12 + MediaQuery.of(context).padding.bottom,
            child: _ActionBar(
              label: l10n.redesignBulkSelected(selection.length),
              busy: _busy,
              actions: [
                (Icons.swap_horiz, l10n.redesignBulkActionGroup, () => _moveToGroup(selection), false),
                (Icons.pause_circle_outline, l10n.redesignBulkActionPause, () => _pause(selection), false),
                (Icons.archive_outlined, l10n.redesignBulkActionArchive, () => _archive(selection), true),
              ],
            ),
          ),
      ],
    );
  }
}

/// Dark bar with the selection count and the actions for the selection.
class _ActionBar extends StatelessWidget {
  const _ActionBar({required this.label, required this.busy, required this.actions});

  final String label;
  final bool busy;
  final List<(IconData, String, VoidCallback, bool)> actions;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    return Material(
      color: p.text,
      borderRadius: BorderRadius.circular(16),
      elevation: 6,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 2),
              child: Semantics(
                liveRegion: true,
                child: Text(label, style: TextStyle(color: p.bg, fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            ),
            Row(
              children: [
                for (final (icon, text, onTap, danger) in actions)
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: busy ? null : onTap,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 56),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(height: 6),
                            Icon(icon, size: 22, color: danger ? p.absentSoft : p.bg),
                            const SizedBox(height: 3),
                            Text(
                              text,
                              style: TextStyle(fontSize: 12, color: danger ? p.absentSoft : p.bg),
                            ),
                            const SizedBox(height: 6),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
