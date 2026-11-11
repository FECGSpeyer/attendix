import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/assistant_repository.dart';
import '../../data/repositories/duty_repository.dart' show DutyTakeResult;
import '../../features/assistant/data/assistant_command.dart';
import '../../features/assistant/data/assistant_executor.dart';
import '../../features/assistant/data/assistant_reply.dart';
import 'locale_provider.dart';
import 'tenant_providers.dart';

/// Chat assistant repository of the current tenant.
final assistantRepositoryWithTenantProvider = Provider<AssistantRepository>((ref) {
  return ref.watch(assistantRepositoryForTenantProvider(ref.watch(currentTenantIdProvider)));
});

/// Whether the admin switched the assistant on for the current tenant and
/// the role may use it (not applicants).
final assistantEnabledProvider = Provider<bool>((ref) {
  final tenant = ref.watch(currentTenantProvider);
  final role = ref.watch(currentRoleProvider);
  return (tenant?.aiAssistantEnabled ?? false) && role.canView;
});

/// One line of the chat: the person's text or the assistant's answer.
class AssistantMessage {
  const AssistantMessage.user(String this.text) : reply = null;
  const AssistantMessage.assistant(AssistantReply this.reply) : text = null;

  final String? text;
  final AssistantReply? reply;

  bool get fromUser => text != null;
}

class AssistantChatState {
  const AssistantChatState({this.messages = const [], this.busy = false});

  final List<AssistantMessage> messages;

  /// Waiting for the answer (the input is locked, one message at a time).
  final bool busy;

  AssistantChatState copyWith({List<AssistantMessage>? messages, bool? busy}) =>
      AssistantChatState(messages: messages ?? this.messages, busy: busy ?? this.busy);
}

/// The chat of the current tenant (kept in memory only; a tenant switch
/// starts a new chat). Messages are not stored anywhere.
class AssistantChatNotifier extends Notifier<AssistantChatState> {
  @override
  AssistantChatState build() {
    ref.watch(currentTenantIdProvider);
    return const AssistantChatState();
  }

  void _add(AssistantMessage m) => state = state.copyWith(messages: [...state.messages, m]);

  /// Sends a typed message: the model names the command, the app answers.
  Future<void> send(String text) async {
    final clean = text.trim();
    if (clean.isEmpty || state.busy) return;
    _add(AssistantMessage.user(clean));
    if (clean.length > assistantMaxTextLength) {
      _add(const AssistantMessage.assistant(NoticeReply(AssistantNotice.tooLong)));
      return;
    }
    state = state.copyWith(busy: true);
    // Repositories bound to the current tenant before the first await.
    final repo = ref.read(assistantRepositoryWithTenantProvider);
    final executor = AssistantExecutor(ref);
    try {
      final command = await repo.ask(
        text: clean,
        today: DateTime.now(),
        language: ref.read(localeProvider).languageCode,
      );
      _add(AssistantMessage.assistant(await _answer(executor, command)));
    } on AssistantException catch (e) {
      _add(
        AssistantMessage.assistant(
          NoticeReply(switch (e.failure) {
            AssistantFailure.disabled => AssistantNotice.disabled,
            AssistantFailure.limit => AssistantNotice.limit,
            AssistantFailure.tooLong => AssistantNotice.tooLong,
            AssistantFailure.failed => AssistantNotice.failed,
          }),
        ),
      );
    } catch (_) {
      _add(const AssistantMessage.assistant(NoticeReply(AssistantNotice.failed)));
    } finally {
      state = state.copyWith(busy: false);
    }
  }

  /// A tapped option of a [ChoiceReply]: answered without the model.
  Future<void> choose(String label, AssistantCommand command) async {
    if (state.busy) return;
    _add(AssistantMessage.user(label));
    state = state.copyWith(busy: true);
    final executor = AssistantExecutor(ref);
    try {
      _add(AssistantMessage.assistant(await _answer(executor, command)));
    } catch (_) {
      _add(const AssistantMessage.assistant(NoticeReply(AssistantNotice.failed)));
    } finally {
      state = state.copyWith(busy: false);
    }
  }

  void clear() {
    if (state.busy) return;
    state = const AssistantChatState();
  }

  void _replace(int index, AssistantReply reply) {
    final list = [...state.messages];
    list[index] = AssistantMessage.assistant(reply);
    state = state.copyWith(messages: list);
  }

  AssistantReply? _replyAt(int index) =>
      index >= 0 && index < state.messages.length ? state.messages[index].reply : null;

  /// "Speichern" on a preview. Saves nothing on the first tap when the
  /// preview needs a second confirmation (many rows).
  Future<void> confirm(int index) async {
    final reply = _replyAt(index);
    if (reply is! ActionPreviewReply || state.busy) return;
    if (reply.state == ActionState.pending && reply.needsSecondConfirm) {
      _replace(index, reply.withState(ActionState.confirmAgain));
      return;
    }
    if (reply.state != ActionState.pending && reply.state != ActionState.confirmAgain) return;
    _replace(index, reply.withState(ActionState.saving));
    state = state.copyWith(busy: true);
    // Repositories bound to the current tenant before the first await.
    final executor = AssistantExecutor(ref);
    try {
      final AssistantReply done;
      switch (reply) {
        case StatusPreviewReply(:final plan):
          final count = await executor.applyStatus(plan);
          done = ActionDoneReply(statusPlan: plan, count: count);
        case AbsencePreviewReply(:final plan):
          final saved = await executor.applyAbsence(plan);
          done = ActionDoneReply(absencePlan: plan, absence: saved.absence, count: saved.count);
        case CreatePreviewReply(:final plan):
          final ids = await executor.applyCreate(plan);
          done = ActionDoneReply(createPlan: plan, createdIds: ids, count: ids.length);
        case MovePreviewReply(:final plan):
          final restore = await executor.applyMove(plan);
          done = ActionDoneReply(movePlan: plan, moveRestore: restore, count: 1);
        case SongsPreviewReply(:final plan):
          await executor.applySongs(plan);
          done = ActionDoneReply(songsPlan: plan, count: plan.added.length + plan.removed.length);
        case TaskPreviewReply(:final plan):
          final id = await executor.applyTask(plan);
          done = ActionDoneReply(
            taskPlan: plan,
            taskId: id,
            // Push only when tapped, and never to oneself.
            notify: plan.personId != null && !plan.isMe ? NotifyState.available : NotifyState.none,
            count: 1,
          );
        case DutyPreviewReply(:final plan):
          final result = await executor.applyDuty(plan);
          done =
              result == DutyTakeResult.ok
                  ? ActionDoneReply(dutyPlan: plan, count: 1)
                  : NoticeReply(switch (result) {
                    DutyTakeResult.full => AssistantNotice.dutyFull,
                    DutyTakeResult.notMember => AssistantNotice.dutyNotMember,
                    DutyTakeResult.past => AssistantNotice.eventLocked,
                    _ => AssistantNotice.dutyNotSelf,
                  });
      }
      _replace(index, reply.withState(ActionState.done));
      _add(AssistantMessage.assistant(done));
    } catch (_) {
      _replace(index, reply.withState(ActionState.done));
      _add(const AssistantMessage.assistant(NoticeReply(AssistantNotice.failed)));
    } finally {
      state = state.copyWith(busy: false);
    }
  }

  /// "Abbrechen" on a preview: nothing is saved.
  void cancel(int index) {
    final reply = _replyAt(index);
    if (reply is! ActionPreviewReply || state.busy) return;
    if (reply.state != ActionState.pending && reply.state != ActionState.confirmAgain) return;
    _replace(index, reply.withState(ActionState.cancelled));
  }

  /// "Rückgängig" on a saved change (once).
  Future<void> undo(int index) async {
    final reply = _replyAt(index);
    if (reply is! ActionDoneReply || reply.undo != UndoState.available || state.busy) return;
    _replace(index, reply.withUndo(UndoState.working));
    state = state.copyWith(busy: true);
    final executor = AssistantExecutor(ref);
    try {
      if (reply.statusPlan != null) {
        await executor.revertStatus(reply.statusPlan!);
      } else if (reply.absence != null && reply.absencePlan != null) {
        await executor.revertAbsence(reply.absence!, reply.absencePlan!);
      } else if (reply.createPlan != null) {
        await executor.revertCreate(reply.createdIds);
      } else if (reply.movePlan != null) {
        await executor.revertMove(reply.movePlan!, reply.moveRestore);
      } else if (reply.songsPlan != null) {
        await executor.revertSongs(reply.songsPlan!);
      } else if (reply.taskId != null) {
        await executor.revertTask(reply.taskId!);
      } else if (reply.dutyPlan != null) {
        await executor.revertDuty(reply.dutyPlan!);
      }
      _replace(index, reply.withUndo(UndoState.undone));
    } catch (_) {
      _replace(index, reply.withUndo(UndoState.failed));
    } finally {
      state = state.copyWith(busy: false);
    }
  }

  /// "Benachrichtigen" on a new task (once, not after undo).
  Future<void> notifyTask(int index) async {
    final reply = _replyAt(index);
    if (reply is! ActionDoneReply ||
        reply.taskId == null ||
        reply.notify != NotifyState.available ||
        reply.undo != UndoState.available ||
        state.busy) {
      return;
    }
    _replace(index, reply.withNotify(NotifyState.working));
    final executor = AssistantExecutor(ref);
    try {
      await executor.notifyTask(reply.taskId!);
      _replace(index, (_replyAt(index) as ActionDoneReply).withNotify(NotifyState.sent));
    } catch (_) {
      _replace(index, (_replyAt(index) as ActionDoneReply).withNotify(NotifyState.failed));
    }
  }

  Future<AssistantReply> _answer(AssistantExecutor executor, AssistantCommand command) async {
    try {
      return await executor.run(command);
    } catch (_) {
      return const NoticeReply(AssistantNotice.failed);
    }
  }
}

final assistantChatNotifierProvider = NotifierProvider<AssistantChatNotifier, AssistantChatState>(
  AssistantChatNotifier.new,
);
