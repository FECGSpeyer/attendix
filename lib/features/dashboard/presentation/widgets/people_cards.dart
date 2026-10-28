import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/dashboard_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/dashboard_utils.dart';
import '../../../../data/models/person/person.dart';
import 'dashboard_card.dart';
import '../../../../l10n/l10n.dart';
import '../../../../core/utils/error_message.dart';

/// Opens the person detail page (Ionic opens PersonPage as modal).
Future<void> _openPerson(BuildContext context, WidgetRef ref, Person? person) async {
  final id = person?.id;
  if (id == null) return;
  await context.push('/people/$id');
  // The person may have been changed (e.g. Problemfall gelöst).
  ref.invalidate(dashboardPersonsProvider);
}

/// "Geburtstage" — last and next 14 days, archived persons hidden.
class BirthdaysCard extends ConsumerWidget {
  const BirthdaysCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(dashboardBirthdaysProvider);
    return DashboardCard(
      icon: Icons.card_giftcard_outlined,
      title: context.l10n.homeDashboardBirthdays,
      subtitle: context.l10n.homeDashboardBirthdayRange,
      strip: DashStrips.birthday,
      child: async.when(
        loading: () => const DashLoading(),
        error: (e, _) => DashEmptyRow(icon: Icons.error_outline, text: context.l10n.homeDashboardFlutterLoadFailed(friendlyErrorMessage(e))),
        data: (entries) {
          if (entries.isEmpty) {
            return DashEmptyRow(
              icon: Icons.sentiment_satisfied_alt_outlined,
              text: context.l10n.homeDashboardNoBirthdays,
            );
          }
          final upcoming = entries.where((e) => e.daysOffset >= 0).toList();
          final past = entries.where((e) => e.daysOffset < 0).toList();
          return Column(
            children: [
              for (final e in upcoming) _row(context, ref, e),
              if (past.isNotEmpty) ...[
                DashDivider(context.l10n.homeDashboardRecently),
                for (final e in past) _row(context, ref, e),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _row(BuildContext context, WidgetRef ref, BirthdayEntry e) {
    final today = e.daysOffset == 0;
    final past = e.daysOffset < 0;
    return DashRow(
      onTap: () => _openPerson(context, ref, e.person),
      highlight: today ? DashTone.pink.bg(context) : null,
      dim: past,
      leading: DashTile.date(
        e.date,
        tone: past ? DashTone.muted : DashTone.pink,
        solid: today,
      ),
      title: '${e.person.firstName} ${e.person.lastName}',
      subtitle: '${DashboardUtils.weekday(e.date)} · ${DashboardUtils.birthdayAgeText(e)}',
      trailing: today
          ? DashChip(
              label: context.l10n.teamOrgTodayCap,
              tone: DashTone.pink,
              icon: Icons.auto_awesome,
              solid: true,
            )
          : DashMeta(DashboardUtils.relativeDays(e.date)),
    );
  }
}

/// "Mitglieder-Veränderungen" — joins/leaves of the last 60 days.
class MemberChangesCard extends ConsumerWidget {
  const MemberChangesCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(dashboardMemberChangesProvider);
    return DashboardCard(
      icon: Icons.people_outline,
      title: context.l10n.homeDashboardMemberChanges,
      subtitle: context.l10n.homeDashboardLast60Days,
      strip: DashStrips.members,
      child: async.when(
        loading: () => const DashLoading(),
        error: (e, _) => DashEmptyRow(icon: Icons.error_outline, text: context.l10n.homeDashboardFlutterLoadFailed(friendlyErrorMessage(e))),
        data: (changes) {
          if (changes.isEmpty) {
            return DashEmptyRow(
              icon: Icons.people_outline,
              text: context.l10n.homeDashboardNoChanges,
            );
          }
          return Column(
            children: [
              for (final c in changes)
                DashRow(
                  onTap: () => _openPerson(context, ref, c.person),
                  leading: DashTile.date(
                    c.date,
                    tone: c.joined ? DashTone.green : DashTone.red,
                  ),
                  title: '${c.person.firstName} ${c.person.lastName}',
                  subtitle: DashboardUtils.relativeDays(c.date),
                  trailing: DashChip(
                    label: c.joined
                        ? context.l10n.homeDashboardFlutterJoin
                        : context.l10n.homeDashboardFlutterExit,
                    tone: c.joined ? DashTone.green : DashTone.red,
                    icon: c.joined ? Icons.arrow_forward : Icons.arrow_back,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// "Abwesenheiten & Pausierungen" — last 4 weeks.
class AbsencesCard extends ConsumerWidget {
  const AbsencesCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(dashboardAbsencesProvider);
    return DashboardCard(
      icon: Icons.nightlight_outlined,
      title: context.l10n.homeDashboardAbsences,
      subtitle: context.l10n.homeDashboardLast4Weeks,
      strip: DashStrips.absences,
      child: async.when(
        loading: () => const DashLoading(),
        error: (e, _) => DashEmptyRow(icon: Icons.error_outline, text: context.l10n.homeDashboardFlutterLoadFailed(friendlyErrorMessage(e))),
        data: (entries) {
          if (entries.isEmpty) {
            return DashEmptyRow(
              icon: Icons.check_circle_outline,
              text: context.l10n.homeDashboardNoAbsences,
            );
          }
          return Column(
            children: [
              for (final e in entries)
                DashRow(
                  onTap: () => _openPerson(context, ref, e.person),
                  leading: _leading(e),
                  title: '${e.firstName} ${e.lastName}',
                  subtitle: DashboardUtils.absenceSubtitle(e),
                  trailing: DashChip(
                    label: e.isPause
                        ? context.l10n.homeDashboardFlutterPause
                        : context.l10n.commonStatusAbsent,
                    tone: e.isPause ? DashTone.muted : DashTone.orange,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _leading(AbsenceEntry e) {
    final from = DashboardUtils.parse(e.fromDate);
    if (from == null) {
      return const DashTile(tone: DashTone.muted, icon: Icons.pause);
    }
    return DashTile.date(from, tone: e.isPause ? DashTone.muted : DashTone.orange);
  }
}

/// "Problemfälle" — persons flagged as critical.
class CriticalPersonsCard extends ConsumerWidget {
  const CriticalPersonsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(dashboardCriticalPersonsProvider);
    return DashboardCard(
      icon: Icons.warning_amber_outlined,
      title: context.l10n.homeDashboardProblemCases,
      subtitle: context.l10n.homeDashboardCurrentProblemCases,
      strip: DashStrips.critical,
      child: async.when(
        loading: () => const DashLoading(),
        error: (e, _) => DashEmptyRow(icon: Icons.error_outline, text: context.l10n.homeDashboardFlutterLoadFailed(friendlyErrorMessage(e))),
        data: (persons) {
          if (persons.isEmpty) {
            return DashEmptyRow(
              icon: Icons.check_circle_outline,
              iconColor: AppColors.success,
              text: context.l10n.homeDashboardNoProblemCases,
            );
          }
          return Column(
            children: [
              for (final p in persons)
                DashRow(
                  onTap: () => _openPerson(context, ref, p),
                  leading: DashTile(
                    tone: DashTone.red,
                    main: DashboardUtils.initials(p),
                    smallMain: true,
                  ),
                  title: '${p.firstName} ${p.lastName}',
                  subtitle: DashboardUtils.criticalReasonText(p).isNotEmpty
                      ? DashboardUtils.criticalReasonText(p)
                      : context.l10n.peopleProblemCase,
                ),
            ],
          );
        },
      ),
    );
  }
}
