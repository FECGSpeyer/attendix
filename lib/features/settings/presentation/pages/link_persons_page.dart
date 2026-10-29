import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/files_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/person_matcher.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/person/person.dart';
import '../../../../data/models/tenant/tenant.dart';
import '../../../../data/repositories/organisation_repository.dart';
import '../../../../l10n/l10n.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart'; // IOS_LOOK
import 'package:attendix/shared/widgets/layout/ios_tab_bar.dart'; // IOS_SHELL2

class PersonLinkMatch {
  PersonLinkMatch(this.match);
  final RankedMatch<Person> match;
  bool selected = true;
}

/// Gruppe aus Repräsentant und möglichen Treffern
class PersonLinkGroup {
  PersonLinkGroup(this.representative, this.matches);
  final Person representative;
  final List<PersonLinkMatch> matches;
}

PersonLike _toPersonLike(Person p) => PersonLike(
      firstName: p.firstName,
      lastName: p.lastName,
      email: p.email,
      appId: p.appId,
      globalPersonId: p.globalPersonId,
      birthday: p.birthday,
    );

/// Localized label of a [MatchReason] (Ionic `linkPersons.reason.*`).
// MatchReason values are already localized (core l10n).
String _reasonLabel(AppLocalizations l10n, String reason) => reason;

String linkGroupKey(int a, int b) {
  final ids = [a, b]..sort();
  return ids.join('-');
}

/// Baut Vorschlagsgruppen (wie LinkPersonsPage.buildGroups in Ionic)
List<PersonLinkGroup> buildPersonLinkGroups(List<Person> allPersons, Set<String> ignoredKeys) {
  final candidates = allPersons
      .where((p) => (p.globalPersonId?.isEmpty ?? true) && (p.appId?.isEmpty ?? true) && p.id != null)
      .toList();
  final seen = <int>{};
  final groups = <PersonLinkGroup>[];

  for (final player in candidates) {
    if (seen.contains(player.id)) continue;
    final others = candidates.where((p) => p.tenantId != player.tenantId && !seen.contains(p.id)).toList();
    final raw = rankCandidates<Person>(
      _toPersonLike(player),
      others,
      _toPersonLike,
      threshold: 0.85,
      prefixMode: false,
    );
    if (raw.isEmpty) continue;
    if (ignoredKeys.contains(linkGroupKey(player.id!, raw.first.candidate.id!))) continue;

    groups.add(PersonLinkGroup(player, raw.map(PersonLinkMatch.new).toList()));
    for (final m in raw) {
      seen.add(m.candidate.id!);
    }
    seen.add(player.id!);
  }
  return groups;
}

/// Personen verknüpfen (Ionic: settings/general/link-persons)
class LinkPersonsPage extends ConsumerStatefulWidget {
  const LinkPersonsPage({super.key});

  @override
  ConsumerState<LinkPersonsPage> createState() => _LinkPersonsPageState();
}

class _LinkPersonsPageState extends ConsumerState<LinkPersonsPage> {
  static const _storageKey = 'link-persons-ignored';

  List<PersonLinkGroup> _groups = [];
  List<Tenant> _tenants = [];
  final Set<String> _ignoredKeys = {};
  bool _loading = true;
  int _linkedCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final organisationSettingsRepo = ref.read(organisationSettingsRepositoryWithTenantProvider);
    try {
      try {
        final prefs = await SharedPreferences.getInstance();
        _ignoredKeys.addAll(prefs.getStringList(_storageKey) ?? const []);
      } catch (_) {}

      final org = await organisationSettingsRepo.getCurrentOrganisation();
      if (org?.id == null) return;
      final orgRepo = ref.read(organisationRepositoryProvider);
      _tenants = await orgRepo.getInstancesOfOrganisation(org!.id!);
      final persons = await orgRepo.getAllPersonsFromOrganisation(_tenants);
      _groups = buildPersonLinkGroups(persons, _ignoredKeys);
    } catch (e) {
      if (mounted) ToastHelper.showError(context, context.l10n.settingsFlutterLoadFailed(friendlyErrorMessage(e)));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _tenantName(int? tenantId) =>
      _tenants.where((t) => t.id == tenantId).firstOrNull?.shortName ?? '${tenantId ?? ''}';

  String _formatBirthday(String? birthday) {
    if (birthday == null || birthday.isEmpty) return '–';
    final d = DateTime.tryParse(birthday);
    return d == null ? '–' : DateFormat(dateFmt()).format(d);
  }

  Future<void> _link(PersonLinkGroup group) async {
    final selected = group.matches.where((m) => m.selected).map((m) => m.match.candidate).toList();
    if (selected.isEmpty) {
      ToastHelper.showWarning(context, context.l10n.linkPersonsSelectOne);
      return;
    }
    final all = [group.representative, ...selected];
    final ids = all.map((p) => p.id!).toList();
    final existingId = all.map((p) => p.globalPersonId).firstWhere((id) => id?.isNotEmpty ?? false, orElse: () => null);
    final globalId = existingId ?? const Uuid().v4();
    try {
      await ref.read(organisationSettingsRepositoryWithTenantProvider).setGlobalPersonId(ids, globalId);
      if (!mounted) return;
      setState(() {
        _linkedCount += ids.length;
        _groups.remove(group);
      });
      ToastHelper.showSuccess(context, context.l10n.linkPersonsLinked(ids.length));
    } catch (_) {
      if (mounted) ToastHelper.showError(context, context.l10n.linkPersonsFailed);
    }
  }

  Future<void> _ignore(PersonLinkGroup group) async {
    _ignoredKeys.add(linkGroupKey(group.representative.id!, group.matches.first.match.candidate.id!));
    setState(() => _groups.remove(group));
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_storageKey, _ignoredKeys.toList());
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.linkPersonsTitle)),
      body: _loading
          ? const Center(child: AppSpinner())
          : _groups.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppDimensions.paddingL),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_circle_outline, color: AppColors.success, size: 48),
                        const SizedBox(height: AppDimensions.paddingS),
                        Text(context.l10n.linkPersonsNoMore),
                        if (_linkedCount > 0)
                          Text(context.l10n.linkPersonsLinkedCount(_linkedCount),
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                )
              : ListView(
                  padding: EdgeInsets.fromLTRB(AppDimensions.paddingM, AppDimensions.paddingM, AppDimensions.paddingM, scrollEndPadding(context, base: AppDimensions.paddingM)),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppDimensions.paddingM),
                      child: Text(
                        context.l10n.linkPersonsIntro,
                        style: const TextStyle(color: AppColors.medium),
                      ),
                    ),
                    for (final group in [..._groups]) _buildGroupCard(group),
                  ],
                ),
    );
  }

  Widget _buildGroupCard(PersonLinkGroup group) {
    final rep = group.representative;
    return Card(
      margin: const EdgeInsets.only(bottom: AppDimensions.paddingM),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${rep.firstName} ${rep.lastName}', style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('${_tenantName(rep.tenantId)} · ${_formatBirthday(rep.birthday)}',
                style: const TextStyle(color: AppColors.medium)),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppDimensions.paddingXS),
              child: Center(child: Icon(Icons.merge_type, color: AppColors.medium)),
            ),
            for (final m in group.matches)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: m.selected,
                onChanged: (v) => setState(() => m.selected = v ?? false),
                title: Text('${m.match.candidate.firstName} ${m.match.candidate.lastName}'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${_tenantName(m.match.candidate.tenantId)} · ${_formatBirthday(m.match.candidate.birthday)}'),
                    const SizedBox(height: 2),
                    Chip(
                      label: Text(_reasonLabel(context.l10n, m.match.reason), style: const TextStyle(fontSize: 11)),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ],
                ),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(onPressed: () => _ignore(group), child: IonButtonLabel(context.l10n.linkPersonsIgnore)),
                const SizedBox(width: AppDimensions.paddingS),
                ElevatedButton(onPressed: () => _link(group), child: IonButtonLabel(context.l10n.linkPersonsLink)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
