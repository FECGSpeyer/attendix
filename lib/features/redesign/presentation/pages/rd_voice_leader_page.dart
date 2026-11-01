import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/router/redesign_routes.dart';
import '../../../../core/theme/redesign/rd_theme.dart';
import '../../../../data/models/person/person.dart';
import '../../../../l10n/l10n.dart';
import '../../../voice_leader/data/providers/voice_leader_providers.dart';
import '../widgets/rd_widgets.dart';
import '../widgets/today/rd_today_common.dart' show RdInfoCard;

/// REDESIGN: "Meine Stimme" of Stimmführer (the old
/// `/settings/voice-leader` page in the new design): the members of the own
/// register with mail/phone and their coming absences.
class RdVoiceLeaderPage extends ConsumerWidget {
  const RdVoiceLeaderPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.rd;
    final l10n = context.l10n;
    final async = ref.watch(voiceGroupMembersProvider);
    final groupName = ref.watch(voiceGroupNameProvider).valueOrNull;
    // Like the old page: the Einteilung tag only when the group has the field.
    final hasEinteilung = ref.watch(
      currentTenantProvider.select((t) => t?.additionalFields?.any((f) => f.id == 'einteilung') ?? false),
    );
    final noProfile = ref.watch(currentPlayerProvider.select((v) => v.hasValue && v.value == null));
    final members = async.valueOrNull;

    final children = <Widget>[
      Align(
        alignment: Alignment.centerLeft,
        child: RdBackLink(
          label: MaterialLocalizations.of(context).backButtonTooltip,
          onTap: () => context.canPop() ? context.pop() : context.go(RedesignRoutes.today),
        ),
      ),
      const SizedBox(height: 4),
      Semantics(header: true, child: Text(l10n.voiceLeaderMyVoice, style: RdType.largeTitle(p))),
      if (members != null && !noProfile)
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            '${groupName ?? l10n.voiceLeaderFlutterVoiceGroup} · ${l10n.voiceLeaderFlutterMemberCount(members.length)}',
            style: RdType.meta(p, size: 15),
          ),
        ),
      const SizedBox(height: 16),
    ];

    if (members == null) {
      children.add(
        async.hasError
            ? RdInfoCard(
              text: l10n.voiceLeaderLoadFailed,
              icon: Icons.cloud_off_outlined,
              action: RdOutlineButton(
                label: l10n.redesignCommonRetry,
                onPressed: () => ref.invalidate(voiceGroupMembersProvider),
              ),
            )
            : RdInfoCard(text: l10n.redesignTodayLoading, loading: true),
      );
    } else if (noProfile) {
      children.add(RdInfoCard(text: l10n.voiceLeaderNoProfile, icon: Icons.person_off_outlined));
    } else if (members.isEmpty) {
      children.add(RdInfoCard(text: l10n.voiceLeaderNoMembers, icon: Icons.people_outline));
    } else {
      children.add(
        RdGroupedList(
          children: [
            for (final m in members)
              _VoiceMemberRow(key: ValueKey('rd-voice-${m.person.id}'), member: m, showEinteilung: hasEinteilung),
          ],
        ),
      );
    }

    return RdPage(
      onRefresh: () async {
        ref.invalidate(voiceGroupMembersProvider);
        ref.invalidate(voiceGroupNameProvider);
        try {
          await ref.read(voiceGroupMembersProvider.future);
        } catch (_) {
          // The page shows the error with "retry".
        }
      },
      children: children,
    );
  }
}

class _VoiceMemberRow extends StatelessWidget {
  const _VoiceMemberRow({super.key, required this.member, required this.showEinteilung});

  final VoiceGroupMember member;
  final bool showEinteilung;

  static Future<void> _launch(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) await launchUrl(uri);
    } catch (_) {
      // PWA may not support mailto:/tel: links.
    }
  }

  /// Like the old page: excused / late excused → late tone, absent → absent.
  static RdTone _tone(int status) => switch (status) {
    2 || 5 => RdTone.late,
    4 => RdTone.absent,
    _ => RdTone.excused,
  };

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final person = member.person;
    final name = person.fullName.trim();
    final einteilung = showEinteilung ? (person.additionalFields?['einteilung'])?.toString().trim() : null;
    final email = (person.email ?? '').trim();
    final phone = (person.phone ?? '').trim();
    final short = DateFormat.Md(currentIntlLocale());

    Widget contact(IconData icon, String text, String url) => InkWell(
      onTap: () => _launch(url),
      borderRadius: BorderRadius.circular(8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 32),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: p.link),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                text,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 14, color: p.link, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RdInitials(rdInitialsOf(name.isEmpty ? '?' : name)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(name, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: p.text)),
                    if (person.isLeader) const RdLeaderTag(),
                  ],
                ),
                // Like the Mitglieder rows: the Einteilung as grey line.
                if (einteilung != null && einteilung.isNotEmpty && einteilung != '-')
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(einteilung, style: RdType.meta(p, size: 13)),
                  ),
                const SizedBox(height: 4),
                if (email.isNotEmpty) contact(Icons.mail_outline, email, 'mailto:$email'),
                if (phone.isNotEmpty) contact(Icons.call_outlined, phone, 'tel:$phone'),
                if (email.isEmpty && phone.isEmpty) Text(l10n.voiceLeaderNoContact, style: RdType.meta(p, size: 13)),
                if (member.upcomingAbsences.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(l10n.voiceLeaderUpcomingAbsences, style: RdType.meta(p, size: 13)),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final a in member.upcomingAbsences)
                        RdPill(
                          '${short.format(a.date)}${a.typeName != null ? ' ${a.typeName}' : ''}',
                          tone: _tone(a.status),
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
