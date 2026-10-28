import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/church_providers.dart';
import '../../../../core/providers/dashboard_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/dialog_helper.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/church/church.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart'; // IOS_LOOK

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
    final name = await DialogHelper.showTextInput(
      context,
      title: context.l10n.adminAddChurch,
      hint: context.l10n.adminChurchName,
      confirmText: context.l10n.attendanceAdd,
    );
    if (name == null || !mounted) return;
    if (name.trim().isEmpty) {
      ToastHelper.showWarning(context, context.l10n.adminInvalidValues);
      return;
    }
    final id = await ref.read(churchNotifierProvider.notifier).createChurch(name.trim());
    if (!mounted) return;
    if (id != null) {
      ToastHelper.showSuccess(context, context.l10n.adminChurchAdded);
    } else {
      ToastHelper.showError(context, context.l10n.adminFlutterAddFailed);
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

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.adminTitle)),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _Header(context.l10n.adminEvaluation),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: ListTile(
              leading: const Icon(Icons.analytics_outlined),
              title: Text(context.l10n.usageTitle),
              trailing: const Icon(Icons.chevron_right, color: AppColors.medium),
              onTap: () => context.push('/dashboard'),
            ),
          ),
          const SizedBox(height: 16),
          _Header(context.l10n.adminStorageFor(tenant?.longName ?? '')),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: _limitController,
                    focusNode: _limitFocus,
                    enabled: !saving,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: context.l10n.adminMaxStorage,
                      hintText: context.l10n.adminUnlimited,
                      helperText: context.l10n.adminLimitHelper,
                      helperMaxLines: 2,
                    ),
                    onSubmitted: (_) => _saveFilesLimit(),
                  ),
                ),
                if (storage.valueOrNull?.usedBytes != null)
                  ListTile(
                    title: Text(context.l10n.adminCurrentlyUsed),
                    trailing: Text(
                      context.l10n.adminGb(_fmtGb(_toGb(storage.value!.usedBytes)!)),
                      style: const TextStyle(color: AppColors.medium),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _Header(context.l10n.adminChurchesCount(churches.length)),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            clipBehavior: Clip.antiAlias,
            child: churchesAsync.isLoading && churches.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(child: AppSpinner()),
                  )
                : Column(
                    children: [
                      if (duplicates.isNotEmpty) ...[
                        Container(
                          color: AppColors.warning.withAlpha((0.25 * 255).round()),
                          child: ListTile(
                            leading: const Icon(Icons.warning_amber_outlined),
                            title: Text(context.l10n.adminDuplicateGroups(duplicates.length)),
                            subtitle: Text(context.l10n.adminDuplicatesHint),
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
                                    icon: const Icon(Icons.merge_type, size: 16),
                                    label: Text(context.l10n.adminMerge),
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
                        ListTile(
                          leading: const Icon(Icons.merge_type, color: AppColors.warningDark),
                          title: Text(
                            context.l10n.adminMergeAllDuplicates,
                            style: const TextStyle(color: AppColors.warningDark),
                          ),
                          onTap: saving
                              ? null
                              : () {
                                  final pairs = [
                                    for (final g in duplicates)
                                      for (final d in g.duplicates) (g.target.id!, d.id!),
                                  ];
                                  _merge(
                                    pairs,
                                    title: context.l10n.adminMergeAllDuplicates,
                                    message: context.l10n
                                        .adminMergeAllMessage(pairs.length, duplicates.length),
                                    confirm: context.l10n.adminMergeAll,
                                  );
                                },
                        ),
                        const Divider(height: 1),
                      ],
                      ListTile(
                        title: Text(context.l10n.adminShowAllChurches),
                        trailing: Icon(
                          _showAllChurches ? Icons.expand_less : Icons.expand_more,
                        ),
                        onTap: () => setState(() => _showAllChurches = !_showAllChurches),
                      ),
                      if (_showAllChurches)
                        for (final c in churches)
                          ListTile(
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
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.add, color: AppColors.primary),
                        title: Text(
                          context.l10n.adminAddChurch,
                          style: const TextStyle(color: AppColors.primary),
                        ),
                        onTap: _addChurch,
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 6),
        child: Text(
          text,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: AppColors.medium,
                fontWeight: FontWeight.w600,
              ),
        ),
      );
}
