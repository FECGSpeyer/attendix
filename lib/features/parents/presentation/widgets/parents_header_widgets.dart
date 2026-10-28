import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/enums.dart';
import '../../../../core/providers/song_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/providers/user_preferences_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/person/person.dart';
import '../../../../data/models/song/song.dart';
import '../../../../data/models/tenant/tenant.dart';
import '../../data/providers/parents_providers.dart';
import '../../../../l10n/l10n.dart';

/// App bar title of the parents page (Ionic: tenant switcher when the user
/// has more than one tenant, otherwise the tenant's long name).
class ParentsTenantTitle extends ConsumerWidget {
  const ParentsTenantTitle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenant = ref.watch(currentTenantProvider);
    final tenants = ref.watch(userTenantsProvider).valueOrNull ?? const <Tenant>[];
    final name = tenant?.longName ?? context.l10n.tabsEvents;

    if (tenants.length <= 1) return Text(name);

    return PopupMenuButton<Tenant>(
      tooltip: context.l10n.settingsSwitchTenant,
      onSelected: (t) => _switchTenant(context, ref, t),
      itemBuilder: (_) => [
        for (final t in tenants)
          PopupMenuItem(
            value: t,
            child: Row(
              children: [
                Expanded(child: Text(t.longName)),
                if (t.id == tenant?.id)
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      context.l10n.signoutCurrent,
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ),
              ],
            ),
          ),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: Text(name, overflow: TextOverflow.ellipsis)),
          const Icon(Icons.expand_more),
        ],
      ),
    );
  }

  Future<void> _switchTenant(
    BuildContext context,
    WidgetRef ref,
    Tenant tenant,
  ) async {
    final current = ref.read(currentTenantProvider);
    if (tenant.id == null || tenant.id == current?.id) return;
    try {
      final prefsNotifier = ref.read(userPreferencesNotifierProvider.notifier);
      await ref.read(currentTenantProvider.notifier).setTenantLocal(tenant);
      final tenantUser = await ref.read(currentTenantUserProvider.future);
      final role = Role.fromValue(tenantUser?.role ?? Role.none.value);
      if (context.mounted) context.go(role.defaultRoute);
      prefsNotifier.updateCurrentTenantId(tenant.id!);
    } catch (e) {
      if (context.mounted) {
        ToastHelper.showError(context, context.l10n.selfServiceFlutterSwitchFailed(e));
      }
    }
  }
}

/// Welcome card (Ionic parents page): "Shalom!", kids with attendance
/// percentage and the "Aktuelle Werke anzeigen" button.
class ParentsWelcomeCard extends ConsumerWidget {
  const ParentsWelcomeCard({super.key, required this.kids});

  final List<Person> kids;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (kids.isEmpty) return const SizedBox.shrink();
    final songs = ref.watch(currentSongsProvider).valueOrNull ?? const [];
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.all(AppDimensions.paddingM),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.selfServiceShalom,
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppDimensions.paddingXS),
            Text(
              context.l10n.selfServiceYouManageKids(kids.length),
            ),
            const SizedBox(height: AppDimensions.paddingS),
            Wrap(
              spacing: AppDimensions.paddingS,
              runSpacing: AppDimensions.paddingS,
              children: [
                for (final kid in kids)
                  _KidChip(
                    name: kid.firstName,
                    stats: kid.id != null
                        ? ref.watch(childStatsProvider(kid.id!))
                        : null,
                  ),
              ],
            ),
            if (songs.isNotEmpty) ...[
              const SizedBox(height: AppDimensions.paddingS),
              TextButton(
                onPressed: () => showCurrentSongsSheet(context, songs),
                child: Text(context.l10n.selfServiceShowCurrentSongs),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _KidChip extends StatelessWidget {
  const _KidChip({required this.name, this.stats});

  final String name;
  final ChildStats? stats;

  @override
  Widget build(BuildContext context) {
    final perc = stats?.percentage;
    final color = perc == null
        ? AppColors.medium
        : perc >= 75
            ? AppColors.success
            : perc >= 50
                ? AppColors.warning
                : AppColors.danger;
    return Chip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(name),
          if (perc != null) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$perc%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

String _formatSongDate(String date) {
  final parsed = DateTime.tryParse(date);
  if (parsed == null) return date;
  return DateFormat('EEE, ${dateFmt()}', currentIntlLocale()).format(parsed);
}

/// "Aktuelle Werke" sheet: songs of upcoming Termine grouped by date.
Future<void> showCurrentSongsSheet(
  BuildContext context,
  List<({String date, List<SongHistory> history})> groups,
) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => FractionallySizedBox(
      heightFactor: groups.length > 1 ? 0.8 : 0.6,
      child: Scaffold(
        appBar: AppBar(
          title: Text(sheetContext.l10n.signoutCurrentSongs),
          automaticallyImplyLeading: false,
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(sheetContext).pop(),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(AppDimensions.paddingM),
          children: [
            for (final group in groups) ...[
              Padding(
                padding: const EdgeInsets.symmetric(
                    vertical: AppDimensions.paddingS),
                child: Text(
                  _formatSongDate(group.date),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Card(
                margin: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (final his in group.history)
                      if (his.song != null)
                        ListTile(
                          title: Text(
                            '${his.song!.number ?? ''}. ${his.song!.name}',
                          ),
                          subtitle: (his.conductorName ?? '').isNotEmpty
                              ? Text(sheetContext.l10n.signoutConductor(his.conductorName!))
                              : null,
                          trailing: (his.song!.link ?? '').isNotEmpty
                              ? const Icon(Icons.download_outlined)
                              : null,
                          onTap: (his.song!.link ?? '').isNotEmpty
                              ? () => launchUrl(
                                    Uri.parse(his.song!.link!),
                                    mode: LaunchMode.externalApplication,
                                  )
                              : null,
                        ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

/// Legend sheet of the parents page (Ionic legend modal).
Future<void> showParentsLegendSheet(BuildContext context) {
  Widget pill(String text, Color color) => Container(
        width: 150,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 12),
          overflow: TextOverflow.ellipsis,
        ),
      );

  Widget row(String pillText, Color color, String label) => ListTile(
        dense: true,
        leading: pill(pillText, color),
        title: Text(label),
      );

  final l10n = context.l10n;
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(l10n.signoutLegend,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            // Ionic parents legend (pill / label pairs).
            row(l10n.signoutLegendAccepted, AttendanceStatus.present.color,
                l10n.signoutLegendAcceptedPresent),
            row(l10n.commonStatusExcused, AttendanceStatus.excused.color,
                l10n.commonStatusExcused),
            row(l10n.commonStatusAbsent, AttendanceStatus.absent.color,
                l10n.commonStatusAbsent),
            row(l10n.signoutLegendLate, AttendanceStatus.late.color,
                l10n.commonStatusLate),
            row(l10n.signoutLegendLateReported, AttendanceStatus.lateExcused.color,
                l10n.signoutLegendLateReportedExcused),
            row(l10n.commonStatusNeutral, AttendanceStatus.neutral.color,
                l10n.commonStatusNeutral),
            const SizedBox(height: AppDimensions.paddingM),
          ],
        ),
      ),
    ),
  );
}
