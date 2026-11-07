import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/supabase_config.dart';
import '../../../../core/utils/choir_file_utils.dart';
import '../../../../core/utils/instrument_matcher.dart';
import '../../../songs/presentation/widgets/file_upload_sheet.dart' show guessFileCategory;
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
      // A group is one instrument: "Posaune und Tuba" is no answer.
      if (InstrumentMatcher.knownGroups(trimmed, isChoir: isChoir).length > 1) return null;
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

/// What part-detect read on page 1 ([groupId] of the tenant's groups,
/// [label] the part name as printed) as the file's part: the group, else
/// what the label names (a group, Partitur …, one known instrument without
/// a group: "Neue Gruppe"); null when it names nothing usable. Only a sure
/// read of a group is taken without a look.
RdImportPageRead? rdImportPageRead({
  int? groupId,
  String? label,
  required bool sure,
  required List<InstrumentInfo> instruments,
  required bool isChoir,
}) {
  final text = (label ?? '').trim();
  if (groupId != null && instruments.any((i) => i.id == groupId)) {
    return RdImportPageRead(RdImportCategory(instrumentId: groupId), label: text.isEmpty ? null : text, sure: sure);
  }
  if (text.isEmpty || text.length > 80) return null;
  // As a file name: a label like "1. Vl" has no file ending to strip.
  final asName = '$text.pdf';
  final guess = guessFileCategory(asName, instruments: instruments, isChoir: false);
  if (guess.confidence == MatchConfidence.sure && (guess.instrumentId != null || guess.note != null)) {
    return RdImportPageRead(RdImportCategory(instrumentId: guess.instrumentId, note: guess.note), label: text);
  }
  final known = InstrumentMatcher.knownGroups(asName, isChoir: isChoir);
  if (known.length != 1) return null;
  final name = known.single;
  final existing = instruments.where((i) => i.name.trim().toLowerCase() == name.toLowerCase()).firstOrNull;
  return RdImportPageRead(
    existing != null ? RdImportCategory(instrumentId: existing.id) : RdImportCategory(newGroup: name),
    label: text,
  );
}

class RdImportAi {
  /// [works] calls `work-match`; without it no Werk is matched.
  RdImportAi(this._invoke, {Future<dynamic> Function(Map<String, dynamic> body)? works})
      : _works = works ?? ((_) async => const {'matches': []});

  /// Calls the function on [client].
  factory RdImportAi.supabase(SupabaseClient client) => RdImportAi(
        (body) async {
          final response = await client.functions.invoke(function, body: body).timeout(const Duration(seconds: 60));
          return response.data;
        },
        works: (body) async {
          final response = await client.functions.invoke(worksFunction, body: body).timeout(const Duration(seconds: 90));
          return response.data;
        },
      );

  static const function = 'part-suggest';

  /// Finds the Werk in Attendix of folders the comparison is not sure about.
  static const worksFunction = 'work-match';

  /// Folders per call (the function refuses more).
  static const maxWorks = 150;

  /// Questions per call (the function refuses more).
  static const maxQuestions = 80;

  static final _key = RegExp(r'^[\p{L}\p{N} ._+\-]{1,80}$', unicode: true);

  final Future<dynamic> Function(Map<String, dynamic> body) _invoke;
  final Future<dynamic> Function(Map<String, dynamic> body) _works;

  /// The Werk in Attendix the KI is sure each of [folders] (names) is, by
  /// folder name; folders it does not know or is unsure about are missing.
  /// Never throws: without the KI the comparison alone counts.
  Future<Map<String, int>> matchWorks(int tenantId, List<String> folders, {required Set<int> songs}) async {
    final asked = folders.take(maxWorks).toList();
    if (asked.isEmpty || songs.isEmpty) return const {};
    dynamic data;
    try {
      data = await _works({
        'tenantId': tenantId,
        'works': [
          for (var i = 0; i < asked.length; i++) {'key': 'w$i', 'name': asked[i]},
        ],
      });
      if (data is String) data = jsonDecode(data);
    } catch (_) {
      return const {};
    }
    final result = <String, int>{};
    final list = data is Map ? data['matches'] : null;
    if (list is List) {
      for (final m in list) {
        if (m is! Map) continue;
        final key = m['key'];
        final id = m['songId'];
        if (key is! String || !key.startsWith('w') || id is! int || !songs.contains(id) || m['confidence'] != 'high') continue;
        final index = int.tryParse(key.substring(1));
        if (index == null || index < 0 || index >= asked.length) continue;
        result.putIfAbsent(asked[index], () => id);
      }
    }
    return result;
  }

  /// Guesses for [questions] of [tenantId]'s import, by question key. Keys
  /// the KI left out or answered with something that does not fit are
  /// missing.
  Future<({Map<String, RdImportAiAnswer> answers, RdImportAiStatus status})> suggest(
    int tenantId,
    List<RdImportQuestion> questions, {
    required Set<int> groups,
    required bool isChoir,
  }) async {
    // Unknown names first: a known instrument already has its answer.
    final asked = [
      for (final q in [...questions.where((q) => q.newGroup == null), ...questions.where((q) => q.newGroup != null)])
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
