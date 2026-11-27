import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/providers/role_permission_providers.dart';
import '../../../../../core/providers/team_org_providers.dart';
import '../../../../../core/providers/tenant_providers.dart';
import '../../../../../core/redesign/rd_words.dart';
import '../../../../../core/router/redesign_routes.dart';
import '../../../../../core/theme/redesign/rd_theme.dart';
import '../../../../../l10n/l10n.dart';
import '../../../../../shared/widgets/adaptive/app_action_sheet.dart';
import '../../../../team_organization/presentation/pages/rd_meeting_page.dart'
    show rdMeetingRoute;
import '../../../../team_organization/presentation/widgets/rd_new_meeting_sheet.dart';

enum _CreateChoiceKind { event, meeting }

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
  bool _openingSheet = false;
  bool _creatingMeeting = false;

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

  Future<void> _openCreateMenu(BuildContext buttonContext) async {
    if (_openingSheet || _creatingMeeting) return;
    if (!ref.read(canCreateAttendanceProvider)) return;
    if (!ref.read(isTeamLeaderProvider)) {
      _createEvent();
      return;
    }

    final l10n = context.l10n;
    final kind = ref.read(rdGroupKindProvider);
    final tenantId = ref.read(currentTenantIdProvider);
    setState(() => _openingSheet = true);
    _CreateChoiceKind? choice;
    try {
      choice = await showAppActionSheet<_CreateChoiceKind>(
        context,
        title: l10n.redesignEventsNew,
        anchor: buttonContext,
        actions: [
          AppActionSheetAction(
            value: _CreateChoiceKind.event,
            icon: Icons.calendar_month_outlined,
            label: l10n.rdCreateMenuEvent(kind),
            subtitle: l10n.rdCreateMenuEventHint,
          ),
          AppActionSheetAction(
            value: _CreateChoiceKind.meeting,
            icon: Icons.forum_outlined,
            label: l10n.rdTeamMeetingTypeName,
            subtitle: l10n.rdCreateMenuMeetingHint,
          ),
        ],
      );
    } finally {
      if (mounted) setState(() => _openingSheet = false);
    }

    if (!mounted || ref.read(currentTenantIdProvider) != tenantId) return;
    switch (choice) {
      case _CreateChoiceKind.event:
        _createEvent();
      case _CreateChoiceKind.meeting:
        await _createMeeting();
      case null:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final canCreate = ref.watch(canCreateAttendanceProvider);
    if (!canCreate) return const SizedBox.shrink();

    return Builder(
      builder: (buttonContext) {
        void activate() => _openCreateMenu(buttonContext);

        return widget.compact
            ? SizedBox.square(
              dimension: 44,
              child: IconButton.filled(
                key: const Key('rd-events-add'),
                tooltip: l10n.redesignEventsNew,
                icon: const Icon(Icons.add, size: 22),
                style: IconButton.styleFrom(
                  backgroundColor: p.primary,
                  foregroundColor: p.onPrimary,
                ),
                onPressed: activate,
              ),
            )
            : FloatingActionButton(
              key: const Key('rd-events-add'),
              tooltip: l10n.redesignEventsNew,
              backgroundColor: p.primary,
              foregroundColor: p.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              onPressed: activate,
              child: const Icon(Icons.add, size: 28),
            );
      },
    );
  }
}
