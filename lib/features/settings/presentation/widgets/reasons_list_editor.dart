import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/l10n.dart';
import 'settings_list.dart';

/// Editable list of absence / late reasons (Ionic general settings
/// "Abwesenheits- & Verspätungsgründe").
///
/// Like Ionic every reason is an inline input ("Grund eingeben...") and
/// "Grund hinzufügen" appends an empty row. Empty rows are kept while
/// editing and dropped when the page saves (`normalizeReasons`).
class ReasonsListEditor extends StatefulWidget {
  const ReasonsListEditor({
    super.key,
    required this.title,
    required this.reasons,
    required this.defaults,
    required this.onChanged,
  });

  final String title;
  final List<String> reasons;
  final List<String> defaults;
  final ValueChanged<List<String>> onChanged;

  @override
  State<ReasonsListEditor> createState() => _ReasonsListEditorState();
}

class _ReasonsListEditorState extends State<ReasonsListEditor> {
  /// One input per reason; the id keeps focus and text across reorders.
  final List<({int id, TextEditingController controller})> _rows = [];
  int _nextId = 0;

  List<String> get _values => [for (final r in _rows) r.controller.text];

  @override
  void initState() {
    super.initState();
    _sync(widget.reasons);
  }

  @override
  void didUpdateWidget(covariant ReasonsListEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only replace the inputs when the list changed from outside
    // (e.g. "Standardwerte wiederherstellen").
    if (!listEquals(widget.reasons, _values)) _sync(widget.reasons);
  }

  @override
  void dispose() {
    for (final r in _rows) {
      r.controller.dispose();
    }
    super.dispose();
  }

  void _sync(List<String> reasons) {
    final old = [for (final r in _rows) r.controller];
    _rows
      ..clear()
      ..addAll([for (final reason in reasons) _newRow(reason)]);
    _disposeLater(old);
  }

  ({int id, TextEditingController controller}) _newRow(String text) =>
      (id: _nextId++, controller: TextEditingController(text: text));

  /// Controllers of removed rows are still attached until the next frame.
  void _disposeLater(List<TextEditingController> controllers) {
    if (controllers.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final c in controllers) {
        c.dispose();
      }
    });
  }

  void _emit() => widget.onChanged(_values);

  void _add() {
    setState(() => _rows.add(_newRow('')));
    _emit();
  }

  void _remove(int index) {
    final removed = _rows[index].controller;
    setState(() => _rows.removeAt(index));
    _disposeLater([removed]);
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    // UX_SETTINGS (WAVE 8): ion-accordion — header item (h2 + p count),
    // inset rows with a red trash button, then "+ Grund hinzufügen"
    // (primary) and, only for an empty list, "Standard wiederherstellen".
    final ios = ionIsIos(context);
    final pad = ios
        ? const EdgeInsets.only(left: IonIos.itemPaddingStart, right: IonIos.itemPaddingEnd)
        : const EdgeInsets.symmetric(horizontal: 16);
    return ExpansionTile(
      tilePadding: pad,
      shape: const Border(),
      collapsedShape: const Border(),
      iconColor: ios ? IonIos.text(context).withValues(alpha: 0.4) : null,
      collapsedIconColor: ios ? IonIos.text(context).withValues(alpha: 0.4) : null,
      title: Text(widget.title),
      subtitle: Text(
        context.l10n.generalSettingsReasonsCount(_rows.length),
        style: ios ? TextStyle(fontSize: 14, color: IonIos.labelP(context)) : null,
      ),
      children: [
        ReorderableListView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          onReorder: (oldIndex, newIndex) {
            if (newIndex > oldIndex) newIndex -= 1;
            setState(() => _rows.insert(newIndex, _rows.removeAt(oldIndex)));
            _emit();
          },
          children: [
            for (var i = 0; i < _rows.length; i++)
              ListTile(
                key: ValueKey('reason-${_rows[i].id}'),
                contentPadding: pad,
                leading: ReorderableDragStartListener(
                  index: i,
                  child: Icon(Icons.drag_handle, color: ios ? IonIos.note(context) : null),
                ),
                // Ionic ion-input (no label) in an inset ion-item.
                title: TextField(
                  controller: _rows[i].controller,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: context.l10n.generalSettingsReasonPh,
                    hintStyle: ios ? TextStyle(color: IonIos.note(context)) : null,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  onChanged: (_) => _emit(),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                  tooltip: context.l10n.commonRemove,
                  onPressed: () => _remove(i),
                ),
              ),
          ],
        ),
        ListTile(
          contentPadding: pad,
          onTap: _add,
          title: Text.rich(
            TextSpan(children: [
              const WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Icon(Icons.add_circle_outline, size: 18, color: AppColors.primary),
              ),
              TextSpan(text: ' ${context.l10n.generalSettingsAddReason}'),
            ]),
            style: const TextStyle(color: AppColors.primary),
          ),
        ),
        if (_rows.isEmpty)
          ListTile(
            contentPadding: pad,
            onTap: () => widget.onChanged([...widget.defaults]),
            title: Text(
              context.l10n.generalSettingsRestoreDefaults,
              style: const TextStyle(color: AppColors.medium),
            ),
          ),
      ],
    );
  }
}
