import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/tenant_providers.dart';

/// Kind of the open group ("Art der Gruppe"). The words of the new design
/// for the parts of a group depend on it, because "Gruppe" is the tenant
/// itself there:
///
/// | kind        | members are divided by | summed up as |
/// |-------------|------------------------|--------------|
/// | `orchestra` | Instrument             | Register     |
/// | `choir`     | Stimme                 | Kategorie    |
/// | else        | Untergruppe            | Kategorie    |
///
/// Every text takes the kind (`l10n.rdWordsGroup(kind)`, select messages in
/// `lib/l10n/fragments`), so no page picks its own word. The sheet music of
/// one instrument stays "Stimme" everywhere, a Werk keeps its "Kategorie".
final rdGroupKindProvider = Provider<String>((ref) => ref.watch(currentTenantProvider.select((t) => t?.type ?? '')));

/// Whether the level above the groups (Register, Kategorie) is offered. A
/// choir has none ("nach Stimme reicht"): it only shows there while
/// [categories] from before still exist, so nothing gets out of reach.
bool rdOffersCategories(String kind, Iterable<Object?> categories) => kind != 'choir' || categories.isNotEmpty;

/// [rdGroupKindProvider] for the few sheets and helpers without a `ref`
/// (read once: the kind of a group does not change while they are open).
String rdGroupKindOf(BuildContext context) =>
    ProviderScope.containerOf(context, listen: false).read(rdGroupKindProvider);
