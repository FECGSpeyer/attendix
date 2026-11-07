import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/group_providers.dart';
import '../../../../core/providers/song_providers.dart';
import '../../../../core/router/redesign_routes.dart';
import '../../../../core/theme/redesign/rd_theme.dart';
import '../../../../core/utils/dialog_helper.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/instrument/instrument.dart';
import '../../../../data/models/song/song.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/adaptive/app_dialog.dart';
import '../../data/rd_collections_logic.dart';
import '../widgets/event/rd_form_widgets.dart';
import '../widgets/rd_widgets.dart';
import '../widgets/today/rd_today_common.dart' show RdInfoCard;

/// REDESIGN: "Sammlung bearbeiten" (template of "Gruppe bearbeiten", canvas
/// "Noten-Bereich neu gedacht", board 4): Name, "Nummern mit" (also renames
/// the prefix of the Werke already in it), who sees it (Alle, Nur Leitung,
/// Bestimmte Gruppen), "Im Termin-Programm planbar", "Im öffentlichen
/// Werke-Link"; saved right away (text when the field loses focus or the
/// page closes). "Sammlung löschen" at the bottom: its Werke go back to the
/// Repertoire, or (chosen, asked twice) are deleted with their files.
class RdCollectionEditPage extends ConsumerStatefulWidget {
  const RdCollectionEditPage({super.key, required this.collectionId});

  final int collectionId;

  @override
  ConsumerState<RdCollectionEditPage> createState() => _RdCollectionEditPageState();
}

class _RdCollectionEditPageState extends ConsumerState<RdCollectionEditPage> {
  final _name = TextEditingController();
  final _prefix = TextEditingController();
  final _nameFocus = FocusNode();
  final _prefixFocus = FocusNode();

  late final int _id = widget.collectionId;
  bool _filled = false;
  bool _deleted = false;
  bool _deleting = false;

  /// Werke deleted with the Sammlung so far, of how many.
  (int, int)? _progress;

  /// As last stored (to save text only when it changed).
  String _storedName = '';
  String _storedPrefix = '';

  /// The chosen groups as last tapped (two taps before the reload must not
  /// start from the same stored list).
  List<int> _groupIds = const [];

  /// Writes run one after another, so the last change wins.
  Future<void> _queue = Future.value();

  late final SongCollectionNotifier _notifier;

  /// The Werke as last built (read without `ref` when the page closes).
  List<Song>? _songs;

  @override
  void initState() {
    super.initState();
    _notifier = ref.read(songCollectionNotifierProvider.notifier);
    _nameFocus.addListener(() {
      if (!_nameFocus.hasFocus) _saveName();
    });
    _prefixFocus.addListener(() {
      if (!_prefixFocus.hasFocus) _savePrefix();
    });
  }

  @override
  void dispose() {
    // Text typed last is saved when the page closes.
    _saveName();
    _savePrefix(quiet: true);
    _name.dispose();
    _prefix.dispose();
    _nameFocus.dispose();
    _prefixFocus.dispose();
    super.dispose();
  }

  void _fill(SongCollection c) {
    if (_filled) return;
    _filled = true;
    _name.text = c.name;
    _prefix.text = c.prefix;
    _storedName = c.name;
    _storedPrefix = c.prefix;
    _groupIds = [...c.groupIds];
  }

  void _enqueue(Future<void> Function() task) => _queue = _queue.then((_) => task());

  Future<bool> _store(Map<String, dynamic> updates) async {
    if (_deleted) return false;
    final ok = await _notifier.update(_id, updates);
    if (!ok && mounted) ToastHelper.showError(context, context.l10n.collectionsSaveFailed);
    return ok;
  }

  void _saveName() {
    final value = _name.text.trim();
    _enqueue(() async {
      if (!_filled || value.isEmpty || value == _storedName) return;
      if (await _store({'name': value})) _storedName = value;
    });
  }

  /// The prefix of the Sammlung and of its Werke that still carry the old
  /// one, all or nothing (one database transaction); refused when a number
  /// would then be taken twice (checked here first for the message, and
  /// again by the database).
  void _savePrefix({bool quiet = false}) {
    final value = _prefix.text.trim();
    final songs = _songs;
    _enqueue(() async {
      if (!_filled || _deleted || value == _storedPrefix || songs == null) return;
      final old = _storedPrefix;
      final clash = rdPrefixClash(songs, _id, old, value);
      if (clash != null) {
        if (!quiet && mounted) {
          ToastHelper.showError(context, context.l10n.collectionsPrefixTaken(value, '$value${clash.number}'));
          setState(() => _prefix.text = old);
        }
        return;
      }
      final result = await _notifier.renamePrefix(_id, value);
      if (result.ok) {
        _storedPrefix = value;
      } else if (!quiet && mounted) {
        ToastHelper.showError(
          context,
          result.clash ? context.l10n.collectionsPrefixTakenShort(value) : context.l10n.collectionsSaveFailed,
        );
        setState(() => _prefix.text = old);
      }
    });
  }

  void _write(Map<String, dynamic> updates) => _enqueue(() async {
    await _store(updates);
  });

  void _done() {
    FocusScope.of(context).unfocus();
    context.canPop() ? context.pop() : context.go(RedesignRoutes.collections);
  }

  /// Without Werke one question; with Werke the choice "ins Repertoire" or
  /// "samt Noten löschen", the latter asked once more (it cannot be undone).
  Future<void> _delete(SongCollection c) async {
    if (_deleting) return;
    final l10n = context.l10n;
    final name = _name.text.trim().isEmpty ? c.name : _name.text.trim();
    final count = rdWorksIn(_songs ?? const <Song>[], _id).length;
    var withWorks = false;
    if (count == 0) {
      final confirmed = await DialogHelper.showConfirmation(
        context,
        title: l10n.collectionsDelete,
        message: l10n.collectionsDeleteConfirm(name),
        confirmText: l10n.commonDelete,
        isDestructive: true,
      );
      if (!confirmed || !mounted) return;
    } else {
      final choice = await showAppRadioAlert<bool>(
        context,
        title: l10n.collectionsDelete,
        subtitle: l10n.collectionsDeleteChoose(name),
        options: [
          (false, l10n.collectionsDeleteKeepWorks(count)),
          (true, l10n.collectionsDeleteWithWorks(count)),
        ],
        initialValue: false,
        confirmText: l10n.commonDelete,
      );
      final value = choice?.value;
      if (value == null || !mounted) return;
      withWorks = value;
      if (withWorks) {
        final sure = await DialogHelper.showConfirmation(
          context,
          title: l10n.collectionsDeleteWorksTitle(count),
          message: l10n.collectionsDeleteWorksMessage(name),
          confirmText: l10n.collectionsDeleteWorksConfirm,
          isDestructive: true,
        );
        if (!sure || !mounted) return;
      }
    }
    setState(() => _deleting = true);
    await _queue;
    if (!mounted) return;
    _deleted = true;
    if (withWorks) {
      final result = await _notifier.deleteWithWorks(
        _id,
        onProgress: (done, total) {
          if (mounted) setState(() => _progress = (done, total));
        },
      );
      if (!mounted) return;
      setState(() {
        _deleting = false;
        _progress = null;
      });
      if (!result.ok) {
        _deleted = false;
        ToastHelper.showError(
          context,
          result.failed > 0 ? l10n.collectionsDeleteWorksFailed(result.failed) : l10n.collectionsDeleteFailed,
        );
        return;
      }
      ToastHelper.showSuccess(context, l10n.collectionsDeletedWorks(result.deleted));
    } else {
      final ok = await _notifier.delete(_id);
      if (!mounted) return;
      setState(() => _deleting = false);
      if (!ok) {
        _deleted = false;
        ToastHelper.showError(context, l10n.collectionsDeleteFailed);
        return;
      }
    }
    context.canPop() ? context.pop() : context.go(RedesignRoutes.collections);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final async = ref.watch(songCollectionsProvider);
    final collection = async.valueOrNull?.where((c) => c.id == _id).firstOrNull;

    final Widget body;
    if (collection == null) {
      body = RdFormBody(
        children: [
          async.isLoading || _deleted
              ? RdInfoCard(text: l10n.redesignTodayLoading, loading: true)
              : RdInfoCard(
                text: async.hasError ? l10n.redesignTodayLoadFailed : l10n.collectionsNotFound,
                icon: Icons.error_outline,
                action: RdOutlineButton(
                  label: l10n.redesignCommonRetry,
                  onPressed: () => ref.invalidate(songCollectionsProvider),
                ),
              ),
        ],
      );
    } else {
      _fill(collection);
      body = IgnorePointer(ignoring: _deleting, child: _form(context, collection));
    }

    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            RdEditTopBar(title: l10n.collectionsEditTitle, doneKey: const Key('rd-collection-edit-done'), onDone: _done),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }

  Widget _form(BuildContext context, SongCollection c) {
    final p = context.rd;
    final l10n = context.l10n;
    final groups = [...?ref.watch(groupsProvider).valueOrNull?.where((g) => g.maingroup != true && g.id != null)];
    _songs = ref.watch(songsProvider).valueOrNull ?? _songs;
    final count = rdWorksIn(_songs ?? const <Song>[], _id).length;
    final textStyle = TextStyle(fontSize: 17, color: p.text);
    final visibility = c.visibleTo;

    Widget hint(String text, {Color? color}) => Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
      child: Text(text, style: RdType.meta(p, size: 13).copyWith(color: color)),
    );

    Widget visRow(SongCollectionVisibility v, String label) => RdListRow(
      key: Key('rd-collection-vis-${v.value}'),
      title: label,
      showChevron: false,
      selected: visibility == v,
      trailing: RdSheetCheck(visibility == v),
      onTap: visibility == v ? null : () => _write({'visibility': v.value}),
    );

    void toggleGroup(Group g) {
      final ids = {..._groupIds};
      ids.contains(g.id) ? ids.remove(g.id) : ids.add(g.id!);
      // Ids of groups no longer listed stay out, like before.
      final next = [
        for (final x in groups)
          if (ids.contains(x.id)) x.id!,
      ];
      setState(() => _groupIds = next);
      _write({'group_ids': next});
    }

    final prefix = _prefix.text.trim();
    return RdFormBody(
      children: [
        RdGroupedList(
          children: [
            RdFieldRow(
              label: l10n.collectionsName,
              child: TextField(
                key: const Key('rd-collection-edit-name'),
                controller: _name,
                focusNode: _nameFocus,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.done,
                style: textStyle,
                decoration: rdInputDecoration(p, ''),
                onChanged: (_) => setState(() {}),
              ),
            ),
            RdFieldRow(
              label: l10n.collectionsPrefix,
              child: TextField(
                key: const Key('rd-collection-edit-prefix'),
                controller: _prefix,
                focusNode: _prefixFocus,
                textCapitalization: TextCapitalization.characters,
                textInputAction: TextInputAction.done,
                style: textStyle,
                decoration: rdInputDecoration(p, l10n.redesignWorkEditPrefixHint),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ],
        ),
        if (_name.text.trim().isEmpty) hint(l10n.collectionsNameEmpty, color: p.absent),
        hint(prefix.isEmpty ? l10n.collectionsPrefixNone : '${prefix}1, ${prefix}2 … · ${l10n.collectionsPrefixHint}'),
        const SizedBox(height: 20),
        RdGroupLabel(l10n.collectionsWhoSees),
        RdGroupedList(
          children: [
            visRow(SongCollectionVisibility.all, l10n.collectionsVisAll),
            visRow(SongCollectionVisibility.leads, l10n.collectionsVisLeads),
            visRow(SongCollectionVisibility.groups, l10n.collectionsVisGroups),
          ],
        ),
        if (visibility == SongCollectionVisibility.groups) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final g in groups)
                RdChoiceChip(
                  key: Key('rd-collection-group-${g.id}'),
                  label: g.name,
                  selected: _groupIds.contains(g.id),
                  onTap: () => toggleGroup(g),
                ),
            ],
          ),
          if (_groupIds.isEmpty) hint(l10n.collectionsGroupsNone, color: p.late),
        ],
        hint(l10n.collectionsLeadsSeeAll),
        const SizedBox(height: 20),
        RdGroupedList(
          children: [
            RdSwitchRow(
              key: const Key('rd-collection-plannable'),
              title: l10n.collectionsPlannable,
              subtitle: l10n.collectionsPlannableHint,
              value: c.plannable,
              onChanged: (v) => _write({'plannable': v}),
            ),
            RdSwitchRow(
              key: const Key('rd-collection-public'),
              title: l10n.collectionsPublicLink,
              subtitle: l10n.collectionsPublicLinkHint,
              value: c.publicLink && visibility == SongCollectionVisibility.all,
              onChanged: visibility == SongCollectionVisibility.all ? (v) => _write({'public_link': v}) : null,
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 16, 4, 20),
          child: Text(l10n.collectionsEditHint, style: RdType.meta(p, size: 13)),
        ),
        RdPrimaryButton(label: l10n.redesignCommonDone, onPressed: _done),
        const SizedBox(height: 28),
        RdGroupedList(
          children: [
            RdListRow(
              key: const Key('rd-collection-delete'),
              title: l10n.collectionsDelete,
              subtitle: _progress != null
                  ? l10n.collectionsDeletingWorks(_progress!.$1, _progress!.$2)
                  : count == 0
                  ? null
                  : l10n.collectionsWorks(count),
              titleColor: p.absent,
              leading: Icon(Icons.delete_outline, color: p.absent),
              showChevron: false,
              onTap: _deleting ? null : () => _delete(c),
            ),
          ],
        ),
      ],
    );
  }
}
