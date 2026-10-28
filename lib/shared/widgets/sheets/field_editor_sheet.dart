import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';

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
    this.confirmText = 'Speichern',
    this.cancelText = 'Abbrechen',
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
  final String confirmText;
  final String cancelText;

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
    String confirmText = 'Speichern',
    String cancelText = 'Abbrechen',
    TextCapitalization? textCapitalization,
  }) async {
    return showModalBottomSheet<String>(
      context: context,
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
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.paddingL),

            // Text field
            TextField(
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
            ),
            const SizedBox(height: AppDimensions.paddingL),

            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(widget.cancelText),
                ),
                const SizedBox(width: AppDimensions.paddingS),
                FilledButton(
                  onPressed: _submit,
                  child: Text(widget.confirmText),
                ),
              ],
            ),
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
  }) async {
    final now = DateTime.now();
    return showDatePicker(
      context: context,
      initialDate: initialDate ?? now,
      firstDate: firstDate ?? DateTime(1900),
      lastDate: lastDate ?? DateTime(2100),
    );
  }
}
