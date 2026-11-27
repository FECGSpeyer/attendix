part of 'app_dialog.dart';

/// Text input used inside an [AppAlertDialog] / [AppAlertInputGroup].
class AppAlertInput extends StatelessWidget {
  const AppAlertInput({
    super.key,
    required this.controller,
    this.placeholder,
    this.autofocus = false,
    this.keyboardType,
    this.onSubmitted,
    this.minLines,
    this.maxLines = 1,
    this.textCapitalization = TextCapitalization.none,
    this.textarea = false,
    this.obscureText = false,
    this.readOnly = false,
    this.onTap,
    this.onChanged,
    this.enabled,
    this.inputFormatters,
    this.focusNode,
    this.textInputAction,
    this.autofillHints,
    this.autocorrect = true,
    this.betaDecoration,
  });

  final TextEditingController controller;
  final String? placeholder;
  final bool autofocus;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onSubmitted;
  final int? minLines;
  final int? maxLines;
  final TextCapitalization textCapitalization;
  final bool textarea;
  final bool obscureText;
  final bool readOnly;
  final VoidCallback? onTap;
  final ValueChanged<String>? onChanged;
  final bool? enabled;
  final List<TextInputFormatter>? inputFormatters;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final bool autocorrect;
  final InputDecoration? betaDecoration;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autofocus: autofocus,
      keyboardType: keyboardType,
      onSubmitted: onSubmitted,
      minLines: minLines,
      maxLines: maxLines,
      textCapitalization: textCapitalization,
      obscureText: obscureText,
      readOnly: readOnly,
      onTap: onTap,
      onChanged: onChanged,
      enabled: enabled,
      inputFormatters: inputFormatters,
      focusNode: focusNode,
      textInputAction: textInputAction,
      autofillHints: autofillHints,
      autocorrect: autocorrect,
      decoration: betaDecoration ?? InputDecoration(hintText: placeholder),
    );
  }
}

/// Column of alert message and inputs/widgets for an [AppAlertDialog].
class AppAlertInputGroup extends StatelessWidget
    implements AppAlertGroupContent {
  const AppAlertInputGroup({
    super.key,
    this.message,
    required this.children,
    this.betaCrossAxisAlignment = CrossAxisAlignment.center,
    this.beta,
  });

  final Widget? message;
  final List<Widget> children;
  final CrossAxisAlignment betaCrossAxisAlignment;
  final Widget? beta;

  @override
  String? get alertMessageText => switch (message) {
        final Text t => t.data,
        _ => null,
      };

  @override
  Widget build(BuildContext context) {
    final beta = this.beta;
    if (beta != null) return beta;
    final message = this.message;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: betaCrossAxisAlignment,
      children: [if (message != null) message, ...children],
    );
  }
}

/// Dialog title wrapper (ignores legacy subHeader).
class AppAlertTitle extends StatelessWidget {
  const AppAlertTitle(this.title, {super.key, this.subHeader});

  final String title;
  final String? subHeader;

  @override
  Widget build(BuildContext context) => Text(title);
}

/// Vertical spacing helper inside an [AppAlertInputGroup].
class AppAlertBetaGap extends StatelessWidget {
  const AppAlertBetaGap(this.height, {super.key});

  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(height: height);
}

/// Alert dialog with a date picker input field.
Future<DateTime?> showAppDateAlert(
  BuildContext context, {
  required String title,
  String? message,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  required String confirmText,
}) {
  return showAppDialog<DateTime>(
    context: context,
    builder: (_) => _DateAlert(
      title: title,
      message: message,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      confirmText: confirmText,
    ),
  );
}

class _DateAlert extends StatefulWidget {
  const _DateAlert({
    required this.title,
    required this.message,
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
    required this.confirmText,
  });

  final String title;
  final String? message;
  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final String confirmText;

  @override
  State<_DateAlert> createState() => _DateAlertState();
}

class _DateAlertState extends State<_DateAlert> {
  late DateTime _value = widget.initialDate;
  final _text = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _text.text = MaterialLocalizations.of(context).formatCompactDate(_value);
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final picked = await showAppDatePicker(
      context: context,
      initialDate: _value,
      firstDate: widget.firstDate,
      lastDate: widget.lastDate,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _value = picked;
      _text.text = MaterialLocalizations.of(context).formatCompactDate(picked);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    void cancel() => Navigator.of(context).pop();
    void confirm() => Navigator.of(context).pop(_value);
    return AppAlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.message != null) ...[
            Text(widget.message!),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _text,
            readOnly: true,
            onTap: _pick,
            decoration: InputDecoration(
              suffixIcon: Icon(AppIcons.calendarTodayOutlined),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: cancel, child: Text(l10n.commonCancel)),
        TextButton(onPressed: confirm, child: Text(widget.confirmText)),
      ],
    );
  }
}

/// Result of [showAppRadioAlert].
class AppRadioAlertResult<T> {
  const AppRadioAlertResult(this.value);
  final T? value;
}

/// Radio alert dialog with options, cancel and confirm buttons.
Future<AppRadioAlertResult<T>?> showAppRadioAlert<T>(
  BuildContext context, {
  required String title,
  String? subtitle,
  required List<(T value, String label)> options,
  T? initialValue,
  String? confirmText,
  String? cancelText,
  bool cancelDestructive = false,
  bool barrierDismissible = true,
}) {
  return showAppDialog<AppRadioAlertResult<T>>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (_) => _RadioAlert<T>(
      title: title,
      message: subtitle,
      options: options,
      initialValue: initialValue,
      confirmText: confirmText,
      cancelText: cancelText,
      cancelDestructive: cancelDestructive,
    ),
  );
}

class _RadioAlert<T> extends StatefulWidget {
  const _RadioAlert({
    required this.title,
    required this.message,
    required this.options,
    required this.initialValue,
    required this.confirmText,
    required this.cancelText,
    required this.cancelDestructive,
  });

  final String title;
  final String? message;
  final List<(T, String)> options;
  final T? initialValue;
  final String? confirmText;
  final String? cancelText;
  final bool cancelDestructive;

  @override
  State<_RadioAlert<T>> createState() => _RadioAlertState<T>();
}

class _RadioAlertState<T> extends State<_RadioAlert<T>> {
  late T? _value = widget.initialValue;

  @override
  Widget build(BuildContext context) {
    final cancelText = widget.cancelText ?? context.l10n.commonCancel;
    final confirmText = widget.confirmText ?? context.l10n.commonOk;
    void cancel() => Navigator.of(context).pop();
    void confirm() => Navigator.of(context).pop(AppRadioAlertResult<T>(_value));
    final maxHeight = MediaQuery.sizeOf(context).height * 0.5;
    final rd = context.rd;
    final message = widget.message;
    return AppAlertDialog(
      title: Text(widget.title),
      contentPadding: const EdgeInsets.only(bottom: 14),
      content: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (message != null && message.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 0, 22, 8),
                  child: Text(message),
                ),
              for (final (value, label) in widget.options)
                Semantics(
                  checked: value == _value,
                  inMutuallyExclusiveGroup: true,
                  child: InkWell(
                    onTap: () => setState(() => _value = value),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 22),
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 48),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(color: rd.line, width: 0.5),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                label,
                                style: TextStyle(
                                  fontSize: 16,
                                  height: 1.3,
                                  fontWeight: value == _value
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                  color: value == _value ? rd.primary : rd.text,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            value == _value
                                ? Icon(Icons.check, size: 22, color: rd.primary)
                                : const SizedBox(width: 22),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: cancel,
          style: widget.cancelDestructive
              ? TextButton.styleFrom(foregroundColor: AppColors.danger)
              : null,
          child: Text(cancelText),
        ),
        TextButton(onPressed: confirm, child: Text(confirmText)),
      ],
    );
  }
}
