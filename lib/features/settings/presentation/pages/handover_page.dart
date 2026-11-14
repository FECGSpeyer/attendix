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
import '../widgets/settings_list.dart';
import '../../../people/presentation/widgets/ion/ion_widgets.dart' show IonFabButton;
import '../../../../shared/widgets/layout/ion_form_items.dart';
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
  final _dateController = TextEditingController();

  @override
  void dispose() {
    _dateController.dispose();
    super.dispose();
  }

  void _goBack() => context.canPop() ? context.pop() : context.go('/settings');

  Future<void> _addFilter(BuildContext rowContext) async {
    final items = [
      if (!filters.contains('younger') && !filters.contains('older')) ...[
        AppPopoverMenuItem(value: 'younger', label: context.l10n.handoverYoungerThanDots),
        AppPopoverMenuItem(value: 'older', label: context.l10n.handoverOlderThanDots),
      ],
      if (!filters.contains('group'))
        AppPopoverMenuItem(value: 'group', label: context.l10n.handoverInGroupDots),
    ];
    if (items.isEmpty) return;
    // Ionic `ion-popover` with an `ion-list` (item lines) below the row.
    final f = await showAppPopoverMenu<String>(
      context: rowContext,
      lines: true,
      iosArrow: true,
      items: items,
    );
    if (f != null && mounted) setState(() => filters.add(f));
  }

  /// `ion-button fill="clear" slot="end"` with the trash icon.
  Widget _removeButton(VoidCallback onPressed) => IconButton(
        icon: Icon(AppIcons.deleteOutline, semanticLabel: context.l10n.commonDelete),
        color: AppColors.primary,
        onPressed: onPressed,
      );

  @override
  Widget build(BuildContext context) {
    final view = handoverView();
    final tenants = view.tenants;
    final groups = view.groups;
    final groupNames = view.groupNames;
    final filtered = view.filtered;
    final selectedPersons = view.selectedPersons;
    final playersLoading = view.loading;
    final canProceed = targetTenantId != null && selectedPersons.isNotEmpty;
    final l10n = context.l10n;
    _dateController.text = dateFormat.format(date);
    final dateFilter = filters.contains('younger') || filters.contains('older');

    // EIB-06: Ionic settings/handover – arrow-back button, condense title,
    // intro `ion-card` with the header icon, ONE inset list "Einstellungen"
    // (toggles with helper text, target select, filter item, active
    // filters), the person list as an inset list with "Alle auswählen" in
    // its header, the arrow FAB.
    return IonCondense(builder: (context, collapsed) => Scaffold(
      extendBodyBehindAppBar: ionIsIos(context),
      appBar: IonTranslucentAppBar(
        condensed: collapsed,
        child: AppBar(
          leading: IonArrowBackButton(onPressed: _goBack),
          leadingWidth: IonArrowBackButton.leadingWidth(context),
          title: IonCondenseTitle(l10n.handoverTitle, collapsed: collapsed),
        ),
      ),
      // Ionic `[disabled]` on the fab button: the same button at .5.
      floatingActionButton: TabBarFab.wrap(Opacity(
        opacity: canProceed ? 1 : 0.5,
        child: IonFabButton(
          icon: AppIcons.arrowForward,
          onPressed: canProceed
              ? () => openHandoverDetail(view, '/settings/handover/detail')
              : null,
        ),
      )),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          ionListMargin(context),
          ionIsIos(context) ? 0 : AppDimensions.paddingM,
          ionListMargin(context),
          scrollEndPadding(context, base: 16, fabRoom: 84),
        ),
        children: [
          const IonContentTopInset(),
          IonLargeTitle(l10n.handoverTitle, padding: const EdgeInsets.only(bottom: 4)),
          SettingsHintCard(icon: AppIcons.directionsWalk, text: l10n.handoverIntro),
          SettingsListSection(
            title: l10n.handoverSettings,
            icons: false,
            children: [
              IonToggleItem(
                title: l10n.handoverKeepInTenant,
                helper: l10n.handoverKeepHelper,
                value: stayInInstance,
                onChanged: (v) => setState(() => stayInInstance = v),
              ),
              IonToggleItem(
                title: l10n.handoverRespectMainGroup,
                helper: l10n.handoverMainGroupHelper,
                value: includeMainGroup,
                onChanged: (v) => setState(() => includeMainGroup = v),
              ),
              // `ion-select [label]` (alert interface, label at the start).
              IonSelectItem(
                lines: false,
                label: l10n.handoverTargetTenant,
                value: tenants.where((t) => t.id == targetTenantId).map((t) => t.longName).firstOrNull,
                onOpen: (anchor) async {
                  final picked = await showAppSelect<int>(
                    context: anchor,
                    interface: AppSelectInterface.alert,
                    header: l10n.handoverTargetTenant,
                    value: targetTenantId,
                    options: [
                      for (final t in tenants)
                        if (t.id != null) AppSelectOption(value: t.id!, label: t.longName),
                    ],
                  );
                  if (picked != null && mounted) setState(() => targetTenantId = picked.value);
                },
              ),
              // `ion-item button detail="false"`: label only.
              Builder(
                builder: (rowContext) => SettingsListTile(
                  title: l10n.handoverAddFilter,
                  detail: false,
                  onTap: () => _addFilter(rowContext),
                ),
              ),
              if (dateFilter)
                IonStackedInputItem(
                  lines: false,
                  label: filters.contains('younger') ? l10n.handoverYoungerThan : l10n.handoverOlderThan,
                  controller: _dateController,
                  readOnly: true,
                  onTap: pickDate,
                  end: _removeButton(() => setState(() {
                    filters.remove(filters.contains('younger') ? 'younger' : 'older');
                  })),
                ),
              if (filters.contains('group'))
                IonSelectItem(
                  lines: false,
                  stacked: true,
                  label: l10n.peopleGroup,
                  value: groups.where((g) => g.id == groupId).map((g) => g.name).firstOrNull,
                  onOpen: (anchor) async {
                    final picked = await showAppSelect<int>(
                      context: anchor,
                      interface: AppSelectInterface.alert,
                      header: l10n.peopleGroup,
                      value: groupId,
                      options: [
                        for (final g in groups)
                          if (g.id != null) AppSelectOption(value: g.id!, label: g.name),
                      ],
                    );
                    if (picked != null && mounted) setState(() => groupId = picked.value);
                  },
                  end: _removeButton(() => setState(() => filters.remove('group'))),
                ),
            ],
          ),
          if (playersLoading)
            const Center(child: AppSpinner())
          else if (filtered.isEmpty)
            IonCardBox(
              child: Padding(
                padding: const EdgeInsets.all(AppDimensions.paddingM),
                child: Text(l10n.handoverNoneSelected,
                    style: const TextStyle(color: AppColors.danger)),
              ),
            )
          else
            SettingsListSection(
              title: l10n.handoverPersonList,
              icons: false,
              // `ion-list-header` > `ion-button size="small" fill="clear"`.
              headerAction: IonButton(
                small: true,
                fill: IonButtonFill.clear,
                label: l10n.handoverSelectAll,
                onPressed: () => setState(() {
                  selected
                    ..clear()
                    ..addAll(filtered.where((p) => p.id != null).map((p) => p.id!));
                }),
              ),
              children: [
                for (final p in filtered)
                  // `ion-checkbox` with the label at the start and the box
                  // at the end (h2 name, p birthday | group).
                  CheckboxListTile(
                    controlAffinity: ListTileControlAffinity.trailing,
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
        ],
      ),
    ));
  }
}
