part of 'assistant_page.dart';

String _priority(AppLocalizations l10n, String p) => switch (p) {
  'high' => l10n.assistantTaskPriorityHigh,
  'low' => l10n.assistantTaskPriorityLow,
  _ => l10n.assistantTaskPriorityMedium,
};

/// Title of a message draft: a reminder for a Termin, otherwise neutral.
String _draftTitle(AppLocalizations l10n, MessageDraftReply m) =>
    m.eventTitle == null ? l10n.assistantMessageGenericTitle : l10n.assistantMessageReminderTitle(m.eventTitle!);

/// Text of a message draft: the Termin line (app text) and the person's
/// own words. The model never writes text of its own.
String _draftBody(AppLocalizations l10n, MessageDraftReply m) => [
  if (m.eventTitle != null && m.eventDate != null)
    m.eventTime == null
        ? l10n.assistantMessageReminderBody(m.eventTitle!, _weekdayDate(m.eventDate!))
        : l10n.assistantMessageReminderBodyTime(m.eventTitle!, _weekdayDate(m.eventDate!), m.eventTime!),
  if (m.note != null) m.note!,
].join('\n\n');

/// Status as a small coloured label.
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status, required this.style});

  final AttendanceStatus status;
  final _ChatStyle style;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final label = switch (status) {
      AttendanceStatus.present => l10n.assistantStatusPresent,
      AttendanceStatus.excused => l10n.assistantStatusExcused,
      AttendanceStatus.lateExcused => l10n.assistantStatusLateExcused,
      AttendanceStatus.late => l10n.assistantStatusLate,
      AttendanceStatus.absent => l10n.assistantStatusAbsent,
      AttendanceStatus.neutral => l10n.assistantStatusNeutral,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: status.color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(status.icon, size: 16, color: status.color),
          const SizedBox(width: 6),
          Text(l10n.assistantChangeNewStatus(label), style: TextStyle(color: style.text, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// "Speichern" / "Abbrechen" of a preview, or where it stands.
class _ActionButtons extends ConsumerWidget {
  const _ActionButtons({
    required this.index,
    required this.state,
    required this.busy,
    required this.count,
    required this.style,
  });

  final int index;
  final ActionState state;
  final bool busy;
  final int count;
  final _ChatStyle style;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final muted = TextStyle(color: style.muted, fontSize: 13);
    final notifier = ref.read(assistantChatNotifierProvider.notifier);
    switch (state) {
      case ActionState.cancelled:
        return Text(l10n.assistantChangeCancelled, style: muted);
      case ActionState.saving:
        return Text(l10n.assistantChangeSaving, style: muted);
      case ActionState.done:
        return const SizedBox.shrink();
      case ActionState.pending:
      case ActionState.confirmAgain:
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: state == ActionState.confirmAgain ? style.bad : style.accent,
                foregroundColor: style.onAccent,
              ),
              onPressed: busy ? null : () => notifier.confirm(index),
              icon: const Icon(Icons.check, size: 18),
              label: Text(
                state == ActionState.confirmAgain ? l10n.assistantChangeConfirmAgain(count) : l10n.assistantChangeSave,
              ),
            ),
            OutlinedButton(
              style: OutlinedButton.styleFrom(foregroundColor: style.text),
              onPressed: busy ? null : () => notifier.cancel(index),
              child: Text(l10n.assistantChangeCancel),
            ),
          ],
        );
    }
  }
}
