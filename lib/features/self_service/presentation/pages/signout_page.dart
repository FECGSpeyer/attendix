import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/supabase_config.dart';
import '../../../../core/constants/enums.dart';
import '../../../../core/providers/self_service_providers.dart';
import '../../../../core/providers/signout_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/providers/user_preferences_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/event_list_utils.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/person/person.dart';
import '../../../../data/models/tenant/tenant.dart';
import '../../../../shared/widgets/event_list/event_list_widgets.dart';
import '../../data/providers/upcoming_songs_provider.dart';
import '../widgets/plan_viewer_sheet.dart';
import '../widgets/self_service_event_actions.dart';
import '../widgets/upcoming_songs_sheet.dart';

/// "Meine Termine" – self-service sign in/out of the current tenant
/// (Ionic `selfService/signout`).
///
/// Card layout: greeting, "Heute"/"Nächster Termin" card with the buttons
/// Zusagen / Verspätung / Absagen in one row and directly tappable chips,
/// upcoming Termine grouped by month and past Termine with summary.
///
/// Hook points for other packages: [SignoutPage.extraTilesBuilder] (e.g.
/// Abwesenheit melden, Offene Dienste) and [SignoutPage.extraSectionsBuilder]
/// (geplante Abwesenheiten, Dienstplan).
class SignoutPage extends ConsumerStatefulWidget {
  const SignoutPage({super.key});

  /// Additional greeting tiles (player absences, duty roster, ...).
  static List<Widget> Function(BuildContext context, WidgetRef ref, Person player)?
      extraTilesBuilder;

  /// Additional sections shown above the Termine.
  static List<Widget> Function(BuildContext context, WidgetRef ref, Person player)?
      extraSectionsBuilder;

  @override
  ConsumerState<SignoutPage> createState() => _SignoutPageState();
}

class _SignoutPageState extends ConsumerState<SignoutPage> {
  bool _showAllPast = false;

  SelfServiceEventActions _actions(Tenant? tenant, Person? player) {
    final notifier = ref.read(signoutNotifierProvider.notifier);
    final canAccessFiles = ref.read(canAccessFilesProvider);
    return SelfServiceEventActions(
      absenceReasons: EventListUtils.absenceReasonsOf(tenant?.absenceReasons),
      lateReasons: EventListUtils.lateReasonsOf(tenant?.lateReasons),
      showAllAttendances: tenant?.showAllAttendances ?? false,
      signIn: (att, note) => notifier.signIn(att, notes: note),
      signOut: (att, reason, isLate) =>
          notifier.signOut([att.id!], reason, isLate: isLate),
      updateNote: (att, note) => notifier.updateNote(att.id!, note),
      saveRegistrationAnswers: (att, answers) =>
          notifier.saveRegistrationAnswers(att.id!, answers),
      openPlan: (att) => showPlanViewerSheet(
        context,
        attendance: att,
        playerInstrumentId: player?.instrument,
      ),
      canAccessFiles: (_) => canAccessFiles,
    );
  }

  Future<void> _refresh() async {
    ref.invalidate(signoutDataProvider);
    ref.invalidate(currentSelfServicePlayerProvider);
    ref.invalidate(upcomingSongsProvider);
    await ref.read(signoutDataProvider.future);
  }

  Future<void> _switchTenant(Tenant tenant) async {
    final current = ref.read(currentTenantProvider);
    if (current?.id == tenant.id || tenant.id == null) return;
    final supabase = ref.read(supabaseClientProvider);
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;
    try {
      final row = await supabase
          .from('tenantUsers')
          .select('role')
          .eq('tenantId', tenant.id!)
          .eq('userId', userId)
          .maybeSingle();
      final role = Role.fromValue(row?['role'] as int? ?? 99);
      await ref.read(currentTenantProvider.notifier).setTenantLocal(tenant);
      await ref.read(currentTenantUserProvider.future);
      if (!mounted) return;
      final prefs = ref.read(userPreferencesNotifierProvider.notifier);
      context.go(role.defaultRoute);
      prefs.updateCurrentTenantId(tenant.id!);
    } catch (e) {
      if (mounted) ToastHelper.showError(context, 'Instanz konnte nicht gewechselt werden');
    }
  }

  PreferredSizeWidget _buildAppBar(Tenant? tenant, List<Tenant> tenants) {
    final Widget title;
    if (tenants.length > 1) {
      title = PopupMenuButton<Tenant>(
        tooltip: 'Instanz wechseln',
        onSelected: _switchTenant,
        itemBuilder: (_) => [
          for (final t in tenants)
            PopupMenuItem(
              value: t,
              child: Row(
                children: [
                  Expanded(child: Text(t.longName.isNotEmpty ? t.longName : t.shortName)),
                  if (t.id == tenant?.id)
                    const EventPill(label: 'Aktuell', color: AppColors.primary),
                ],
              ),
            ),
        ],
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                tenant?.longName.isNotEmpty == true ? tenant!.longName : (tenant?.shortName ?? ''),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.expand_more),
          ],
        ),
      );
    } else {
      title = Text(tenant?.shortName ?? 'Meine Termine');
    }
    return AppBar(
      title: title,
      actions: [
        IconButton(
          icon: const Icon(Icons.info_outline),
          tooltip: 'Legende',
          onPressed: () => showEventLegendSheet(context),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final tenant = ref.watch(currentTenantProvider);
    final tenants = ref.watch(userTenantsProvider).valueOrNull ?? const <Tenant>[];
    final isApplicant = ref.watch(isApplicantProvider);
    final playerAsync = ref.watch(currentSelfServicePlayerProvider);
    final dataAsync = ref.watch(signoutDataProvider);
    ref.watch(canAccessFilesProvider);

    if (isApplicant) {
      return Scaffold(
        appBar: _buildAppBar(tenant, tenants),
        body: Card(
          margin: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (playerAsync.valueOrNull != null)
                  Text(
                    'Shalom ${playerAsync.valueOrNull!.firstName}!',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                const SizedBox(height: 8),
                const Text(
                  'Deine Registrierung wurde erfolgreich übermittelt. Du wirst benachrichtigt, sobald diese bearbeitet wurde.',
                ),
              ],
            ),
          ),
        ),
      );
    }

    final player = playerAsync.valueOrNull;
    final actions = _actions(tenant, player);

    return Scaffold(
      appBar: _buildAppBar(tenant, tenants),
      body: dataAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.danger),
              const SizedBox(height: 8),
              Text('Fehler: $e', textAlign: TextAlign.center),
              TextButton(onPressed: _refresh, child: const Text('Erneut versuchen')),
            ],
          ),
        ),
        data: (data) => RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              if (player != null) _buildGreeting(player, data),
              if (player != null) ..._buildTiles(player),
              if (player != null && SignoutPage.extraSectionsBuilder != null)
                ...SignoutPage.extraSectionsBuilder!(context, ref, player),
              if (player == null)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Text(
                    'Für dein Konto wurde in dieser Instanz keine Person gefunden.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ..._buildCurrent(data, actions, tenant),
              ..._buildUpcoming(data, actions),
              ..._buildPast(data, actions),
              if (player != null &&
                  data.current == null &&
                  data.upcoming.isEmpty &&
                  data.past.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Text(
                    'Keine Termine gefunden',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.medium),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGreeting(Person player, SignoutData data) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundImage: player.img != null && player.img!.isNotEmpty
                ? NetworkImage(player.img!)
                : null,
            child: player.img == null || player.img!.isEmpty
                ? Text(player.initials)
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Shalom ${player.firstName}!',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 10,
                  runSpacing: 4,
                  children: [
                    if (player.paused)
                      const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.pause_circle_outline, size: 16, color: AppColors.warningDark),
                          SizedBox(width: 2),
                          Text('Pausiert', style: TextStyle(color: AppColors.warningDark)),
                        ],
                      ),
                    if (data.percentage > 0)
                      Text(
                        '${data.percentage}% Anwesenheit',
                        style: TextStyle(
                          color: EventListUtils.percentageColor(data.percentage),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    if (data.lateCount > 0)
                      Text('${data.lateCount}× zu spät',
                          style: const TextStyle(color: AppColors.medium)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildTiles(Person player) {
    final songs = ref.watch(upcomingSongsProvider).valueOrNull ?? const [];
    final extra = SignoutPage.extraTilesBuilder?.call(context, ref, player) ?? const <Widget>[];
    final tiles = <Widget>[
      if (songs.isNotEmpty)
        _GreetTile(
          icon: Icons.music_note_outlined,
          title: 'Aktuelle Werke',
          subtitle: songs.length == 1 ? 'Nächster Termin' : '${songs.length} Termine',
          onTap: () => showUpcomingSongsSheet(context),
        ),
      ...extra,
    ];
    if (tiles.isEmpty) return const [];
    return [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(
          children: [
            for (var i = 0; i < tiles.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(child: tiles[i]),
            ],
          ],
        ),
      ),
    ];
  }

  List<Widget> _buildCurrent(SignoutData data, SelfServiceEventActions actions, Tenant? tenant) {
    final att = data.current;
    if (att == null) return const [];
    final own = actions.isOwn(att);
    final showAll = tenant?.showAllAttendances ?? false;
    final infoText = showAll && !att.isMember
        ? (tenant?.showAllAttendancesInfoText?.isNotEmpty == true
            ? tenant!.showAllAttendancesInfoText
            : EventListUtils.defaultShowAllInfoText)
        : null;
    final qa = actions.quickActions(att);
    return [
      EventMonthHeader(label: att.isRunning ? 'Heute' : 'Nächster Termin'),
      EventTodayCard(
        date: att.date,
        title: att.eventTitle,
        meta: att.eventMeta(withDate: true, withPlace: false),
        status: own ? EventPill.status(att.status) : null,
        place: att.place,
        infoText: infoText,
        dimmed: showAll && !att.isMember,
        chips: actions.chips(context, att),
        actions: actions.quickActionButtons(context, att),
        onMore: qa != null
            ? () => actions.presentActions(context, att, hideQuickActions: true)
            : null,
      ),
    ];
  }

  List<Widget> _buildUpcoming(SignoutData data, SelfServiceEventActions actions) {
    if (data.upcoming.isEmpty) return const [];
    final groups = EventListUtils.groupByMonth(data.upcoming, (a) => a.date);
    return [
      EventSectionHeader(title: 'Anstehend', count: data.upcoming.length),
      for (final group in groups) ...[
        EventMonthHeader(label: group.label),
        EventListCard(
          children: [
            for (final att in group.items)
              EventRow(
                date: att.date,
                title: att.eventTitle,
                subtitle: att.eventMeta(),
                highlight: att.highlight,
                dimmed: actions.showAllAttendances && !att.isMember,
                onTap: () => actions.presentActions(context, att),
                extra: [
                  if (actions.showAllAttendances && !att.isMember)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        ref.read(currentTenantProvider)?.showAllAttendancesInfoText?.isNotEmpty == true
                            ? ref.read(currentTenantProvider)!.showAllAttendancesInfoText!
                            : EventListUtils.defaultShowAllInfoText,
                        style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 12, color: AppColors.medium),
                      ),
                    ),
                  EventChips(chips: actions.chips(context, att)),
                ],
                trailing: [
                  if (actions.isOwn(att)) EventPill.status(att.status),
                ],
              ),
          ],
        ),
      ],
    ];
  }

  List<Widget> _buildPast(SignoutData data, SelfServiceEventActions actions) {
    if (data.past.isEmpty) return const [];
    final preview = _showAllPast
        ? data.past
        : data.past.take(EventListUtils.pastPreviewCount).toList();
    return [
      EventSectionHeader(title: 'Vergangen', count: data.past.length),
      EventListCard(
        children: [
          EventSummary(
            percentage: data.percentage,
            lateCount: data.lateCount,
            dots: data.past.take(12).map((a) => a.status).toList(),
          ),
          for (final att in preview)
            EventRow(
              date: att.date,
              title: att.eventTitle,
              subtitle: att.readableDate,
              past: true,
              highlight: att.highlight,
              onTap: att.isExcusedStatus ? () => actions.presentActions(context, att) : null,
              trailing: [
                if (actions.hasFilesFolder(att))
                  IconButton(
                    icon: const Icon(Icons.folder_open_outlined),
                    tooltip: 'Dateiablage öffnen',
                    onPressed: () => openFilesFolderRoute(context, att.filesFolder!),
                  ),
                EventPill.status(att.status, past: true),
              ],
            ),
          if (data.past.length > EventListUtils.pastPreviewCount)
            EventMoreLink(
              label: _showAllPast ? 'Weniger anzeigen' : 'Alle ${data.past.length} anzeigen',
              onTap: () => setState(() => _showAllPast = !_showAllPast),
            ),
        ],
      ),
    ];
  }
}

class _GreetTile extends StatelessWidget {
  const _GreetTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                child: Icon(icon, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text(subtitle, style: const TextStyle(color: AppColors.medium, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
