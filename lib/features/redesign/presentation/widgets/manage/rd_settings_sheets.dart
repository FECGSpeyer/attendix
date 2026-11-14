import 'package:flutter/material.dart';

import '../../../../../core/theme/redesign/rd_theme.dart';
import '../../../../../l10n/l10n.dart';
import '../rd_widgets.dart';

/// REDESIGN: building blocks of the page type "Einstellungen" (canvas
/// "Beta: Gruppe und Daten"): switch rows and small sheets that change one
/// value. Same look as Ich › Benachrichtigungen and the sheets of
/// "Termin anlegen"; the pages save right after "Fertig" or a switch.

/// A grey note below a grouped list (one or two lines).
class RdListNote extends StatelessWidget {
  const RdListNote(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
    child: Text(text, style: RdType.meta(context.rd, size: 13)),
  );
}

/// Bottom sheet of the new design (drag handle, page background).
Future<T?> showRdSettingsSheet<T>(BuildContext context, WidgetBuilder builder) {
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: true,
    useSafeArea: true,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: context.rd.bg,
    builder:
        (ctx) => SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.85),
            child: builder(ctx),
          ),
        ),
  );
}

/// Head of a sheet: "Abbrechen" · title · "Fertig".
class RdSheetHead extends StatelessWidget {
  const RdSheetHead({super.key, required this.title, this.onDone, this.doneLabel, this.cancel = true});

  final String title;

  /// False hides "Abbrechen" (sheets that save every change right away).
  final bool cancel;

  /// Null hides "Fertig" (sheets that close on a tap).
  final VoidCallback? onDone;
  final String? doneLabel;

  /// Both sides equally wide so the title stays centred; wide enough for
  /// "Abbrechen" on one line (it wrapped to "Abbreche/n" at 96).
  static const double _sideWidth = 104;
  static final ButtonStyle _sideButtonStyle = TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8));

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: Row(
        children: [
          SizedBox(
            width: _sideWidth,
            child: Align(
              alignment: Alignment.centerLeft,
              child: !cancel
                  ? null
                  : TextButton(
                      style: _sideButtonStyle,
                      onPressed: () => Navigator.of(context).pop(),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          l10n.redesignCommonCancel,
                          maxLines: 1,
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
          SizedBox(
            width: _sideWidth,
            child: Align(
              alignment: Alignment.centerRight,
              child:
                  onDone == null
                      ? null
                      : TextButton(
                        style: _sideButtonStyle,
                        onPressed: onDone,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            doneLabel ?? l10n.redesignCommonDone,
                            maxLines: 1,
                            style: TextStyle(color: p.link, fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Changes one text value ("Kürzel", "Branding-Text"). Returns the trimmed
/// text on "Fertig", null on cancel. [required] refuses an empty value.
Future<String?> showRdTextSheet(
  BuildContext context, {
  required String title,
  String initial = '',
  String? hint,
  String? helper,
  bool required = false,
  int maxLines = 1,
  int? maxLength,
  TextCapitalization capitalization = TextCapitalization.sentences,
  TextInputType? keyboardType,
}) {
  return showRdSettingsSheet<String>(
    context,
    (_) => _TextSheet(
      keyboardType: keyboardType,
      title: title,
      initial: initial,
      hint: hint,
      helper: helper,
      required: required,
      maxLines: maxLines,
      maxLength: maxLength,
      capitalization: capitalization,
    ),
  );
}

class _TextSheet extends StatefulWidget {
  const _TextSheet({
    required this.title,
    required this.initial,
    required this.hint,
    required this.helper,
    required this.required,
    required this.maxLines,
    required this.maxLength,
    required this.capitalization,
    this.keyboardType,
  });

  final String title;
  final String initial;
  final String? hint;
  final String? helper;
  final bool required;
  final int maxLines;
  final int? maxLength;
  final TextCapitalization capitalization;
  final TextInputType? keyboardType;

  @override
  State<_TextSheet> createState() => _TextSheetState();
}

class _TextSheetState extends State<_TextSheet> {
  late final _controller = TextEditingController(text: widget.initial);
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _done() {
    final value = _controller.text.trim();
    if (widget.required && value.isEmpty) {
      setState(() => _error = context.l10n.rdSettingsEmptyValue);
      return;
    }
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            RdSheetHead(title: widget.title, onDone: _done),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: RdCard(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                child: TextField(
                  controller: _controller,
                  autofocus: true,
                  maxLines: widget.maxLines,
                  maxLength: widget.maxLength,
                  minLines: 1,
                  textCapitalization: widget.capitalization,
                  keyboardType: widget.keyboardType,
                  textInputAction: widget.maxLines == 1 ? TextInputAction.done : TextInputAction.newline,
                  onSubmitted: widget.maxLines == 1 ? (_) => _done() : null,
                  decoration: InputDecoration(
                    hintText: widget.hint,
                    errorText: _error,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                  ),
                  style: RdType.body(p),
                ),
              ),
            ),
            if (widget.helper != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                child: Text(widget.helper!, style: RdType.meta(p, size: 13)),
              ),
          ],
        ),
      ),
    );
  }
}

/// Picks one of [options] (value, label); closes on tap.
Future<T?> showRdChoiceSheet<T>(
  BuildContext context, {
  required String title,
  required List<(T, String)> options,
  T? selected,
}) {
  return showRdSettingsSheet<T>(context, (ctx) {
    final p = ctx.rd;
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        RdSheetHead(title: title),
        RdGroupedList(
          children: [
            for (final (value, label) in options)
              RdListRow(
                title: label,
                selected: value == selected,
                showChevron: false,
                trailing: value == selected ? Icon(Icons.check, size: 22, color: p.primary) : const SizedBox(width: 22),
                onTap: () => Navigator.of(ctx).pop(value),
              ),
          ],
        ),
      ],
    );
  });
}

/// One option of [showRdMultiChoiceSheet]; [locked] options stay selected.
typedef RdMultiOption = ({String key, String label, bool locked});

/// Picks several options; returns the selected keys in option order on
/// "Fertig", null on cancel.
Future<List<String>?> showRdMultiChoiceSheet(
  BuildContext context, {
  required String title,
  required List<RdMultiOption> options,
  required List<String> selected,
  String? hint,
}) {
  return showRdSettingsSheet<List<String>>(
    context,
    (_) => _MultiChoiceSheet(title: title, options: options, selected: selected, hint: hint),
  );
}

class _MultiChoiceSheet extends StatefulWidget {
  const _MultiChoiceSheet({required this.title, required this.options, required this.selected, this.hint});

  final String title;
  final List<RdMultiOption> options;
  final List<String> selected;
  final String? hint;

  @override
  State<_MultiChoiceSheet> createState() => _MultiChoiceSheetState();
}

class _MultiChoiceSheetState extends State<_MultiChoiceSheet> {
  late final Set<String> _selected = {
    ...widget.selected,
    for (final o in widget.options)
      if (o.locked) o.key,
  };

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        RdSheetHead(
          title: widget.title,
          onDone:
              () => Navigator.of(context).pop([
                // Keys of options that no longer exist are kept (Ionic keeps
                // the stored list as it is).
                for (final key in widget.selected)
                  if (!widget.options.any((o) => o.key == key)) key,
                for (final o in widget.options)
                  if (_selected.contains(o.key)) o.key,
              ]),
        ),
        RdGroupedList(
          children: [
            for (final o in widget.options)
              RdListRow(
                title: o.label,
                showChevron: false,
                titleColor: o.locked ? p.text2 : null,
                trailing: Icon(
                  _selected.contains(o.key) ? Icons.check_circle : Icons.radio_button_unchecked,
                  size: 24,
                  color: _selected.contains(o.key) ? (o.locked ? p.text2 : p.primary) : p.text2,
                ),
                onTap:
                    o.locked
                        ? null
                        : () => setState(() {
                          if (!_selected.remove(o.key)) _selected.add(o.key);
                        }),
              ),
          ],
        ),
        if (widget.hint != null) RdListNote(widget.hint!),
      ],
    );
  }
}

/// Edits a list of reasons (Abwesenheits-/Verspätungsgründe): type, drag
/// to sort, remove; "Standardwerte wiederherstellen" while empty. Returns
/// the list on "Fertig", null on cancel.
Future<List<String>?> showRdReasonsSheet(
  BuildContext context, {
  required String title,
  required List<String> reasons,
  required List<String> defaults,
}) {
  return showRdSettingsSheet<List<String>>(
    context,
    (_) => _ReasonsSheet(title: title, reasons: reasons, defaults: defaults),
  );
}

class _ReasonsSheet extends StatefulWidget {
  const _ReasonsSheet({required this.title, required this.reasons, required this.defaults});

  final String title;
  final List<String> reasons;
  final List<String> defaults;

  @override
  State<_ReasonsSheet> createState() => _ReasonsSheetState();
}

class _ReasonsSheetState extends State<_ReasonsSheet> {
  final List<({int id, TextEditingController controller})> _rows = [];
  int _nextId = 0;

  @override
  void initState() {
    super.initState();
    _fill(widget.reasons);
  }

  @override
  void dispose() {
    for (final r in _rows) {
      r.controller.dispose();
    }
    super.dispose();
  }

  void _fill(List<String> reasons) {
    for (final reason in reasons) {
      _rows.add((id: _nextId++, controller: TextEditingController(text: reason)));
    }
  }

  void _remove(int index) {
    final removed = _rows.removeAt(index).controller;
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) => removed.dispose());
  }

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          RdSheetHead(
            title: widget.title,
            onDone: () => Navigator.of(context).pop([for (final r in _rows) r.controller.text]),
          ),
          if (_rows.isNotEmpty)
            RdCard(
              padding: EdgeInsets.zero,
              child: ReorderableListView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: false,
                onReorderItem: (oldIndex, newIndex) {
                  setState(() => _rows.insert(newIndex, _rows.removeAt(oldIndex)));
                },
                children: [
                  for (var i = 0; i < _rows.length; i++)
                    Padding(
                      key: ValueKey('rd-reason-${_rows[i].id}'),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Row(
                        children: [
                          ReorderableDragStartListener(
                            index: i,
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Icon(Icons.drag_handle, color: p.text2),
                            ),
                          ),
                          Expanded(
                            child: TextField(
                              controller: _rows[i].controller,
                              textCapitalization: TextCapitalization.sentences,
                              decoration: InputDecoration(
                                hintText: l10n.generalSettingsReasonPh,
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                filled: false,
                              ),
                              style: RdType.body(p),
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.remove_circle_outline, color: p.absent),
                            tooltip: l10n.commonRemove,
                            onPressed: () => _remove(i),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          RdGroupedList(
            children: [
              RdListRow(
                title: l10n.generalSettingsAddReason,
                titleColor: p.primary,
                showChevron: false,
                onTap: () => setState(() => _fill([''])),
              ),
              if (_rows.isEmpty)
                RdListRow(
                  title: l10n.generalSettingsRestoreDefaults,
                  showChevron: false,
                  onTap: () => setState(() => _fill(widget.defaults)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
