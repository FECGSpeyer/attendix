import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/group_providers.dart';
import '../../../data/models/instrument/instrument.dart';

/// Validation of the teacher form:
/// - create: requires at least 3 chars in name and >= 1 instrument;
/// - edit: allows saving existing entries even without instruments.
bool isTeacherFormValid({
  required bool isNew,
  required String name,
  required Iterable<int> instruments,
}) {
  if (!isNew) return true;
  return name.length >= 3 && instruments.isNotEmpty;
}

/// All groups of the tenant; waits for them if no page loaded them yet.
Future<List<Group>> loadTeacherGroups(WidgetRef ref) async {
  try {
    return await ref.read(groupsProvider.future);
  } catch (_) {
    return ref.read(groupsProvider).valueOrNull ?? const [];
  }
}
