part of 'work_edit_page.dart';

/// Form body and field rows for [RdWorkEditPage].
extension _RdWorkEditForm on _RdWorkEditPageState {
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
                onChanged: (_) => _update(() {}),
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
                      onChanged: (_) => _update(() {}),
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
                      onChanged: (_) => _update(() {}),
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
        if (data.isOrchestra) hint(l10n.redesignWorkEditInstrumentationHint(ref.watch(rdGroupKindProvider))),
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
        const SizedBox(height: 20),
        RdGroupLabel(l10n.redesignWorkEditPlanMinutes),
        RdGroupedList(
          children: [
            RdFieldRow(
              label: l10n.redesignWorkEditPlanMinutesLabel,
              child: TextField(
                key: const Key('rd-work-edit-minutes'),
                controller: _minutes,
                focusNode: _minutesFocus,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)],
                textInputAction: TextInputAction.done,
                style: textStyle,
                decoration: rdInputDecoration(p, '${PlanSongHelper.betaMinutes}'),
              ),
            ),
          ],
        ),
        hint(l10n.redesignWorkEditPlanMinutesHint(PlanSongHelper.betaMinutes)),
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
        _update(() => _additional[field.id] = v);
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
