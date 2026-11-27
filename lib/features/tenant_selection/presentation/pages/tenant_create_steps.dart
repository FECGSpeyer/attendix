part of 'tenant_create_page.dart';

/// Step UI builders (header, step body, type cards, summary, footer) for [TenantCreatePage].
extension _TenantCreateSteps on _TenantCreatePageState {
  Widget _buildHeader(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          Flexible(
            child: TextButton(
              onPressed: _busy ? null : _close,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(l10n.redesignCommonCancel, maxLines: 1),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              l10n.redesignTenantsNewTitle,
              textAlign: TextAlign.end,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: p.text),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepBody(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final texts = TenantTypeTexts.of(_selectedType, l10n);
    final language = Localizations.localeOf(context).languageCode;
    final presets = instrumentPresets.where((preset) => preset.tenantType == _selectedType);
    final selectedPreset = presets.where((preset) => preset.id == _catalogPresetId).firstOrNull;
    final total = _hasType ? _lastStep + 1 : 3;
    final finalStep = _hasType && _step == _lastStep;
    final count =
        _catalogSelection.isEmpty ? l10n.catalogSetupNone : l10n.catalogSetupCount(_catalogSelection.length);
    final question = switch (_step) {
      0 => l10n.ensembleGuideQuestionType,
      1 => l10n.ensembleGuideQuestionName(_selectedType),
      _ => l10n.ensembleGuideQuestionInstruments,
    };

    return RdFormBody(
      key: ValueKey(_step),
      children: [
        const SizedBox(height: 12),
        Semantics(
          liveRegion: true,
          child: Text(l10n.ensembleGuideProgress(_step + 1, total), style: RdType.meta(p, size: 14)),
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: (_step + 1) / total,
            color: p.primary,
            backgroundColor: p.track,
            minHeight: 4,
          ),
        ),
        const SizedBox(height: 24),
        Semantics(
          header: true,
          child: Text(
            question,
            style: TextStyle(fontSize: 27, height: 1.18, fontWeight: FontWeight.w700, color: p.text),
          ),
        ),
        const SizedBox(height: 24),
        if (_step == 0) ...[
          for (final type in const ['orchestra', 'choir', 'general']) _typeCard(context, type),
        ],
        if (_step == 1) ...[
          RdGroupedList(
            children: [
              _textField(
                context,
                l10n.redesignTenantsNewName,
                _longNameController,
                texts.namePlaceholder,
                'rd-tenant-new-name',
                maxLength: 50,
              ),
              _textField(
                context,
                l10n.redesignTenantsNewShort,
                _shortNameController,
                texts.shortPlaceholder,
                'rd-tenant-new-short',
                onChanged: (_) => _shortNameEdited = true,
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
            child: Text(l10n.ensembleGuideNameHint, style: RdType.meta(p, size: 14)),
          ),
        ],
        if (_step == 2) ...[
          Text(l10n.ensembleGuideInstrumentsHint, style: RdType.meta(p, size: 15)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final preset in presets)
                RdChoiceChip(
                  key: Key('rd-tenant-preset-${preset.id}'),
                  label: preset.label(language),
                  selected: _catalogPresetId == preset.id,
                  onTap: _busy ? null : () => _choosePreset(preset),
                ),
              RdChoiceChip(
                key: const Key('rd-tenant-preset-later'),
                label: l10n.catalogSetupLater,
                selected: _catalogPresetId == null && _catalogSelection.isEmpty,
                onTap: _busy ? null : () => _choosePreset(null),
              ),
            ],
          ),
          const SizedBox(height: 16),
          RdGroupedList(
            children: [
              RdListRow(
                key: const Key('rd-tenant-catalog'),
                title:
                    _catalogSelection.isEmpty && _catalogPresetId == null
                        ? l10n.ensembleGuideCustom
                        : l10n.catalogSetupChoose,
                subtitle: count,
                leading: const RdRowIcon(Icons.tune),
                onTap: _busy ? null : _chooseCatalog,
              ),
            ],
          ),
        ],
        if (finalStep) _buildSummary(context, selectedPreset, language, count),
      ],
    );
  }

  Widget _textField(
    BuildContext context,
    String label,
    TextEditingController controller,
    String placeholder,
    String key, {
    int? maxLength,
    ValueChanged<String>? onChanged,
  }) {
    final p = context.rd;
    return RdFieldRow(
      label: label,
      child: TextField(
        key: Key(key),
        controller: controller,
        enabled: !_busy,
        maxLength: maxLength,
        onChanged: onChanged,
        textCapitalization: TextCapitalization.sentences,
        textInputAction: TextInputAction.next,
        style: TextStyle(fontSize: 17, color: p.text),
        decoration: rdInputDecoration(p, placeholder).copyWith(counterText: ''),
      ),
    );
  }

  Widget _typeCard(BuildContext context, String type) {
    final p = context.rd;
    final l10n = context.l10n;
    final typeTexts = TenantTypeTexts.of(type, l10n);
    final selected = _hasType && _selectedType == type;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Semantics(
        selected: selected,
        button: true,
        child: Material(
          color: selected ? p.primary.withValues(alpha: 0.10) : p.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: selected ? p.primary : p.offBorder, width: selected ? 2 : 1),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: Key('rd-tenant-type-$type'),
            onTap: _busy ? null : () => _chooseType(type),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(typeTexts.icon, color: p.primary, size: 26),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          type == 'general' ? l10n.ensembleGuideOtherGroup : typeTexts.label,
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: p.text),
                        ),
                        const SizedBox(height: 5),
                        Text(typeTexts.help, style: RdType.meta(p, size: 13)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Icon(
                    selected ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: selected ? p.primary : p.text2,
                    size: 22,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummary(
    BuildContext context,
    CatalogPreset? selectedPreset,
    String language,
    String count,
  ) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        RdGroupLabel(l10n.ensembleGuideSummary),
        RdGroupedList(
          children: [
            RdListRow(
              title: _longName.isEmpty ? l10n.redesignTenantsNewName : _longName,
              subtitle: _shortName,
              showChevron: false,
            ),
            if (_selectedType != 'general')
              RdListRow(
                title: selectedPreset?.label(language) ?? l10n.catalogSetupTitle,
                subtitle: _catalogSelection.isEmpty ? l10n.catalogSetupLater : count,
                showChevron: false,
              ),
            RdListRow(
              key: const Key('rd-tenant-guide-leadership'),
              title: l10n.ensembleGuideLeadership,
              subtitle: _mainGroupName,
              value: l10n.ensembleGuideChange,
              onTap: _busy ? null : _editLeadership,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFooter(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final finalStep = _hasType && _step == _lastStep;
    final canContinue = !_busy && !_creationComplete && (_step == 0 ? _hasType : _isComplete);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final back = TextButton(
                key: const Key('rd-tenant-guide-back'),
                onPressed: _busy ? null : _previousStep,
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                child: Text(l10n.ensembleGuideBack),
              );
              final primary = FilledButton(
                key: Key(finalStep ? 'rd-tenant-guide-create' : 'rd-tenant-guide-next'),
                onPressed: canContinue ? (finalStep ? _createTenant : _nextStep) : null,
                style: FilledButton.styleFrom(
                  backgroundColor: p.primary,
                  foregroundColor: p.onPrimary,
                  disabledBackgroundColor: p.track,
                  disabledForegroundColor: p.text2,
                  minimumSize: const Size(48, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(p.buttonRadius)),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                child:
                    _isLoading
                        ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : Text(
                          finalStep ? l10n.ensembleGuideCreate(_selectedType) : l10n.ensembleGuideNext,
                          textAlign: TextAlign.center,
                        ),
              );
              final stacked = constraints.maxWidth < 328 || MediaQuery.textScalerOf(context).scale(16) > 21;
              if (stacked) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    primary,
                    if (_step > 0) ...[const SizedBox(height: 4), back],
                  ],
                );
              }
              return Row(
                children: [
                  if (_step > 0) ...[Flexible(child: back), const SizedBox(width: 12)],
                  Expanded(flex: 2, child: primary),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
