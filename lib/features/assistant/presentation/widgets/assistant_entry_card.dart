import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/assistant_providers.dart';
import '../../../../core/providers/redesign_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/router/redesign_routes.dart';
import '../../../../core/theme/redesign/rd_theme.dart';
import '../../../../l10n/l10n.dart';

/// Route of the chat assistant (same page in both designs).
const assistantRoute = '/settings/assistant';

/// Coloured card at the top of "Mehr" (old design) and "Ich" (new design)
/// that opens the chat assistant.
///
/// Shown when the admin switched the assistant on. While it is off, admins
/// and Verantwortliche see it too, with a hint that leads to the switch.
class AssistantEntryCard extends ConsumerWidget {
  const AssistantEntryCard({super.key, this.margin = EdgeInsets.zero});

  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(assistantEnabledProvider);
    final role = ref.watch(currentRoleProvider);
    final isLead = role.isAdmin || role.isResponsible;
    if (!enabled && !isLead) return const SizedBox.shrink();
    final redesign = ref.watch(redesignEnabledProvider);
    final l10n = context.l10n;
    final rd = context.rdSkin;
    final primary = rd?.primary ?? Theme.of(context).colorScheme.primary;
    // A second, cooler tone so the card stands out from the plain rows.
    final second = Color.lerp(primary, const Color(0xFF7C4DFF), 0.55)!;
    final radius = BorderRadius.circular(rd?.cardRadius ?? 16);

    void open() {
      if (enabled) {
        context.push(assistantRoute);
      } else {
        // Where the switch is: Rollen und Rechte › Was Mitglieder sehen (new
        // design), Einstellungen (old design).
        context.push(redesign ? RedesignRoutes.rolePermissions : '/settings/general');
      }
    }

    return Padding(
      padding: margin,
      child: Semantics(
        button: true,
        label: l10n.assistantEntryTitle,
        child: Material(
          color: Colors.transparent,
          borderRadius: radius,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: radius,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [primary, second],
              ),
              boxShadow: [
                BoxShadow(color: primary.withValues(alpha: 0.25), blurRadius: 14, offset: const Offset(0, 6)),
              ],
            ),
            child: InkWell(
              borderRadius: radius,
              onTap: open,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.auto_awesome, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  l10n.assistantEntryTitle,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.22),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  l10n.assistantBeta,
                                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            enabled ? l10n.assistantEntryHint : l10n.assistantEntryEnableHint,
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: Colors.white),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
