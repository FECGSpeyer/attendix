import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/event_list_utils.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/repositories/sign_in_out_repository.dart';
import '../../../../shared/widgets/event_list/event_list_widgets.dart';
import '../../../../shared/widgets/event_list/excuse_reason_sheet.dart';

/// Route of the Dateiablage (files module, `/settings/files?path=<folder>`).
const String kFilesRoute = '/settings/files';

/// Opens the Dateiablage folder of a Termin (Ionic openFilesFolder).
Future<void> openFilesFolderRoute(BuildContext context, String path) async {
  final uri = Uri(path: kFilesRoute, queryParameters: {'path': path});
  await GoRouter.of(context).push(uri.toString());
}

/// Direct buttons of the current card (Zusagen / Verspätung / Absagen).
class QuickActions {
  const QuickActions({
    required this.present,
    required this.canSignin,
    required this.late,
    required this.excused,
    required this.blocked,
    required this.allowLate,
    required this.allowExcuse,
  });

  final bool present;
  final bool canSignin;
  final bool late;
  final bool excused;
  final bool blocked;
  final bool allowLate;
  final bool allowExcuse;
}

/// Shared sign in/out flows of "Meine Termine" and the cross-tenant
/// "Übersicht" (Ionic SignoutPage / OverviewPage).
class SelfServiceEventActions {
  SelfServiceEventActions({
    required this.absenceReasons,
    required this.lateReasons,
    required this.signIn,
    required this.signOut,
    required this.updateNote,
    this.saveRegistrationAnswers,
    this.openPlan,
    this.canAccessFiles,
    this.showAllAttendances = false,
    this.supportsRegistrationFields = true,
  });

  final List<String> absenceReasons;
  final List<String> lateReasons;
  final Future<bool> Function(CrossTenantPersonAttendance att, String note) signIn;
  final Future<bool> Function(CrossTenantPersonAttendance att, String reason, bool isLate) signOut;
  final Future<bool> Function(CrossTenantPersonAttendance att, String note) updateNote;
  final Future<bool> Function(CrossTenantPersonAttendance att, Map<String, dynamic> answers)?
      saveRegistrationAnswers;
  final Future<void> Function(CrossTenantPersonAttendance att)? openPlan;
  final bool Function(CrossTenantPersonAttendance att)? canAccessFiles;
  final bool showAllAttendances;
  final bool supportsRegistrationFields;

  /// In "alle Termine" mode the person may not be part of a Termin.
  bool isOwn(CrossTenantPersonAttendance att) => !showAllAttendances || att.isMember;

  bool hasFilesFolder(CrossTenantPersonAttendance att) =>
      (att.filesFolder?.isNotEmpty ?? false) && (canAccessFiles?.call(att) ?? false);

  List<String> _availableStatusesValues(CrossTenantPersonAttendance att) =>
      att.attendanceType?.availableStatuses?.map((s) => s.name).toList() ?? const [];

  bool _allows(CrossTenantPersonAttendance att, AttendanceStatus status) {
    final type = att.attendanceType;
    if (type == null || type.availableStatuses == null) return true;
    return _availableStatusesValues(att).contains(status.name);
  }

  /// Quick actions of the current card; null when not applicable.
  QuickActions? quickActions(CrossTenantPersonAttendance att) {
    if (!isOwn(att) || att.id == null) return null;
    return QuickActions(
      present: att.text == 'X',
      canSignin: att.text != 'X' && EventListUtils.isSigninOpen(att.deadline),
      late: att.status == AttendanceStatus.lateExcused,
      excused: att.status == AttendanceStatus.excused,
      blocked: att.isExcusedStatus || att.text == 'A',
      allowLate: _allows(att, AttendanceStatus.late),
      allowExcuse: _allows(att, AttendanceStatus.excused),
    );
  }

  /// The three buttons in one row (Zusagen / Verspätung / Absagen).
  List<Widget> quickActionButtons(BuildContext context, CrossTenantPersonAttendance att) {
    final qa = quickActions(att);
    if (qa == null) return const [];
    return [
      EventActionButton(
        label: 'Zusagen',
        active: qa.present,
        activeColor: AppColors.success,
        onPressed: qa.canSignin ? () => handleSigninWithFields(context, att) : null,
      ),
      if (qa.allowLate)
        EventActionButton(
          label: 'Verspätung',
          active: qa.late,
          activeColor: EventListUtils.rosa,
          onPressed: qa.blocked ? null : () => quickSignout(context, att, isLate: true),
        ),
      if (qa.allowExcuse)
        EventActionButton(
          label: 'Absagen',
          active: qa.excused,
          activeColor: AppColors.warning,
          onPressed: qa.blocked ? null : () => quickSignout(context, att, isLate: false),
        ),
    ];
  }

  /// Chips below a Termin; tappable chips act directly.
  List<Widget> chips(
    BuildContext context,
    CrossTenantPersonAttendance att, {
    bool withPlan = true,
  }) {
    return [
      if (att.deadline != null && att.deadline!.isNotEmpty)
        EventChip(label: EventListUtils.deadlineText(att.deadline), danger: true),
      if (att.notes != null && att.notes!.isNotEmpty)
        EventChip(label: 'Notiz: ${att.notes}'),
      if (withPlan && att.hasPlan && openPlan != null)
        EventChip(
          label: 'Ablaufplan',
          icon: Icons.description_outlined,
          onTap: () => openPlan!(att),
        ),
      if (att.description != null && att.description!.isNotEmpty)
        EventChip(
          label: 'Infos',
          icon: Icons.info_outline,
          onTap: () => showEventDescriptionSheet(context, att.description!),
        ),
      if (att.attachmentUrl != null && att.attachmentUrl!.isNotEmpty)
        EventChip(
          label: att.attachmentName?.isNotEmpty == true ? att.attachmentName! : 'Anhang',
          icon: Icons.attach_file,
          onTap: () => openEventAttachment(att.attachmentUrl!),
        ),
      if (hasFilesFolder(att))
        EventChip(
          label: 'Dateien',
          icon: Icons.folder_outlined,
          onTap: () => openFilesFolderRoute(context, att.filesFolder!),
        ),
      if (att.place != null && att.place!.isNotEmpty)
        EventChip(
          label: 'Route',
          icon: Icons.navigation_outlined,
          onTap: () => openEventNavigation(context, att.place!),
        ),
    ];
  }

  /// Absagen / Verspätung with the reason sheet.
  Future<void> quickSignout(
    BuildContext context,
    CrossTenantPersonAttendance att, {
    required bool isLate,
  }) async {
    final id = att.id;
    if (id == null) return;
    final reason = await showExcuseReasonSheet(
      context,
      isLate: isLate,
      isToday: att.isRunning,
      absenceReasons: absenceReasons,
      lateReasons: lateReasons,
    );
    if (reason == null || !context.mounted) return;
    final ok = await signOut(att, reason, isLate);
    if (!context.mounted) return;
    if (ok) {
      ToastHelper.showSuccess(
        context,
        isLate
            ? 'Vielen Dank für die Info und Gottes Segen dir!'
            : 'Vielen Dank für deine rechtzeitige Abmeldung und Gottes Segen dir.',
      );
    } else {
      ToastHelper.showError(context, 'Abmeldung fehlgeschlagen. Bitte versuche es erneut.');
    }
  }

  /// Sign in; asks for the registration fields of the type first.
  Future<void> handleSigninWithFields(
    BuildContext context,
    CrossTenantPersonAttendance att, {
    String note = '',
    bool editMode = false,
  }) async {
    final fields = supportsRegistrationFields ? att.registrationFields : const [];
    if (fields.isEmpty) {
      if (!editMode) await _signIn(context, att, note);
      return;
    }
    final answers = await showRegistrationFieldsSheet(
      context,
      fields: att.registrationFields,
      existing: att.registrationAnswers,
      editMode: editMode,
    );
    if (answers == null || !context.mounted) return;
    final saved = await saveRegistrationAnswers?.call(att, answers) ?? false;
    if (!context.mounted) return;
    if (!saved) {
      ToastHelper.showError(context, 'Anmeldefelder konnten nicht gespeichert werden.');
      return;
    }
    if (editMode) {
      ToastHelper.showSuccess(context, 'Anmeldefelder gespeichert.');
      return;
    }
    await _signIn(context, att.copyWith(registrationAnswers: answers), note);
  }

  Future<void> _signIn(BuildContext context, CrossTenantPersonAttendance att, String note) async {
    final ok = await signIn(att, note);
    if (!context.mounted) return;
    if (ok) {
      ToastHelper.showSuccess(context, 'Schön, dass du dabei bist 🙂');
    } else {
      ToastHelper.showError(context, 'Anmeldung fehlgeschlagen. Bitte versuche es erneut.');
    }
  }

  Future<void> _signInWithNote(BuildContext context, CrossTenantPersonAttendance att) async {
    final note = await showEventNoteDialog(
      context,
      title: 'Notiz für Anmeldung',
      confirmText: 'Anmelden',
    );
    if (note == null || !context.mounted) return;
    await handleSigninWithFields(context, att, note: note);
  }

  Future<void> _editNote(BuildContext context, CrossTenantPersonAttendance att) async {
    final note = await showEventNoteDialog(
      context,
      title: 'Notiz anpassen',
      confirmText: 'Speichern',
      initialValue: att.notes ?? '',
    );
    if (note == null || !context.mounted) return;
    final ok = await updateNote(att, note);
    if (!context.mounted) return;
    if (ok) {
      ToastHelper.showSuccess(context, 'Notiz erfolgreich aktualisiert.');
    } else {
      ToastHelper.showError(context, 'Notiz konnte nicht gespeichert werden.');
    }
  }

  /// Builds the menu entries following the Ionic rules.
  List<SelfServiceAction> buildActions(
    CrossTenantPersonAttendance att, {
    bool hideQuickActions = false,
  }) {
    final isExcused = att.isExcusedStatus;
    final canSignin = EventListUtils.isSigninOpen(att.deadline);
    final actions = <SelfServiceAction>[];

    final signInAllowed = att.text != 'X' && canSignin;
    final excuseAllowed = _allows(att, AttendanceStatus.excused);
    final lateAllowed = _allows(att, AttendanceStatus.late);
    final qa = hideQuickActions ? quickActions(att) : null;

    if (signInAllowed && qa == null) {
      actions.add(SelfServiceAction(
        isExcused ? SelfServiceActionType.undoSignout : SelfServiceActionType.signIn,
      ));
    }
    if (signInAllowed && !isExcused) {
      actions.add(const SelfServiceAction(SelfServiceActionType.signInWithNote));
    }
    final blockedBySignout = isExcused || att.text == 'A';
    if (excuseAllowed && !blockedBySignout && !(qa?.allowExcuse ?? false)) {
      actions.add(const SelfServiceAction(SelfServiceActionType.signOut));
    }
    if (lateAllowed && !blockedBySignout && !(qa?.allowLate ?? false)) {
      actions.add(const SelfServiceAction(SelfServiceActionType.enterLate));
    }
    final isSignedIn =
        att.status == AttendanceStatus.present || att.status == AttendanceStatus.late;
    if (supportsRegistrationFields && isSignedIn && canSignin && att.registrationFields.isNotEmpty) {
      actions.add(const SelfServiceAction(SelfServiceActionType.editRegistrationFields));
    }
    if (att.text == 'X') {
      actions.add(const SelfServiceAction(SelfServiceActionType.editNote));
    }
    if (att.hasPlan && openPlan != null && !hideQuickActions) {
      actions.add(const SelfServiceAction(SelfServiceActionType.showPlan));
    }
    if ((att.description?.isNotEmpty ?? false) && !hideQuickActions) {
      actions.add(const SelfServiceAction(SelfServiceActionType.showDescription));
    }
    if ((att.attachmentUrl?.isNotEmpty ?? false) && !hideQuickActions) {
      actions.add(const SelfServiceAction(SelfServiceActionType.openAttachment));
    }
    if ((att.place?.isNotEmpty ?? false) && !hideQuickActions) {
      actions.add(const SelfServiceAction(SelfServiceActionType.openNavigation));
    }
    if (hasFilesFolder(att) && !hideQuickActions) {
      actions.add(const SelfServiceAction(SelfServiceActionType.openFiles));
    }
    return actions;
  }

  /// Action sheet of a Termin (Ionic presentActionSheetForChoice).
  ///
  /// [hideQuickActions]: on the current card Zusagen / Verspätung / Absagen
  /// and the chips are buttons already, so the sheet only offers the rest.
  Future<void> presentActions(
    BuildContext context,
    CrossTenantPersonAttendance att, {
    bool hideQuickActions = false,
  }) async {
    // Read-only for non-participants in show-all mode
    if (showAllAttendances && att.id == null) {
      if (att.description?.isNotEmpty ?? false) {
        await showEventDescriptionSheet(context, att.description!);
      } else if (att.hasPlan && openPlan != null) {
        await openPlan!(att);
      } else if (att.attachmentUrl?.isNotEmpty ?? false) {
        await openEventAttachment(att.attachmentUrl!);
      } else if (att.place?.isNotEmpty ?? false) {
        await openEventNavigation(context, att.place!);
      } else if (hasFilesFolder(att)) {
        await openFilesFolderRoute(context, att.filesFolder!);
      }
      return;
    }

    final actions = buildActions(att, hideQuickActions: hideQuickActions);
    if (actions.isEmpty) {
      ToastHelper.showWarning(context, 'Für diesen Termin sind keine Aktionen verfügbar.');
      return;
    }

    final selected = await showModalBottomSheet<SelfServiceActionType>(
      context: context,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(att.eventTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(att.eventMeta(withDate: true)),
              ),
              const Divider(height: 1),
              for (final action in actions)
                ListTile(
                  leading: Icon(action.type.icon),
                  title: Text(action.type.label),
                  onTap: () => Navigator.pop(ctx, action.type),
                ),
              ListTile(
                leading: const Icon(Icons.close, color: AppColors.danger),
                title: const Text('Abbrechen', style: TextStyle(color: AppColors.danger)),
                onTap: () => Navigator.pop(ctx),
              ),
            ],
          ),
        ),
      ),
    );
    if (selected == null || !context.mounted) return;

    switch (selected) {
      case SelfServiceActionType.signIn:
      case SelfServiceActionType.undoSignout:
        await handleSigninWithFields(context, att);
      case SelfServiceActionType.signInWithNote:
        await _signInWithNote(context, att);
      case SelfServiceActionType.signOut:
        await quickSignout(context, att, isLate: false);
      case SelfServiceActionType.enterLate:
        await quickSignout(context, att, isLate: true);
      case SelfServiceActionType.editRegistrationFields:
        await handleSigninWithFields(context, att, editMode: true);
      case SelfServiceActionType.editNote:
        await _editNote(context, att);
      case SelfServiceActionType.showPlan:
        await openPlan?.call(att);
      case SelfServiceActionType.showDescription:
        await showEventDescriptionSheet(context, att.description ?? '');
      case SelfServiceActionType.openAttachment:
        await openEventAttachment(att.attachmentUrl!);
      case SelfServiceActionType.openNavigation:
        await openEventNavigation(context, att.place!);
      case SelfServiceActionType.openFiles:
        await openFilesFolderRoute(context, att.filesFolder!);
    }
  }
}

/// Entries of the Termin action sheet.
enum SelfServiceActionType {
  signIn('Anmelden', Icons.check_circle_outline),
  undoSignout('Abmeldung zurücknehmen', Icons.undo),
  signInWithNote('Anmelden mit Notiz', Icons.edit_note),
  signOut('Abmelden', Icons.cancel_outlined),
  enterLate('Verspätung eintragen', Icons.schedule),
  editRegistrationFields('Anmeldefelder anpassen', Icons.assignment_outlined),
  editNote('Notiz anpassen', Icons.sticky_note_2_outlined),
  showPlan('Ablaufplan anzeigen', Icons.description_outlined),
  showDescription('Beschreibung anzeigen', Icons.info_outline),
  openAttachment('Anhang öffnen', Icons.attach_file),
  openNavigation('Navigation öffnen', Icons.navigation_outlined),
  openFiles('Dateiablage öffnen', Icons.folder_open_outlined);

  const SelfServiceActionType(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// One entry of the action sheet.
class SelfServiceAction {
  const SelfServiceAction(this.type);

  final SelfServiceActionType type;
}
