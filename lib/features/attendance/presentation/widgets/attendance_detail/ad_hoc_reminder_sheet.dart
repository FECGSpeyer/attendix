import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../../core/theme/app_colors.dart';

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
  final dateStr = parsed != null ? DateFormat('dd.MM.yyyy').format(parsed) : date;
  final type = (typeName?.isNotEmpty ?? false) ? typeName! : 'Termin';
  final time = (startTime?.isNotEmpty ?? false) ? ' um ${_hhmm(startTime!)} Uhr' : '';
  final info = (typeInfo?.isNotEmpty ?? false) ? ' ($typeInfo)' : '';
  final eventLine = '$type am $dateStr$time$info';
  final title = '🔔 Erinnerung: $eventLine';
  final message =
      (tenantLongName?.isNotEmpty ?? false) ? '$tenantLongName\n$eventLine' : eventLine;
  return (title: title, message: message);
}

String _hhmm(String time) => time.length >= 5 ? time.substring(0, 5) : time;

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
            Text('Erinnerung versenden', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text(
              'Die Erinnerung wird per App-Benachrichtigung und per E-Mail verschickt. '
              'Betreff und Nachricht können frei angepasst werden.',
              style: TextStyle(color: AppColors.medium),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _title,
              minLines: 1,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Betreff',
                hintText: 'z. B. 🔔 Erinnerung: Probe am 01.09.2026',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _message,
              minLines: 3,
              maxLines: 8,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Nachricht',
                hintText: 'Nachrichtentext',
                border: OutlineInputBorder(),
              ),
            ),
            if (widget.hasNeutralPersons)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _neutralOnly,
                onChanged: (v) => setState(() => _neutralOnly = v),
                title: const Text('Nur Personen ohne Status'),
                subtitle: const Text('Sendet nur an Personen, die noch keine Rückmeldung gegeben haben'),
              ),
            if (widget.attendanceLink != null) ...[
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.link, color: AppColors.medium),
                title: const Text('Link in der E-Mail', style: TextStyle(fontSize: 13, color: AppColors.medium)),
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
              label: const Text('Versenden'),
            ),
          ],
        ),
      ),
    );
  }
}
