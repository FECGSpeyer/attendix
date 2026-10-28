import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/group_providers.dart';
import '../../../../core/providers/organisation_providers.dart';
import '../../../../core/providers/player_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/instrument/instrument.dart';
import '../../../../data/models/person/person.dart';
import '../../../../data/models/tenant/tenant.dart';

/// Data handed from the handover page to the detail page
/// (Ionic: DataService.setHandoverData).
class HandoverData {
  const HandoverData({
    required this.persons,
    required this.tenant,
    required this.stayInInstance,
  });

  final List<Person> persons;
  final Tenant tenant;
  final bool stayInInstance;
}

/// Personenübergabe – step 1: choose target tenant, filter and select persons
/// (Ionic settings/handover).
class HandoverPage extends ConsumerStatefulWidget {
  const HandoverPage({super.key});

  @override
  ConsumerState<HandoverPage> createState() => _HandoverPageState();
}

class _HandoverPageState extends ConsumerState<HandoverPage> {
  bool _stayInInstance = false;
  bool _includeMainGroup = false;
  int? _targetTenantId;
  final Set<int> _selected = {};
  final List<String> _filters = [];
  DateTime _date = DateTime.now();
  int? _groupId;
  bool _noTenantsToastShown = false;

  final _dateFormat = DateFormat('dd.MM.yyyy');

  List<Person> _filtered(List<Person> all, int? mainGroupId) {
    var list = _includeMainGroup
        ? all
        : all.where((p) => p.instrument != mainGroupId).toList();

    DateTime? birthday(Person p) =>
        p.birthday == null ? null : DateTime.tryParse(p.birthday!);

    if (_filters.contains('older')) {
      list = list.where((p) {
        final b = birthday(p);
        return b != null && _date.isAfter(b);
      }).toList();
    }
    if (_filters.contains('younger')) {
      list = list.where((p) {
        final b = birthday(p);
        return b != null && _date.isBefore(b);
      }).toList();
    }
    if (_filters.contains('group') && _groupId != null) {
      list = list.where((p) => p.instrument == _groupId).toList();
    }
    return list;
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date.isAfter(now) ? now : _date,
      firstDate: DateTime(1900),
      lastDate: now,
      locale: const Locale('de', 'DE'),
    );
    if (picked != null) setState(() => _date = picked);
  }

  @override
  Widget build(BuildContext context) {
    final playersAsync = ref.watch(playersProvider);
    final groups = ref.watch(groupsProvider).valueOrNull ?? const <Group>[];
    final mainGroupId = ref.watch(mainGroupProvider).valueOrNull?.id;
    final tenantsAsync = ref.watch(linkedTenantsProvider);
    final tenants = tenantsAsync.valueOrNull ?? const <Tenant>[];

    // Default target = first tenant of the organisation (Ionic)
    if (_targetTenantId == null && tenants.isNotEmpty) {
      _targetTenantId = tenants.first.id;
    }
    if (tenantsAsync.hasValue && tenants.isEmpty && !_noTenantsToastShown) {
      _noTenantsToastShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ToastHelper.showError(
            context,
            'Es sind keine weiteren Instanzen vorhanden. Bitte füge weitere '
            'Instanzen dieser Organisation hinzu.',
          );
        }
      });
    }
    _groupId ??= groups.isNotEmpty ? groups.first.id : null;

    final groupNames = {for (final g in groups) g.id: g.name};
    final filtered = _filtered(playersAsync.valueOrNull ?? const [], mainGroupId);
    final selectedPersons =
        filtered.where((p) => p.id != null && _selected.contains(p.id)).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Personenübergabe')),
      floatingActionButton: FloatingActionButton(
        onPressed: _targetTenantId == null || selectedPersons.isEmpty
            ? null
            : () {
                final tenant = tenants.firstWhere((t) => t.id == _targetTenantId);
                context.push(
                  '/settings/handover/detail',
                  extra: HandoverData(
                    persons: selectedPersons
                        .map((p) => p.copyWith(
                            groupName: p.groupName ?? groupNames[p.instrument]))
                        .toList(),
                    tenant: tenant,
                    stayInInstance: _stayInInstance,
                  ),
                );
              },
        backgroundColor: _targetTenantId == null || selectedPersons.isEmpty
            ? AppColors.medium
            : null,
        child: const Icon(Icons.arrow_forward),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppDimensions.paddingM,
          AppDimensions.paddingM,
          AppDimensions.paddingM,
          100,
        ),
        children: [
          const Card(
            child: Padding(
              padding: EdgeInsets.all(AppDimensions.paddingM),
              child: Column(
                children: [
                  Icon(Icons.directions_walk, size: 48, color: AppColors.primary),
                  SizedBox(height: AppDimensions.paddingS),
                  Text(
                    'Hiermit kannst du Personen innerhalb einer Organisation weitergeben '
                    'oder in einer andere Instanz kopieren. Falls die Person ein Account '
                    'hat, wird diese informiert.',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppDimensions.paddingM),
          Text('Einstellungen', style: Theme.of(context).textTheme.titleSmall),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Personen in Instanz behalten'),
                  subtitle: const Text(
                      'Die Person wird in der aktuellen Instanz nicht archiviert sondern bleibt aktiv'),
                  value: _stayInInstance,
                  onChanged: (v) => setState(() => _stayInInstance = v),
                ),
                SwitchListTile(
                  title: const Text('Hauptgruppe beachten'),
                  subtitle: const Text(
                      'Personen die in der Hauptgruppe sind, werden auch angezeigt'),
                  value: _includeMainGroup,
                  onChanged: (v) => setState(() => _includeMainGroup = v),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.paddingM,
                    vertical: AppDimensions.paddingS,
                  ),
                  child: DropdownButtonFormField<int>(
                    // ignore: deprecated_member_use
                    value: _targetTenantId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Ziel-Instanz'),
                    items: [
                      for (final t in tenants)
                        if (t.id != null)
                          DropdownMenuItem(value: t.id, child: Text(t.longName)),
                    ],
                    onChanged: (v) => setState(() => _targetTenantId = v),
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (f) => setState(() => _filters.add(f)),
                  itemBuilder: (context) => [
                    if (!_filters.contains('younger') && !_filters.contains('older')) ...[
                      const PopupMenuItem(value: 'younger', child: Text('Jünger als...')),
                      const PopupMenuItem(value: 'older', child: Text('Älter als...')),
                    ],
                    if (!_filters.contains('group'))
                      const PopupMenuItem(value: 'group', child: Text('Ist in der Gruppe...')),
                  ],
                  child: const ListTile(
                    leading: Icon(Icons.filter_list),
                    title: Text('Filter hinzufügen'),
                  ),
                ),
                if (_filters.contains('younger') || _filters.contains('older'))
                  ListTile(
                    title: Text(_filters.contains('younger') ? 'Jünger als' : 'Älter als'),
                    subtitle: Text(_dateFormat.format(_date)),
                    onTap: _pickDate,
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => setState(() {
                        _filters.remove(_filters.contains('younger') ? 'younger' : 'older');
                      }),
                    ),
                  ),
                if (_filters.contains('group'))
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingM),
                    child: Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            // ignore: deprecated_member_use
                            value: _groupId,
                            isExpanded: true,
                            decoration: const InputDecoration(labelText: 'Gruppe'),
                            items: [
                              for (final g in groups)
                                if (g.id != null)
                                  DropdownMenuItem(value: g.id, child: Text(g.name)),
                            ],
                            onChanged: (v) => setState(() => _groupId = v),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => setState(() => _filters.remove('group')),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppDimensions.paddingM),
          if (playersAsync.isLoading)
            const Center(child: CircularProgressIndicator())
          else if (filtered.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(AppDimensions.paddingM),
                child: Text('Keine Personen ausgewählt',
                    style: TextStyle(color: AppColors.danger)),
              ),
            )
          else ...[
            Row(
              children: [
                Expanded(
                  child: Text('Personenliste',
                      style: Theme.of(context).textTheme.titleSmall),
                ),
                TextButton(
                  onPressed: () => setState(() {
                    _selected
                      ..clear()
                      ..addAll(filtered.where((p) => p.id != null).map((p) => p.id!));
                  }),
                  child: const Text('Alle auswählen'),
                ),
              ],
            ),
            Card(
              child: Column(
                children: [
                  for (final p in filtered)
                    CheckboxListTile(
                      value: _selected.contains(p.id),
                      onChanged: p.id == null
                          ? null
                          : (v) => setState(() {
                                if (v == true) {
                                  _selected.add(p.id!);
                                } else {
                                  _selected.remove(p.id);
                                }
                              }),
                      title: Text('${p.firstName} ${p.lastName}'),
                      subtitle: Text([
                        if (p.birthday != null && DateTime.tryParse(p.birthday!) != null)
                          _dateFormat.format(DateTime.parse(p.birthday!)),
                        p.groupName ?? groupNames[p.instrument] ?? '',
                      ].join(' | ')),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
