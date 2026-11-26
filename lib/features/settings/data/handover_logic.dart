import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/group_providers.dart';
import '../../../core/providers/organisation_providers.dart';
import '../../../core/providers/player_providers.dart';
import '../../../core/providers/tenant_providers.dart';
import '../../../core/router/redesign_routes.dart';
import '../../../core/services/tracking/tracking_event.dart';
import '../../../core/services/tracking/tracking_service.dart';
import '../../../core/utils/dialog_helper.dart';
import '../../../core/utils/error_message.dart';
import '../../../core/utils/handover_request.dart';
import '../../../core/utils/toast_helper.dart';
import '../../../data/models/instrument/instrument.dart';
import '../../../data/models/person/person.dart';
import '../../../data/models/tenant/tenant.dart';
import '../../../data/repositories/player_repository.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/widgets/adaptive/adaptive.dart';
import '../../people/people_list_utils.dart';

/// Data handed from step 1 (`RdHandoverPage`) to step 2 (`RdHandoverDetailPage`).
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

typedef HandoverView = ({
  List<Tenant> tenants,
  List<Group> groups,
  Map<int?, String> groupNames,
  List<Person> filtered,
  List<Person> selectedPersons,
  bool loading,
});

/// State and rules of handover step 1, used by `RdHandoverPage`.
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
    );
    if (picked != null) setState(() => date = picked);
  }

  /// Watches data for step 1 and applies defaults and error toasts.
  HandoverView handoverView() {
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
    final filtered = filteredPeople(
      sortPeopleByGroup(
        (playersAsync.isReloading ? null : playersAsync.valueOrNull) ?? const [],
        groups,
      ),
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

  /// Opens step 2 with the selected people.
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

/// Maps [sourceGroupName] automatically onto the matching group in [targetGroups].
int? autoMapHandoverGroup(String? sourceGroupName, List<Group> targetGroups) {
  final name = sourceGroupName ?? '';
  for (final g in targetGroups) {
    if (g.name == name) return g.id;
    if (g.name.length > 2 && name.length > 2) {
      if (g.name.contains(name) || name.contains(g.name)) return g.id;
    }
  }
  return targetGroups.isNotEmpty ? targetGroups.first.id : null;
}

/// State, group mapping, and transfer of handover step 2 (`RdHandoverDetailPage`).
mixin HandoverDetailLogic<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  HandoverData? get handoverData;

  String get handoverDoneRoute => RedesignRoutes.manage;

  String handoverConfirmMessage(HandoverData data) => context.l10n.handoverConfirm(
        data.persons.length,
        data.tenant.longName,
        handoverNote(
          data,
          stay: context.l10n.handoverStayNote,
          archive: context.l10n.handoverArchiveNote,
        ),
      );

  bool get asRequest {
    final id = handoverData?.tenant.id;
    return id != null &&
        handoverNeedsRequest(
          tenants: ref.read(userTenantsProvider).valueOrNull,
          targetTenantId: id,
        );
  }

  String handoverNote(
    HandoverData data, {
    required String stay,
    required String archive,
  }) {
    if (!asRequest) return data.stayInInstance ? stay : archive;
    final l10n = context.l10n;
    return data.stayInInstance
        ? l10n.peopleFlutterHandoverRequestNoteStay(data.tenant.longName)
        : l10n.peopleFlutterHandoverRequestNoteMove(data.tenant.longName);
  }

  List<Group> targetGroups = [];
  final Map<int, int?> groupMapping = {};
  bool loading = true;
  bool transferring = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    final data = handoverData;
    if (data == null || data.tenant.id == null) {
      ToastHelper.showError(context, context.l10n.handoverNoData);
      context.go('/settings/handover');
      return;
    }
    try {
      final repo = ref.read(playerRepositoryWithTenantProvider);
      final groups = await repo.getTargetTenantGroups(data.tenant.id!);
      if (!mounted) return;
      setState(() {
        targetGroups = groups;
        for (final p in data.persons) {
          if (p.id != null) {
            groupMapping[p.id!] = autoMapHandoverGroup(p.groupName, groups);
          }
        }
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      ToastHelper.showError(
        context,
        context.l10n.settingsFlutterErrorDetail(friendlyErrorMessage(e)),
      );
    }
  }

  String targetGroupName(int? id) =>
      targetGroups.where((g) => g.id == id).map((g) => g.name).firstOrNull ??
      context.l10n.commonUnknown;

  void onTransferFinished() {}

  Future<void> confirmProceed() async {
    final data = handoverData!;
    final confirmed = await DialogHelper.showConfirmation(
      context,
      title: context.l10n.handoverTitle,
      message: handoverConfirmMessage(data),
      confirmText: context.l10n.handoverTransfer,
      isDestructive: !data.stayInInstance && !asRequest,
    );
    if (confirmed) await proceed();
  }

  Future<void> proceed() async {
    final data = handoverData!;
    final sourceTenant = ref.read(currentTenantProvider);
    if (data.sourceTenantId != null && sourceTenant?.id != data.sourceTenantId) {
      ToastHelper.showError(context, context.l10n.handoverNoData);
      context.go('/settings/handover');
      return;
    }
    final container = ProviderScope.containerOf(context, listen: false);
    final sourceTenantId = data.sourceTenantId ?? sourceTenant?.id;
    final repo = ref.read(playerRepositoryWithTenantProvider);
    final tracking = ref.read(trackingServiceProvider);
    final request = asRequest;
    setState(() => transferring = true);

    final failed = <Person>[];
    try {
      for (final (index, person) in data.persons.indexed) {
        if (container.read(currentTenantIdProvider) != sourceTenantId) {
          failed.addAll(data.persons.skip(index));
          break;
        }
        final result = await repo.handoverPlayer(
          player: person,
          targetTenantId: data.tenant.id!,
          targetGroupId: groupMapping[person.id],
          targetTenantName: data.tenant.longName,
          sourceTenantName: sourceTenant?.longName ?? '',
          stayInInstance: data.stayInInstance,
          asRequest: request,
        );
        if (result != HandoverResult.success &&
            result != HandoverResult.requested) {
          failed.add(person);
        }
      }

      tracking.track(
        TrackingEvent.handoverCreated,
        properties: {
          'count': data.persons.length,
          'stayInInstance': data.stayInInstance,
          'asRequest': request,
          'failed': failed.length,
        },
      );
      container.invalidate(playersProvider);
      onTransferFinished();

      if (!mounted) return;
      if (failed.isNotEmpty) {
        await DialogHelper.showAlert(
          context,
          title: context.l10n.handoverFailed,
          message: context.l10n.handoverAlreadyThere(
            failed.map((p) => '${p.firstName} ${p.lastName}').join('\n'),
          ),
        );
      } else {
        ToastHelper.showSuccess(
          context,
          request
              ? context.l10n.peopleFlutterHandoverRequestSent(
                  data.persons.length,
                  data.tenant.longName,
                )
              : context.l10n.handoverTransferred(data.persons.length),
        );
      }
      if (mounted) context.go(handoverDoneRoute);
    } catch (e) {
      onTransferFinished();
      if (mounted) {
        ToastHelper.showError(
          context,
          context.l10n.handoverFailedWith(friendlyErrorMessage(e)),
        );
      }
    } finally {
      if (mounted) setState(() => transferring = false);
    }
  }
}
