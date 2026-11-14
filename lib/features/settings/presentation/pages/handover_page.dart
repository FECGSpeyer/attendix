import 'package:flutter/material.dart';
import 'package:attendix/core/theme/app_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/group_providers.dart';
import '../../../../core/providers/organisation_providers.dart';
import '../../../../core/providers/player_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/instrument/instrument.dart';
import '../../../../data/models/person/person.dart';
import '../../../../data/models/tenant/tenant.dart';
import '../../../../l10n/l10n.dart';
import '../../../people/people_list_utils.dart';
import '../widgets/ion_condense.dart';
import '../widgets/settings_list.dart' show ionIsIos;
import 'package:attendix/shared/widgets/layout/ionic_ios.dart' show IonTranslucentAppBar, IonContentTopInset;
import '../../../../shared/widgets/adaptive/adaptive.dart';
import 'package:attendix/shared/widgets/layout/ios_tab_bar.dart';

/// Data handed from the handover page to the detail page
/// (Ionic: DataService.setHandoverData).
class HandoverData {
  const HandoverData({
    required this.persons,
    required this.tenant,
    required this.stayInInstance,
    this.sourceTenantId,
  });

  final List<Person> persons;
  final Tenant tenant;
  final bool stayInInstance;

  /// Group the people were picked in. The transfer only runs while it is
  /// still the current group.
  final int? sourceTenantId;
}

/// Personenübergabe – step 1: choose target tenant, filter and select persons
/// (Ionic settings/handover).
class HandoverPage extends ConsumerStatefulWidget {
  const HandoverPage({super.key});

  @override
  ConsumerState<HandoverPage> createState() => _HandoverPageState();
}

/// What step 1 shows: target groups, the filtered people and the ticked
/// ones (shared by the old page and the Beta page).
typedef HandoverView = ({
  List<Tenant> tenants,
  List<Group> groups,
  Map<int?, String> groupNames,
  List<Person> filtered,
  List<Person> selectedPersons,
  bool loading,
});

/// State and rules of step 1 (Ionic settings/handover), shared by the old
/// page and the Beta page (`RdHandoverPage`).
mixin HandoverSelectionLogic<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  bool stayInInstance = false;
  bool includeMainGroup = false;
  int? targetTenantId;
  final Set<int> selected = {};
  final List<String> filters = [];
  DateTime date = DateTime.now();
  int? groupId;
  bool _noTenantsToastShown = false;
  bool _playersErrorToastShown = false;
  int? _viewTenantId;

  DateFormat get dateFormat => DateFormat(dateFmt());

  List<Person> filteredPeople(List<Person> all, int? mainGroupId) {
    var list = includeMainGroup
        ? all
        : all.where((p) => p.instrument != mainGroupId).toList();

    DateTime? birthday(Person p) =>
        p.birthday == null ? null : DateTime.tryParse(p.birthday!);

    if (filters.contains('older')) {
      list = list.where((p) {
        final b = birthday(p);
        return b != null && date.isAfter(b);
      }).toList();
    }
    if (filters.contains('younger')) {
      list = list.where((p) {
        final b = birthday(p);
        return b != null && date.isBefore(b);
      }).toList();
    }
    if (filters.contains('group') && groupId != null) {
      list = list.where((p) => p.instrument == groupId).toList();
    }
    return list;
  }

  Future<void> pickDate() async {
    final now = DateTime.now();
    final picked = await showAppDatePicker(
      context: context,
      initialDate: date.isAfter(now) ? now : date,
      firstDate: DateTime(1900),
      lastDate: now,
      locale: Locale(currentLanguage()),
      // Ionic: `ion-modal.dateModal`, `show-adjacent-days`.
      overlay: IonDatetimeOverlay.dateModal,
      showAdjacentDays: true,
    );
    if (picked != null) setState(() => date = picked);
  }

  /// Watches the data of step 1 and applies the Ionic defaults and toasts.
  HandoverView handoverView() {
    // A group switch starts over: target, filters and ticks belonged to the
    // previous group.
    final tenantId = ref.watch(currentTenantIdProvider);
    if (tenantId != _viewTenantId) {
      _viewTenantId = tenantId;
      targetTenantId = null;
      groupId = null;
      selected.clear();
      filters.clear();
      _noTenantsToastShown = false;
    }
    final playersAsync = ref.watch(playersProvider);
    final groups = ref.watch(groupsProvider).valueOrNull ?? const <Group>[];
    final mainGroupId = ref.watch(mainGroupProvider).valueOrNull?.id;
    final tenantsAsync = ref.watch(linkedTenantsProvider);
    final tenants = tenantsAsync.valueOrNull ?? const <Tenant>[];

    // Default target = first tenant of the organisation (Ionic)
    if (targetTenantId == null && tenants.isNotEmpty) {
      targetTenantId = tenants.first.id;
    }
    if (tenantsAsync.hasValue && tenants.isEmpty && !_noTenantsToastShown) {
      _noTenantsToastShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ToastHelper.showError(
            context,
            context.l10n.handoverNoOtherTenants,
          );
        }
      });
    }
    // Ionic db.getPlayers(): toast when the persons can't be loaded (the
    // list stays empty).
    if (!playersAsync.hasError) {
      _playersErrorToastShown = false;
    } else if (!playersAsync.isLoading && !_playersErrorToastShown) {
      _playersErrorToastShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ToastHelper.showError(context, context.l10n.dbLoadPeopleFailed);
        }
      });
    }
    groupId ??= groups.isNotEmpty ? groups.first.id : null;

    final groupNames = {for (final g in groups) g.id: g.name};
    // Ionic Utils.getModifiedPlayersForList order: main group first, group
    // sort_order, group name, person sort_order, last name.
    final filtered = filteredPeople(
      sortPeopleByGroup((playersAsync.isReloading ? null : playersAsync.valueOrNull) ?? const [], groups),
      mainGroupId,
    );
    final selectedPersons =
        filtered.where((p) => p.id != null && selected.contains(p.id)).toList();
    return (
      tenants: tenants,
      groups: groups,
      groupNames: groupNames,
      filtered: filtered,
      selectedPersons: selectedPersons,
      loading: playersAsync.isLoading,
    );
  }

  /// Opens step 2 with the ticked people.
  void openHandoverDetail(HandoverView view, String route) {
    final tenant = view.tenants.firstWhere((t) => t.id == targetTenantId);
    context.push(
      route,
      extra: HandoverData(
        persons: view.selectedPersons
            .map((p) => p.copyWith(groupName: p.groupName ?? view.groupNames[p.instrument]))
            .toList(),
        tenant: tenant,
        stayInInstance: stayInInstance,
        sourceTenantId: _viewTenantId,
      ),
    );
  }
}

class _HandoverPageState extends ConsumerState<HandoverPage> with HandoverSelectionLogic {
  @override
  Widget build(BuildContext context) {
    final view = handoverView();
    final tenants = view.tenants;
    final groups = view.groups;
    final groupNames = view.groupNames;
    final filtered = view.filtered;
    final selectedPersons = view.selectedPersons;
    final playersLoading = view.loading;

    // IOS_R6: Ionic `ion-header collapse="condense"` (large title on iOS)
    return IonCondense(builder: (context, collapsed) => Scaffold(
      // IOS_R6: Ionic `ion-content fullscreen` under the translucent header
      extendBodyBehindAppBar: ionIsIos(context),
      // IOS_R6: `ion-header translucent` + `collapse="condense"`
      appBar: IonTranslucentAppBar(condensed: collapsed, child: AppBar(title: IonCondenseTitle(context.l10n.handoverTitle, collapsed: collapsed))),
      floatingActionButton: TabBarFab.wrap(FloatingActionButton(
        onPressed: targetTenantId == null || selectedPersons.isEmpty
            ? null
            : () => openHandoverDetail(view, '/settings/handover/detail'),
        backgroundColor: targetTenantId == null || selectedPersons.isEmpty
            ? AppColors.medium
            : null,
        child: Icon(AppIcons.arrowForward),
      )),
      body: ListView(
        padding: EdgeInsets.fromLTRB(AppDimensions.paddingM, ionIsIos(context) ? 0 : AppDimensions.paddingM, AppDimensions.paddingM, scrollEndPadding(context, base: 16, fabRoom: 84)), // IOS_R6: large title on top
        children: [
          const IonContentTopInset(),
          IonLargeTitle(context.l10n.handoverTitle, padding: const EdgeInsets.only(bottom: 4)),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.paddingM),
              child: Column(
                children: [
                  Icon(AppIcons.directionsWalk, size: 48, color: AppColors.primary),
                  const SizedBox(height: AppDimensions.paddingS),
                  Text(
                    context.l10n.handoverIntro,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppDimensions.paddingM),
          Text(context.l10n.handoverSettings, style: Theme.of(context).textTheme.titleSmall),
          Card(
            child: Column(
              children: [
                SwitchListTile.adaptive(
                  title: Text(context.l10n.handoverKeepInTenant),
                  subtitle: Text(context.l10n.handoverKeepHelper),
                  value: stayInInstance,
                  onChanged: (v) => setState(() => stayInInstance = v),
                ),
                SwitchListTile.adaptive(
                  title: Text(context.l10n.handoverRespectMainGroup),
                  subtitle: Text(context.l10n.handoverMainGroupHelper),
                  value: includeMainGroup,
                  onChanged: (v) => setState(() => includeMainGroup = v),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.paddingM,
                    vertical: AppDimensions.paddingS,
                  ),
                  child: AppDropdownFormField<int>(
                    interface: AppSelectInterface.alert,
                    // ignore: deprecated_member_use
                    value: targetTenantId,
                    isExpanded: true,
                    decoration: InputDecoration(labelText: context.l10n.handoverTargetTenant),
                    items: [
                      for (final t in tenants)
                        if (t.id != null)
                          DropdownMenuItem(value: t.id, child: Text(t.longName)),
                    ],
                    onChanged: (v) => setState(() => targetTenantId = v),
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (f) => setState(() => filters.add(f)),
                  itemBuilder: (context) => [
                    if (!filters.contains('younger') && !filters.contains('older')) ...[
                      PopupMenuItem(value: 'younger', child: Text(context.l10n.handoverYoungerThanDots)),
                      PopupMenuItem(value: 'older', child: Text(context.l10n.handoverOlderThanDots)),
                    ],
                    if (!filters.contains('group'))
                      PopupMenuItem(value: 'group', child: Text(context.l10n.handoverInGroupDots)),
                  ],
                  child: ListTile(
                    leading: Icon(AppIcons.filterList),
                    title: Text(context.l10n.handoverAddFilter),
                  ),
                ),
                if (filters.contains('younger') || filters.contains('older'))
                  ListTile(
                    title: Text(filters.contains('younger') ? context.l10n.handoverYoungerThan : context.l10n.handoverOlderThan),
                    subtitle: Text(dateFormat.format(date)),
                    onTap: pickDate,
                    trailing: IconButton(
                      icon: Icon(AppIcons.deleteOutline, semanticLabel: context.l10n.commonDelete),
                      onPressed: () => setState(() {
                        filters.remove(filters.contains('younger') ? 'younger' : 'older');
                      }),
                    ),
                  ),
                if (filters.contains('group'))
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingM),
                    child: Row(
                      children: [
                        Expanded(
                          child: AppDropdownFormField<int>(
                            interface: AppSelectInterface.alert,
                            // ignore: deprecated_member_use
                            value: groupId,
                            isExpanded: true,
                            decoration: InputDecoration(labelText: context.l10n.peopleGroup),
                            items: [
                              for (final g in groups)
                                if (g.id != null)
                                  DropdownMenuItem(value: g.id, child: Text(g.name)),
                            ],
                            onChanged: (v) => setState(() => groupId = v),
                          ),
                        ),
                        IconButton(
                          icon: Icon(AppIcons.deleteOutline, semanticLabel: context.l10n.commonDelete),
                          onPressed: () => setState(() => filters.remove('group')),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppDimensions.paddingM),
          if (playersLoading)
            const Center(child: AppSpinner())
          else if (filtered.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppDimensions.paddingM),
                child: Text(context.l10n.handoverNoneSelected,
                    style: const TextStyle(color: AppColors.danger)),
              ),
            )
          else ...[
            Row(
              children: [
                Expanded(
                  child: Text(context.l10n.handoverPersonList,
                      style: Theme.of(context).textTheme.titleSmall),
                ),
                TextButton(
                  onPressed: () => setState(() {
                    selected
                      ..clear()
                      ..addAll(filtered.where((p) => p.id != null).map((p) => p.id!));
                  }),
                  child: IonButtonLabel(context.l10n.handoverSelectAll),
                ),
              ],
            ),
            Card(
              child: Column(
                children: [
                  for (final p in filtered)
                    CheckboxListTile(
                      value: selected.contains(p.id),
                      onChanged: p.id == null
                          ? null
                          : (v) => setState(() {
                                if (v == true) {
                                  selected.add(p.id!);
                                } else {
                                  selected.remove(p.id);
                                }
                              }),
                      title: Text('${p.firstName} ${p.lastName}'),
                      subtitle: Text([
                        if (p.birthday != null && DateTime.tryParse(p.birthday!) != null)
                          dateFormat.format(DateTime.parse(p.birthday!)),
                        p.groupName ?? groupNames[p.instrument] ?? '',
                      ].join(' | ')),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    ));
  }
}
