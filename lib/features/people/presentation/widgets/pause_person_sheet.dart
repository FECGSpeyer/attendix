import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/enums.dart';
import '../../../../core/providers/cross_tenant_person_providers.dart';
import '../../../../core/providers/player_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/person/person.dart';
import '../../../../data/repositories/cross_tenant_person_repository.dart';
import '../../../../core/utils/date_helper.dart';
import '../../../../l10n/l10n.dart';

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

/// Shows the pause sheet. Returns null when cancelled.
Future<PauseInput?> showPauseSheet(BuildContext context, Person person) {
  return showModalBottomSheet<PauseInput>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _PauseSheet(person: person),
  );
}

class _PauseSheet extends StatefulWidget {
  const _PauseSheet({required this.person});

  final Person person;

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

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: AppDimensions.paddingL,
        right: AppDimensions.paddingL,
        top: AppDimensions.paddingL,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.pause_circle, color: AppColors.warning, size: 28),
                const SizedBox(width: AppDimensions.paddingS),
                Expanded(
                  child: Text(
                    context.l10n.peoplePauseTitle('${p.firstName} ${p.lastName}'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.paddingL),
            TextField(
              controller: _reasonController,
              decoration: InputDecoration(
                labelText: context.l10n.peopleReasonRequired,
                hintText: context.l10n.personPauseReasonPlaceholder,
                border: const OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.sentences,
              minLines: 2,
              maxLines: 5,
              autofocus: true,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: AppDimensions.paddingM),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event, color: AppColors.primary),
              title: Text(context.l10n.peoplePausedFrom),
              subtitle: Text(
                _from != null ? DateFormat(dateFmt()).format(_from!) : context.l10n.peopleFromToday,
                style: TextStyle(
                  color: _from != null ? AppColors.primary : AppColors.medium,
                ),
              ),
              trailing: _from != null
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: AppColors.medium),
                      onPressed: () => setState(() => _from = null),
                    )
                  : null,
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _from ?? today,
                  firstDate: DateTime(today.year - 5),
                  lastDate: today,
                );
                if (date != null) setState(() => _from = date);
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_available, color: AppColors.primary),
              title: Text(context.l10n.signoutPausedUntil),
              subtitle: Text(
                _until != null ? DateFormat(dateFmt()).format(_until!) : context.l10n.peopleNoEndDate,
                style: TextStyle(
                  color: _until != null ? AppColors.primary : AppColors.medium,
                ),
              ),
              trailing: _until != null
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: AppColors.medium),
                      onPressed: () => setState(() => _until = null),
                    )
                  : null,
              onTap: () async {
                final date = await showDatePicker(
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
                style: const TextStyle(color: AppColors.medium, fontSize: 13),
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
              icon: const Icon(Icons.pause),
              label: Text(context.l10n.peoplePause),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.warning,
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
  Person person,
) async {
  final input = await showPauseSheet(context, person);
  if (input == null || !context.mounted) return false;

  final messenger = ScaffoldMessenger.of(context);
  final repo = ref.read(playerRepositoryWithTenantProvider);
  final text = buildPauseHistoryText(input.reason,
      from: input.from, until: input.until);
  final until = input.until != null ? DateHelper.isoDay(input.until!) : null;
  final from = input.from != null ? DateHelper.isoDay(input.from!) : null;

  try {
    await repo.pausePlayer(person, until, text, pauseFrom: from);
  } catch (e) {
    messenger.showSnackBar(
      SnackBar(content: Text(l10nWithoutContext.peopleFlutterErrorWith(e)), backgroundColor: AppColors.danger),
    );
    return false;
  }

  messenger.showSnackBar(
    SnackBar(
      content: Text(l10nWithoutContext.peopleFlutterPausedToast(person.firstName)),
      backgroundColor: AppColors.success,
    ),
  );

  final appId = person.appId;
  if (appId == null || !context.mounted) return true;

  // "Auch in anderen Instanzen pausieren?"
  try {
    final linkedIds = await ref.read(linkedTenantIdsProvider.future);
    if (linkedIds.isEmpty) return true;
    final crossRepo = ref.read(crossTenantPersonRepositoryWithTenantProvider);
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

    final entry = {
      'date': DateTime.now().toIso8601String(),
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
  final selected = <int>{};
  return showDialog<List<LinkedTenantRef>>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
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
