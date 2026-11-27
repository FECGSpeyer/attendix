import 'package:flutter/material.dart';

import '../../../../core/theme/redesign/rd_theme.dart';
import '../../../attendance/presentation/widgets/event/rd_form_widgets.dart';
import '../../../../shared/widgets/redesign/rd_widgets.dart';

import '../../../../l10n/l10n.dart';

/// Password reset sheet ("Passwort zurücksetzen"), prefilled with [email].
/// Returns the entered e-mail, or null when cancelled.
Future<String?> showResetPasswordDialog(
  BuildContext context, {
  String? email,
}) {
  return showRdSheet<String>(context, ResetPasswordDialog(email: email));
}

class ResetPasswordDialog extends StatefulWidget {
  const ResetPasswordDialog({super.key, this.email});

  final String? email;

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

  void _confirm() => Navigator.of(context).pop(_controller.text);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.rd;
    // Scrolls inside the sheet so the button stays reachable above the
    // keyboard on short screens.
    return SingleChildScrollView(
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
}
