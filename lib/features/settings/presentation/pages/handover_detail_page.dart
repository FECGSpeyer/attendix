import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/player_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/services/tracking/tracking_event.dart';
import '../../../../core/services/tracking/tracking_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/dialog_helper.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/instrument/instrument.dart';
import '../../../../data/models/person/person.dart';
import '../../../../data/repositories/player_repository.dart';
import 'handover_page.dart';
import '../../../../l10n/l10n.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart'; // IOS_LOOK

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

class _HandoverDetailPageState extends ConsumerState<HandoverDetailPage> {
  List<Group> _targetGroups = [];
  final Map<int, int?> _groupMapping = {};
  bool _loading = true;
  bool _transferring = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    final data = widget.data;
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
        _targetGroups = groups;
        for (final p in data.persons) {
          if (p.id != null) {
            _groupMapping[p.id!] = autoMapHandoverGroup(p.groupName, groups);
          }
        }
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ToastHelper.showError(context, context.l10n.settingsFlutterErrorDetail(friendlyErrorMessage(e)));
    }
  }

  String _groupName(int? id) =>
      _targetGroups.where((g) => g.id == id).map((g) => g.name).firstOrNull ??
      context.l10n.commonUnknown;

  Future<void> _changeGroup(Person person) async {
    final current = _groupMapping[person.id];
    final picked = await showAppDialog<int>(
      context: context,
      builder: (context) => AppSimpleDialog(
        title: Text(context.l10n.handoverSelectGroup),
        children: [
          for (final g in _targetGroups)
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
    if (picked != null) setState(() => _groupMapping[person.id!] = picked);
  }

  Future<void> _confirmProceed() async {
    final data = widget.data!;
    final note = data.stayInInstance
        ? context.l10n.handoverStayNote
        : context.l10n.handoverArchiveNote;
    final confirmed = await DialogHelper.showConfirmation(
      context,
      title: context.l10n.handoverTitle,
      message: context.l10n.handoverConfirm(data.persons.length, data.tenant.longName, note),
      confirmText: context.l10n.handoverTransfer,
      isDestructive: !data.stayInInstance,
    );
    if (confirmed) await _proceed();
  }

  Future<void> _proceed() async {
    final data = widget.data!;
    final sourceTenant = ref.read(currentTenantProvider);
    final repo = ref.read(playerRepositoryWithTenantProvider);
    setState(() => _transferring = true);

    final failed = <Person>[];
    try {
      for (final person in data.persons) {
        final result = await repo.handoverPlayer(
          player: person,
          targetTenantId: data.tenant.id!,
          targetGroupId: _groupMapping[person.id],
          targetTenantName: data.tenant.longName,
          sourceTenantName: sourceTenant?.longName ?? '',
          stayInInstance: data.stayInInstance,
        );
        if (result != PlayerRepository.handoverSuccess) failed.add(person);
      }

      ref.read(trackingServiceProvider).track(
        TrackingEvent.handoverCreated,
        properties: {
          'count': data.persons.length,
          'stayInInstance': data.stayInInstance,
          'failed': failed.length,
        },
      );
      ref.invalidate(playersProvider);

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
            context, context.l10n.handoverTransferred(data.persons.length));
      }
      if (mounted) context.go('/settings');
    } catch (e) {
      if (mounted) {
        ToastHelper.showError(context, context.l10n.handoverFailedWith(friendlyErrorMessage(e)));
      }
    } finally {
      if (mounted) setState(() => _transferring = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.handoverTitle)),
      floatingActionButton: data == null || _loading
          ? null
          : FloatingActionButton(
              onPressed: _transferring ? null : _confirmProceed,
              child: _transferring
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: AppSpinner(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.directions_walk),
            ),
      body: data == null || _loading
          ? const Center(child: AppSpinner())
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                AppDimensions.paddingM,
                AppDimensions.paddingM,
                AppDimensions.paddingM,
                100,
              ),
              children: [
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
                            '${p.groupName ?? ''} -> ${_groupName(_groupMapping[p.id])}',
                            style: const TextStyle(color: AppColors.medium),
                          ),
                          onTap: _targetGroups.isEmpty ? null : () => _changeGroup(p),
                        ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
