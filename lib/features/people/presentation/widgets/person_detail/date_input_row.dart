import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../l10n/l10n.dart';
import '../../../../../shared/widgets/sheets/field_editor_sheet.dart';
import '../ion/ion_widgets.dart';

/// Ionic `dayjs(date).startOf('day').utc(true).toISOString()`.
String utcMidnightIso(DateTime d) =>
    DateTime.utc(d.year, d.month, d.day).toIso8601String();

/// Ionic person.page `onManualDateInput`: "T.M.JJJJ" / "TT.MM.JJJJ" →
/// UTC-midnight ISO. Returns null for another format or an impossible day /
/// month (Ionic keeps the old value then).
String? parseManualDate(String input) {
  final m = RegExp(r'^(\d{1,2})\.(\d{1,2})\.(\d{4})$').firstMatch(input.trim());
  if (m == null) return null;
  final day = int.parse(m.group(1)!);
  final month = int.parse(m.group(2)!);
  final year = int.parse(m.group(3)!);
  if (month < 1 || month > 12 || day < 1 || day > 31) return null;
  // JS new Date(y, m - 1, d) rolls an overflowing day into the next month.
  return utcMidnightIso(DateTime(year, month, day));
}

/// Display value of a stored date (Ionic formatDateForDisplay, local date).
String formatStoredDate(String? value) {
  if (value == null || value.isEmpty) return '';
  final date = DateTime.tryParse(value);
  if (date == null) return '';
  return DateFormat('dd.MM.yyyy').format(date.isUtc ? date.toLocal() : date);
}

/// Ionic person.page date item: stacked label, `ion-input` with placeholder
/// "TT.MM.JJJJ" (applied on blur) and a calendar button that opens the date
/// picker. [onChanged] receives the UTC-midnight ISO string.
class DateInputRow extends StatefulWidget {
  const DateInputRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.highlight = false,
    this.lastDate,
  });

  final String label;
  final String? value;
  final ValueChanged<String> onChanged;
  final bool enabled;
  final bool highlight;
  final DateTime? lastDate;

  @override
  State<DateInputRow> createState() => _DateInputRowState();
}

class _DateInputRowState extends State<DateInputRow> {
  late final TextEditingController _controller =
      TextEditingController(text: formatStoredDate(widget.value));
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) _applyTyped();
    });
  }

  @override
  void didUpdateWidget(covariant DateInputRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && !_focus.hasFocus) {
      _controller.text = formatStoredDate(widget.value);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _applyTyped() {
    final text = _controller.text.trim();
    if (text.isEmpty) return; // Ionic: empty input changes nothing
    final iso = parseManualDate(text);
    if (iso == null) {
      _controller.text = formatStoredDate(widget.value); // revert
      return;
    }
    if (iso != widget.value) widget.onChanged(iso);
  }

  Future<void> _pick() async {
    final current = DateTime.tryParse(widget.value ?? '');
    final date = await DateEditorSheet.show(
      context,
      title: widget.label,
      initialDate: current == null
          ? null
          : (current.isUtc ? current.toLocal() : current),
      lastDate: widget.lastDate,
    );
    if (date == null || !mounted) return;
    final iso = utcMidnightIso(date);
    _controller.text = formatStoredDate(iso);
    widget.onChanged(iso);
  }

  @override
  Widget build(BuildContext context) {
    final ios = ionIsIos(context);
    final bg = widget.highlight ? AppColors.warning : null;
    final fg = widget.highlight
        ? AppColors.getContrastColor(AppColors.warning)
        : Theme.of(context).colorScheme.onSurface;
    return Material(
      color: bg ?? Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.only(left: 16),
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: ionLineColor(context), width: ios ? 0.55 : 1),
            ),
          ),
          padding: const EdgeInsets.only(right: 4, top: 8, bottom: 4),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.label,
                      style: TextStyle(
                        fontSize: ios ? 14 : 12,
                        color: ios || widget.highlight ? fg : AppColors.medium,
                      ),
                    ),
                    TextField(
                      controller: _controller,
                      focusNode: _focus,
                      enabled: widget.enabled,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: TextStyle(fontSize: ios ? 17 : 16, color: fg),
                      decoration: InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        filled: false,
                        contentPadding: const EdgeInsets.symmetric(vertical: 6),
                        hintText: context.l10n.personDatePlaceholder,
                      ),
                      onSubmitted: (_) => _applyTyped(),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: widget.label,
                icon: Icon(Icons.calendar_today_outlined, color: widget.highlight ? fg : null),
                onPressed: widget.enabled ? _pick : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
