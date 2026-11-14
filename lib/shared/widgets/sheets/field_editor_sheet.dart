import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:attendix/shared/widgets/dialogs/ion_sheet.dart';
import 'package:attendix/core/theme/redesign/rd_theme.dart';
import 'package:attendix/core/theme/app_icons.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/l10n.dart';
import '../adaptive/adaptive.dart';

/// A reusable BottomSheet for editing text/multiline fields.
/// Shows a text field with title, optional hint, and save/cancel buttons.
class FieldEditorSheet extends StatefulWidget {
  const FieldEditorSheet({
    super.key,
    required this.title,
    this.initialValue,
    this.hint,
    this.maxLines = 1,
    this.keyboardType,
    this.validator,
    this.icon,
    this.iconColor,
    this.confirmText,
    this.cancelText,
    this.textCapitalization,
  });

  final String title;
  final String? initialValue;
  final String? hint;
  final int maxLines;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final IconData? icon;
  final Color? iconColor;
  final String? confirmText;
  final String? cancelText;

  /// Keyboard capitalization. Defaults to sentence case for free text
  /// (Ionic `autocapitalize="sentences"`) and none for email/phone/number.
  final TextCapitalization? textCapitalization;

  /// Shows the field editor sheet and returns the new value, or null if cancelled.
  static Future<String?> show(
    BuildContext context, {
    required String title,
    String? initialValue,
    String? hint,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    IconData? icon,
    Color? iconColor,
    String? confirmText,
    String? cancelText,
    TextCapitalization? textCapitalization,
  }) async {
    return showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true, // IOS_SHELL2: above the tab bar
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => FieldEditorSheet(
        title: title,
        initialValue: initialValue,
        hint: hint,
        maxLines: maxLines,
        keyboardType: keyboardType,
        validator: validator,
        icon: icon,
        iconColor: iconColor,
        confirmText: confirmText,
        cancelText: cancelText,
        textCapitalization: textCapitalization,
      ),
    );
  }

  @override
  State<FieldEditorSheet> createState() => _FieldEditorSheetState();
}

class _FieldEditorSheetState extends State<FieldEditorSheet> {
  late TextEditingController _controller;
  final _formKey = GlobalKey<FormState>();
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (widget.validator != null) {
      final error = widget.validator!(_controller.text);
      if (error != null) {
        setState(() => _errorText = error);
        return;
      }
    }
    Navigator.pop(context, _controller.text);
  }

  @override
  Widget build(BuildContext context) {
    final field = TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: widget.hint,
                border: const OutlineInputBorder(),
                errorText: _errorText,
              ),
              maxLines: widget.maxLines,
              keyboardType: widget.keyboardType,
              textCapitalization: widget.textCapitalization ??
                  (widget.keyboardType == null ||
                          widget.keyboardType == TextInputType.text ||
                          widget.keyboardType == TextInputType.multiline
                      ? TextCapitalization.sentences
                      : TextCapitalization.none),
              autofocus: true,
              onChanged: (_) {
                if (_errorText != null) {
                  setState(() => _errorText = null);
                }
              },
              onSubmitted: widget.maxLines == 1 ? (_) => _submit() : null,
            );
    final actions = Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: IonButtonLabel(widget.cancelText ?? context.l10n.commonCancel),
                ),
                const SizedBox(width: AppDimensions.paddingS),
                FilledButton(
                  onPressed: _submit,
                  child: IonButtonLabel(widget.confirmText ?? context.l10n.commonSave),
                ),
              ],
            );
    if (context.rdSkin == null) {
      // Classic: the shared sheet toolbar (title + close ✕) under the
      // Ionic modal handle. The sheet keeps the height of its content
      // (Flutter-only editor, Ionic edits these fields inline).
      return Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              IonModalHandleOverlay(
                child: IonSheetHeader(title: widget.title, end: const [IonCloseButton()]),
              ),
              Padding(
                padding: const EdgeInsets.all(AppDimensions.paddingL),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    field,
                    const SizedBox(height: AppDimensions.paddingL),
                    actions,
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: AppDimensions.paddingL,
        right: AppDimensions.paddingL,
        top: AppDimensions.paddingL,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header row with title and close button
            Row(
              children: [
                if (widget.icon != null) ...[
                  Icon(
                    widget.icon,
                    color: widget.iconColor ?? AppColors.primary,
                    size: 28,
                  ),
                  const SizedBox(width: AppDimensions.paddingS),
                ],
                Expanded(
                  child: Text(
                    widget.title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  icon: Icon(AppIcons.close, semanticLabel: context.l10n.commonClose),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.paddingL),

            // Text field
            field,
            const SizedBox(height: AppDimensions.paddingL),

            // Action buttons
            actions,
            const SizedBox(height: AppDimensions.paddingL),
          ],
        ),
      ),
    );
  }
}

/// A date picker sheet that shows a calendar and returns the selected date.
class DateEditorSheet {
  /// Shows a date picker and returns the selected date, or null if cancelled.
  static Future<DateTime?> show(
    BuildContext context, {
    required String title,
    DateTime? initialDate,
    DateTime? firstDate,
    DateTime? lastDate,
    // md look (QUE-27): Ionic `ion-modal.dateModal` with
    // `<ion-datetime [preferWheel]="true">` (person page date fields).
    IonDatetimeOverlay overlay = IonDatetimeOverlay.dateModal,
    bool preferWheel = true,
  }) async {
    final now = DateTime.now();
    // PEO-26: iOS look (classic) – Ionic `ion-modal.dateModal` (max 400px,
    // auto height, radius 8) with `ion-datetime [preferWheel]="true"`: the
    // day / month / year wheel instead of the month grid.
    if (preferWheel &&
        overlay == IonDatetimeOverlay.dateModal &&
        useIosLook(context) &&
        context.rdSkin == null) {
      return _showIosWheelDateModal(
        context,
        initialDate: initialDate ?? now,
        firstDate: firstDate ?? DateTime(1900),
        lastDate: lastDate ?? DateTime(2100),
      );
    }
    return showAppDatePicker(
      context: context,
      initialDate: initialDate ?? now,
      firstDate: firstDate ?? DateTime(1900),
      lastDate: lastDate ?? DateTime(2100),
      overlay: overlay,
      preferWheel: preferWheel,
    );
  }
}

/// iOS `ion-modal.dateModal` with a wheel `ion-datetime`: a centred card
/// (max 400px, radius 8) holding the date wheel. Turning a wheel picks the
/// date; closing the modal (tap outside) returns the last picked date, or
/// null when nothing was turned.
Future<DateTime?> _showIosWheelDateModal(
  BuildContext context, {
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
}) async {
  var initial = initialDate;
  if (initial.isBefore(firstDate)) initial = firstDate;
  if (initial.isAfter(lastDate)) initial = lastDate;
  DateTime? picked;
  await showDialog<void>(
    context: context,
    useRootNavigator: true,
    barrierColor: const Color(0x33000000),
    builder: (ctx) {
      final theme = Theme.of(ctx);
      final w = (MediaQuery.sizeOf(ctx).width - 32).clamp(240.0, 400.0);
      return Center(
        child: SizedBox(
          width: w,
          child: Material(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
            clipBehavior: Clip.antiAlias,
            child: SizedBox(
              height: 216,
              child: CupertinoTheme(
                data: CupertinoThemeData(brightness: theme.brightness),
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.date,
                  dateOrder: DatePickerDateOrder.dmy,
                  initialDateTime: initial,
                  minimumDate: firstDate,
                  maximumDate: lastDate,
                  onDateTimeChanged: (d) =>
                      picked = DateTime(d.year, d.month, d.day),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
  return picked;
}
