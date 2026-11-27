import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/group_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/router/redesign_routes.dart';
import '../../../../core/services/ai_service.dart';
import '../../../../core/services/offline_queue_service.dart';
import '../../../../core/services/tracking/tracking_event.dart';
import '../../../../core/services/tracking/tracking_service.dart';
import '../../../../core/theme/redesign/rd_theme.dart';
import '../../../../core/utils/dialog_helper.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/instrument/instrument.dart';
import '../../../../data/repositories/group_repository.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/adaptive/app_action_sheet.dart';
import '../../data/group_options.dart'
    show groupClefLabel, groupClefOptions, groupTuningOptions;
import '../widgets/instrument_categories_sheet.dart';
import '../../../../core/redesign/rd_words.dart';
import '../../../attendance/presentation/widgets/event/rd_form_widgets.dart';
import '../../../../shared/widgets/redesign/rd_widgets.dart';
import '../../../today/presentation/widgets/rd_today_common.dart' show RdInfoCard;

part 'rd_group_edit_sections.dart';

/// Persons that are or were in a group (archived ones count, pending
/// registrations not), like the delete check of the old group page.
final rdGroupMemberCountProvider = FutureProvider.autoDispose.family<int, int>((
  ref,
  groupId,
) async {
  final repo = ref.watch(groupRepositoryWithTenantProvider);
  if (!repo.hasTenantId) return 0;
  return repo.getPlayerCountInGroup(groupId, includeArchived: true);
});

/// REDESIGN: "Gruppe bearbeiten" (template of "Werk bearbeiten"): every field
/// of the old group page (Name, Kategorie, Stimmung, Tonumfang,
/// Notenschlüssel, Synonyme with "Synonyme generieren", Notizen), saved
/// right away (text fields when they lose focus or the page closes).
/// Fields hidden for this group on the old page (choir, general, main
/// group) stay hidden and keep their value. "Gruppe löschen" sits at the
/// bottom and says why when a group cannot be deleted.
class RdGroupEditPage extends ConsumerStatefulWidget {
  const RdGroupEditPage({super.key, required this.groupId});

  final int groupId;

  @override
  ConsumerState<RdGroupEditPage> createState() => _RdGroupEditPageState();
}

class _RdGroupEditPageState extends ConsumerState<RdGroupEditPage> {
  final _name = TextEditingController();
  final _range = TextEditingController();
  final _synonyms = TextEditingController();
  final _notes = TextEditingController();
  final _nameFocus = FocusNode();
  final _rangeFocus = FocusNode();
  final _synonymsFocus = FocusNode();
  final _notesFocus = FocusNode();

  /// Text columns as last written (null value = never set); empty until the
  /// group is loaded.
  final Map<String, String?> _stored = {};

  int? _categoryId;
  String? _tuning;
  Set<String> _clefs = {};

  /// The group this form writes to, bound once.
  late final int _groupId = widget.groupId;

  bool _deleted = false;
  bool _deleting = false;
  bool _generating = false;

  /// Writes run one after another, so the last change always wins.
  Future<void> _queue = Future.value();

  /// Bound once the group is loaded, so text saved when the page closes
  /// still goes to the group's tenant.
  GroupRepository? _repo;
  late final ProviderContainer _container;
  late final OfflineWriteSession _session;

  void _update(VoidCallback fn) => setState(fn);

  TextEditingController _controllerOf(String column) => switch (column) {
    'name' => _name,
    'range' => _range,
    'synonyms' => _synonyms,
    _ => _notes,
  };

  @override
  void initState() {
    super.initState();
    _container = ProviderScope.containerOf(context, listen: false);
    _session =
        ref.read(offlineQueueNotifierProvider.notifier).captureWriteSession();
    for (final (focus, column) in [
      (_nameFocus, 'name'),
      (_rangeFocus, 'range'),
      (_synonymsFocus, 'synonyms'),
      (_notesFocus, 'notes'),
    ]) {
      focus.addListener(() {
        if (!focus.hasFocus) _saveText(column);
      });
    }
  }

  @override
  void dispose() {
    // Text typed last is saved when the page closes (no focus change).
    for (final column in const ['name', 'range', 'synonyms', 'notes']) {
      _saveText(column);
    }
    for (final c in [_name, _range, _synonyms, _notes]) {
      c.dispose();
    }
    for (final f in [_nameFocus, _rangeFocus, _synonymsFocus, _notesFocus]) {
      f.dispose();
    }
    super.dispose();
  }

  void _fill(Group group) {
    if (_repo != null) return;
    _repo = ref.read(groupRepositoryWithTenantProvider);
    _stored
      ..['name'] = group.name
      ..['range'] = group.range
      ..['synonyms'] = group.synonyms
      ..['notes'] = group.notes;
    _name.text = group.name;
    _range.text = group.range ?? '';
    _synonyms.text = group.synonyms ?? '';
    _notes.text = group.notes ?? '';
    _categoryId = group.categoryId;
    // Unpitched and unspecified catalog metadata must stay visibly unset.
    _tuning = group.tuning;
    _clefs =
        (group.clefs ?? const <String>[]).map((c) => c.toUpperCase()).toSet();
  }

  void _refresh() {
    _container
      ..invalidate(groupsProvider)
      ..invalidate(groupsMapProvider);
  }

  void _enqueue(Future<void> Function() task) {
    _queue = _queue.then((_) => task());
  }

  /// Writes [updates]; reports a failure while the page is open.
  Future<bool> _store(Map<String, dynamic> updates) async {
    final repo = _repo;
    if (_deleted ||
        repo == null ||
        !repo.hasTenantId ||
        !_session.isCurrent()) {
      return false;
    }
    try {
      await repo.updateGroup(_groupId, {...updates});
      _container
          .read(trackingServiceProvider)
          .track(TrackingEvent.instrumentUpdated);
      _refresh();
      return true;
    } catch (_) {
      if (mounted) {
        ToastHelper.showError(context, context.l10n.extraFieldsSaveFailed);
      }
      return false;
    }
  }

  /// Writes [updates]; on failure [revert] puts the shown value back.
  void _write(Map<String, dynamic> updates, {VoidCallback? revert}) =>
      _enqueue(() async {
        if (!await _store(updates) && revert != null && mounted && !_deleted) {
          setState(revert);
        }
      });

  /// Saves a text column when it differs from what is stored when it runs
  /// (the last typed value wins). Like the old page: trimmed, an empty field
  /// that was never set stays unset, an empty name is not saved.
  void _saveText(String column) {
    final value =
        _controllerOf(
          column,
        ).text.trim(); // read now: the page may be gone when it runs
    _enqueue(() async {
      if (!_stored.containsKey(column)) return;
      if (value == (_stored[column] ?? '')) return;
      if (column == 'name' && value.isEmpty) return;
      if (await _store({column: value})) _stored[column] = value;
    });
  }

  void _done() {
    FocusScope.of(context).unfocus();
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(RedesignRoutes.groups);
    }
  }

  Future<void> _pickCategory(List<GroupCategory> categories) async {
    final l10n = context.l10n;
    final choice = await showAppActionSheet<int>(
      context,
      title: l10n.rdWordsCategory(ref.read(rdGroupKindProvider)),
      actions: [
        AppActionSheetAction(
          value: -1,
          label: l10n.redesignGroupEditCategoryNone,
        ),
        for (final c in categories)
          if (c.id != null) AppActionSheetAction(value: c.id!, label: c.name),
      ],
    );
    if (choice == null || !mounted) return;
    final id = choice == -1 ? null : choice;
    if (id == _categoryId) return;
    final before = _categoryId;
    setState(() => _categoryId = id);
    _write(
      {'category': id},
      revert: () {
        if (_categoryId == id) _categoryId = before;
      },
    );
  }

  void _toggleClef(String clef) {
    final next = {..._clefs};
    if (next.contains(clef)) {
      next.remove(clef);
    } else {
      next.add(clef);
    }
    _setClefs(next);
  }

  void _setClefs(Set<String> next) {
    final before = _clefs;
    setState(() => _clefs = next);
    _write(
      {
        'clefs': [
          for (final c in groupClefOptions)
            if (next.contains(c)) c.toLowerCase(),
        ],
      },
      revert: () {
        if (identical(_clefs, next)) _clefs = before;
      },
    );
  }

  /// Old page: synonyms from the AI function `synonyms-gpt`.
  Future<void> _generateSynonyms() async {
    final l10n = context.l10n;
    final name = _name.text.trim();
    if (name.isEmpty) {
      ToastHelper.showError(context, l10n.instrumentsNameFirst);
      return;
    }
    setState(() => _generating = true);
    try {
      final others = ref.read(groupsProvider).valueOrNull ?? const <Group>[];
      final synonyms = await ref
          .read(aiServiceProvider)
          .getGroupSynonyms(
            name,
            existing: _synonyms.text,
            otherGroups: [
              for (final g in others)
                if (g.id != _groupId) (name: g.name, synonyms: g.synonyms),
            ],
          );
      if (!mounted) return;
      _synonyms.text = synonyms;
      _saveText('synonyms');
      ToastHelper.showSuccess(context, l10n.instrumentsSynonymsGenerated);
    } catch (_) {
      if (mounted) {
        ToastHelper.showError(context, l10n.instrumentsSynonymsFailed);
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  /// Old page: checks right away whether anyone is or was in the group
  /// (then it says why it cannot), otherwise asks and deletes.
  Future<void> _delete(Group group) async {
    if (_deleting) return;
    final l10n = context.l10n;
    final kind = ref.read(rdGroupKindProvider);
    setState(() => _deleting = true);
    try {
      int count;
      try {
        count = await ref
            .read(groupRepositoryWithTenantProvider)
            .getPlayerCountInGroup(_groupId, includeArchived: true);
      } catch (_) {
        // Unknown member count: never delete a group that may still have people.
        if (mounted) {
          ToastHelper.showError(
            context,
            l10n.redesignGroupEditDeleteFailed(kind),
          );
        }
        return;
      }
      if (!mounted) return;
      if (count > 0) {
        ref.invalidate(rdGroupMemberCountProvider(_groupId));
        ToastHelper.showError(
          context,
          l10n.redesignGroupEditDeleteMembers(kind, count),
        );
        return;
      }
      final confirmed = await DialogHelper.showConfirmation(
        context,
        title: l10n.redesignGroupEditDelete(kind),
        message: l10n.redesignGroupEditDeleteConfirm(
          kind,
          _name.text.trim().isEmpty ? group.name : _name.text.trim(),
        ),
        confirmText: l10n.commonDelete,
        isDestructive: true,
      );
      if (!confirmed || !mounted) return;
      final notifier = ref.read(groupNotifierProvider.notifier);
      // Saves still running finish first; nothing is written to the group
      // while it is deleted (the form is locked); a failed delete writes again.
      await _queue;
      if (!mounted) return;
      _deleted = true;
      await notifier.deleteGroup(_groupId);
      if (!mounted) return;
      if (ref.read(groupNotifierProvider).hasError) {
        _deleted = false;
        ToastHelper.showError(
          context,
          l10n.redesignGroupEditDeleteFailed(kind),
        );
        return;
      }
      ref.invalidate(playerCountsForGroupsProvider);
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(RedesignRoutes.groups);
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final kind = ref.watch(rdGroupKindProvider);
    final async = ref.watch(groupsProvider);
    final group = async.valueOrNull?.where((g) => g.id == _groupId).firstOrNull;

    final Widget body;
    if (group == null) {
      body = RdFormBody(
        children: [
          async.isLoading || _deleted
              ? RdInfoCard(text: l10n.redesignTodayLoading, loading: true)
              : RdInfoCard(
                text:
                    async.hasError
                        ? l10n.redesignTodayLoadFailed
                        : l10n.redesignGroupEditNotFound(kind),
                icon: Icons.error_outline,
                action: RdOutlineButton(
                  label: l10n.redesignCommonRetry,
                  onPressed: () => ref.invalidate(groupsProvider),
                ),
              ),
        ],
      );
    } else {
      _fill(group);
      // Locked while deleting: no change can get lost.
      body = IgnorePointer(ignoring: _deleting, child: _form(context, group));
    }

    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            RdEditTopBar(
              title: l10n.redesignGroupEditTitle(kind),
              doneKey: const Key('rd-group-edit-done'),
              onDone: _done,
            ),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}
