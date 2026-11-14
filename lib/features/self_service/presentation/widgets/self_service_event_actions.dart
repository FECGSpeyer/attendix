import 'package:flutter/material.dart';
import 'package:attendix/core/theme/app_icons.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/redesign/rd_theme.dart';
import '../../../../core/utils/event_list_utils.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/attendance/attendance.dart';
import '../../../../data/repositories/sign_in_out_repository.dart';
import '../../../../shared/widgets/event_list/event_list_widgets.dart';
import '../../../../shared/widgets/event_list/excuse_reason_sheet.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';

/// Route of the Dateiablage (files module, `/settings/files?path=<folder>`).
const String kFilesRoute = '/settings/files';

/// Opens the Dateiablage folder of a Termin (Ionic openFilesFolder).
///
/// ASTRA_FILES: with [switchToTenantId] (a Termin of another instance in the
/// cross-tenant "Übersicht") it goes through `/open-file` like Ionic
/// (`FilesService.getFolderOpenParams`): that route switches the instance
/// first, checks the files access there and then opens the folder.
Future<void> openFilesFolderRoute(BuildContext context, String path, {int? switchToTenantId}) async {
  if (switchToTenantId != null) {
    final uri = Uri(path: '/open-file', queryParameters: {
      'tenantId': '$switchToTenantId',
      'path': path,
      'folder': '1',
    });
    GoRouter.of(context).go(uri.toString());
    return;
  }
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
    this.songCountOf,
    this.openSongs,
    this.canAccessFiles,
    this.currentTenantId,
    this.showAllAttendances = false,
    this.supportsRegistrationFields = true,
    this.overviewMode = false,
  });

  final List<String> absenceReasons;
  final List<String> lateReasons;
  /// `null`: the callback already reported the outcome itself (duty
  /// confirmation, SOL_FIX35), so no sign-in toast follows.
  final Future<bool?> Function(CrossTenantPersonAttendance att, String note) signIn;
  final Future<bool> Function(CrossTenantPersonAttendance att, String reason, bool isLate) signOut;
  final Future<bool> Function(CrossTenantPersonAttendance att, String note) updateNote;
  final Future<bool> Function(CrossTenantPersonAttendance att, Map<String, dynamic> answers)?
      saveRegistrationAnswers;
  final Future<void> Function(CrossTenantPersonAttendance att)? openPlan;

  /// Ionic 4.17.26: number of Werke selected for a Termin ("♪ n Werke" chip,
  /// "Werke anzeigen" entry) and the Werke sheet.
  final int Function(CrossTenantPersonAttendance att)? songCountOf;
  final Future<void> Function(CrossTenantPersonAttendance att)? openSongs;

  int songCount(CrossTenantPersonAttendance att) =>
      openSongs == null ? 0 : (songCountOf?.call(att) ?? 0);
  final bool Function(CrossTenantPersonAttendance att)? canAccessFiles;

  /// ASTRA_FILES: set in the cross-tenant "Übersicht" – files of a Termin
  /// from another instance open after switching to that instance.
  final int? currentTenantId;
  final bool showAllAttendances;
  final bool supportsRegistrationFields;

  /// P10_SELF_PLAN: cross-tenant "Übersicht" (Ionic OverviewPage): the
  /// sheet has no "Abmeldung zurücknehmen", Ablaufplan or Route entries and
  /// the deadline chip only shows within 3 days before the deadline
  /// ("Anmeldefrist: …", `selfService.deadline`).
  final bool overviewMode;

  /// Deadline chip text, or null when no chip is shown.
  String? deadlineChipText(CrossTenantPersonAttendance att, {DateTime? now}) {
    final deadline = att.deadline;
    if (deadline == null || deadline.isEmpty) return null;
    if (!overviewMode) return EventListUtils.deadlineText(deadline, now: now);
    // Local wall time like the sign-out check (Ionic's overview chip read
    // the stored value as an instant and showed it 1-2 h late).
    final parsed = EventListUtils.deadlineLocal(deadline);
    if (parsed == null) return null;
    final current = now ?? DateTime.now();
    if (!current.isBefore(parsed) || parsed.difference(current).inDays > 3) return null;
    return l10nWithoutContext.selfServiceDeadline(DateFormat('${dateFmt()} HH:mm').format(parsed));
  }

  /// In "alle Termine" mode the person may not be part of a Termin.
  bool isOwn(CrossTenantPersonAttendance att) => !showAllAttendances || att.isMember;

  bool hasFilesFolder(CrossTenantPersonAttendance att) =>
      (att.filesFolder?.isNotEmpty ?? false) && (canAccessFiles?.call(att) ?? false);

  /// Ionic openFilesFolder: guarded by [hasFilesFolder]; a Termin of another
  /// instance switches the instance first (ASTRA_FILES).
  Future<void> openFilesFolder(BuildContext context, CrossTenantPersonAttendance att) async {
    if (!hasFilesFolder(att)) return;
    final otherTenant = currentTenantId != null && att.tenantId != currentTenantId;
    await openFilesFolderRoute(
      context,
      att.filesFolder!,
      switchToTenantId: otherTenant ? att.tenantId : null,
    );
  }

  List<String> _availableStatusesValues(CrossTenantPersonAttendance att) =>
      att.attendanceType?.availableStatuses?.map((s) => s.name).toList() ?? const [];

  bool _allows(CrossTenantPersonAttendance att, AttendanceStatus status) {
    final type = att.attendanceType;
    if (type == null || type.availableStatuses == null) return true;
    return _availableStatusesValues(att).contains(status.name);
  }

  /// Quick actions of the current card; null when not applicable.
  /// [anyLate]: the Beta also counts "Verspätet" (status 3, e.g. set by the
  /// leads) as "kommt später", like the leads' lists show it; the classic
  /// page keeps Ionic's check for "Verspätet (entschuldigt)" only.
  QuickActions? quickActions(CrossTenantPersonAttendance att, {bool anyLate = false}) {
    if (!isOwn(att) || att.id == null) return null;
    return QuickActions(
      present: att.text == 'X',
      canSignin: att.text != 'X' && EventListUtils.isSigninOpen(att.deadline),
      late: anyLate ? att.status.isLate : att.status == AttendanceStatus.lateExcused,
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
        label: context.l10n.signoutAccept,
        active: qa.present,
        activeColor: AppColors.success,
        onPressed: qa.canSignin ? () => handleSigninWithFields(context, att) : null,
      ),
      if (qa.allowLate)
        EventActionButton(
          label: context.l10n.signoutLateButton,
          active: qa.late,
          activeColor: EventListUtils.rosa,
          onPressed: qa.blocked ? null : () => quickSignout(context, att, isLate: true),
        ),
      if (qa.allowExcuse)
        EventActionButton(
          label: context.l10n.signoutDecline,
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
      if (deadlineChipText(att) case final deadline?)
        EventChip(label: deadline, danger: true),
      if (att.notes != null && att.notes!.isNotEmpty)
        EventChip(label: context.l10n.signoutNoteChip(att.notes!)),
      if (songCount(att) case final count when count > 0)
        EventChip(
          label: context.l10n.attendanceSongsChip(count),
          icon: AppIcons.musicNoteOutlined,
          onTap: () => openSongs!(att),
        ),
      if (withPlan && att.hasPlan && openPlan != null)
        EventChip(
          label: context.l10n.signoutRunSheet,
          icon: AppIcons.descriptionOutlined,
          onTap: () => openPlan!(att),
        ),
      if (att.description != null && att.description!.isNotEmpty)
        EventChip(
          label: context.l10n.signoutInfos,
          icon: AppIcons.infoOutline,
          onTap: () => showEventDescriptionSheet(context, att.description!),
        ),
      if (att.attachmentUrl != null && att.attachmentUrl!.isNotEmpty)
        EventChip(
          label: att.attachmentName?.isNotEmpty == true ? att.attachmentName! : context.l10n.selfServiceAttachment,
          icon: AppIcons.attachFile,
          onTap: () => openEventAttachment(att.attachmentUrl!),
        ),
      if (hasFilesFolder(att))
        EventChip(
          label: context.l10n.signoutFiles,
          icon: AppIcons.folderOutlined,
          onTap: () => openFilesFolder(context, att),
        ),
      if (att.place != null && att.place!.isNotEmpty)
        EventChip(
          label: context.l10n.signoutRoute,
          icon: AppIcons.navigationOutlined,
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
    await submitSignout(context, att, reason, isLate: isLate);
  }

  /// Saves an Absage / Verspätung with [reason] and reports the outcome
  /// (shared by the reason sheet and the new design's sign-out sheet).
  Future<void> submitSignout(
    BuildContext context,
    CrossTenantPersonAttendance att,
    String reason, {
    required bool isLate,
  }) async {
    if (att.id == null) return;
    final ok = await signOut(att, reason, isLate);
    if (!context.mounted) return;
    if (ok) {
      ToastHelper.showSuccess(
        context,
        isLate
            ? context.l10n.signoutThanksLate
            : context.l10n.signoutThanksSignout,
      );
    } else {
      ToastHelper.showError(context, context.l10n.signoutFlutterSignoutFailed);
    }
  }

  /// Sign in; asks for the registration fields of the type first.
  Future<void> handleSigninWithFields(
    BuildContext context,
    CrossTenantPersonAttendance att, {
    String note = '',
    bool editMode = false,
  }) async {
    final fields = supportsRegistrationFields ? att.registrationFields : const <RegistrationField>[];
    if (fields.isEmpty) {
      if (!editMode) await _signIn(context, att, note);
      return;
    }
    // UX_SELF: one field -> alert, 2+ fields -> sheet (Ionic handleSigninWithFields)
    final Map<String, dynamic>? answers;
    if (fields.length == 1) {
      answers = await showSingleRegistrationFieldDialog(
        context,
        field: fields.first,
        existing: att.registrationAnswers?[fields.first.id],
        editMode: editMode,
      );
      if (answers == null || !context.mounted) return;
      final missing = missingRegistrationField(fields, answers);
      if (missing != null) {
        ToastHelper.showWarning(context, context.l10n.signoutFillField(missing));
        return;
      }
    } else {
      answers = await showRegistrationFieldsSheet(
        context,
        fields: att.registrationFields,
        existing: att.registrationAnswers,
        editMode: editMode,
      );
    }
    if (answers == null || !context.mounted) return;
    final saved = await saveRegistrationAnswers?.call(att, answers) ?? false;
    if (!context.mounted) return;
    if (!saved) {
      ToastHelper.showError(context, context.l10n.signoutFlutterFieldsSaveFailed);
      return;
    }
    if (editMode) {
      ToastHelper.showSuccess(context, context.l10n.signoutRegistrationFieldsSaved);
      return;
    }
    await _signIn(context, att.copyWith(registrationAnswers: answers), note);
  }

  Future<void> _signIn(BuildContext context, CrossTenantPersonAttendance att, String note) async {
    final ok = await signIn(att, note);
    if (ok == null || !context.mounted) return;
    if (ok) {
      ToastHelper.showSuccess(context, context.l10n.signoutGladYouCome);
    } else {
      ToastHelper.showError(context, context.l10n.signoutFlutterSigninFailed);
    }
  }

  Future<void> _signInWithNote(BuildContext context, CrossTenantPersonAttendance att) async {
    final note = await showEventNoteDialog(
      context,
      title: context.l10n.signoutNoteForSignin,
      confirmText: context.l10n.signoutSignIn,
    );
    if (note == null || !context.mounted) return;
    await handleSigninWithFields(context, att, note: note);
  }

  Future<void> _editNote(BuildContext context, CrossTenantPersonAttendance att) async {
    final note = await showEventNoteDialog(
      context,
      title: context.l10n.signoutEditNote,
      confirmText: context.l10n.commonSave,
      initialValue: att.notes ?? '',
    );
    if (note == null || !context.mounted) return;
    final ok = await updateNote(att, note);
    if (!context.mounted) return;
    if (ok) {
      ToastHelper.showSuccess(context, context.l10n.signoutNoteUpdated);
    } else {
      ToastHelper.showError(context, context.l10n.signoutFlutterNoteSaveFailed);
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
        isExcused && !overviewMode ? SelfServiceActionType.undoSignout : SelfServiceActionType.signIn,
      ));
    }
    // PARITY_SELF: Ionic OverviewPage only filters by the status letter:
    // 'E' / 'A' drop Abmelden + Verspätung eintragen, 'Anmelden mit Notiz'
    // stays; 'L' (Verspätet / Verspätung gemeldet) keeps all of them.
    // Ionic SignoutPage additionally blocks them for every excused status.
    if (signInAllowed && (overviewMode || !isExcused)) {
      actions.add(const SelfServiceAction(SelfServiceActionType.signInWithNote));
    }
    final blockedBySignout = overviewMode
        ? att.text == 'E' || att.text == 'A'
        : isExcused || att.text == 'A';
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
    if (songCount(att) > 0 && !hideQuickActions) {
      actions.add(const SelfServiceAction(SelfServiceActionType.showSongs));
    }
    if (att.hasPlan && openPlan != null && !hideQuickActions && !overviewMode) {
      actions.add(const SelfServiceAction(SelfServiceActionType.showPlan));
    }
    if ((att.description?.isNotEmpty ?? false) && !hideQuickActions) {
      actions.add(const SelfServiceAction(SelfServiceActionType.showDescription));
    }
    if ((att.attachmentUrl?.isNotEmpty ?? false) && !hideQuickActions) {
      actions.add(const SelfServiceAction(SelfServiceActionType.openAttachment));
    }
    if ((att.place?.isNotEmpty ?? false) && !hideQuickActions && !overviewMode) {
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
        await openFilesFolder(context, att);
      }
      return;
    }

    final actions = buildActions(att, hideQuickActions: hideQuickActions);
    if (actions.isEmpty) {
      ToastHelper.showWarning(context, context.l10n.signoutNoActions);
      return;
    }

    // SEL-06: Ionic `actionSheetController.create({ buttons })` – no header
    // and no icons (Beta keeps its title, meta line and icons).
    final classic = context.rdSkin == null;
    final selected = await showAppActionSheet<SelfServiceActionType>(
      context,
      title: classic ? null : att.eventTitle,
      message: classic ? null : att.eventMeta(withDate: true),
      cancelDestructive: true,
      actions: [
        for (final action in actions)
          AppActionSheetAction(
            value: action.type,
            icon: classic ? null : action.type.icon,
            label: action.type.label(context.l10n),
          ),
      ],
    );
    if (selected == null || !context.mounted) return;
    await runAction(context, att, selected);
  }

  /// Runs one entry of the action sheet (also offered as rows on the new
  /// design's Termin page).
  Future<void> runAction(
    BuildContext context,
    CrossTenantPersonAttendance att,
    SelfServiceActionType selected,
  ) async {
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
      case SelfServiceActionType.showSongs:
        await openSongs?.call(att);
      case SelfServiceActionType.showPlan:
        await openPlan?.call(att);
      case SelfServiceActionType.showDescription:
        await showEventDescriptionSheet(context, att.description ?? '');
      case SelfServiceActionType.openAttachment:
        await openEventAttachment(att.attachmentUrl!);
      case SelfServiceActionType.openNavigation:
        await openEventNavigation(context, att.place!);
      case SelfServiceActionType.openFiles:
        await openFilesFolder(context, att);
    }
  }
}

/// Entries of the Termin action sheet.
enum SelfServiceActionType {
  signIn,
  undoSignout,
  signInWithNote,
  signOut,
  enterLate,
  editRegistrationFields,
  editNote,
  showSongs,
  showPlan,
  showDescription,
  openAttachment,
  openNavigation,
  openFiles;

  IconData get icon => switch (this) {
        signIn => AppIcons.checkCircleOutline,
        undoSignout => AppIcons.undo,
        signInWithNote => AppIcons.editNote,
        signOut => AppIcons.cancelOutlined,
        enterLate => AppIcons.schedule,
        editRegistrationFields => AppIcons.assignmentOutlined,
        editNote => AppIcons.stickyNote2Outlined,
        showSongs => AppIcons.musicNoteOutlined,
        showPlan => AppIcons.descriptionOutlined,
        showDescription => AppIcons.infoOutline,
        openAttachment => AppIcons.attachFile,
        openNavigation => AppIcons.navigationOutlined,
        openFiles => AppIcons.folderOpenOutlined,
      };

  /// Ionic signout.* action sheet labels.
  String label(AppLocalizations l10n) => switch (this) {
        signIn => l10n.signoutSignIn,
        undoSignout => l10n.signoutUndoSignout,
        signInWithNote => l10n.signoutSignInWithNote,
        signOut => l10n.signoutSignOut,
        enterLate => l10n.signoutEnterLate,
        editRegistrationFields => l10n.signoutEditRegistrationFields,
        editNote => l10n.signoutEditNote,
        showSongs => l10n.attendanceSongsShow,
        showPlan => l10n.signoutShowRunSheet,
        showDescription => l10n.signoutShowDescription,
        openAttachment => l10n.signoutOpenAttachment,
        openNavigation => l10n.signoutOpenNavigation,
        openFiles => l10n.signoutOpenFiles,
      };
}

/// One entry of the action sheet.
class SelfServiceAction {
  const SelfServiceAction(this.type);

  final SelfServiceActionType type;
}

/// Alert for a single registration field (Ionic showSingleFieldAlert):
/// text input, Ja/Nein radios, option radios or checkboxes. In sign-in mode
/// the only button is "Anmelden"; in edit mode "Abbrechen" / "Speichern".
Future<Map<String, dynamic>?> showSingleRegistrationFieldDialog(
  BuildContext context, {
  required RegistrationField field,
  dynamic existing,
  bool editMode = false,
}) {
  return showAppDialog<Map<String, dynamic>>(
    context: context,
    barrierDismissible: editMode,
    builder: (ctx) => _SingleFieldDialog(field: field, existing: existing, editMode: editMode),
  );
}

class _SingleFieldDialog extends StatefulWidget {
  const _SingleFieldDialog({required this.field, required this.existing, required this.editMode});

  final RegistrationField field;
  final dynamic existing;
  final bool editMode;

  @override
  State<_SingleFieldDialog> createState() => _SingleFieldDialogState();
}

class _SingleFieldDialogState extends State<_SingleFieldDialog> {
  late dynamic _value;
  late final TextEditingController _text;

  @override
  void initState() {
    super.initState();
    final field = widget.field;
    final existing = widget.existing;
    if (field.type == RegistrationFieldType.multiSelect) {
      _value = existing is List ? existing.map((e) => e.toString()).toList() : <String>[];
    } else {
      _value = existing ?? (field.type == RegistrationFieldType.boolean ? false : '');
    }
    _text = TextEditingController(
      text: field.type == RegistrationFieldType.text ? '${_value ?? ''}' : '',
    );
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Widget _content() {
    final field = widget.field;
    switch (field.type) {
      case RegistrationFieldType.boolean:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final opt in const [true, false])
              RadioListTile<bool>(
                contentPadding: EdgeInsets.zero,
                value: opt,
                groupValue: _value is bool ? _value as bool : null,
                title: Text(opt ? context.l10n.commonYes : context.l10n.commonNo),
                onChanged: (v) => setState(() => _value = v),
              ),
          ],
        );
      case RegistrationFieldType.select:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final opt in field.options ?? const <String>[])
              RadioListTile<String>(
                contentPadding: EdgeInsets.zero,
                value: opt,
                groupValue: _value is String ? _value as String : null,
                title: Text(opt),
                onChanged: (v) => setState(() => _value = v),
              ),
          ],
        );
      case RegistrationFieldType.multiSelect:
        final selected = _value as List<String>;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final opt in field.options ?? const <String>[])
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: selected.contains(opt),
                title: Text(opt),
                onChanged: (v) => setState(() {
                  if (v == true) {
                    selected.add(opt);
                  } else {
                    selected.remove(opt);
                  }
                }),
              ),
          ],
        );
      default:
        return TextField(
          controller: _text,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: '...'),
          onChanged: (v) => _value = v,
        );
    }
  }

  /// Classic: the Ionic alert inputs of the field type (`text`, `radio`,
  /// `checkbox`) in the look's alert style; Beta keeps [_content].
  Widget _alertContent() {
    final field = widget.field;
    final beta = SingleChildScrollView(child: _content());
    switch (field.type) {
      case RegistrationFieldType.boolean:
        return AppAlertRadioGroup<bool>(
          options: [
            AppAlertOption(true, context.l10n.commonYes),
            AppAlertOption(false, context.l10n.commonNo),
          ],
          groupValue: _value is bool ? _value as bool : null,
          onChanged: (v) => setState(() => _value = v),
          beta: beta,
        );
      case RegistrationFieldType.select:
        return AppAlertRadioGroup<String>(
          options: [
            for (final opt in field.options ?? const <String>[]) AppAlertOption(opt, opt),
          ],
          groupValue: _value is String ? _value as String : null,
          onChanged: (v) => setState(() => _value = v),
          beta: beta,
        );
      case RegistrationFieldType.multiSelect:
        final selected = _value as List<String>;
        return AppAlertCheckboxGroup<String>(
          options: [
            for (final opt in field.options ?? const <String>[]) AppAlertOption(opt, opt),
          ],
          values: selected.toSet(),
          onChanged: (opt, checked) => setState(() {
            checked ? selected.add(opt) : selected.remove(opt);
          }),
          beta: beta,
        );
      default:
        return AppAlertInputGroup(
          beta: beta,
          children: [
            AppAlertInput(
              controller: _text,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              placeholder: '...',
              onChanged: (v) => _value = v,
            ),
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppAlertDialog(
      title: Text(widget.field.label),
      content: _alertContent(),
      actions: [
        if (widget.editMode)
          TextButton(onPressed: () => Navigator.pop(context), child: Text(context.l10n.commonCancel)),
        TextButton(
          onPressed: () => Navigator.pop(context, <String, dynamic>{widget.field.id: _value}),
          child: Text(widget.editMode ? context.l10n.commonSave : context.l10n.signoutSignIn),
        ),
      ],
    );
  }
}
