import 'package:flutter/material.dart';

import '../../../../../core/theme/redesign/rd_theme.dart';
import '../../../../../data/repositories/sign_in_out_repository.dart';
import '../../../../../l10n/l10n.dart';
import '../../../../self_service/presentation/widgets/self_service_event_actions.dart';
import '../rd_widgets.dart';

/// Result of the sign-out sheet: the reason and whether it is a delay.
typedef RdSignoutChoice = ({String reason, bool isLate});

/// A reason typed by hand needs at least 5 characters (like the reason
/// sheet of "Meine Termine").
bool rdSignoutReasonValid(String reason) => reason.trim().length > 4;

/// REDESIGN: "Abmelden" (canvas S4): "Ich kann nicht" / "Ich komme
/// später", reason chips or an own reason. Saves through
/// [SelfServiceEventActions.submitSignout] (same write and messages as the
/// reason sheet of "Meine Termine").
Future<void> showRdSignoutSheet(
  BuildContext context, {
  required CrossTenantPersonAttendance att,
  required SelfServiceEventActions actions,
  bool late = false,
}) async {
  final qa = actions.quickActions(att);
  if (qa == null || att.id == null) return;
  final allowExcuse = qa.allowExcuse && !qa.blocked;
  final allowLate = qa.allowLate && !qa.blocked;
  if (!allowExcuse && !allowLate) return;

  final choice = await showRdReasonSheet(
    context,
    title: att.eventTitle,
    meta: att.eventMeta(withDate: true),
    absenceReasons: actions.absenceReasons,
    lateReasons: actions.lateReasons,
    allowExcuse: allowExcuse,
    allowLate: allowLate,
    late: late && allowLate || !allowExcuse,
    ownReasonFirst: att.isRunning,
  );
  if (choice == null || !context.mounted) return;
  await actions.submitSignout(context, att, choice.reason, isLate: choice.isLate);
}

/// The reason picker of [showRdSignoutSheet] on its own (also used by
/// Eltern for a child): returns the choice, writes nothing.
Future<RdSignoutChoice?> showRdReasonSheet(
  BuildContext context, {
  required String title,
  String meta = '',
  required List<String> absenceReasons,
  required List<String> lateReasons,
  bool allowExcuse = true,
  bool allowLate = true,
  bool late = false,
  bool ownReasonFirst = false,
}) {
  return showModalBottomSheet<RdSignoutChoice>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: context.rd.bg,
    builder: (_) => _SignoutSheet(
      title: title,
      meta: meta,
      absenceReasons: absenceReasons,
      lateReasons: lateReasons,
      allowExcuse: allowExcuse,
      allowLate: allowLate,
      late: late,
      ownReasonFirst: ownReasonFirst,
    ),
  );
}

class _SignoutSheet extends StatefulWidget {
  const _SignoutSheet({
    required this.title,
    required this.meta,
    required this.absenceReasons,
    required this.lateReasons,
    required this.allowExcuse,
    required this.allowLate,
    required this.late,
    required this.ownReasonFirst,
  });

  final String title;
  final String meta;
  final List<String> absenceReasons;
  final List<String> lateReasons;
  final bool allowExcuse;
  final bool allowLate;
  final bool late;

  /// Today: an own reason is more likely than a prepared one.
  final bool ownReasonFirst;

  @override
  State<_SignoutSheet> createState() => _SignoutSheetState();
}

class _SignoutSheetState extends State<_SignoutSheet> {
  late bool _late = widget.late;
  String? _reason;
  late bool _own = widget.ownReasonFirst;
  final _text = TextEditingController();

  List<String> get _reasons => _late ? widget.lateReasons : widget.absenceReasons;

  String? get _result {
    if (_own) return rdSignoutReasonValid(_text.text) ? _text.text.trim() : null;
    return _reason;
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final result = _result;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.title, style: RdType.cardTitle(p)),
              if (widget.meta.isNotEmpty) Text(widget.meta, style: RdType.meta(p, size: 14)),
              if (widget.allowExcuse && widget.allowLate) ...[
                const SizedBox(height: 16),
                RdSegmented<bool>(
                  values: const [false, true],
                  selected: _late,
                  labelOf: (late) => late ? l10n.redesignSignoutLater : l10n.redesignSignoutCannot,
                  onChanged: (v) => setState(() {
                    _late = v;
                    _reason = null;
                  }),
                ),
              ],
              const SizedBox(height: 18),
              RdGroupLabel(l10n.redesignSignoutReason),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final r in _reasons)
                    RdChoiceChip(
                      label: r,
                      selected: !_own && _reason == r,
                      onTap: () => setState(() {
                        _own = false;
                        _reason = r;
                      }),
                    ),
                  RdChoiceChip(
                    label: l10n.redesignSignoutOther,
                    selected: _own,
                    onTap: () => setState(() => _own = true),
                  ),
                ],
              ),
              if (_own) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _text,
                  autofocus: true,
                  minLines: 2,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: l10n.redesignSignoutOtherHint,
                    filled: true,
                    fillColor: p.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(p.buttonRadius),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Row(
                children: [
                  Icon(Icons.lock_outline, size: 16, color: p.text2),
                  const SizedBox(width: 6),
                  Expanded(child: Text(l10n.redesignSignoutPrivacy, style: RdType.meta(p, size: 13))),
                ],
              ),
              const SizedBox(height: 18),
              RdPrimaryButton(
                label: _late ? l10n.redesignSignoutSubmitLate : l10n.redesignSignoutSubmit,
                color: _late ? p.late : p.absent,
                foreground: p.onStatus,
                onPressed: result == null
                    ? null
                    : () => Navigator.of(context).pop((reason: result, isLate: _late)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
