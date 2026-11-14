import 'package:flutter/material.dart';
import 'package:attendix/shared/widgets/dialogs/ion_sheet.dart';
import 'package:attendix/core/theme/redesign/rd_theme.dart';
import 'package:attendix/core/theme/app_icons.dart';
import 'package:intl/intl.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/utils/date_helper.dart';
import '../../../../../l10n/l10n.dart';
import '../../../../../shared/widgets/adaptive/adaptive_platform.dart';
import '../../../../../shared/widgets/adaptive/ion_button_label.dart';
import '../../../../people/presentation/widgets/ion/ion_widgets.dart' show IonText, ionLineColor;
import '../../../../../shared/widgets/layout/ion_stacked_field.dart';

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
  if (context.rdSkin == null) {
    // Ionic: modalController.create({ breakpoints: [0, 0.75, 1],
    // initialBreakpoint: 0.75 }).
    return showIonSheet<AdHocReminderResult>(
      context,
      breakpoints: const [0, 0.75, 1],
      initialBreakpoint: 0.75,
      builder: (ctx, controller) => _AdHocReminderForm(
        defaultTitle: defaultTitle,
        defaultMessage: defaultMessage,
        attendanceLink: attendanceLink,
        hasNeutralPersons: hasNeutralPersons,
        scrollController: controller,
      ),
    );
  }
  return showModalBottomSheet<AdHocReminderResult>(
    context: context,
    useRootNavigator: true, // IOS_SHELL2: above the tab bar
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
    this.scrollController,
  });

  final String defaultTitle;
  final String defaultMessage;
  final String? attendanceLink;
  final bool hasNeutralPersons;

  /// Classic design: the controller of the breakpoint sheet.
  final ScrollController? scrollController;

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

  void _send() => Navigator.of(context).pop(AdHocReminderResult(
        title: _title.text,
        message: _message.text,
        neutralOnly: _neutralOnly,
      ));

  /// TER-04 / TER-17: Ionic AdHocReminderModal – toolbar title + close ✕,
  /// `ion-padding` content: intro text, an `ion-list lines="full"` with two
  /// stacked textareas and the toggle, the link item, the block button.
  Widget _buildClassic(BuildContext context) {
    final ios = useIosLook(context);
    return IonSheetScaffold(
      title: context.l10n.attendanceSendReminder,
      showClose: true,
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          controller: widget.scrollController,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              // `.intro p`: .9rem, line-height 1.4, medium-shade.
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  context.l10n.attendanceReminderInfo,
                  style: TextStyle(
                    fontSize: ios ? 15.3 : 14.4,
                    height: 1.4,
                    color: AppColors.medium,
                  ),
                ),
              ),
              IonStackedField(
                label: context.l10n.attendanceSubject,
                hintText: context.l10n.attendanceSubjectPlaceholder,
                controller: _title,
                minLines: 2,
                maxLines: null,
                lineInset: false,
                onChanged: (_) => setState(() {}),
              ),
              IonStackedField(
                label: context.l10n.attendanceMessage,
                hintText: context.l10n.attendanceMessagePlaceholder,
                controller: _message,
                minLines: 3,
                maxLines: null,
                lineInset: false,
                onChanged: (_) => setState(() {}),
              ),
              if (widget.hasNeutralPersons)
                DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: ionLineColor(context), width: ios ? 0.55 : 1),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.l10n.attendanceOnlyNeutral,
                                style: TextStyle(fontSize: ios ? 17 : 16),
                              ),
                              Text(context.l10n.attendanceOnlyNeutralHint, style: IonText.p(context)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Switch.adaptive(
                          value: _neutralOnly,
                          onChanged: (v) => setState(() => _neutralOnly = v),
                        ),
                      ],
                    ),
                  ),
                ),
              if (widget.attendanceLink != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 0, 0),
                        child: Icon(AppIcons.link, color: AppColors.medium),
                      ),
                      SizedBox(width: ios ? 16 : 32),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(context.l10n.attendanceEmailLink, style: IonText.p(context)),
                              SelectableText(
                                widget.attendanceLink!,
                                style: const TextStyle(fontSize: 13, color: AppColors.primary),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _canSend ? _send : null,
                icon: Icon(AppIcons.notificationsOutlined),
                label: IonButtonLabel(context.l10n.attendanceSend),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final classic = context.rdSkin == null;
    if (classic) return _buildClassic(context);
    final form = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!classic) ...[
              Text(context.l10n.attendanceSendReminder, style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
            ],
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
                leading: Icon(AppIcons.link, color: AppColors.medium),
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
              icon: Icon(AppIcons.notificationsOutlined),
              label: IonButtonLabel(context.l10n.attendanceSend),
            ),
          ],
        );
    if (classic) {
      // Ionic AdHocReminderModal: ion-title + close ✕ (end), padded content.
      return IonSheetScaffold(
        title: context.l10n.attendanceSendReminder,
        showClose: true,
        body: SafeArea(
          top: false,
          child: SingleChildScrollView(
            controller: widget.scrollController,
            padding: const EdgeInsets.all(16),
            child: form,
          ),
        ),
      );
    }
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: form,
      ),
    );
  }
}
