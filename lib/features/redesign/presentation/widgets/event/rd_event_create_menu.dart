import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/providers/role_permission_providers.dart';
import '../../../../../core/providers/team_org_providers.dart';
import '../../../../../core/providers/tenant_providers.dart';
import '../../../../../core/router/redesign_routes.dart';
import '../../../../../core/theme/redesign/rd_theme.dart';
import '../../../../../l10n/l10n.dart';
import '../../../../team_organization/presentation/pages/rd_meeting_page.dart'
    show rdMeetingRoute;
import '../../../../team_organization/presentation/widgets/rd_new_meeting_sheet.dart';
import '../../../data/rd_words.dart';

/// The single creation entry for the event list, as a floating button on
/// phones or a compact button in the desktop header.
/// Helpers only have one choice and go straight to the regular event form.
class RdEventCreateMenu extends ConsumerStatefulWidget {
  const RdEventCreateMenu({super.key, this.compact = false, this.initialDate});

  final bool compact;

  /// An already selected calendar day, shared by both creation flows.
  final DateTime? initialDate;

  @override
  ConsumerState<RdEventCreateMenu> createState() => _RdEventCreateMenuState();
}

class _RdEventCreateMenuState extends ConsumerState<RdEventCreateMenu> {
  final _controller = MenuController();
  final _buttonFocus = FocusNode();
  bool _open = false;
  bool _creatingMeeting = false;

  @override
  void dispose() {
    _buttonFocus.dispose();
    super.dispose();
  }

  void _createEvent() {
    if (!ref.read(canCreateAttendanceProvider)) return;
    context.push(RedesignRoutes.newEvent, extra: widget.initialDate);
  }

  Future<void> _createMeeting() async {
    if (_creatingMeeting ||
        !ref.read(isTeamLeaderProvider) ||
        !ref.read(canCreateAttendanceProvider)) {
      return;
    }
    final tenantId = ref.read(currentTenantIdProvider);
    setState(() => _creatingMeeting = true);
    try {
      final id = await showNewMeetingSheet(
        context,
        initialDate: widget.initialDate,
      );
      if (id != null &&
          mounted &&
          ref.read(currentTenantIdProvider) == tenantId &&
          ref.read(isTeamLeaderProvider)) {
        context.push(rdMeetingRoute(id));
      }
    } finally {
      if (mounted) setState(() => _creatingMeeting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final canCreate = ref.watch(canCreateAttendanceProvider);
    final canMeet = ref.watch(isTeamLeaderProvider);
    final kind = ref.watch(rdGroupKindProvider);
    ref.listen(currentTenantIdProvider, (_, __) => _controller.close());
    ref.listen(isTeamLeaderProvider, (_, __) => _controller.close());
    if (!canCreate) return const SizedBox.shrink();

    final menuWidth = math.min(300.0, MediaQuery.sizeOf(context).width - 32);
    final label = _open ? l10n.rdCreateMenuClose : l10n.redesignEventsNew;
    final icon = _open ? Icons.close : Icons.add;

    return MenuAnchor(
      controller: _controller,
      childFocusNode: _buttonFocus,
      consumeOutsideTap: true,
      useRootOverlay: true,
      // Align the right edges. At a phone's bottom edge the standard menu
      // flips above the button, retaining this gap; the header opens below.
      alignmentOffset: Offset(-menuWidth, 8),
      style: MenuStyle(
        alignment: AlignmentDirectional.bottomEnd,
        backgroundColor: WidgetStatePropertyAll(p.surface),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        padding: const WidgetStatePropertyAll(EdgeInsets.all(6)),
        elevation: const WidgetStatePropertyAll(6),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(19)),
        ),
      ),
      onOpen: () => setState(() => _open = true),
      onClose: () => setState(() => _open = false),
      menuChildren: [
        _CreateChoice(
          width: menuWidth - 12,
          icon: Icons.calendar_month_outlined,
          title: l10n.rdCreateMenuEvent(kind),
          subtitle: l10n.rdCreateMenuEventHint,
          onPressed: _createEvent,
        ),
        if (canMeet) ...[
          const Divider(height: 1),
          _CreateChoice(
            width: menuWidth - 12,
            icon: Icons.forum_outlined,
            title: l10n.rdTeamMeetingTypeName,
            subtitle: l10n.rdCreateMenuMeetingHint,
            onPressed: _createMeeting,
          ),
        ],
      ],
      builder: (context, controller, child) {
        void activate() {
          if (_creatingMeeting) return;
          if (!canMeet) {
            _createEvent();
          } else if (controller.isOpen) {
            controller.close();
          } else {
            controller.open();
          }
        }

        return Semantics(
          expanded: canMeet ? _open : null,
          child:
              widget.compact
                  ? SizedBox.square(
                    dimension: 44,
                    child: IconButton.filled(
                      key: const Key('rd-events-add'),
                      focusNode: _buttonFocus,
                      tooltip: label,
                      icon: Icon(icon, size: 22),
                      style: IconButton.styleFrom(
                        backgroundColor: p.primary,
                        foregroundColor: p.onPrimary,
                      ),
                      onPressed: activate,
                    ),
                  )
                  : FloatingActionButton(
                    key: const Key('rd-events-add'),
                    focusNode: _buttonFocus,
                    tooltip: label,
                    backgroundColor: p.primary,
                    foregroundColor: p.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    onPressed: activate,
                    child: Icon(icon, size: 28),
                  ),
        );
      },
    );
  }
}

class _CreateChoice extends StatelessWidget {
  const _CreateChoice({
    required this.width,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onPressed,
  });

  final double width;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    return MenuItemButton(
      onPressed: onPressed,
      style: MenuItemButton.styleFrom(padding: EdgeInsets.zero),
      child: SizedBox(
        width: width,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: p.soft,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, size: 21, color: p.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                        color: p.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(subtitle, style: RdType.meta(p, size: 12)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
