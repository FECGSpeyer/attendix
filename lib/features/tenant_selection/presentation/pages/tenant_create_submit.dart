part of 'tenant_create_page.dart';

/// Catalog selection, tenant creation submission, and account deletion helper
/// for [TenantCreatePage].
extension _TenantCreateSubmit on _TenantCreatePageState {
  Future<void> _chooseCatalog() async {
    if (_busy) return;
    final type = _selectedType;
    final accountId = ref.read(currentAuthUserIdProvider);
    final tenantId = ref.read(currentTenantIdProvider);
    _update(() => _isChoosingCatalog = true);
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
      _update(() {
        _catalogSelection = selection.drafts;
        _catalogPresetId = selection.presetId;
      });
    } finally {
      if (mounted) _update(() => _isChoosingCatalog = false);
    }
  }

  Future<void> _choosePreset(CatalogPreset? preset) async {
    if (_busy || _creationComplete) return;
    if (preset?.id == _catalogPresetId && (preset != null || _catalogSelection.isEmpty)) {
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
    _update(() => _isChoosingCatalog = true);
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
        _update(() {
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
        for (final entry in preset.entries.where((entry) => entry.selectedByDefault))
          draftFromPresetEntry(entry, languageCode: language),
      ];
      _update(() {
        _catalogSelection =
            change == CatalogPresetChange.merge ? mergeCatalogDrafts(_catalogSelection, additions) : additions;
        _catalogPresetId = preset.id;
      });
    } finally {
      if (mounted) _update(() => _isChoosingCatalog = false);
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
        _selectedType == 'general' ? <CatalogGroupDraft>[] : List<CatalogGroupDraft>.of(_catalogSelection);
    bool sameAccount() => mounted && ref.read(currentAuthUserIdProvider) == userId;
    bool beforeSelection() => sameAccount() && ref.read(currentTenantIdProvider) == startingTenantId;
    _update(() => _isLoading = true);

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
      bool selectedTenant() => sameAccount() && ref.read(currentTenantIdProvider) == newTenant.id;
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
        ToastHelper.showSuccess(context, context.l10n.redesignTenantsNewCreated);
        GoRouter.of(context).go(RedesignRoutes.today);
      }
    } catch (e) {
      if (mounted && beforeSelection()) {
        ToastHelper.showError(context, context.l10n.registerCreateFailed(friendlyErrorMessage(e)));
      }
    } finally {
      if (mounted) _update(() => _isLoading = false);
    }
  }
}

/// Account deletion dialog for users without any group ([RdNoGroupPage]).
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
