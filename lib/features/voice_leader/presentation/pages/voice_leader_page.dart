import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/person/person.dart';
import '../../data/providers/voice_leader_providers.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart'; // IOS_LOOK

/// Voice Leader page - shows members of the same voice group
class VoiceLeaderPage extends ConsumerWidget {
  const VoiceLeaderPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(voiceGroupMembersProvider);
    final groupNameAsync = ref.watch(voiceGroupNameProvider);

    return Scaffold(
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
          loading: () => const Center(child: AppSpinner()),
          error: (error, stack) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: AppColors.danger),
                const SizedBox(height: AppDimensions.paddingM),
                Text(
                  context.l10n.voiceLeaderLoadFailed,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppDimensions.paddingS),
                Text(
                  error.toString(),
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppDimensions.paddingL),
                ElevatedButton(
                  onPressed: () => ref.invalidate(voiceGroupMembersProvider),
                  child: Text(context.l10n.messagesRetry),
                ),
              ],
            ),
          ),
          data: (members) {
            if (members.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.group_off_outlined,
                      size: 64,
                      color: AppColors.medium,
                    ),
                    const SizedBox(height: AppDimensions.paddingM),
                    Text(
                      context.l10n.voiceLeaderNoMembers,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppDimensions.paddingS),
                    Text(
                      context.l10n.voiceLeaderFlutterNoGroup,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.medium,
                          ),
                    ),
                  ],
                ),
              );
            }

            final groupName = groupNameAsync.valueOrNull ?? context.l10n.voiceLeaderFlutterVoiceGroup;

            return ListView(
              padding: const EdgeInsets.all(AppDimensions.paddingM),
              children: [
                // Group header
                _GroupHeader(
                  groupName: groupName,
                  memberCount: members.length,
                ),
                const SizedBox(height: AppDimensions.paddingM),

                // Members list
                Card(
                  margin: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (int i = 0; i < members.length; i++) ...[
                        _MemberTile(member: members[i]),
                        if (i < members.length - 1)
                          const Divider(height: 1, indent: 72),
                      ],
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

/// Group header showing name and member count
class _GroupHeader extends StatelessWidget {
  const _GroupHeader({
    required this.groupName,
    required this.memberCount,
  });

  final String groupName;
  final int memberCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
          ),
          child: const Icon(
            Icons.people,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: AppDimensions.paddingM),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                groupName,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              Text(
                context.l10n.voiceLeaderFlutterMemberCount(memberCount),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.medium,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Member tile showing person info and upcoming absences
class _MemberTile extends StatelessWidget {
  const _MemberTile({required this.member});

  final VoiceGroupMember member;

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final person = member.person;
    final absences = member.upcomingAbsences;

    return Padding(
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.primaryLight,
            backgroundImage: person.img != null ? NetworkImage(person.img!) : null,
            child: person.img == null
                ? Text(
                    person.initials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: AppDimensions.paddingM),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name row with badges
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        person.fullName,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                    if (person.isLeader)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          context.l10n.voiceLeaderSfShort,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 4),

                // Contact info
                if (person.email != null && person.email!.isNotEmpty)
                  InkWell(
                    onTap: () => _launchUrl('mailto:${person.email}'),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.email_outlined,
                            size: 14,
                            color: AppColors.medium,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              person.email!,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.primary,
                                  ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                if (person.phone != null && person.phone!.isNotEmpty)
                  InkWell(
                    onTap: () => _launchUrl('tel:${person.phone}'),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.phone_outlined,
                            size: 14,
                            color: AppColors.medium,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            person.phone!,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppColors.primary,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),

                if ((person.email == null || person.email!.isEmpty) &&
                    (person.phone == null || person.phone!.isEmpty))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.contact_mail_outlined,
                          size: 14,
                          color: AppColors.medium,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          context.l10n.voiceLeaderNoContact,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.medium,
                              ),
                        ),
                      ],
                    ),
                  ),

                // Upcoming absences
                if (absences.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      ...absences.take(5).map((absence) {
                        return _AbsenceChip(absence: absence);
                      }),
                      if (absences.length > 5)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.medium.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            context.l10n.voiceLeaderFlutterMoreCount(absences.length - 5),
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.medium,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Chip showing an upcoming absence
class _AbsenceChip extends StatelessWidget {
  const _AbsenceChip({required this.absence});

  final UpcomingAbsence absence;

  Color get _chipColor {
    switch (absence.status) {
      case 2: // excused
        return AppColors.warning;
      case 4: // absent
        return AppColors.danger;
      case 5: // late_excused
        return AppColors.warning;
      default:
        return AppColors.medium;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat(dateFmt(DateFmtKind.dayMonth));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: _chipColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: _chipColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Text(
        '${dateFormat.format(absence.date)}${absence.typeName != null ? ' ${absence.typeName}' : ''}',
        style: TextStyle(
          fontSize: 11,
          color: _chipColor,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
