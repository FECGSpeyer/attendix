import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import 'haptic_helper.dart';

/// Helper class for showing dialogs
class DialogHelper {
  /// Shows a confirmation dialog with title, message and custom button labels
  ///
  /// Returns true if user confirms, false if user cancels
  static Future<bool> showConfirmation(
    BuildContext context, {
    required String title,
    required String message,
    String? confirmText,
    String? cancelText,
    bool isDestructive = false,
  }) async {
    final l10n = context.l10n;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(cancelText ?? l10n.commonCancel),
          ),
          ElevatedButton(
            onPressed: () {
              if (isDestructive) HapticHelper.medium();
              Navigator.of(context).pop(true);
            },
            style: isDestructive
                ? ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                    foregroundColor: Theme.of(context).colorScheme.onError,
                  )
                : null,
            child: Text(confirmText ?? l10n.commonConfirm),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// Shows a simple alert dialog with OK button
  static Future<void> showAlert(
    BuildContext context, {
    required String title,
    required String message,
    String? okText,
  }) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(okText ?? context.l10n.commonOk),
          ),
        ],
      ),
    );
  }

  /// Shows a text input dialog
  ///
  /// The controller lives in the dialog's State, so it is disposed only after
  /// the dialog's exit animation (disposing it right after `showDialog`
  /// returns would hit "used after being disposed" during the animation).
  static Future<String?> showTextInput(
    BuildContext context, {
    required String title,
    String? initialValue,
    String? hint,
    int maxLines = 1,
    String? confirmText,
    String? cancelText,
    TextInputType? keyboardType,
  }) {
    return showDialog<String>(
      context: context,
      builder: (context) => _TextInputDialog(
        title: title,
        initialValue: initialValue,
        hint: hint,
        maxLines: maxLines,
        confirmText: confirmText ?? context.l10n.commonOk,
        cancelText: cancelText ?? context.l10n.commonCancel,
        keyboardType: keyboardType,
      ),
    );
  }
}

class _TextInputDialog extends StatefulWidget {
  const _TextInputDialog({
    required this.title,
    required this.initialValue,
    required this.hint,
    required this.maxLines,
    required this.confirmText,
    required this.cancelText,
    required this.keyboardType,
  });

  final String title;
  final String? initialValue;
  final String? hint;
  final int maxLines;
  final String confirmText;
  final String cancelText;
  final TextInputType? keyboardType;

  @override
  State<_TextInputDialog> createState() => _TextInputDialogState();
}

class _TextInputDialogState extends State<_TextInputDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialValue);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        maxLines: widget.maxLines,
        keyboardType: widget.keyboardType,
        decoration: InputDecoration(hintText: widget.hint),
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: Text(widget.cancelText),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: Text(widget.confirmText),
        ),
      ],
    );
  }
}
