import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/person/person.dart';
import '../../data/providers/voice_leader_providers.dart';
import '../../../../l10n/l10n.dart';
import '../../../people/presentation/widgets/ion/ion_widgets.dart'; // UX_PEOPLE

/// Voice Leader page - shows members of the same voice group.
///
/// UX_PEOPLE: Ionic settings/voice-leader — `ion-content color="light"`,
/// light group header (icon, name, member count), inset ion-list with
/// 48px avatars, contact links and upcoming absence badges.
class VoiceLeaderPage extends ConsumerWidget {
  const VoiceLeaderPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(voiceGroupMembersProvider);
    final groupNameAsync = ref.watch(voiceGroupNameProvider);

    return Scaffold(
      backgroundColor: ionLightColor(context),
      appBar: AppBar(
        title: Text(context.l10n.voiceLeaderMyVoice),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(voiceGroupMembersProvider);
          ref.invalidate(voiceGroupNameProvider);
          await ref.read(voiceGroupMembersProvider.future);
        },
        child: membersAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(32),
            child: Align(
              alignment: Alignment.topCenter,
              child: CircularProgressIndicator(),
            ),
          ),
          error: (error, stack) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              IonNoData(
                icon: Icons.error_outline,
                label: context.l10n.voiceLeaderLoadFailed,
                message: error.toString(),
                actions: [
                  (
                    context.l10n.messagesRetry,
                    () => ref.invalidate(voiceGroupMembersProvider),
                  ),
                ],
              ),
            ],
          ),
          data: (members) {
            final groupName = groupNameAsync.valueOrNull ??
                context.l10n.voiceLeaderFlutterVoiceGroup;

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: AppDimensions.paddingL),
              children: [
                _GroupHeader(groupName: groupName, memberCount: members.length),
                if (members.isEmpty)
                  // Ionic .no-data-message
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
                    child: Column(
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 48,
                          color: AppColors.medium.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          context.l10n.voiceLeaderNoMembers,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.medium),
                        ),
                      ],
                    ),
                  )
                else
                  // ion-list [inset]="true"
                  Container(
                    margin: const EdgeInsets.all(16),
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: ionContentBackground(context),
                      borderRadius: BorderRadius.circular(ionIsIos(context) ? 10 : 4),
                    ),
                    child: Column(
                      children: [
                        for (var i = 0; i < members.length; i++)
                          _MemberTile(
                            member: members[i],
                            last: i == members.length - 1,
                          ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Ionic `.group-header`: light background, primary people icon, bold
/// group name and grey member count.
class _GroupHeader extends StatelessWidget {
  const _GroupHeader({
    required this.groupName,
    required this.memberCount,
  });

  final String groupName;
  final int memberCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: ionLightColor(context),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Icon(Icons.people_outline, size: 24, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  groupName,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                Text(
                  context.l10n.voiceLeaderFlutterMemberCount(memberCount),
                  style: const TextStyle(fontSize: 13.6, color: AppColors.medium),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Ionic `.person-item`: avatar (48px), bold name with "SF"/Einteilung
/// badges, mail/phone links and the upcoming absences.
class _MemberTile extends StatelessWidget {
  const _MemberTile({required this.member, required this.last});

  final VoiceGroupMember member;
  final bool last;

  Future<void> _launchUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    } catch (_) {
      // PWA may not support mailto:/tel: links
    }
  }

  static const _smallBadge = TextStyle(fontSize: 10.4, fontWeight: FontWeight.w700);

  Widget _contactLink(IconData icon, String text, String url) {
    return InkWell(
      onTap: () => _launchUrl(url),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14.4, color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final person = member.person;
    final absences = member.upcomingAbsences;
    final einteilung = person.additionalFields?['einteilung'];
    final hasEmail = person.email != null && person.email!.isNotEmpty;
    final hasPhone = person.phone != null && person.phone!.isNotEmpty;
    final dateFormat = DateFormat(dateFmt(DateFmtKind.dayMonth));

    return IonItem(
      lines: !last,
      start: IonAvatar(url: person.img, size: 48),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                Text(
                  person.fullName,
                  style: IonText.h2(context).copyWith(fontWeight: FontWeight.w700),
                ),
                if (person.isLeader)
                  IonBadge(
                    text: context.l10n.voiceLeaderSfShort,
                    color: AppColors.primary,
                  ),
                if (einteilung is String && einteilung.isNotEmpty)
                  IonBadge(text: einteilung, color: AppColors.medium),
              ],
            ),
            const SizedBox(height: 4),
            if (hasEmail) _contactLink(Icons.mail_outline, person.email!, 'mailto:${person.email}'),
            if (hasEmail && hasPhone) const SizedBox(height: 4),
            if (hasPhone) _contactLink(Icons.call_outlined, person.phone!, 'tel:${person.phone}'),
            if (!hasEmail && !hasPhone)
              Text(
                context.l10n.voiceLeaderNoContact,
                style: const TextStyle(fontSize: 13.6, color: AppColors.medium),
              ),
            if (absences.isNotEmpty)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.only(top: 8),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: ionLineColor(context))),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.voiceLeaderUpcomingAbsences,
                      style: const TextStyle(fontSize: 12.8, color: AppColors.medium),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        for (final absence in absences)
                          DefaultTextStyle.merge(
                            style: _smallBadge,
                            child: IonBadge(
                              text: '${dateFormat.format(absence.date)}'
                                  '${absence.typeName != null ? ' ${absence.typeName}' : ''}',
                              color: _absenceColor(absence.status),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Ionic getAbsenceColor: excused/late excused → warning, absent →
  /// danger, otherwise medium.
  static Color _absenceColor(int status) {
    switch (status) {
      case 2:
      case 5:
        return AppColors.warning;
      case 4:
        return AppColors.danger;
      default:
        return AppColors.medium;
    }
  }
}
