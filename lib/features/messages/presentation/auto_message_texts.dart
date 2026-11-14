import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/attendance/attendance.dart';
import '../../../data/models/auto_message/auto_message.dart';
import '../../../l10n/generated/app_localizations.dart';

/// Texts of "Automatische Nachrichten" whose Ionic keys are built at runtime
/// (`'autoMessages.status.' + s`, …).
extension AutoMessageTexts on AppLocalizations {
  String autoMessageStatus(int? status) => switch (status) {
    1 => autoMessagesStatus1,
    2 => autoMessagesStatus2,
    3 => autoMessagesStatus3,
    4 => autoMessagesStatus4,
    5 => autoMessagesStatus5,
    _ => autoMessagesStatus0,
  };

  String autoMessageTrigger(int status) => switch (status) {
    4 => autoMessagesTrigger4,
    3 => autoMessagesTrigger3,
    _ => autoMessagesTrigger0,
  };

  String autoMessageTriggerHint(int status) => switch (status) {
    4 => autoMessagesTriggerHint4,
    3 => autoMessagesTriggerHint3,
    _ => autoMessagesTriggerHint0,
  };

  String autoMessageTemplateName(String key) => switch (key) {
    'late' => autoMessagesTplNameLate,
    'noAnswer' => autoMessagesTplNameNoAnswer,
    'streak' => autoMessagesTplNameStreak,
    _ => autoMessagesTplNameAbsent,
  };

  String autoMessageTemplateHint(String key) => switch (key) {
    'late' => autoMessagesTplHintLate,
    'noAnswer' => autoMessagesTplHintNoAnswer,
    'streak' => autoMessagesTplHintStreak,
    _ => autoMessagesTplHintAbsent,
  };

  /// Template title with its placeholders kept as `{name}` (Ionic templateText).
  String autoMessageTemplateTitle(String key) => switch (key) {
    'late' => autoMessagesTplLateTitle('{vorname}'),
    'noAnswer' => autoMessagesTplNoAnswerTitle('{termin}'),
    'streak' => autoMessagesTplStreakTitle('{vorname}'),
    _ => autoMessagesTplAbsentTitle('{vorname}'),
  };

  /// Template body with its placeholders kept as `{name}`.
  String autoMessageTemplateBody(String key) => switch (key) {
    'late' => autoMessagesTplLateBody('{vorname}', '{termin}', '{datum}', '{instanz}'),
    'noAnswer' => autoMessagesTplNoAnswerBody('{vorname}', '{termin}', '{datum}', '{instanz}'),
    'streak' => autoMessagesTplStreakBody(
      '{vorname}',
      '{anzahl}',
      '{termin}',
      '{datum}',
      '{instanz}',
    ),
    _ => autoMessagesTplAbsentBody('{vorname}', '{termin}', '{datum}', '{instanz}'),
  };

  String autoMessageReason(String? code) => switch (code) {
    'sick' => autoMessagesReasonSick,
    'work' => autoMessagesReasonWork,
    'family' => autoMessagesReasonFamily,
    'forgot' => autoMessagesReasonForgot,
    _ => autoMessagesReasonOther,
  };

  String autoMessageResponseState(String state) => switch (state) {
    'accepted' => autoMessagesRespStateAccepted,
    'rejected' => autoMessagesRespStateRejected,
    _ => autoMessagesRespStatePending,
  };

  String autoMessageFrequencyHint(AutoMessageRule rule) => switch (rule.frequency) {
    AutoMessageFrequency.streak => autoMessagesFreqHintStreak(rule.frequencyCount),
    AutoMessageFrequency.window => autoMessagesFreqHintWindow(
      rule.frequencyDays,
      rule.frequencyCount,
    ),
    AutoMessageFrequency.each => autoMessagesFreqHintEach,
  };

  /// "2 Std. danach" / "30 Min. danach" (Ionic delayText).
  String autoMessageDelayText(int minutes) =>
      minutes % 60 == 0 ? autoMessagesDelayHours(minutes ~/ 60) : autoMessagesDelayMinutes(minutes);

  /// Select label: 0 → "Direkt nach Ende" (Ionic delayLabel).
  String autoMessageDelayLabel(int minutes) =>
      minutes == 0 ? autoMessagesDelayNone : autoMessageDelayText(minutes);

  /// One-line summary of a rule on the list page (Ionic summary()).
  String autoMessageRuleSummary(AutoMessageRule rule, List<AttendanceType> types) {
    final statuses = rule.statuses.map(autoMessageStatus).join(', ');
    final typeNames =
        (rule.typeIds?.isNotEmpty ?? false)
            ? rule.typeIds!
                .map((id) => types.where((t) => t.id == id).firstOrNull?.name)
                .whereType<String>()
                .join(', ')
            : autoMessagesAllTypes;
    final freq = switch (rule.frequency) {
      AutoMessageFrequency.streak => autoMessagesFreqStreakShort(rule.frequencyCount),
      AutoMessageFrequency.window => autoMessagesFreqWindowShort(
        rule.frequencyCount,
        rule.frequencyDays,
      ),
      AutoMessageFrequency.each => '',
    };
    return [
      statuses + (freq.isNotEmpty ? ', $freq' : ''),
      typeNames,
      autoMessageDelayText(rule.delayMinutes),
    ].join(' · ');
  }

  /// Chips of a rule on the list page (Ionic chips()).
  List<String> autoMessageRuleChips(AutoMessageRule rule) => [
    if (rule.channels.contains('push')) autoMessagesChipPush,
    if (rule.channels.contains('email')) autoMessagesChipEmail,
    if (rule.allowResponses) autoMessagesChipResponses,
    if (rule.copyResponsibles || rule.copyVoiceLeaders) autoMessagesChipCopy,
  ];
}

/// Ionic `.hint` under inset lists: 0.8rem, medium, line height 1.4.
class AutoMessageHint extends StatelessWidget {
  const AutoMessageHint(this.text, {super.key, this.trailing, this.center = false});

  final String text;
  final InlineSpan? trailing;
  final bool center;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 14),
      child: Text.rich(
        TextSpan(text: text, children: [if (trailing != null) trailing!]),
        textAlign: center ? TextAlign.center : TextAlign.start,
        style: const TextStyle(fontSize: 12.8, height: 1.4, color: AppColors.medium),
      ),
    );
  }
}

/// Ionic `ion-chip` for multi-select (outline + medium when off, primary
/// when on) – used for Termintypen, Gruppen, Platzhalter and Gründe.
class AutoMessageChip extends StatelessWidget {
  const AutoMessageChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.placeholder = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// EIB-23: the placeholder chips of the rule editor – `ion-chip
  /// outline="true" color="primary" class="ph"` (primary outline, monospace
  /// 0.8rem); [selected] is ignored.
  final bool placeholder;

  @override
  Widget build(BuildContext context) {
    if (placeholder) {
      return Material(
        color: Colors.transparent,
        shape: StadiumBorder(side: BorderSide(color: AppColors.primary.withValues(alpha: 0.32))),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12.8,
                color: AppColors.primary,
                fontFamily: 'Menlo',
                fontFamilyFallback: ['Courier New', 'Courier', 'monospace'],
              ),
            ),
          ),
        ),
      );
    }
    final color = selected ? AppColors.primary : AppColors.medium;
    return Material(
      color: selected ? AppColors.primary.withValues(alpha: 0.12) : Colors.transparent,
      shape: StadiumBorder(side: BorderSide(color: color.withValues(alpha: selected ? 0.0 : 0.5))),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Text(label, style: TextStyle(fontSize: 14, color: color)),
        ),
      ),
    );
  }
}

/// Wrap of [AutoMessageChip]s with the Ionic `.chips` margins.
class AutoMessageChipWrap extends StatelessWidget {
  const AutoMessageChipWrap({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
      child: Wrap(spacing: 8, runSpacing: 8, children: children),
    );
  }
}
