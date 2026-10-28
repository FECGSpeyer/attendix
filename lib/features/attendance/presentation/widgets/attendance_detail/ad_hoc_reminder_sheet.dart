import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/utils/date_helper.dart';
import '../../../../../l10n/l10n.dart';

/// Result of the "Erinnerung versenden" sheet.
class AdHocReminderResult {
  const AdHocReminderResult({
    required this.title,
    required this.message,
    required this.neutralOnly,
  });

  final String title;
  final String message;
  final bool neutralOnly;
}

/// Default subject/message of an ad-hoc reminder (Ionic sendAdHocReminder).
///
/// Subject: "🔔 Erinnerung: {Typ} am {dd.MM.yyyy}[ um {hh:mm} Uhr][ (typeInfo)]"
/// Message: "{tenant long name}\n{event line}" (or just the event line).
({String title, String message}) adHocReminderDefaults({
  required String? typeName,
  required String date,
  String? startTime,
  String? typeInfo,
  String? tenantLongName,
}) {
  final parsed = DateTime.tryParse(date);
  final l10n = l10nWithoutContext;
  final dateStr = parsed != null ? DateFormat(dateFmt()).format(parsed) : date;
  final type = (typeName?.isNotEmpty ?? false) ? typeName! : l10n.attendanceEventFallback;
  final time = (startTime?.isNotEmpty ?? false) ? l10n.attendanceAtTime(DateHelper.hhmm(startTime!)) : '';
  final info = (typeInfo?.isNotEmpty ?? false) ? ' ($typeInfo)' : '';
  final eventLine = '${l10n.attendanceEventOnDate(type, dateStr)}$time$info';
  final title = l10n.attendanceReminderTitle(eventLine);
  final message =
      (tenantLongName?.isNotEmpty ?? false) ? '$tenantLongName\n$eventLine' : eventLine;
  return (title: title, message: message);
}


/// Link to the Termin that is added to the e-mail.
String adHocReminderLink(int attendanceId, int tenantId) =>
    'https://attendix.de/open-attendance?id=$attendanceId&tenantId=$tenantId';

/// Shows the ad-hoc reminder editor (Ionic AdHocReminderModalComponent).
Future<AdHocReminderResult?> showAdHocReminderSheet(
  BuildContext context, {
  required String defaultTitle,
  required String defaultMessage,
  String? attendanceLink,
  bool hasNeutralPersons = false,
}) {
  return showModalBottomSheet<AdHocReminderResult>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: _AdHocReminderForm(
        defaultTitle: defaultTitle,
        defaultMessage: defaultMessage,
        attendanceLink: attendanceLink,
        hasNeutralPersons: hasNeutralPersons,
      ),
    ),
  );
}

class _AdHocReminderForm extends StatefulWidget {
  const _AdHocReminderForm({
    required this.defaultTitle,
    required this.defaultMessage,
    required this.attendanceLink,
    required this.hasNeutralPersons,
  });

  final String defaultTitle;
  final String defaultMessage;
  final String? attendanceLink;
  final bool hasNeutralPersons;

  @override
  State<_AdHocReminderForm> createState() => _AdHocReminderFormState();
}

class _AdHocReminderFormState extends State<_AdHocReminderForm> {
  late final TextEditingController _title = TextEditingController(text: widget.defaultTitle);
  late final TextEditingController _message = TextEditingController(text: widget.defaultMessage);
  bool _neutralOnly = false;

  @override
  void dispose() {
    _title.dispose();
    _message.dispose();
    super.dispose();
  }

  bool get _canSend => _title.text.trim().isNotEmpty || _message.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(context.l10n.attendanceSendReminder, style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              context.l10n.attendanceReminderInfo,
              style: const TextStyle(color: AppColors.medium),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _title,
              minLines: 1,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: context.l10n.attendanceSubject,
                hintText: context.l10n.attendanceSubjectPlaceholder,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _message,
              minLines: 3,
              maxLines: 8,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: context.l10n.attendanceMessage,
                hintText: context.l10n.attendanceMessagePlaceholder,
                border: const OutlineInputBorder(),
              ),
            ),
            if (widget.hasNeutralPersons)
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _neutralOnly,
                onChanged: (v) => setState(() => _neutralOnly = v),
                title: Text(context.l10n.attendanceOnlyNeutral),
                subtitle: Text(context.l10n.attendanceOnlyNeutralHint),
              ),
            if (widget.attendanceLink != null) ...[
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.link, color: AppColors.medium),
                title: Text(context.l10n.attendanceEmailLink, style: const TextStyle(fontSize: 13, color: AppColors.medium)),
                subtitle: SelectableText(widget.attendanceLink!),
              ),
            ],
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _canSend
                  ? () => Navigator.of(context).pop(AdHocReminderResult(
                        title: _title.text,
                        message: _message.text,
                        neutralOnly: _neutralOnly,
                      ))
                  : null,
              icon: const Icon(Icons.notifications_outlined),
              label: Text(context.l10n.attendanceSend),
            ),
          ],
        ),
      ),
    );
  }
}
