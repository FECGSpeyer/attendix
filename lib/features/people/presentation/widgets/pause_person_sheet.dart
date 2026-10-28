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

final _fmt = DateFormat('dd.MM.yyyy');

String _isoDay(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

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
                    '${p.firstName} ${p.lastName} Pausieren',
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
              decoration: const InputDecoration(
                labelText: 'Grund *',
                hintText: 'Gib einen Grund für die Pause an...',
                border: OutlineInputBorder(),
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
              title: const Text('Pausiert ab (optional)'),
              subtitle: Text(
                _from != null ? _fmt.format(_from!) : 'Ab heute',
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
              title: const Text('Pausiert bis (optional)'),
              subtitle: Text(
                _until != null ? _fmt.format(_until!) : 'Kein Enddatum gewählt',
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
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppDimensions.paddingS),
              child: Text(
                'Mit einem Startdatum in der Vergangenheit wird die Person auch '
                'aus zurückliegenden Anwesenheiten ab diesem Datum entfernt. '
                'Wenn ein Enddatum angegeben ist, wird die Person danach '
                'automatisch wieder aktiviert.',
                style: TextStyle(color: AppColors.medium, fontSize: 13),
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
              label: const Text('Pausieren'),
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
  final until = input.until != null ? _isoDay(input.until!) : null;
  final from = input.from != null ? _isoDay(input.from!) : null;

  try {
    await repo.pausePlayer(person, until, text, pauseFrom: from);
  } catch (e) {
    messenger.showSnackBar(
      SnackBar(content: Text('Fehler: $e'), backgroundColor: AppColors.danger),
    );
    return false;
  }

  messenger.showSnackBar(
    SnackBar(
      content: Text('${person.firstName} wurde pausiert'),
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
    final others =
        await crossRepo.getLinkedTenantsOfUser(appId, linkedTenantIds: linkedIds);
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
            content: Text(
                'Fehler bei ${tenant.shortName.isNotEmpty ? tenant.shortName : tenant.name}: $e'),
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
        title: const Text('Auch in anderen Instanzen pausieren?'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${person.firstName} ${person.lastName} ist auch in anderen '
                'Instanzen aktiv. In welchen soll die Person ebenfalls '
                'pausiert werden?',
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
            child: const Text('Überspringen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              ctx,
              tenants.where((t) => selected.contains(t.id)).toList(),
            ),
            child: const Text('Pausieren'),
          ),
        ],
      ),
    ),
  );
}
