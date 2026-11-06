import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/redesign_providers.dart';
import '../../../../core/theme/redesign/rd_theme.dart';
import '../../../redesign/presentation/widgets/event/rd_form_widgets.dart';
import '../../../redesign/presentation/widgets/rd_widgets.dart';

import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';

/// Ionic login `forgotPassword()` alert: header "Passwort zurücksetzen", one
/// e-mail input (prefilled with the login e-mail, placeholder "E-Mail
/// eingeben..."), buttons Abbrechen / Zurücksetzen.
///
/// - iOS: `ion-alert` iOS – plain white input with a hairline border (no
///   focus outline or fill), the two buttons side by side,
/// - md: `ion-alert` md – underlined input and the uppercase text buttons
///   "ABBRECHEN  ZURÜCKSETZEN" right-aligned.
///
/// Returns the entered e-mail, or null when cancelled.
Future<String?> showResetPasswordDialog(
  BuildContext context, {
  String? email,
}) {
  // REDESIGN (E5): sheet from below in the Beta, same result.
  if (ProviderScope.containerOf(context, listen: false).read(redesignEnabledProvider)) {
    return showRdSheet<String>(context, ResetPasswordDialog(email: email, beta: true));
  }
  return showAppDialog<String>(
    context: context,
    builder: (_) => ResetPasswordDialog(email: email),
  );
}

class ResetPasswordDialog extends StatefulWidget {
  const ResetPasswordDialog({super.key, this.email, this.beta = false});

  final String? email;

  /// Beta look (content of an [showRdSheet] sheet).
  final bool beta;

  @override
  State<ResetPasswordDialog> createState() => _ResetPasswordDialogState();
}

class _ResetPasswordDialogState extends State<ResetPasswordDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.email);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _cancel() => Navigator.of(context).pop();

  void _confirm() => Navigator.of(context).pop(_controller.text);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (widget.beta) {
      final p = context.rd;
      return Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(header: true, child: Text(l10n.loginResetHeader, style: RdType.section(p))),
            const SizedBox(height: 6),
            Text(l10n.redesignLoginResetIntro, style: RdType.meta(p, size: 14)),
            const SizedBox(height: 12),
            RdGroupedList(
              children: [
                RdFieldRow(
                  label: l10n.loginEmail,
                  child: TextField(
                    controller: _controller,
                    autofocus: true,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    autofillHints: const [AutofillHints.email],
                    onSubmitted: (_) => _confirm(),
                    decoration: rdInputDecoration(p, l10n.loginEmailPlaceholder),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            RdPrimaryButton(label: l10n.redesignLoginResetSend, onPressed: _confirm),
          ],
        ),
      );
    }
    if (useIosLook(context)) {
      return IosAlertCard(
        title: Text(l10n.loginResetHeader),
        contentPadding: const EdgeInsets.fromLTRB(16, 0, 16, 21),
        content: IosAlertInput(
          controller: _controller,
          placeholder: l10n.loginEmailPlaceholder,
          keyboardType: TextInputType.emailAddress,
          autofocus: true,
          onSubmitted: (_) => _confirm(),
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: IosAlertButton(
                  bold: false,
                  onPressed: _cancel,
                  child: _OneLine(l10n.commonCancel),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: IosAlertButton(
                  bold: false,
                  onPressed: _confirm,
                  child: _OneLine(l10n.loginResetConfirm),
                ),
              ),
            ],
          ),
        ],
      );
    }

    // md alert: underlined input like the "Passwort ändern" alert.
    final theme = Theme.of(context);
    final line = UnderlineInputBorder(
      borderSide: BorderSide(color: theme.dividerColor),
    );
    return AppAlertDialog(
      title: Text(l10n.loginResetHeader),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.emailAddress,
        onSubmitted: (_) => _confirm(),
        decoration: InputDecoration(
          hintText: l10n.loginEmailPlaceholder,
          filled: false,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 13),
          border: line,
          enabledBorder: line,
          focusedBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _cancel,
          child: Text(l10n.commonCancel.toUpperCase()),
        ),
        TextButton(
          onPressed: _confirm,
          child: Text(l10n.loginResetConfirm.toUpperCase()),
        ),
      ],
    );
  }
}

/// Button label on one line: the shared iOS alert card is 280pt wide while
/// Ionic sizes an alert with an input to ≈313pt, where "Zurücksetzen"
/// still fits next to "Abbrechen".
class _OneLine extends StatelessWidget {
  const _OneLine(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(text, maxLines: 1, softWrap: false),
      );
}
