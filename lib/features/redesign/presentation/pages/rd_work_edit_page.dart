import 'package:flutter/foundation.dart' show mapEquals;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/song_providers.dart';
import '../../../../core/router/redesign_routes.dart';
import '../../../../core/services/offline_queue_service.dart';
import '../../../../core/theme/redesign/rd_theme.dart';
import '../../../../core/utils/dialog_helper.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/song/song.dart';
import '../../../../data/models/song/song_additional_field.dart';
import '../../../../data/repositories/song_repository.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';
import '../../../songs/presentation/widgets/song_categories_sheet.dart';
import '../../data/providers/rd_shared_library.dart';
import '../../data/rd_works_logic.dart';
import '../widgets/event/rd_form_widgets.dart';
import '../widgets/rd_widgets.dart';
import '../widgets/today/rd_today_common.dart' show RdInfoCard;
import '../widgets/works/rd_collections_ui.dart';

/// REDESIGN: "Werk bearbeiten" (canvas "Werke neu gedacht", board
/// "Bearbeiten"): only the master data of a Werk, saved right away like
/// "Termin bearbeiten" (text fields when they lose focus or the page
/// closes). No Besetzung: the groups follow from the uploaded Noten, which
/// are managed on the Werk page. "Werk löschen" sits at the bottom.
class RdWorkEditPage extends ConsumerStatefulWidget {
  const RdWorkEditPage({super.key, required this.songId});

  final int songId;

  @override
  ConsumerState<RdWorkEditPage> createState() => _RdWorkEditPageState();
}

class _RdWorkEditPageState extends ConsumerState<RdWorkEditPage> {
  final _name = TextEditingController();
  final _prefix = TextEditingController();
  final _number = TextEditingController();
  final _link = TextEditingController();
  final _nameFocus = FocusNode();
  final _prefixFocus = FocusNode();
  final _numberFocus = FocusNode();
  final _linkFocus = FocusNode();
  final Map<String, TextEditingController> _fieldControllers = {};
  final Map<String, FocusNode> _fieldFocus = {};

  /// Stored values the text fields started from (null until loaded).
  String? _storedName;
  String? _storedPrefix;
  int? _storedNumber;
  String? _storedLink;

  bool _withChoir = false;
  bool _withSolo = false;
  int? _difficulty;
  List<String> _categoryIds = [];

  /// Zusatzfelder as typed or picked, and as last written.
  Map<String, dynamic> _additional = {};
  Map<String, dynamic> _storedAdditional = {};
  List<SongAdditionalField> _fields = const [];

  /// The Werk this form writes to, bound once (the router builds a new
  /// form per Werk; this keeps queued writes on the Werk they came from).
  late final int _songId = widget.songId;

  /// Set once the Werk is deleted: nothing is written any more.
  bool _deleted = false;

  /// Writes run one after another, so the last change always wins.
  Future<void> _queue = Future.value();

  /// Bound once the Werk is loaded (the song source of a synced library is
  /// known then), so text saved when the page closes still goes to it.
  SongRepository? _repo;
  late final ProviderContainer _container;

  /// The acting user's session; text saved when the page closes after a
  /// sign-out or account switch is dropped, not written.
  late final OfflineWriteSession _session;

  SongDetailParams get _params => (songId: _songId, sharingId: null);

  @override
  void initState() {
    super.initState();
    _container = ProviderScope.containerOf(context, listen: false);
    _session = ref.read(offlineQueueNotifierProvider.notifier).captureWriteSession();
    for (final (focus, save) in [
      (_nameFocus, _saveName),
      (_prefixFocus, _saveNumber),
      (_numberFocus, _saveNumber),
      (_linkFocus, _saveLink),
    ]) {
      focus.addListener(() {
        if (!focus.hasFocus) save();
      });
    }
  }

  @override
  void dispose() {
    // Text typed last is saved when the page closes (no focus change).
    _saveName();
    _saveNumber();
    _saveLink();
    _saveFieldTexts();
    for (final c in [_name, _prefix, _number, _link, ..._fieldControllers.values]) {
      c.dispose();
    }
    for (final f in [_nameFocus, _prefixFocus, _numberFocus, _linkFocus, ..._fieldFocus.values]) {
      f.dispose();
    }
    super.dispose();
  }

  void _fill(SongDetailData data) {
    if (_storedName != null) return;
    final song = data.song;
    _repo = ref.read(songRepositoryWithTenantProvider);
    _storedName = song.name;
    _storedPrefix = song.prefix ?? '';
    _storedNumber = song.number;
    _storedLink = song.link ?? '';
    _name.text = _storedName!;
    _prefix.text = _storedPrefix!;
    _number.text = song.number?.toString() ?? '';
    _link.text = _storedLink!;
    _withChoir = song.withChoir;
    _withSolo = song.withSolo;
    _difficulty = song.difficulty;
    _categoryIds = [...?song.categoryIds];
    _storedControls = (_difficulty, _withChoir, _withSolo, _categoryIds);
    // Like the old page: empty fields start with their default.
    _additional = {...?song.additionalFields};
    _fields = data.additionalFields;
    for (final field in _fields) {
      _additional[field.id] ??= field.effectiveDefault;
      if (!field.isBoolean && !field.isSelect) {
        _fieldControllers[field.id] = TextEditingController(text: _additional[field.id]?.toString() ?? '');
        final focus = FocusNode();
        focus.addListener(() {
          if (!focus.hasFocus) _saveFieldTexts();
        });
        _fieldFocus[field.id] = focus;
      }
    }
    _storedAdditional = {..._additional};
  }

  void _refresh() {
    _container
      ..invalidate(songDetailDataProvider(_params))
      ..invalidate(songByIdProvider(_songId))
      ..invalidate(songsProvider);
  }

  void _enqueue(Future<void> Function() task) {
    _queue = _queue.then((_) => task());
  }

  /// Writes [updates]; reports a failure while the page is open.
  Future<bool> _store(Map<String, dynamic> updates) async {
    final repo = _repo;
    if (_deleted || repo == null || !repo.hasTenantId || !_session.isCurrent()) return false;
    try {
      await repo.updateSong(_songId, updates);
      _refresh();
      return true;
    } catch (_) {
      if (mounted) ToastHelper.showError(context, context.l10n.extraFieldsSaveFailed);
      return false;
    }
  }

  // Text saves compare with what is stored when they run, so the last typed
  // value always wins; a value is marked as stored only once written, so a
  // failed save is tried again.

  void _saveName() {
    final value = _name.text.trim(); // read now: the page may be gone when it runs
    _enqueue(() async {
      if (_storedName == null || value == _storedName || value.isEmpty) return;
      if (await _store({'name': value})) _storedName = value;
    });
  }

  void _saveNumber() {
    final prefix = _prefix.text.trim();
    final number = int.tryParse(_number.text.trim());
    _enqueue(() async {
      if (_storedPrefix == null || (prefix == _storedPrefix && number == _storedNumber)) return;
      // Only checked against the loaded Werke (the fields stay locked until
      // then); a number another Werk has is not saved (the form says so).
      final songs = _container.read(songsProvider).valueOrNull;
      if (songs == null || rdNumberTakenBy(songs, _songId, prefix, number) != null) return;
      if (await _store({'prefix': prefix, 'number': number})) {
        _storedPrefix = prefix;
        _storedNumber = number;
      }
    });
  }

  /// "Sammlung": moves the Werk (typed numbers saved first) and takes the
  /// prefix and number it got there.
  Future<void> _moveToCollection(Song song) async {
    _saveNumber();
    await _queue;
    if (!mounted) return;
    final moved = await rdMoveWorkToCollection(context, ref, song);
    if (!moved || !mounted) return;
    final songs = await ref.read(songsProvider.future).catchError((_) => const <Song>[]);
    final fresh = songs.where((s) => s.id == _songId).firstOrNull;
    if (fresh == null || !mounted) return;
    setState(() {
      _storedPrefix = fresh.prefix ?? '';
      _storedNumber = fresh.number;
      _prefix.text = _storedPrefix!;
      _number.text = fresh.number?.toString() ?? '';
    });
  }

  void _saveLink() {
    final value = _link.text.trim();
    _enqueue(() async {
      if (_storedLink == null || value == _storedLink) return;
      if (await _store({'link': value.isEmpty ? null : value})) _storedLink = value;
    });
  }

  /// Text and number Zusatzfelder; also retries a failed write of switch
  /// and choice fields (on close, too).
  void _saveFieldTexts() {
    if (_storedName == null) return;
    for (final field in _fields) {
      final c = _fieldControllers[field.id];
      if (c == null) continue;
      _additional[field.id] = field.isNumber ? num.tryParse(c.text.trim()) ?? 0 : c.text;
    }
    _writeFields();
  }

  /// Writes the whole Zusatzfelder map (like Ionic) when it differs from
  /// the last written one; marked as written only once it is, so a failed
  /// save is tried again on the next change, focus change or close.
  void _writeFields() {
    final next = {..._additional};
    _enqueue(() async {
      if (mapEquals(next, _storedAdditional)) return;
      if (await _store({'additional_fields': next})) _storedAdditional = next;
    });
  }

  Song? _numberTakenBy(String prefix, int? number) =>
      rdNumberTakenBy(_container.read(songsProvider).valueOrNull ?? const [], _songId, prefix, number);

  /// What is stored for the switches and chips (difficulty, choir, solo,
  /// categories), and how often each was changed here.
  (int?, bool, bool, List<String>) _storedControls = (null, false, false, const []);
  final _controlChanges = [0, 0, 0, 0];

  /// Applies a switch/chip change at once and writes it; a failed save puts
  /// the control back to what is stored, so it never shows another value.
  void _set(void Function() change, Map<String, dynamic> Function() updates) {
    final before = (_difficulty, _withChoir, _withSolo, _categoryIds);
    setState(change);
    final after = (_difficulty, _withChoir, _withSolo, _categoryIds);
    final touched = [
      before.$1 != after.$1,
      before.$2 != after.$2,
      before.$3 != after.$3,
      !identical(before.$4, after.$4),
    ];
    for (var i = 0; i < 4; i++) {
      if (touched[i]) _controlChanges[i]++;
    }
    final changes = [..._controlChanges];
    final values = updates();
    _enqueue(() async {
      if (await _store(values)) {
        _storedControls = (
          touched[0] ? after.$1 : _storedControls.$1,
          touched[1] ? after.$2 : _storedControls.$2,
          touched[2] ? after.$3 : _storedControls.$3,
          touched[3] ? after.$4 : _storedControls.$4,
        );
        return;
      }
      if (!mounted) return;
      // Back to the stored value, but only for the controls this change
      // touched and that were not changed again (that write comes next).
      bool last(int i) => touched[i] && _controlChanges[i] == changes[i];
      setState(() {
        if (last(0)) _difficulty = _storedControls.$1;
        if (last(1)) _withChoir = _storedControls.$2;
        if (last(2)) _withSolo = _storedControls.$3;
        if (last(3)) _categoryIds = _storedControls.$4;
      });
    });
  }

  void _done() {
    FocusScope.of(context).unfocus();
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(RedesignRoutes.work(_songId));
    }
  }

  Future<void> _pickOption(SongAdditionalField field) async {
    final choice = await showAppActionSheet<String>(
      context,
      title: field.name,
      actions: [for (final o in field.options) AppActionSheetAction(value: o, label: o)],
    );
    if (choice == null || !mounted) return;
    setState(() => _additional[field.id] = choice);
    _writeFields();
  }

  /// The stored name (not what is typed just now) for the delete question.
  String get _deleteName => (_storedName ?? _name.text).trim();

  Future<void> _delete() async {
    final l10n = context.l10n;
    List<String> names;
    try {
      names = await ref.read(songSyncedTenantNamesProvider.future);
    } catch (_) {
      names = const [];
    }
    if (!mounted) return;
    final confirmed = await DialogHelper.showConfirmation(
      context,
      title: l10n.rdTextWorkDeleteTitle(_deleteName),
      message: names.isNotEmpty ? l10n.rdTextWorkDeleteSyncedMessage(names.join(', ')) : l10n.rdTextWorkDeleteMessage,
      confirmText: l10n.commonDelete,
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;
    final ok = await ref.read(songNotifierProvider.notifier).deleteSong(_songId);
    if (!mounted) return;
    if (ok) {
      _deleted = true; // nothing left to save
      context.go(RedesignRoutes.works);
    } else {
      ToastHelper.showError(context, l10n.songsFlutterDeleteFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final async = ref.watch(songDetailDataProvider(_params));
    final data = async.valueOrNull;
    // Loads the Werke for the number check (opened from a link).
    ref.watch(songsProvider);

    final Widget body;
    if (data == null) {
      body = RdFormBody(
        children: [
          async.isLoading
              ? RdInfoCard(text: l10n.redesignTodayLoading, loading: true)
              : RdInfoCard(
                text: async.hasError ? l10n.redesignTodayLoadFailed : l10n.redesignWorkNotFound,
                icon: Icons.error_outline,
                // Retry only helps after an error, not when it is gone.
                action: async.hasError
                    ? RdOutlineButton(
                      label: l10n.redesignCommonRetry,
                      onPressed: () => ref.invalidate(songDetailDataProvider(_params)),
                    )
                    : null,
              ),
        ],
      );
    } else if (data.readOnly || data.isPublic || !ref.watch(rdLibraryEditableProvider)) {
      body = RdFormBody(children: [RdInfoCard(text: l10n.redesignWorkEditNotAllowed, icon: Icons.lock_outline)]);
    } else {
      _fill(data);
      body = _form(context, data);
    }

    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            RdEditTopBar(title: l10n.redesignWorkEditTitle, doneKey: const Key('rd-work-edit-done'), onDone: _done),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }

  Widget _form(BuildContext context, SongDetailData data) {
    final p = context.rd;
    final l10n = context.l10n;
    final prefix = _prefix.text.trim();
    final number = int.tryParse(_number.text.trim());
    final taken = _numberTakenBy(prefix, number);
    // The number check needs every Werk: locked until they are loaded.
    final songsAsync = ref.watch(songsProvider);
    final numberLocked = !songsAsync.hasValue;
    final nameEmpty = _name.text.trim().isEmpty;
    final textStyle = TextStyle(fontSize: 17, color: p.text);

    Widget hint(String text, {Color? color}) => Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
      child: Text(text, style: RdType.meta(p, size: 13).copyWith(color: color)),
    );

    return RdFormBody(
      children: [
        RdGroupedList(
          children: [
            RdFieldRow(
              label: l10n.redesignWorkEditName,
              child: TextField(
                key: const Key('rd-work-edit-name'),
                controller: _name,
                focusNode: _nameFocus,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
                style: textStyle,
                decoration: rdInputDecoration(p, ''),
                onChanged: (_) => setState(() {}),
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 112,
                  child: RdFieldRow(
                    label: l10n.redesignWorkEditPrefix,
                    child: TextField(
                      key: const Key('rd-work-edit-prefix'),
                      controller: _prefix,
                      focusNode: _prefixFocus,
                      readOnly: numberLocked,
                      textCapitalization: TextCapitalization.characters,
                      textInputAction: TextInputAction.next,
                      style: textStyle,
                      decoration: rdInputDecoration(p, l10n.redesignWorkEditPrefixHint),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ),
                Expanded(
                  child: RdFieldRow(
                    label: l10n.redesignWorkEditNumber,
                    child: TextField(
                      key: const Key('rd-work-edit-number'),
                      controller: _number,
                      focusNode: _numberFocus,
                      readOnly: numberLocked,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      textInputAction: TextInputAction.done,
                      style: textStyle,
                      decoration: rdInputDecoration(p, ''),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        if (nameEmpty) hint(l10n.redesignWorkEditNameEmpty, color: p.absent),
        if (taken != null) hint(l10n.redesignWorkEditNumberTaken(taken.fullNumber, taken.name), color: p.absent),
        if (songsAsync.hasError && !songsAsync.hasValue)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
            child: Row(
              children: [
                Expanded(child: Text(l10n.redesignWorkEditNumberLocked, style: RdType.meta(p, size: 13))),
                RdTextLink(label: l10n.redesignCommonRetry, onTap: () => ref.invalidate(songsProvider)),
              ],
            ),
          ),
        if (ref.watch(songCollectionsProvider).valueOrNull case final collections?
            when collections.isNotEmpty) ...[
          const SizedBox(height: 20),
          RdGroupedList(
            children: [
              RdListRow(
                key: const Key('rd-work-edit-collection'),
                title: l10n.collectionsRow,
                value: rdCollectionName(l10n, collections, data.song.collectionId),
                onTap: () => _moveToCollection(data.song),
              ),
            ],
          ),
        ],
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(child: RdGroupLabel(l10n.redesignWorkEditCategories)),
            RdTextLink(label: l10n.redesignWorkEditManageCategories, onTap: () => showSongCategoriesSheet(context)),
          ],
        ),
        if (data.categories.isEmpty)
          hint(l10n.redesignWorkEditNoCategories)
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in data.categories)
                if (c.id != null)
                  RdChoiceChip(
                    label: c.name,
                    selected: _categoryIds.contains(c.id),
                    onTap:
                        () => _set(
                          () =>
                              _categoryIds =
                                  _categoryIds.contains(c.id)
                                      ? [
                                        for (final id in _categoryIds)
                                          if (id != c.id) id,
                                      ]
                                      : [..._categoryIds, c.id!],
                          () => {
                            'category_ids': [..._categoryIds],
                          },
                        ),
                  ),
            ],
          ),
        const SizedBox(height: 20),
        RdGroupLabel(l10n.redesignWorkEditDifficulty),
        RdSegmented<int>(
          values: const [0, 1, 2, 3],
          selected: (_difficulty ?? 0).clamp(0, 3),
          semanticLabel: l10n.redesignWorkEditDifficulty,
          labelOf:
              (v) => switch (v) {
                1 => l10n.redesignWorkEditEasy,
                2 => l10n.redesignWorkEditMedium,
                3 => l10n.redesignWorkEditHard,
                _ => l10n.redesignWorkEditDifficultyNone,
              },
          onChanged: (v) => _set(() => _difficulty = v == 0 ? null : v, () => {'difficulty': _difficulty}),
        ),
        const SizedBox(height: 20),
        RdGroupLabel(l10n.redesignWorkEditInstrumentation),
        RdGroupedList(
          children: [
            _switchRow(
              data.isOrchestra ? l10n.redesignWorkWithChoir : l10n.redesignWorkWithOrchestra,
              _withChoir,
              (v) => _set(() => _withChoir = v, () => {'withChoir': v}),
            ),
            _switchRow(l10n.redesignWorkWithSolo, _withSolo, (v) => _set(() => _withSolo = v, () => {'withSolo': v})),
          ],
        ),
        if (data.isOrchestra) hint(l10n.redesignWorkEditInstrumentationHint),
        const SizedBox(height: 20),
        RdGroupLabel(l10n.redesignWorkEditLink),
        RdGroupedList(
          children: [
            RdFieldRow(
              label: l10n.redesignWorkEditLinkHint,
              child: TextField(
                key: const Key('rd-work-edit-link'),
                controller: _link,
                focusNode: _linkFocus,
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.done,
                style: textStyle,
                decoration: rdInputDecoration(p, 'https://'),
              ),
            ),
          ],
        ),
        if (data.additionalFields.isNotEmpty) ...[
          const SizedBox(height: 20),
          RdGroupLabel(l10n.redesignWorkEditFields),
          RdGroupedList(children: [for (final field in data.additionalFields) _fieldRow(field, textStyle)]),
        ],
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 16, 4, 20),
          child: Text(l10n.redesignWorkEditHint, style: RdType.meta(p, size: 13)),
        ),
        const SizedBox(height: 8),
        RdGroupedList(
          children: [
            RdListRow(
              key: const Key('rd-work-edit-delete'),
              title: l10n.redesignWorkEditDelete,
              titleColor: p.absent,
              leading: Icon(Icons.delete_outline, color: p.absent),
              showChevron: false,
              onTap: _delete,
            ),
          ],
        ),
      ],
    );
  }

  Widget _switchRow(String title, bool value, ValueChanged<bool> onChanged) => RdListRow(
    title: title,
    showChevron: false,
    trailing: Switch.adaptive(value: value, activeTrackColor: context.rd.primary, onChanged: onChanged),
    onTap: () => onChanged(!value),
  );

  Widget _fieldRow(SongAdditionalField field, TextStyle textStyle) {
    final p = context.rd;
    final value = _additional[field.id];
    if (field.isBoolean) {
      return _switchRow(field.name, value == true, (v) {
        setState(() => _additional[field.id] = v);
        _writeFields();
      });
    }
    if (field.isSelect) {
      return RdListRow(
        title: field.name,
        value: field.options.contains(value) ? value as String : '–',
        onTap: field.options.isEmpty ? null : () => _pickOption(field),
      );
    }
    return RdFieldRow(
      label: field.name,
      child: TextField(
        key: Key('rd-work-edit-field-${field.id}'),
        controller: _fieldControllers[field.id],
        focusNode: _fieldFocus[field.id],
        keyboardType: field.isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
        minLines: 1,
        maxLines: field.type == 'textarea' ? 6 : 1,
        textCapitalization: TextCapitalization.sentences,
        style: textStyle,
        decoration: rdInputDecoration(p, ''),
      ),
    );
  }
}
