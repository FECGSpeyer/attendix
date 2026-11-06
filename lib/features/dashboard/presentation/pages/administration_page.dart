import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/church_providers.dart';
import '../../../../core/providers/dashboard_providers.dart';
import '../../../../core/providers/redesign_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/router/redesign_routes.dart';
import '../../../../core/theme/redesign/rd_theme.dart';
import '../../../redesign/presentation/widgets/event/rd_form_widgets.dart';
import '../../../redesign/presentation/widgets/rd_widgets.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/dialog_helper.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/church/church.dart';
import '../../../../l10n/l10n.dart';
import 'package:attendix/shared/widgets/layout/ionic_ios.dart' show IonTranslucentAppBar, IonContentTopInset;
import '../../../../shared/widgets/adaptive/adaptive.dart';
import '../../../settings/presentation/widgets/ion_condense.dart';
import '../../../settings/presentation/widgets/settings_list.dart';
import 'package:attendix/shared/widgets/layout/ios_tab_bar.dart';

const int _gb = 1024 * 1024 * 1024;

double? _toGb(int? bytes) =>
    bytes == null ? null : (bytes / _gb * 100).round() / 100;

String _fmtGb(double v) {
  final s = v.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '');
  return s.replaceAll('.', ',');
}

/// Super-developer administration (Ionic `settings/administration`):
/// usage dashboard link, Dateiablage quota of the current tenant and
/// Gemeinden-Verwaltung (rename / merge duplicates / add).
class AdministrationPage extends ConsumerStatefulWidget {
  const AdministrationPage({super.key});

  @override
  ConsumerState<AdministrationPage> createState() => _AdministrationPageState();
}

class _AdministrationPageState extends ConsumerState<AdministrationPage> {
  final _limitController = TextEditingController();
  final _limitFocus = FocusNode();
  bool _limitInitialized = false;
  bool _showAllChurches = false;

  @override
  void initState() {
    super.initState();
    _limitFocus.addListener(() {
      if (!_limitFocus.hasFocus) _saveFilesLimit();
    });
  }

  @override
  void dispose() {
    _limitController.dispose();
    _limitFocus.dispose();
    super.dispose();
  }

  Future<void> _saveFilesLimit() async {
    final info = ref.read(tenantStorageInfoProvider).valueOrNull;
    final raw = _limitController.text.trim().replaceAll(',', '.');
    final gb = raw.isEmpty ? null : double.tryParse(raw);
    if (raw.isNotEmpty && (gb == null || gb <= 0)) {
      ToastHelper.showWarning(
        context,
        context.l10n.adminInvalidLimit,
      );
      return;
    }
    final bytes = gb == null ? null : (gb * _gb).round();
    if (bytes == info?.maxBytes) return;

    final ok = await ref
        .read(administrationNotifierProvider.notifier)
        .setFilesMaxBytes(bytes);
    if (!mounted) return;
    if (ok) {
      ToastHelper.showSuccess(
        context,
        bytes == null
            ? context.l10n.adminStorageUnlimited
            : context.l10n.adminStorageLimit(_fmtGb(gb!)),
      );
    } else {
      final prev = _toGb(info?.maxBytes);
      _limitController.text = prev == null ? '' : _fmtGb(prev);
      ToastHelper.showError(context, context.l10n.svcSaveFailed);
    }
  }

  Future<void> _addChurch() async {
    // Ionic openChurchInput: an empty name keeps the alert open with
    // "Bitte gib gültige Werte ein.", creating shows a blocking loading
    // overlay, errors are shown with their message.
    final name = await DialogHelper.showTextInput(
      context,
      title: context.l10n.adminAddChurch,
      hint: context.l10n.adminChurchName,
      confirmText: context.l10n.attendanceAdd,
      validator: (v) => v.trim().isEmpty ? context.l10n.adminInvalidValues : null,
    );
    if (name == null || !mounted) return;
    final navigator = Navigator.of(context, rootNavigator: true);
    showAppDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PopScope(
        canPop: false,
        child: Center(child: AppSpinner()),
      ),
    );
    final notifier = ref.read(churchNotifierProvider.notifier);
    final id = await notifier.createChurch(name.trim());
    navigator.pop();
    if (!mounted) return;
    if (id != null) {
      ToastHelper.showSuccess(context, context.l10n.adminChurchAdded);
    } else {
      ToastHelper.showError(
        context,
        friendlyErrorMessage(ref.read(churchNotifierProvider).error),
      );
    }
  }

  Future<void> _rename(Church church) async {
    final name = await DialogHelper.showTextInput(
      context,
      title: context.l10n.adminRenameChurch,
      initialValue: church.name,
      hint: context.l10n.adminChurchName,
      confirmText: context.l10n.commonSave,
    );
    final trimmed = name?.trim() ?? '';
    if (trimmed.isEmpty || church.id == null || !mounted) return;
    final ok = await ref
        .read(administrationNotifierProvider.notifier)
        .renameChurch(church.id!, trimmed);
    if (!mounted) return;
    ok
        ? ToastHelper.showSuccess(context, context.l10n.adminChurchRenamed)
        : ToastHelper.showError(context, context.l10n.adminRenameFailed);
  }

  Future<void> _merge(List<(String, String)> pairs, {required String title, required String message, required String confirm}) async {
    final confirmed = await DialogHelper.showConfirmation(
      context,
      title: title,
      message: message,
      confirmText: confirm,
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;
    final count = await ref.read(administrationNotifierProvider.notifier).mergeChurches(pairs);
    if (!mounted) return;
    if (count == null) {
      ToastHelper.showError(context, context.l10n.adminMergeFailed);
    } else if (pairs.length > 1) {
      ToastHelper.showSuccess(
        context,
        context.l10n.adminMergedAll(count, pairs.length),
      );
    } else {
      ToastHelper.showSuccess(context, context.l10n.adminMerged(count));
    }
  }

  Future<void> _mergeManual(Church source, List<Church> churches) async {
    final targets = churches.where((c) => c.id != source.id).toList();
    if (targets.isEmpty) return;
    String? selected = targets.first.id;
    final targetId = await showAppDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AppAlertDialog(
          title: Text(context.l10n.adminMergeWith(source.name)),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final c in targets)
                  RadioListTile<String>(
                    value: c.id!,
                    groupValue: selected,
                    title: Text(c.name),
                    onChanged: (v) => setDialogState(() => selected = v),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.l10n.commonCancel),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(selected),
              child: Text(context.l10n.adminMerge),
            ),
          ],
        ),
      ),
    );
    if (targetId == null || !mounted) return;
    final target = targets.firstWhere((c) => c.id == targetId);
    await _merge(
      [(targetId, source.id!)],
      title: context.l10n.commonConfirm,
      message: context.l10n.adminMergeMoveMessage(source.name, target.name),
      confirm: context.l10n.adminMerge,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tenant = ref.watch(currentTenantProvider);
    final storage = ref.watch(tenantStorageInfoProvider);
    final churchesAsync = ref.watch(churchesProvider);
    final saving = ref.watch(administrationNotifierProvider).isLoading;

    if (!_limitInitialized && storage.hasValue) {
      final gb = _toGb(storage.value!.maxBytes);
      _limitController.text = gb == null ? '' : _fmtGb(gb);
      _limitInitialized = true;
    }

    final churches = churchesAsync.valueOrNull ?? const <Church>[];
    final duplicates = findChurchDuplicates(churches);

    void mergeAll() {
      final pairs = [
        for (final g in duplicates)
          for (final d in g.duplicates) (g.target.id!, d.id!),
      ];
      _merge(
        pairs,
        title: context.l10n.adminMergeAllDuplicates,
        message: context.l10n.adminMergeAllMessage(pairs.length, duplicates.length),
        confirm: context.l10n.adminMergeAll,
      );
    }

    if (ref.watch(redesignEnabledProvider)) {
      return _buildBeta(context, storage, churchesAsync, churches, duplicates, saving, mergeAll);
    }
    final ios = ionIsIos(context);
    // UX_SETTINGS (WAVE 8): administration.page.html — condense title,
    // inset lists (Auswertung / Speicher / Gemeinden) on the light page.
    return IonCondense(builder: (context, collapsed) => Scaffold(
      // IOS_R6: Ionic `ion-content fullscreen` under the translucent header
      extendBodyBehindAppBar: ionIsIos(context),
      // IOS_R6: `ion-header translucent` (blur once condensed)
      appBar: IonTranslucentAppBar(condensed: collapsed, child: AppBar(title: IonCondenseTitle(context.l10n.adminTitle, collapsed: collapsed))),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, ios ? 0 : 8, 16, scrollEndPadding(context, base: 24)),
        children: [
          const IonContentTopInset(),
          IonLargeTitle(context.l10n.adminTitle, padding: const EdgeInsets.only(bottom: 4)),
          if (ios) const SizedBox(height: 16),
          SettingsListSection(
            title: context.l10n.adminEvaluation,
            children: [
              SettingsListTile(
                icon: Icons.analytics_outlined,
                title: context.l10n.usageTitle,
                onTap: () => context.push('/dashboard'),
              ),
            ],
          ),
          SettingsListSection(
            title: context.l10n.adminStorageFor(tenant?.longName ?? ''),
            icons: false,
            children: [
              IonStackedField(
                label: context.l10n.adminMaxStorage,
                hint: context.l10n.adminUnlimited,
                helper: context.l10n.adminLimitHelper,
                builder: (decoration) => TextField(
                  controller: _limitController,
                  focusNode: _limitFocus,
                  enabled: !saving,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: decoration.copyWith(helperMaxLines: 2),
                  onSubmitted: (_) => _saveFilesLimit(),
                ),
              ),
              if (storage.valueOrNull?.usedBytes != null)
                ListTile(
                  title: Text(context.l10n.adminCurrentlyUsed),
                  trailing: IonNote(
                    context.l10n.adminGb(_fmtGb(_toGb(storage.value!.usedBytes)!)),
                  ),
                ),
            ],
          ),
          SettingsListSection(
            title: context.l10n.adminChurchesCount(churches.length),
            icon: Icons.home_outlined,
            children: churchesAsync.isLoading && churches.isEmpty
                ? const [
                    Padding(
                      padding: EdgeInsets.all(20),
                      child: Center(child: AppSpinner()),
                    ),
                  ]
                : [
                    if (duplicates.isNotEmpty) ...[
                      // ion-item color="warning"
                      Material(
                        color: ios
                            ? AppColors.warning
                            : AppColors.warning.withAlpha((0.25 * 255).round()),
                        child: ListTile(
                          leading: const Icon(Icons.warning_amber_outlined, color: Colors.black),
                          title: Text(
                            context.l10n.adminDuplicateGroups(duplicates.length),
                            style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            context.l10n.adminDuplicatesHint,
                            style: const TextStyle(color: Colors.black87),
                          ),
                        ),
                      ),
                      for (final g in duplicates)
                        ListTile(
                          title: Text(g.target.name),
                          subtitle: Text(context.l10n.adminTimesPresent(g.duplicates.length + 1)),
                          trailing: Wrap(
                            spacing: 4,
                            children: [
                              for (final dup in g.duplicates)
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.warningDark,
                                    side: const BorderSide(color: AppColors.warning),
                                  ),
                                  icon: const Icon(Icons.merge_type, size: 16),
                                  label: IonButtonLabel(context.l10n.adminMerge),
                                  onPressed: saving
                                      ? null
                                      : () => _merge(
                                            [(g.target.id!, dup.id!)],
                                            title: context.l10n.adminMergeChurches,
                                            message: context.l10n
                                                .adminMergeMessage(dup.name, g.target.name),
                                            confirm: context.l10n.adminMerge,
                                          ),
                                ),
                            ],
                          ),
                        ),
                      SettingsListTile(
                        icon: Icons.merge_type,
                        color: AppColors.warningDark,
                        detail: false,
                        title: context.l10n.adminMergeAllDuplicates,
                        onTap: saving ? null : mergeAll,
                      ),
                    ],
                    // ion-accordion: header item color="light"
                    Material(
                      color: ios ? Theme.of(context).scaffoldBackgroundColor : Colors.transparent,
                      child: Column(
                        children: [
                          ListTile(
                            title: Text(context.l10n.adminShowAllChurches),
                            trailing: Icon(
                              _showAllChurches ? Icons.expand_less : Icons.expand_more,
                              color: ios ? IonIos.text(context).withValues(alpha: 0.5) : null,
                            ),
                            onTap: () => setState(() => _showAllChurches = !_showAllChurches),
                          ),
                          if (_showAllChurches)
                            for (final c in churches)
                              Material(
                                color: ios ? IonIos.itemBackground(context) : Colors.transparent,
                                child: ListTile(
                                  leading: const Icon(Icons.home_outlined, color: AppColors.medium),
                                  title: Text(c.name),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        tooltip: context.l10n.adminRenameChurch,
                                        icon: const Icon(Icons.edit_outlined, color: AppColors.medium),
                                        onPressed: saving ? null : () => _rename(c),
                                      ),
                                      IconButton(
                                        tooltip: context.l10n.adminMerge,
                                        icon: const Icon(Icons.merge_type, color: AppColors.medium),
                                        onPressed: saving ? null : () => _mergeManual(c, churches),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                        ],
                      ),
                    ),
                    SettingsListTile(
                      icon: Icons.add,
                      color: AppColors.primary,
                      detail: false,
                      title: context.l10n.adminAddChurch,
                      onTap: _addChurch,
                    ),
                  ],
          ),
        ],
      ),
    ));
  }

  /// REDESIGN (E4): small sheet to set the storage limit (same check and
  /// write as the old field).
  Future<void> _editLimitBeta() async {
    await showRdSheet<void>(
      context,
      Builder(
        builder: (ctx) {
          final p = ctx.rd;
          final l10n = ctx.l10n;
          // Scrolls inside the sheet so "Speichern" stays reachable above
          // the keyboard on short screens.
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.viewInsetsOf(ctx).bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(header: true, child: Text(l10n.adminMaxStorage, style: RdType.section(p))),
                const SizedBox(height: 12),
                RdGroupedList(
                  children: [
                    RdFieldRow(
                      label: l10n.redesignAdminLimitGb,
                      child: TextField(
                        controller: _limitController,
                        autofocus: true,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: rdInputDecoration(p, l10n.adminUnlimited),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(l10n.adminLimitHelper, style: RdType.meta(p, size: 12)),
                ),
                const SizedBox(height: 16),
                RdPrimaryButton(
                  label: l10n.commonSave,
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    await _saveFilesLimit();
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _churchMoreBeta(Church c, List<Church> churches) async {
    final l10n = context.l10n;
    final action = await showAppActionSheet<int>(
      context,
      title: c.name,
      actions: [
        AppActionSheetAction(value: 0, icon: Icons.edit_outlined, label: l10n.adminRenameChurch),
        AppActionSheetAction(value: 1, icon: Icons.merge_type, label: l10n.adminMerge),
      ],
    );
    if (!mounted) return;
    if (action == 0) await _rename(c);
    if (action == 1) await _mergeManual(c, churches);
  }

  /// REDESIGN (E4): settings page – Nutzungs-Dashboard, storage limit as a
  /// value with a small sheet, duplicates as a hint card, Gemeinden as list.
  Widget _buildBeta(
    BuildContext context,
    AsyncValue<TenantStorageInfo> storage,
    AsyncValue<List<Church>> churchesAsync,
    List<Church> churches,
    List<ChurchDuplicateGroup> duplicates,
    bool saving,
    VoidCallback mergeAll,
  ) {
    final p = context.rd;
    final l10n = context.l10n;
    final tenant = ref.watch(currentTenantProvider);
    final maxGb = _toGb(storage.valueOrNull?.maxBytes);
    final usedBytes = storage.valueOrNull?.usedBytes;
    return RdPage(
      children: [
        RdBackLink(
          label: l10n.redesignTabMe,
          onTap: () => context.canPop() ? context.pop() : context.go(RedesignRoutes.me),
        ),
        Semantics(header: true, child: Text(l10n.adminTitle, style: RdType.largeTitle(p))),
        const SizedBox(height: 16),
        RdGroupedList(
          children: [
            RdListRow(
              leading: RdRowIcon(Icons.analytics_outlined, color: p.primary, background: p.soft),
              title: l10n.usageTitle,
              onTap: () => context.push('/dashboard'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        RdGroupLabel(l10n.adminStorageFor(tenant?.longName ?? '')),
        RdGroupedList(
          children: [
            RdListRow(
              title: l10n.adminMaxStorage,
              value: maxGb == null ? l10n.adminUnlimited : l10n.adminGb(_fmtGb(maxGb)),
              onTap: saving || !storage.hasValue ? null : _editLimitBeta,
            ),
            if (usedBytes != null)
              RdListRow(
                title: l10n.adminCurrentlyUsed,
                value: l10n.adminGb(_fmtGb(_toGb(usedBytes)!)),
                showChevron: false,
              ),
          ],
        ),
        const SizedBox(height: 20),
        RdGroupLabel(l10n.adminChurchesCount(churches.length)),
        if (churchesAsync.isLoading && churches.isEmpty)
          const Padding(padding: EdgeInsets.all(20), child: Center(child: AppSpinner()))
        else ...[
          if (duplicates.isNotEmpty) ...[
            RdCard(
              color: p.lateSoft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: p.late),
                      const SizedBox(width: 8),
                      Expanded(child: Text(l10n.adminDuplicateGroups(duplicates.length), style: RdType.cardTitle(p))),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(l10n.adminDuplicatesHint, style: RdType.meta(p, size: 14)),
                  const SizedBox(height: 8),
                  RdTextLink(label: l10n.adminMergeAllDuplicates, onTap: saving ? () {} : mergeAll),
                ],
              ),
            ),
            const SizedBox(height: 12),
            RdGroupedList(
              children: [
                // One row per duplicate, each merges exactly one pair with
                // its own confirmation (like the old buttons).
                for (final g in duplicates)
                  for (final dup in g.duplicates)
                    RdListRow(
                      title: dup.name,
                      subtitle: '→ ${g.target.name}',
                      showChevron: false,
                      trailing: RdTextLink(
                        label: l10n.adminMerge,
                        onTap: () {
                          if (saving) return;
                          _merge(
                            [(g.target.id!, dup.id!)],
                            title: l10n.adminMergeChurches,
                            message: l10n.adminMergeMessage(dup.name, g.target.name),
                            confirm: l10n.adminMerge,
                          );
                        },
                      ),
                    ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          RdGroupedList(
            children: [
              Semantics(
                expanded: _showAllChurches,
                child: RdListRow(
                  title: l10n.adminShowAllChurches,
                  showChevron: false,
                  trailing: Icon(_showAllChurches ? Icons.expand_less : Icons.expand_more, color: p.text2),
                  onTap: () => setState(() => _showAllChurches = !_showAllChurches),
                ),
              ),
              if (_showAllChurches)
                for (final c in churches)
                  RdListRow(
                    leading: RdRowIcon(Icons.home_outlined, color: p.text2, background: p.track),
                    title: c.name,
                    showChevron: false,
                    trailing: IconButton(
                      tooltip: l10n.redesignTenantsMore(c.name),
                      icon: Icon(Icons.more_horiz, color: p.text2),
                      onPressed: saving ? null : () => _churchMoreBeta(c, churches),
                    ),
                  ),
              RdListRow(
                leading: RdRowIcon(Icons.add, color: p.primary, background: p.soft),
                title: l10n.adminAddChurch,
                titleColor: p.link,
                showChevron: false,
                onTap: _addChurch,
              ),
            ],
          ),
        ],
      ],
    );
  }
}

