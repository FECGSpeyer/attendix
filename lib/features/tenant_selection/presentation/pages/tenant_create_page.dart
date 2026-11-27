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

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/design_theme.dart';
import '../../../attendance/presentation/widgets/event/form_widgets.dart';
import '../../../../shared/widgets/components/components.dart';
import '../../../settings/presentation/widgets/manage/settings_sheets.dart'
    show showRdTextSheet;
import '../../../instruments/data/catalog_import.dart';
import '../../../instruments/data/catalog_selection.dart';
import '../../../instruments/data/instrument_presets.dart';
import '../../../instruments/presentation/widgets/instrument_catalog_sheet.dart';

part 'tenant_create_steps.dart';
part 'tenant_create_submit.dart';

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

  void _update(VoidCallback fn) => setState(fn);

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
              _buildHeader(context),
              Expanded(child: _buildStepBody(context)),
              _buildFooter(context),
            ],
          ),
        ),
      ),
    );
  }
}
