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
import '../../../redesign/presentation/widgets/event/rd_form_widgets.dart';
import '../../../redesign/presentation/widgets/rd_widgets.dart';
import '../../../instruments/data/catalog_import.dart';
import '../../../instruments/data/catalog_selection.dart';
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
  List<CatalogGroupDraft> _catalogSelection = const [];

  @override
  void initState() {
    super.initState();
    _shortNameController.addListener(_onFieldChanged);
    _longNameController.addListener(_onFieldChanged);
    _mainGroupNameController.addListener(_onFieldChanged);
  }

  void _onFieldChanged() => setState(() {});

  @override
  void dispose() {
    _shortNameController.removeListener(_onFieldChanged);
    _longNameController.removeListener(_onFieldChanged);
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
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/tenants');
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final texts = TenantTypeTexts.of(_selectedType, l10n);
    final textStyle = TextStyle(fontSize: 17, color: p.text);
    Widget hint(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
      child: Text(text, style: RdType.meta(p, size: 13)),
    );
    Widget field(
      String label,
      TextEditingController controller,
      String placeholder, {
      int? maxLength,
      String? key,
    }) => RdFieldRow(
      label: label,
      child: TextField(
        key: key == null ? null : Key(key),
        controller: controller,
        enabled: !_isLoading,
        maxLength: maxLength,
        textCapitalization: TextCapitalization.sentences,
        textInputAction: TextInputAction.next,
        style: textStyle,
        decoration: rdInputDecoration(p, placeholder).copyWith(counterText: ''),
      ),
    );
    return PopScope(
      canPop: !_isLoading,
      child: Scaffold(
        backgroundColor: p.bg,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              RdFormTopBar(
                title: l10n.redesignTenantsNewTitle,
                cancel: l10n.redesignCommonCancel,
                submit: l10n.redesignTenantsNewSubmit,
                saving: _isLoading,
                onCancel: !_isLoading ? _close : null,
                onSubmit:
                    _isLoading || _creationComplete
                        ? null
                        : () =>
                            _isComplete
                                ? _createTenant()
                                : ToastHelper.showError(
                                  context,
                                  l10n.redesignTenantsNewMissing,
                                ),
              ),
              Expanded(
                child: RdFormBody(
                  children: [
                    RdGroupLabel(l10n.redesignTenantsNewType),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final type in const [
                          'choir',
                          'orchestra',
                          'general',
                        ])
                          RdChoiceChip(
                            label:
                                type == 'general'
                                    ? l10n.redesignTenantsTypeGeneral
                                    : TenantTypeTexts.of(type, l10n).label,
                            selected: _selectedType == type,
                            onTap:
                                _isLoading
                                    ? null
                                    : () => setState(() {
                                      if (_selectedType != type) {
                                        _catalogSelection = const [];
                                      }
                                      _selectedType = type;
                                    }),
                          ),
                      ],
                    ),
                    hint(texts.help),
                    const SizedBox(height: 20),
                    RdGroupedList(
                      children: [
                        field(
                          l10n.redesignTenantsNewName,
                          _longNameController,
                          texts.namePlaceholder,
                          maxLength: 50,
                          key: 'rd-tenant-new-name',
                        ),
                        field(
                          l10n.redesignTenantsNewShort,
                          _shortNameController,
                          texts.shortPlaceholder,
                          key: 'rd-tenant-new-short',
                        ),
                      ],
                    ),
                    hint(
                      '${l10n.redesignTenantsNewNameHint} ${l10n.redesignTenantsNewShortHint}',
                    ),
                    const SizedBox(height: 20),
                    RdGroupLabel(l10n.redesignTenantsNewMain),
                    RdGroupedList(
                      children: [
                        field(
                          l10n.redesignTenantsNewMainName,
                          _mainGroupNameController,
                          texts.mainGroupPlaceholder,
                          key: 'rd-tenant-new-main',
                        ),
                      ],
                    ),
                    hint(l10n.redesignTenantsNewMainHint(_selectedType)),
                    if (_selectedType != 'general') ...[
                      const SizedBox(height: 20),
                      RdGroupLabel(l10n.catalogSetupTitle),
                      RdGroupedList(
                        children: [
                          RdListRow(
                            key: const Key('rd-tenant-catalog'),
                            title: l10n.catalogSetupChoose,
                            subtitle:
                                _catalogSelection.isEmpty
                                    ? l10n.catalogSetupNone
                                    : l10n.catalogSetupCount(
                                      _catalogSelection.length,
                                    ),
                            onTap: _isLoading ? null : _chooseCatalog,
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _chooseCatalog() async {
    final type = _selectedType;
    final accountId = ref.read(currentAuthUserIdProvider);
    final tenantId = ref.read(currentTenantIdProvider);
    final selection = await showInstrumentCatalogSheet(
      context,
      tenantType: type,
      initialSelection: _catalogSelection,
    );
    if (!mounted ||
        selection == null ||
        _selectedType != type ||
        ref.read(currentAuthUserIdProvider) != accountId ||
        ref.read(currentTenantIdProvider) != tenantId) {
      return;
    }
    setState(() => _catalogSelection = selection);
  }

  Future<void> _createTenant() async {
    if (_isLoading || _creationComplete) return;
    if (!_isComplete) {
      ToastHelper.showError(context, context.l10n.registerFillAllToast);
      return;
    }

    final userId = ref.read(currentAuthUserIdProvider);
    if (userId == null) return;
    final startingTenantId = ref.read(currentTenantIdProvider);
    final selection = List<CatalogGroupDraft>.of(_catalogSelection);
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
