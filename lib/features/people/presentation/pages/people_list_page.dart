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
import '../../../../shared/widgets/animations/animated_list_item.dart';
import '../widgets/handover_sheet.dart';
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
                // Select all button
                IconButton(
                  icon: const Icon(Icons.select_all),
                  tooltip: 'Alle auswählen',
                  onPressed: () {
                    final people = ref.read(realtimePlayersProvider).valueOrNull ?? [];
                    final filtered = _filterPeople(people);
                    setState(() {
                      _selectedPlayerIds.clear();
                      for (final p in filtered) {
                        if (p.id != null) _selectedPlayerIds.add(p.id!);
                      }
                    });
                  },
                ),
                // Clear selection button
                IconButton(
                  icon: const Icon(Icons.deselect),
                  tooltip: 'Auswahl aufheben',
                  onPressed: () {
                    setState(() => _selectedPlayerIds.clear());
                  },
                ),
              ]
            : [
                const NotificationBell(), // MESSAGES
                // Selection mode toggle
                IconButton(
                  icon: const Icon(Icons.checklist),
                  tooltip: 'Auswahl-Modus',
                  onPressed: _enterSelectionMode,
                ),
                // Filter button
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.filter_list,
                    color: _filterOption != 'all' ? AppColors.primary : null,
                  ),
                  tooltip: 'Filter',
                  onSelected: (value) async {
                    if (value.startsWith('extra:')) {
                      await _selectExtraFieldFilter(value);
                      return;
                    }
                    if (value == 'otherInstance') {
                      await _selectOtherInstanceFilter();
                      return;
                    }
                    if (value == 'churchOverview') {
                      _showChurchOverview();
                      return;
                    }
                    if (value == 'reorder') {
                      _toggleReorderMode();
                      return;
                    }
                    setState(() {
                      _filterOption = value;
                      _extraFilterValue = null;
                    });
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'all', child: Text('Alle')),
                    const PopupMenuItem(value: 'active', child: Text('Aktiv')),
                    const PopupMenuItem(value: 'paused', child: Text('Pausiert')),
                    const PopupMenuItem(value: 'critical', child: Text('Kritisch')),
                    const PopupMenuItem(value: 'leaders', child: Text('Leiter')),
                    const PopupMenuDivider(),
                    const PopupMenuItem(value: 'noAccount', child: Text('Ohne Account')),
                    const PopupMenuItem(value: 'noTeacher', child: Text('Ohne Lehrer')),
                    if (tenant != null && tenant.type != 'general')
                      const PopupMenuItem(value: 'examinees', child: Text('Prüflinge')),
                    if (tenant != null && tenant.type != 'general')
                      const PopupMenuItem(value: 'noTest', child: Text('Ohne Test')),
                    if (_isVoS(tenant))
                      const PopupMenuItem(value: 'new', child: Text('Neue Spieler')),
                    if ((ref.watch(allLinkedTenantsProvider).valueOrNull ?? const [])
                        .isNotEmpty)
                      const PopupMenuItem(
                        value: 'otherInstance',
                        child: Text('Mitglied anderer Instanz'),
                      ),
                    if (_filterableExtraFields(tenant).isNotEmpty)
                      const PopupMenuDivider(),
                    ..._filterableExtraFields(tenant).map((f) => PopupMenuItem(
                          value: 'extra:${f.id}',
                          child: Text(f.name),
                        )),
                    if (_churchField(tenant) != null) ...[
                      const PopupMenuDivider(),
                      const PopupMenuItem(
                        value: 'churchOverview',
                        child: ListTile(
                          leading: Icon(Icons.business_outlined),
                          title: Text('Gemeinde-Übersicht'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                    if (_sortOption == 'group' &&
                        (ref.watch(currentRoleProvider).isAdmin ||
                            ref.watch(currentRoleProvider).isResponsible)) ...[
                      const PopupMenuDivider(),
                      const PopupMenuItem(
                        value: 'reorder',
                        child: ListTile(
                          leading: Icon(Icons.swap_vert),
                          title: Text('Reihenfolge anpassen'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ],
                ),
                // Sort button
                PopupMenuButton<String>(
                  icon: const Icon(Icons.sort),
                  tooltip: 'Sortierung',
                  onSelected: (value) {
                    setState(() {
                      _sortOption = value;
                    });
                  },
                  itemBuilder: (context) => [
                    _buildSortMenuItem('group', 'Nach Gruppe'),
                    _buildSortMenuItem('lastName', 'Nach Nachname'),
                    _buildSortMenuItem('firstName', 'Nach Vorname'),
                    const PopupMenuDivider(),
                    _buildSortMenuItem('birthdayAsc', 'Geburtstag (älteste)'),
                    _buildSortMenuItem('birthdayDesc', 'Geburtstag (jüngste)'),
                    _buildSortMenuItem('nextBirthday', 'Nächster Geburtstag'),
                    const PopupMenuDivider(),
                    _buildSortMenuItem('joinedAsc', 'Beitritt (älteste)'),
                    _buildSortMenuItem('joinedDesc', 'Beitritt (neueste)'),
                    if (tenant != null && tenant.type != 'general')
                      _buildSortMenuItem('testResult', 'Testergebnis'),
                    const PopupMenuDivider(),
                    _buildSortMenuItem('attAsc', 'Anwesenheit (aufsteigend)'),
                    _buildSortMenuItem('attDesc', 'Anwesenheit (absteigend)'),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.settings_outlined),
                  tooltip: 'Ansicht',
                  onPressed: _showViewOptionsDialog,
                ),
                // PEOPLE_IMPORT: bulk edit + import (Ionic: isAdmin = Admin/Responsible)
                if (ref.watch(currentRoleProvider).isAdmin ||
                    ref.watch(currentRoleProvider).isResponsible)
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    tooltip: 'Mehr',
                    onSelected: (value) {
                      if (value == 'bulkEdit') _openBulkEdit();
                      if (value == 'import') _openImport();
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: 'bulkEdit',
                        child: ListTile(
                          leading: Icon(Icons.edit),
                          title: Text('Bulk-Bearbeitung'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      PopupMenuItem(
                        value: 'import',
                        child: ListTile(
                          leading: Icon(Icons.cloud_upload_outlined),
                          title: Text('Personen importieren'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
              ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(AppDimensions.paddingM),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Suchen...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),

          // Active filter chip
          if (_filterOption != 'all')
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingM),
              child: Row(
                children: [
                  Chip(
                    label: Text(_getFilterLabel(_filterOption)),
                    deleteIcon: const Icon(Icons.close, size: 18),
                    onDeleted: () {
                      setState(() {
                        _filterOption = 'all';
                        _extraFilterValue = null;
                      });
                    },
                  ),
                ],
              ),
            ),

          // Birthday banner (Ionic people/list birthday-banner)
          if (!_isSelectionMode)
            _BirthdayBanner(
              people: todaysBirthdays(peopleAsync.valueOrNull ?? const []),
              onTap: (p) => context.push('/people/${p.id}'),
            ),

          // People list
          Expanded(
            child: peopleAsync.when(
              loading: () => const ListSkeleton(
                itemCount: 10,
                showAvatar: true,
                showSubtitle: true,
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
                  final role = ref.watch(currentRoleProvider);
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
                          if (role.isAdmin || role.isResponsible) ...[
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

                // Group by group if sorted by group
                if (_sortOption == 'group') {
                  // Keys keep the order of sortedPeople (sort_order aware)
                  final grouped = _groupByGroup(sortedPeople);
                  final groups = grouped.keys.toList();
                  
                  return RefreshIndicator(
                    onRefresh: () async {
                      // FN-007: invalidate for manual refresh (realtime handles automatic updates)
                      ref.invalidate(realtimePlayersProvider);
                    },
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimensions.paddingM,
                      ),
                      itemCount: groups.length,
                      itemBuilder: (context, groupIndex) {
                        final groupName = groups[groupIndex];
                        final groupPeople = grouped[groupName]!;
                        
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Group header
                            Padding(
                              padding: const EdgeInsets.only(
                                top: AppDimensions.paddingM,
                                bottom: AppDimensions.paddingS,
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    groupName,
                                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  const SizedBox(width: AppDimensions.paddingS),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryLight.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '${groupPeople.length}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Group members
                            ...groupPeople.asMap().entries.map((entry) {
                              final index = entry.key;
                              final person = entry.value;
                              final isSelected = person.id != null &&
                                  _selectedPlayerIds.contains(person.id);
                              return AnimatedListItem(
                                index: index,
                                child: _PersonListItem(
                                  person: person,
                                  isSelectionMode: _isSelectionMode,
                                  isSelected: isSelected,
                                  viewOptions: _viewOptions,
                                  extraFields: extraFields,
                                  churchNames: churchNames,
                                  onTap: _isSelectionMode && person.id != null
                                      ? () => _togglePlayerSelection(person.id!)
                                      : () => context.push('/people/${person.id}'),
                                  onPause: () => _showPauseDialog(person),
                                  onUnpause: () => _unpausePerson(person),
                                  onArchive: () => _showArchiveDialog(person),
                                  onDelete: ref.watch(currentRoleProvider).isConductor
                                      ? () => _showDeleteDialog(person)
                                      : null,
                                  attendancePercentage: person.id != null
                                      ? percentages[person.id]
                                      : null,
                                ),
                              );
                            }),
                          ],
                        );
                      },
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    // FN-002: Use same provider as display (realtimePlayersProvider)
                    ref.invalidate(realtimePlayersProvider);
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.paddingM,
                    ),
                    itemCount: sortedPeople.length,
                    itemBuilder: (context, index) {
                      final person = sortedPeople[index];
                      final isSelected = person.id != null &&
                          _selectedPlayerIds.contains(person.id);
                      return AnimatedListItem(
                        index: index,
                        child: _PersonListItem(
                          person: person,
                          isSelectionMode: _isSelectionMode,
                          isSelected: isSelected,
                          viewOptions: _viewOptions,
                          extraFields: extraFields,
                          churchNames: churchNames,
                          onTap: _isSelectionMode && person.id != null
                              ? () => _togglePlayerSelection(person.id!)
                              : () => context.push('/people/${person.id}'),
                          onPause: () => _showPauseDialog(person),
                          onUnpause: () => _unpausePerson(person),
                          onArchive: () => _showArchiveDialog(person),
                          onDelete: ref.watch(currentRoleProvider).isConductor
                              ? () => _showDeleteDialog(person)
                              : null,
                          attendancePercentage: person.id != null
                              ? percentages[person.id]
                              : null,
                        ),
                      );
                    },
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
          : FloatingActionButton(
              onPressed: () => context.push('/people/new'),
              child: const Icon(Icons.add),
            ),
    );
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

  /// "Gemeinde-Übersicht" (Ionic showChurchOverview).
  void _showChurchOverview() {
    // TODO(PEOPLE2): open the ChurchOverview widget built by ATT_DETAIL once
    // it is merged, passing the church ids of the filtered people:
    //   _filterPeople(people).map((p) => p.additionalFields?[field.id])
    ToastHelper.showInfo(context, 'Gemeinde-Übersicht ist noch nicht verfügbar');
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

  String _getFilterLabel(String filter) {
    if (filter.startsWith('extra:')) {
      final field = _filterableExtraFields(ref.read(currentTenantProvider))
          .where((f) => f.id == filter.substring(6))
          .firstOrNull;
      final v = _extraFilterValue;
      final display = v == 'true'
          ? 'Ja'
          : v == 'false'
              ? 'Nein'
              : v;
      return '${field?.name ?? 'Feld'}: ${display ?? ''}';
    }
    return switch (filter) {
      'critical' => 'Kritisch',
      'paused' => 'Pausiert',
      'leaders' => 'Leiter',
      'active' => 'Aktiv',
      'noAccount' => 'Ohne Account',
      'examinees' => 'Prüflinge',
      'noTeacher' => 'Ohne Lehrer',
      'noTest' => 'Ohne Test',
      'new' => 'Neue Spieler',
      'otherInstance' => 'Mitglied anderer Instanz: ${_otherInstanceName ?? ''}',
      _ => 'Alle',
    };
  }

  PopupMenuItem<String> _buildSortMenuItem(String value, String label) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          if (_sortOption == value)
            const Icon(Icons.check, size: 18, color: AppColors.primary)
          else
            const SizedBox(width: 18),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
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
    await pausePersonFlow(context, ref, person);
  }

  /// Unpause a person
  Future<void> _unpausePerson(Person person) async {
    final repository = ref.read(playerRepositoryWithTenantProvider);
    // Cache ScaffoldMessenger before async gap to avoid disposed context issues
    final messenger = ScaffoldMessenger.of(context);

    try {
      await repository.unpausePlayer(person);
      // Realtime handles the refresh automatically

      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('${person.firstName} wurde reaktiviert'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Fehler: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  /// Show archive dialog with date picker and note
  Future<void> _showArchiveDialog(Person person) async {
    final noteController = TextEditingController();
    DateTime archiveDate = DateTime.now();

    try {
      final result = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text('${person.firstName} archivieren?'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Die Person wird als "ausgetreten" markiert und erscheint nicht mehr in der aktiven Liste.',
                ),
                const SizedBox(height: AppDimensions.paddingM),
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
                      lastDate: DateTime.now(),
                    );
                    if (date != null) {
                      setDialogState(() => archiveDate = date);
                    }
                  },
                ),
                const SizedBox(height: AppDimensions.paddingS),
                TextField(
                  controller: noteController,
                  decoration: const InputDecoration(
                    labelText: 'Grund (optional)',
                    hintText: 'Warum verlässt die Person?',
                  ),
                  maxLines: 2,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Abbrechen'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
                onPressed: () {
                  Navigator.pop(context, {
                    'date': archiveDate.toIso8601String(),
                    'note': noteController.text,
                  });
                },
                child: const Text('Archivieren'),
              ),
            ],
          ),
        ),
      );

      if (result != null && mounted) {
        await _archivePerson(person,
            date: result['date'] as String,
            note: result['note'] as String);
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

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${person.firstName} wurde archiviert'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  Future<void> _showDeleteDialog(Person person) async {
    final confirmed = await DialogHelper.showConfirmation(
      context,
      title: '${person.firstName} endgültig entfernen?',
      message: 'Diese Aktion kann nicht rückgängig gemacht werden. '
          'Alle Daten von ${person.fullName} werden unwiderruflich gelöscht.',
      confirmText: 'Endgültig entfernen',
      isDestructive: true,
    );

    if (confirmed == true && mounted && person.id != null) {
      try {
        final notifier = ref.read(playerNotifierProvider.notifier);
        await notifier.deletePlayer(person.id!);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${person.firstName} wurde entfernt'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Fehler: $e'), backgroundColor: AppColors.danger),
          );
        }
      }
    }
  }
}

class _PersonListItem extends StatelessWidget {
  const _PersonListItem({
    required this.person,
    required this.onTap,
    this.isSelectionMode = false,
    this.isSelected = false,
    this.onPause,
    this.onUnpause,
    this.onArchive,
    this.onDelete,
    this.attendancePercentage,
    this.viewOptions = const {'group', 'paused', 'critical', 'leader'},
    this.extraFields = const [],
    this.churchNames = const {},
  });

  final Person person;
  final VoidCallback onTap;
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback? onPause;
  final VoidCallback? onUnpause;
  final VoidCallback? onArchive;
  final VoidCallback? onDelete;
  final int? attendancePercentage;
  final Set<String> viewOptions;
  final List<ExtraField> extraFields;
  final Map<String, String> churchNames;

  String _extraValueText(ExtraField field, dynamic value) {
    if (field.type == 'bfecg_church') {
      return churchNames[value?.toString()] ?? value.toString();
    }
    return value.toString();
  }

  bool _hasExtraValue(dynamic v) => v != null && v != false && v != '';

  /// Extra fields shown underneath the name (displayMode 'underneath')
  List<String> get _extraLines => [
        for (final f in extraFields)
          if (viewOptions.contains('extra:${f.id}') &&
              f.displayMode == 'underneath' &&
              _hasExtraValue(person.additionalFields?[f.id]))
            f.type == 'boolean'
                ? f.name
                : '${f.name}: ${_extraValueText(f, person.additionalFields?[f.id])}',
      ];

  /// Extra fields shown as badges
  List<String> get _extraBadges => [
        for (final f in extraFields)
          if (viewOptions.contains('extra:${f.id}') &&
              f.displayMode != 'underneath' &&
              _hasExtraValue(person.additionalFields?[f.id]))
            switch (f.type) {
              'boolean' => f.name,
              'number' => '${f.name} ${person.additionalFields?[f.id]}',
              _ => _extraValueText(f, person.additionalFields?[f.id]),
            },
      ];

  String? _buildSubtitle() {
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
    parts.addAll(_extraLines);
    if (viewOptions.contains('notes') && person.notes != null && person.notes!.isNotEmpty) {
      parts.add(person.notes!);
    }
    if (viewOptions.contains('teacher') && person.teacherName != null) {
      parts.add('Lehrer: ${person.teacherName}');
    }

    return parts.isNotEmpty ? parts.join(' | ') : null;
  }

  bool get _showPhoto => viewOptions.contains('photo');
  bool get _showLeaderBadge => viewOptions.contains('leader') && person.isLeader;
  bool get _showPausedBadge => viewOptions.contains('paused') && person.paused;
  bool get _showCriticalBadge => viewOptions.contains('critical') && person.critical;
  bool get _showNotesBadge => person.notes != null && person.notes!.isNotEmpty;
  bool get _showNewBadge =>
      viewOptions.contains('new') && isNewPerson(person) && !person.isLeader;
  bool get _showExamineeBadge =>
      viewOptions.contains('examinee') && person.examinee;
  bool get _showAttendance => viewOptions.contains('attendance');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // RT-004: Safe cast for cardShape - check type before casting
    final cardShape = theme.cardTheme.shape is RoundedRectangleBorder
        ? theme.cardTheme.shape as RoundedRectangleBorder
        : RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.borderRadiusL),
          );
    final cardBorderRadius =
        cardShape.borderRadius.resolve(Directionality.of(context));

    // In selection mode, don't use Slidable
    if (isSelectionMode) {
      return Padding(
        padding: const EdgeInsets.only(bottom: AppDimensions.paddingS),
        child: Card(
          margin: EdgeInsets.zero,
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.1)
              : null,
          child: ListTile(
            onTap: onTap,
            leading: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Checkbox(
                  value: isSelected,
                  onChanged: (_) => onTap(),
                ),
                CircleAvatar(
                  backgroundColor: person.critical
                      ? AppColors.danger.withValues(alpha: 0.2)
                      : person.paused
                          ? AppColors.warning.withValues(alpha: 0.2)
                          : AppColors.primaryLight.withValues(alpha: 0.2),
                  // RT-002: Use null-safe pattern for imageUrl
                  backgroundImage: (person.imageUrl?.contains('.svg') == false)
                      ? NetworkImage(person.imageUrl!)
                      : null,
                  child: (person.imageUrl == null ||
                          person.imageUrl!.contains('.svg'))
                      ? Text(
                          person.initials,
                          style: TextStyle(
                            color: person.critical
                                ? AppColors.danger
                                : person.paused
                                    ? AppColors.warning
                                    : AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      : null,
                ),
              ],
            ),
            title: Text(
              person.fullName,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: _buildSubtitle() != null
                ? Text(
                    _buildSubtitle()!,
                    style: const TextStyle(
                      color: AppColors.medium,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  )
                : null,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.paddingS),
      child: Slidable(
        key: ValueKey(person.id),
        // Swipe left for pause/unpause
        endActionPane: ActionPane(
          motion: const BehindMotion(),
          extentRatio: 0.25,
          children: [
            CustomSlidableAction(
              onPressed: (slideContext) {
                // Close the slidable first
                Slidable.of(slideContext)?.close();
                if (!person.paused && onPause != null) {
                  onPause!();
                } else if (person.paused && onUnpause != null) {
                  onUnpause!();
                }
              },
              backgroundColor: Colors.transparent,
              padding: EdgeInsets.zero,
              child: Container(
                margin: const EdgeInsets.only(left: AppDimensions.paddingS),
                decoration: BoxDecoration(
                  color: person.paused ? AppColors.success : AppColors.warning,
                  borderRadius: cardBorderRadius,
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        person.paused ? Icons.play_arrow : Icons.pause,
                        color: Colors.white,
                        size: 28,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        person.paused ? 'Aktiv' : 'Pause',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        // Swipe right for archive + delete
        startActionPane: (onArchive != null || onDelete != null)
            ? ActionPane(
                motion: const BehindMotion(),
                extentRatio: onArchive != null && onDelete != null ? 0.5 : 0.25,
                children: [
                  if (onArchive != null)
                    CustomSlidableAction(
                      onPressed: (slideContext) {
                        Slidable.of(slideContext)?.close();
                        onArchive!();
                      },
                      backgroundColor: Colors.transparent,
                      padding: EdgeInsets.zero,
                      child: Container(
                        margin:
                            const EdgeInsets.only(right: AppDimensions.paddingS),
                        decoration: BoxDecoration(
                          color: AppColors.danger,
                          borderRadius: cardBorderRadius,
                        ),
                        child: const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.archive,
                                color: Colors.white,
                                size: 28,
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Archiv',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  if (onDelete != null)
                    CustomSlidableAction(
                      onPressed: (slideContext) {
                        Slidable.of(slideContext)?.close();
                        onDelete!();
                      },
                      backgroundColor: Colors.transparent,
                      padding: EdgeInsets.zero,
                      child: Container(
                        margin:
                            const EdgeInsets.only(right: AppDimensions.paddingS),
                        decoration: BoxDecoration(
                          color: AppColors.dark,
                          borderRadius: cardBorderRadius,
                        ),
                        child: const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.delete_forever,
                                color: Colors.white,
                                size: 28,
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Löschen',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              )
            : null,
        child: Card(
          margin: EdgeInsets.zero,
          child: ListTile(
            onTap: onTap,
            leading: CircleAvatar(
              backgroundColor: person.critical
                  ? AppColors.danger.withValues(alpha: 0.2)
                  : person.paused
                      ? AppColors.warning.withValues(alpha: 0.2)
                      : AppColors.primaryLight.withValues(alpha: 0.2),
              // RT-002: Use null-safe pattern for imageUrl
              backgroundImage: (_showPhoto && person.imageUrl?.contains('.svg') == false)
                  ? NetworkImage(person.imageUrl!)
                  : null,
              child: (!_showPhoto || person.imageUrl == null || person.imageUrl!.contains('.svg'))
                  ? Text(
                      person.initials,
                      style: TextStyle(
                        color: person.critical
                            ? AppColors.danger
                            : person.paused
                                ? AppColors.warning
                                : AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  : null,
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    person.fullName,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
                if (_showLeaderBadge)
                  const Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Icon(
                      Icons.star,
                      size: 18,
                      color: AppColors.primary,
                    ),
                  ),
                if (_showPausedBadge)
                  const Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Icon(
                      Icons.pause_circle_outline,
                      size: 18,
                      color: AppColors.warning,
                    ),
                  ),
                if (_showCriticalBadge)
                  const Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Icon(
                      Icons.warning_amber,
                      size: 18,
                      color: AppColors.danger,
                    ),
                  ),
                if (_showNotesBadge)
                  const Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Icon(
                      Icons.sticky_note_2_outlined,
                      size: 16,
                      color: AppColors.medium,
                    ),
                  ),
                if (_showNewBadge)
                  const _TextBadge(text: 'Neu', color: AppColors.danger),
                if (_showExamineeBadge)
                  const _TextBadge(text: 'Prüfling', color: AppColors.dark),
                for (final b in _extraBadges)
                  Flexible(child: _TextBadge(text: b, color: AppColors.dark)),
              ],
            ),
            subtitle: _buildSubtitle() != null
                ? Text(
                    _buildSubtitle()!,
                    style: const TextStyle(
                      color: AppColors.medium,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  )
                : null,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_showAttendance && attendancePercentage != null)
                  _AttendanceBadge(percentage: attendancePercentage!),
                const Icon(
                  Icons.chevron_right,
                  color: AppColors.medium,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TextBadge extends StatelessWidget {
  const _TextBadge({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _AttendanceBadge extends StatelessWidget {
  const _AttendanceBadge({required this.percentage});

  final int percentage;

  @override
  Widget build(BuildContext context) {
    final color = percentage >= 80
        ? AppColors.success
        : percentage >= 50
            ? AppColors.warning
            : AppColors.danger;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      margin: const EdgeInsets.only(right: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$percentage%',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
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
