import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/assistant_repository.dart';
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
      _add(AssistantMessage.assistant(NoticeReply(switch (e.failure) {
        AssistantFailure.disabled => AssistantNotice.disabled,
        AssistantFailure.limit => AssistantNotice.limit,
        AssistantFailure.tooLong => AssistantNotice.tooLong,
        AssistantFailure.failed => AssistantNotice.failed,
      })));
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

  void clear() => state = const AssistantChatState();

  Future<AssistantReply> _answer(AssistantExecutor executor, AssistantCommand command) async {
    try {
      return await executor.run(command);
    } catch (_) {
      return const NoticeReply(AssistantNotice.failed);
    }
  }
}

final assistantChatNotifierProvider =
    NotifierProvider<AssistantChatNotifier, AssistantChatState>(AssistantChatNotifier.new);
