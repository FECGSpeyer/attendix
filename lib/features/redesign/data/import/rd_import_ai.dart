import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/supabase_config.dart';
import '../../../../core/utils/choir_file_utils.dart';
import 'rd_import_logic.dart';

/// REDESIGN: suggestions of the KI for the questions of "Noten importieren".
/// The `part-suggest` Edge Function guesses for each unknown part name which
/// group (or which kind of file) it means. Sure guesses are pre-filled, the
/// others are offered; the person sees and can change every one.

/// A guess for one question.
class RdImportAiAnswer {
  const RdImportAiAnswer(this.category, {required this.sure});

  final RdImportCategory category;

  /// Pre-filled (the KI is sure); otherwise only offered.
  final bool sure;

  @override
  bool operator ==(Object other) => other is RdImportAiAnswer && other.category == category && other.sure == sure;

  @override
  int get hashCode => Object.hash(category, sure);
}

/// Where the KI suggestions are.
enum RdImportAiStatus {
  /// Not asked (switched off, no questions).
  off,
  loading,
  done,

  /// The day's KI budget is used up.
  limit,

  /// Not reachable or not set up: the questions work without.
  failed,
}

/// Category of one answer of `part-suggest`; null when it does not fit the
/// tenant ([groups], [isChoir]).
RdImportCategory? rdImportAiCategory(Map<String, dynamic> answer, {required Set<int> groups, required bool isChoir}) {
  switch (answer['kind']) {
    case 'group':
      final id = answer['groupId'];
      return id is int && groups.contains(id) ? RdImportCategory(instrumentId: id) : null;
    case 'new':
      final name = answer['newGroup'];
      if (name is! String) return null;
      final trimmed = name.trim();
      return trimmed.isEmpty || trimmed.length > 40 ? null : RdImportCategory(newGroup: trimmed);
    case 'recording':
      return const RdImportCategory(instrumentId: 1);
    case 'lyrics':
      return const RdImportCategory(instrumentId: 2);
    case 'score':
      return const RdImportCategory(note: 'Partitur');
    case 'piano':
      return const RdImportCategory(note: 'Klavierauszug');
    case 'sibelius':
      return const RdImportCategory(note: 'Sibelius');
    case 'midi':
      return const RdImportCategory(note: 'MIDI');
    case 'choir':
      return isChoir ? const RdImportCategory(note: kChoirAllNote) : null;
    case 'other':
      return RdImportCategory.other;
  }
  return null;
}

class RdImportAi {
  RdImportAi(this._invoke);

  /// Calls the function on [client].
  factory RdImportAi.supabase(SupabaseClient client) => RdImportAi((body) async {
        final response = await client.functions.invoke(function, body: body).timeout(const Duration(seconds: 60));
        return response.data;
      });

  static const function = 'part-suggest';

  /// Questions per call (the function refuses more).
  static const maxQuestions = 80;

  static final _key = RegExp(r'^[\p{L}\p{N} ._+\-]{1,80}$', unicode: true);

  final Future<dynamic> Function(Map<String, dynamic> body) _invoke;

  /// Guesses for [questions] of [tenantId]'s import, by question key. Keys
  /// the KI left out or answered with something that does not fit are
  /// missing.
  Future<({Map<String, RdImportAiAnswer> answers, RdImportAiStatus status})> suggest(
    int tenantId,
    List<RdImportQuestion> questions, {
    required Set<int> groups,
    required bool isChoir,
  }) async {
    final asked = [
      for (final q in questions)
        if (_key.hasMatch(q.key)) q,
    ].take(maxQuestions).toList();
    if (asked.isEmpty) return (answers: const <String, RdImportAiAnswer>{}, status: RdImportAiStatus.off);
    dynamic data;
    try {
      data = await _invoke({
        'tenantId': tenantId,
        'questions': [
          for (final q in asked)
            {
              'key': q.key,
              'label': q.label,
              'files': q.files,
              'works': q.works,
            },
        ],
      });
      if (data is String) data = jsonDecode(data);
    } on FunctionException catch (e) {
      return (answers: const <String, RdImportAiAnswer>{}, status: e.status == 429 ? RdImportAiStatus.limit : RdImportAiStatus.failed);
    } catch (_) {
      return (answers: const <String, RdImportAiAnswer>{}, status: RdImportAiStatus.failed);
    }
    final keys = {for (final q in asked) q.key};
    final answers = <String, RdImportAiAnswer>{};
    final list = data is Map ? data['answers'] : null;
    if (list is List) {
      for (final a in list) {
        if (a is! Map<String, dynamic>) continue;
        final key = a['key'];
        if (key is! String || !keys.contains(key) || answers.containsKey(key)) continue;
        final category = rdImportAiCategory(a, groups: groups, isChoir: isChoir);
        if (category == null) continue;
        answers[key] = RdImportAiAnswer(category, sure: a['confidence'] == 'high');
      }
    }
    return (answers: answers, status: RdImportAiStatus.done);
  }
}

final rdImportAiProvider = Provider<RdImportAi>((ref) => RdImportAi.supabase(ref.watch(supabaseClientProvider)));
