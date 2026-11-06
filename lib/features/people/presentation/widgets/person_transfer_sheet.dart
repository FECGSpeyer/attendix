import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/organisation_providers.dart';
import '../../../../core/providers/player_providers.dart';
import '../../../../core/providers/realtime_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/utils/dialog_helper.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/instrument/instrument.dart';
import '../../../../data/models/person/person.dart';
import '../../../../data/models/tenant/tenant.dart';
import '../../../../data/repositories/player_repository.dart' show HandoverResult;
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';
import 'ion/ion_widgets.dart';

/// Ionic person.page transfer modal (sheet, breakpoint 0.5): "Kopieren von
/// {name}" / "Übertragen von {name}" with "Ziel-Instanz" (instances of the
/// organisation except the current one, first preselected) and
/// "Ziel-Gruppe" (required). Returns true when the person was handed over.
Future<bool> showPersonTransferSheet(
  BuildContext context,
  Person person, {
  required bool copy,
}) async {
  final done = await showModalBottomSheet<bool>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _PersonTransferSheet(person: person, copy: copy),
  );
  return done ?? false;
}

class _PersonTransferSheet extends ConsumerStatefulWidget {
  const _PersonTransferSheet({required this.person, required this.copy});

  final Person person;
  final bool copy;

  @override
  ConsumerState<_PersonTransferSheet> createState() => _PersonTransferSheetState();
}

class _PersonTransferSheetState extends ConsumerState<_PersonTransferSheet> {
  int? _tenantId;
  int? _groupId;
  List<Group> _groups = const [];
  bool _busy = false;
  int _groupLoad = 0;

  Future<void> _loadGroups(int tenantId) async {
    final seq = ++_groupLoad;
    setState(() {
      _groups = const [];
      _groupId = null;
    });
    try {
      final groups = await ref
          .read(playerRepositoryWithTenantProvider)
          .getTargetTenantGroups(tenantId);
      if (mounted && seq == _groupLoad) setState(() => _groups = groups);
    } catch (_) {
      // Ionic: the group select stays hidden without groups.
    }
  }

  Future<void> _transfer(List<Tenant> tenants) async {
    final target = tenants.where((t) => t.id == _tenantId).firstOrNull;
    final source = ref.read(currentTenantProvider);
    if (target?.id == null || _groupId == null || source == null) return;
    final repo = ref.read(playerRepositoryWithTenantProvider);
    final person = widget.person;
    final copy = widget.copy;
    final l10n = context.l10n;

    setState(() => _busy = true);
    try {
      bool exists = false;
      try {
        exists = await repo.playerExistsInTenant(person, target!.id!);
      } catch (_) {
        // The handover checks again and reports a duplicate.
      }
      if (!mounted) return;
      if (exists) {
        final email = (person.email ?? '').trim();
        await DialogHelper.showAlert(
          context,
          title: copy ? l10n.personCopyNotPossible : l10n.personTransferNotPossible,
          message: email.isNotEmpty
              ? l10n.personExistsWithEmail(target!.longName, email)
              : l10n.personExistsWithName(
                  target!.longName, '${person.firstName} ${person.lastName}'),
        );
        return;
      }

      final confirmed = await showAppDialog<bool>(
        context: context,
        builder: (ctx) => AppAlertDialog(
          title: Text(copy ? l10n.personCopyPerson : l10n.personTransferPerson),
          content: Text(copy ? l10n.personCopyConfirm : l10n.personTransferConfirm),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.commonCancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.commonYes),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;

      final result = await repo.handoverPlayer(
        player: person,
        targetTenantId: target!.id!,
        targetGroupId: _groupId,
        targetTenantName: target.longName,
        sourceTenantName: source.longName,
        stayInInstance: copy,
        // Ionic person.page handoverPerson: the new account is always a
        // Spieler (alert-97cf5262); only handover-detail grants Verantwortlich.
        responsibleForMainGroup: false,
      );
      if (!mounted) return;
      if (result != HandoverResult.success) {
        ToastHelper.showError(
          context,
          result == HandoverResult.duplicate
              ? (copy ? l10n.personCopyNotPossible : l10n.personTransferNotPossible)
              : l10n.commonUnknownError,
        );
        return;
      }
      ref.invalidate(realtimePlayersProvider);
      ToastHelper.showSuccess(context, copy ? l10n.personCopied : l10n.personTransferred);
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) ToastHelper.showError(context, friendlyErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tenants = ref.watch(linkedTenantsProvider).valueOrNull ?? const <Tenant>[];
    if (_tenantId == null && tenants.isNotEmpty && tenants.first.id != null) {
      _tenantId = tenants.first.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _tenantId != null) _loadGroups(_tenantId!);
      });
    }
    final name = '${widget.person.firstName} ${widget.person.lastName}';

    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: MediaQuery.sizeOf(context).height * 0.5),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppDimensions.paddingM,
          AppDimensions.paddingS,
          AppDimensions.paddingM,
          AppDimensions.paddingL,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const SizedBox(width: 48),
                Expanded(
                  child: Text(
                    widget.copy ? l10n.personCopyFrom(name) : l10n.personTransferFrom(name),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, semanticLabel: l10n.commonClose),
                  onPressed: () => Navigator.pop(context, false),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.paddingM),
            IonFormTheme(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppDropdownFormField<int>(
                    iosInterface: AppSelectInterface.alert,
                    value: _tenantId,
                    isExpanded: true,
                    decoration: InputDecoration(labelText: l10n.personTargetInstance),
                    items: [
                      for (final t in tenants)
                        if (t.id != null)
                          DropdownMenuItem(value: t.id, child: Text(t.longName)),
                    ],
                    onChanged: _busy
                        ? null
                        : (id) {
                            if (id == null || id == _tenantId) return;
                            setState(() => _tenantId = id);
                            _loadGroups(id);
                          },
                  ),
                  if (_tenantId != null && _groups.isNotEmpty) ...[
                    const SizedBox(height: AppDimensions.paddingM),
                    AppDropdownFormField<int>(
                      iosInterface: AppSelectInterface.alert,
                      value: _groupId,
                      isExpanded: true,
                      decoration: InputDecoration(labelText: l10n.personTargetGroup),
                      items: [
                        for (final g in _groups)
                          if (g.id != null)
                            DropdownMenuItem(value: g.id, child: Text(g.name)),
                      ],
                      onChanged: _busy ? null : (id) => setState(() => _groupId = id),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppDimensions.paddingL),
            FilledButton(
              onPressed: _busy || _tenantId == null || _groupId == null
                  ? null
                  : () => _transfer(tenants),
              child: Text(widget.copy ? l10n.peopleFlutterHandoverCopy : l10n.handoverTransfer),
            ),
          ],
        ),
      ),
    );
  }
}
