import 'package:flutter/cupertino.dart';
import 'package:attendix/core/theme/app_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/utils/people_sort.dart';
import '../../../../core/config/supabase_config.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/attendance_rate_filter_providers.dart';
import '../../../../core/providers/attendance_type_providers.dart';
import '../../rate_filter_labels.dart';
import '../../../../core/providers/group_providers.dart';
import '../../../../core/providers/player_providers.dart';
import '../../../../core/providers/realtime_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/providers/profile_providers.dart';
import '../../../../data/repositories/shared_person_fields.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/redesign/rd_theme.dart' show RdSkinContext;
import '../../../../core/utils/demo_guard.dart' show DemoModeException;
import '../../../../core/utils/dialog_helper.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../core/providers/organisation_providers.dart';
import '../../../../core/providers/cross_tenant_person_providers.dart';
import '../../../../core/providers/church_providers.dart';
import '../../../../core/providers/teacher_providers.dart';
import '../../../../data/models/person/person.dart';
import '../../../../data/models/tenant/tenant.dart';
import '../../../../shared/widgets/tenant/tenant_switcher_title.dart';
import '../../people_list_utils.dart';
import '../../../../shared/widgets/loading/loading.dart';
import '../../../../shared/widgets/common/empty_state.dart';
import '../../../../shared/widgets/sheets/church_overview_sheet.dart';
import '../widgets/archive_person_modal.dart';
import '../widgets/handover_sheet.dart';
import '../../../../core/utils/haptic_helper.dart';
import '../widgets/pause_person_sheet.dart';
import '../widgets/person_modal.dart';
import '../widgets/ion/ion_widgets.dart';
import '../../../messages/presentation/widgets/notification_bell.dart';
import 'bulk_edit_page.dart';
import 'person_import_page.dart';
import '../../../../l10n/l10n.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';
import '../../../../shared/widgets/layout/ios_tab_bar.dart';
import '../../../../shared/widgets/layout/side_nav/side_nav_layout.dart';
import '../../../../core/utils/helper_member.dart';

/// People list page
class PeopleListPage extends ConsumerStatefulWidget {
  const PeopleListPage({super.key});

  @override
  ConsumerState<PeopleListPage> createState() => _PeopleListPageState();
}

class _PeopleListPageState extends ConsumerState<PeopleListPage> {
  String _searchQuery = '';
  final _searchController = TextEditingController();
  String _filterOption = 'all';
  String _sortOption = 'group';

  /// Value for extra-field filters (filter option `extra:<fieldId>`)
  String? _extraFilterValue;

  /// "Mitglied anderer Instanz": user ids of the chosen linked tenant
  Set<String>? _otherInstanceUserIds;
  String? _otherInstanceName;

  /// "Reihenfolge anpassen" (Ionic toggleReorderMode)
  bool _isReordering = false;
  bool _isSavingOrder = false;

  /// Working order while reordering: group key → player ids
  final Map<String, List<int>> _reorderIds = {};

  /// Groups whose order was changed (Ionic handleReorder sets sort_order
  /// 1..n only for the moved group; untouched groups keep their order).
  final Set<String> _reorderedGroups = {};

  // Selection mode state
  bool _isSelectionMode = false;
  final Set<int> _selectedPlayerIds = {};

  // View options (Ionic list.page viewOpts)
  Set<String> _viewOptions = Set.of(_defaultViewOptions);

  static const _defaultViewOptions = {
    'group',
    'leader',
    'attendance',
    'critical',
    'paused',
  };

  /// Marker: saved options already know the 'attendance' option
  static const _viewOptionsVersionMarker = '__v2';

  /// Labels of the selectable view options for the current tenant
  /// (order and conditions as in Ionic list.page.html).
  Map<String, String> _viewOptionLabels(Tenant? tenant) {
    final isVoS = _isVoS(tenant);
    final isChoir = tenant?.type == 'choir';
    final isGeneral = tenant?.type == 'general';
    return {
      'group': context.l10n.peopleGroup,
      'attendance': context.l10n.peopleAttendance,
      'birthday': context.l10n.peopleBirthday,
      if (isChoir) 'instruments': context.l10n.peopleInstruments,
      if (isVoS) 'test': context.l10n.peopleTestResult,
      'exercises': context.l10n.peopleOtherDuties,
      if (!isGeneral) 'leader': context.l10n.peopleVoiceLeader,
      'critical': context.l10n.peopleProblemCases,
      if (isVoS) 'new': context.l10n.peopleNew,
      'paused': context.l10n.peoplePaused,
      'notes': context.l10n.peopleNotes,
      'photo': context.l10n.peoplePassportPhoto,
      if (tenant?.maintainTeachers ?? false) 'teacher': context.l10n.peopleTeacher,
      if (isVoS) 'examinee': context.l10n.peopleCandidate,
      for (final f in ref.read(personListExtraFieldsProvider))
        if (const ['boolean', 'text', 'select', 'bfecg_church', 'number']
            .contains(f.type))
          'extra:${f.id}': f.name,
    };
  }

  @override
  void initState() {
    super.initState();
    _loadViewOptions();
    // DB_REVIEW_REST (F3): Ionic list.page – admins/responsibles lift
    // expired pauses (paused_until reached) when opening the list (no cron).
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkAndUnpause());
  }

  Future<void> _checkAndUnpause() async {
    if (!mounted) return;
    final role = ref.read(currentRoleProvider);
    if (!(role.isAdmin || role.isResponsible)) return;
    final repo = ref.read(playerRepositoryWithTenantProvider);
    if (!repo.hasTenantId) return;
    try {
      await repo.checkAndUnpausePlayers();
      await repo.archiveExpiredHelpers();
    } on DemoModeException {
      // Demo account: the guard already showed the demo hint; load anyway.
    }
    if (mounted) ref.invalidate(realtimePlayersProvider);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadViewOptions() async {
    final tenant = ref.read(currentTenantProvider);
    if (tenant == null) return;
    final prefs = await SharedPreferences.getInstance();
    // A tenant switch during the awaits must not apply A's options to B.
    if (!_stillTenant(tenant.id)) return;
    final saved = prefs.getStringList('viewOpts_${tenant.id}');
    final savedSort = prefs.getString('sortOpt_${tenant.id}');
    if (savedSort != null && mounted) setState(() => _sortOption = savedSort);
    // Ionic: filterOpt<tenantId> + filterOptAdd<tenantId> are remembered
    final savedFilter = prefs.getString('filterOpt_${tenant.id}');
    final savedFilterAdd = prefs.getString('filterOptAdd_${tenant.id}');
    if (savedFilter != null && savedFilter != 'all' && mounted) {
      if (savedFilter == 'otherInstance') {
        await _restoreOtherInstanceFilter(savedFilterAdd, tenant.id);
        if (!_stillTenant(tenant.id)) return;
      } else if (savedFilter.startsWith('extra:')) {
        if (savedFilterAdd != null && savedFilterAdd.isNotEmpty) {
          setState(() {
            _filterOption = savedFilter;
            _extraFilterValue = savedFilterAdd;
          });
        }
      } else {
        setState(() => _filterOption = savedFilter);
      }
    }
    if (saved != null && mounted) {
      final opts = saved.toSet();
      // Attendance used to be always visible: keep it for old saved options
      if (!opts.contains(_viewOptionsVersionMarker)) opts.add('attendance');
      opts.remove(_viewOptionsVersionMarker);
      setState(() => _viewOptions = opts);
    }
  }

  /// Whether the page is still mounted for the tenant [tenantId] that an
  /// async restore started in.
  bool _stillTenant(int? tenantId) =>
      mounted && ref.read(currentTenantProvider)?.id == tenantId;

  Future<void> _saveViewOptions() async {
    final tenant = ref.read(currentTenantProvider);
    if (tenant == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('viewOpts_${tenant.id}',
        [..._viewOptions, _viewOptionsVersionMarker]);
  }

  /// Ionic onFilterChanged: storage `filterOpt<tenantId>` and
  /// `filterOptAdd<tenantId>` (value of extra-field / instance filters).
  Future<void> _saveFilterOption() async {
    final tenant = ref.read(currentTenantProvider);
    if (tenant == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('filterOpt_${tenant.id}', _filterOption);
      await prefs.setString(
        'filterOptAdd_${tenant.id}',
        _filterOption == 'otherInstance'
            ? (_otherInstanceName ?? '')
            : (_extraFilterValue ?? ''),
      );
    } catch (_) {
      // Preferences are a convenience only
    }
  }

  /// Re-applies a remembered "Mitglied anderer Instanz" filter (Ionic
  /// onFilterChanged(implicit) with the stored instance name).
  Future<void> _restoreOtherInstanceFilter(String? name, int? tenantId) async {
    if (name == null || name.isEmpty) return;
    // Read the tenant-bound repository before the first await.
    final crossTenantPersonRepo =
        ref.read(crossTenantPersonRepositoryWithTenantProvider);
    try {
      final linked = await ref.read(allLinkedTenantsProvider.future);
      final tenant = linked
          .where((t) => t.longName == name || t.shortName == name)
          .firstOrNull;
      if (tenant?.id == null) return;
      final linkedIds = await ref.read(linkedTenantIdsProvider.future);
      final ids = await crossTenantPersonRepo
          .getUserIdsInTenant(tenant!.id!, linkedTenantIds: linkedIds);
      if (!_stillTenant(tenantId)) return;
      setState(() {
        _filterOption = 'otherInstance';
        _otherInstanceUserIds = ids;
        _otherInstanceName = name;
      });
    } catch (_) {
      // Keep "Alle anzeigen"; Ionic shows the service toast here too.
      if (mounted) ToastHelper.showError(context, context.l10n.svcLoadUsersFailed);
    }
  }

  Future<void> _saveSortOption() async {
    final tenant = ref.read(currentTenantProvider);
    if (tenant == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('sortOpt_${tenant.id}', _sortOption);
    } catch (_) {
      // Preferences are a convenience only
    }
  }

  List<Person> _filterPeople(List<Person> people) {
    var filtered = people;

    // Apply filter
    switch (_filterOption) {
      case 'critical':
        filtered = filtered.where((p) => p.isCritical && !isHelperMember(p)).toList();
        break;
      case 'paused':
        filtered = filtered.where((p) => p.paused).toList();
        break;
      case 'leaders':
        filtered = filtered.where((p) => p.isLeader).toList();
        break;
      case 'active':
        filtered = filtered.where((p) => !p.paused).toList();
        break;
      case 'noAccount':
        filtered = filtered.where((p) => p.appId == null).toList();
        break;
      case 'examinees':
        filtered = filtered.where((p) => p.examinee).toList();
        break;
      case 'noTeacher':
        filtered = filtered.where((p) => !p.hasTeacher).toList();
        break;
      case 'noTest':
        filtered = filtered.where((p) =>
            p.testResult == null || p.testResult!.isEmpty).toList();
        break;
      case 'new':
        filtered = filtered.where(isNewPerson).toList();
        break;
      case 'otherInstance':
        final ids = _otherInstanceUserIds;
        if (ids != null) {
          filtered = filtered
              .where((p) => p.appId != null && ids.contains(p.appId))
              .toList();
        }
        break;
    }

    final extraFields = ref.read(personListExtraFieldsProvider);

    // Extra field filter (Ionic: select / boolean / number / bfecg_church)
    if (_filterOption.startsWith('extra:') && _extraFilterValue != null) {
      final fieldId = _filterOption.substring(6);
      final field = extraFields.where((f) => f.id == fieldId).firstOrNull;
      if (field != null) {
        filtered = filtered.where((p) {
          final raw = p.additionalFields?[fieldId] ??
              (field.type == 'boolean' ? (field.defaultValue ?? true) : null);
          return raw?.toString() == _extraFilterValue;
        }).toList();
      }
    }

    // Apply search (names, group and text/number extra fields)
    if (_searchQuery.isNotEmpty) {
      filtered = searchPeople(filtered, _searchQuery, extraFields: extraFields);
    }

    return filtered;
  }

  /// Ionic list players: shared organisation values hydrated, then
  /// getModifiedPlayersForList fills missing extra field values with their
  /// defaults (getPersonExtraFields, first church).
  List<Person> _listPeople() {
    final raw = ref.read(realtimePlayersProvider).valueOrNull ?? const <Person>[];
    return _withDefaults(mergeSharedPersonFieldValues(
        raw, ref.read(sharedPersonFieldValuesProvider).valueOrNull ?? const {}));
  }

  List<Person> _withDefaults(List<Person> people) {
    final fields = ref.read(personListExtraFieldsProvider);
    final hasChurch = fields.any((f) => f.type == 'bfecg_church');
    return withExtraFieldDefaults(
      people,
      fields,
      churchIds: hasChurch
          ? [
              for (final c in ref.read(churchesProvider).valueOrNull ?? const [])
                if (c.id != null) c.id!,
            ]
          : const [],
    );
  }

  List<Person> _sortPeople(List<Person> people) {
    final sorted = List<Person>.from(people);

    switch (_sortOption) {
      case 'firstName':
        // LOGIC_PEOPLE: Ionic localeCompare (case/umlaut aware)
        sorted.sort((a, b) => localeCompareDe(a.firstName, b.firstName));
        break;
      case 'lastName':
        sorted.sort((a, b) => localeCompareDe(a.lastName, b.lastName));
        break;
      case 'birthdayAsc':
        sorted.sort((a, b) {
          if (a.birthday == null && b.birthday == null) return 0;
          if (a.birthday == null) return 1;
          if (b.birthday == null) return -1;
          return a.birthday!.compareTo(b.birthday!);
        });
        break;
      case 'birthdayDesc':
        sorted.sort((a, b) {
          if (a.birthday == null && b.birthday == null) return 0;
          if (a.birthday == null) return 1;
          if (b.birthday == null) return -1;
          return b.birthday!.compareTo(a.birthday!);
        });
        break;
      case 'nextBirthday':
        sorted.sort((a, b) {
          if (a.birthday == null && b.birthday == null) return 0;
          if (a.birthday == null) return 1;
          if (b.birthday == null) return -1;
          final now = DateTime.now();
          final aBirthday = DateTime.tryParse(a.birthday!);
          final bBirthday = DateTime.tryParse(b.birthday!);
          if (aBirthday == null && bBirthday == null) return 0;
          if (aBirthday == null) return 1;
          if (bBirthday == null) return -1;
          // Calculate next birthday
          var aNext = DateTime(now.year, aBirthday.month, aBirthday.day);
          var bNext = DateTime(now.year, bBirthday.month, bBirthday.day);
          if (aNext.isBefore(now)) aNext = DateTime(now.year + 1, aBirthday.month, aBirthday.day);
          if (bNext.isBefore(now)) bNext = DateTime(now.year + 1, bBirthday.month, bBirthday.day);
          return aNext.compareTo(bNext);
        });
        break;
      case 'joinedAsc':
        sorted.sort((a, b) {
          if (a.joined == null && b.joined == null) return 0;
          if (a.joined == null) return 1;
          if (b.joined == null) return -1;
          return a.joined!.compareTo(b.joined!);
        });
        break;
      case 'joinedDesc':
        sorted.sort((a, b) {
          if (a.joined == null && b.joined == null) return 0;
          if (a.joined == null) return 1;
          if (b.joined == null) return -1;
          return b.joined!.compareTo(a.joined!);
        });
        break;
      case 'testResult':
        // LOGIC_PEOPLE: Ionic strips '%' ("85%") and counts missing as 0.
        sorted.sort((a, b) => testResultValue(b.testResult)
            .compareTo(testResultValue(a.testResult))); // descending
        break;
      case 'attAsc':
      case 'attDesc':
        final pct = ref.read(listAttendancePercentagesProvider).valueOrNull ??
            const <int, int>{};
        sorted.sort((a, b) {
          final c = (pct[a.id] ?? 0).compareTo(pct[b.id] ?? 0);
          return _sortOption == 'attAsc' ? c : -c;
        });
        break;
      case 'group':
      default:
        // Main group first, then instrument sort_order, then group name;
        // inside a group: player sort_order, then last name (Ionic Utils)
        final groups = ref.read(groupsProvider).valueOrNull ?? const [];
        return sortPeopleByGroup(sorted, groups);
    }

    return sorted;
  }

  /// Group people by their group name
  Map<String, List<Person>> _groupByGroup(List<Person> people) {
    final grouped = <String, List<Person>>{};
    for (final person in people) {
      final group = person.groupName ?? context.l10n.attendanceNoGroup;
      grouped.putIfAbsent(group, () => []);
      grouped[group]!.add(person);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final tenant = ref.watch(currentTenantProvider);
    // B3-028: Reset filters when tenant changes
    ref.listen(currentTenantProvider, (previous, next) {
      if (previous?.id != next?.id) {
        setState(() {
          _filterOption = 'all';
          _extraFilterValue = null;
          _sortOption = 'group';
          _searchQuery = '';
          _searchController.clear();
          _isSelectionMode = false;
          _selectedPlayerIds.clear();
        });
        _loadViewOptions();
      }
    });
    // Use realtime provider for live updates
    final peopleAsync = ref.watch(realtimePlayersProvider);
    // "Anwesenheit zählen": season (default) or a chosen period / Terminart.
    final rateFilter = ref.watch(attendanceRateFilterProvider);
    final percentagesAsync = ref.watch(listAttendancePercentagesProvider);
    final percentages = percentagesAsync.valueOrNull ?? {};
    // Ionic showTeachers = view option and tenant.maintainTeachers; names
    // from db.getTeachers().
    final showTeachers = (tenant?.maintainTeachers ?? false) &&
        _viewOptions.contains('teacher');
    final teacherNames = <int, String>{
      if (showTeachers)
        for (final t in ref.watch(teachersProvider).valueOrNull ?? const [])
          if (t.id != null) t.id!: t.name,
    };
    // PARITY_B (I2): Ionic getPersonExtraFields + hydrated shared values
    final extraFields = ref.watch(personListExtraFieldsProvider);
    // Gemeinde defaults need the churches (first church).
    if (extraFields.any((f) => f.type == 'bfecg_church')) {
      ref.watch(churchesProvider);
    }
    final sharedFieldValues =
        ref.watch(sharedPersonFieldValuesProvider).valueOrNull ?? const {};
    final mainGroupId = ref.watch(mainGroupProvider).valueOrNull?.id;
    // _sortPeople liest die Gruppen per ref.read: hier beobachten, damit die
    // Liste neu sortiert wird, sobald sie geladen sind (Sortierung „Gruppe“).
    ref.watch(groupsProvider);
    final churchNames = <String, String>{
      if (_churchField(tenant) != null)
        for (final c in ref.watch(churchesProvider).valueOrNull ?? const [])
          if (c.id != null) c.id!: c.name,
    };
    final ios = ionIsIos(context);
    final background = ionContentBackground(context);

    if (_isReordering) {
      // Ionic: toolbar color="warning" "Reihenfolge anpassen" + checkmark
      return Scaffold(
        backgroundColor: background,
        appBar: AppBar(
          backgroundColor: AppColors.warning,
          foregroundColor: Colors.black,
          title: Text(context.l10n.peopleReorder),
          leading: IconButton(
            icon: Icon(AppIcons.close),
            tooltip: context.l10n.commonCancel,
            onPressed: () => setState(() {
              _isReordering = false;
              _reorderIds.clear();
            }),
          ),
          actions: [
            IconButton(
              icon: _isSavingOrder
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: AppSpinner(strokeWidth: 2),
                    )
                  : Icon(AppIcons.check),
              tooltip: context.l10n.peopleFlutterSaveOrder,
              onPressed: _isSavingOrder ? null : _toggleReorderMode,
            ),
          ],
        ),
        body: _buildReorderList(peopleAsync.valueOrNull ?? const []),
      );
    }

    final role = ref.watch(currentRoleProvider);
    // Ionic list.page isAdmin = Admin or Responsible
    final isAdmin = role.isAdmin || role.isResponsible;
    final tenants = ref.watch(userTenantsProvider).valueOrNull ?? const [];
    final multiTenant = tenants.length > 1;
    final tenantTitle = tenant?.longName.isNotEmpty == true
        ? tenant!.longName
        : (tenant?.shortName ?? context.l10n.commonPeople);
    // Ionic iOS: single tenant → ion-header collapse="condense" large title
    final largeTitle = ios && !multiTenant && !_isSelectionMode;

    final slivers = <Widget>[
      if (largeTitle)
        ionCondenseHeader(
          context,
          title: tenantTitle,
          // SIDE_NAV: menu button of the overlay panel (tablet portrait)
          leading: SideNavMenuButton.maybe(context),
          // IOS_SHELL: bell alone → glass circle
          trailing: const ToolbarButtonGroup(children: [NotificationBell()]),
        ),
      if (ios) CupertinoSliverRefreshControl(onRefresh: _refresh),
      // Search bar + options button (Ionic div.flex: ion-searchbar (86%) +
      // "options" icon that opens the filter popover)
      SliverToBoxAdapter(
        child: Row(
          children: [
            Expanded(
              child: IonSearchbar(
                controller: _searchController,
                placeholder: context.l10n.peopleSearchPerson,
                onChanged: (value) => setState(() => _searchQuery = value),
                padding: ios
                    ? const EdgeInsets.fromLTRB(8, 6, 0, 6)
                    : null,
              ),
            ),
            _buildOptionsButton(isAdmin: isAdmin),
            SizedBox(width: ios ? 8 : 4),
          ],
        ),
      ),
      // Birthday banner (Ionic people/list birthday-banner)
      if (!_isSelectionMode && peopleAsync.hasValue)
        SliverToBoxAdapter(
          child: _BirthdayBanner(
            people: todaysBirthdays(peopleAsync.valueOrNull ?? const []),
            onTap: (p) {
              if (p.id != null) showPersonModal(context, p.id!);
            },
          ),
        ),
      ...peopleAsync.when(
        loading: () => [_skeletonSliver()],
        error: (error, stack) => [
          SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyStateWidget(
              icon: AppIcons.errorOutline,
              title: context.l10n.peopleFlutterLoadFailed,
              subtitle: context.l10n.peopleFlutterListLoadFailed,
              actionLabel: context.l10n.messagesRetry,
              onAction: () => ref.invalidate(realtimePlayersProvider),
            ),
          ),
        ],
        data: (rawPeople) {
          final people = _withDefaults(
              mergeSharedPersonFieldValues(rawPeople, sharedFieldValues));
          final sortedPeople = _sortPeople(_filterPeople(people));

          if (people.isEmpty) {
            // Ionic: people-outline + "Bisher wurden noch keine Personen
            // angelegt" + "Person hinzufügen" / "Personen importieren"
            return [
              SliverFillRemaining(
                hasScrollBody: false,
                child: IonNoData(
                  icon: AppIcons.peopleOutline,
                  label: context.l10n.peopleNoPeopleYet,
                  actions: [
                    (
                      context.l10n.attendanceAddPerson,
                      () => showPersonCreateModal(context),
                    ),
                    if (isAdmin)
                      (context.l10n.peopleImportPeople, _openImport),
                  ],
                ),
              ),
            ];
          }

          if (sortedPeople.isEmpty) {
            // Ionic: noPeopleFound / filtersNoMatch / resetFilter
            return [
              SliverFillRemaining(
                hasScrollBody: false,
                child: IonNoData(
                  icon: AppIcons.filterAltOutlined,
                  label: context.l10n.peopleNoPeopleFound,
                  message: context.l10n.peopleFiltersNoMatch,
                  actions: [(context.l10n.peopleResetFilter, _clearFilters)],
                ),
              ),
            ];
          }

          Widget tile(Person person) {
            final isSelected = person.id != null &&
                _selectedPlayerIds.contains(person.id);
            return _PersonListItem(
              person: person,
              isSelectionMode: _isSelectionMode,
              isSelected: isSelected,
              viewOptions: _viewOptions,
              extraFields: extraFields,
              churchNames: churchNames,
              isMainGroup:
                  mainGroupId != null && person.instrument == mainGroupId,
              otherInstanceName:
                  _filterOption == 'otherInstance' ? _otherInstanceName : null,
              onTap: _isSelectionMode && person.id != null
                  ? () => _togglePlayerSelection(person.id!)
                  : () {
                      if (person.id != null) showPersonModal(context, person.id!);
                    },
              onPause: isAdmin ? () => _showPauseDialog(person) : null,
              onUnpause: isAdmin ? () => _unpausePerson(person) : null,
              onRemove: isAdmin ? () => _remove(person) : null,
              // Ionic shows the badge for everyone, 0% without counted Termine;
              // a chosen period without Termine of the person shows none.
              attendancePercentage: person.id != null && percentagesAsync.hasValue
                  ? percentages[person.id] ?? (rateFilter.isDefault ? 0 : null)
                  : null,
              showTeachers: showTeachers,
              teacherNames: teacherNames,
            );
          }

          // Ionic: ion-list-header "Personen (n)", then (sorted by group) a
          // primary ion-item-divider per group.
          final children = <Widget>[
            IonListHeader(
                text: rateFilter.isDefault
                    ? context.l10n.peoplePeopleCount(sortedPeople.length)
                    : '${context.l10n.peoplePeopleCount(sortedPeople.length)} · '
                        '${rateFilterChip(context.l10n, rateFilter, ref.watch(attendanceTypesProvider).valueOrNull ?? const [])}'),
          ];
          if (_sortOption == 'group') {
            final grouped = _groupByGroup(sortedPeople);
            for (final entry in grouped.entries) {
              children.add(IonItemDivider(
                text: '${entry.key} (${entry.value.length})',
                color: AppColors.primary,
              ));
              children.addAll(entry.value.map(tile));
            }
          } else {
            children.addAll(sortedPeople.map(tile));
          }
          children.add(SizedBox(
              height: scrollEndPadding(context, base: 16, fabRoom: 88)));
          return [SliverList(delegate: SliverChildListDelegate(children))];
        },
      ),
    ];

    final scrollView = CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: slivers,
    );

    return Scaffold(
      backgroundColor: background,
      appBar: largeTitle ? null : _buildAppBar(context, ios: ios, multiTenant: multiTenant, tenantTitle: tenantTitle),
      body: ios
          ? scrollView
          : RefreshIndicator.adaptive(onRefresh: _refresh, child: scrollView),
      floatingActionButton: _isSelectionMode
          ? _selectedPlayerIds.isNotEmpty
              // A wide pill does not fit into the 61pt "+" slot beside the
              // iOS tab bar (it covered the tabs): it sits above the bar.
              ? TabBarFab.above(
                  child: ios
                      ? FilledButton.icon(
                          onPressed: _showHandoverSheet,
                          icon: Icon(AppIcons.swapHoriz),
                          label: Text(context.l10n.peopleFlutterTransferCount(_selectedPlayerIds.length)),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.warning,
                            foregroundColor: Colors.black,
                            elevation: 3,
                            shadowColor: Colors.black,
                          ),
                        )
                      : FloatingActionButton.extended(
                          onPressed: _showHandoverSheet,
                          icon: Icon(AppIcons.swapHoriz),
                          label: Text(context.l10n.peopleFlutterTransferCount(_selectedPlayerIds.length)),
                          backgroundColor: AppColors.warning,
                          foregroundColor: Colors.black,
                          shape: const StadiumBorder(),
                        ),
                )
              : null
          // Ionic: FAB "add" only for admins
          : isAdmin
              // IOS_SHELL: iOS → ion-fab in the tab bar row
              ? TabBarFab(
                  child: IonFabButton(onPressed: () => showPersonCreateModal(context)))
              : null,
    );
  }

  /// FN-007: manual refresh (realtime handles live updates)
  Future<void> _refresh() async {
    ref.invalidate(realtimePlayersProvider);
  }

  /// Ionic loading state: list header skeleton + 10 items with thumbnail.
  Widget _skeletonSliver() => const SliverToBoxAdapter(
        child: ListSkeleton(
          itemCount: 10,
          showAvatar: true,
          showSubtitle: true,
          showDividers: true,
        ),
      );

  /// Ionic header: tenant switcher button (slot start) when the user has
  /// several tenants, otherwise the tenant name; notification bell at the end.
  PreferredSizeWidget _buildAppBar(
    BuildContext context, {
    required bool ios,
    required bool multiTenant,
    required String tenantTitle,
  }) {
    if (_isSelectionMode) {
      return AppBar(
        title: Text(context.l10n.peopleFlutterSelectedCount(_selectedPlayerIds.length)),
        leading: IconButton(
          icon: Icon(AppIcons.close, semanticLabel: context.l10n.commonClose),
          onPressed: _exitSelectionMode,
        ),
        actions: [
          IconButton(
            icon: Icon(AppIcons.selectAll),
            tooltip: context.l10n.handoverSelectAll,
            onPressed: () {
              final filtered = _filterPeople(_listPeople());
              setState(() {
                _selectedPlayerIds.clear();
                for (final p in filtered) {
                  if (p.id != null) _selectedPlayerIds.add(p.id!);
                }
              });
            },
          ),
          IconButton(
            icon: Icon(AppIcons.deselect),
            tooltip: context.l10n.peopleFlutterDeselectAll,
            onPressed: () => setState(() => _selectedPlayerIds.clear()),
          ),
        ],
      );
    }
    if (ios && multiTenant) {
      // Ionic iOS: <ion-buttons slot="start"> tenant name + chevron-down,
      // no title.
      return AppBar(
        centerTitle: false,
        automaticallyImplyLeading: false,
        leading: SideNavMenuButton.maybe(context),
        titleSpacing: 8,
        title: DefaultTextStyle.merge(
          style: const TextStyle(
            color: AppColors.primary,
            fontSize: 17,
            fontWeight: FontWeight.w400,
          ),
          child: IconTheme.merge(
            data: const IconThemeData(color: AppColors.primary, size: 20),
            child: TenantSwitcherTitle(fallbackTitle: tenantTitle),
          ),
        ),
        actions: const [ToolbarButtonGroup(children: [NotificationBell()])], // MESSAGES, IOS_SHELL
      );
    }
    // Ionic: only the notification bell in the header; filter, sort, view
    // and admin actions live in the options popover next to the search bar.
    return AppBar(
      // SIDE_NAV: menu button of the overlay panel (tablet portrait)
      leading: SideNavMenuButton.maybe(context),
      title: TenantSwitcherTitle(fallbackTitle: context.l10n.commonPeople),
      centerTitle: TenantSwitcherTitle.centerTitle(ref),
      actions: const [ToolbarButtonGroup(children: [NotificationBell()])], // MESSAGES, IOS_SHELL
    );
  }

  // ---------------------------------------------------------------------
  // UX_PEOPLE: options popover (Ionic filterPopover)
  // ---------------------------------------------------------------------

  /// Filter options in Ionic order (list.page.html filter select).
  Map<String, String> _filterOptionLabels(Tenant? tenant) {
    final isVoS = _isVoS(tenant);
    final isGeneral = tenant?.type == 'general';
    final hasLinked =
        (ref.read(allLinkedTenantsProvider).valueOrNull ?? const []).isNotEmpty;
    return {
      'all': context.l10n.peopleShowAll,
      'active': context.l10n.peopleActivePeople,
      'critical': context.l10n.peopleProblemCases,
      if (!isGeneral) 'leaders': context.l10n.peopleVoiceLeader,
      'noAccount': context.l10n.peopleWithoutAccount,
      if (isVoS) 'examinees': context.l10n.peopleCandidates,
      if (isVoS) 'new': context.l10n.peopleNewPlayers,
      if (isVoS) 'noTeacher': context.l10n.peopleWithoutTeacher,
      if (isVoS) 'noTest': context.l10n.peopleTestResultMissing,
      if (hasLinked || _filterOption == 'otherInstance')
        'otherInstance': context.l10n.peopleOtherInstanceMember,
      for (final f in _filterableExtraFields(tenant)) 'extra:${f.id}': f.name,
    };
  }

  /// Sort options in Ionic order (list.page.html sort select).
  Map<String, String> _sortOptionLabels(Tenant? tenant) => {
        'group': context.l10n.peopleGroup,
        'firstName': context.l10n.peopleFirstName,
        'lastName': context.l10n.peopleLastName,
        'attAsc': context.l10n.peopleAttendanceAsc,
        'attDesc': context.l10n.peopleAttendanceDesc,
        'birthdayAsc': context.l10n.peopleBirthdayAsc,
        'birthdayDesc': context.l10n.peopleBirthdayDesc,
        'joinedAsc': context.l10n.peopleJoinAsc,
        'joinedDesc': context.l10n.peopleJoinDesc,
        'nextBirthday': context.l10n.peopleNextBirthday,
        if (_isVoS(tenant)) 'testResult': context.l10n.peopleTestResult,
      };

  Future<void> _onFilterSelected(String value) async {
    if (value.startsWith('extra:')) {
      await _selectExtraFieldFilter(value);
      return;
    }
    if (value == 'otherInstance') {
      await _selectOtherInstanceFilter();
      return;
    }
    _searchController.clear();
    setState(() {
      _filterOption = value;
      _extraFilterValue = null;
      _searchQuery = '';
    });
    _saveFilterOption();
  }

  /// "Anwesenheit zählen": a preset, or "Eigener …" with a date range.
  Future<void> _onRatePeriodSelected(RatePeriod period) async {
    final notifier = ref.read(attendanceRateFilterProvider.notifier);
    if (period != RatePeriod.custom) {
      notifier.state = notifier.state.withPeriod(period);
      return;
    }
    final today = DateUtils.dateOnly(DateTime.now());
    final current = notifier.state;
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2015),
      lastDate: today,
      initialDateRange: current.period == RatePeriod.custom && current.from != null && current.to != null
          ? DateTimeRange(start: current.from!, end: current.to!)
          : DateTimeRange(start: DateTime(today.year, 1, 1), end: today),
      locale: Locale(currentLanguage()),
      helpText: context.l10n.peopleRateTitle,
      saveText: context.l10n.commonApply,
    );
    if (range == null || !mounted) return;
    notifier.state = notifier.state.withPeriod(RatePeriod.custom, from: range.start, to: range.end);
  }

  void _onSortSelected(String value) {
    setState(() => _sortOption = value);
    _saveSortOption();
  }

  /// Ionic `#filterPopover` (ion-popover at the options button): Filter
  /// (funnel), Sortierung (filter), Ansicht (eye, multiple) as popover
  /// selects, then Gemeinde-Übersicht, Bulk-Bearbeitung, Personen
  /// importieren and Reihenfolge anpassen.
  ///
  /// The selects open nested popovers and the options popover stays open
  /// while they are used (a Material `MenuAnchor` closed everything with
  /// the first tap).
  Widget _buildOptionsButton({required bool isAdmin}) {
    final rate = ref.read(attendanceRateFilterProvider);
    return Builder(
      builder: (buttonContext) => IconButton(
        key: const Key('people_options_button'),
        icon: Icon(
          AppIcons.tune,
          color: _filterOption != 'all' || !rate.isDefault ? AppColors.primary : null,
        ),
        tooltip: context.l10n.typeSettingsOptions,
        onPressed: () => showAppFilterPopover(
          context: buttonContext,
          rows: () => _optionsRows(isAdmin: isAdmin),
        ),
      ),
    );
  }

  /// The rows of the options popover, built from the current state (the
  /// popover reads them again after every change).
  List<AppFilterRow> _optionsRows({required bool isAdmin}) {
    // The popover can outlive the page (resize across the side-nav
    // breakpoint, tenant switch).
    if (!mounted) return const [];
    final tenant = ref.read(currentTenantProvider);
    final filterLabels = _filterOptionLabels(tenant);
    final sortLabels = _sortOptionLabels(tenant);
    final viewLabels = _viewOptionLabels(tenant);
    final rate = ref.read(attendanceRateFilterProvider);
    final rateTypes = [
      for (final t in ref.read(attendanceTypesProvider).valueOrNull ?? const [])
        if (t.id != null && t.visible) t,
    ];
    List<(String, String)> entries(Map<String, String> m) =>
        [for (final e in m.entries) (e.key, e.value)];
    return [
      AppFilterSelect<String>(
        icon: AppIcons.filterAlt,
        value: filterLabels.containsKey(_filterOption) ? _filterOption : 'all',
        options: entries(filterLabels),
        onSelected: _onFilterSelected,
      ),
      AppFilterSelect<String>(
        icon: AppIcons.filterList,
        value: sortLabels.containsKey(_sortOption) ? _sortOption : 'group',
        options: entries(sortLabels),
        onSelected: _onSortSelected,
      ),
      // "Anwesenheit zählen": period of the percentages.
      AppFilterSelect<String>(
        icon: AppIcons.calendarToday,
        value: rate.period.name,
        options: [
          for (final period in RatePeriod.values)
            (period.name, ratePeriodLabel(context.l10n, period, filter: rate)),
        ],
        onSelected: (v) => _onRatePeriodSelected(RatePeriod.values.byName(v)),
      ),
      if (rateTypes.length > 1)
        AppFilterSelect<String>(
          icon: AppIcons.event,
          value: rate.typeId ?? '',
          options: [
            ('', context.l10n.peopleRateAllTypes),
            for (final t in rateTypes) (t.id!, t.name),
          ],
          onSelected: (v) => ref.read(attendanceRateFilterProvider.notifier).state =
              ref.read(attendanceRateFilterProvider).withType(v.isEmpty ? null : v),
        ),
      AppFilterMultiSelect<String>(
        icon: AppIcons.visibility,
        values: () => _viewOptions.toList(),
        options: entries(viewLabels),
        onChanged: (key, on) {
          setState(() {
            if (on) {
              _viewOptions.add(key);
            } else {
              _viewOptions.remove(key);
            }
          });
          _saveViewOptions();
        },
      ),
      if (_churchField(tenant) != null)
        AppFilterAction(
          icon: AppIcons.businessOutlined,
          label: context.l10n.attendanceChurchOverview,
          onTap: _showChurchOverview,
        ),
      if (isAdmin) ...[
        AppFilterAction(
          icon: AppIcons.edit,
          label: context.l10n.peopleBulkEdit,
          onTap: _openBulkEdit,
        ),
        AppFilterAction(
          icon: AppIcons.cloudUploadOutlined,
          label: context.l10n.peopleImportPeople,
          onTap: _openImport,
        ),
        if (_sortOption == 'group')
          AppFilterAction(
            icon: AppIcons.swapVert,
            label: context.l10n.peopleReorder,
            onTap: _toggleReorderMode,
          ),
        // Flutter extra: multi-select handover (Ionic only has the
        // handover page in the settings)
        AppFilterAction(
          icon: AppIcons.checklist,
          label: context.l10n.peopleFlutterTransferPeople,
          onTap: _enterSelectionMode,
        ),
      ],
    ];
  }

  List<ExtraField> _filterableExtraFields(Tenant? tenant) =>
      ref.read(personListExtraFieldsProvider)
          .where((f) => const ['boolean', 'select', 'number', 'bfecg_church']
              .contains(f.type))
          .toList();

  /// Ask for the value of an extra-field filter (Ionic onFilterChanged).
  Future<void> _selectExtraFieldFilter(String option) async {
    final tenant = ref.read(currentTenantProvider);
    final fieldId = option.substring(6);
    final field = _filterableExtraFields(tenant)
        .where((f) => f.id == fieldId)
        .firstOrNull;
    if (field == null) return;

    String? value;
    if (field.type == 'number') {
      final controller = TextEditingController(
          text: _filterOption == option ? _extraFilterValue ?? '' : '');
      value = await showAppDialog<String>(
        context: context,
        builder: (ctx) => AppAlertDialog(
          title: Text(field.name),
          // Ionic alert input `type: 'number'`; "Abbrechen" has
          // `role: 'destructive'` (list.page.ts onFilterChanged).
          content: AppAlertInput(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            placeholder: context.l10n.peopleEnterValue,
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                style: appAlertDestructiveStyle(ctx),
                child: Text(context.l10n.commonCancel)),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, controller.text.trim()),
                child: Text(context.l10n.peopleFilter)),
          ],
        ),
      );
      controller.dispose();
    } else {
      final List<MapEntry<String, String>> choices;
      if (field.type == 'boolean') {
        choices = [MapEntry('true', context.l10n.commonYes), MapEntry('false', context.l10n.commonNo)];
      } else if (field.type == 'bfecg_church') {
        final churches = await ref.read(churchesProvider.future);
        choices = churches
            .where((c) => c.id != null)
            .map((c) => MapEntry(c.id!, c.name))
            .toList();
      } else {
        choices = (field.options ?? const <String>[])
            .map((o) => MapEntry(o, o))
            .toList();
      }
      if (!mounted) return;
      // Ionic: ion-alert with radio inputs, "Abbrechen" (→ Alle) /
      // "Filtern". Only the Ja/Nein alert pre-checks a value (Ja unless the
      // saved filter is Nein); the select/church inputs set `selected`,
      // which ion-alert ignores, so nothing is pre-checked there.
      final saved = _filterOption == option ? _extraFilterValue : null;
      final result = await showAppRadioAlert<String>(
        context,
        title: field.name,
        options: [for (final c in choices) (c.key, c.value)],
        initialValue: field.type == 'boolean'
            ? (saved == 'false' ? 'false' : 'true')
            : null,
        confirmText: context.l10n.peopleFilter,
        // Ionic: "Abbrechen" has `role: 'destructive'` (Beta unchanged).
        cancelDestructive: context.rdSkin == null,
      );
      value = result?.value;
    }

    if (!mounted) return;
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      if (value == null || value.isEmpty) {
        _filterOption = 'all';
        _extraFilterValue = null;
      } else {
        _filterOption = option;
        _extraFilterValue = value;
      }
    });
    _saveFilterOption();
  }

  // ---------------------------------------------------------------------
  // PEOPLE2: other-instance filter, church overview, reorder mode
  // ---------------------------------------------------------------------

  bool _isVoS(Tenant? tenant) => tenant?.shortName == 'VoS';

  ExtraField? _churchField(Tenant? tenant) =>
      ref.read(personListExtraFieldsProvider)
          .where((f) => f.type == 'bfecg_church')
          .firstOrNull;

  /// Ionic onFilterChanged('otherInstance'): pick a linked instance and show
  /// only people whose account is also a member there.
  Future<void> _selectOtherInstanceFilter() async {
    final crossTenantPersonRepo = ref.read(crossTenantPersonRepositoryWithTenantProvider);
    final linked = await ref.read(allLinkedTenantsProvider.future);
    if (!mounted) return;
    if (linked.isEmpty) {
      setState(() => _filterOption = 'all');
      return;
    }
    final chosen = await showAppDialog<Tenant>(
      context: context,
      builder: (ctx) => AppSimpleDialog(
        title: Text(context.l10n.peopleChooseInstance),
        children: [
          for (final t in linked)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, t),
              child: Text(t.longName.isNotEmpty ? t.longName : t.shortName),
            ),
        ],
      ),
    );
    if (chosen == null || chosen.id == null || !mounted) return;
    try {
      final linkedIds = await ref.read(linkedTenantIdsProvider.future);
      final ids = await crossTenantPersonRepo
          .getUserIdsInTenant(chosen.id!, linkedTenantIds: linkedIds);
      if (!mounted) return;
      _searchController.clear();
      setState(() {
        _searchQuery = '';
        _filterOption = 'otherInstance';
        _extraFilterValue = null;
        _otherInstanceUserIds = ids;
        _otherInstanceName =
            chosen.longName.isNotEmpty ? chosen.longName : chosen.shortName;
      });
      _saveFilterOption();
    } catch (e) {
      // Ionic CrossTenantService.getUserIdsInTenant: 'Fehler beim Laden der Benutzer'.
      if (mounted) ToastHelper.showError(context, context.l10n.svcLoadUsersFailed);
    }
  }

  /// "Gemeinde-Übersicht" (Ionic showChurchOverview): church counts of the
  /// currently filtered people.
  Future<void> _showChurchOverview() async {
    final field = _churchField(ref.read(currentTenantProvider));
    if (field == null) return;
    final people = _listPeople();
    final churchIds = _filterPeople(people)
        .map((p) => churchIdOf(p.additionalFields, field.id))
        .toList();
    final churches = await ref.read(churchesProvider.future);
    if (!mounted) return;
    await showChurchOverviewSheet(
      context,
      churchIds: churchIds,
      churches: churches,
      subtitle: context.l10n.commonPeople,
    );
  }

  /// Ionic toggleReorderMode: enter reorder mode, or save the new order.
  Future<void> _toggleReorderMode() async {
    if (!_isReordering) {
      final grouped = _groupByGroup(_sortPeople(_filterPeople(_listPeople())));
      setState(() {
        _reorderedGroups.clear();
        _reorderIds
          ..clear()
          ..addAll(grouped.map((k, v) =>
              MapEntry(k, v.map((p) => p.id).whereType<int>().toList())));
        _isReordering = true;
        _sortOption = 'group';
      });
      return;
    }

    // Ionic savePlayerOrder: writes sort_order only where it is set, i.e.
    // the moved groups; never-sorted groups stay alphabetical.
    final orders = <int, int>{};
    for (final entry in _reorderIds.entries) {
      if (!_reorderedGroups.contains(entry.key)) continue;
      final ids = entry.value;
      for (var i = 0; i < ids.length; i++) {
        orders[ids[i]] = i + 1;
      }
    }
    setState(() => _isSavingOrder = true);
    try {
      await ref.read(playerRepositoryWithTenantProvider).savePlayerOrder(orders);
      ref.invalidate(realtimePlayersProvider);
      if (mounted) ToastHelper.showSuccess(context, context.l10n.peopleOrderSaved);
    } catch (_) {
      if (mounted) {
        ToastHelper.showError(context, context.l10n.peopleOrderSaveFailed);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSavingOrder = false;
          _isReordering = false;
          _reorderIds.clear();
        });
      }
    }
  }

  Widget _buildReorderList(List<Person> people) {
    final byId = {for (final p in people) if (p.id != null) p.id!: p};
    final groupNames = _reorderIds.keys.toList();
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingM),
      children: [
        for (final groupName in groupNames) ...[
          Padding(
            padding: const EdgeInsets.only(
              top: AppDimensions.paddingM,
              bottom: AppDimensions.paddingS,
            ),
            child: Text(
              '$groupName (${_reorderIds[groupName]!.length})',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
            ),
          ),
          ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            onReorder: (oldIndex, newIndex) {
              setState(() {
                final ids = _reorderIds[groupName]!;
                if (newIndex > oldIndex) newIndex -= 1;
                if (newIndex == oldIndex) return;
                final moved = ids.removeAt(oldIndex);
                ids.insert(newIndex, moved);
                _reorderedGroups.add(groupName);
              });
            },
            children: [
              for (var i = 0; i < _reorderIds[groupName]!.length; i++)
                Card(
                  key: ValueKey('reorder_${_reorderIds[groupName]![i]}'),
                  margin: const EdgeInsets.only(bottom: AppDimensions.paddingS),
                  child: ListTile(
                    leading: ReorderableDragStartListener(
                      index: i,
                      child: Icon(AppIcons.dragHandle),
                    ),
                    title: Text(
                        byId[_reorderIds[groupName]![i]]?.fullName ?? '?'),
                  ),
                ),
            ],
          ),
        ],
        SizedBox(height: scrollEndPadding(context, base: 16, fabRoom: 64)),
      ],
    );
  }

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _filterOption = 'all';
      _extraFilterValue = null;
      _otherInstanceUserIds = null;
      _otherInstanceName = null;
    });
    _saveFilterOption();
  }

  void _enterSelectionMode() {
    setState(() {
      _isSelectionMode = true;
      _selectedPlayerIds.clear();
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedPlayerIds.clear();
    });
  }

  void _togglePlayerSelection(int playerId) {
    setState(() {
      if (_selectedPlayerIds.contains(playerId)) {
        _selectedPlayerIds.remove(playerId);
      } else {
        _selectedPlayerIds.add(playerId);
      }
    });
  }

  // PEOPLE_IMPORT: open bulk edit with the currently filtered persons
  Future<void> _openBulkEdit() async {
    // PARITY_B (I3): bulk edit works on hydrated values (Ionic list players)
    final people = _listPeople();
    final players = _sortPeople(_filterPeople(people));
    final updated = await Navigator.of(context, rootNavigator: true).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => BulkEditPage(players: players),
      ),
    );
    if (updated == true && mounted) {
      ref.invalidate(realtimePlayersProvider);
    }
  }

  // PEOPLE_IMPORT: open the person import
  Future<void> _openImport() async {
    final imported = await Navigator.of(context, rootNavigator: true).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const PersonImportPage(),
      ),
    );
    if (imported == true && mounted) {
      ref.invalidate(realtimePlayersProvider);
    }
  }

  Future<void> _showHandoverSheet() async {
    final people = ref.read(realtimePlayersProvider).valueOrNull ?? [];
    final selectedPlayers = people
        .where((p) => p.id != null && _selectedPlayerIds.contains(p.id))
        .toList();

    if (selectedPlayers.isEmpty) return;

    final result = await showHandoverSheet(
      context,
      selectedPlayers: selectedPlayers,
    );

    if (result == true && mounted) {
      _exitSelectionMode();
      ref.invalidate(realtimePlayersProvider);
    }
  }

  /// Pause flow (Ionic pausePlayer/confirmPause incl. "Pausiert ab" and
  /// "Auch in anderen Instanzen pausieren?")
  Future<void> _showPauseDialog(Person person) async {
    HapticHelper.light(); // MEDIA_REALTIME: Ionic Haptics.impact Light
    await pausePersonFlow(context, ref, person);
  }

  /// Ionic unpausePlayer: alert "Person wieder aktivieren?" → Aktivieren.
  Future<void> _unpausePerson(Person person) async {
    final repository = ref.read(playerRepositoryWithTenantProvider);
    final confirmed = await showAppDialog<bool>(
      context: context,
      builder: (ctx) => AppAlertDialog(
        title: Text(context.l10n.peopleReactivateConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.l10n.peopleActivate),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await repository.unpausePlayer(person, historyText: context.l10n.peopleActiveAgain);
      // Realtime handles the refresh automatically
    } catch (e) {
      if (mounted) ToastHelper.showError(context, context.l10n.peopleFlutterErrorWith(friendlyErrorMessage(e)));
    }
  }

  /// Ionic remove(): action sheet "Archivieren" / "Entfernen" / "Abbrechen".
  Future<void> _remove(Person person) async {
    final userId = ref.read(supabaseClientProvider).auth.currentUser?.id;
    if (person.appId != null && person.appId == userId) {
      ToastHelper.showError(context, context.l10n.peopleCannotRemoveSelf);
      return;
    }
    final choice = await showAppActionSheet<String>(
      context,
      actions: [
        AppActionSheetAction(value: 'archive', label: context.l10n.peopleArchive),
        AppActionSheetAction(value: 'remove', label: context.l10n.commonRemove),
      ],
    );
    if (!mounted) return;
    if (choice == 'archive') await _showArchiveDialog(person);
    if (choice == 'remove') await _removePlayer(person);
  }

  /// Ionic archive modal: full screen "{name} Archivieren" with X,
  /// Austrittsdatum, Notiz and the archive FAB.
  Future<void> _showArchiveDialog(Person person) async {
    final result = await showArchivePersonModal(
        context, '${person.firstName} ${person.lastName}');
    if (result != null && mounted) {
      await _archivePerson(person, date: result.date, note: result.note);
    }
  }

  /// Archive a person
  Future<void> _archivePerson(Person person, {String? date, String? note}) async {
    final repository = ref.read(playerRepositoryWithTenantProvider);
    try {
      await repository.archivePlayer(
        person,
        date ?? DateTime.now().toUtc().toIso8601String(),
        note?.isEmpty == true ? null : note,
      );
      // Realtime handles the refresh automatically
    } catch (e) {
      if (mounted) ToastHelper.showError(context, context.l10n.peopleFlutterErrorWith(friendlyErrorMessage(e)));
    }
  }

  /// Ionic removePlayer: alert "Person wirklich entfernen?".
  Future<void> _removePlayer(Person person) async {
    HapticHelper.medium(); // MEDIA_REALTIME: Ionic Haptics.impact Medium
    final confirmed = await DialogHelper.showConfirmation(
      context,
      title: context.l10n.peopleRemoveConfirm,
      message: context.l10n.peopleCannotUndoExcl,
      confirmText: context.l10n.commonRemove,
      isDestructive: true,
    );

    if (confirmed == true && mounted && person.id != null) {
      try {
        await ref.read(playerNotifierProvider.notifier).deletePlayer(person.id!, appId: person.appId);
        if (mounted) ToastHelper.showSuccess(context, context.l10n.peopleRemoved);
      } catch (e) {
        if (mounted) ToastHelper.showError(context, context.l10n.peopleFlutterErrorWith(friendlyErrorMessage(e)));
      }
    }
  }
}

/// Person row (Ionic ion-item-sliding in people/list).
class _PersonListItem extends StatelessWidget {
  const _PersonListItem({
    required this.person,
    required this.onTap,
    this.isSelectionMode = false,
    this.isSelected = false,
    this.onPause,
    this.onUnpause,
    this.onRemove,
    this.attendancePercentage,
    this.viewOptions = const {'group', 'paused', 'critical', 'leader'},
    this.extraFields = const [],
    this.churchNames = const {},
    this.isMainGroup = false,
    this.otherInstanceName,
    this.showTeachers = false,
    this.teacherNames = const {},
  });

  final Person person;
  final VoidCallback onTap;
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback? onPause;
  final VoidCallback? onUnpause;
  final VoidCallback? onRemove;
  final int? attendancePercentage;
  final Set<String> viewOptions;
  final List<ExtraField> extraFields;
  final Map<String, String> churchNames;
  final bool isMainGroup;
  final String? otherInstanceName;

  /// Ionic showTeachers: view option "Lehrer" and tenant maintainTeachers.
  final bool showTeachers;

  /// Teacher id → name (Ionic getTeacherName, unknown → "Unbekannt").
  final Map<int, String> teacherNames;

  String _extraValueText(ExtraField field, dynamic value) {
    if (field.type == 'bfecg_church') {
      return churchNames[value?.toString()] ?? l10nWithoutContext.commonUnknown;
    }
    return value.toString();
  }

  /// JS truthiness like Ionic `@if (player.additional_fields[field.id])`:
  /// null, false, '' and 0 hide the badge/line.
  bool _hasExtraValue(dynamic v) =>
      v != null && v != false && v != '' && v != 0;

  /// Ionic getSubText: Gruppe | Geburtsdatum | Testergebnis | Instrumente |
  /// Sonstige Dienste, joined with " | ".
  String _subText(BuildContext context) {
    final parts = <String>[];
    if (viewOptions.contains('group') && person.groupName != null) {
      parts.add(person.groupName!);
    }
    if (viewOptions.contains('birthday') && person.birthday != null) {
      final date = DateTime.tryParse(person.birthday!);
      if (date != null) {
        parts.add(
            context.l10n.peopleAgeShort(DateFormat(dateFmt()).format(date), ageInYears(person.birthday!)));
      }
    }
    if (viewOptions.contains('test')) {
      parts.add((person.testResult?.isNotEmpty ?? false)
          ? person.testResult!
          : context.l10n.peopleNoResult);
    }
    if (viewOptions.contains('instruments') &&
        (person.instruments?.isNotEmpty ?? false)) {
      parts.add(person.instruments!);
    }
    if (viewOptions.contains('exercises') &&
        (person.otherExercise?.isNotEmpty ?? false)) {
      parts.add(person.otherExercise!);
    }
    return parts.join(' | ');
  }

  /// Additional label lines (h3 / p in Ionic) below the name.
  List<Widget> _lines(BuildContext context) {
    final h3 = IonText.h3(context);
    final p = IonText.p(context);
    Widget line(String text) => Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(text, style: h3, maxLines: 1, overflow: TextOverflow.ellipsis),
        );
    final sub = _subText(context);
    return [
      if (sub.isNotEmpty) line(sub),
      if (!isMainGroup && showTeachers)
        line(
          person.teacher != null
              ? context.l10n.peopleTeacherName(
                  teacherNames[person.teacher] ?? context.l10n.commonUnknown)
              : context.l10n.peopleNoTeacher,
        ),
      if (otherInstanceName != null) line(otherInstanceName!),
      // Ionic: <p style="white-space: pre-line">
      if (viewOptions.contains('notes') && (person.notes?.isNotEmpty ?? false))
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(person.notes!, style: p),
        ),
      for (final f in extraFields)
        if (viewOptions.contains('extra:${f.id}') &&
            f.displayMode == 'underneath' &&
            _hasExtraValue(person.additionalFields?[f.id]))
          line(
            f.type == 'boolean'
                ? f.name
                : '${f.name}: ${_extraValueText(f, person.additionalFields?[f.id])}',
          ),
    ];
  }

  /// Badges on the right (slot="end"), same order and colors as Ionic.
  List<Widget> _badges(BuildContext context) {
    final showPaused = viewOptions.contains('paused');
    final notHiddenByPause = !showPaused || !person.paused;
    return [
      if (notHiddenByPause && viewOptions.contains('leader') && person.isLeader)
        IonBadge(text: context.l10n.peopleVoiceLeader, color: AppColors.secondary),
      if (notHiddenByPause &&
          viewOptions.contains('new') &&
          isNewPerson(person) &&
          !person.isLeader)
        IonBadge(text: context.l10n.peopleNew, color: AppColors.danger),
      if (notHiddenByPause && viewOptions.contains('critical') && person.isCritical)
        IonBadge(text: context.l10n.peopleProblemCase, color: AppColors.danger),
      if (showPaused && person.paused)
        IonBadge(
            text: context.l10n.peoplePaused, color: AppColors.warning, textColor: Colors.black),
      if (viewOptions.contains('examinee') && person.examinee)
        IonBadge(text: context.l10n.peopleCandidate, color: AppColors.dark),
      for (final f in extraFields)
        if (viewOptions.contains('extra:${f.id}') &&
            f.displayMode != 'underneath' &&
            const ['boolean', 'select', 'text', 'bfecg_church', 'number']
                .contains(f.type) &&
            _hasExtraValue(person.additionalFields?[f.id]))
          IonBadge(
            text: switch (f.type) {
              'boolean' => f.name,
              'number' => '${f.name} ${person.additionalFields?[f.id]}',
              _ => _extraValueText(f, person.additionalFields?[f.id]),
            },
            color: f.type == 'boolean' ? AppColors.success : AppColors.dark,
          ),
      if (viewOptions.contains('attendance') && attendancePercentage != null)
        IonBadge(
          text: '$attendancePercentage%',
          color: attendancePercentage! >= 75
              ? AppColors.success
              : attendancePercentage! >= 50
                  ? AppColors.warning
                  : AppColors.danger,
          textColor: attendancePercentage! >= 75 || attendancePercentage! < 50
              ? Colors.white
              : Colors.black,
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final showPhoto = viewOptions.contains('photo');
    final badges = _badges(context);
    final tile = IonItem(
      onTap: onTap,
      selected: isSelected,
      start: isSelectionMode
          ? Checkbox(value: isSelected, onChanged: (_) => onTap())
          : (showPhoto ? IonAvatar(url: person.imageUrl) : null),
      end: [
        if (badges.isNotEmpty)
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * 0.55,
            ),
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: 4,
              runSpacing: 4,
              children: badges,
            ),
          ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${person.firstName} ${person.lastName}',
            style: IonText.h2(context),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          ..._lines(context),
        ],
      ),
    );

    if (isSelectionMode || (onRemove == null && onPause == null)) return tile;

    // Ionic ion-item-options (side end): trash (danger), pause (warning,
    // expandable) or play (success); a full swipe pauses/reactivates.
    final pauseAction = person.paused ? onUnpause : onPause;
    return Slidable(
      key: ValueKey('person_${person.id}'),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.4,
        dismissible: pauseAction == null
            ? null
            : DismissiblePane(
                closeOnCancel: true,
                confirmDismiss: () async {
                  pauseAction();
                  return false;
                },
                onDismissed: () {},
              ),
        children: [
          if (onRemove != null)
            SlidableAction(
              onPressed: (_) => onRemove!(),
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              icon: AppIcons.delete,
            ),
          if (pauseAction != null)
            SlidableAction(
              onPressed: (_) => pauseAction(),
              backgroundColor:
                  person.paused ? AppColors.success : AppColors.warning,
              foregroundColor: person.paused ? Colors.white : Colors.black,
              icon: person.paused ? AppIcons.playArrow : AppIcons.pause,
            ),
        ],
      ),
      child: tile,
    );
  }
}

/// Ionic `.birthday-banner`: card (radius 16, 1px step-150 border) with a
/// gift icon tile, the title and one pill per person (avatar or 🎂, name,
/// age).
class _BirthdayBanner extends StatelessWidget {
  const _BirthdayBanner({required this.people, required this.onTap});

  final List<Person> people;
  final void Function(Person) onTap;

  @override
  Widget build(BuildContext context) {
    if (people.isEmpty) return const SizedBox.shrink();
    final dark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = dark ? AppColors.surfaceDark : Colors.white;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: dark ? const Color(0xFF262626) : const Color(0xFFE5E5EA),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(AppIcons.cardGiftcardOutlined,
                    size: 18, color: AppColors.primaryDark),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  people.length == 1
                      ? context.l10n.peopleBirthdayToday
                      : context.l10n.peopleBirthdaysToday(people.length),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: people.map((p) {
              final age = p.birthday != null ? ageInYears(p.birthday!) : 0;
              final hasImg = p.img != null && p.img!.isNotEmpty;
              return Material(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: const StadiumBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => onTap(p),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(4, 4, 10, 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (hasImg)
                          IonAvatar(url: p.img, size: 28)
                        else
                          Container(
                            width: 28,
                            height: 28,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: cardColor,
                              shape: BoxShape.circle,
                            ),
                            child: const Text('🎂', style: TextStyle(fontSize: 14)),
                          ),
                        const SizedBox(width: 8),
                        Text(
                          '${p.firstName} ${p.lastName}',
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          context.l10n.peopleAgeYears(age),
                          style: const TextStyle(
                              fontSize: 13.5, color: AppColors.medium),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
