import 'package:flutter/material.dart';
import 'package:attendix/core/theme/app_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/player_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/services/tracking/tracking_event.dart';
import '../../../../core/services/tracking/tracking_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/dialog_helper.dart';
import '../../../../core/utils/handover_request.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/instrument/instrument.dart';
import '../../../../data/models/person/person.dart';
import '../../../../data/repositories/player_repository.dart';
import 'handover_page.dart';
import '../../../../l10n/l10n.dart';
import '../../../../core/utils/error_message.dart';
import '../widgets/ion_condense.dart';
import '../widgets/settings_list.dart' show ionIsIos;
import 'package:attendix/shared/widgets/layout/ionic_ios.dart' show IonTranslucentAppBar, IonContentTopInset;
import '../../../../shared/widgets/adaptive/adaptive.dart';
import 'package:attendix/shared/widgets/layout/ios_tab_bar.dart';

/// Ionic handover-detail auto mapping: same name, or one name contains the
/// other (e.g. "Trompete" vs. "Bb Trompete", "Flöte" vs. "Querflöte").
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

/// Personenübergabe – step 2: map groups and transfer
/// (Ionic settings/handover-detail).
class HandoverDetailPage extends ConsumerStatefulWidget {
  const HandoverDetailPage({super.key, required this.data});

  final HandoverData? data;

  @override
  ConsumerState<HandoverDetailPage> createState() => _HandoverDetailPageState();
}

/// State, group mapping and transfer of step 2 (Ionic handover-detail),
/// shared by the old page and the Beta page (`RdHandoverDetailPage`).
mixin HandoverDetailLogic<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  /// The people and target from step 1 (null: opened without data).
  HandoverData? get handoverData;

  /// Where to go after the transfer.
  String get handoverDoneRoute => '/settings';

  /// Text of the confirm dialog (the Beta says "Gruppe" instead of "Instanz").
  String handoverConfirmMessage(HandoverData data) => context.l10n.handoverConfirm(
        data.persons.length,
        data.tenant.longName,
        handoverNote(data, stay: context.l10n.handoverStayNote, archive: context.l10n.handoverArchiveNote),
      );

  /// The viewer is no lead of the target group: the people only wait in
  /// its Freigaben until a lead there takes them in (`handover_request.dart`).
  bool get asRequest {
    final id = handoverData?.tenant.id;
    return id != null &&
        handoverNeedsRequest(tenants: ref.read(userTenantsProvider).valueOrNull, targetTenantId: id);
  }

  /// What happens to the people here: [stay] / [archive] for a direct
  /// handover, for a request the sentence that the target group decides.
  String handoverNote(HandoverData data, {required String stay, required String archive}) {
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
      ToastHelper.showError(context, context.l10n.settingsFlutterErrorDetail(friendlyErrorMessage(e)));
    }
  }

  String targetGroupName(int? id) =>
      targetGroups.where((g) => g.id == id).map((g) => g.name).firstOrNull ??
      context.l10n.commonUnknown;

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
    // Picked in another group than the current one: transfer nothing.
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
        // Group switched during the transfer: the remaining people stay and
        // are listed as not transferred.
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
        if (result != HandoverResult.success && result != HandoverResult.requested) failed.add(person);
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

      if (!mounted) return;
      if (failed.isNotEmpty) {
        await DialogHelper.showAlert(
          context,
          title: context.l10n.handoverFailed,
          message: context.l10n.handoverAlreadyThere(
              failed.map((p) => '${p.firstName} ${p.lastName}').join('\n')),
        );
      } else {
        ToastHelper.showSuccess(
            context,
            request
                ? context.l10n.peopleFlutterHandoverRequestSent(data.persons.length, data.tenant.longName)
                : context.l10n.handoverTransferred(data.persons.length));
      }
      if (mounted) context.go(handoverDoneRoute);
    } catch (e) {
      if (mounted) {
        ToastHelper.showError(context, context.l10n.handoverFailedWith(friendlyErrorMessage(e)));
      }
    } finally {
      if (mounted) setState(() => transferring = false);
    }
  }
}

class _HandoverDetailPageState extends ConsumerState<HandoverDetailPage> with HandoverDetailLogic {
  @override
  HandoverData? get handoverData => widget.data;

  Future<void> _changeGroup(Person person) async {
    final current = groupMapping[person.id];
    final picked = await showAppDialog<int>(
      context: context,
      builder: (context) => AppSimpleDialog(
        title: Text(context.l10n.handoverSelectGroup),
        children: [
          for (final g in targetGroups)
            RadioListTile<int>(
              value: g.id!,
              // ignore: deprecated_member_use
              groupValue: current,
              title: Text(g.name),
              // ignore: deprecated_member_use
              onChanged: (v) => Navigator.pop(context, v),
            ),
        ],
      ),
    );
    if (picked != null) setState(() => groupMapping[person.id!] = picked);
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    // IOS_R6: Ionic `ion-header collapse="condense"` (large title on iOS)
    return IonCondense(builder: (context, collapsed) => Scaffold(
      // IOS_R6: Ionic `ion-content fullscreen` under the translucent header
      extendBodyBehindAppBar: ionIsIos(context),
      // IOS_R6: `ion-header translucent` + `collapse="condense"`
      appBar: IonTranslucentAppBar(condensed: collapsed, child: AppBar(title: IonCondenseTitle(context.l10n.handoverTitle, collapsed: collapsed))),
      floatingActionButton: TabBarFab.wrap(data == null || loading
          ? null
          : FloatingActionButton(
              onPressed: transferring ? null : confirmProceed,
              child: transferring
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: AppSpinner(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Icon(AppIcons.directionsWalk),
            )),
      body: data == null || loading
          ? const Center(child: AppSpinner())
          : ListView(
              padding: EdgeInsets.fromLTRB(AppDimensions.paddingM, ionIsIos(context) ? 0 : AppDimensions.paddingM, AppDimensions.paddingM, scrollEndPadding(context, base: 16, fabRoom: 84)), // IOS_R6: large title on top
              children: [
                const IonContentTopInset(),
                IonLargeTitle(context.l10n.handoverTitle, padding: const EdgeInsets.only(bottom: 4)),
                Text(context.l10n.handoverGroupMapping,
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: AppDimensions.paddingS),
                Card(
                  child: Column(
                    children: [
                      for (final p in data.persons)
                        ListTile(
                          title: Text('${p.firstName} ${p.lastName}'),
                          trailing: Text(
                            '${p.groupName ?? ''} -> ${targetGroupName(groupMapping[p.id])}',
                            style: const TextStyle(color: AppColors.medium),
                          ),
                          onTap: targetGroups.isEmpty ? null : () => _changeGroup(p),
                        ),
                    ],
                  ),
                ),
              ],
            ),
    ));
  }
}
