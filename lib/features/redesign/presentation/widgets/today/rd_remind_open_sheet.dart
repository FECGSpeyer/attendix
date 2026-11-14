import 'package:flutter/material.dart';
import '../../../../../core/utils/toast_helper.dart';
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

/// Text to share with everybody: the standard text while [body] is the
/// unchanged [defaultBody], else "Hallo zusammen," and the edited body.
String rdRemindShareText(
  AppLocalizations l10n, {
  required String body,
  required String defaultBody,
  required String title,
  required String when,
}) {
  final text = body.trim();
  if (text.isEmpty || text == defaultBody.trim()) return l10n.redesignRemindShareText(title, when);
  return '${l10n.redesignRemindHelloAll}\n$text';
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
  // The page behind keeps the list alive for its count: whom to remind is
  // read again when the sheet opens (answers given since then are left out).
  ProviderScope.containerOf(context, listen: false).invalidate(rdOpenPersonsProvider(attendanceId));
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    useSafeArea: true,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: context.rd.bg,
    // Capped so the handle and the page above stay reachable with a long
    // list (closing used to need the push to be sent).
    builder: (_) => RdSheetCap(child: _RemindSheet(attendanceId: attendanceId, title: title, when: when)),
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
  late final _defaultBody = l10nWithoutContext.redesignRemindBody(widget.title, widget.when);
  late final _body = TextEditingController(text: _defaultBody);
  bool _sending = false;

  /// Persons reached in this sheet; a second send after a partial failure
  /// only goes to the others, so nobody gets the reminder twice.
  final _reached = <int>{};

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
    // The sheet can be closed while sending ("Abbrechen", swipe): only
    // pop it when it is still on top, never the page below.
    final sheet = ModalRoute.of(context);
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
        if (person.id != null) _reached.add(person.id!);
      } catch (_) {
        failed++;
      }
    }
    if (!mounted) return;
    setState(() => _sending = false);
    // Toast on the root overlay: stays visible after the sheet closes.
    if (failed == 0) {
      ToastHelper.showSuccess(context, l10n.redesignRemindSent(sent));
      if (sheet != null && sheet.isCurrent) Navigator.of(context).pop();
    } else {
      ToastHelper.showError(
        context,
        sent == 0 ? l10n.redesignRemindFailed : l10n.redesignRemindPartlyFailed(sent, failed),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final async = ref.watch(rdOpenPersonsProvider(widget.attendanceId));
    final open = async.valueOrNull;

    final children = <Widget>[
      Text([widget.title, widget.when].where((s) => s.isNotEmpty).join(' · '), style: RdType.meta(p, size: 14)),
      const SizedBox(height: 12),
    ];
    if (open == null) {
      children.add(RdInfoCard(text: l10n.redesignTodayLoading, loading: !async.hasError));
    } else {
      final withApp =
          open.where((x) => (x.appId?.isNotEmpty ?? false) && !_reached.contains(x.id)).toList();
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
        final reached = _reached.contains(person.id);
        rows.add(RdListRow(
          leading: RdInitials(rdInitialsOf('${person.firstName} ${person.lastName}'), size: 32),
          title: '${person.firstName} ${person.lastName}'.trim(),
          trailing: reached
              ? Text(l10n.redesignRemindReached, style: RdType.meta(p, size: 12).copyWith(color: p.present))
              : (hasApp ? null : Text(l10n.redesignRemindNoApp, style: RdType.meta(p, size: 12))),
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
              rdRemindShareText(
                l10n,
                body: _body.text,
                defaultBody: _defaultBody,
                title: widget.title,
                when: widget.when,
              ),
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
        child: LayoutBuilder(
          builder: (context, box) {
            // Head with "Abbrechen", like the other sheets. Fixed above the
            // list; scrolls along when there is hardly any room (small
            // screen in landscape with the keyboard open).
            final head = _RemindHead(title: open == null ? widget.title : l10n.redesignRemindTitle(open.length));
            final fixedHead = box.maxHeight >= 200;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (fixedHead) head,
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [if (!fixedHead) head, ...children],
                    ),
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

/// "Abbrechen" · title. Own head (not RdSheetHead): "Abbrechen" never wraps
/// at 390 px (it broke into "Abbreche n" and the first tap missed), wide
/// sides with the whole side as tap area, scaled down instead of wrapped.
class _RemindHead extends StatelessWidget {
  const _RemindHead({required this.title});

  final String title;

  static const double _side = 104;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Row(
        children: [
          SizedBox(
            width: _side,
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: const Key('rd-remind-cancel'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(_side, 44),
                  alignment: Alignment.centerLeft,
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    l10n.redesignCommonCancel,
                    maxLines: 1,
                    softWrap: false,
                    style: TextStyle(color: p.link, fontSize: 16),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: RdType.section(p),
              ),
            ),
          ),
          const SizedBox(width: _side),
        ],
      ),
    );
  }
}
