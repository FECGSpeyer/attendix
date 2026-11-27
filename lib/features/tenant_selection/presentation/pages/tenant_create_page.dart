import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/supabase_config.dart';
import '../../../../core/providers/group_providers.dart';
import '../../../../core/services/offline_queue_service.dart'
    show connectivityCheckProvider;
import '../../../../core/utils/device_timezone.dart';
import '../../../../core/providers/legal_providers.dart'
    show accountNotifierProvider;
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/repositories/tenant_create_repository.dart';
import '../../../../l10n/l10n.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../data/repositories/base_repository.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';

import '../../../../core/router/redesign_routes.dart';
import '../../../../core/theme/redesign/rd_theme.dart';
import '../../../attendance/presentation/widgets/event/rd_form_widgets.dart';
import '../../../../shared/widgets/redesign/rd_widgets.dart';
import '../../../settings/presentation/widgets/manage/rd_settings_sheets.dart'
    show showRdTextSheet;
import '../../../instruments/data/catalog_import.dart';
import '../../../instruments/data/catalog_selection.dart';
import '../../../instruments/data/instrument_presets.dart';
import '../../../instruments/presentation/widgets/instrument_catalog_sheet.dart';

/// Create a new group/tenant ("Neue Gruppe").
class TenantCreatePage extends ConsumerStatefulWidget {
  const TenantCreatePage({super.key});

  @override
  ConsumerState<TenantCreatePage> createState() => _TenantCreatePageState();
}

/// Type-specific texts for the new-group form.
class TenantTypeTexts {
  const TenantTypeTexts({
    required this.option,
    required this.label,
    required this.help,
    required this.namePlaceholder,
    required this.shortPlaceholder,
    required this.mainGroupPlaceholder,
    required this.icon,
  });

  final String option;
  final String label;
  final String help;
  final String namePlaceholder;
  final String shortPlaceholder;
  final String mainGroupPlaceholder;
  final IconData icon;

  static Map<String, TenantTypeTexts> byType(AppLocalizations l10n) => {
    'general': TenantTypeTexts(
      option: l10n.registerTypeGeneral,
      label: l10n.registerTypeGeneral,
      help: l10n.registerHelpGeneral,
      namePlaceholder: l10n.registerPlaceholderGeneralName,
      shortPlaceholder: l10n.registerPlaceholderGeneralShort,
      mainGroupPlaceholder: l10n.registerPlaceholderGeneralMain,
      icon: Icons.groups_outlined,
    ),
    'choir': TenantTypeTexts(
      option: l10n.registerTypeChoirOption,
      label: l10n.registerTypeChoir,
      help: l10n.registerHelpChoir,
      namePlaceholder: l10n.registerPlaceholderChoirName,
      shortPlaceholder: l10n.registerPlaceholderChoirShort,
      mainGroupPlaceholder: l10n.registerPlaceholderChoirMain,
      icon: Icons.mic_none_outlined,
    ),
    'orchestra': TenantTypeTexts(
      option: l10n.registerTypeOrchestraOption,
      label: l10n.registerTypeOrchestra,
      help: l10n.registerHelpOrchestra,
      namePlaceholder: l10n.registerPlaceholderOrchestraName,
      shortPlaceholder: l10n.registerPlaceholderOrchestraShort,
      mainGroupPlaceholder: l10n.registerPlaceholderOrchestraMain,
      icon: Icons.music_note_outlined,
    ),
  };

  static TenantTypeTexts of(String type, AppLocalizations l10n) {
    final all = byType(l10n);
    return all[type] ?? all['general']!;
  }
}

class _TenantCreatePageState extends ConsumerState<TenantCreatePage> {
  final _shortNameController = TextEditingController();
  final _longNameController = TextEditingController();
  final _mainGroupNameController = TextEditingController();
  String _selectedType = 'general';
  bool _isLoading = false;
  bool _creationComplete = false;
  bool _isChoosingCatalog = false;
  String? _catalogPresetId;
  List<CatalogGroupDraft> _catalogSelection = const [];

  @override
  void initState() {
    super.initState();
    _shortNameController.addListener(_onFieldChanged);
    _longNameController.addListener(_onNameChanged);
    _mainGroupNameController.addListener(_onFieldChanged);
  }

  void _onFieldChanged() => setState(() {});

  @override
  void dispose() {
    _shortNameController.removeListener(_onFieldChanged);
    _longNameController.removeListener(_onNameChanged);
    _mainGroupNameController.removeListener(_onFieldChanged);
    _shortNameController.dispose();
    _longNameController.dispose();
    _mainGroupNameController.dispose();
    super.dispose();
  }

  String get _longName => _longNameController.text.trim();
  String get _shortName => _shortNameController.text.trim();
  String get _mainGroupName => _mainGroupNameController.text.trim();
  bool get _isComplete =>
      _longName.isNotEmpty &&
      _shortName.isNotEmpty &&
      _mainGroupName.isNotEmpty;

  void _close() {
    if (_busy) return;
    setState(() => _isClosing = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/tenants');
      }
    });
  }

  int _step = 0;
  bool _hasType = false;
  bool _shortNameEdited = false;
  bool _mainNameInitialized = false;
  bool _isClosing = false;
  final _typeSelections =
      <String, ({String? presetId, List<CatalogGroupDraft> drafts})>{};
  bool get _busy => _isLoading || _isChoosingCatalog || _isClosing;
  int get _lastStep => _selectedType == 'general' ? 1 : 2;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_mainNameInitialized) {
      _mainNameInitialized = true;
      _mainGroupNameController.text =
          context.l10n.ensembleGuideLeadershipDefault;
    }
  }

  void _onNameChanged() {
    if (!_shortNameEdited) {
      final words =
          _longNameController.text
              .trim()
              .split(RegExp(r'\s+'))
              .where((word) => word.isNotEmpty)
              .toList();
      final suggestion =
          words.length > 1
              ? words.take(6).map((word) => word.characters.first).join()
              : (words.isEmpty ? '' : words.first.characters.take(3).join());
      _shortNameController.text = suggestion.toUpperCase();
    }
    _onFieldChanged();
  }

  void _chooseType(String type) {
    if (_busy) return;
    setState(() {
      if (_selectedType != type) {
        if (_hasType && _selectedType != 'general') {
          _typeSelections[_selectedType] = (
            presetId: _catalogPresetId,
            drafts: _catalogSelection,
          );
        }
        final saved = _typeSelections[type];
        _catalogPresetId = saved?.presetId;
        _catalogSelection = saved?.drafts ?? const [];
        _selectedType = type;
      }
      _hasType = true;
    });
  }

  void _nextStep() {
    if (_busy || _creationComplete) return;
    if ((_step == 0 && !_hasType) || (_step == 1 && !_isComplete)) return;
    if (_step < _lastStep) {
      FocusManager.instance.primaryFocus?.unfocus();
      setState(() => _step++);
    }
  }

  void _previousStep() {
    if (_busy || _step == 0) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _step--);
  }

  Future<void> _editLeadership() async {
    if (_busy) return;
    final account = ref.read(currentAuthUserIdProvider);
    final tenant = ref.read(currentTenantIdProvider);
    setState(() => _isChoosingCatalog = true);
    try {
      final value = await showRdTextSheet(
        context,
        title: context.l10n.ensembleGuideLeadershipEdit,
        initial: _mainGroupName,
        hint: context.l10n.ensembleGuideLeadershipDefault,
        required: true,
      );
      if (!mounted ||
          value == null ||
          ref.read(currentAuthUserIdProvider) != account ||
          ref.read(currentTenantIdProvider) != tenant) {
        return;
      }
      _mainGroupNameController.text = value;
    } finally {
      if (mounted) setState(() => _isChoosingCatalog = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final texts = TenantTypeTexts.of(_selectedType, l10n);
    final language = Localizations.localeOf(context).languageCode;
    final presets = instrumentPresets.where(
      (preset) => preset.tenantType == _selectedType,
    );
    final selectedPreset =
        presets.where((preset) => preset.id == _catalogPresetId).firstOrNull;
    final total = _hasType ? _lastStep + 1 : 3;
    final finalStep = _hasType && _step == _lastStep;
    final count =
        _catalogSelection.isEmpty
            ? l10n.catalogSetupNone
            : l10n.catalogSetupCount(_catalogSelection.length);
    final question = switch (_step) {
      0 => l10n.ensembleGuideQuestionType,
      1 => l10n.ensembleGuideQuestionName(_selectedType),
      _ => l10n.ensembleGuideQuestionInstruments,
    };
    Widget field(
      String label,
      TextEditingController controller,
      String placeholder,
      String key, {
      int? maxLength,
      ValueChanged<String>? onChanged,
    }) => RdFieldRow(
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
    Widget typeCard(String type) {
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
              side: BorderSide(
                color: selected ? p.primary : p.offBorder,
                width: selected ? 2 : 1,
              ),
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
                            type == 'general'
                                ? l10n.ensembleGuideOtherGroup
                                : typeTexts.label,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: p.text,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(typeTexts.help, style: RdType.meta(p, size: 13)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Icon(
                      selected
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
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

    Widget summary() => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        RdGroupLabel(l10n.ensembleGuideSummary),
        RdGroupedList(
          children: [
            RdListRow(
              title:
                  _longName.isEmpty ? l10n.redesignTenantsNewName : _longName,
              subtitle: _shortName,
              showChevron: false,
            ),
            if (_selectedType != 'general')
              RdListRow(
                title:
                    selectedPreset?.label(language) ?? l10n.catalogSetupTitle,
                subtitle:
                    _catalogSelection.isEmpty ? l10n.catalogSetupLater : count,
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
    final canContinue =
        !_busy && !_creationComplete && (_step == 0 ? _hasType : _isComplete);
    return PopScope(
      canPop: _isClosing || (!_busy && _step == 0),
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _previousStep();
      },
      child: Scaffold(
        backgroundColor: p.bg,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
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
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: p.text,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: RdFormBody(
                  key: ValueKey(_step),
                  children: [
                    const SizedBox(height: 12),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        l10n.ensembleGuideProgress(_step + 1, total),
                        style: RdType.meta(p, size: 14),
                      ),
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
                        style: TextStyle(
                          fontSize: 27,
                          height: 1.18,
                          fontWeight: FontWeight.w700,
                          color: p.text,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (_step == 0) ...[
                      for (final type in const [
                        'orchestra',
                        'choir',
                        'general',
                      ])
                        typeCard(type),
                    ],
                    if (_step == 1) ...[
                      RdGroupedList(
                        children: [
                          field(
                            l10n.redesignTenantsNewName,
                            _longNameController,
                            texts.namePlaceholder,
                            'rd-tenant-new-name',
                            maxLength: 50,
                          ),
                          field(
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
                        child: Text(
                          l10n.ensembleGuideNameHint,
                          style: RdType.meta(p, size: 14),
                        ),
                      ),
                    ],
                    if (_step == 2) ...[
                      Text(
                        l10n.ensembleGuideInstrumentsHint,
                        style: RdType.meta(p, size: 15),
                      ),
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
                            selected:
                                _catalogPresetId == null &&
                                _catalogSelection.isEmpty,
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
                                _catalogSelection.isEmpty &&
                                        _catalogPresetId == null
                                    ? l10n.ensembleGuideCustom
                                    : l10n.catalogSetupChoose,
                            subtitle: count,
                            leading: RdRowIcon(Icons.tune),
                            onTap: _busy ? null : _chooseCatalog,
                          ),
                        ],
                      ),
                    ],
                    if (finalStep) summary(),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 640),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final back = TextButton(
                          key: const Key('rd-tenant-guide-back'),
                          onPressed: _busy ? null : _previousStep,
                          style: TextButton.styleFrom(
                            minimumSize: const Size(48, 48),
                          ),
                          child: Text(l10n.ensembleGuideBack),
                        );
                        final primary = FilledButton(
                          key: Key(
                            finalStep
                                ? 'rd-tenant-guide-create'
                                : 'rd-tenant-guide-next',
                          ),
                          onPressed:
                              canContinue
                                  ? (finalStep ? _createTenant : _nextStep)
                                  : null,
                          style: FilledButton.styleFrom(
                            backgroundColor: p.primary,
                            foregroundColor: p.onPrimary,
                            disabledBackgroundColor: p.track,
                            disabledForegroundColor: p.text2,
                            minimumSize: const Size(48, 48),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                p.buttonRadius,
                              ),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          child:
                              _isLoading
                                  ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                  : Text(
                                    finalStep
                                        ? l10n.ensembleGuideCreate(
                                          _selectedType,
                                        )
                                        : l10n.ensembleGuideNext,
                                    textAlign: TextAlign.center,
                                  ),
                        );
                        final stacked =
                            constraints.maxWidth < 328 ||
                            MediaQuery.textScalerOf(context).scale(16) > 21;
                        if (stacked) {
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              primary,
                              if (_step > 0) ...[
                                const SizedBox(height: 4),
                                back,
                              ],
                            ],
                          );
                        }
                        return Row(
                          children: [
                            if (_step > 0) ...[
                              Flexible(child: back),
                              const SizedBox(width: 12),
                            ],
                            Expanded(flex: 2, child: primary),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _chooseCatalog() async {
    if (_busy) return;
    final type = _selectedType;
    final accountId = ref.read(currentAuthUserIdProvider);
    final tenantId = ref.read(currentTenantIdProvider);
    setState(() => _isChoosingCatalog = true);
    try {
      final selection = await showInstrumentCatalogSheet(
        context,
        tenantType: type,
        initialSelection: _catalogSelection,
        initialPresetId: _catalogPresetId,
        purpose: CatalogPickerPurpose.setup,
      );
      if (!mounted ||
          selection == null ||
          _selectedType != type ||
          ref.read(currentAuthUserIdProvider) != accountId ||
          ref.read(currentTenantIdProvider) != tenantId) {
        return;
      }
      setState(() {
        _catalogSelection = selection.drafts;
        _catalogPresetId = selection.presetId;
      });
    } finally {
      if (mounted) setState(() => _isChoosingCatalog = false);
    }
  }

  Future<void> _choosePreset(CatalogPreset? preset) async {
    if (_busy || _creationComplete) return;
    if (preset?.id == _catalogPresetId &&
        (preset != null || _catalogSelection.isEmpty)) {
      return;
    }
    final type = _selectedType;
    if (preset != null && preset.tenantType != type) return;
    final accountId = ref.read(currentAuthUserIdProvider);
    final tenantId = ref.read(currentTenantIdProvider);
    final language = Localizations.localeOf(context).languageCode;
    final l10n = context.l10n;
    bool isCurrent() =>
        mounted &&
        _selectedType == type &&
        ref.read(currentAuthUserIdProvider) == accountId &&
        ref.read(currentTenantIdProvider) == tenantId;
    setState(() => _isChoosingCatalog = true);
    try {
      if (preset == null) {
        if (_catalogSelection.isNotEmpty) {
          final discard = await showAppDialog<bool>(
            context: context,
            builder:
                (dialogContext) => AppAlertDialog(
                  title: Text(l10n.catalogSetupSkipTitle),
                  content: Text(l10n.catalogSetupSkipMessage),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(false),
                      child: Text(l10n.commonCancel),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(true),
                      child: Text(l10n.catalogSetupDiscard),
                    ),
                  ],
                ),
          );
          if (!isCurrent() || discard != true) return;
        }
        setState(() {
          _catalogSelection = const [];
          _catalogPresetId = null;
        });
        return;
      }
      var change = CatalogPresetChange.replace;
      if (_catalogSelection.isNotEmpty) {
        final decision = await showCatalogPresetChangeDialog(context);
        if (!isCurrent() || decision == null) return;
        change = decision;
      }
      final additions = [
        for (final entry in preset.entries.where(
          (entry) => entry.selectedByDefault,
        ))
          draftFromPresetEntry(entry, languageCode: language),
      ];
      setState(() {
        _catalogSelection =
            change == CatalogPresetChange.merge
                ? mergeCatalogDrafts(_catalogSelection, additions)
                : additions;
        _catalogPresetId = preset.id;
      });
    } finally {
      if (mounted) setState(() => _isChoosingCatalog = false);
    }
  }

  Future<void> _createTenant() async {
    if (_busy || _creationComplete || !_hasType || _step != _lastStep) return;
    if (!_isComplete) {
      ToastHelper.showError(context, context.l10n.registerFillAllToast);
      return;
    }

    final userId = ref.read(currentAuthUserIdProvider);
    if (userId == null) return;
    final startingTenantId = ref.read(currentTenantIdProvider);
    final selection =
        _selectedType == 'general'
            ? <CatalogGroupDraft>[]
            : List<CatalogGroupDraft>.of(_catalogSelection);
    bool sameAccount() =>
        mounted && ref.read(currentAuthUserIdProvider) == userId;
    bool beforeSelection() =>
        sameAccount() && ref.read(currentTenantIdProvider) == startingTenantId;
    setState(() => _isLoading = true);

    try {
      final newTenant = await ref
          .read(tenantCreateRepositoryProvider)
          .createTenant(
            shortName: _shortName,
            longName: _longName,
            type: _selectedType,
            mainGroupName: _mainGroupName,
            timezone: deviceTimezone(),
          );

      // Once creation succeeded, no later failure may offer another create.
      _creationComplete = true;
      if (!beforeSelection()) return;
      ref.invalidate(userTenantsProvider);
      bool selectedTenant() =>
          sameAccount() && ref.read(currentTenantIdProvider) == newTenant.id;
      var selectionFailed = false;
      try {
        await ref.read(currentTenantProvider.notifier).setTenant(newTenant);
        if (!selectedTenant()) return;
        await ref.read(currentTenantUserProvider.future);
        if (!selectedTenant()) return;
        if (selection.isNotEmpty) {
          final online = await ref.read(connectivityCheckProvider)();
          if (!selectedTenant()) return;
          if (!online) throw StateError('Catalog import needs a connection');
          await importCatalogGroups(
            ref.read(groupRepositoryForTenantProvider(newTenant.id)),
            selection,
            isCurrent: selectedTenant,
          );
        }
      } on CatalogImportCancelled {
        return;
      } catch (_) {
        if (!selectedTenant() && !beforeSelection()) return;
        selectionFailed = true;
      } finally {
        if (selectedTenant()) {
          ref.invalidate(groupsProvider);
          ref.invalidate(groupsMapProvider);
          ref.invalidate(groupCategoriesProvider);
          ref.invalidate(playerCountsForGroupsProvider);
        }
      }
      if (!mounted || !sameAccount()) return;
      if (selectionFailed) {
        ToastHelper.showError(context, context.l10n.catalogSetupFailed);
        context.go(selectedTenant() ? RedesignRoutes.groups : '/tenants');
      } else if (selectedTenant()) {
        ToastHelper.showSuccess(
          context,
          context.l10n.redesignTenantsNewCreated,
        );
        GoRouter.of(context).go(RedesignRoutes.today);
      }
    } catch (e) {
      if (mounted && beforeSelection()) {
        ToastHelper.showError(
          context,
          context.l10n.registerCreateFailed(friendlyErrorMessage(e)),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}

/// Ionic register-account-menu "Konto löschen" (user without any group):
/// confirm, delete the account, back to the login. Also used by the Beta
/// page "Ohne Gruppe" ([RdNoGroupPage]).
Future<void> confirmDeleteAccountWithoutGroup(
  BuildContext context,
  WidgetRef ref,
) async {
  final l10n = context.l10n;
  final confirmed = await showAppDialog<bool>(
    context: context,
    builder:
        (dialogContext) => AppAlertDialog(
          title: Text(l10n.registerDeleteHeader),
          content: Text(l10n.registerDeleteMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.commonCancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: TextButton.styleFrom(foregroundColor: AppColors.danger),
              child: Text(l10n.registerDeleteConfirm),
            ),
          ],
        ),
  );
  if (confirmed != true || !context.mounted) return;

  ToastHelper.showInfo(context, l10n.registerDeleteRunning);
  try {
    await ref.read(accountNotifierProvider.notifier).deleteAccount();
    if (!context.mounted) return;
    ToastHelper.showSuccess(context, l10n.registerDeleteDone);
    context.go('/login');
  } catch (e) {
    if (!context.mounted) return;
    final message = e is RepositoryException ? e.message : e.toString();
    ToastHelper.showError(
      context,
      l10n.registerDeleteFailed(message.isEmpty ? l10n.commonUnknown : message),
    );
  }
}
