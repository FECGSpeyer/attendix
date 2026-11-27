import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/redesign/rd_theme.dart';
import '../../../../data/models/instrument/instrument.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/adaptive/app_dialog.dart';
import '../../../redesign/presentation/widgets/event/rd_form_widgets.dart'
    show RdFieldRow, RdFormBody, rdInputDecoration;
import '../../../redesign/presentation/widgets/manage/rd_settings_sheets.dart'
    show RdSheetHead, showRdSettingsSheet, showRdTextSheet;
import '../../../redesign/presentation/widgets/rd_widgets.dart';
import '../../data/catalog_selection.dart';
import '../../data/instrument_catalog.dart';
import '../../data/instrument_presets.dart';

enum CatalogPickerPurpose { setup, add }

class CatalogPickerResult {
  const CatalogPickerResult({required this.drafts, this.presetId});

  final List<CatalogGroupDraft> drafts;
  final String? presetId;
}

enum CatalogPresetChange { merge, replace }

/// The same explicit choice protects both setup and the collection picker.
Future<CatalogPresetChange?> showCatalogPresetChangeDialog(
  BuildContext context,
) {
  final l10n = context.l10n;
  return showAppDialog<CatalogPresetChange>(
    context: context,
    builder:
        (dialogContext) => AppAlertDialog(
          title: Text(l10n.catalogPresetChangeTitle),
          content: Text(l10n.catalogPresetChangeMessage),
          scrollable: true,
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.redesignCommonCancel),
            ),
            TextButton(
              onPressed:
                  () => Navigator.of(
                    dialogContext,
                  ).pop(CatalogPresetChange.replace),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(dialogContext).colorScheme.error,
              ),
              child: Text(l10n.catalogPresetReplace),
            ),
            TextButton(
              onPressed:
                  () => Navigator.of(
                    dialogContext,
                  ).pop(CatalogPresetChange.merge),
              child: Text(l10n.catalogPresetMerge),
            ),
          ],
        ),
  );
}

/// Local collection picker. Nothing is written until the caller imports
/// the returned drafts. Null means cancel; empty drafts are intentional.
Future<CatalogPickerResult?> showInstrumentCatalogSheet(
  BuildContext context, {
  required String tenantType,
  List<Group> existingGroups = const [],
  List<CatalogGroupDraft> initialSelection = const [],
  String? initialPresetId,
  CatalogPickerPurpose purpose = CatalogPickerPurpose.add,
  bool allowCustom = true,
}) {
  final statusBar = MediaQuery.paddingOf(context).top;
  return showModalBottomSheet<CatalogPickerResult>(
    context: context,
    useRootNavigator: true,
    useSafeArea: true,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: context.rd.bg,
    builder:
        (context) => _InstrumentCatalogSheet(
          tenantType: tenantType,
          existingGroups: List.unmodifiable(existingGroups),
          initialSelection: List.unmodifiable(initialSelection),
          initialPresetId: initialPresetId,
          purpose: purpose,
          allowCustom: allowCustom,
          statusBar: statusBar,
        ),
  );
}

class _InstrumentCatalogSheet extends StatefulWidget {
  const _InstrumentCatalogSheet({
    required this.tenantType,
    required this.existingGroups,
    required this.initialSelection,
    required this.initialPresetId,
    required this.purpose,
    required this.allowCustom,
    required this.statusBar,
  });

  final String tenantType;
  final List<Group> existingGroups;
  final List<CatalogGroupDraft> initialSelection;
  final String? initialPresetId;
  final CatalogPickerPurpose purpose;
  final bool allowCustom;
  final double statusBar;

  @override
  State<_InstrumentCatalogSheet> createState() =>
      _InstrumentCatalogSheetState();
}

class _InstrumentCatalogSheetState extends State<_InstrumentCatalogSheet> {
  final _search = TextEditingController();
  late final _rowOverrides = <String, CatalogGroupDraft>{
    for (final draft in widget.initialSelection)
      if (draft.instrumentId.isNotEmpty) draft.key: draft,
  };
  late final _selected = <String, CatalogGroupDraft>{
    for (final draft in widget.initialSelection)
      if (draft.name.trim().isNotEmpty && !_exists(draft)) draft.key: draft,
  };
  InstrumentFamily? _family;
  late CatalogPreset? _preset =
      instrumentPresets
          .where(
            (preset) =>
                preset.id == widget.initialPresetId &&
                preset.tenantType == widget.tenantType,
          )
          .firstOrNull;
  bool _showSelection = false;
  int _customSerial = 0;

  String get _language => Localizations.localeOf(context).languageCode;
  bool get _choir => widget.tenantType == 'choir';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _exists(CatalogGroupDraft draft) =>
      widget.existingGroups.any((group) => draftMatchesGroup(draft, group));

  String _newKey(String prefix) {
    String key;
    do {
      key = '$prefix:${++_customSerial}';
    } while (_selected.containsKey(key) ||
        widget.initialSelection.any((draft) => draft.key == key) ||
        _rowOverrides.values.any((draft) => draft.key == key));
    return key;
  }

  void _toggle(CatalogGroupDraft draft) {
    if (_exists(draft)) return;
    setState(() {
      if (_selected.containsKey(draft.key)) {
        _selected.remove(draft.key);
      } else {
        _selected[draft.key] = draft;
      }
    });
  }

  void _apply() => Navigator.of(context).pop(
    CatalogPickerResult(
      drafts: List<CatalogGroupDraft>.unmodifiable(
        _selected.values.where(
          (draft) => draft.name.trim().isNotEmpty && !_exists(draft),
        ),
      ),
      presetId: _preset?.id,
    ),
  );

  Future<void> _choosePreset() async {
    final l10n = context.l10n;
    final presets =
        instrumentPresets
            .where((preset) => preset.tenantType == widget.tenantType)
            .toList();
    final choice = await showRdSettingsSheet<String>(
      context,
      (context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RdSheetHead(title: l10n.catalogPreset),
          Flexible(
            child: RdFormBody(
              shrinkWrap: true,
              children: [
                RdGroupedList(
                  children: [
                    RdListRow(
                      title: l10n.catalogWithoutPreset,
                      selected: _preset == null,
                      showChevron: false,
                      onTap: () => Navigator.of(context).pop(''),
                    ),
                    for (final preset in presets)
                      RdListRow(
                        title: preset.label(_language),
                        selected: _preset?.id == preset.id,
                        showChevron: false,
                        onTap: () => Navigator.of(context).pop(preset.id),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
    if (!mounted || choice == null) return;
    final preset = presets.where((preset) => preset.id == choice).firstOrNull;
    if (preset?.id == _preset?.id) return;
    if (preset == null) {
      // Removing the association never removes the user's selection.
      setState(() => _preset = null);
      return;
    }
    final change =
        _selected.isEmpty
            ? CatalogPresetChange.replace
            : await showCatalogPresetChangeDialog(context);
    if (!mounted || change == null) return;
    final additions =
        [
          for (final entry in preset.entries.where(
            (entry) => entry.selectedByDefault,
          ))
            draftFromPresetEntry(entry, languageCode: _language),
        ].where((draft) => !_exists(draft)).toList();
    final selection =
        change == CatalogPresetChange.merge
            ? mergeCatalogDrafts(_selected.values.toList(), additions)
            : additions;
    setState(() {
      _preset = preset;
      if (change == CatalogPresetChange.replace) _rowOverrides.clear();
      _selected.clear();
      for (final draft in selection) {
        _selected[draft.key] = draft;
        if (draft.instrumentId.isNotEmpty) _rowOverrides[draft.key] = draft;
      }
      _showSelection = false;
    });
  }

  Future<void> _custom() async {
    final l10n = context.l10n;
    final name = await showRdTextSheet(
      context,
      title: l10n.catalogCustom(widget.tenantType),
      hint: l10n.catalogNameHint(widget.tenantType),
      required: true,
    );
    if (!mounted || name == null) return;
    final draft = CatalogGroupDraft(
      key: _newKey('custom'),
      instrumentId: '',
      name: name,
    );
    setState(() {
      if (!_exists(draft)) _selected[draft.key] = draft;
      _showSelection = true;
    });
  }

  Future<void> _editName(CatalogGroupDraft draft, {String? sourceKey}) async {
    final l10n = context.l10n;
    final existing = _exists(draft);
    final name = await showRdTextSheet(
      context,
      title: existing ? l10n.catalogAddPart : l10n.catalogEditName,
      initial: draft.name,
      hint: l10n.catalogNameHint(widget.tenantType),
      helper: l10n.catalogEditHint,
      required: true,
    );
    if (!mounted || name == null) return;
    var renamed = draft.copyWith(name: name);
    // An existing local entry is never edited. Give the additional voice
    // its own draft key, after copyWith has restricted its synonyms.
    if (existing) {
      renamed = CatalogGroupDraft(
        key: _newKey('voice:${draft.key}'),
        instrumentId: renamed.instrumentId,
        name: renamed.name,
        categoryName: renamed.categoryName,
        synonyms: renamed.synonyms,
        tuning: renamed.tuning,
        clefs: renamed.clefs,
      );
    }
    setState(() {
      for (final key in _rowOverrides.keys.toList()) {
        if (_rowOverrides[key]!.key == draft.key) _rowOverrides[key] = renamed;
      }
      if (sourceKey != null) _rowOverrides[sourceKey] = renamed;
      _selected.remove(draft.key);
      if (!_exists(renamed)) _selected[renamed.key] = renamed;
    });
  }

  CatalogGroupDraft _resolveRow(CatalogGroupDraft draft) {
    final rowDraft = _rowOverrides[draft.key] ?? draft;
    // Renamed parts keep their identity even while unchecked. Equivalent
    // overrides can still resolve through the catalog's curated aliases.
    final matchingDraft = draftMatchesDraft(rowDraft, draft) ? draft : rowDraft;
    final selected =
        _selected[draft.key] ??
        _selected[rowDraft.key] ??
        _selected.values
            .where((selected) => draftMatchesDraft(matchingDraft, selected))
            .firstOrNull;
    if (selected == null) return rowDraft;
    // Merge may retain another key for the same part. Keep that association
    // after deselection so reselecting restores the original draft as well.
    _rowOverrides[draft.key] = selected;
    return selected;
  }

  List<({CatalogGroupDraft draft, String sourceKey, bool optional})>
  _results() {
    final catalogResults = searchInstrumentCatalog(
      _search.text,
      family: _family,
      voicesOnly: _choir,
    );
    final matchingIds =
        catalogResults.map((instrument) => instrument.id).toSet();
    final instruments = {
      for (final instrument in instrumentCatalog) instrument.id: instrument,
    };
    final query = normalizeCatalogName(_search.text);
    final presetIds =
        _preset?.entries.map((entry) => entry.instrumentId).toSet() ??
        <String>{};
    final results =
        <({CatalogGroupDraft draft, String sourceKey, bool optional})>[];
    for (final entry in _preset?.entries ?? const <CatalogPresetEntry>[]) {
      final draft = _resolveRow(
        draftFromPresetEntry(entry, languageCode: _language),
      );
      if (_family != null &&
          instruments[entry.instrumentId]?.family != _family) {
        continue;
      }
      if (query.isNotEmpty &&
          !matchingIds.contains(entry.instrumentId) &&
          ![
            draft.name,
            ...draft.synonyms,
          ].any((name) => normalizeCatalogName(name).contains(query))) {
        continue;
      }
      results.add((
        draft: draft,
        sourceKey: entry.key,
        optional: !entry.selectedByDefault,
      ));
    }
    for (final instrument in catalogResults) {
      if (presetIds.contains(instrument.id)) continue;
      final draft = _resolveRow(
        draftFromInstrument(instrument, languageCode: _language),
      );
      results.add((draft: draft, sourceKey: instrument.id, optional: false));
    }
    return results;
  }

  Widget _row(
    CatalogGroupDraft draft, {
    String? sourceKey,
    bool optional = false,
  }) {
    final l10n = context.l10n;
    final existing = _exists(draft);
    final selected = _selected.containsKey(draft.key);
    return Semantics(
      selected: selected,
      child: RdListRow(
        key: Key('catalog-entry-${draft.key}'),
        title: draft.name,
        subtitle:
            existing
                ? l10n.catalogExisting
                : (optional ? l10n.catalogOptional : null),
        selected: selected,
        showChevron: false,
        leading: Checkbox(
          value: selected,
          onChanged: existing ? null : (_) => _toggle(draft),
        ),
        trailing: IconButton(
          tooltip: existing ? l10n.catalogAddPart : l10n.catalogEditName,
          icon: Icon(Icons.edit_outlined, size: 20, color: context.rd.text2),
          onPressed: () => _editName(draft, sourceKey: sourceKey),
        ),
        onTap: existing ? null : () => _toggle(draft),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.rd;
    final mq = MediaQuery.of(context);
    final height =
        (mq.size.height - mq.viewInsets.bottom - widget.statusBar - 48)
            .clamp(160.0, mq.size.height * 0.90)
            .toDouble();
    final results = _results();
    final applyLabel =
        widget.purpose == CatalogPickerPurpose.setup
            ? l10n.catalogApply
            : l10n.catalogAddCount(widget.tenantType, _selected.length);
    return Padding(
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: height,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              RdSheetHead(title: l10n.catalogTitle(widget.tenantType)),
              Expanded(
                child: RdFormBody(
                  children: [
                    RdGroupedList(
                      children: [
                        RdFieldRow(
                          label: l10n.catalogSearch(widget.tenantType),
                          child: TextField(
                            key: const Key('catalog-search'),
                            controller: _search,
                            decoration: rdInputDecoration(
                              p,
                              l10n.catalogSearchHint(widget.tenantType),
                            ),
                            style: RdType.body(p),
                            textInputAction: TextInputAction.search,
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ],
                    ),
                    if (!_choir) ...[
                      const SizedBox(height: 12),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            RdChoiceChip(
                              label: l10n.catalogAllFamilies,
                              selected: _family == null,
                              onTap: () => setState(() => _family = null),
                            ),
                            for (final family in InstrumentFamily.values) ...[
                              const SizedBox(width: 8),
                              RdChoiceChip(
                                key: Key('catalog-family-${family.name}'),
                                label: family.label(_language),
                                selected: _family == family,
                                onTap: () => setState(() => _family = family),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    RdGroupedList(
                      children: [
                        RdListRow(
                          key: const Key('catalog-presets'),
                          title: l10n.catalogPreset,
                          value:
                              _preset?.label(_language) ??
                              l10n.catalogWithoutPreset,
                          onTap: _choosePreset,
                        ),
                        if (widget.allowCustom)
                          RdListRow(
                            key: const Key('catalog-custom'),
                            title: l10n.catalogCustom(widget.tenantType),
                            leading: RdRowIcon(Icons.add),
                            onTap: _custom,
                          ),
                        RdListRow(
                          title: l10n.catalogSelected,
                          value: _selected.length.toString(),
                          showChevron: false,
                          trailing: Icon(
                            _showSelection
                                ? Icons.expand_less
                                : Icons.expand_more,
                            color: p.text2,
                          ),
                          onTap:
                              () => setState(
                                () => _showSelection = !_showSelection,
                              ),
                        ),
                      ],
                    ),
                    if (_showSelection && _selected.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      RdGroupedList(
                        key: const Key('catalog-selection'),
                        children: [
                          for (final draft in _selected.values) _row(draft),
                        ],
                      ),
                    ],
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 8),
                      child: Text(l10n.catalogBrowse, style: RdType.section(p)),
                    ),
                    if (results.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(4),
                        child: Text(
                          l10n.catalogNoResults,
                          style: RdType.meta(p, size: 15),
                        ),
                      )
                    else
                      RdGroupedList(
                        children: [
                          for (final result in results)
                            _row(
                              result.draft,
                              sourceKey: result.sourceKey,
                              optional: result.optional,
                            ),
                        ],
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        l10n.catalogSelectedCount(_selected.length),
                        style: RdType.meta(p, size: 13),
                      ),
                    ),
                    const SizedBox(height: 8),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final label = TextPainter(
                          text: TextSpan(
                            text: applyLabel,
                            style: (Theme.of(context).textTheme.labelLarge ??
                                    const TextStyle())
                                .copyWith(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          textDirection: Directionality.of(context),
                          textScaler: mq.textScaler,
                        )..layout(
                          maxWidth: math.max(1, constraints.maxWidth - 32),
                        );
                        final height = math.max(48.0, label.height + 24);
                        label.dispose();
                        return RdPrimaryButton(
                          key: const Key('catalog-apply'),
                          label: applyLabel,
                          height: height,
                          onPressed: _apply,
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
