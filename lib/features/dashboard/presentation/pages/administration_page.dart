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
        'Bitte eine Zahl größer 0 eingeben oder das Feld leeren (unbegrenzt).',
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
        bytes == null ? 'Speicher: unbegrenzt' : 'Speicherlimit: ${_fmtGb(gb!)} GB',
      );
    } else {
      final prev = _toGb(info?.maxBytes);
      _limitController.text = prev == null ? '' : _fmtGb(prev);
      ToastHelper.showError(context, 'Fehler beim Speichern');
    }
  }

  Future<void> _addChurch() async {
    final name = await DialogHelper.showTextInput(
      context,
      title: 'Gemeinde hinzufügen',
      hint: 'Name der Gemeinde',
      confirmText: 'Hinzufügen',
    );
    if (name == null || !mounted) return;
    if (name.trim().isEmpty) {
      ToastHelper.showWarning(context, 'Bitte gib gültige Werte ein.');
      return;
    }
    final id = await ref.read(churchNotifierProvider.notifier).createChurch(name.trim());
    if (!mounted) return;
    if (id != null) {
      ToastHelper.showSuccess(context, 'Die Gemeinde wurde erfolgreich hinzugefügt.');
    } else {
      ToastHelper.showError(context, 'Fehler beim Hinzufügen');
    }
  }

  Future<void> _rename(Church church) async {
    final name = await DialogHelper.showTextInput(
      context,
      title: 'Gemeinde umbenennen',
      initialValue: church.name,
      hint: 'Name der Gemeinde',
      confirmText: 'Speichern',
    );
    final trimmed = name?.trim() ?? '';
    if (trimmed.isEmpty || church.id == null || !mounted) return;
    final ok = await ref
        .read(administrationNotifierProvider.notifier)
        .renameChurch(church.id!, trimmed);
    if (!mounted) return;
    ok
        ? ToastHelper.showSuccess(context, 'Gemeinde umbenannt')
        : ToastHelper.showError(context, 'Fehler beim Umbenennen');
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
      ToastHelper.showError(context, 'Fehler beim Zusammenführen');
    } else if (pairs.length > 1) {
      ToastHelper.showSuccess(
        context,
        '$count Person(en) aktualisiert, ${pairs.length} Duplikat(e) entfernt',
      );
    } else {
      ToastHelper.showSuccess(context, 'Zusammengeführt: $count Person(en) aktualisiert');
    }
  }

  Future<void> _mergeManual(Church source, List<Church> churches) async {
    final targets = churches.where((c) => c.id != source.id).toList();
    if (targets.isEmpty) return;
    String? selected = targets.first.id;
    final targetId = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('„${source.name}“ zusammenführen mit...'),
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
              child: const Text('Abbrechen'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(selected),
              child: const Text('Zusammenführen'),
            ),
          ],
        ),
      ),
    );
    if (targetId == null || !mounted) return;
    final target = targets.firstWhere((c) => c.id == targetId);
    await _merge(
      [(targetId, source.id!)],
      title: 'Bestätigen',
      message:
          '„${source.name}“ wird gelöscht und alle Personen zu „${target.name}“ verschoben. Fortfahren?',
      confirm: 'Zusammenführen',
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
      appBar: AppBar(title: const Text('Administration')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          const _Header('Auswertung'),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: ListTile(
              leading: const Icon(Icons.analytics_outlined),
              title: const Text('Usage Dashboard'),
              trailing: const Icon(Icons.chevron_right, color: AppColors.medium),
              onTap: () => context.push('/dashboard'),
            ),
          ),
          const SizedBox(height: 16),
          _Header('Speicher Dateiablage: ${tenant?.longName ?? ''}'),
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
                    decoration: const InputDecoration(
                      labelText: 'Max. Speicher (GB)',
                      hintText: 'Unbegrenzt',
                      helperText: 'Leer lassen für unbegrenzt. Neue Instanzen starten mit 5 GB.',
                      helperMaxLines: 2,
                    ),
                    onSubmitted: (_) => _saveFilesLimit(),
                  ),
                ),
                if (storage.valueOrNull?.usedBytes != null)
                  ListTile(
                    title: const Text('Aktuell belegt'),
                    trailing: Text(
                      '${_fmtGb(_toGb(storage.value!.usedBytes)!)} GB',
                      style: const TextStyle(color: AppColors.medium),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _Header('Gemeinden (${churches.length})'),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            clipBehavior: Clip.antiAlias,
            child: churchesAsync.isLoading && churches.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : Column(
                    children: [
                      if (duplicates.isNotEmpty) ...[
                        Container(
                          color: AppColors.warning.withAlpha((0.25 * 255).round()),
                          child: ListTile(
                            leading: const Icon(Icons.warning_amber_outlined),
                            title: Text('${duplicates.length} Duplikat-Gruppe(n) gefunden'),
                            subtitle: const Text(
                              'Gemeinden mit gleichem Namen können zusammengeführt werden.',
                            ),
                          ),
                        ),
                        for (final g in duplicates)
                          ListTile(
                            title: Text(g.target.name),
                            subtitle: Text('${g.duplicates.length + 1}x vorhanden'),
                            trailing: Wrap(
                              spacing: 4,
                              children: [
                                for (final dup in g.duplicates)
                                  OutlinedButton.icon(
                                    icon: const Icon(Icons.merge_type, size: 16),
                                    label: const Text('Zusammenführen'),
                                    onPressed: saving
                                        ? null
                                        : () => _merge(
                                              [(g.target.id!, dup.id!)],
                                              title: 'Gemeinden zusammenführen',
                                              message:
                                                  '„${dup.name}“ wird in „${g.target.name}“ zusammengeführt. Alle Personen werden aktualisiert. Fortfahren?',
                                              confirm: 'Zusammenführen',
                                            ),
                                  ),
                              ],
                            ),
                          ),
                        ListTile(
                          leading: const Icon(Icons.merge_type, color: AppColors.warningDark),
                          title: const Text(
                            'Alle Duplikate zusammenführen',
                            style: TextStyle(color: AppColors.warningDark),
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
                                    title: 'Alle Duplikate zusammenführen',
                                    message:
                                        '${pairs.length} Duplikat(e) in ${duplicates.length} Gruppe(n) werden zusammengeführt. Fortfahren?',
                                    confirm: 'Alle zusammenführen',
                                  );
                                },
                        ),
                        const Divider(height: 1),
                      ],
                      ListTile(
                        title: const Text('Alle Gemeinden anzeigen'),
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
                                  tooltip: 'Gemeinde umbenennen',
                                  icon: const Icon(Icons.edit_outlined, color: AppColors.medium),
                                  onPressed: saving ? null : () => _rename(c),
                                ),
                                IconButton(
                                  tooltip: 'Zusammenführen',
                                  icon: const Icon(Icons.merge_type, color: AppColors.medium),
                                  onPressed: saving ? null : () => _mergeManual(c, churches),
                                ),
                              ],
                            ),
                          ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.add, color: AppColors.primary),
                        title: const Text(
                          'Gemeinde hinzufügen',
                          style: TextStyle(color: AppColors.primary),
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
