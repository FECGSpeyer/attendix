import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../../core/providers/files_providers.dart';
import '../../../core/providers/tenant_providers.dart';
import '../../../core/utils/error_message.dart';
import '../../../core/utils/person_matcher.dart';
import '../../../core/utils/toast_helper.dart';
import '../../../data/models/person/person.dart';
import '../../../data/models/tenant/tenant.dart';
import '../../../data/repositories/organisation_repository.dart';
import '../../../l10n/l10n.dart';

class PersonLinkMatch {
  PersonLinkMatch(this.match);
  final RankedMatch<Person> match;
  bool selected = true;
}

/// Group of a representative person and matching candidates across the org.
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

String linkReasonLabel(AppLocalizations l10n, String reason) => reason;

/// Canonical string key for an ignored link candidate pair.
String linkGroupKey(int a, int b) {
  final ids = ['$a', '$b']..sort();
  return ids.join('-');
}

/// Builds candidate link groups across organisation instances.
List<PersonLinkGroup> buildPersonLinkGroups(
  List<Person> allPersons,
  Set<String> ignoredKeys,
) {
  final candidates = allPersons
      .where((p) =>
          (p.globalPersonId?.isEmpty ?? true) &&
          (p.appId?.isEmpty ?? true) &&
          p.id != null)
      .toList();
  final seen = <int>{};
  final groups = <PersonLinkGroup>[];

  for (final player in candidates) {
    if (seen.contains(player.id)) continue;
    final others = candidates
        .where((p) => p.tenantId != player.tenantId && !seen.contains(p.id))
        .toList();
    final raw = rankCandidates<Person>(
      _toPersonLike(player),
      others,
      _toPersonLike,
      threshold: 0.85,
      prefixMode: false,
    );
    if (raw.isEmpty) continue;
    if (ignoredKeys.contains(linkGroupKey(player.id!, raw.first.candidate.id!))) {
      continue;
    }

    groups.add(PersonLinkGroup(player, raw.map(PersonLinkMatch.new).toList()));
    for (final m in raw) {
      seen.add(m.candidate.id!);
    }
    seen.add(player.id!);
  }
  return groups;
}

/// Loading, linking, and ignoring suggestions for `RdLinkPersonsPage`.
mixin LinkPersonsLogic<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  static const _storageKey = 'link-persons-ignored';

  List<PersonLinkGroup> groups = [];
  List<Tenant> tenants = [];
  final Set<String> _ignoredKeys = {};
  bool loading = true;
  int linkedCount = 0;

  int? _loadedTenantId;
  int _loadRun = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  /// Loads the suggestions again, e.g. after a group switch.
  void reload() {
    setState(() {
      loading = true;
      groups = [];
      tenants = [];
      linkedCount = 0;
    });
    _load();
  }

  Future<void> _load() async {
    final run = ++_loadRun;
    final tenantId = ref.read(currentTenantIdProvider);
    final organisationSettingsRepo =
        ref.read(organisationSettingsRepositoryWithTenantProvider);
    final orgRepo = ref.read(organisationRepositoryProvider);
    try {
      try {
        final prefs = await SharedPreferences.getInstance();
        _ignoredKeys.addAll(prefs.getStringList(_storageKey) ?? const []);
      } catch (_) {}

      final org = await organisationSettingsRepo.getCurrentOrganisation();
      if (org?.id == null) return;
      final loadedTenants = await orgRepo.getInstancesOfOrganisation(org!.id!);
      final persons = await orgRepo.getAllPersonsFromOrganisation(loadedTenants);
      if (run != _loadRun) return;
      tenants = loadedTenants;
      groups = buildPersonLinkGroups(persons, _ignoredKeys);
      _loadedTenantId = tenantId;
    } catch (e) {
      if (mounted && run == _loadRun) {
        ToastHelper.showError(
          context,
          context.l10n.settingsFlutterLoadFailed(friendlyErrorMessage(e)),
        );
      }
    } finally {
      if (mounted && run == _loadRun) setState(() => loading = false);
    }
  }

  String tenantName(int? tenantId) =>
      tenants.where((t) => t.id == tenantId).firstOrNull?.shortName ??
      '${tenantId ?? ''}';

  String formatBirthday(String? birthday) {
    if (birthday == null || birthday.isEmpty) return '–';
    final d = DateTime.tryParse(birthday);
    return d == null ? '–' : DateFormat(dateFmt()).format(d);
  }

  Future<void> link(PersonLinkGroup group) async {
    final selected =
        group.matches.where((m) => m.selected).map((m) => m.match.candidate).toList();
    if (selected.isEmpty) {
      ToastHelper.showWarning(context, context.l10n.linkPersonsSelectOne);
      return;
    }
    final all = [group.representative, ...selected];
    final ids = all.map((p) => p.id!).toList();
    final existingId = all
        .map((p) => p.globalPersonId)
        .firstWhere((id) => id?.isNotEmpty ?? false, orElse: () => null);
    final globalId = existingId ?? const Uuid().v4();
    if (_loadedTenantId == null ||
        ref.read(currentTenantIdProvider) != _loadedTenantId) {
      return;
    }
    try {
      await ref
          .read(organisationSettingsRepositoryWithTenantProvider)
          .setGlobalPersonId(ids, globalId);
      if (!mounted) return;
      setState(() {
        linkedCount += ids.length;
        groups.remove(group);
      });
      ToastHelper.showSuccess(context, context.l10n.linkPersonsLinked(ids.length));
    } catch (_) {
      if (mounted) ToastHelper.showError(context, context.l10n.linkPersonsFailed);
    }
  }

  Future<void> ignore(PersonLinkGroup group) async {
    _ignoredKeys.add(
      linkGroupKey(group.representative.id!, group.matches.first.match.candidate.id!),
    );
    setState(() => groups.remove(group));
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_storageKey, _ignoredKeys.toList());
    } catch (_) {}
  }
}
