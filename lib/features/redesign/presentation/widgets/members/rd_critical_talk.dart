import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/constants/enums.dart';
import '../../../../../core/providers/player_providers.dart';
import '../../../../../core/providers/realtime_providers.dart';
import '../../../../../core/theme/redesign/rd_theme.dart';
import '../../../../../core/utils/error_message.dart';
import '../../../../../core/utils/toast_helper.dart';
import '../../../../../data/models/person/person.dart';
import '../../../../../data/repositories/player_repository.dart';
import '../../../../../l10n/l10n.dart';
import '../../../../people/person_write.dart' show personProblemSolvedColumns, personProblemSolvedEntry;
import '../../../../people/presentation/pages/person_detail_page.dart' show personProvider;
import '../../../data/providers/rd_critical_providers.dart';
import '../../../data/rd_critical_logic.dart';
import '../manage/rd_settings_sheets.dart' show RdListNote;
import '../rd_widgets.dart';

/// REDESIGN: "Gespräch eintragen" for a Problemfall, right where the
/// Problemfälle are shown (the list of the current Problemfälle and the
/// person page). Before it sat only in "Person bearbeiten", far down
/// behind a switch. A short sheet with the reason, an optional note and
/// "Gespräch speichern"; saving writes what "Mit Person gesprochen" always
/// wrote (`isCritical` false, `lastSolve` now, a Verlauf entry with the
/// note) and offers "Rückgängig" for a few seconds.

/// Who may enter a conversation: like "Person bearbeiten" (Ionic: not
/// read-only), Admins and Verantwortliche.
bool rdCanRecordTalk(Role role) => role.isAdmin || role.isResponsible;

/// "4-mal unentschuldigt gefehlt" (red) over "in den letzten 30 Tagen ·
/// Regel „Fehlt oft“": why the person is a Problemfall.
class RdCriticalReasonRow extends StatelessWidget {
  const RdCriticalReasonRow(this.reason, {super.key});

  final RdCriticalReason reason;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final rule = reason.rule;
    final name = (rule.name ?? '').trim();
    return RdListRow(
      title: rdCriticalHitText(rule, reason.result, l10n),
      titleColor: context.rd.absent,
      subtitle:
          name.isEmpty
              ? rdCriticalPeriodText(rule, l10n)
              : l10n.rdCriticalReasonDetail(rdCriticalPeriodText(rule, l10n), name),
      showChevron: false,
    );
  }
}

/// The small "✓ Gespräch eintragen" button below a Problemfall in a list.
class RdTalkChip extends StatelessWidget {
  const RdTalkChip({super.key, required this.name, required this.onTap});

  final String name;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => RdChoiceChip(
    label: context.l10n.rdCriticalTalk,
    semanticLabel: context.l10n.rdCriticalTalkFor(name),
    icon: Icons.check,
    selected: false,
    onTap: onTap,
  );
}

/// Problemfall on top of the person page: why, and "Gespräch eintragen"
/// as the page's main action (like "Prüfen und freigeben" of a request).
class RdCriticalTalkCard extends ConsumerWidget {
  const RdCriticalTalkCard({super.key, required this.person});

  final Person person;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.rd;
    final l10n = context.l10n;
    final reason = rdCriticalContextOf(ref)?.reasonOf(person);
    final rule = reason?.rule;
    final name = (rule?.name ?? '').trim();
    return RdCard(
      key: const Key('rd-person-critical'),
      color: p.absentSoft,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: p.absent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  // Why; just "Problemfall" while it cannot be worked out.
                  reason == null ? l10n.peopleProblemCase : rdCriticalHitText(reason.rule, reason.result, l10n),
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: p.text),
                ),
              ),
            ],
          ),
          if (rule != null) ...[
            const SizedBox(height: 4),
            Text(
              name.isEmpty
                  ? rdCriticalPeriodText(rule, l10n)
                  : l10n.rdCriticalReasonDetail(rdCriticalPeriodText(rule, l10n), name),
              style: RdType.meta(p, size: 14),
            ),
          ],
          const SizedBox(height: 12),
          RdPrimaryButton(
            key: const Key('rd-person-talk'),
            icon: Icons.check,
            label: l10n.rdCriticalTalk,
            onPressed: () => rdRecordTalk(context, ref, person, reason: reason),
          ),
        ],
      ),
    );
  }
}

/// Opens the sheet for [person] and saves the conversation. [onHidden]
/// gets true as soon as it is saved (a list hides the row at once) and
/// false when saving failed or was undone. [run] runs the write in the
/// caller's write queue ("Person bearbeiten"); the undo runs on its own
/// (the page may be closed by then).
Future<void> rdRecordTalk(
  BuildContext context,
  WidgetRef ref,
  Person person, {
  RdCriticalReason? reason,
  ValueChanged<bool>? onHidden,
  Future<void> Function(Future<void> Function() write)? run,
}) async {
  final id = person.id;
  if (id == null) return;
  // TENANT: the group's repository, bound before the first await.
  final repo = ref.read(playerRepositoryWithTenantProvider);
  if (!repo.hasTenantId) return;
  final container = ProviderScope.containerOf(context, listen: false);
  // The toasts outlive the button: on the person page the card goes away
  // with the Problemfall.
  final toastContext = Navigator.of(context, rootNavigator: true).context;
  final l10n = context.l10n;
  final name = person.fullName.trim();
  final first = person.firstName.trim().isEmpty ? name : person.firstName.trim();
  final note = await showRdSheet<String>(context, _RdTalkSheet(name: name, firstName: first, reason: reason));
  if (note == null) return;

  onHidden?.call(true);
  _RdTalk? done;
  Object? error;
  Future<void> write() async {
    try {
      done = await _solve(repo, id, note.trim());
    } catch (e) {
      error = e;
    }
  }

  await (run?.call(write) ?? write());
  _refresh(container, id);
  final talk = done;
  if (talk == null) {
    onHidden?.call(false);
    if (toastContext.mounted) {
      ToastHelper.showError(
        toastContext,
        error == null ? l10n.redesignPersonNotFound : l10n.personUpdateFailedWith(friendlyErrorMessage(error!)),
      );
    }
    return;
  }
  if (!toastContext.mounted) return;
  ToastHelper.showSuccess(
    toastContext,
    l10n.rdCriticalTalkSaved(name),
    duration: const Duration(seconds: 6),
    action: ToastAction(
      label: l10n.redesignEventUndo,
      onPressed: () => unawaited(_undoTalk(toastContext, repo, container, talk, onHidden: onHidden)),
    ),
  );
}

/// What a saved conversation changed, to put it back.
class _RdTalk {
  const _RdTalk({required this.id, required this.wasCritical, required this.lastSolve, required this.entry});

  final int id;
  final bool wasCritical;
  final String? lastSolve;
  final Map<String, dynamic> entry;
}

/// Writes the conversation (id + tenantId). The history is the stored one,
/// not a shown copy: entries deleted in "Verlauf" stay deleted, entries
/// added elsewhere stay. Null when the person is gone.
Future<_RdTalk?> _solve(PlayerRepository repo, int id, String note) async {
  final stored = await repo.getPlayerById(id);
  if (stored == null) return null;
  final entry = personProblemSolvedEntry(note);
  await repo.updatePlayerFields(id, {
    ...personProblemSolvedColumns(),
    'history': [for (final h in stored.history) h.toJson(), entry],
  });
  return _RdTalk(id: id, wasCritical: stored.isCritical, lastSolve: stored.lastSolve, entry: entry);
}

/// "Rückgängig": Problemfall and last conversation as before, the Verlauf
/// entry removed again.
Future<void> _undoTalk(
  BuildContext context,
  PlayerRepository repo,
  ProviderContainer container,
  _RdTalk talk, {
  ValueChanged<bool>? onHidden,
}) async {
  Object? error;
  var ok = false;
  try {
    final stored = await repo.getPlayerById(talk.id);
    if (stored != null) {
      final history = [for (final h in stored.history) h.toJson()];
      final i = history.lastIndexWhere((h) => h['date'] == talk.entry['date'] && h['type'] == talk.entry['type']);
      if (i >= 0) history.removeAt(i);
      await repo.updatePlayerFields(talk.id, {
        'isCritical': talk.wasCritical,
        'lastSolve': talk.lastSolve,
        'history': history,
      });
      ok = true;
    }
  } catch (e) {
    error = e;
  }
  _refresh(container, talk.id);
  if (ok) onHidden?.call(false);
  if (!context.mounted) return;
  final l10n = context.l10n;
  if (ok) {
    ToastHelper.showSuccess(context, l10n.redesignEventUndone);
  } else {
    ToastHelper.showError(
      context,
      error == null ? l10n.redesignPersonNotFound : l10n.personUpdateFailedWith(friendlyErrorMessage(error)),
    );
  }
}

void _refresh(ProviderContainer container, int id) {
  container
    ..invalidate(realtimePlayersProvider)
    ..invalidate(criticalPlayersProvider)
    ..invalidate(playersProvider)
    ..invalidate(personProvider(id));
}

/// "Mit Anna Berg gesprochen": the reason, an optional note and
/// "Gespräch speichern". Returns the note ('' without), null when closed.
class _RdTalkSheet extends StatefulWidget {
  const _RdTalkSheet({required this.name, required this.firstName, this.reason});

  final String name;
  final String firstName;
  final RdCriticalReason? reason;

  @override
  State<_RdTalkSheet> createState() => _RdTalkSheetState();
}

class _RdTalkSheetState extends State<_RdTalkSheet> {
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final reason = widget.reason;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            RdSheetTitle(l10n.rdCriticalTalkTitle(widget.name)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (reason != null) ...[
                    RdGroupedList(children: [RdCriticalReasonRow(reason)]),
                    const SizedBox(height: 14),
                  ],
                  RdGroupLabel(l10n.rdCriticalTalkNote),
                  TextField(
                    key: const Key('rd-talk-note'),
                    controller: _note,
                    textCapitalization: TextCapitalization.sentences,
                    minLines: 2,
                    maxLines: 5,
                    decoration: InputDecoration(
                      hintText: l10n.rdCriticalTalkNoteHint,
                      filled: true,
                      fillColor: p.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(p.buttonRadius),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  RdListNote(l10n.rdCriticalTalkHint(widget.firstName)),
                  const SizedBox(height: 18),
                  RdPrimaryButton(
                    key: const Key('rd-talk-save'),
                    icon: Icons.check,
                    label: l10n.redesignPersonFormProblemSave,
                    onPressed: () => Navigator.of(context).pop(_note.text),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
