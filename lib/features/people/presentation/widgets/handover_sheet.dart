import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/supabase_config.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/enums.dart';
import '../../../../core/providers/group_providers.dart';
import '../../../../core/providers/player_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/dialog_helper.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/instrument/instrument.dart';
import '../../../../data/models/person/person.dart';
import '../../../../data/models/tenant/tenant.dart';
import '../../../../l10n/l10n.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart'; // IOS_LOOK

/// Sheet for transferring players to another tenant (handover)
class HandoverSheet extends ConsumerStatefulWidget {
  final List<Person> selectedPlayers;
  final bool initialStayInInstance;

  const HandoverSheet({
    super.key,
    required this.selectedPlayers,
    this.initialStayInInstance = false,
  });

  @override
  ConsumerState<HandoverSheet> createState() => _HandoverSheetState();
}

class _HandoverSheetState extends ConsumerState<HandoverSheet> {
  int? _targetTenantId;
  bool _stayInInstance = false; // false = transfer, true = copy
  bool _isTransferring = false;
  String _progressMessage = '';
  final Map<int, int?> _groupMapping = {};
  List<Group> _targetGroups = [];
  bool _initialized = false;
  int? _sourceGroupFilter;
  int? _minAge;
  int? _maxAge;

  List<Person> get _filteredPlayers {
    var players = widget.selectedPlayers;
    if (_sourceGroupFilter != null) {
      players = players.where((p) => p.instrument == _sourceGroupFilter).toList();
    }
    if (_minAge != null || _maxAge != null) {
      final now = DateTime.now();
      players = players.where((p) {
        if (p.birthday == null) return false;
        final birthday = DateTime.tryParse(p.birthday!);
        if (birthday == null) return false;
        final age = now.year - birthday.year - (now.isBefore(DateTime(now.year, birthday.month, birthday.day)) ? 1 : 0);
        if (_minAge != null && age < _minAge!) return false;
        if (_maxAge != null && age > _maxAge!) return false;
        return true;
      }).toList();
    }
    return players;
  }

  @override
  void initState() {
    super.initState();
    _stayInInstance = widget.initialStayInInstance;
  }

  // FN-004: Move initialization to didChangeDependencies instead of build
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initializeTargetTenant();
    }
  }

  void _initializeTargetTenant() {
    final tenants = ref.read(userTenantsProvider).valueOrNull ?? [];
    final currentTenant = ref.read(currentTenantProvider);
    final availableTenants = tenants.where((t) => t.id != currentTenant?.id).toList();

    if (availableTenants.isNotEmpty && _targetTenantId == null) {
      _targetTenantId = availableTenants.first.id;
      _initialized = true;
      _loadTargetGroups();
    }
  }

  @override
  Widget build(BuildContext context) {
    final tenantsAsync = ref.watch(userTenantsProvider);
    final currentTenant = ref.watch(currentTenantProvider);
    final sourceGroupsAsync = ref.watch(groupsProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Header
            AppBar(
              toolbarHeight: ionModalToolbarHeight(context), // PARITY_R5
              title: Text(
                _stayInInstance ? context.l10n.peopleFlutterHandoverCopyTitle : context.l10n.peopleFlutterHandoverTransferTitle,
              ),
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
              automaticallyImplyLeading: false,
            ),

            // Content
            Expanded(
              child: tenantsAsync.when(
                loading: () => const Center(child: AppSpinner()),
                error: (e, _) => Center(child: Text(context.l10n.peopleFlutterErrorWith(friendlyErrorMessage(e)))),
                data: (tenants) {
                  // Filter out current tenant
                  final availableTenants = tenants
                      .where((t) => t.id != currentTenant?.id)
                      .toList();

                  if (availableTenants.isEmpty) {
                    return _buildNoTenantsMessage();
                  }

                  // FN-004: Initialization moved to didChangeDependencies
                  // Late init if provider wasn't ready in didChangeDependencies
                  if (_targetTenantId == null && !_initialized) {
                    _initializeTargetTenant();
                  }

                  return ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(AppDimensions.paddingM),
                    children: [
                      // Players summary
                      _buildPlayersSummary(),
                      const SizedBox(height: AppDimensions.paddingM),

                      // Mode toggle (copy vs transfer)
                      _buildModeToggle(),
                      const SizedBox(height: AppDimensions.paddingM),

                      // Target tenant dropdown
                      _buildTargetTenantDropdown(availableTenants),
                      const SizedBox(height: AppDimensions.paddingM),

                      // Group mapping section
                      if (_targetTenantId != null)
                        _buildGroupMappingSection(
                          sourceGroupsAsync.valueOrNull ?? [],
                        ),
                      const SizedBox(height: AppDimensions.paddingM),

                      // Info card
                      _buildInfoCard(),
                      const SizedBox(height: AppDimensions.paddingM),

                      // Progress indicator
                      if (_isTransferring) ...[
                        const LinearProgressIndicator(),
                        const SizedBox(height: AppDimensions.paddingS),
                        Center(
                          child: Text(
                            _progressMessage,
                            style: const TextStyle(color: AppColors.medium),
                          ),
                        ),
                        const SizedBox(height: AppDimensions.paddingM),
                      ],

                      // Transfer button
                      ElevatedButton.icon(
                        onPressed: _isTransferring
                            ? null
                            : () => _performHandover(currentTenant),
                        icon: _isTransferring
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    AppSpinner(strokeWidth: 2),
                              )
                            : Icon(_stayInInstance
                                ? Icons.copy
                                : Icons.swap_horiz),
                        label: Text(_isTransferring
                            ? context.l10n.peopleFlutterHandoverTransferring
                            : _stayInInstance
                                ? context.l10n.peopleFlutterHandoverCopy
                                : context.l10n.handoverTransfer),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 48),
                          backgroundColor:
                              _stayInInstance ? null : AppColors.warning,
                          disabledBackgroundColor: _stayInInstance
                              ? null
                              : AppColors.warning.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildNoTenantsMessage() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.business_outlined,
                size: 64, color: AppColors.medium),
            const SizedBox(height: AppDimensions.paddingM),
            Text(
              context.l10n.peopleFlutterHandoverNoTenants,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: AppDimensions.paddingS),
            Text(
              context.l10n.peopleFlutterHandoverNoTenantsHint,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.medium),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayersSummary() {
    final sourceGroups = ref.watch(groupsProvider).valueOrNull ?? [];
    // Only show groups that have selected players
    final relevantGroupIds = widget.selectedPlayers
        .where((p) => p.instrument != null)
        .map((p) => p.instrument!)
        .toSet();
    final relevantGroups = sourceGroups.where((g) => relevantGroupIds.contains(g.id)).toList();
    final players = _filteredPlayers;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.people, color: AppColors.primary),
                const SizedBox(width: AppDimensions.paddingS),
                Text(
                  context.l10n.peopleFlutterHandoverCount(players.length, widget.selectedPlayers.length),
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            if (relevantGroups.length > 1) ...[
              const SizedBox(height: AppDimensions.paddingS),
              SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: AppDimensions.paddingXS),
                      child: FilterChip(
                        label: Text(context.l10n.commonAll),
                        selected: _sourceGroupFilter == null,
                        onSelected: (_) => setState(() => _sourceGroupFilter = null),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                    ...relevantGroups.map((g) => Padding(
                          padding: const EdgeInsets.only(right: AppDimensions.paddingXS),
                          child: FilterChip(
                            label: Text(g.shortName ?? g.name),
                            selected: _sourceGroupFilter == g.id,
                            onSelected: (_) => setState(() =>
                                _sourceGroupFilter = _sourceGroupFilter == g.id ? null : g.id),
                            visualDensity: VisualDensity.compact,
                          ),
                        )),
                  ],
                ),
              ),
            ],
            // Age filter
            _buildAgeFilter(),
            const SizedBox(height: AppDimensions.paddingS),
            Wrap(
              spacing: AppDimensions.paddingS,
              runSpacing: AppDimensions.paddingXS,
              children: players.take(10).map((p) {
                return Chip(
                  label: Text(p.fullName),
                  avatar: CircleAvatar(
                    backgroundColor: AppColors.primary.withAlpha(50),
                    child: Text(
                      p.initials,
                      style: const TextStyle(fontSize: 10),
                    ),
                  ),
                );
              }).toList(),
            ),
            if (players.length > 10)
              Padding(
                padding: const EdgeInsets.only(top: AppDimensions.paddingS),
                child: Text(
                  context.l10n.peopleAndMore(players.length - 10),
                  style: const TextStyle(color: AppColors.medium),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAgeFilter() {
    // Check if any player has a birthday
    final hasBirthdays = widget.selectedPlayers.any((p) => p.birthday != null);
    if (!hasBirthdays) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: AppDimensions.paddingS),
      child: Row(
        children: [
          const Icon(Icons.cake_outlined, size: 16, color: AppColors.medium),
          const SizedBox(width: 8),
          SizedBox(
            width: 70,
            child: TextField(
              decoration: InputDecoration(
                labelText: context.l10n.peopleFlutterAgeFrom,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                suffixText: context.l10n.peopleFlutterAgeSuffix,
              ),
              keyboardType: TextInputType.number,
              onChanged: (value) => setState(() {
                _minAge = int.tryParse(value);
              }),
            ),
          ),
          const SizedBox(width: 8),
          const Text('–', style: TextStyle(color: AppColors.medium)),
          const SizedBox(width: 8),
          SizedBox(
            width: 70,
            child: TextField(
              decoration: InputDecoration(
                labelText: context.l10n.peopleFlutterAgeTo,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                suffixText: context.l10n.peopleFlutterAgeSuffix,
              ),
              keyboardType: TextInputType.number,
              onChanged: (value) => setState(() {
                _maxAge = int.tryParse(value);
              }),
            ),
          ),
          if (_minAge != null || _maxAge != null) ...[
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.clear, size: 18),
              onPressed: () => setState(() {
                _minAge = null;
                _maxAge = null;
              }),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildModeToggle() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.peopleFlutterHandoverMode,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.medium,
              ),
            ),
            const SizedBox(height: AppDimensions.paddingS),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: Text(context.l10n.handoverKeepInTenant),
              subtitle: Text(
                _stayInInstance
                    ? context.l10n.peopleFlutterHandoverModeCopy
                    : context.l10n.peopleFlutterHandoverModeTransfer,
                style: TextStyle(
                  color: _stayInInstance ? AppColors.success : AppColors.warning,
                ),
              ),
              value: _stayInInstance,
              onChanged: _isTransferring
                  ? null
                  : (value) {
                      setState(() => _stayInInstance = value);
                    },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTargetTenantDropdown(List<Tenant> tenants) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.handoverTargetTenant,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.medium,
              ),
            ),
            const SizedBox(height: AppDimensions.paddingS),
            AppDropdownFormField<int>(
              iosInterface: AppSelectInterface.alert, // IOS_THEME2
              value: _targetTenantId,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.business),
              ),
              items: tenants
                  .map((t) => DropdownMenuItem(
                        value: t.id,
                        child: Text(t.longName),
                      ))
                  .toList(),
              onChanged: _isTransferring
                  ? null
                  : (value) {
                      if (value != null) {
                        setState(() {
                          _targetTenantId = value;
                          _groupMapping.clear();
                          _targetGroups = [];
                        });
                        _loadTargetGroups();
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupMappingSection(List<Group> sourceGroups) {
    // Get unique instrument IDs from selected players
    final instrumentIds = widget.selectedPlayers
        .map((p) => p.instrument)
        .where((id) => id != null)
        .cast<int>()
        .toSet();

    if (instrumentIds.isEmpty) {
      return const SizedBox.shrink();
    }

    // Load target groups if not loaded
    if (_targetGroups.isEmpty && _targetTenantId != null) {
      _loadTargetGroups();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.handoverGroupMapping,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.medium,
              ),
            ),
            const SizedBox(height: AppDimensions.paddingS),
            Text(
              context.l10n.peopleFlutterHandoverMappingHint,
              style: const TextStyle(color: AppColors.medium, fontSize: 12),
            ),
            const SizedBox(height: AppDimensions.paddingM),
            ...instrumentIds.map((instrumentId) {
              final sourceGroup = sourceGroups.firstWhere(
                (g) => g.id == instrumentId,
                // BL-008: Consistent fallback label
                orElse: () => Group(id: instrumentId, name: context.l10n.peopleNoGroupAssigned),
              );

              // Auto-map if not already mapped
              if (!_groupMapping.containsKey(instrumentId)) {
                _groupMapping[instrumentId] = _autoMapGroup(
                  sourceGroup,
                  _targetGroups,
                );
              }

              return Padding(
                padding:
                    const EdgeInsets.only(bottom: AppDimensions.paddingS),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        sourceGroup.name,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                    const Icon(Icons.arrow_forward, color: AppColors.medium),
                    const SizedBox(width: AppDimensions.paddingS),
                    Expanded(
                      child: AppDropdownFormField<int?>(
                        iosInterface: AppSelectInterface.alert, // IOS_THEME2
                        value: _groupMapping[instrumentId],
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        items: [
                          DropdownMenuItem(
                            value: null,
                            child: Text(context.l10n.peopleFlutterHandoverNoMapping),
                          ),
                          ..._targetGroups.map((g) => DropdownMenuItem(
                                value: g.id,
                                child: Text(g.name),
                              )),
                        ],
                        onChanged: _isTransferring
                            ? null
                            : (value) {
                                setState(() {
                                  _groupMapping[instrumentId] = value;
                                });
                              },
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      color: (_stayInInstance ? AppColors.info : AppColors.warning)
          .withAlpha(20),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _stayInInstance ? Icons.info_outline : Icons.warning_amber,
                  color: _stayInInstance ? AppColors.info : AppColors.warning,
                ),
                const SizedBox(width: AppDimensions.paddingS),
                Text(
                  _stayInInstance ? context.l10n.peopleFlutterHint : context.l10n.peopleFlutterAttention,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color:
                        _stayInInstance ? AppColors.info : AppColors.warning,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.paddingS),
            Text(
              _stayInInstance
                  ? context.l10n.peopleFlutterHandoverCopyNote
                  : context.l10n.peopleFlutterHandoverTransferNote,
              style: const TextStyle(color: AppColors.medium),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadTargetGroups() async {
    if (_targetTenantId == null) return;

    try {
      final supabase = ref.read(supabaseClientProvider);
      final response = await supabase
          .from('instruments')
          .select('*')
          .eq('tenantId', _targetTenantId!);

      if (!mounted) return;

      setState(() {
        _targetGroups = (response as List)
            .map((g) => Group.fromJson(g as Map<String, dynamic>))
            .toList();

        // Re-auto-map all groups
        final sourceGroups = ref.read(groupsProvider).valueOrNull ?? [];
        final instrumentIds = widget.selectedPlayers
            .map((p) => p.instrument)
            .where((id) => id != null)
            .cast<int>()
            .toSet();

        for (final instrumentId in instrumentIds) {
          final sourceGroup = sourceGroups.firstWhere(
            (g) => g.id == instrumentId,
            // BL-008: Consistent fallback label
            orElse: () => Group(id: instrumentId, name: context.l10n.peopleNoGroupAssigned),
          );
          _groupMapping[instrumentId] = _autoMapGroup(sourceGroup, _targetGroups);
        }
      });
    } catch (e) {
      // SEC-003: Only log in debug mode to avoid data exposure
      if (kDebugMode) {
        debugPrint('Error loading target groups: $e');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.peopleFlutterGroupsLoadFailed),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  int? _autoMapGroup(Group sourceGroup, List<Group> targetGroups) {
    if (targetGroups.isEmpty) return null;

    // Exact name match (case-insensitive)
    for (final target in targetGroups) {
      if (target.name.toLowerCase() == sourceGroup.name.toLowerCase()) {
        return target.id;
      }
    }

    // Partial match
    for (final target in targetGroups) {
      if (target.name.toLowerCase().contains(sourceGroup.name.toLowerCase()) ||
          sourceGroup.name.toLowerCase().contains(target.name.toLowerCase())) {
        return target.id;
      }
    }

    return null;
  }

  /// BL-002: Get user's role in a specific tenant
  Future<Role?> _getUserRoleInTenant(int tenantId) async {
    final supabase = ref.read(supabaseClientProvider);
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return null;

    try {
      final response = await supabase
          .from('tenantUsers')
          .select('role')
          .eq('tenantId', tenantId)
          .eq('userId', userId)
          .maybeSingle();

      if (response == null) return null;
      return Role.fromValue(response['role'] as int? ?? 99);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error getting user role in tenant: $e');
      }
      return null;
    }
  }

  Future<void> _performHandover(Tenant? currentTenant) async {
    final playerRepo = ref.read(playerRepositoryWithTenantProvider);
    if (_targetTenantId == null || currentTenant == null) return;

    // BL-002: Check if user has edit permission in target tenant
    final targetRole = await _getUserRoleInTenant(_targetTenantId!);
    if (targetRole == null || !targetRole.canEdit) {
      if (mounted) {
        ToastHelper.showError(
          context,
          context.l10n.peopleFlutterHandoverNoPermission,
        );
      }
      return;
    }

    // Get target tenant name for confirmation
    final tenants = ref.read(userTenantsProvider).valueOrNull ?? [];
    final targetTenant = tenants.where((t) => t.id == _targetTenantId).firstOrNull;
    if (targetTenant == null) {
      if (mounted) ToastHelper.showError(context, context.l10n.peopleFlutterHandoverTargetNotFound);
      return;
    }

    // Confirmation dialog
    final playersToTransfer = _filteredPlayers;
    final playerCount = playersToTransfer.length;
    final isTransfer = !_stayInInstance;
    if (!mounted) return;
    final confirmed = await DialogHelper.showConfirmation(
      context,
      title: isTransfer ? context.l10n.peopleFlutterHandoverTransferQuestion : context.l10n.peopleFlutterHandoverCopyQuestion,
      message: isTransfer
          ? context.l10n.peopleFlutterHandoverTransferConfirm(playerCount, targetTenant.name)
          : context.l10n.peopleFlutterHandoverCopyConfirm(playerCount, targetTenant.name),
      confirmText: isTransfer ? context.l10n.handoverTransfer : context.l10n.peopleFlutterHandoverCopy,
      isDestructive: isTransfer,
    );
    if (!confirmed) return;

    setState(() {
      _isTransferring = true;
      _progressMessage = context.l10n.peopleFlutterHandoverPreparing;
    });

    try {
      final results = await playerRepo.handoverPlayers(
        players: playersToTransfer,
        targetTenantId: _targetTenantId!,
        groupMapping: _groupMapping,
        targetTenantName: targetTenant.longName,
        sourceTenantName: currentTenant.longName,
        stayInInstance: _stayInInstance,
        onProgress: (current, total, name) {
          if (mounted) {
            setState(() {
              _progressMessage = context.l10n.peopleFlutterHandoverProgress(name, current, total);
            });
          }
        },
      );

      // Note: The calling page (PeopleListPage) will invalidate peopleListProvider
      // when this sheet returns true

      if (mounted) {
        if (results['error']! > 0 || results['duplicate']! > 0) {
          ToastHelper.showWarning(
            context,
            _stayInInstance
                ? context.l10n.peopleFlutterHandoverPartialCopied(
                    results['success']!, results['duplicate']!, results['error']!)
                : context.l10n.peopleFlutterHandoverPartialTransferred(
                    results['success']!, results['duplicate']!, results['error']!),
          );
        } else {
          ToastHelper.showSuccess(
            context,
            _stayInInstance
                ? context.l10n.peopleFlutterHandoverCopied(results['success']!)
                : context.l10n.peopleFlutterHandoverTransferred(results['success']!),
          );
        }
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ToastHelper.showError(context, context.l10n.peopleFlutterErrorWith(friendlyErrorMessage(e)));
      }
    } finally {
      if (mounted) {
        setState(() => _isTransferring = false);
      }
    }
  }
}

/// Shows the handover sheet
Future<bool?> showHandoverSheet(
  BuildContext context, {
  required List<Person> selectedPlayers,
  bool initialStayInInstance = false,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    useRootNavigator: true, // IOS_SHELL2: above the tab bar
    isScrollControlled: true,
    builder: (context) => HandoverSheet(
      selectedPlayers: selectedPlayers,
      initialStayInInstance: initialStayInInstance,
    ),
  );
}
