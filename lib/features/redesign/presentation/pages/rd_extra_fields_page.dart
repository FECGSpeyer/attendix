import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/church_providers.dart';
import '../../../../core/providers/files_providers.dart' show extraFieldsRepositoryWithTenantProvider;
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/router/redesign_routes.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/tenant/tenant.dart';
import '../../../../data/repositories/extra_fields_repository.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/adaptive/app_action_sheet.dart';
import '../../../settings/presentation/pages/extra_fields_page.dart'
    show ExtraFieldTarget, ProviderRead, extraFieldChurchIds, extraFieldSummaryLines, saveExtraFieldDefinitions, showExtraFieldSheet;
import '../../data/rd_manage_logic.dart' show RdManageEntry;
import '../widgets/manage/rd_manage_entries.dart' show rdManageTitle;
import '../widgets/manage/rd_manage_list.dart';

Future<void> _extraFieldWrites = Future.value();

/// Runs [task] after every earlier write of the extra fields from the Beta
/// pages (list and edit page), so each one builds both lists from the state
/// the previous one left (a save still running from a closed edit page is
/// never overwritten by a reorder or a new field).
Future<T> rdSerialExtraFieldWrite<T>(Future<T> Function() task) {
  final result = _extraFieldWrites.then((_) => task());
  _extraFieldWrites = result.then((_) {}, onError: (Object _) {});
  return result;
}

/// Saves the person and work fields of [repo]'s tenant like "Speichern" of
/// the old page (definitions, then the values are cleaned). Returns false
/// without writing when that tenant is no longer the current one (the lists
/// are always built from the current tenant). Throws when saving fails.
Future<bool> rdSaveExtraFields(
  ProviderRead read,
  ExtraFieldsRepository repo, {
  required List<ExtraField> persons,
  required List<ExtraField> songs,
}) async {
  if (!repo.hasTenantId || read(currentTenantProvider)?.id != repo.currentTenantId) return false;
  await saveExtraFieldDefinitions(
    read,
    repo,
    personFields: List.unmodifiable(persons),
    songFields: List.unmodifiable(songs),
    churchIds: List.unmodifiable(extraFieldChurchIds(read)),
  );
  return true;
}

/// REDESIGN: Verwaltung › Zusatzfelder in the template "Verwaltungsliste"
/// (replaces `/settings/general/extra-fields` while the Beta is on). The
/// fields for persons and for works as two sections, type and display as
/// subtitle (like the old page). "+" asks for which list and opens the old
/// add sheet, then "Zusatzfeld bearbeiten". The order is changed behind
/// "•••" › "Reihenfolge ändern" (each list on its own). Every change is
/// saved right away like "Speichern" of the old page.
class RdExtraFieldsPage extends ConsumerStatefulWidget {
  const RdExtraFieldsPage({super.key});

  @override
  ConsumerState<RdExtraFieldsPage> createState() => _RdExtraFieldsPageState();
}

class _RdExtraFieldsPageState extends ConsumerState<RdExtraFieldsPage> {
  bool _adding = false;

  Future<bool> _saveOrder(List<RdManageListSection> sections) async {
    final l10n = context.l10n;
    final repo = ref.read(extraFieldsRepositoryWithTenantProvider);
    final read = ref.read;
    List<ExtraField> ordered(Object key, List<ExtraField> fields) {
      final byId = {for (final f in fields) f.id: f};
      final items = sections.where((s) => s.key == key).firstOrNull?.items ?? const <RdManageListItem>[];
      final result = [for (final i in items) if (byId[i.id] != null) byId[i.id]!];
      // Nothing may get lost: fields the list did not show stay at the end.
      return [...result, ...fields.where((f) => !result.contains(f))];
    }

    var ok = false;
    try {
      ok = await rdSerialExtraFieldWrite(() async {
        // The fields as stored now (after earlier writes).
        final tenant = read(currentTenantProvider);
        if (tenant == null) return false;
        return rdSaveExtraFields(
          read,
          repo,
          persons: ordered(ExtraFieldTarget.person, tenant.additionalFields ?? const []),
          songs: ordered(ExtraFieldTarget.song, tenant.songAdditionalFields ?? const []),
        );
      });
    } catch (_) {
      ok = false;
    }
    if (!mounted) return ok;
    if (ok) {
      ToastHelper.showSuccess(context, l10n.extraFieldsSaved);
    } else {
      ToastHelper.showError(context, l10n.redesignManageListOrderFailed);
    }
    return ok;
  }

  Future<void> _add() async {
    if (_adding) return;
    final l10n = context.l10n;
    final target = await showAppActionSheet<ExtraFieldTarget>(
      context,
      title: l10n.redesignExtraFieldsListAddFor,
      actions: [
        AppActionSheetAction(
          value: ExtraFieldTarget.person,
          icon: Icons.person_outline,
          label: l10n.redesignExtraFieldsListPersons,
        ),
        AppActionSheetAction(
          value: ExtraFieldTarget.song,
          icon: Icons.library_music_outlined,
          label: l10n.redesignExtraFieldsListSongs,
        ),
      ],
    );
    if (target == null || !mounted) return;
    final song = target == ExtraFieldTarget.song;
    // Bound before the first await: the field goes to this tenant.
    final repo = ref.read(extraFieldsRepositoryWithTenantProvider);
    List<ExtraField> fieldsOf(Tenant? t) =>
        (song ? t?.songAdditionalFields : t?.additionalFields) ?? const <ExtraField>[];
    final field = await showExtraFieldSheet(
      context,
      ref,
      target: target,
      fields: () => fieldsOf(ref.read(currentTenantProvider)),
    );
    if (field == null || !mounted) return;
    final read = ref.read;
    setState(() => _adding = true);
    var ok = false;
    try {
      ok = await rdSerialExtraFieldWrite(() async {
        final tenant = read(currentTenantProvider);
        // Same id added meanwhile (old sheet checks when it closes).
        if (fieldsOf(tenant).any((f) => f.id == field.id)) return false;
        return rdSaveExtraFields(
          read,
          repo,
          persons: song ? (tenant?.additionalFields ?? const []) : [...?tenant?.additionalFields, field],
          songs: song ? [...?tenant?.songAdditionalFields, field] : (tenant?.songAdditionalFields ?? const []),
        );
      });
    } catch (_) {
      ok = false;
    }
    if (!mounted) return;
    setState(() => _adding = false);
    if (!ok) {
      ToastHelper.showError(context, l10n.extraFieldsSaveFailed);
      return;
    }
    context.push(RedesignRoutes.extraFieldEdit(song: song, id: field.id));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // Churches preloaded (default of the BFECG church field), like the old page.
    ref.watch(churchesProvider);
    final tenant = ref.watch(currentTenantProvider);

    return RdManageListPage(
      title: rdManageTitle(l10n, RdManageEntry.extraFields),
      intro: l10n.redesignExtraFieldsListIntro,
      sections:
          tenant == null
              ? null
              : rdExtraFieldSections(
                l10n,
                persons: tenant.additionalFields ?? const [],
                songs: tenant.songAdditionalFields ?? const [],
                onTap: (song, id) => context.push(RedesignRoutes.extraFieldEdit(song: song, id: id)),
              ),
      emptyText: l10n.redesignExtraFieldsListEmpty,
      emptyIcon: Icons.dynamic_form_outlined,
      addLabel: l10n.redesignExtraFieldsListAdd,
      onAdd: _adding ? null : _add,
      // The fields live on the tenant (loaded with it), like the old page:
      // no pull to refresh.
      onReorder: tenant == null ? null : _saveOrder,
    );
  }
}

/// The fields as two sections ("Für Personen", "Für Werke"); key is the
/// [ExtraFieldTarget], the subtitle the lines of the old page.
List<RdManageListSection> rdExtraFieldSections(
  AppLocalizations l10n, {
  required List<ExtraField> persons,
  required List<ExtraField> songs,
  void Function(bool song, String id)? onTap,
}) {
  RdManageListSection section(ExtraFieldTarget target, String title, List<ExtraField> fields) {
    final song = target == ExtraFieldTarget.song;
    return RdManageListSection(
      key: target,
      title: title,
      items: [
        for (final f in fields)
          RdManageListItem(
            id: f.id,
            title: f.name,
            subtitle: extraFieldSummaryLines(l10n, f, person: !song).join(' · '),
            onTap: onTap == null ? null : () => onTap(song, f.id),
          ),
      ],
    );
  }

  return [
    section(ExtraFieldTarget.person, l10n.redesignExtraFieldsListPersons, persons),
    section(ExtraFieldTarget.song, l10n.redesignExtraFieldsListSongs, songs),
  ];
}
