import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/group_providers.dart';
import '../../../../core/providers/song_filter_providers.dart';
import '../../../../core/providers/song_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/router/redesign_routes.dart';
import '../../../../core/theme/redesign/rd_theme.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/song/song.dart';
import '../../../../l10n/l10n.dart';
import '../../data/rd_collections_logic.dart';
import '../../data/rd_works_logic.dart';
import '../widgets/event/rd_form_widgets.dart';
import '../widgets/rd_widgets.dart';
import '../widgets/works/rd_collections_ui.dart';

/// REDESIGN: "Neues Werk" (canvas "Werke neu gedacht", board "Neues
/// Werk"): title, prefix and the next free number, the category the list
/// is filtered to, Chor/Solo. No Besetzung: the groups follow from the
/// Noten uploaded right after, on the Werk page this opens. With
/// Sammlungen (canvas "Noten-Bereich neu gedacht") the Werk goes into the
/// Sammlung the list shows ([collectionId]) and takes its prefix.
class RdWorkCreatePage extends ConsumerStatefulWidget {
  const RdWorkCreatePage({super.key, this.collectionId});

  /// The Sammlung the Werke list showed (null = Repertoire).
  final int? collectionId;

  @override
  ConsumerState<RdWorkCreatePage> createState() => _RdWorkCreatePageState();
}

class _RdWorkCreatePageState extends ConsumerState<RdWorkCreatePage> {
  final _name = TextEditingController();
  final _prefix = TextEditingController();
  final _number = TextEditingController();

  /// The number was typed (not the suggested next free one).
  bool _numberTouched = false;

  /// The prefix was typed (not the one of the Sammlung).
  bool _prefixTouched = false;

  /// The Sammlung of the new Werk (null = Repertoire).
  late int? _collection = widget.collectionId;
  bool _withChoir = false;
  bool _withSolo = false;
  bool _saving = false;

  /// Categories once a chip was tapped; until then the one the list is
  /// filtered to (it may load after the page opens).
  List<String>? _pickedCategories;

  @override
  void dispose() {
    _name.dispose();
    _prefix.dispose();
    _number.dispose();
    super.dispose();
  }

  void _cancel() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(RedesignRoutes.works);
    }
  }

  Future<void> _create(List<Song> songs, List<String> categoryIds) async {
    final number = int.tryParse(_number.text.trim());
    final name = _name.text.trim();
    final prefix = _prefix.text.trim();
    if (name.isEmpty || number == null || rdNumberTakenBy(songs, null, prefix, number) != null) return;
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    final created = await ref
        .read(songNotifierProvider.notifier)
        .createSong(
          Song(
            name: name,
            prefix: prefix,
            number: number,
            withChoir: _withChoir,
            withSolo: _withSolo,
            categoryIds: categoryIds,
            collectionId: _collection,
            // The Besetzung follows from the uploaded Noten.
            instrumentIds: const [],
          ),
        );
    if (!mounted) return;
    setState(() => _saving = false);
    if (created?.id == null) {
      ToastHelper.showError(context, context.l10n.songsFlutterCreateFailed);
      return;
    }
    // Next step on the Werk page: "Noten hinzufügen".
    context.go(RedesignRoutes.work(created!.id!));
  }

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    // Number suggestion and check need every Werk: no Werk is created
    // before they are loaded.
    final songsAsync = ref.watch(songsProvider);
    final songs = songsAsync.valueOrNull;
    final categories = [...?ref.watch(songCategoriesProvider).valueOrNull?.where((c) => c.id != null)]
      ..sort((a, b) => a.index.compareTo(b.index));
    final tenantId = ref.watch(currentTenantIdProvider);
    final filtered = tenantId == null ? null : ref.watch(songFilterProvider(tenantId)).category;
    final preselected = categories.where((c) => c.id == filtered).firstOrNull;
    final categoryIds = _pickedCategories ?? [if (preselected != null) preselected.id!];
    final collections = ref.watch(songCollectionsProvider).valueOrNull;
    final collection = rdCollectionById(collections ?? const [], _collection);
    // Until a prefix is typed, the field shows the one of the Sammlung.
    final collectionPrefix = collection?.prefix ?? '';
    if (!_prefixTouched && _prefix.text != collectionPrefix) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_prefixTouched) setState(() => _prefix.text = collectionPrefix);
      });
    }
    final prefix = _prefix.text.trim();
    final next = songs == null ? null : rdNextFreeNumber(songs, prefix);
    // Until a number is typed, the field shows the next free one.
    if (next != null && !_numberTouched && _number.text != '$next') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_numberTouched) _number.text = '$next';
      });
    }
    final number = _numberTouched ? int.tryParse(_number.text.trim()) : next;
    final taken = songs == null ? null : rdNumberTakenBy(songs, null, prefix, number);
    final canCreate = songs != null && !_saving && _name.text.trim().isNotEmpty && number != null && taken == null;
    final textStyle = TextStyle(fontSize: 17, color: p.text);

    Widget hint(String text, {Color? color}) => Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
      child: Text(text, style: RdType.meta(p, size: 13).copyWith(color: color)),
    );

    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            RdFormTopBar(
              title: l10n.redesignWorkCreateTitle,
              cancel: l10n.commonCancel,
              submit: l10n.redesignWorkCreateCreate,
              saving: _saving,
              onCancel: _cancel,
              onSubmit: canCreate ? () => _create(songs, categoryIds) : null,
              submitKey: const Key('rd-work-create-submit'),
            ),
            Expanded(
              child: RdFormBody(
                children: [
                  RdGroupedList(
                    children: [
                      RdFieldRow(
                        label: l10n.redesignWorkEditName,
                        child: TextField(
                          key: const Key('rd-work-create-name'),
                          controller: _name,
                          autofocus: true,
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
                                key: const Key('rd-work-create-prefix'),
                                controller: _prefix,
                                readOnly: songs == null,
                                textCapitalization: TextCapitalization.characters,
                                textInputAction: TextInputAction.next,
                                style: textStyle,
                                decoration: rdInputDecoration(p, l10n.redesignWorkEditPrefixHint),
                                onChanged: (_) => setState(() => _prefixTouched = true),
                              ),
                            ),
                          ),
                          Expanded(
                            child: RdFieldRow(
                              label: l10n.redesignWorkEditNumber,
                              child: TextField(
                                key: const Key('rd-work-create-number'),
                                controller: _number,
                                readOnly: songs == null,
                                keyboardType: TextInputType.number,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                textInputAction: TextInputAction.done,
                                style: textStyle,
                                decoration: rdInputDecoration(p, ''),
                                onChanged: (_) => setState(() => _numberTouched = true),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (taken != null)
                    hint(l10n.rdTextNumberTaken(taken.fullNumber, taken.name), color: p.absent)
                  else if (next != null)
                    hint('${l10n.redesignWorkCreateNextNumber('$prefix$next')} ${l10n.redesignWorkCreatePrefixHint}')
                  else if (songsAsync.hasError)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
                      child: Row(
                        children: [
                          Expanded(child: Text(l10n.redesignWorkEditNumberLocked, style: RdType.meta(p, size: 13))),
                          RdTextLink(label: l10n.redesignCommonRetry, onTap: () => ref.invalidate(songsProvider)),
                        ],
                      ),
                    ),
                  if (collections != null && collections.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    RdGroupLabel(l10n.collectionsRow),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final c in [null, ...collections.where((c) => c.id != null)])
                          RdChoiceChip(
                            key: Key('rd-work-create-collection-${c?.id ?? 'repertoire'}'),
                            label: c?.name ?? l10n.collectionsRepertoire,
                            icon: rdCollectionIcon(c),
                            selected: c?.id == _collection,
                            onTap: () => setState(() => _collection = c?.id),
                          ),
                      ],
                    ),
                    if (rdCollectionBanner(l10n, collection, ref.watch(groupsProvider).valueOrNull ?? const [])
                        case final audience?)
                      hint(audience),
                  ],
                  if (categories.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    RdGroupLabel(l10n.redesignWorkCreateCategory),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final c in categories)
                          RdChoiceChip(
                            label: c.name,
                            selected: categoryIds.contains(c.id),
                            onTap:
                                () => setState(
                                  () =>
                                      _pickedCategories =
                                          categoryIds.contains(c.id)
                                              ? [
                                                for (final id in categoryIds)
                                                  if (id != c.id) id,
                                              ]
                                              : [...categoryIds, c.id!],
                                ),
                          ),
                      ],
                    ),
                    if (preselected != null) hint(l10n.redesignWorkCreateCategoryHint(preselected.name)),
                  ],
                  const SizedBox(height: 20),
                  RdGroupLabel(l10n.redesignWorkEditInstrumentation),
                  RdGroupedList(
                    children: [
                      for (final (label, value, set) in <(String, bool, void Function(bool))>[
                        (
                          ref.watch(currentTenantProvider)?.type == 'orchestra'
                              ? l10n.redesignWorkWithChoir
                              : l10n.redesignWorkWithOrchestra,
                          _withChoir,
                          (v) => _withChoir = v,
                        ),
                        (l10n.redesignWorkWithSolo, _withSolo, (v) => _withSolo = v),
                      ])
                        RdListRow(
                          title: label,
                          showChevron: false,
                          trailing: Switch.adaptive(
                            value: value,
                            activeTrackColor: p.primary,
                            onChanged: (v) => setState(() => set(v)),
                          ),
                          onTap: () => setState(() => set(!value)),
                        ),
                    ],
                  ),
                  hint(l10n.redesignWorkCreateInstrumentationHint),
                  hint(l10n.redesignWorkCreateLater),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
