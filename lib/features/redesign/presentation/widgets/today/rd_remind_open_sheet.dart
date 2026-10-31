import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../../core/providers/attendance_providers.dart';
import '../../../../../core/theme/redesign/rd_theme.dart';
import '../../../../../data/models/person/person.dart';
import '../../../../../l10n/l10n.dart';
import '../../../data/providers/rd_today_providers.dart';
import '../../rd_actions.dart' show rdShareLink;
import '../rd_widgets.dart';
import 'rd_today_common.dart';

/// "Fr 2.11., 19:30" of a Termin for the reminder text.
String rdRemindWhen(DateTime? start, {required bool hasTime}) {
  if (start == null) return '';
  final day = DateFormat.E(currentIntlLocale()).format(start).replaceAll('.', '');
  final date = '$day ${DateFormat('d.M.').format(start)}';
  return hasTime ? '$date, ${DateFormat('HH:mm').format(start)}' : date;
}

/// Personal push text: "Hallo Tim," and the body below.
String rdRemindMessage(AppLocalizations l10n, Person person, String body) {
  final name = person.firstName.trim();
  return name.isEmpty ? body.trim() : '${l10n.redesignRemindHello(name)}\n${body.trim()}';
}

/// REDESIGN (UX D2): who has not answered the next Termin yet, grouped by
/// register, with a personal reminder ("Hallo Tim, …") through the
/// existing `send-ad-hoc-reminder` Edge Function (push + mail, one call per
/// person with an app account) and the same text to share for the rest.
Future<void> showRdRemindOpenSheet(
  BuildContext context, {
  required int attendanceId,
  required String title,
  required String when,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: context.rd.bg,
    builder: (_) => _RemindSheet(attendanceId: attendanceId, title: title, when: when),
  );
}

class _RemindSheet extends ConsumerStatefulWidget {
  const _RemindSheet({required this.attendanceId, required this.title, required this.when});

  final int attendanceId;
  final String title;
  final String when;

  @override
  ConsumerState<_RemindSheet> createState() => _RemindSheetState();
}

class _RemindSheetState extends ConsumerState<_RemindSheet> {
  late final _body = TextEditingController(
    text: l10nWithoutContext.redesignRemindBody(widget.title, widget.when),
  );
  bool _sending = false;

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  Future<void> _send(List<Person> withApp) async {
    if (_sending || withApp.isEmpty || _body.text.trim().isEmpty) return;
    final l10n = context.l10n;
    final repo = ref.read(attendanceRepositoryWithTenantProvider);
    final title = l10n.attendanceReminderTitle('${widget.title} · ${widget.when}');
    setState(() => _sending = true);
    var sent = 0;
    var failed = 0;
    for (final person in withApp) {
      try {
        await repo.sendAdHocReminder(
          attendanceId: widget.attendanceId,
          title: title,
          message: rdRemindMessage(l10n, person, _body.text),
          playerAppId: person.appId,
        );
        sent++;
      } catch (_) {
        failed++;
      }
    }
    if (!mounted) return;
    setState(() => _sending = false);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final text = failed == 0
        ? l10n.redesignRemindSent(sent)
        : (sent == 0 ? l10n.redesignRemindFailed : l10n.redesignRemindPartlyFailed(sent, failed));
    if (failed == 0) Navigator.of(context).pop();
    messenger?.showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final async = ref.watch(rdOpenPersonsProvider(widget.attendanceId));
    final open = async.valueOrNull;

    final children = <Widget>[
      Text(
        open == null ? widget.title : l10n.redesignRemindTitle(open.length),
        style: RdType.cardTitle(p),
      ),
      Text([widget.title, widget.when].where((s) => s.isNotEmpty).join(' · '), style: RdType.meta(p, size: 14)),
      const SizedBox(height: 12),
    ];
    if (open == null) {
      children.add(RdInfoCard(text: l10n.redesignTodayLoading, loading: !async.hasError));
    } else {
      final withApp = open.where((x) => x.appId?.isNotEmpty ?? false).toList();
      String? group;
      final rows = <Widget>[];
      for (final person in open) {
        final g = person.groupName ?? l10n.attendanceNoGroup;
        if (g != group) {
          group = g;
          if (rows.isNotEmpty) children.add(RdGroupedList(children: List.of(rows)));
          rows.clear();
          children.add(Padding(padding: const EdgeInsets.only(top: 6), child: RdGroupLabel(g)));
        }
        final hasApp = person.appId?.isNotEmpty ?? false;
        rows.add(RdListRow(
          leading: RdInitials(rdInitialsOf('${person.firstName} ${person.lastName}'), size: 32),
          title: '${person.firstName} ${person.lastName}'.trim(),
          trailing: hasApp ? null : Text(l10n.redesignRemindNoApp, style: RdType.meta(p, size: 12)),
          showChevron: false,
        ));
      }
      if (rows.isNotEmpty) children.add(RdGroupedList(children: rows));
      children.addAll([
        const SizedBox(height: 16),
        TextField(
          controller: _body,
          minLines: 3,
          maxLines: 6,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: l10n.redesignRemindMessageLabel,
            filled: true,
            fillColor: p.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(p.buttonRadius),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 12),
        RdPrimaryButton(
          label: l10n.redesignRemindPush(withApp.length),
          icon: Icons.notifications_active_outlined,
          onPressed: withApp.isEmpty || _sending || _body.text.trim().isEmpty ? null : () => _send(withApp),
        ),
        const SizedBox(height: 8),
        Builder(
          builder: (button) => RdOutlineButton(
            label: l10n.redesignRemindShare,
            icon: Icons.ios_share,
            onPressed: () => rdShareLink(
              button,
              l10n.redesignRemindShareText(widget.title, widget.when),
              copiedMessage: l10n.redesignRemindCopied,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(l10n.redesignRemindHint, style: RdType.meta(p, size: 13)),
      ]);
    }

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
        ),
      ),
    );
  }
}
