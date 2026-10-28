import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/supabase_config.dart';
import '../../../../core/constants/enums.dart';
import '../../../../core/providers/self_service_providers.dart';
import '../../../../core/providers/role_permission_providers.dart';
import '../../../../core/providers/signout_providers.dart';
import '../../../../core/providers/team_org_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/providers/user_preferences_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/event_list_utils.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/person/person.dart';
import '../../../../data/models/tenant/tenant.dart';
import '../../../../shared/widgets/event_list/event_list_widgets.dart';
import '../../../../shared/widgets/layout/ionic_ios.dart';
import '../../data/providers/upcoming_songs_provider.dart';
import '../widgets/plan_viewer_sheet.dart';
import '../widgets/self_service_event_actions.dart';
import '../widgets/upcoming_songs_sheet.dart';
import '../widgets/self_service_absences.dart';
import '../../../../core/providers/duty_providers.dart';
import '../../../../core/providers/player_absence_providers.dart';
import '../../../duty/presentation/widgets/duty_actions.dart';
import '../../../duty/presentation/widgets/self_service_duty_section.dart';
import '../../../../l10n/l10n.dart';
import '../../../messages/presentation/widgets/notification_bell.dart'; // MESSAGES
import '../../../team_organization/presentation/widgets/my_tasks_card.dart'; // INTEGRATION
import '../../../../core/utils/error_message.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart'; // IOS_LOOK

/// "Meine Termine" – self-service sign in/out of the current tenant
/// (Ionic `selfService/signout`).
///
/// Card layout: greeting, "Heute"/"Nächster Termin" card with the buttons
/// Zusagen / Verspätung / Absagen in one row and directly tappable chips,
/// upcoming Termine grouped by month and past Termine with summary.
class SignoutPage extends ConsumerStatefulWidget {
  const SignoutPage({super.key});

  @override
  ConsumerState<SignoutPage> createState() => _SignoutPageState();
}

class _SignoutPageState extends ConsumerState<SignoutPage> {
  bool _showAllPast = false;
  bool _showOtherTermine = false; // DUTY: "Weitere Termine" in the Dienstplan view

  SelfServiceEventActions _actions(Tenant? tenant, Person? player) {
    final notifier = ref.read(signoutNotifierProvider.notifier);
    final canAccessFiles = ref.read(canAccessFilesProvider);
    return SelfServiceEventActions(
      absenceReasons: EventListUtils.absenceReasonsOf(tenant?.absenceReasons),
      lateReasons: EventListUtils.lateReasonsOf(tenant?.lateReasons),
      showAllAttendances: tenant?.showAllAttendances ?? false,
      signIn: (att, note) async {
        // UX_SELF: "Zusagen" on a duty I was assigned to confirms it (Ionic signin).
        if (att.isDutyRequested && att.attendanceId != null) {
          await confirmDutyAction(context, ref, att.id!, att.attendanceId!);
          return true;
        }
        return notifier.signIn(att, notes: note);
      },
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

  /// INTEGRATION: opens the Termin of an /open-attendance deep link once the
  /// data is loaded (Ionic consumePendingAttendanceId).
  void _openPendingAttendance(SignoutData data, SelfServiceEventActions actions) {
    final pendingId = ref.read(pendingAttendanceIdProvider);
    if (pendingId == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || ref.read(pendingAttendanceIdProvider) != pendingId) return;
      ref.read(pendingAttendanceIdProvider.notifier).state = null;
      final att = [
        if (data.current != null) data.current!,
        ...data.upcoming,
        ...data.past,
      ].where((a) => a.attendanceId == pendingId).firstOrNull;
      if (att != null) actions.presentActions(context, att);
    });
  }

  Future<void> _refresh() async {
    ref.invalidate(signoutDataProvider);
    ref.invalidate(currentSelfServicePlayerProvider);
    ref.invalidate(upcomingSongsProvider);
    ref.invalidate(myTasksProvider); // INTEGRATION
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
      if (mounted) ToastHelper.showError(context, context.l10n.signoutFlutterSwitchTenantFailed);
    }
  }

  PreferredSizeWidget _buildAppBar(
    Tenant? tenant,
    List<Tenant> tenants, {
    Person? player,
    bool condensed = true,
  }) {
    final canSelfPause = ref.watch(canSelfPauseProvider);
    // UX_SONGS_SELF: Ionic shows the tenant switcher as a start button
    // (long name + chevron-down) and otherwise the short name as title.
    Widget? title;
    Widget? switcher;
    if (tenants.length > 1) {
      switcher = PopupMenuButton<Tenant>(
        tooltip: context.l10n.settingsSwitchTenant,
        onSelected: _switchTenant,
        itemBuilder: (_) => [
          for (final t in tenants)
            PopupMenuItem(
              value: t,
              child: Row(
                children: [
                  Expanded(child: Text(t.longName.isNotEmpty ? t.longName : t.shortName)),
                  if (t.id == tenant?.id)
                    EventPill(label: context.l10n.signoutCurrent, color: AppColors.primary),
                ],
              ),
            ),
        ],
        child: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  tenant?.longName.isNotEmpty == true ? tenant!.longName : (tenant?.shortName ?? ''),
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 17,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.keyboard_arrow_down, color: AppColors.primary, size: 20),
            ],
          ),
        ),
      );
    } else {
      title = CondenseTitle(
        condensed: condensed,
        child: Text(tenant?.shortName ?? context.l10n.tabsMyEvents),
      );
    }
    return AppBar(
      title: title,
      automaticallyImplyLeading: false,
      leading: switcher == null
          ? null
          : Align(alignment: Alignment.centerLeft, child: switcher),
      leadingWidth: switcher == null ? null : MediaQuery.sizeOf(context).width * 0.55,
      backgroundColor: condenseBarColor(context, condensed),
      shape: condenseBarShape(context, condensed),
      actions: [
        // UX_SELF: pause / unpause sit in the header like in Ionic
        if (canSelfPause && player != null && !player.paused)
          IconButton(
            icon: const Icon(Icons.pause_circle_outline),
            tooltip: context.l10n.signoutPause,
            onPressed: () => selfServicePause(context, ref, player),
          ),
        if (canSelfPause && player != null && player.paused)
          IconButton(
            icon: const Icon(Icons.play_circle_outline),
            tooltip: context.l10n.signoutEndPause,
            onPressed: () => selfServiceUnpause(context, ref, player),
          ),
        IconButton(
          icon: const Icon(Icons.info_outline),
          tooltip: context.l10n.signoutLegend,
          onPressed: () => showEventLegendSheet(context),
        ),
        const NotificationBell(), // MESSAGES
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
    final useDutyView =
        ref.watch(myDutyOverviewProvider).valueOrNull?.useDutyView ?? false; // DUTY

    if (isApplicant) {
      // Ionic: ion-card, content centered (global ion-card-content rule)
      return Scaffold(
        appBar: _buildAppBar(tenant, tenants),
        body: Align(
          alignment: Alignment.topCenter,
          child: Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (playerAsync.valueOrNull != null)
                    Text(
                      context.l10n.signoutGreeting(playerAsync.valueOrNull!.firstName),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w500),
                    ),
                  const SizedBox(height: 8),
                  Text(context.l10n.signoutRegistrationSubmitted, textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final player = playerAsync.valueOrNull;
    final actions = _actions(tenant, player);
    final loaded = dataAsync.valueOrNull;
    // PUSH: also react when a push tap sets the id while this page is open
    // (Ionic effect on pendingAttendanceId).
    ref.watch(pendingAttendanceIdProvider);
    if (loaded != null) _openPendingAttendance(loaded, actions);

    // Ionic: condensed large title (short name) when there is no switcher.
    return CondenseHeader(
      enabled: tenants.length <= 1 && player != null,
      builder: (context, condensed) => Scaffold(
      appBar: _buildAppBar(tenant, tenants, player: player, condensed: condensed),
      // IOS_ATT_PAGES: Ionic iOS page is white, rows sit directly on it
      backgroundColor: eventPageBackground(context),
      body: dataAsync.when(
        loading: () => const Center(child: AppSpinner()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.danger),
              const SizedBox(height: 8),
              Text(context.l10n.signoutFlutterError(friendlyErrorMessage(e)), textAlign: TextAlign.center),
              TextButton(onPressed: _refresh, child: Text(context.l10n.messagesRetry)),
            ],
          ),
        ),
        data: (data) => RefreshIndicator.adaptive(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              if (player != null)
                IonLargeTitle(tenant?.shortName ?? '', enabled: tenants.length <= 1),
              // UX_SELF: element order of the Ionic signout page
              if (player != null) _buildGreeting(player, data, useDutyView: useDutyView),
              if (player != null && useDutyView)
                const SelfServiceDutySection(part: SelfServiceDutyPart.stats),
              if (player != null && !useDutyView) ..._buildTiles(player),
              // DUTY: "Bitte bestätigen"
              if (player != null)
                const SelfServiceDutySection(part: SelfServiceDutyPart.requests),
              // INTEGRATION: "Meine Aufgaben" (Teamorganisation, Ionic app-my-tasks)
              if (player != null) const MyTasksCard(),
              // PEOPLE_IMPORT: "Geplante Abwesenheiten"
              if (player != null) const SelfServicePlannedAbsences(),
              if (player == null)
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    context.l10n.signoutFlutterNoPerson,
                    textAlign: TextAlign.center,
                  ),
                ),
              // DUTY: Dienstplan ("Bitte bestätigen", "Meine Dienste", "Offene Dienste");
              // in the Dienstplan view the other Termine are collapsed.
              if (player != null)
                SelfServiceDutySection(
                  part: SelfServiceDutyPart.dutyView,
                  showOtherTermine: _showOtherTermine,
                  otherTermineCount: data.upcoming.length + (data.current != null ? 1 : 0),
                  otherTermineNames: _otherTermineNames(data),
                  onToggleOtherTermine: () =>
                      setState(() => _showOtherTermine = !_showOtherTermine),
                  onReportAbsence: ref.watch(canSelfReportAbsenceProvider)
                      ? () => selfServiceReportAbsence(context, ref, player,
                          canSelfPause: ref.read(canSelfPauseProvider))
                      : null,
                ),
              if (!useDutyView || _showOtherTermine) ...[
                ..._buildCurrent(data, actions, tenant),
                ..._buildUpcoming(data, actions),
                ..._buildPast(data, actions),
              ],
              if (player != null &&
                  data.current == null &&
                  data.upcoming.isEmpty &&
                  data.past.isEmpty)
                Padding(
                  padding: EdgeInsets.all(32),
                  child: Text(
                    context.l10n.selfServiceNoEvents,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.medium),
                  ),
                ),
            ],
          ),
        ),
      ),
      ),
    );
  }

  /// Names of the other Termine for the collapsed "Weitere Termine" row.
  String _otherTermineNames(SignoutData data) {
    final names = <String>{
      for (final att in [if (data.current != null) data.current!, ...data.upcoming])
        att.eventTitle,
    };
    return names.take(3).join(', ');
  }

  /// Ionic `.greet`: 48px avatar, h1 1.35rem bold, meta line 14px medium.
  Widget _buildGreeting(Person player, SignoutData data, {bool useDutyView = false}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundImage: player.img != null && player.img!.isNotEmpty
                ? NetworkImage(player.img!)
                : null,
            child: player.img == null || player.img!.isEmpty
                ? Text(player.initials)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.signoutGreeting(player.firstName),
                  style: const TextStyle(fontSize: 21.6, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                DefaultTextStyle.merge(
                  style: const TextStyle(fontSize: 14),
                  child: Wrap(
                  spacing: 10,
                  runSpacing: 4,
                  children: [
                    if (player.paused)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.pause_circle_outline, size: 16, color: AppColors.warningDark),
                          SizedBox(width: 3),
                          Text(
                            context.l10n.signoutPaused,
                            style: const TextStyle(
                              color: AppColors.warningDark,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    if (useDutyView)
                      Text(context.l10n.signoutYourDutyRoster, style: const TextStyle(color: AppColors.medium))
                    else if (data.percentage > 0)
                      Text(
                        context.l10n.signoutAttendancePercent(data.percentage),
                        style: TextStyle(
                          color: EventListUtils.percentageColor(data.percentage),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    if (data.lateCount > 0)
                      Text(context.l10n.signoutLateCount(data.lateCount),
                          style: const TextStyle(color: AppColors.medium)),
                  ],
                ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Greet tiles: Aktuelle Werke / Abwesenheit melden / Offene Dienste.
  List<Widget> _buildTiles(Person player) {
    final songs = ref.watch(upcomingSongsProvider).valueOrNull ?? const [];
    final canPlannedAbsence = ref.watch(canSelfReportAbsenceProvider);
    final duty = ref.watch(myDutyOverviewProvider).valueOrNull;
    final inDutyCircle = duty?.inDutyCircle ?? false;
    final tiles = <Widget>[
      if (songs.isNotEmpty)
        _GreetTile(
          icon: Icons.music_note_outlined,
          title: context.l10n.signoutCurrentSongs,
          subtitle: songs.length == 1
              ? context.l10n.teamOrgNextEvent
              : context.l10n.signoutFlutterEventsCount(songs.length),
          onTap: () => showUpcomingSongsSheet(context),
        ),
      if (canPlannedAbsence)
        _GreetTile(
          icon: Icons.calendar_today_outlined,
          title: context.l10n.signoutAbsenceTileTitle,
          subtitle: context.l10n.signoutAbsenceTileSub,
          onTap: () => selfServiceReportAbsence(context, ref, player,
              canSelfPause: ref.read(canSelfPauseProvider)),
        ),
      if (inDutyCircle)
        _GreetTile(
          icon: Icons.headset_mic_outlined,
          title: context.l10n.signoutOpenDuties,
          subtitle: openDutiesTileSubtitle(duty!.openDuties.length),
          onTap: () => showOpenDutiesSheet(context),
        ),
    ];
    if (tiles.isEmpty) return const [];
    // Ionic: 2-column grid
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
        child: Column(
          children: [
            for (var i = 0; i < tiles.length; i += 2) ...[
              if (i > 0) const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: tiles[i]),
                  const SizedBox(width: 10),
                  Expanded(child: i + 1 < tiles.length ? tiles[i + 1] : const SizedBox.shrink()),
                ],
              ),
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
      EventMonthHeader(label: att.isRunning
          ? context.l10n.teamOrgTodayCap
          : context.l10n.teamOrgNextEvent),
      EventTodayCard(
        bordered: true,
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
      EventSectionHeader(title: context.l10n.signoutUpcoming, count: data.upcoming.length),
      for (final group in groups) ...[
        EventMonthHeader(label: group.label),
        EventListCard(
          iosPlain: true,
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
      EventSectionHeader(title: context.l10n.signoutPast, count: data.past.length),
      EventListCard(
        iosPlain: true,
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
                    tooltip: context.l10n.signoutOpenFiles,
                    onPressed: () => openFilesFolderRoute(context, att.filesFolder!),
                  ),
                EventPill.status(att.status, past: true),
              ],
            ),
          if (data.past.length > EventListUtils.pastPreviewCount)
            EventMoreLink(
              label: _showAllPast
                  ? context.l10n.signoutFlutterShowLess
                  : context.l10n.signoutFlutterShowAll(data.past.length),
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
        child: Container(
          constraints: const BoxConstraints(minHeight: 60),
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: AppColors.primaryDark, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    Text(subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.medium, fontSize: 12)),
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
