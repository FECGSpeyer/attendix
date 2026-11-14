import 'package:flutter/material.dart';
import 'package:attendix/shared/widgets/dialogs/ion_sheet.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/organisation_providers.dart';
import '../../../../core/providers/player_providers.dart';
import '../../../../core/providers/realtime_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/router/redesign_routes.dart';
import '../../../../core/utils/dialog_helper.dart';
import '../../../../core/utils/handover_request.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/instrument/instrument.dart';
import '../../../../data/models/person/person.dart';
import '../../../../data/models/tenant/tenant.dart';
import '../../../../data/repositories/player_repository.dart' show HandoverResult;
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';
import '../../../redesign/presentation/widgets/manage/rd_settings_sheets.dart' show showRdChoiceSheet;
import '../../../redesign/presentation/widgets/rd_widgets.dart';
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
  if (RedesignRoutes.active) {
    // REDESIGN: the same flow in a sheet of the new design.
    final done = await showRdSheet<bool>(context, _PersonTransferSheet(person: person, copy: copy, beta: true));
    return done ?? false;
  }
  // Ionic: [breakpoints]="[0, 0.5, 1]" [initialBreakpoint]="0.5".
  final done = await showIonSheet<bool>(
    context,
    breakpoints: const [0, 0.5, 1],
    initialBreakpoint: 0.5,
    builder: (_, controller) => _PersonTransferSheet(person: person, copy: copy, scrollController: controller),
  );
  return done ?? false;
}

class _PersonTransferSheet extends ConsumerStatefulWidget {
  const _PersonTransferSheet({required this.person, required this.copy, this.beta = false, this.scrollController});

  /// Classic design: the controller of the breakpoint sheet.
  final ScrollController? scrollController;

  final Person person;
  final bool copy;

  /// Drawn in the new design (Beta).
  final bool beta;

  @override
  ConsumerState<_PersonTransferSheet> createState() => _PersonTransferSheetState();
}

class _PersonTransferSheetState extends ConsumerState<_PersonTransferSheet> {
  int? _tenantId;
  int? _groupId;
  List<Group> _groups = const [];
  bool _busy = false;
  int _groupLoad = 0;

  /// TENANT (Beta): the group the sheet was opened in (source of the person).
  int? _sourceTenantId;

  @override
  void initState() {
    super.initState();
    _sourceTenantId = ref.read(currentTenantIdProvider);
  }

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
    // TENANT (Beta): the person belongs to the group the sheet was opened
    // in; after a switch before "Übertragen" nothing is handed over.
    if (widget.beta &&
        (source.id != _sourceTenantId || (person.tenantId != null && person.tenantId != source.id))) {
      ToastHelper.showError(context, l10n.rdPeopleGroupSwitched);
      return;
    }

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

      // No lead of the target group: its leads decide (handover_request.dart).
      final request = handoverNeedsRequest(
        tenants: ref.read(userTenantsProvider).valueOrNull,
        targetTenantId: target!.id!,
      );
      final question = copy ? l10n.personCopyConfirm : l10n.personTransferConfirm;
      final requestNote = copy
          ? l10n.peopleFlutterHandoverRequestNoteStay(target.longName)
          : l10n.peopleFlutterHandoverRequestNoteMove(target.longName);
      final confirmText = request ? '$question\n\n$requestNote' : question;
      final confirmed = widget.beta
          ? await showAppConfirm(
              context,
              title: copy ? l10n.personCopyPerson : l10n.personTransferPerson,
              message: confirmText,
              confirmText: l10n.commonYes,
            )
          : await showAppDialog<bool>(
        context: context,
        builder: (ctx) => AppAlertDialog(
          title: Text(copy ? l10n.personCopyPerson : l10n.personTransferPerson),
          content: Text(confirmText),
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
      // TENANT (Beta): after a group change nothing is handed over.
      if (widget.beta && ref.read(currentTenantIdProvider) != _sourceTenantId) {
        ToastHelper.showError(context, l10n.rdPeopleGroupSwitched);
        return;
      }

      final result = await repo.handoverPlayer(
        player: person,
        targetTenantId: target.id!,
        targetGroupId: _groupId,
        targetTenantName: target.longName,
        sourceTenantName: source.longName,
        stayInInstance: copy,
        // Ionic person.page handoverPerson: the new account is always a
        // Spieler (alert-97cf5262); only handover-detail grants Verantwortlich.
        responsibleForMainGroup: false,
        asRequest: request,
      );
      if (!mounted) return;
      if (result == HandoverResult.requested) {
        ref.invalidate(realtimePlayersProvider);
        ToastHelper.showSuccess(context, l10n.peopleFlutterHandoverRequestSent(1, target.longName));
        Navigator.pop(context, true);
        return;
      }
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
    if (widget.beta) return _buildBeta(context, tenants, name.trim());

    // Ionic: ion-title + close ✕ in the end slot; PEO-22: `ion-content
    // color="light"` with an inset list of two label-start selects
    // (default alert interface) and the block button.
    return IonSheetScaffold(
      title: widget.copy ? l10n.personCopyFrom(name) : l10n.personTransferFrom(name),
      showClose: true,
      onClose: () => Navigator.pop(context, false),
      backgroundColor: ionLightColor(context),
      body: SingleChildScrollView(
        controller: widget.scrollController,
        padding: const EdgeInsets.only(bottom: AppDimensions.paddingL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: AppDimensions.paddingM),
            IonInsetList(
              children: [
                IonSelectRow<int>(
                  lines: false,
                  label: l10n.personTargetInstance,
                  value: _tenantId,
                  options: [
                    for (final t in tenants)
                      if (t.id != null)
                        AppSelectOption<int>(value: t.id!, label: t.longName),
                  ],
                  onChanged: _busy
                      ? null
                      : (id) {
                          if (id == _tenantId) return;
                          setState(() => _tenantId = id);
                          _loadGroups(id);
                        },
                ),
                if (_tenantId != null && _groups.isNotEmpty)
                  IonSelectRow<int>(
                    lines: false,
                    label: l10n.personTargetGroup,
                    value: _groupId,
                    options: [
                      for (final g in _groups)
                        if (g.id != null)
                          AppSelectOption<int>(value: g.id!, label: g.name),
                    ],
                    onChanged: _busy ? null : (id) => setState(() => _groupId = id),
                  ),
              ],
            ),
            const SizedBox(height: AppDimensions.paddingL),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingM),
              child: FilledButton(
                onPressed: _busy || _tenantId == null || _groupId == null
                    ? null
                    : () => _transfer(tenants),
                child: IonButtonLabel(
                    widget.copy ? l10n.peopleFlutterHandoverCopy : l10n.handoverTransfer),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// REDESIGN: "{Name} übertragen / kopieren" with "Zielgruppe" and the
  /// group there ("Instrument", "Stimme" … by the kind of the target) as
  /// choice rows, a note and the primary button.
  Widget _buildBeta(BuildContext context, List<Tenant> tenants, String name) {
    final l10n = context.l10n;
    final target = tenants.where((t) => t.id == _tenantId).firstOrNull;
    final kind = target?.type ?? '';
    final group = _groups.where((g) => g.id == _groupId).firstOrNull;
    final tenantOptions = [
      for (final t in tenants)
        if (t.id != null) (t.id!, t.longName),
    ];
    final groupOptions = [
      for (final g in _groups)
        if (g.id != null) (g.id!, g.name),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          RdSheetTitle(widget.copy ? l10n.rdPeopleCopyTitle(name) : l10n.rdPeopleTransferTitle(name)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (tenantOptions.isEmpty)
                  RdHintBox(l10n.rdPeopleTransferNoTargets)
                else ...[
                  RdGroupedList(
                    children: [
                      RdListRow(
                        key: const Key('rd-transfer-target'),
                        title: l10n.rdPeopleTransferTarget,
                        value: target?.longName ?? l10n.rdPeopleTransferChoose,
                        onTap: _busy
                            ? null
                            : () async {
                                final id = await showRdChoiceSheet<int>(
                                  context,
                                  title: l10n.rdPeopleTransferTarget,
                                  options: tenantOptions,
                                  selected: _tenantId,
                                );
                                if (id == null || id == _tenantId || !mounted) return;
                                setState(() => _tenantId = id);
                                _loadGroups(id);
                              },
                      ),
                      RdListRow(
                        key: const Key('rd-transfer-register'),
                        title: l10n.rdWordsGroup(kind),
                        value: group?.name ??
                            (groupOptions.isEmpty ? l10n.rdPeopleTransferNoGroups(kind) : l10n.rdPeopleTransferChoose),
                        onTap: _busy || groupOptions.isEmpty
                            ? null
                            : () async {
                                final id = await showRdChoiceSheet<int>(
                                  context,
                                  title: l10n.rdWordsGroup(kind),
                                  options: groupOptions,
                                  selected: _groupId,
                                );
                                if (id != null && mounted) setState(() => _groupId = id);
                              },
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  RdHintBox(widget.copy ? l10n.rdPeopleCopyHint : l10n.rdPeopleTransferHint),
                  const SizedBox(height: 18),
                  RdPrimaryButton(
                    key: const Key('rd-transfer-submit'),
                    label: widget.copy ? l10n.peopleFlutterHandoverCopy : l10n.handoverTransfer,
                    loading: _busy,
                    onPressed: _tenantId == null || _groupId == null ? null : () => _transfer(tenants),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
