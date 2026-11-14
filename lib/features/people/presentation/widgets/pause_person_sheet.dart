import 'package:flutter/material.dart';
import 'package:attendix/shared/widgets/dialogs/ion_sheet.dart';
import 'package:attendix/core/theme/app_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/enums.dart';
import '../../../../core/providers/cross_tenant_person_providers.dart';
import '../../../../core/providers/player_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/router/redesign_routes.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/person/person.dart';
import '../../../../data/repositories/cross_tenant_person_repository.dart';
import '../../../../core/utils/date_helper.dart';
import '../../../../l10n/l10n.dart';
import 'ion/ion_widgets.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';
import '../../../redesign/presentation/widgets/members/rd_pause_sheets.dart';

final _fmt = DateFormat('dd.MM.yyyy');

/// Input of the "{name} Pausieren" sheet (Ionic people/person pause modal).
class PauseInput {
  const PauseInput({required this.reason, this.from, this.until});

  final String reason;

  /// "Pausiert ab (optional)" — today or earlier
  final DateTime? from;

  /// "Pausiert bis (optional)" — today or later
  final DateTime? until;
}

/// History text like Ionic confirmPause: "Grund (ab dd.MM.yyyy bis dd.MM.yyyy)".
String buildPauseHistoryText(String reason, {DateTime? from, DateTime? until}) {
  final segments = <String>[
    if (from != null) 'ab ${_fmt.format(from)}',
    if (until != null) 'bis ${_fmt.format(until)}',
  ];
  return segments.isEmpty ? reason : '$reason (${segments.join(' ')})';
}

/// Shows the pause sheet. Returns null when cancelled. In the Beta the
/// sheet of the new design ([showRdPauseSheet]).
Future<PauseInput?> showPauseSheet(BuildContext context, Person person) {
  if (RedesignRoutes.active) {
    return showRdPauseSheet(
      context,
      title: context.l10n.rdPeoplePauseTitle('${person.firstName} ${person.lastName}'.trim()),
      hint: context.l10n.rdPeoplePauseHint,
    );
  }
  // Ionic pause modal: [breakpoints]="[0, 0.75, 1]" [initialBreakpoint]="0.75".
  return showIonSheet<PauseInput>(
    context,
    breakpoints: const [0, 0.75, 1],
    initialBreakpoint: 0.75,
    builder: (_, controller) => _PauseSheet(person: person, scrollController: controller),
  );
}

class _PauseSheet extends StatefulWidget {
  const _PauseSheet({required this.person, this.scrollController});

  final Person person;
  final ScrollController? scrollController;

  @override
  State<_PauseSheet> createState() => _PauseSheetState();
}

class _PauseSheetState extends State<_PauseSheet> {
  final _reasonController = TextEditingController();
  DateTime? _from;
  DateTime? _until;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final p = widget.person;
    final hasReason = _reasonController.text.trim().isNotEmpty;

    // UX_PEOPLE: Ionic modal toolbar — ion-title, close ✕ in the end slot.
    return IonSheetScaffold(
      title: context.l10n.peoplePauseTitle('${p.firstName} ${p.lastName}'),
      showClose: true,
      body: SingleChildScrollView(
        controller: widget.scrollController,
        padding: const EdgeInsets.only(
          left: AppDimensions.paddingM,
          right: AppDimensions.paddingM,
          top: AppDimensions.paddingM,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ion-item + stacked label + textarea
            IonFormTheme(
              child: TextField(
                controller: _reasonController,
                decoration: InputDecoration(
                  labelText: context.l10n.peopleReasonRequired,
                  hintText: context.l10n.personPauseReasonPlaceholder,
                  border: ionIsIos(context) ? null : const OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.sentences,
                minLines: 1,
                maxLines: 5,
                autofocus: true,
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(height: AppDimensions.paddingM),
            _DateHeaderItem(
              title: context.l10n.peoplePausedFrom,
              value: _from != null ? DateFormat(dateFmt()).format(_from!) : context.l10n.peopleFromToday,
              onClear: _from != null ? () => setState(() => _from = null) : null,
              onTap: () async {
                final date = await showAppDatePicker(
                  context: context,
                  initialDate: _from ?? today,
                  firstDate: DateTime(today.year - 5),
                  lastDate: today,
                );
                if (date != null) setState(() => _from = date);
              },
            ),
            _DateHeaderItem(
              title: context.l10n.signoutPausedUntil,
              value: _until != null ? DateFormat(dateFmt()).format(_until!) : context.l10n.peopleNoEndDate,
              onClear: _until != null ? () => setState(() => _until = null) : null,
              onTap: () async {
                final date = await showAppDatePicker(
                  context: context,
                  initialDate: _until ?? today.add(const Duration(days: 30)),
                  firstDate: today,
                  lastDate: DateTime(today.year + 3),
                );
                if (date != null) setState(() => _until = date);
              },
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppDimensions.paddingS),
              child: Text(
                context.l10n.personPauseHintAuto,
                style: IonText.note(context).copyWith(color: AppColors.medium),
              ),
            ),
            const SizedBox(height: AppDimensions.paddingS),
            FilledButton.icon(
              onPressed: hasReason
                  ? () => Navigator.pop(
                        context,
                        PauseInput(
                          reason: _reasonController.text.trim(),
                          from: _from,
                          until: _until,
                        ),
                      )
                  : null,
              icon: Icon(AppIcons.pause),
              label: IonButtonLabel(context.l10n.peoplePause),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.warning,
                disabledBackgroundColor: AppColors.warning.withValues(alpha: 0.5),
                padding:
                    const EdgeInsets.symmetric(vertical: AppDimensions.paddingM),
              ),
            ),
            const SizedBox(height: AppDimensions.paddingL),
          ],
        ),
      ),
    );
  }
}

/// Full pause flow of the Ionic list/person page: sheet → pause → optionally
/// pause in other linked instances where the person's account is active.
/// Returns true when the person was paused.
Future<bool> pausePersonFlow(
  BuildContext context,
  WidgetRef ref,
  Person person, {
  // Ionic person.page confirmPause shows no success toast (it closes).
  bool showSuccessToast = true,
}) async {
  final repo = ref.read(playerRepositoryWithTenantProvider);
  final crossRepo = ref.read(crossTenantPersonRepositoryWithTenantProvider);
  final beta = RedesignRoutes.active;
  final tenantId = ref.read(currentTenantIdProvider);
  final input = await showPauseSheet(context, person);
  if (input == null || !context.mounted) return false;
  // TENANT (Beta): the group changed while the sheet was open, so write
  // nothing (the person belongs to the old group).
  if (beta && ref.read(currentTenantIdProvider) != tenantId) {
    ToastHelper.showError(context, context.l10n.rdPeopleGroupSwitched);
    return false;
  }

  final messenger = ScaffoldMessenger.of(context);
  final text = buildPauseHistoryText(input.reason,
      from: input.from, until: input.until);
  final until = input.until != null ? DateHelper.isoDay(input.until!) : null;
  final from = input.from != null ? DateHelper.isoDay(input.from!) : null;

  try {
    await repo.pausePlayer(person, until, text, pauseFrom: from);
  } catch (e) {
    messenger.showSnackBar(
      SnackBar(content: Text(l10nWithoutContext.peopleFlutterErrorWith(friendlyErrorMessage(e))), backgroundColor: AppColors.danger),
    );
    return false;
  }

  if (showSuccessToast) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(l10nWithoutContext.peopleFlutterPausedToast(person.firstName)),
        backgroundColor: AppColors.success,
      ),
    );
  }

  final appId = person.appId;
  if (appId == null || !context.mounted) return true;

  // "Auch in anderen Instanzen pausieren?"
  try {
    final linkedIds = await ref.read(linkedTenantIdsProvider.future);
    if (linkedIds.isEmpty) return true;
    final memberOf =
        await crossRepo.getLinkedTenantsOfUser(appId, linkedTenantIds: linkedIds);
    // Only offer instances where the current user may pause people.
    final manageable = await crossRepo.getManageableTenantIds(
      memberOf.map((t) => t.id).toList(),
      linkedTenantIds: linkedIds,
    );
    final others =
        memberOf.where((t) => manageable.contains(t.id)).toList();
    if (others.isEmpty || !context.mounted) return true;

    final selected = await _askPauseInOtherTenants(context, person, others);
    if (selected == null || selected.isEmpty) return true;
    if (beta && ref.read(currentTenantIdProvider) != tenantId) return true;

    final entry = {
      'date': DateTime.now().toUtc().toIso8601String(),
      'text': text,
      'type': PlayerHistoryType.paused.value,
    };
    for (final tenant in selected) {
      try {
        final otherId = await crossRepo.getPersonIdFromTenant(
          appId,
          tenant.id,
          linkedTenantIds: linkedIds,
        );
        if (otherId == null) continue;
        await crossRepo.pausePlayerInOtherTenant(
          playerId: otherId,
          tenantId: tenant.id,
          linkedTenantIds: linkedIds,
          historyEntry: entry,
          pausedUntil: until,
          pauseFrom: from,
        );
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(l10nWithoutContext.peopleErrorAt(
                tenant.shortName.isNotEmpty ? tenant.shortName : tenant.name, e)),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  } catch (_) {
    // Optional follow-up; the person itself is paused.
  }
  return true;
}

Future<List<LinkedTenantRef>?> _askPauseInOtherTenants(
  BuildContext context,
  Person person,
  List<LinkedTenantRef> tenants,
) {
  if (RedesignRoutes.active) {
    return showRdPauseOthersSheet(
      context,
      name: '${person.firstName} ${person.lastName}'.trim(),
      tenants: tenants,
    );
  }
  final selected = <int>{};
  return showAppDialog<List<LinkedTenantRef>>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AppAlertDialog(
        title: Text(context.l10n.peoplePauseOthers),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.peoplePauseOthersMessage('${person.firstName} ${person.lastName}'),
              ),
              const SizedBox(height: AppDimensions.paddingS),
              for (final t in tenants)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(t.name),
                  value: selected.contains(t.id),
                  onChanged: (v) => setState(() {
                    if (v == true) {
                      selected.add(t.id);
                    } else {
                      selected.remove(t.id);
                    }
                  }),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.l10n.peopleSkip),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              ctx,
              tenants.where((t) => selected.contains(t.id)).toList(),
            ),
            child: Text(context.l10n.peoplePause),
          ),
        ],
      ),
    ),
  );
}

/// UX_PEOPLE: Ionic `ion-item slot="header" color="light"` with h3 title,
/// p value and a close-circle clear button (pause modal date rows).
class _DateHeaderItem extends StatelessWidget {
  const _DateHeaderItem({
    required this.title,
    required this.value,
    required this.onTap,
    this.onClear,
  });

  final String title;
  final String value;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return IonItem(
      background: ionLightColor(context),
      onTap: onTap,
      end: [
        if (onClear != null)
          IconButton(
            icon: Icon(AppIcons.highlightOff, color: AppColors.medium, semanticLabel: context.l10n.commonRemove),
            onPressed: onClear,
          ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: IonText.h3(context)),
          const SizedBox(height: 2),
          Text(value, style: IonText.p(context)),
        ],
      ),
    );
  }
}
