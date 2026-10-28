import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/config/supabase_config.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/attendance_providers.dart';
import '../../../../core/providers/group_providers.dart';
import '../../../../core/providers/player_providers.dart';
import '../../../../core/providers/realtime_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/dialog_helper.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../core/providers/organisation_providers.dart';
import '../../../../core/providers/cross_tenant_person_providers.dart';
import '../../../../core/providers/church_providers.dart';
import '../../../../data/models/person/person.dart';
import '../../../../data/models/tenant/tenant.dart';
import '../../../../shared/widgets/tenant/tenant_switcher_title.dart';
import '../../people_list_utils.dart';
import '../../../../shared/widgets/loading/loading.dart';
import '../../../../shared/widgets/common/empty_state.dart';
import '../../../../shared/widgets/sheets/church_overview_sheet.dart';
import '../widgets/handover_sheet.dart';
import '../../../../core/utils/haptic_helper.dart';
import '../widgets/pause_person_sheet.dart';
import '../../../messages/presentation/widgets/notification_bell.dart'; // MESSAGES
import 'bulk_edit_page.dart';
import 'person_import_page.dart';

/// Provider for people list (active players only)
final peopleListProvider = FutureProvider<List<Person>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  final tenant = ref.watch(currentTenantProvider);
  // Use centralized groupsMapProvider (cached with keepAlive)
  final groups = await ref.watch(groupsMapProvider.future);
  final repository = ref.watch(playerRepositoryWithTenantProvider);

  final tenantId = tenant?.id;
  if (tenant == null || tenantId == null) return [];

  // Check for auto-unpause (players whose pause period has ended)
  await repository.checkAndUnpausePlayers();

  try {
    final response = await supabase
        .from('player')
        .select('*')
        .eq('tenantId', tenantId)
        .isFilter('left', null)      // Only active (not archived/left)
        .isFilter('pending', false)  // Only confirmed players
        .order('instrument')         // Sort by group (instrument) first
        .order('isLeader', ascending: false)  // Leaders first
        .order('lastName');

    // Parse and add group name from groups map
    return (response as List).map((e) {
      try {
        final person = Person.fromJson(e as Map<String, dynamic>);
        // Add group name from the groups map
        final groupName = person.instrument != null ? groups[person.instrument] : null;
        return person.copyWith(groupName: groupName);
      } catch (parseError) {
        // SEC-002: Only log in debug mode to avoid PII exposure
        if (kDebugMode) {
          debugPrint('Error parsing person: $parseError');
          debugPrint('JSON data: $e');
        }
        rethrow;
      }
    }).toList();
  } catch (e, stack) {
    // SEC-002: Only log in debug mode to avoid PII exposure
    if (kDebugMode) {
      debugPrint('Error fetching people: $e');
      debugPrint('Stack trace: $stack');
    }
    rethrow;
  }
});

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
      'group': 'Gruppe',
      'attendance': 'Anwesenheit',
      'birthday': 'Geburtsdatum',
      if (isChoir) 'instruments': 'Instrumente',
      if (isVoS) 'test': 'Testergebnis',
      'exercises': 'Sonstige Dienste',
      if (!isGeneral) 'leader': 'Stimmführer',
      'critical': 'Problemfälle',
      if (isVoS) 'new': 'Neu',
      'paused': 'Pausiert',
      'notes': 'Notizen',
      'photo': 'Passbild',
      if (tenant?.maintainTeachers ?? false) 'teacher': 'Lehrer',
      if (isVoS) 'examinee': 'Prüfling',
      for (final f in tenant?.additionalFields ?? const <ExtraField>[])
        if (const ['boolean', 'text', 'select', 'bfecg_church', 'number']
            .contains(f.type))
          'extra:${f.id}': f.name,
    };
  }

  @override
  void initState() {
    super.initState();
    _loadViewOptions();
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
    final saved = prefs.getStringList('viewOpts_${tenant.id}');
    final savedSort = prefs.getString('sortOpt_${tenant.id}');
    if (savedSort != null && mounted) setState(() => _sortOption = savedSort);
    if (saved != null && mounted) {
      final opts = saved.toSet();
      // Attendance used to be always visible: keep it for old saved options
      if (!opts.contains(_viewOptionsVersionMarker)) opts.add('attendance');
      opts.remove(_viewOptionsVersionMarker);
      setState(() => _viewOptions = opts);
    }
  }

  Future<void> _saveViewOptions() async {
    final tenant = ref.read(currentTenantProvider);
    if (tenant == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('viewOpts_${tenant.id}',
        [..._viewOptions, _viewOptionsVersionMarker]);
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

  Future<void> _showViewOptionsDialog() async {
    final selected = Set<String>.from(_viewOptions);
    final result = await showDialog<Set<String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Ansicht konfigurieren'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: _viewOptionLabels(ref.read(currentTenantProvider))
                  .entries
                  .map((entry) {
                return CheckboxListTile(
                  title: Text(entry.value),
                  value: selected.contains(entry.key),
                  onChanged: (v) {
                    setDialogState(() {
                      if (v == true) {
                        selected.add(entry.key);
                      } else {
                        selected.remove(entry.key);
                      }
                    });
                  },
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                setDialogState(() {
                  selected.clear();
                  selected.addAll(_defaultViewOptions);
                });
              },
              child: const Text('Standard'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, selected),
              child: const Text('Übernehmen'),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      setState(() => _viewOptions = result);
      _saveViewOptions();
    }
  }

  List<Person> _filterPeople(List<Person> people) {
    var filtered = people;

    // Apply filter
    switch (_filterOption) {
      case 'critical':
        filtered = filtered.where((p) => p.isCritical).toList();
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

    final extraFields =
        ref.read(currentTenantProvider)?.additionalFields ?? const <ExtraField>[];

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

  List<Person> _sortPeople(List<Person> people) {
    final sorted = List<Person>.from(people);

    switch (_sortOption) {
      case 'firstName':
        sorted.sort((a, b) => a.firstName.compareTo(b.firstName));
        break;
      case 'lastName':
        sorted.sort((a, b) => a.lastName.compareTo(b.lastName));
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
        sorted.sort((a, b) {
          final aVal = double.tryParse(a.testResult ?? '');
          final bVal = double.tryParse(b.testResult ?? '');
          if (aVal == null && bVal == null) return 0;
          if (aVal == null) return 1;
          if (bVal == null) return -1;
          return bVal.compareTo(aVal); // descending
        });
        break;
      case 'attAsc':
      case 'attDesc':
        final pct = ref.read(playerAttendancePercentagesProvider).valueOrNull ??
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
      final group = person.groupName ?? 'Keine Gruppe';
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
    final percentages = ref.watch(playerAttendancePercentagesProvider).valueOrNull ?? {};
    final extraFields = tenant?.additionalFields ?? const <ExtraField>[];
    final mainGroupId = ref.watch(mainGroupProvider).valueOrNull?.id;
    final churchNames = <String, String>{
      if (_churchField(tenant) != null)
        for (final c in ref.watch(churchesProvider).valueOrNull ?? const [])
          if (c.id != null) c.id!: c.name,
    };

    if (_isReordering) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: AppColors.warning,
          title: const Text('Reihenfolge anpassen'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Abbrechen',
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
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              tooltip: 'Reihenfolge speichern',
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

    return Scaffold(
      appBar: AppBar(
        title: _isSelectionMode
            ? Text('${_selectedPlayerIds.length} ausgewählt')
            : const TenantSwitcherTitle(fallbackTitle: 'Personen'),
        leading: _isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: _exitSelectionMode,
              )
            : null,
        actions: _isSelectionMode
            ? [
                IconButton(
                  icon: const Icon(Icons.select_all),
                  tooltip: 'Alle auswählen',
                  onPressed: () {
                    final people =
                        ref.read(realtimePlayersProvider).valueOrNull ?? [];
                    final filtered = _filterPeople(people);
                    setState(() {
                      _selectedPlayerIds.clear();
                      for (final p in filtered) {
                        if (p.id != null) _selectedPlayerIds.add(p.id!);
                      }
                    });
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.deselect),
                  tooltip: 'Auswahl aufheben',
                  onPressed: () => setState(() => _selectedPlayerIds.clear()),
                ),
              ]
            // Ionic: only the notification bell in the header; filter, sort,
            // view and admin actions live in the options popover next to the
            // search bar.
            : const [NotificationBell()], // MESSAGES
      ),
      body: Column(
        children: [
          // Search bar + options button (Ionic div.flex: ion-searchbar +
          // "options" icon that opens the filter popover)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimensions.paddingM,
              AppDimensions.paddingS,
              AppDimensions.paddingXS,
              AppDimensions.paddingS,
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Person suchen...',
                      prefixIcon: const Icon(Icons.search),
                      isDense: true,
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                    ),
                    onChanged: (value) => setState(() => _searchQuery = value),
                  ),
                ),
                IconButton(
                  key: const Key('people_options_button'),
                  icon: Icon(
                    Icons.tune,
                    color: _filterOption != 'all' ? AppColors.primary : null,
                  ),
                  tooltip: 'Optionen',
                  onPressed: () => _showOptionsSheet(isAdmin: isAdmin),
                ),
              ],
            ),
          ),

          // Birthday banner (Ionic people/list birthday-banner)
          if (!_isSelectionMode && peopleAsync.hasValue)
            _BirthdayBanner(
              people: todaysBirthdays(peopleAsync.valueOrNull ?? const []),
              onTap: (p) => context.push('/people/${p.id}'),
            ),

          Expanded(
            child: peopleAsync.when(
              loading: () => const ListSkeleton(
                itemCount: 10,
                showAvatar: true,
                showSubtitle: true,
                showDividers: true,
              ),
              error: (error, stack) => EmptyStateWidget(
                icon: Icons.error_outline,
                title: 'Fehler beim Laden',
                subtitle: 'Die Personenliste konnte nicht geladen werden.',
                actionLabel: 'Erneut versuchen',
                onAction: () => ref.invalidate(realtimePlayersProvider),
              ),
              data: (people) {
                final filteredPeople = _filterPeople(people);
                final sortedPeople = _sortPeople(filteredPeople);

                if (people.isEmpty) {
                  // Ionic: "Bisher wurden noch keine Personen angelegt"
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppDimensions.paddingL),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.people_outline,
                              size: 48, color: AppColors.medium),
                          const SizedBox(height: AppDimensions.paddingM),
                          const Text(
                            'Bisher wurden noch keine Personen angelegt',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: AppDimensions.paddingM),
                          OutlinedButton(
                            onPressed: () => context.push('/people/new'),
                            child: const Text('Person hinzufügen'),
                          ),
                          if (isAdmin) ...[
                            const SizedBox(height: AppDimensions.paddingS),
                            OutlinedButton(
                              onPressed: _openImport,
                              child: const Text('Personen importieren'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }

                if (sortedPeople.isEmpty) {
                  // Ionic: noPeopleFound / filtersNoMatch / resetFilter
                  return EmptyStateWidget(
                    icon: Icons.filter_alt_outlined,
                    title: 'Keine Personen gefunden',
                    subtitle: 'Die aktiven Filter ergeben keine Treffer.',
                    actionLabel: 'Filter zurücksetzen',
                    onAction: _clearFilters,
                    animateIcon: false,
                  );
                }

                if (_isReordering) return _buildReorderList(people);

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
                    isMainGroup: mainGroupId != null &&
                        person.instrument == mainGroupId,
                    otherInstanceName: _filterOption == 'otherInstance'
                        ? _otherInstanceName
                        : null,
                    onTap: _isSelectionMode && person.id != null
                        ? () => _togglePlayerSelection(person.id!)
                        : () => context.push('/people/${person.id}'),
                    onPause: isAdmin ? () => _showPauseDialog(person) : null,
                    onUnpause: isAdmin ? () => _unpausePerson(person) : null,
                    onRemove: isAdmin ? () => _remove(person) : null,
                    attendancePercentage:
                        person.id != null ? percentages[person.id] : null,
                  );
                }

                // Ionic: ion-list-header "Personen (n)", then (sorted by
                // group) a primary ion-item-divider per group.
                final children = <Widget>[
                  _ListHeader(text: 'Personen (${sortedPeople.length})'),
                ];
                if (_sortOption == 'group') {
                  final grouped = _groupByGroup(sortedPeople);
                  for (final entry in grouped.entries) {
                    children.add(_GroupDivider(
                        text: '${entry.key} (${entry.value.length})'));
                    for (final p in entry.value) {
                      children.add(tile(p));
                    }
                  }
                } else {
                  children.addAll(sortedPeople.map(tile));
                }
                children.add(const SizedBox(height: 88));

                return RefreshIndicator(
                  onRefresh: () async {
                    // FN-007: manual refresh (realtime handles live updates)
                    ref.invalidate(realtimePlayersProvider);
                  },
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: children,
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: _isSelectionMode
          ? _selectedPlayerIds.isNotEmpty
              ? FloatingActionButton.extended(
                  onPressed: _showHandoverSheet,
                  icon: const Icon(Icons.swap_horiz),
                  label: Text('${_selectedPlayerIds.length} übertragen'),
                  backgroundColor: AppColors.warning,
                )
              : null
          // Ionic: FAB "add" only for admins
          : isAdmin
              ? FloatingActionButton(
                  onPressed: () => context.push('/people/new'),
                  child: const Icon(Icons.add),
                )
              : null,
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
      'all': 'Alle Anzeigen',
      'active': 'Aktive Personen',
      'critical': 'Problemfälle',
      if (!isGeneral) 'leaders': 'Stimmführer',
      'noAccount': 'Ohne Account',
      if (isVoS) 'examinees': 'Prüflinge',
      if (isVoS) 'new': 'Neue Spieler',
      if (isVoS) 'noTeacher': 'Ohne Lehrer',
      if (isVoS) 'noTest': 'Testergebnis fehlt',
      if (hasLinked || _filterOption == 'otherInstance')
        'otherInstance': 'Mitglied anderer Instanz',
      for (final f in _filterableExtraFields(tenant)) 'extra:${f.id}': f.name,
    };
  }

  /// Sort options in Ionic order (list.page.html sort select).
  Map<String, String> _sortOptionLabels(Tenant? tenant) => {
        'group': 'Gruppe',
        'firstName': 'Vorname',
        'lastName': 'Nachname',
        'attAsc': 'Anwesenheit ↑',
        'attDesc': 'Anwesenheit ↓',
        'birthdayAsc': 'Geburtsdatum ↑',
        'birthdayDesc': 'Geburtsdatum ↓',
        'joinedAsc': 'Beitrittsdatum ↑',
        'joinedDesc': 'Beitrittsdatum ↓',
        'nextBirthday': 'Nächster Geburtstag',
        if (_isVoS(tenant)) 'testResult': 'Testergebnis',
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
    setState(() {
      _filterOption = value;
      _extraFilterValue = null;
    });
  }

  void _onSortSelected(String value) {
    setState(() => _sortOption = value);
    _saveSortOption();
  }

  /// Ionic filter popover: Filter (funnel), Sortierung (filter), Ansicht
  /// (eye), Gemeinde-Übersicht, Bulk-Bearbeitung, Personen importieren,
  /// Reihenfolge anpassen.
  Future<void> _showOptionsSheet({required bool isAdmin}) async {
    final tenant = ref.read(currentTenantProvider);
    final filterLabels = _filterOptionLabels(tenant);
    final sortLabels = _sortOptionLabels(tenant);
    final viewLabels = _viewOptionLabels(tenant);
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _OptionDropdownTile(
                icon: Icons.filter_alt,
                label: 'Filter',
                value: filterLabels.containsKey(_filterOption)
                    ? _filterOption
                    : 'all',
                options: filterLabels,
                onChanged: (v) => Navigator.pop(ctx, 'filter:$v'),
              ),
              _OptionDropdownTile(
                icon: Icons.filter_list,
                label: 'Sortierung',
                value: sortLabels.containsKey(_sortOption) ? _sortOption : 'group',
                options: sortLabels,
                onChanged: (v) => Navigator.pop(ctx, 'sort:$v'),
              ),
              ListTile(
                leading: const Icon(Icons.visibility, size: 20),
                title: const Text('Ansicht'),
                subtitle: Text(
                  viewLabels.entries
                      .where((e) => _viewOptions.contains(e.key))
                      .map((e) => e.value)
                      .join(', '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.arrow_drop_down),
                onTap: () => Navigator.pop(ctx, 'view'),
              ),
              if (_churchField(tenant) != null)
                ListTile(
                  leading: const Icon(Icons.business_outlined, size: 20),
                  title: const Text('Gemeinde-Übersicht'),
                  onTap: () => Navigator.pop(ctx, 'churchOverview'),
                ),
              if (isAdmin) ...[
                ListTile(
                  leading: const Icon(Icons.edit, size: 20),
                  title: const Text('Bulk-Bearbeitung'),
                  onTap: () => Navigator.pop(ctx, 'bulkEdit'),
                ),
                ListTile(
                  leading: const Icon(Icons.cloud_upload_outlined, size: 20),
                  title: const Text('Personen importieren'),
                  onTap: () => Navigator.pop(ctx, 'import'),
                ),
                if (_sortOption == 'group')
                  ListTile(
                    leading: const Icon(Icons.swap_vert, size: 20),
                    title: const Text('Reihenfolge anpassen'),
                    onTap: () => Navigator.pop(ctx, 'reorder'),
                  ),
                // Flutter extra: multi-select handover (Ionic only has the
                // handover page in the settings)
                ListTile(
                  leading: const Icon(Icons.checklist, size: 20),
                  title: const Text('Personen übertragen'),
                  onTap: () => Navigator.pop(ctx, 'select'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
    if (action == null || !mounted) return;
    if (action.startsWith('filter:')) {
      await _onFilterSelected(action.substring(7));
    } else if (action.startsWith('sort:')) {
      _onSortSelected(action.substring(5));
    } else {
      switch (action) {
        case 'view':
          await _showViewOptionsDialog();
        case 'churchOverview':
          await _showChurchOverview();
        case 'bulkEdit':
          await _openBulkEdit();
        case 'import':
          await _openImport();
        case 'reorder':
          await _toggleReorderMode();
        case 'select':
          _enterSelectionMode();
      }
    }
  }

  List<ExtraField> _filterableExtraFields(Tenant? tenant) =>
      (tenant?.additionalFields ?? const <ExtraField>[])
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
      value = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(field.name),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(hintText: 'Wert eingeben'),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Abbrechen')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, controller.text.trim()),
                child: const Text('Filtern')),
          ],
        ),
      );
      controller.dispose();
    } else {
      final List<MapEntry<String, String>> choices;
      if (field.type == 'boolean') {
        choices = const [MapEntry('true', 'Ja'), MapEntry('false', 'Nein')];
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
      value = await showDialog<String>(
        context: context,
        builder: (ctx) => SimpleDialog(
          title: Text(field.name),
          children: choices
              .map((c) => SimpleDialogOption(
                    onPressed: () => Navigator.pop(ctx, c.key),
                    child: Text(c.value),
                  ))
              .toList(),
        ),
      );
    }

    if (!mounted) return;
    setState(() {
      if (value == null || value.isEmpty) {
        _filterOption = 'all';
        _extraFilterValue = null;
      } else {
        _filterOption = option;
        _extraFilterValue = value;
      }
    });
  }

  // ---------------------------------------------------------------------
  // PEOPLE2: other-instance filter, church overview, reorder mode
  // ---------------------------------------------------------------------

  bool _isVoS(Tenant? tenant) => tenant?.shortName == 'VoS';

  ExtraField? _churchField(Tenant? tenant) =>
      (tenant?.additionalFields ?? const <ExtraField>[])
          .where((f) => f.type == 'bfecg_church')
          .firstOrNull;

  /// Ionic onFilterChanged('otherInstance'): pick a linked instance and show
  /// only people whose account is also a member there.
  Future<void> _selectOtherInstanceFilter() async {
    final linked = await ref.read(allLinkedTenantsProvider.future);
    if (!mounted) return;
    if (linked.isEmpty) {
      setState(() => _filterOption = 'all');
      return;
    }
    final chosen = await showDialog<Tenant>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Instanz wählen'),
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
      final ids = await ref
          .read(crossTenantPersonRepositoryWithTenantProvider)
          .getUserIdsInTenant(chosen.id!, linkedTenantIds: linkedIds);
      if (!mounted) return;
      setState(() {
        _filterOption = 'otherInstance';
        _extraFilterValue = null;
        _otherInstanceUserIds = ids;
        _otherInstanceName =
            chosen.longName.isNotEmpty ? chosen.longName : chosen.shortName;
      });
    } catch (e) {
      if (mounted) ToastHelper.showError(context, 'Fehler: $e');
    }
  }

  /// "Gemeinde-Übersicht" (Ionic showChurchOverview): church counts of the
  /// currently filtered people.
  Future<void> _showChurchOverview() async {
    final field = _churchField(ref.read(currentTenantProvider));
    if (field == null) return;
    final people = ref.read(realtimePlayersProvider).valueOrNull ?? const [];
    final churchIds = _filterPeople(people)
        .map((p) => churchIdOf(p.additionalFields, field.id))
        .toList();
    final churches = await ref.read(churchesProvider.future);
    if (!mounted) return;
    await showChurchOverviewSheet(
      context,
      churchIds: churchIds,
      churches: churches,
      subtitle: 'Personen',
    );
  }

  /// Ionic toggleReorderMode: enter reorder mode, or save the new order.
  Future<void> _toggleReorderMode() async {
    if (!_isReordering) {
      final people = ref.read(realtimePlayersProvider).valueOrNull ?? [];
      final grouped = _groupByGroup(_sortPeople(_filterPeople(people)));
      setState(() {
        _reorderIds
          ..clear()
          ..addAll(grouped.map((k, v) =>
              MapEntry(k, v.map((p) => p.id).whereType<int>().toList())));
        _isReordering = true;
        _sortOption = 'group';
      });
      return;
    }

    final orders = <int, int>{};
    for (final ids in _reorderIds.values) {
      for (var i = 0; i < ids.length; i++) {
        orders[ids[i]] = i + 1;
      }
    }
    setState(() => _isSavingOrder = true);
    try {
      await ref.read(playerRepositoryWithTenantProvider).savePlayerOrder(orders);
      ref.invalidate(realtimePlayersProvider);
      if (mounted) ToastHelper.showSuccess(context, 'Reihenfolge gespeichert');
    } catch (_) {
      if (mounted) {
        ToastHelper.showError(context, 'Fehler beim Speichern der Reihenfolge');
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
                final moved = ids.removeAt(oldIndex);
                ids.insert(newIndex, moved);
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
                      child: const Icon(Icons.drag_handle),
                    ),
                    title: Text(
                        byId[_reorderIds[groupName]![i]]?.fullName ?? '?'),
                  ),
                ),
            ],
          ),
        ],
        const SizedBox(height: 80),
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
    final people = ref.read(realtimePlayersProvider).valueOrNull ?? [];
    final players = _sortPeople(_filterPeople(people));
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => BulkEditPage(players: players),
      ),
    );
    if (updated == true && mounted) {
      ref.invalidate(realtimePlayersProvider);
      ref.invalidate(peopleListProvider);
    }
  }

  // PEOPLE_IMPORT: open the person import
  Future<void> _openImport() async {
    final imported = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const PersonImportPage(),
      ),
    );
    if (imported == true && mounted) {
      ref.invalidate(realtimePlayersProvider);
      ref.invalidate(peopleListProvider);
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Person wieder aktivieren?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Aktivieren'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final repository = ref.read(playerRepositoryWithTenantProvider);
    try {
      await repository.unpausePlayer(person, historyText: 'Person wieder aktiv');
      // Realtime handles the refresh automatically
    } catch (e) {
      if (mounted) ToastHelper.showError(context, 'Fehler: $e');
    }
  }

  /// Ionic remove(): action sheet "Archivieren" / "Entfernen" / "Abbrechen".
  Future<void> _remove(Person person) async {
    final userId = ref.read(supabaseClientProvider).auth.currentUser?.id;
    if (person.appId != null && person.appId == userId) {
      ToastHelper.showError(context, 'Du kannst dich nicht selbst entfernen!');
      return;
    }
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Archivieren', textAlign: TextAlign.center),
              onTap: () => Navigator.pop(ctx, 'archive'),
            ),
            ListTile(
              title: const Text('Entfernen', textAlign: TextAlign.center),
              onTap: () => Navigator.pop(ctx, 'remove'),
            ),
            const Divider(height: 1),
            ListTile(
              title: const Text(
                'Abbrechen',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              onTap: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (choice == 'archive') await _showArchiveDialog(person);
    if (choice == 'remove') await _removePlayer(person);
  }

  /// Ionic archive modal: "{name} Archivieren" with Austrittsdatum + Notiz.
  Future<void> _showArchiveDialog(Person person) async {
    final noteController = TextEditingController();
    DateTime archiveDate = DateTime.now();

    try {
      final result = await showDialog<Map<String, dynamic>>(
        context: context,
        barrierDismissible: false,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text('${person.firstName} ${person.lastName} Archivieren'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Austrittsdatum'),
                  subtitle: Text(DateFormat('dd.MM.yyyy').format(archiveDate)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: archiveDate,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (date != null) {
                      setDialogState(() => archiveDate = date);
                    }
                  },
                ),
                TextField(
                  controller: noteController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(labelText: 'Notiz'),
                  maxLines: 3,
                  minLines: 1,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Abbrechen'),
              ),
              FilledButton.icon(
                icon: const Icon(Icons.archive_outlined),
                onPressed: () {
                  Navigator.pop(context, {
                    'date': archiveDate.toIso8601String(),
                    'note': noteController.text,
                  });
                },
                label: const Text('Archivieren'),
              ),
            ],
          ),
        ),
      );

      if (result != null && mounted) {
        await _archivePerson(person,
            date: result['date'] as String, note: result['note'] as String);
      }
    } finally {
      noteController.dispose();
    }
  }

  /// Archive a person
  Future<void> _archivePerson(Person person, {String? date, String? note}) async {
    final repository = ref.read(playerRepositoryWithTenantProvider);
    try {
      await repository.archivePlayer(
        person,
        date ?? DateTime.now().toIso8601String(),
        note?.isEmpty == true ? null : note,
      );
      // Realtime handles the refresh automatically
    } catch (e) {
      if (mounted) ToastHelper.showError(context, 'Fehler: $e');
    }
  }

  /// Ionic removePlayer: alert "Person wirklich entfernen?".
  Future<void> _removePlayer(Person person) async {
    HapticHelper.medium(); // MEDIA_REALTIME: Ionic Haptics.impact Medium
    final confirmed = await DialogHelper.showConfirmation(
      context,
      title: 'Person wirklich entfernen?',
      message: 'Diese Aktion kann nicht rückgängig gemacht werden!',
      confirmText: 'Entfernen',
      isDestructive: true,
    );

    if (confirmed == true && mounted && person.id != null) {
      try {
        await ref.read(playerNotifierProvider.notifier).deletePlayer(person.id!);
        if (mounted) ToastHelper.showSuccess(context, 'Person wurde entfernt.');
      } catch (e) {
        if (mounted) ToastHelper.showError(context, 'Fehler: $e');
      }
    }
  }
}

/// Ionic ion-list-header ("Personen (n)").
class _ListHeader extends StatelessWidget {
  const _ListHeader({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppDimensions.paddingM, AppDimensions.paddingS, AppDimensions.paddingM, 4),
      child: Text(
        text,
        style: Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }
}

/// Ionic ion-item-divider color="primary" (group header).
class _GroupDivider extends StatelessWidget {
  const _GroupDivider({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.primary,
      padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.paddingM, vertical: 6),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
    );
  }
}

/// One option row of the options popover (icon + dropdown, Ionic ion-select
/// interface="popover").
class _OptionDropdownTile extends StatelessWidget {
  const _OptionDropdownTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final String value;
  final Map<String, String> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, size: 20),
      title: Text(label),
      trailing: DropdownButton<String>(
        value: value,
        underline: const SizedBox.shrink(),
        items: [
          for (final e in options.entries)
            DropdownMenuItem(value: e.key, child: Text(e.value)),
        ],
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    );
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

  String _extraValueText(ExtraField field, dynamic value) {
    if (field.type == 'bfecg_church') {
      return churchNames[value?.toString()] ?? 'Unbekannt';
    }
    return value.toString();
  }

  bool _hasExtraValue(dynamic v) => v != null && v != false && v != '';

  /// Ionic getSubText: Gruppe | Geburtsdatum | Testergebnis | Instrumente |
  /// Sonstige Dienste, joined with " | ".
  String get _subText {
    final parts = <String>[];
    if (viewOptions.contains('group') && person.groupName != null) {
      parts.add(person.groupName!);
    }
    if (viewOptions.contains('birthday') && person.birthday != null) {
      final date = DateTime.tryParse(person.birthday!);
      if (date != null) {
        parts.add(
            '${DateFormat('dd.MM.yyyy').format(date)} (${ageInYears(person.birthday!)} J.)');
      }
    }
    if (viewOptions.contains('test')) {
      parts.add((person.testResult?.isNotEmpty ?? false)
          ? person.testResult!
          : 'Kein Ergebnis');
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
    const h3 = TextStyle(fontSize: 14);
    final p = TextStyle(fontSize: 13, color: Theme.of(context).hintColor);
    final sub = _subText;
    return [
      if (sub.isNotEmpty) Text(sub, style: h3),
      if (!isMainGroup && viewOptions.contains('teacher'))
        Text(
          person.teacherName != null
              ? 'Lehrer: ${person.teacherName}'
              : 'Kein Lehrer',
          style: h3,
        ),
      if (otherInstanceName != null) Text(otherInstanceName!, style: h3),
      if (viewOptions.contains('notes') && (person.notes?.isNotEmpty ?? false))
        Text(person.notes!, style: p),
      for (final f in extraFields)
        if (viewOptions.contains('extra:${f.id}') &&
            f.displayMode == 'underneath' &&
            _hasExtraValue(person.additionalFields?[f.id]))
          Text(
            f.type == 'boolean'
                ? f.name
                : '${f.name}: ${_extraValueText(f, person.additionalFields?[f.id])}',
            style: h3,
          ),
    ];
  }

  /// Badges on the right (slot="end"), same order and colors as Ionic.
  List<Widget> get _badges {
    final showPaused = viewOptions.contains('paused');
    final notHiddenByPause = !showPaused || !person.paused;
    return [
      if (notHiddenByPause && viewOptions.contains('leader') && person.isLeader)
        const _IonBadge(text: 'Stimmführer', color: AppColors.secondary),
      if (notHiddenByPause &&
          viewOptions.contains('new') &&
          isNewPerson(person) &&
          !person.isLeader)
        const _IonBadge(text: 'Neu', color: AppColors.danger),
      if (notHiddenByPause && viewOptions.contains('critical') && person.isCritical)
        const _IonBadge(text: 'Problemfall', color: AppColors.danger),
      if (showPaused && person.paused)
        const _IonBadge(
            text: 'Pausiert', color: AppColors.warning, textColor: Colors.black),
      if (viewOptions.contains('examinee') && person.examinee)
        const _IonBadge(text: 'Prüfling', color: AppColors.dark),
      for (final f in extraFields)
        if (viewOptions.contains('extra:${f.id}') &&
            f.displayMode != 'underneath' &&
            _hasExtraValue(person.additionalFields?[f.id]))
          _IonBadge(
            text: switch (f.type) {
              'boolean' => f.name,
              'number' => '${f.name} ${person.additionalFields?[f.id]}',
              _ => _extraValueText(f, person.additionalFields?[f.id]),
            },
            color: f.type == 'boolean' ? AppColors.success : AppColors.dark,
          ),
      if (viewOptions.contains('attendance') && attendancePercentage != null)
        _IonBadge(
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
    final badges = _badges;
    final tile = InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : null,
          border: Border(
            bottom: BorderSide(color: Theme.of(context).dividerColor, width: 0.5),
          ),
        ),
        padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.paddingM, vertical: 10),
        child: Row(
          children: [
            if (isSelectionMode)
              Checkbox(value: isSelected, onChanged: (_) => onTap()),
            if (showPhoto) ...[
              _Avatar(person: person),
              const SizedBox(width: AppDimensions.paddingM),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${person.firstName} ${person.lastName}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  ..._lines(context),
                ],
              ),
            ),
            if (badges.isNotEmpty)
              Flexible(
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 4,
                  runSpacing: 4,
                  children: badges,
                ),
              ),
          ],
        ),
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
              icon: Icons.delete,
            ),
          if (pauseAction != null)
            SlidableAction(
              onPressed: (_) => pauseAction(),
              backgroundColor:
                  person.paused ? AppColors.success : AppColors.warning,
              foregroundColor: person.paused ? Colors.white : Colors.black,
              icon: person.paused ? Icons.play_arrow : Icons.pause,
            ),
        ],
      ),
      child: tile,
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.person});

  final Person person;

  @override
  Widget build(BuildContext context) {
    final url = person.imageUrl;
    final hasImage = url != null && url.isNotEmpty && !url.contains('.svg');
    return CircleAvatar(
      radius: 20,
      backgroundColor: AppColors.primaryLight.withValues(alpha: 0.2),
      backgroundImage: hasImage ? NetworkImage(url) : null,
      child: hasImage
          ? null
          : const Icon(Icons.person, color: AppColors.medium),
    );
  }
}

/// Ionic ion-badge: filled, rounded, small bold text.
class _IonBadge extends StatelessWidget {
  const _IonBadge({
    required this.text,
    required this.color,
    this.textColor = Colors.white,
  });

  final String text;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

/// Banner listing people whose birthday is today.
class _BirthdayBanner extends StatelessWidget {
  const _BirthdayBanner({required this.people, required this.onTap});

  final List<Person> people;
  final void Function(Person) onTap;

  @override
  Widget build(BuildContext context) {
    if (people.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppDimensions.paddingM,
        0,
        AppDimensions.paddingM,
        AppDimensions.paddingS,
      ),
      padding: const EdgeInsets.all(AppDimensions.paddingS),
      decoration: BoxDecoration(
        color: AppColors.warning.withAlpha(31),
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
        border: Border.all(color: AppColors.warning.withAlpha(102)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.card_giftcard, color: AppColors.warning, size: 20),
              const SizedBox(width: 8),
              Text(
                people.length == 1
                    ? 'Geburtstag heute'
                    : '${people.length} Geburtstage heute',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: people.map((p) {
              final age = p.birthday != null ? ageInYears(p.birthday!) : 0;
              return ActionChip(
                avatar: p.img != null && p.img!.isNotEmpty
                    ? CircleAvatar(backgroundImage: NetworkImage(p.img!))
                    : const Text('🎂'),
                label: Text(
                    '${p.firstName} ${p.lastName} · ${age == 1 ? '1 Jahr' : '$age Jahre'}'),
                onPressed: () => onTap(p),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
