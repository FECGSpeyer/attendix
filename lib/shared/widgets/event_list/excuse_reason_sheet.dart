import 'package:flutter/material.dart';
import 'package:attendix/core/theme/app_icons.dart';

import '../../../l10n/l10n.dart';
import '../adaptive/adaptive.dart';
import '../layout/ionic_ios.dart' show IonSheetHeader;

export 'event_description_view.dart';
export 'registration_fields_sheet.dart';

// Internal sentinel for the free-text option (never stored).
const String _customReason = 'Sonstiger Grund';

/// Reason sheet for Absagen / Verspätung (Ionic ExcuseReasonPicker).
///
/// Shows the tenant's absence or late reasons plus "Sonstiger Grund (Text)".
/// When the Termin is today the free text is preselected, otherwise the
/// first predefined reason. Returns the reason or null when cancelled.
Future<String?> showExcuseReasonSheet(
  BuildContext context, {
  required bool isLate,
  required bool isToday,
  required List<String> absenceReasons,
  required List<String> lateReasons,
}) {
  return showModalBottomSheet<String>(
    context: context,
    useRootNavigator: true, // IOS_SHELL2: above the tab bar
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => _ExcuseReasonSheet(
      isLate: isLate,
      reasons: isLate ? lateReasons : absenceReasons,
      isToday: isToday,
    ),
  );
}

class _ExcuseReasonSheet extends StatefulWidget {
  const _ExcuseReasonSheet({
    required this.isLate,
    required this.reasons,
    required this.isToday,
  });

  final bool isLate;
  final List<String> reasons;
  final bool isToday;

  @override
  State<_ExcuseReasonSheet> createState() => _ExcuseReasonSheetState();
}

class _ExcuseReasonSheetState extends State<_ExcuseReasonSheet> {
  late String _selection;
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selection = widget.isToday || widget.reasons.isEmpty
        ? _customReason
        : widget.reasons.first;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _confirmable => _selection == _customReason
      ? _controller.text.trim().length > 4
      : _selection.isNotEmpty;

  void _confirm() {
    if (!_confirmable) return;
    Navigator.of(context).pop(
      _selection == _customReason ? _controller.text.trim() : _selection,
    );
  }

  @override
  Widget build(BuildContext context) {
    // UX_SONGS_SELF: Ionic excuse-reason-picker toolbar:
    // close (start), title, checkmark (end, strong)
    final title = widget.isLate ? context.l10n.excuseLate : context.l10n.excuseSignOut;
    final start = <Widget>[
      IconButton(
        icon: Icon(AppIcons.close),
        tooltip: context.l10n.commonCancel,
        onPressed: () => Navigator.of(context).pop(),
      ),
    ];
    final end = <Widget>[
      IconButton(
        key: const Key('excuse-reason-confirm'),
        icon: Icon(AppIcons.check),
        tooltip: context.l10n.commonConfirm,
        onPressed: _confirmable ? _confirm : null,
      ),
    ];
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              IonSheetHeader(title: title, start: start, end: end),
              ..._rows(context),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _rows(BuildContext context) => [
        RadioGroup<String>(
          groupValue: _selection,
          onChanged: (v) => setState(() => _selection = v ?? _selection),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final reason in [...widget.reasons, _customReason])
                RadioListTile<String>(
                  value: reason,
                  title: Text(reason == _customReason
                      ? context.l10n.excuseCustomOption
                      : reason),
                ),
            ],
          ),
        ),
        if (_selection == _customReason)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: TextField(
              controller: _controller,
              autofocus: true,
              minLines: 2,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: context.l10n.excuseReason,
                hintText: context.l10n.excuseMinChars,
                border: const OutlineInputBorder(),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: FilledButton(
            onPressed: _confirmable ? _confirm : null,
            child: IonButtonLabel(context.l10n.commonConfirm),
          ),
        ),
      ];
}
