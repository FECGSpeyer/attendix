part of 'group_edit_page.dart';

/// Form sections for [RdGroupEditPage].
extension _RdGroupEditSections on _RdGroupEditPageState {
  Widget _form(BuildContext context, Group group) {
    final p = context.rd;
    final l10n = context.l10n;
    final tenantType = ref.watch(currentTenantProvider)?.type;
    final kind = ref.watch(rdGroupKindProvider);
    final categories = ref.watch(groupCategoriesProvider).valueOrNull ?? const <GroupCategory>[];
    // A choir has no level above its Stimmen (see [rdOffersCategories]).
    final withCategory = rdOffersCategories(kind, categories);
    final isMain = group.maingroup == true;
    final isGeneral = tenantType == 'general';
    // Like the old page: the music fields only for orchestras, never for
    // the main group; synonyms for orchestras and choirs.
    final showMusic = tenantType != 'choir' && !isGeneral && !isMain;
    final showSynonyms = !isGeneral && !isMain;
    final category = categories.where((c) => c.id == _categoryId).firstOrNull;
    final textStyle = TextStyle(fontSize: 17, color: p.text);

    final memberCount = isMain ? null : ref.watch(rdGroupMemberCountProvider(_groupId)).valueOrNull;
    final String? deleteBlocked =
        isMain
            ? l10n.redesignGroupEditDeleteMain
            : (memberCount ?? 0) > 0
            ? l10n.redesignGroupEditDeleteMembers(kind, memberCount!)
            : null;

    return RdFormBody(
      children: [
        if (isMain) ...[
          RdInfoCard(icon: Icons.star_outline, text: l10n.redesignGroupEditMainGroupHint),
          const SizedBox(height: 16),
        ],
        RdGroupedList(
          children: [
            RdFieldRow(
              label: l10n.redesignGroupEditName,
              child: _textField('name', _name, _nameFocus, textStyle),
            ),
            if (withCategory)
              RdListRow(
                key: const Key('rd-group-edit-category'),
                title: l10n.rdWordsCategory(kind),
                value: category?.name ?? l10n.redesignGroupEditCategoryNone,
                onTap: () => _pickCategory(categories),
              ),
          ],
        ),
        if (_name.text.trim().isEmpty) _hint(l10n.redesignGroupEditNameEmpty, color: p.absent),
        if (withCategory)
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: RdTextLink(
              label: l10n.redesignGroupEditManageCategories(kind),
              onTap: () => showInstrumentCategoriesSheet(context),
            ),
          ),
        if (showMusic) ..._musicSection(context, textStyle),
        if (showSynonyms) ..._synonymsSection(context, kind, textStyle),
        const SizedBox(height: 20),
        RdGroupedList(
          children: [
            RdFieldRow(
              label: l10n.redesignGroupEditNotes,
              child: _textField('notes', _notes, _notesFocus, textStyle, maxLines: 6),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 16, 4, 20),
          child: Text(l10n.redesignGroupEditHint, style: RdType.meta(p, size: 13)),
        ),
        const SizedBox(height: 8),
        RdGroupedList(
          children: [
            RdListRow(
              key: const Key('rd-group-edit-delete'),
              title: l10n.redesignGroupEditDelete(kind),
              titleColor: deleteBlocked == null ? p.absent : p.text2,
              leading: Icon(Icons.delete_outline, color: deleteBlocked == null ? p.absent : p.text2),
              showChevron: false,
              onTap: deleteBlocked == null && !_deleting ? () => _delete(group) : null,
            ),
          ],
        ),
        if (deleteBlocked != null) _hint(deleteBlocked),
      ],
    );
  }

  Widget _hint(String text, {Color? color}) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
    child: Text(text, style: RdType.meta(context.rd, size: 13).copyWith(color: color)),
  );

  Widget _textField(
    String key,
    TextEditingController c,
    FocusNode f,
    TextStyle textStyle, {
    int maxLines = 1,
    String hintText = '',
  }) => TextField(
    key: Key('rd-group-edit-$key'),
    controller: c,
    focusNode: f,
    minLines: 1,
    maxLines: maxLines,
    textCapitalization: TextCapitalization.sentences,
    textInputAction: maxLines == 1 ? TextInputAction.done : TextInputAction.newline,
    style: textStyle,
    decoration: rdInputDecoration(context.rd, hintText),
    onChanged: key == 'name' ? (_) => _update(() {}) : null,
  );

  List<Widget> _musicSection(BuildContext context, TextStyle textStyle) {
    final l10n = context.l10n;
    return [
      const SizedBox(height: 12),
      RdGroupLabel(l10n.redesignGroupEditTuning),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final tuning in <String?>[
            null,
            if (_tuning != null && !groupTuningOptions.contains(_tuning)) _tuning,
            ...groupTuningOptions,
          ])
            RdChoiceChip(
              key: Key('rd-group-edit-tuning-${tuning ?? 'unset'}'),
              label: tuning ?? l10n.personNotSet,
              selected: _tuning == tuning,
              semanticLabel: '${l10n.redesignGroupEditTuning}: ${tuning ?? l10n.personNotSet}',
              onTap: () {
                if (tuning == _tuning) return;
                final before = _tuning;
                _update(() => _tuning = tuning);
                _write(
                  {'tuning': tuning},
                  revert: () {
                    if (_tuning == tuning) _tuning = before;
                  },
                );
              },
            ),
        ],
      ),
      const SizedBox(height: 20),
      RdGroupLabel(l10n.redesignGroupEditClefs),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          RdChoiceChip(
            key: const Key('rd-group-edit-clefs-unset'),
            label: l10n.personNotSet,
            selected: _clefs.isEmpty,
            semanticLabel: '${l10n.redesignGroupEditClefs}: ${l10n.personNotSet}',
            onTap: () {
              if (_clefs.isNotEmpty) _setClefs({});
            },
          ),
          for (final clef in groupClefOptions)
            RdChoiceChip(
              key: Key('rd-group-edit-clef-$clef'),
              label: '${groupClefLabel(l10n, clef)} ($clef)',
              selected: _clefs.contains(clef),
              onTap: () => _toggleClef(clef),
            ),
        ],
      ),
      _hint(l10n.redesignGroupEditClefsHint),
      const SizedBox(height: 20),
      RdGroupLabel(l10n.redesignGroupEditInstrument),
      RdGroupedList(
        children: [
          RdFieldRow(
            label: l10n.redesignGroupEditRange,
            child: _textField('range', _range, _rangeFocus, textStyle),
          ),
        ],
      ),
    ];
  }

  List<Widget> _synonymsSection(BuildContext context, String kind, TextStyle textStyle) {
    final p = context.rd;
    final l10n = context.l10n;
    return [
      const SizedBox(height: 20),
      Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          RdGroupLabel(l10n.redesignGroupEditSynonyms),
          if (_generating)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: p.primary),
              ),
            )
          else
            RdTextLink(
              key: const Key('rd-group-edit-generate'),
              label: l10n.redesignGroupEditGenerate,
              onTap: _generateSynonyms,
            ),
        ],
      ),
      RdGroupedList(
        children: [
          RdFieldRow(
            label: l10n.redesignGroupEditSynonymsLabel,
            child: _textField('synonyms', _synonyms, _synonymsFocus, textStyle, maxLines: 4),
          ),
        ],
      ),
      _hint(l10n.redesignGroupEditSynonymsHint(kind)),
    ];
  }
}
