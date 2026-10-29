import 'package:flutter/material.dart';

import '../../../core/utils/contact_links.dart';
import '../../../l10n/l10n.dart';

/// Row of contact tiles for a person: Anrufen · WhatsApp · Telegram · E-Mail.
///
/// Phone based tiles only show for a usable number, the mail tile only for a
/// valid address; with neither the bar takes no space.
class ContactActionBar extends StatelessWidget {
  const ContactActionBar({
    super.key,
    required this.phone,
    this.email,
    this.padding = const EdgeInsets.fromLTRB(16, 10, 16, 10),
  });

  final String? phone;
  final String? email;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final call = phoneCallUri(phone);
    final whatsApp = whatsAppUri(phone);
    final telegram = telegramUri(phone);
    final mail = mailUri(email);

    final actions = [
      if (call != null)
        _ContactAction(Icons.call_outlined, l10n.peopleFlutterContactCall,
            l10n.peopleFlutterContactCall, call),
      if (whatsApp != null)
        _ContactAction(Icons.chat_outlined, 'WhatsApp',
            l10n.peopleFlutterContactWhatsAppHint, whatsApp),
      if (telegram != null)
        _ContactAction(Icons.send_outlined, 'Telegram',
            l10n.peopleFlutterContactTelegramHint, telegram),
      if (mail != null)
        _ContactAction(Icons.mail_outline, l10n.peopleFlutterContactMail,
            l10n.peopleFlutterContactMailHint, mail),
    ];
    if (actions.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: padding,
      child: Row(
        children: [
          for (var i = 0; i < actions.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(child: _ContactTile(action: actions[i])),
          ],
        ],
      ),
    );
  }
}

class _ContactAction {
  const _ContactAction(this.icon, this.label, this.hint, this.uri);

  final IconData icon;
  final String label;
  final String hint;
  final Uri uri;
}

class _ContactTile extends StatelessWidget {
  const _ContactTile({required this.action});

  final _ContactAction action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = scheme.primary;
    return Tooltip(
      message: action.hint,
      excludeFromSemantics: true,
      child: Semantics(
        button: true,
        label: action.hint,
        excludeSemantics: true,
        child: Material(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => launchContactUri(action.uri),
            child: SizedBox(
              height: 56,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(action.icon, size: 20, color: color),
                  const SizedBox(height: 2),
                  Text(
                    action.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      // primary on the tint is below 4.5:1 for small text
                      color: scheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
