import 'package:flutter_riverpod/flutter_riverpod.dart';

/// REDESIGN (UX D3): "Fehlen oft" filter of the Mitglieder tab. A provider
/// and not page state, so "Heute" can open the tab already filtered.
final rdMembersCriticalOnlyProvider = StateProvider<bool>((ref) => false);
