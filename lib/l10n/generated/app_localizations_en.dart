// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get a11yAdd => 'Add';

  @override
  String get a11yClearInput => 'Clear input';

  @override
  String get a11yDecrease => 'Decrease';

  @override
  String get a11yHelp => 'Help';

  @override
  String get a11yIncrease => 'Increase';

  @override
  String get a11yMoreActions => 'More actions';

  @override
  String get a11yNextPage => 'Next page';

  @override
  String get a11yPreviousPage => 'Previous page';

  @override
  String a11yRating(Object count) {
    return '$count of 5 stars';
  }

  @override
  String get a11ySelectDate => 'Select date';

  @override
  String get adminAddChurch => 'Add church';

  @override
  String get adminChurchAdded => 'The church was added.';

  @override
  String get adminChurchName => 'Name of the church';

  @override
  String get adminChurchRenamed => 'Church renamed';

  @override
  String adminChurchesCount(Object count) {
    return 'Churches ($count)';
  }

  @override
  String get adminCurrentlyUsed => 'Currently used';

  @override
  String adminDuplicateGroups(Object count) {
    return '$count duplicate group(s) found';
  }

  @override
  String get adminDuplicatesHint => 'Churches with the same name can be merged.';

  @override
  String get adminEvaluation => 'Analytics';

  @override
  String get adminFlutterAddFailed => 'Error while adding';

  @override
  String adminGb(Object value) {
    return '$value GB';
  }

  @override
  String get adminInvalidLimit => 'Please enter a number greater than 0 or clear the field (unlimited).';

  @override
  String get adminInvalidValues => 'Please enter valid values.';

  @override
  String get adminLimitHelper => 'Leave empty for unlimited. New instances start with 5 GB.';

  @override
  String get adminMaxStorage => 'Max. storage (GB)';

  @override
  String get adminMerge => 'Merge';

  @override
  String get adminMergeAll => 'Merge all';

  @override
  String get adminMergeAllDuplicates => 'Merge all duplicates';

  @override
  String adminMergeAllMessage(Object total, Object groups) {
    return '$total duplicate(s) in $groups group(s) will be merged. Continue?';
  }

  @override
  String get adminMergeChurches => 'Merge churches';

  @override
  String get adminMergeFailed => 'Merging failed';

  @override
  String adminMergeMessage(Object source, Object target) {
    return '“$source” will be merged into “$target”. All people will be updated. Continue?';
  }

  @override
  String adminMergeMoveMessage(Object source, Object target) {
    return '“$source” will be deleted and all people moved to “$target”. Continue?';
  }

  @override
  String adminMergeWith(Object name) {
    return 'Merge “$name” with...';
  }

  @override
  String adminMerged(Object count) {
    return 'Merged: $count person(s) updated';
  }

  @override
  String adminMergedAll(Object updated, Object total) {
    return '$updated person(s) updated, $total duplicate(s) removed';
  }

  @override
  String get adminMerging => 'Merging churches...';

  @override
  String get adminRenameChurch => 'Rename church';

  @override
  String get adminRenameFailed => 'Renaming failed';

  @override
  String get adminShowAllChurches => 'Show all churches';

  @override
  String adminStorageFor(Object name) {
    return 'File storage: $name';
  }

  @override
  String adminStorageLimit(Object gb) {
    return 'Storage limit: $gb GB';
  }

  @override
  String get adminStorageUnlimited => 'Storage: unlimited';

  @override
  String adminTimesPresent(Object count) {
    return '$count× present';
  }

  @override
  String get adminTitle => 'Administration';

  @override
  String get adminUnlimited => 'Unlimited';

  @override
  String get agendaAddTask => 'Add task';

  @override
  String agendaAddTopics(num count, Object min) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count topics',
      one: '$count topic',
    );
    return 'Add $_temp0 · $min min';
  }

  @override
  String get agendaAgendaUpdated => 'Agenda updated';

  @override
  String get agendaAlreadyInPlan => 'already in the run sheet';

  @override
  String get agendaAlreadyPlanned => ' (already planned)';

  @override
  String get agendaChooseTopics => 'Choose topics';

  @override
  String agendaCreateAsNew(Object name) {
    return 'Create \"$name\" as a new topic';
  }

  @override
  String get agendaCreateFailed => 'Topic could not be created';

  @override
  String get agendaDefault => 'Default';

  @override
  String get agendaDeleteConfirm => 'Really delete topic?';

  @override
  String get agendaDeleteFailed => 'Delete failed';

  @override
  String get agendaDeleteMessage => 'It disappears from the topic store. Run sheets and minutes already planned stay unchanged. To remove it from one event only, do it there via \"Add topics\" or in team organization.';

  @override
  String get agendaDeleteTopic => 'Delete topic';

  @override
  String get agendaDeleted => 'Deleted';

  @override
  String get agendaDescription => 'Description';

  @override
  String get agendaDescriptionPlaceholder => 'Background, goal, open questions …';

  @override
  String agendaDone(Object who) {
    return '$who · done';
  }

  @override
  String agendaDoneOn(Object who, Object date) {
    return '$who · done $date';
  }

  @override
  String agendaDueOn(Object who, Object date) {
    return '$who · due $date';
  }

  @override
  String get agendaDurationPerSession => 'Duration per meeting (min)';

  @override
  String get agendaEnterTitle => 'Please enter a title';

  @override
  String get agendaFlutterNoMatch => 'No matching topic found.';

  @override
  String get agendaFlutterNoOpenTopics => 'No open topics. Create a new one above.';

  @override
  String get agendaFlutterNotFound => 'Topic not found';

  @override
  String get agendaHigh => 'High';

  @override
  String get agendaHistory => 'History';

  @override
  String agendaInsertAfter(Object name) {
    return 'Inserted after \"$name\"';
  }

  @override
  String get agendaInsertAtStart => 'Inserted at the beginning';

  @override
  String get agendaLoadFailed => 'Topics could not be loaded';

  @override
  String get agendaLonger => 'Longer';

  @override
  String get agendaLow => 'Low';

  @override
  String get agendaMedium => 'Medium';

  @override
  String agendaNewEnd(Object where, Object time) {
    return '$where · new end $time';
  }

  @override
  String get agendaNewEvent => 'Create new event';

  @override
  String get agendaNewTopic => 'New topic';

  @override
  String get agendaNoOutcome => 'No outcome';

  @override
  String get agendaNoProtocolEvent => 'No event with agenda planned yet';

  @override
  String get agendaNoTasks => 'No tasks';

  @override
  String get agendaNobody => 'Nobody';

  @override
  String get agendaNotDiscussed => 'Not discussed in any event yet.';

  @override
  String get agendaPlanFailed => 'Topic could not be planned';

  @override
  String get agendaPlanIn => 'Plan in';

  @override
  String get agendaPlanSaveFailed => 'Run sheet could not be saved';

  @override
  String get agendaPlanned => 'Planned';

  @override
  String agendaPlannedFor(Object date) {
    return 'Planned for $date';
  }

  @override
  String get agendaPostponed => 'Postponed';

  @override
  String get agendaPostponedFromLast => 'Postponed from last meeting';

  @override
  String agendaPostponedOn(Object date) {
    return 'Postponed $date';
  }

  @override
  String get agendaPriority => 'Priority';

  @override
  String agendaProposedBy(Object name) {
    return 'Proposed by $name';
  }

  @override
  String agendaRemoveTopics(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count topics',
      one: '$count topic',
    );
    return 'Remove $_temp0';
  }

  @override
  String get agendaRemovedFromPlan => 'will be removed from the run sheet';

  @override
  String get agendaResponsible => 'Responsible';

  @override
  String get agendaSaveFailed => 'Topic could not be saved';

  @override
  String get agendaSearchOrCreate => 'Search or create topic';

  @override
  String get agendaShorter => 'Shorter';

  @override
  String get agendaStatus => 'Status';

  @override
  String get agendaStatusDone => 'Done';

  @override
  String get agendaStatusDropped => 'Dropped';

  @override
  String get agendaStatusOpen => 'Open';

  @override
  String get agendaTasks => 'Tasks';

  @override
  String agendaTasksDone(Object done, Object total) {
    return '$done of $total done';
  }

  @override
  String get agendaTitlePlaceholder => 'What is it about?';

  @override
  String get agendaTopic => 'Topic';

  @override
  String get agendaTopicAdded => 'Topic added';

  @override
  String get agendaTopicRemoved => 'Topic removed from the run sheet';

  @override
  String get agendaTopicStore => 'Topic store';

  @override
  String agendaTopicsAdded(Object count) {
    return '$count topics added';
  }

  @override
  String agendaTopicsRemoved(Object count) {
    return '$count topics removed from the run sheet';
  }

  @override
  String get agendaWhichEvent => 'Plan into which event?';

  @override
  String get appChangePassword => 'Change password';

  @override
  String get appConfirmLinkInvalid => 'The confirmation link is invalid or has expired.';

  @override
  String get appEmailConfirmed => 'Email address confirmed. Welcome!';

  @override
  String get appMinSixPlaceholder => 'Enter at least 6 characters...';

  @override
  String appNativeAdGoTo(Object store) {
    return 'Go to $store';
  }

  @override
  String get appNativeAdHeader => 'Attendix is available as an app!';

  @override
  String appNativeAdMessage(Object store) {
    return 'Attendix is now available as a native app with push notifications and faster access. Download it now from the $store!';
  }

  @override
  String get appNewPassword => 'Enter new password';

  @override
  String get appPasswordMin => 'Please enter a password with at least 6 characters';

  @override
  String get appRedirectLoadApp => 'Get the app from your device\'s store:';

  @override
  String get appResetLinkInvalid => 'The reset link is invalid or has expired.';

  @override
  String get attListAddEvent => 'Add event';

  @override
  String get attListAddEvents => 'Add events';

  @override
  String get attListAddSongs => 'Add piece(s)';

  @override
  String get attListAverage => 'Average';

  @override
  String get attListChooseOneDate => 'Please choose at least one date';

  @override
  String get attListChooseSongs => 'Choose pieces';

  @override
  String get attListConductor => 'Conductor';

  @override
  String get attListContinue => 'Continue';

  @override
  String attListCountAbsent(Object count) {
    return '$count absent';
  }

  @override
  String attListCountExcused(Object count) {
    return '$count excused';
  }

  @override
  String attListCountPresent(Object count) {
    return '$count present';
  }

  @override
  String get attListDateMulti => 'Date (multiple selection possible)';

  @override
  String get attListDistributeDuties => 'Distribute duties';

  @override
  String get attListDurationDays => 'Duration (in days)';

  @override
  String attListDutyFilled(Object text) {
    return '$text filled';
  }

  @override
  String get attListEnterConductor => 'Enter conductor';

  @override
  String get attListEventAdded => 'Event added';

  @override
  String get attListEventTypes => 'Event types';

  @override
  String get attListEvents => 'Events';

  @override
  String get attListEventsAdded => 'Events added';

  @override
  String attListEventsSelected(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count events selected',
      one: '$count event selected',
    );
    return '$_temp0';
  }

  @override
  String get attListHolidays => 'Public holidays';

  @override
  String get attListHolidaysOfState => 'Public holidays of the selected state';

  @override
  String get attListInfoText => 'Info text (optional)';

  @override
  String get attListInfoTextHelper => 'This text is shown instead of the type.';

  @override
  String get attListInvalidType => 'Invalid event type selected';

  @override
  String get attListLess => 'Less';

  @override
  String get attListMore => 'More';

  @override
  String attListNeededPeople(Object label) {
    return 'People needed · $label';
  }

  @override
  String get attListNoDate => 'No date selected';

  @override
  String get attListNoEventsYet => 'No events have been created yet';

  @override
  String get attListNoSongsFound => 'No pieces found';

  @override
  String get attListNoSongsSelected => 'No pieces selected';

  @override
  String get attListOtherConductor => 'Other conductor';

  @override
  String get attListPlace => 'Location (for navigation)';

  @override
  String get attListPlacePlaceholder => 'e.g. Community Hall, 1 Main Street, Springfield';

  @override
  String attListPresentOf(Object present, Object total) {
    return '$present of $total present';
  }

  @override
  String get attListRemoveConfirm => 'Do you really want to remove the event?';

  @override
  String get attListSchoolHolidays => 'School holidays';

  @override
  String get attListSchoolHolidaysOfState => 'School holidays of the selected state';

  @override
  String get attListSearchSong => 'Search piece...';

  @override
  String get attListShowAll => 'Show all';

  @override
  String get attListSongs => 'Pieces';

  @override
  String get attListSongsLabel => 'Piece(s)';

  @override
  String attListSongsSelected(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pieces',
      one: '$count piece',
    );
    return '$_temp0 selected';
  }

  @override
  String get attListTodayDeselected => 'Today\'s date was deselected';

  @override
  String get attListType => 'Type';

  @override
  String get attListUnknownConductor => 'Unknown conductor';

  @override
  String get attListUnknownSong => 'Unknown song';

  @override
  String get attendanceAdd => 'Add';

  @override
  String get attendanceAddNote => 'Add note';

  @override
  String get attendanceAddPeopleFailed => 'Could not add the people';

  @override
  String get attendanceAddPerson => 'Add person';

  @override
  String attendanceAddPersonsCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Add $count people',
      one: 'Add $count person',
    );
    return '$_temp0';
  }

  @override
  String get attendanceAddTodo => 'Add to-do';

  @override
  String get attendanceAddTopics => 'Add topics';

  @override
  String get attendanceAddingPeople => 'Adding people...';

  @override
  String get attendanceAddressPlaceholder => 'Address or place name';

  @override
  String get attendanceAllAlreadyIncluded => 'Everyone is already part of this attendance.';

  @override
  String get attendanceAssign => 'Assign';

  @override
  String get attendanceAssignPerson => 'Assign person';

  @override
  String attendanceAssignedNotified(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Assigned, the people will be notified',
      one: 'Assigned, the person will be notified',
    );
    return '$_temp0';
  }

  @override
  String attendanceAtTime(Object time) {
    return ' at $time';
  }

  @override
  String get attendanceAttachmentUploaded => 'Attachment uploaded';

  @override
  String get attendanceAvailable => 'Available';

  @override
  String attendanceCannotWithNote(Object note) {
    return 'Can\'t: $note';
  }

  @override
  String get attendanceChangeConductor => 'Change conductor';

  @override
  String get attendanceChangeFolder => 'Change folder';

  @override
  String attendanceChangedOn(Object date) {
    return '· changed on $date';
  }

  @override
  String get attendanceChecklist => 'Checklist';

  @override
  String get attendanceChecklistRestored => 'Checklist restored';

  @override
  String get attendanceChoose => 'Choose';

  @override
  String get attendanceChoosePeople => 'Choose people';

  @override
  String get attendanceChoosePersonMin => 'Please choose at least one person';

  @override
  String get attendanceChurchOverview => 'Church overview';

  @override
  String get attendanceClearFilter => 'Clear filter';

  @override
  String get attendanceConfirmed => 'confirmed';

  @override
  String get attendanceConnectionRestored => 'Connection restored';

  @override
  String get attendanceCreateRunSheet => 'Create run sheet';

  @override
  String attendanceCurrentNote(Object note) {
    return 'Current: $note';
  }

  @override
  String get attendanceCustomNote => 'Custom note';

  @override
  String get attendanceCustomNoteEllipsis => 'Custom note...';

  @override
  String get attendanceDate => 'Date';

  @override
  String get attendanceDeadlineDate => 'Deadline';

  @override
  String get attendanceDeadlineHelper => 'People can only sign up until this date. Signing out is still possible.';

  @override
  String get attendanceDeadlineHours => 'Deadline in hours (optional)';

  @override
  String get attendanceDeclined => 'declined';

  @override
  String get attendanceDefaultSortGroup => 'Default (group)';

  @override
  String get attendanceDeleteNote => 'Delete note';

  @override
  String get attendanceDeleteTodo => 'Delete to-do';

  @override
  String get attendanceDeleteTodoConfirm => 'Do you really want to delete this to-do?';

  @override
  String get attendanceDeletedByOther => 'This attendance was just deleted by another user';

  @override
  String get attendanceDescriptionAttachment => 'Description & attachment';

  @override
  String get attendanceDescriptionPlaceholder => 'Enter description...';

  @override
  String get attendanceDraft => 'Draft';

  @override
  String attendanceDraftEdited(Object date) {
    return 'Draft · last edited $date';
  }

  @override
  String get attendanceDueNow => 'Due now';

  @override
  String attendanceDueOn(Object date) {
    return '· due $date';
  }

  @override
  String get attendanceEditDescription => 'Edit description & attachment';

  @override
  String get attendanceEditRegFields => 'Edit sign-up fields';

  @override
  String get attendanceEditRunSheet => 'Edit run sheet';

  @override
  String get attendanceEmailLink => 'Link in the email';

  @override
  String get attendanceEnd => 'End';

  @override
  String get attendanceEnterNote => 'Enter note...';

  @override
  String get attendanceEnterText => 'Please enter a text';

  @override
  String get attendanceEventFallback => 'Event';

  @override
  String attendanceEventOnDate(Object type, Object date) {
    return '$type on $date';
  }

  @override
  String get attendanceExplicitStatus => 'Explicit status selection';

  @override
  String get attendanceExplicitStatusHint => 'Choose status from a dropdown instead of tapping';

  @override
  String get attendanceExportExcel => 'Export attendance to Excel';

  @override
  String get attendanceExportPdf => 'Export (PDF)';

  @override
  String get attendanceExportPdfA5 => 'Export (PDF 2x A5)';

  @override
  String get attendanceFewerPeopleNeeded => 'Fewer people needed';

  @override
  String get attendanceFilesFolder => 'Folder in file storage';

  @override
  String get attendanceFilesFolderHint => 'e.g. recordings of the event';

  @override
  String attendanceFilterActive(Object count) {
    return '$count active';
  }

  @override
  String get attendanceFlutterA4Standard => 'A4 (default)';

  @override
  String get attendanceFlutterA5OnA4 => '2x A5 on A4';

  @override
  String get attendanceFlutterAddAttachment => 'Add attachment';

  @override
  String get attendanceFlutterAddPhoto => 'Add photo';

  @override
  String get attendanceFlutterAsImage => 'As image';

  @override
  String attendanceFlutterAttendancesCount(Object count) {
    return '$count events';
  }

  @override
  String get attendanceFlutterCalendar => 'Calendar';

  @override
  String get attendanceFlutterCamera => 'Camera';

  @override
  String get attendanceFlutterChooseDeadline => 'Choose registration deadline';

  @override
  String get attendanceFlutterChooseType => 'Please choose an event type';

  @override
  String get attendanceFlutterCreatingExcel => 'Creating Excel export...';

  @override
  String get attendanceFlutterDataUnavailable => 'Data not available';

  @override
  String get attendanceFlutterDeadlineDisabled => 'Registration deadline disabled';

  @override
  String get attendanceFlutterDeadlineEnabled => 'Registration deadline enabled';

  @override
  String get attendanceFlutterDeadlineUpdated => 'Registration deadline updated';

  @override
  String get attendanceFlutterDeleteTodoTitle => 'Delete to-do?';

  @override
  String get attendanceFlutterEndAfterStart => 'End must be after start';

  @override
  String get attendanceFlutterEndTime => 'End time';

  @override
  String get attendanceFlutterEndTimeUpdated => 'End time updated';

  @override
  String attendanceFlutterErrorWith(Object error) {
    return 'Error: $error';
  }

  @override
  String attendanceFlutterEventsCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count events',
      one: '$count event',
    );
    return '$_temp0';
  }

  @override
  String get attendanceFlutterExcusedShort => 'Exc.';

  @override
  String get attendanceFlutterExportFormat => 'Export format';

  @override
  String get attendanceFlutterGallery => 'Gallery';

  @override
  String get attendanceFlutterHoliday => 'Public holiday';

  @override
  String get attendanceFlutterListLoadFailed => 'The attendance list could not be loaded.';

  @override
  String get attendanceFlutterLoadError => 'Error while loading';

  @override
  String get attendanceFlutterNoAccount => 'This person has no account';

  @override
  String get attendanceFlutterNoEntry => 'No attendance entry found';

  @override
  String get attendanceFlutterNoEventTypes => 'No event types configured';

  @override
  String get attendanceFlutterNoItemsToExport => 'No programme items to export';

  @override
  String get attendanceFlutterNoItemsToSend => 'No programme items to send';

  @override
  String get attendanceFlutterNoPermission => 'No permission';

  @override
  String get attendanceFlutterNoPlanToExport => 'No run sheet to export';

  @override
  String get attendanceFlutterNoPlanToSend => 'No run sheet to send';

  @override
  String get attendanceFlutterNoTodos => 'No to-dos yet';

  @override
  String get attendanceFlutterNotFound => 'Attendance not found';

  @override
  String get attendanceFlutterNoteDeleted => 'Note deleted';

  @override
  String get attendanceFlutterNotesOptional => 'Notes (optional)';

  @override
  String get attendanceFlutterOnePlanPerPage => 'One plan per page';

  @override
  String get attendanceFlutterOpen => 'Open';

  @override
  String get attendanceFlutterPhoto => 'Photo';

  @override
  String get attendanceFlutterPhotoUploaded => 'Photo uploaded';

  @override
  String get attendanceFlutterPlanNotShared => 'The plan is no longer shared';

  @override
  String get attendanceFlutterPlanSentTelegram => 'Plan sent via Telegram';

  @override
  String get attendanceFlutterPlanShared => 'The plan is now shared with members';

  @override
  String get attendanceFlutterQuickPreview => 'For a quick preview';

  @override
  String get attendanceFlutterRecordAttendance => 'Record attendance';

  @override
  String get attendanceFlutterRegFieldsSaved => 'Registration fields saved';

  @override
  String get attendanceFlutterRemoveAttachment => 'Remove attachment';

  @override
  String get attendanceFlutterRestoreChecklistMessage => 'The current checklist will be replaced by the default checklist.';

  @override
  String get attendanceFlutterRestoreChecklistTitle => 'Restore checklist?';

  @override
  String attendanceFlutterSaveFailedWith(Object error) {
    return 'Could not save: $error';
  }

  @override
  String get attendanceFlutterSchoolHolidays => 'School holidays';

  @override
  String get attendanceFlutterSelectDate => 'Select date';

  @override
  String attendanceFlutterSendFailedWith(Object error) {
    return 'Sending failed: $error';
  }

  @override
  String attendanceFlutterShowAllCount(Object count) {
    return 'Show all $count';
  }

  @override
  String get attendanceFlutterShowLess => 'Show less';

  @override
  String get attendanceFlutterSongRemoved => 'Piece removed';

  @override
  String get attendanceFlutterStandardFormat => 'Default format';

  @override
  String get attendanceFlutterStartTimeUpdated => 'Start time updated';

  @override
  String get attendanceFlutterTelegramNotConnected => 'Telegram is not connected. Please connect it in the settings first.';

  @override
  String get attendanceFlutterTodoAdded => 'To-do added';

  @override
  String get attendanceFlutterTodoDeleted => 'To-do deleted';

  @override
  String get attendanceFlutterTwoIdenticalPlans => 'Two identical plans (landscape)';

  @override
  String get attendanceFlutterTwoPlansOnePage => 'Two plans on one page';

  @override
  String attendanceFlutterUploadFailedWith(Object error) {
    return 'Upload failed: $error';
  }

  @override
  String get attendanceFlutterUploadingPhoto => 'Uploading photo...';

  @override
  String get attendanceGeneral => 'General';

  @override
  String attendanceInDays(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'in $count days',
      one: 'in $count day',
    );
    return '$_temp0';
  }

  @override
  String attendanceInHours(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'in $count hours',
      one: 'in $count hour',
    );
    return '$_temp0';
  }

  @override
  String get attendanceInfoText => 'Info text';

  @override
  String attendanceLastChangedBy(Object name) {
    return 'Last changed by $name';
  }

  @override
  String attendanceLastChangedByAt(Object name, Object date, Object time) {
    return 'Last changed by $name on $date at $time';
  }

  @override
  String get attendanceLateExcusedParen => 'Late (excused)';

  @override
  String get attendanceLoadFailed => 'Attendance list could not be loaded';

  @override
  String get attendanceLoadFailedReopen => 'Attendance could not be loaded. Please open it again.';

  @override
  String get attendanceLoadPeopleFailed => 'Could not load people';

  @override
  String get attendanceLoadingPeople => 'Loading people...';

  @override
  String get attendanceMatchingPeople => 'Matching people';

  @override
  String get attendanceMessage => 'Message';

  @override
  String get attendanceMessagePlaceholder => 'Message text';

  @override
  String attendanceMinutesShort(Object min) {
    return '$min min';
  }

  @override
  String get attendanceMorePeopleNeeded => 'More people needed';

  @override
  String attendanceNeeded(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count people',
      one: '$count person',
    );
    return 'Needed: $_temp0';
  }

  @override
  String get attendanceNoConnection => 'No internet connection';

  @override
  String get attendanceNoDefaultChecklist => 'No default checklist available';

  @override
  String get attendanceNoGroup => 'No group';

  @override
  String get attendanceNoPeople => 'No people';

  @override
  String get attendanceNobodyAssigned => 'Nobody assigned';

  @override
  String get attendanceNotStarted => 'Not started yet';

  @override
  String get attendanceNoteAdded => 'Note added';

  @override
  String get attendanceNotes => 'Notes';

  @override
  String get attendanceOffline => 'Offline';

  @override
  String get attendanceOnlyNeutral => 'Only people without status';

  @override
  String get attendanceOnlyNeutralHint => 'Only sends to people who have not responded yet';

  @override
  String get attendanceOpenProtocol => 'Open minutes';

  @override
  String get attendanceOtherPeople => 'Other people';

  @override
  String attendanceOverdueDays(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days overdue',
      one: '$count day overdue',
    );
    return '$_temp0';
  }

  @override
  String attendanceOverdueHours(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hours overdue',
      one: '$count hour overdue',
    );
    return '$_temp0';
  }

  @override
  String attendancePending(Object count) {
    return '$count pending';
  }

  @override
  String attendancePeopleAdded(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count people added',
      one: '$count person added',
    );
    return '$_temp0';
  }

  @override
  String get attendancePersonRemoveFailed => 'Could not remove the person';

  @override
  String get attendancePersonRemoved => 'Person removed from attendance';

  @override
  String get attendancePictureFailed => 'Could not add the picture, please try again later';

  @override
  String get attendancePlace => 'Location';

  @override
  String get attendancePresentPeople => 'Present';

  @override
  String get attendanceProtocol => 'Minutes';

  @override
  String get attendancePublished => 'Published';

  @override
  String attendancePublishedOn(Object date) {
    return 'Published on $date';
  }

  @override
  String get attendanceReadProtocol => 'Read minutes';

  @override
  String get attendanceRegFields => 'Sign-up fields';

  @override
  String attendanceRegularlyUnavailableWithReason(Object reason) {
    return 'Regularly unavailable: $reason';
  }

  @override
  String get attendanceReload => 'Reload';

  @override
  String get attendanceReloadFailed => 'Reload failed. Please try again.';

  @override
  String get attendanceReminderInfo => 'The reminder is sent as an app notification and by email. You can freely adjust the subject and message.';

  @override
  String get attendanceReminderSent => 'Reminder sent';

  @override
  String attendanceReminderTitle(Object event) {
    return '🔔 Reminder: $event';
  }

  @override
  String get attendanceRemoveFolder => 'Remove folder';

  @override
  String get attendanceRemovePerson => 'Remove person';

  @override
  String attendanceRemovePersonConfirm(Object name) {
    return 'Do you really want to remove $name from this attendance? This action cannot be undone.';
  }

  @override
  String get attendanceRequested => 'requested';

  @override
  String get attendanceResetChecklist => 'Reset checklist';

  @override
  String get attendanceRunSheetAgenda => 'Run sheet & agenda';

  @override
  String get attendanceSelfSignedUp => 'signed up themselves';

  @override
  String get attendanceSend => 'Send';

  @override
  String get attendanceSendFailed => 'Sending failed';

  @override
  String get attendanceSendReminder => 'Send reminder';

  @override
  String get attendanceSendReminderShort => 'Send reminder';

  @override
  String get attendanceSending => 'Sending...';

  @override
  String get attendanceSetDeadline => 'Set sign-up deadline';

  @override
  String get attendanceSetNeutral => 'Set status to neutral';

  @override
  String get attendanceShare => 'Share';

  @override
  String get attendanceShareRunSheet => 'Share run sheet';

  @override
  String get attendanceShowPictures => 'Show pictures';

  @override
  String get attendanceShowRegFields => 'Show sign-up fields';

  @override
  String get attendanceSignedOut => 'signed out';

  @override
  String attendanceSongsCount(Object count) {
    return 'Pieces ($count)';
  }

  @override
  String get attendanceSorting => 'Sorting';

  @override
  String get attendanceStaffing => 'Staffing';

  @override
  String get attendanceStart => 'Start';

  @override
  String get attendanceStartChecklist => 'Start checklist';

  @override
  String get attendanceStartLabel => 'Start';

  @override
  String get attendanceStartSession => 'Start meeting & take minutes';

  @override
  String get attendanceStatusChangeFailed => 'Could not change the attendance status, please try again later';

  @override
  String get attendanceStatusFilter => 'Status filter';

  @override
  String get attendanceStatusNotChanged => 'The status has not been changed yet';

  @override
  String get attendanceStatusOverview => 'Status overview';

  @override
  String get attendanceSubject => 'Subject';

  @override
  String get attendanceSubjectPlaceholder => 'e.g. 🔔 Reminder: Rehearsal on 01/09/2026';

  @override
  String get attendanceTasksFromEvent => 'Tasks from this event';

  @override
  String get attendanceTelegramImage => 'Send via Telegram (image)';

  @override
  String get attendanceTelegramPdf => 'Send via Telegram (PDF)';

  @override
  String get attendanceTelegramPdfA5 => 'Send via Telegram (PDF 2x A5)';

  @override
  String attendanceTimeOClock(Object time) {
    return '$time';
  }

  @override
  String get attendanceToSong => 'Go to piece';

  @override
  String get attendanceTodoText => 'To-do text...';

  @override
  String attendanceTotalPeople(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count people',
      one: '$count person',
    );
    return 'Total: $_temp0';
  }

  @override
  String get attendanceTryAgain => 'Please try again.';

  @override
  String get attendanceUnassign => 'Remove';

  @override
  String get attendanceUnassignConfirm => 'Remove from this duty?';

  @override
  String get attendanceUploadFailed => 'Upload failed';

  @override
  String get attendanceView => 'View';

  @override
  String get attendanceWhoChanged => 'Who changed it?';

  @override
  String audioPlayFailed(Object error) {
    return 'Playback failed: $error';
  }

  @override
  String get authConfirmEmailFirst => 'Please confirm your email address first.';

  @override
  String get authConfirmationResent => 'Confirmation email sent again';

  @override
  String get authInvalidCredentials => 'Invalid credentials';

  @override
  String get authResendConfirmationFailed => 'Could not send the confirmation email';

  @override
  String get authResetFailed => 'Could not reset the password';

  @override
  String get authResetRetry => 'Reset failed, please try again';

  @override
  String get authResetSent => 'Password reset email sent';

  @override
  String get authUserNotFound => 'User not found';

  @override
  String get bellCurrentInstance => 'Current instance';

  @override
  String get bellDeleteAll => 'Delete all';

  @override
  String get bellDeleteAllHeader => 'Delete all notifications?';

  @override
  String get bellDeleteAllMessage => 'All notifications from all instances will be deleted. This action cannot be undone.';

  @override
  String get bellMark => 'Mark';

  @override
  String get bellMarkAllHeader => 'Mark all as read?';

  @override
  String get bellMarkAllMessage => 'All notifications from all instances will be marked as read.';

  @override
  String get bellMarkAllRead => 'All read';

  @override
  String get bellNone => 'No notifications';

  @override
  String get bellNoneAvailable => 'No notifications available.';

  @override
  String get bellTitle => 'Notifications';

  @override
  String get brandingFlutterReplaceLogo => 'Replace logo';

  @override
  String get brandingFlutterUploadLogo => 'Upload logo';

  @override
  String get brandingIntro => 'Logo and text appear subtly on exported plans and lists (PDF/image). The logo may be at most 2 MB. Branding applies to all instances of the organisation.';

  @override
  String get brandingLogo => 'Logo';

  @override
  String get brandingLogoRemoved => 'Logo removed. Don\'t forget to save.';

  @override
  String get brandingLogoTooBig => 'The logo may be at most 2 MB.';

  @override
  String get brandingLogoUploaded => 'Logo uploaded. Don\'t forget to save.';

  @override
  String get brandingOrgOnly => 'Branding is managed at organisation level. This instance is not assigned to an organisation.';

  @override
  String get brandingRemoveLogo => 'Remove logo';

  @override
  String get brandingSaved => 'Branding saved.';

  @override
  String get brandingSaving => 'Saving branding...';

  @override
  String get brandingSelectImage => 'Please select an image file.';

  @override
  String get brandingText => 'Branding text';

  @override
  String get brandingTextPh => 'e.g. association name';

  @override
  String get churchOverviewChurches => 'Churches';

  @override
  String get churchOverviewNoChurch => 'No church';

  @override
  String get churchOverviewNoPeople => 'No people';

  @override
  String get churchOverviewTitle => 'Church overview';

  @override
  String get churchOverviewTotal => 'Total';

  @override
  String get churchOverviewUnassigned => 'Unassigned';

  @override
  String get churchOverviewUnknownChurch => 'Unknown church';

  @override
  String get commonAll => 'All';

  @override
  String get commonAppleMaps => 'Apple Maps';

  @override
  String get commonApply => 'Apply';

  @override
  String get commonBack => 'Back';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonCannotUndo => 'This action cannot be undone.';

  @override
  String get commonClefC => 'Alto clef';

  @override
  String get commonClefF => 'Bass clef';

  @override
  String get commonClefG => 'Treble clef';

  @override
  String get commonClose => 'Close';

  @override
  String get commonConfirm => 'Confirm';

  @override
  String get commonCreate => 'Create';

  @override
  String commonCreatedAt(Object date) {
    return 'Created on: $date';
  }

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonEdit => 'Edit';

  @override
  String get commonError => 'Error';

  @override
  String get commonGroupLabelGroup => 'Group';

  @override
  String get commonGroupLabelInstrument => 'Instrument';

  @override
  String get commonGroupLabelVoice => 'Voice';

  @override
  String get commonHistoryArchived => 'Archived';

  @override
  String get commonHistoryGroupChange => 'Change';

  @override
  String get commonHistoryPaused => 'Paused';

  @override
  String get commonHistoryReturned => 'Reactivated';

  @override
  String get commonHistoryUnexcused => 'Unexcused';

  @override
  String get commonIntlLocale => 'en-GB';

  @override
  String get commonLoading => 'Loading …';

  @override
  String get commonNext => 'Next';

  @override
  String get commonNgDate => 'dd/MM/yyyy';

  @override
  String get commonNgDayMonth => 'dd/MM';

  @override
  String get commonNo => 'No';

  @override
  String get commonOk => 'OK';

  @override
  String get commonOpen => 'Open';

  @override
  String get commonOther => 'Other';

  @override
  String get commonOtherPlural => 'Other';

  @override
  String get commonPeople => 'People';

  @override
  String commonPersons(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count people',
      one: '$count person',
    );
    return '$_temp0';
  }

  @override
  String get commonRemove => 'Remove';

  @override
  String get commonRolesAdmin => 'Admin';

  @override
  String get commonRolesHelper => 'Helper';

  @override
  String get commonRolesMember => 'Member';

  @override
  String get commonRolesParent => 'Parent';

  @override
  String get commonRolesResponsible => 'Person in charge';

  @override
  String get commonRolesViewer => 'Observer';

  @override
  String get commonRolesVoiceLeader => 'Section leader';

  @override
  String get commonRolesVoiceLeaderHelper => 'Section leader & helper';

  @override
  String get commonSave => 'Save';

  @override
  String get commonSearch => 'Search';

  @override
  String get commonStatusAbsent => 'Absent';

  @override
  String get commonStatusAccepted => 'Accepted';

  @override
  String get commonStatusExcused => 'Excused';

  @override
  String get commonStatusLate => 'Present, late';

  @override
  String get commonStatusLateExcused => 'Late, excused';

  @override
  String get commonStatusLateExcusedShort => 'Late, excused';

  @override
  String get commonStatusLateReported => 'Late arrival reported';

  @override
  String get commonStatusLateShort => 'Late';

  @override
  String get commonStatusNeutral => 'Neutral';

  @override
  String get commonStatusPresent => 'Present';

  @override
  String get commonUnknown => 'Unknown';

  @override
  String get commonUnknownError => 'Unknown error';

  @override
  String commonWithout(Object list) {
    return 'Without $list';
  }

  @override
  String get commonYes => 'Yes';

  @override
  String get coreFlutterAccessDenied => 'Access denied';

  @override
  String get coreFlutterDifficultyEasy => 'Easy';

  @override
  String get coreFlutterDifficultyHard => 'Hard';

  @override
  String get coreFlutterDifficultyMedium => 'Medium';

  @override
  String get coreFlutterDifficultyVeryHard => 'Very hard';

  @override
  String coreFlutterErrorWith(Object error) {
    return 'Error: $error';
  }

  @override
  String coreFlutterExportAttendanceHeader(Object name, Object date) {
    return '$name attendance as of $date';
  }

  @override
  String coreFlutterExportEndAt(Object time) {
    return 'End: $time';
  }

  @override
  String get coreFlutterExportOpen => 'Open';

  @override
  String get coreFlutterExportPdfRenderFailed => 'PDF could not be rendered';

  @override
  String coreFlutterExportPlayerListHeader(Object name, Object date) {
    return '$name member list as of $date';
  }

  @override
  String get coreFlutterExportPlayerListSheet => 'Member list';

  @override
  String get coreFlutterExportRate => 'Rate';

  @override
  String get coreFlutterExportRehearsalProgramme => 'Rehearsal programme';

  @override
  String get coreFlutterFeedbackAnonymousHint => 'Your data will not be sent';

  @override
  String get coreFlutterFeedbackQuestionIntro => 'Do you have a question or need help?';

  @override
  String get coreFlutterFeedbackQuestionRequired => 'Please enter a question';

  @override
  String get coreFlutterFeedbackRatingIntro => 'How do you like the app?';

  @override
  String get coreFlutterFileBytesUnavailable => 'File bytes not available';

  @override
  String get coreFlutterFilePathUnavailable => 'File path not available';

  @override
  String get coreFlutterHistoryApproved => 'Approved';

  @override
  String get coreFlutterHistoryCopiedFrom => 'Copied from';

  @override
  String get coreFlutterHistoryCopiedTo => 'Copied to';

  @override
  String get coreFlutterHistoryCritical => 'Marked critical';

  @override
  String get coreFlutterHistoryDeclined => 'Declined';

  @override
  String get coreFlutterHistoryInstrumentChange => 'Instrument change';

  @override
  String get coreFlutterHistoryReturned => 'Returned';

  @override
  String get coreFlutterHistoryTransferredFrom => 'Transferred from';

  @override
  String get coreFlutterHistoryTransferredTo => 'Transferred to';

  @override
  String get coreFlutterHistoryUnpaused => 'Pause ended';

  @override
  String get coreFlutterHoliday => 'Public holiday';

  @override
  String coreFlutterImportBirthdayUnreadable(Object value) {
    return 'Birth date \"$value\" could not be read';
  }

  @override
  String coreFlutterImportCategoryNotFound(Object name) {
    return 'Category \"$name\" not found';
  }

  @override
  String coreFlutterImportDifficultyInvalid(Object value) {
    return 'Difficulty \"$value\" must be 1, 2 or 3';
  }

  @override
  String get coreFlutterImportDuplicateEmailInFile => 'Duplicate email in the file';

  @override
  String get coreFlutterImportDuplicateNumberInFile => 'Duplicate number in the file';

  @override
  String get coreFlutterImportEmailExists => 'Email already exists in this instance';

  @override
  String coreFlutterImportEmailInvalid(Object email) {
    return 'Email \"$email\" looks invalid';
  }

  @override
  String coreFlutterImportJoinedUnreadable(Object value) {
    return 'Join date \"$value\" could not be read';
  }

  @override
  String coreFlutterImportLinkInvalid(Object link) {
    return 'Link \"$link\" looks invalid';
  }

  @override
  String get coreFlutterImportNameRequired => 'First and last name are required';

  @override
  String get coreFlutterImportNumberRequired => 'Number is required and must be a number';

  @override
  String get coreFlutterImportSongNameRequired => 'Name is required';

  @override
  String get coreFlutterImportSongNumberExists => 'Song number already exists in this instance';

  @override
  String get coreFlutterInvalidCopyCount => 'Invalid number of copies';

  @override
  String get coreFlutterLoadFailed => 'Error loading';

  @override
  String get coreFlutterNewVersionAvailable => 'New version available';

  @override
  String get coreFlutterNoBranding => 'No branding';

  @override
  String get coreFlutterNoConnection => 'No internet connection';

  @override
  String get coreFlutterNoCopiesSelected => 'No copies selected for printing';

  @override
  String get coreFlutterNoEmailAddress => 'No email address available';

  @override
  String get coreFlutterNoFilesDownloaded => 'No files could be downloaded';

  @override
  String get coreFlutterNoFilesToDownload => 'No files to download';

  @override
  String get coreFlutterNoInstanceSelected => 'No instance selected';

  @override
  String get coreFlutterNoResponse => 'No response received';

  @override
  String coreFlutterNoResultsFor(Object query) {
    return 'No results for \"$query\"';
  }

  @override
  String get coreFlutterNoTenantSelected => 'No tenant selected';

  @override
  String get coreFlutterNoVersionHistory => 'No version history available';

  @override
  String get coreFlutterNotLoggedIn => 'Not logged in';

  @override
  String get coreFlutterNotSignedIn => 'Not signed in';

  @override
  String get coreFlutterOfflineQueueSaveFailed => 'The change could not be saved offline';

  @override
  String get coreFlutterOpenExternally => 'Open externally';

  @override
  String get coreFlutterPausedLower => 'paused';

  @override
  String coreFlutterPausedUntil(Object date) {
    return 'until $date';
  }

  @override
  String coreFlutterPdfLoadFailed(Object status) {
    return 'PDF could not be loaded (HTTP $status)';
  }

  @override
  String get coreFlutterPersonHasNoId => 'Person has no ID';

  @override
  String coreFlutterPlanDayN(Object day) {
    return 'Day $day';
  }

  @override
  String coreFlutterPlanStartsInHours(Object hours) {
    return 'starts in $hours h';
  }

  @override
  String coreFlutterPlanStartsInHoursMin(Object hours, Object min) {
    return 'starts in $hours h $min min';
  }

  @override
  String coreFlutterPlanStartsInMin(Object min) {
    return 'starts in $min min';
  }

  @override
  String get coreFlutterPlanStartsSoon => 'starts soon';

  @override
  String get coreFlutterRegistration => 'Registration';

  @override
  String get coreFlutterRepoAccountCreateFailed => 'The account could not be created.';

  @override
  String get coreFlutterRepoAlreadyAdmin => 'This person is already an admin.';

  @override
  String get coreFlutterRepoCategoryCreateFailed => 'Category could not be created';

  @override
  String coreFlutterRepoCategoryNotFound(Object id) {
    return 'Group category with ID $id not found';
  }

  @override
  String coreFlutterRepoChangeRoleFailed(Object error) {
    return 'Error changing the role: $error';
  }

  @override
  String get coreFlutterRepoEventExistsOnDate => 'An event already exists on this date';

  @override
  String get coreFlutterRepoEventNotInTenant => 'Event does not belong to the current instance';

  @override
  String get coreFlutterRepoForeignTenantDenied => 'Access to another instance denied';

  @override
  String get coreFlutterRepoGroupCreateFailed => 'Group could not be created';

  @override
  String coreFlutterRepoGroupHasPlayers(Object count) {
    return 'Group cannot be deleted: $count members are still assigned';
  }

  @override
  String coreFlutterRepoGroupNotFound(Object id) {
    return 'Group with ID $id not found';
  }

  @override
  String get coreFlutterRepoMeetingExistsOnDate => 'A meeting already exists on this date';

  @override
  String get coreFlutterRepoNoPermissionInTenant => 'No permission in this instance';

  @override
  String get coreFlutterRepoNoValidPersons => 'No valid persons';

  @override
  String get coreFlutterRepoPersonsNotInTenant => 'Persons do not belong to the current instance';

  @override
  String get coreFlutterRepoRootNotDeletable => 'Root cannot be deleted.';

  @override
  String get coreFlutterRepoSongNotFoundOrDenied => 'Song not found or access denied';

  @override
  String get coreFlutterRepoTenantNotLinked => 'Instance is not linked';

  @override
  String coreFlutterRepoTypeInUse(Object count) {
    return 'Type cannot be deleted: used by $count attendance(s)';
  }

  @override
  String coreFlutterRepoUnlinkAccountFailed(Object error) {
    return 'Error removing the account link: $error';
  }

  @override
  String get coreFlutterRolePermissionWithoutId => 'Role permission without ID';

  @override
  String get coreFlutterRouterGoHome => 'Go home';

  @override
  String get coreFlutterRouterInvalidAttendanceId => 'Invalid attendance ID';

  @override
  String get coreFlutterRouterInvalidPersonId => 'Invalid person ID';

  @override
  String get coreFlutterRouterInvalidTenantId => 'Invalid instance ID';

  @override
  String coreFlutterRouterPageNotFound(Object path) {
    return 'Page not found: $path';
  }

  @override
  String get coreFlutterRuleOverall => 'overall';

  @override
  String get coreFlutterRuleSinceSeasonStart => 'since season start';

  @override
  String coreFlutterRuleStatusN(Object n) {
    return 'Status $n';
  }

  @override
  String get coreFlutterSchoolHolidays => 'School holidays';

  @override
  String get coreFlutterSearchHint => 'Search...';

  @override
  String get coreFlutterSheetMusic => 'Sheet music';

  @override
  String coreFlutterShiftFreeRange(Object start, Object end) {
    return 'Off ($start - $end)';
  }

  @override
  String coreFlutterShiftWorkRange(Object start, Object end, Object hours) {
    return 'Work ($start - $end, ${hours}h)';
  }

  @override
  String get coreFlutterSongFiles => 'Song files';

  @override
  String get coreFlutterSongNotFound => 'Song not found or already deleted';

  @override
  String get coreFlutterUpdate => 'Update';

  @override
  String get coreFlutterVoices => 'Voices';

  @override
  String get coreFlutterXlsUnsupported => 'The old Excel format (.xls) is not supported. Please save as .xlsx or .csv.';

  @override
  String get coreFlutterZipFailed => 'ZIP could not be created';

  @override
  String get dashSettingsCards => 'Cards';

  @override
  String get dashSettingsFlutterReorder => 'Change order';

  @override
  String dashSettingsFlutterSaveFailed(Object error) {
    return 'Error while saving: $error';
  }

  @override
  String get dashSettingsReorderHint => 'Tap the icon at the top right to change the order by drag & drop.';

  @override
  String get dashSettingsReset => 'Reset';

  @override
  String get dashSettingsShowTab => 'Show dashboard tab';

  @override
  String get dashSettingsTab => 'Tab';

  @override
  String get dateDialogChangeDate => 'Change date';

  @override
  String get dateDialogChangeFailed => 'The date could not be changed';

  @override
  String get dateDialogCreateFailed => 'The event could not be created';

  @override
  String dateDialogCreated(Object date) {
    return 'Event created on $date';
  }

  @override
  String get dateDialogFromToday => 'Please choose a date from today on';

  @override
  String get dateDialogKeep => 'Keep';

  @override
  String get dateDialogLoadFailed => 'The event could not be loaded';

  @override
  String get dateDialogMoveTo => 'Which day should the event be moved to?';

  @override
  String dateDialogMoved(Object date) {
    return 'Event moved to $date';
  }

  @override
  String get dateDialogNoProtocolType => 'No event type with minutes & agenda available';

  @override
  String get dateDialogReset => 'Reset';

  @override
  String get dateDialogResetStatus => 'Reset status?';

  @override
  String dateDialogResetStatusMessage(Object status) {
    return 'Not everyone is set to “$status”. Should everyone be reset to the default status with the move? Absences on the new day will be entered again afterwards.';
  }

  @override
  String get dateDialogWhichDay => 'On which day does the event take place?';

  @override
  String get dateDialogWhichType => 'Which event type?';

  @override
  String get dbAccountDisabled => 'Your account has been deactivated. Please contact the administrator of your instance.';

  @override
  String get dbAddDefaultTypesFailed => 'Could not add the default event types';

  @override
  String get dbAddParentFailed => 'Could not add the parent.';

  @override
  String get dbAddViewerFailed => 'Could not add the observer.';

  @override
  String get dbChooseInstanceHeader => 'Choose instance';

  @override
  String get dbChooseInstanceMessage => 'Please choose the instance you want to open:';

  @override
  String get dbCodeExpired => 'The code has expired. Please request a new one.';

  @override
  String get dbCodeInvalid => 'The code is invalid. Please check your input.';

  @override
  String get dbCodeSendFailed => 'The code could not be sent. Please try again.';

  @override
  String get dbCodeSent => 'We have sent you a code by email.';

  @override
  String get dbCreateAccountFailed => 'Could not create the account';

  @override
  String dbCreateAccountFailedWith(Object error) {
    return 'Could not create the account: $error';
  }

  @override
  String get dbCreateInstanceFailed => 'Could not create the instance, please try again later.';

  @override
  String get dbCreateUserFailed => 'Could not create the user, please try again later.';

  @override
  String get dbDeleteAccountFailed => 'Could not delete the account';

  @override
  String get dbDeleteInstanceFailed => 'Could not delete the instance, please try again later.';

  @override
  String get dbDeleteParentFailed => 'Could not delete the parent';

  @override
  String get dbDeleteViewerFailed => 'Could not delete the observer';

  @override
  String get dbDemoRestricted => 'This feature is not available in demo mode.';

  @override
  String get dbEmailExists => 'Your email address already exists. Please sign in.';

  @override
  String get dbEnterCorrectData => 'Please enter the correct details!';

  @override
  String get dbFavoriteFailed => 'Could not set the favourite, please try again later.';

  @override
  String get dbInstanceCreated => 'Instance created successfully!';

  @override
  String get dbInstanceDeleted => 'Instance deleted successfully!';

  @override
  String get dbInvalidEmail => 'Invalid email address';

  @override
  String get dbInvalidPassword => 'Invalid password';

  @override
  String get dbLoadAttendanceTypeFailed => 'Could not load the event type';

  @override
  String get dbLoadChildrenFailed => 'Could not load the children';

  @override
  String get dbLoadGroupMembersFailed => 'Could not load the group members';

  @override
  String get dbLoadPeopleFailed => 'Could not load the people';

  @override
  String get dbLoadRoleFailed => 'Could not load the role';

  @override
  String get dbLoadTenantsFailed => 'Could not load instances';

  @override
  String get dbLoadTenantsFailed2 => 'Could not load the instances';

  @override
  String get dbLoadUserFailed => 'Could not load the user';

  @override
  String get dbLoginFailed => 'Sign-in failed';

  @override
  String get dbMainGroupNotFound => 'Main group not found';

  @override
  String get dbNoAccount => 'No account found with this email address. Please sign up first.';

  @override
  String get dbNoPersonFound => 'No person found';

  @override
  String get dbNotifyUserFailed => 'Could not notify the user';

  @override
  String get dbOtpUnavailable => 'Signing in with a code is currently not possible.';

  @override
  String get dbPasswordChangeFailed => 'The password could not be changed. Please try again.';

  @override
  String get dbPasswordSameAsOld => 'The new password must not be the same as the old one.';

  @override
  String get dbPasswordTooWeak => 'The password is too weak. Please choose a stronger password.';

  @override
  String get dbPasswordUpdated => 'Password updated successfully';

  @override
  String get dbPauseOtherFailed => 'Could not pause in the other instance';

  @override
  String dbPersonExistsWithEmail(Object email) {
    return 'A person with the email address \"$email\" already exists in the target instance.';
  }

  @override
  String dbPersonExistsWithName(Object name) {
    return 'A person named \"$name\" already exists in the target instance.';
  }

  @override
  String get dbRegisterFailed => 'Sign-up failed';

  @override
  String get dbRemoveAuthEmailFailed => 'Could not remove the email from authentication';

  @override
  String get dbRemoveFromTenantFailed => 'Could not remove the account from the instance';

  @override
  String get dbResetPasswordFailed => 'Could not reset the password. Please try again later';

  @override
  String get dbResetPasswordSent => 'An email with further instructions has been sent to you';

  @override
  String get dbRoleParent => 'Parent';

  @override
  String get dbRoleViewer => 'Observer';

  @override
  String get dbSessionExpired => 'Your session has expired. Please request the reset link again.';

  @override
  String get dbTooManyAttempts => 'Too many attempts. Please try again later.';

  @override
  String get dbTooManyAttemptsWait => 'Too many attempts. Please wait a moment and try again.';

  @override
  String get dbTooManyLogins => 'Too many sign-in attempts. Please try again later.';

  @override
  String get dbTooManyRequests => 'Too many requests. Please wait a moment and try again.';

  @override
  String get dbUpdateChurchFailed => 'Could not update the church assignment';

  @override
  String get dbUpdatePlayerFailed => 'Could not update the person';

  @override
  String get dbUpdateProfileFailed => 'Could not update the profile';

  @override
  String get dbUpdateRoleFailed => 'Could not update the user role';

  @override
  String get dbUpdateSongHistoryFailed => 'Could not update the song history';

  @override
  String get dbUpdateUserFailed => 'Could not update the user';

  @override
  String get dbUpdateUserFailed2 => 'Could not update the user';

  @override
  String dbUserAlreadyInInstanceAs(Object name, Object role) {
    return 'The user is already in this instance: $name ($role)';
  }

  @override
  String get dbUserAlreadyInTenant => 'The user is already in this instance';

  @override
  String dbUserAlreadyInTenantAs(Object name, Object role) {
    return 'The user is already in this instance: $name ($role)';
  }

  @override
  String get dbWeakPasswordRequirements => 'The password does not meet the security requirements.';

  @override
  String get dbWrongCredentials => 'Wrong email or password. If you have not set a password, use the sign-in code by email.';

  @override
  String get defaultsShowAllInfoText => 'You are not part of this event.';

  @override
  String get defaultsTypesMeeting => 'Meeting';

  @override
  String get defaultsTypesPerformance => 'Performance';

  @override
  String get defaultsTypesRehearsal => 'Rehearsal';

  @override
  String get defaultsTypesRehearsalPlan => 'Rehearsal plan';

  @override
  String get deleteAccountAccess => 'Your access to the app';

  @override
  String get deleteAccountAttendance => 'All your attendance data';

  @override
  String get deleteAccountCannotUndo => 'This action <strong>cannot be undone</strong>.';

  @override
  String get deleteAccountCode => 'Confirmation code';

  @override
  String get deleteAccountCodePlaceholder => 'Enter code';

  @override
  String get deleteAccountConfirm => 'Really delete account?';

  @override
  String get deleteAccountConfirmMessage => 'Your account and all related data will be removed permanently. This action cannot be undone.';

  @override
  String get deleteAccountDeleteFinal => 'Delete permanently';

  @override
  String get deleteAccountDeleteForever => 'Delete account permanently';

  @override
  String get deleteAccountDeleted => 'Your account was deleted.';

  @override
  String get deleteAccountDeleting => 'Deleting account...';

  @override
  String get deleteAccountEnterCode => 'Please enter the following code to confirm:';

  @override
  String deleteAccountFailed(Object error) {
    return 'Deletion failed: $error';
  }

  @override
  String get deleteAccountIntro => 'If you delete your account, <strong>all</strong> your data will be removed permanently:';

  @override
  String get deleteAccountMemberships => 'All your memberships in every instance';

  @override
  String get deleteAccountProfile => 'Your profile and photo';

  @override
  String get deleteAccountTitle => 'Delete account';

  @override
  String get deleteAccountWarning => 'Warning';

  @override
  String get dutyAddRule => 'Add rule';

  @override
  String get dutyAllAssigned => 'Everyone in the group of people is already assigned.';

  @override
  String get dutyAllTypes => 'all event types';

  @override
  String get dutyAllTypesHint => 'Without a selection the rule applies to all event types.';

  @override
  String get dutyAlsoPlanned => 'Planned events too?';

  @override
  String get dutyAlsoPlannedButton => 'Planned too';

  @override
  String dutyAlsoPlannedOther(num count, Object preview, Object name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count planned events match',
      one: '$count planned event matches',
    );
    return '$_temp0 this rule ($preview). Should $name be marked as excused there? Events with their own answer or an assignment stay unchanged.';
  }

  @override
  String dutyAlsoPlannedSelf(num count, Object preview) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count planned events match',
      one: '$count planned event matches',
    );
    return '$_temp0 this rule ($preview). Should you be marked as excused there? Events with your own answer or an assignment stay unchanged.';
  }

  @override
  String get dutyAssignHint => 'Sorted by number of duties. Assigned people get a push notification right away and have to confirm.';

  @override
  String dutyAssignName(Object name) {
    return 'Assign $name';
  }

  @override
  String dutyAssignPeople(Object count) {
    return 'Assign $count people';
  }

  @override
  String dutyAssignedToast(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count duties assigned',
      one: '$count duty assigned',
    );
    return '$_temp0. Everyone gets a push notification.';
  }

  @override
  String get dutyAssigning => 'Assigning…';

  @override
  String get dutyCalculate => 'Calculate suggestion';

  @override
  String get dutyChildrenHourPlaceholder => 'e.g. children\'s hour';

  @override
  String get dutyChoosePerson => 'Choose person';

  @override
  String get dutyChooseTypeMin => 'Please choose at least one event type';

  @override
  String get dutyChooseWeekday => 'Please choose at least one weekday';

  @override
  String get dutyDeclinedToast => 'Declined, the team will be notified.';

  @override
  String get dutyDeleteRule => 'Delete rule';

  @override
  String get dutyDeleteRuleConfirm => 'Delete rule?';

  @override
  String get dutyDeleteRuleMessage => 'Absences already entered remain.';

  @override
  String get dutyDistributeHint => 'Only open places are filled, existing assignments stay. People who declined or are regularly unavailable are not assigned. Whoever has had the fewest duties so far goes first.';

  @override
  String get dutyDistributing => 'Distributing duties…';

  @override
  String dutyDutiesCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count duties',
      one: '$count duty',
    );
    return '$_temp0';
  }

  @override
  String get dutyDutiesPerPerson => 'Duties per person in the period';

  @override
  String get dutyDuty => 'Duty';

  @override
  String get dutyEventTypes => 'Event types';

  @override
  String dutyEventsAdjusted(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count events adjusted',
      one: '$count event adjusted',
    );
    return '$_temp0';
  }

  @override
  String get dutyFlutterAllFilled => 'all filled';

  @override
  String get dutyFlutterDeclineFailed => 'Error while declining';

  @override
  String get dutyFlutterDeleteFailed => 'Error while deleting';

  @override
  String dutyFlutterErrorWith(Object error) {
    return 'Error: $error';
  }

  @override
  String dutyFlutterNameRequested(Object name) {
    return '$name (requested)';
  }

  @override
  String get dutyFlutterNobodyAssigned => 'nobody assigned yet';

  @override
  String get dutyFlutterNothingToDistribute => 'Nothing to distribute';

  @override
  String dutyFlutterPlannedNew(Object count) {
    return '(+$count new)';
  }

  @override
  String dutyFlutterSaveAssignments(Object count) {
    return 'Save $count assignments';
  }

  @override
  String dutyFlutterTimeOClock(Object time) {
    return '$time';
  }

  @override
  String dutyFlutterUnassignMessage(Object name) {
    return '$name will then no longer be assigned.';
  }

  @override
  String get dutyForWhichTypes => 'For which event types?';

  @override
  String get dutyFrom => 'From';

  @override
  String get dutyGreyHint => 'Grey = already assigned, stays unchanged.';

  @override
  String dutyInMonth(Object month) {
    return ' in $month';
  }

  @override
  String get dutyMaxPerPerson => 'At most per person';

  @override
  String get dutyMyRequestsTitle => 'Your duties: please confirm';

  @override
  String get dutyNoDutyEvents => 'There are no events with duty mode in this period.';

  @override
  String get dutyNoRuleOther => 'No rule yet. Enter the weekdays this person generally can\'t make, e.g. Wednesdays because of children\'s hour.';

  @override
  String get dutyNoRuleSelf => 'No rule yet. Enter the weekdays you generally can\'t make, e.g. Wednesdays because of children\'s hour.';

  @override
  String get dutyNobody => 'Nobody (leave place open)';

  @override
  String get dutyNobodyElse => 'Nobody else is available for this event';

  @override
  String get dutyNotTwiceSameDay => 'Not twice on the same day';

  @override
  String get dutyOnlyNew => 'Only new events';

  @override
  String get dutyOpen => 'open';

  @override
  String get dutyOverbooked => 'You chose more people than there are free places. The duty will be overstaffed.';

  @override
  String get dutyPeriod => 'Period';

  @override
  String dutyPlacesFree(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count places free',
      one: '$count place free',
    );
    return '$_temp0';
  }

  @override
  String dutyPlannedSummary(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count assignments',
      one: '$count assignment',
    );
    return '$_temp0 planned.';
  }

  @override
  String dutyPlannedSummaryMissing(num count, num missing) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count assignments',
      one: '$count assignment',
    );
    String _temp1 = intl.Intl.pluralLogic(
      missing,
      locale: localeName,
      other: '$missing places stay',
      one: '$missing place stays',
    );
    return '$_temp0 planned, $_temp1 open.';
  }

  @override
  String get dutyReasonOptional => 'Reason (optional)';

  @override
  String get dutyRedistribute => 'Redistribute';

  @override
  String get dutyRuleHint => 'New events on these days are automatically marked as excused. You won\'t be assigned to duties then.';

  @override
  String get dutyRules => 'Rules';

  @override
  String get dutySameDay => '· already on duty that day';

  @override
  String get dutySaved => 'Saved';

  @override
  String dutySwap(Object name) {
    return 'Swap $name';
  }

  @override
  String get dutyTapToSwap => 'Tap a name to swap.';

  @override
  String get dutyTo => 'To';

  @override
  String get dutyUnlimited => 'no end date';

  @override
  String dutyUntil(Object date) {
    return 'until $date';
  }

  @override
  String get dutyValidUntil => 'Valid until (optional)';

  @override
  String get dutyWeekdays => 'Weekdays';

  @override
  String get editorAgendaDesc => 'Insert agenda item';

  @override
  String get editorBold => 'Bold';

  @override
  String get editorBulletDesc => 'Unordered list';

  @override
  String get editorBulletList => 'Bulleted list';

  @override
  String get editorFormatting => 'Formatting';

  @override
  String get editorH1 => 'Heading 1';

  @override
  String get editorH1Desc => 'Large heading';

  @override
  String get editorH2 => 'Heading 2';

  @override
  String get editorH2Desc => 'Medium heading';

  @override
  String get editorHeading => 'Heading';

  @override
  String get editorItalic => 'Italic';

  @override
  String get editorLink => 'Link';

  @override
  String get editorLinkText => 'Display text (optional)';

  @override
  String get editorMessagePlaceholder => 'Write a message …';

  @override
  String get editorNewTask => '/aufgabe – New task';

  @override
  String get editorNewTaskDesc => 'Create and link a task';

  @override
  String get editorNotesPlaceholder => 'Tap here to write notes …';

  @override
  String get editorOrderedDesc => 'Ordered list';

  @override
  String get editorOrderedList => 'Numbered list';

  @override
  String get editorStrike => 'Strikethrough';

  @override
  String get editorUnderline => 'Underline';

  @override
  String get editorUndo => 'Undo';

  @override
  String get excuseCustomOption => 'Other reason (text)';

  @override
  String get excuseLate => 'Late arrival';

  @override
  String get excuseMinChars => 'Enter at least 5 characters...';

  @override
  String get excuseReason => 'Reason';

  @override
  String get excuseSignOut => 'Absence';

  @override
  String get exportAddExtraField => 'Add extra field';

  @override
  String get exportAddField => 'Add field';

  @override
  String get exportAsc => 'Ascending (A–Z)';

  @override
  String get exportAttendance => 'Attendance';

  @override
  String exportAttendanceFile(Object name, Object date) {
    return '${name}_${date}_Attendance.xlsx';
  }

  @override
  String exportAttendanceFileAsOf(Object name, Object date) {
    return '${name}_attendance_$date';
  }

  @override
  String get exportAttendancePercent => 'Attendance %';

  @override
  String exportAttendanceTitle(Object name) {
    return '$name attendance';
  }

  @override
  String get exportChurch => 'Church';

  @override
  String get exportDesc => 'Descending (Z–A)';

  @override
  String get exportDuration => 'Duration';

  @override
  String get exportExport => 'Export';

  @override
  String get exportExportType => 'Export type';

  @override
  String get exportFields => 'Fields';

  @override
  String get exportFirstName => 'First name';

  @override
  String get exportFlutterColumnName => 'Column name';

  @override
  String get exportFlutterCustomFieldEmpty => 'Custom field (empty)';

  @override
  String exportFlutterFailedWith(Object error) {
    return 'Export failed: $error';
  }

  @override
  String get exportFlutterPdfLimitHint => 'The PDF export is limited to the last 8 events. Use the Excel export for all events of the season.';

  @override
  String get exportFlutterSuccess => 'Export successful';

  @override
  String get exportGroup => 'Group';

  @override
  String get exportLastName => 'Last name';

  @override
  String get exportNoPlan => 'No plan available';

  @override
  String get exportNotes => 'Notes';

  @override
  String get exportOrder => 'Order';

  @override
  String get exportPerformer => 'Performed by';

  @override
  String exportPlayerListFile(Object name, Object date) {
    return '${name}_member_list_$date';
  }

  @override
  String exportPlayerListTitle(Object name) {
    return '$name member list';
  }

  @override
  String get exportPlayers => 'Members';

  @override
  String get exportProgrammeItem => 'Programme item';

  @override
  String get exportRunSheet => 'Run sheet';

  @override
  String get exportSortBy => 'Sort by';

  @override
  String get exportStatus => 'Status';

  @override
  String get exportTime => 'Time';

  @override
  String get exportTitle => 'Export data';

  @override
  String get extraFieldsAddNew => 'Add new field';

  @override
  String get extraFieldsAddOption => 'Please add at least one option to the selection field.';

  @override
  String get extraFieldsAllNeedName => 'All fields must have a name.';

  @override
  String get extraFieldsAsChip => 'As chip';

  @override
  String get extraFieldsChurch => 'BFECG church';

  @override
  String get extraFieldsDefaultOptional => 'Default value (optional)';

  @override
  String get extraFieldsDefaultValue => 'Default value';

  @override
  String get extraFieldsDeleteField => 'Delete field?';

  @override
  String extraFieldsDeleteFieldMessage(Object name) {
    return 'Do you really want to delete the field “$name”?';
  }

  @override
  String get extraFieldsDeleteOption => 'Delete option?';

  @override
  String extraFieldsDeleteOptionMessage(Object option) {
    return 'If you delete the option “$option”, all affected records are reset to the default value.';
  }

  @override
  String get extraFieldsDisplay => 'Display in lists';

  @override
  String extraFieldsDisplayLine(Object mode) {
    return 'Display: $mode';
  }

  @override
  String get extraFieldsEditable => 'Editable by members';

  @override
  String get extraFieldsEditableHelper => 'Enable so members can change the value themselves.';

  @override
  String get extraFieldsEditableSuffix => ' (editable)';

  @override
  String get extraFieldsFlutterFirstOptionDefault => 'The first option is the default value';

  @override
  String get extraFieldsFlutterLeaveMessage => 'You have unsaved changes. Do you want to leave the page anyway?';

  @override
  String get extraFieldsForPersons => 'Additional fields for people';

  @override
  String get extraFieldsForSongs => 'Additional fields for pieces';

  @override
  String get extraFieldsIdEmpty => 'The field ID must not be empty.';

  @override
  String get extraFieldsIdExists => 'A field with this ID already exists. Please choose another name.';

  @override
  String get extraFieldsInvalidName => 'Please enter a valid name for the field.';

  @override
  String get extraFieldsNoOptions => 'No options';

  @override
  String get extraFieldsNoOptionsSelected => 'No options selected';

  @override
  String get extraFieldsNoneYet => 'No additional fields have been added yet.';

  @override
  String get extraFieldsNumber => 'Number';

  @override
  String get extraFieldsOptionsEmpty => 'Options must not be empty.';

  @override
  String extraFieldsOptionsEmptyIn(Object name) {
    return 'The options in the field “$name” must not be empty.';
  }

  @override
  String extraFieldsPersonsUpdated(Object count) {
    return '$count people updated';
  }

  @override
  String get extraFieldsResetAll => 'Reset all values to default';

  @override
  String get extraFieldsResetValues => 'Reset values?';

  @override
  String extraFieldsResetValuesMessage(Object name) {
    return 'Do you really want to reset all values of the field “$name” to the default? This cannot be undone!';
  }

  @override
  String get extraFieldsSaveFailed => 'Error saving';

  @override
  String get extraFieldsSaved => 'Fields saved';

  @override
  String get extraFieldsSaving => 'Saving fields...';

  @override
  String get extraFieldsSelect => 'Selection';

  @override
  String extraFieldsSelectNeedsOption(Object name) {
    return 'The selection field “$name” needs at least one option.';
  }

  @override
  String get extraFieldsTextarea => 'Text area';

  @override
  String get extraFieldsTitle => 'Additional fields';

  @override
  String extraFieldsTypeLine(Object type) {
    return 'Type: $type';
  }

  @override
  String get extraFieldsUnderName => 'Below the name';

  @override
  String get extraFieldsValuePh => 'Enter value...';

  @override
  String get extraFieldsVisible => 'Visible to members';

  @override
  String get extraFieldsVisibleHelper => 'Enable so members can see this field in their details.';

  @override
  String get extraFieldsYesNo => 'Yes/No';

  @override
  String get filesAlmostFull => ' · almost full';

  @override
  String filesAndMore(Object count) {
    return ' and $count more';
  }

  @override
  String get filesAscending => 'ascending';

  @override
  String filesChangedAt(Object date) {
    return '· Modified: $date';
  }

  @override
  String get filesConnectTelegram => 'Please connect Telegram in the notifications first.';

  @override
  String get filesCreate => 'Create';

  @override
  String get filesCreateFolder => 'Create folder';

  @override
  String filesDeleteFailed(Object error) {
    return 'Deleting failed: $error';
  }

  @override
  String get filesDeleteFile => 'Delete file?';

  @override
  String get filesDeleteFolder => 'Delete folder?';

  @override
  String filesDeleteMessage(Object name) {
    return 'Do you really want to delete $name?';
  }

  @override
  String get filesDeleted => 'Entry deleted.';

  @override
  String get filesDescending => 'descending';

  @override
  String get filesDownload => 'Download file';

  @override
  String filesDownloadFailed(Object error) {
    return 'Download failed: $error';
  }

  @override
  String get filesExists => 'File already exists';

  @override
  String filesExistsMessage(Object names) {
    return 'The following file(s) already exist: $names. Do you want to overwrite them?';
  }

  @override
  String get filesFlutterAscending => 'Ascending';

  @override
  String get filesFlutterDescending => 'Descending';

  @override
  String get filesFlutterMovePh => 'e.g. Documents/2026';

  @override
  String get filesFlutterOpenDownload => 'Open/download file';

  @override
  String get filesFlutterOpenFolder => 'Open folder';

  @override
  String get filesFlutterOpenLinkFailed => 'Link could not be opened';

  @override
  String get filesFlutterShareFolderLink => 'Share link to this folder';

  @override
  String get filesFlutterShareRootLink => 'Share link to the file storage';

  @override
  String get filesFolderCreated => 'Folder created.';

  @override
  String get filesFolderEmpty => 'This folder is empty.';

  @override
  String filesFolderFailed(Object error) {
    return 'Folder could not be created: $error';
  }

  @override
  String get filesFolderName => 'Folder name';

  @override
  String get filesFull => ' · full';

  @override
  String get filesHowMuch => 'Roughly how much storage do you need? (optional)';

  @override
  String get filesLinkCopied => 'Link copied to clipboard';

  @override
  String filesLinkToast(Object url) {
    return 'Link: $url';
  }

  @override
  String get filesLinkedNotFound => 'The linked file was not found.';

  @override
  String filesLoadFailed(Object error) {
    return 'Error loading files: $error';
  }

  @override
  String get filesModified => 'Date modified';

  @override
  String get filesMove => 'Move';

  @override
  String filesMoveFailed(Object error) {
    return 'Moving failed: $error';
  }

  @override
  String get filesMoveHint => 'Target folder relative to the root. Leave empty for root.';

  @override
  String get filesMoved => 'Entry moved.';

  @override
  String get filesName => 'Name';

  @override
  String get filesNewName => 'New name';

  @override
  String get filesNoAccess => 'You have no access to files.';

  @override
  String get filesNoDeleteRights => 'You may not delete files.';

  @override
  String get filesNoEditRights => 'You may not edit files.';

  @override
  String filesNoHits(Object term) {
    return 'No results for “$term”.';
  }

  @override
  String get filesNoneUploaded => 'No file uploaded.';

  @override
  String get filesOverwrite => 'Overwrite';

  @override
  String filesPlayFailed(Object error) {
    return 'Playback failed: $error';
  }

  @override
  String filesPreviewFailed(Object error) {
    return 'Image preview failed: $error';
  }

  @override
  String get filesRename => 'Rename';

  @override
  String filesRenameFailed(Object error) {
    return 'Renaming failed: $error';
  }

  @override
  String get filesRenameFile => 'Rename file';

  @override
  String get filesRenameFolder => 'Rename folder';

  @override
  String get filesRenamed => 'Entry renamed.';

  @override
  String filesRequestFailed(Object error) {
    return 'Error sending the request: $error';
  }

  @override
  String get filesRequestHint => 'The request goes to the Attendix admin, who will get back to you.';

  @override
  String get filesRequestMore => 'Request more storage';

  @override
  String get filesRequestSent => 'Your request has been sent. We\'ll get back to you as soon as possible.';

  @override
  String get filesResetSearch => 'Reset search';

  @override
  String get filesRoot => 'Root';

  @override
  String get filesSearch => 'Search';

  @override
  String get filesSearchCombine => 'Filters can be combined, e.g. <strong>minutes type:pdf date:2026</strong>.';

  @override
  String get filesSearchDate => '<strong>date:&lt;value&gt;</strong> · Filters by date modified (e.g. <strong>date:2026</strong>, <strong>date:03.2026</strong>, <strong>date:03.03.2026</strong>).';

  @override
  String get filesSearchHelp => 'Free text searches the file/folder name.';

  @override
  String get filesSearchPlaceholder => 'Search files & folders...';

  @override
  String get filesSearchType => '<strong>type:&lt;value&gt;</strong> · Filters by file type or kind (e.g. <strong>type:pdf</strong>, <strong>type:folder</strong>, <strong>type:file</strong>).';

  @override
  String get filesSend => 'Send';

  @override
  String get filesSendTelegram => 'Send via Telegram';

  @override
  String get filesSendingTelegram => 'Sending file via Telegram...';

  @override
  String get filesShareLink => 'Share link';

  @override
  String get filesSize => 'File size';

  @override
  String get filesSkip => 'Skip';

  @override
  String filesSortDate(Object dir) {
    return 'Date ($dir)';
  }

  @override
  String filesSortName(Object dir) {
    return 'Name ($dir)';
  }

  @override
  String filesSortSize(Object dir) {
    return 'Size ($dir)';
  }

  @override
  String get filesSorting => 'Sorting';

  @override
  String get filesStorageFull => 'Storage full';

  @override
  String filesStorageFullMessage(Object needed, Object free, Object max) {
    return 'This upload needs $needed, but only $free of $max is free. Delete files you no longer need or request more storage.';
  }

  @override
  String filesStorageUsed(Object used) {
    return 'Storage: $used used';
  }

  @override
  String filesStorageUsedOf(Object used, Object max) {
    return 'Storage: $used of $max used';
  }

  @override
  String filesTelegramFailed(Object error) {
    return 'Sending via Telegram failed: $error';
  }

  @override
  String get filesTitle => 'Files';

  @override
  String get filesUpload => 'Upload files';

  @override
  String filesUploadProgress(Object done, Object total, Object percent) {
    return 'Upload $done/$total ($percent%)';
  }

  @override
  String filesUploadSummary(Object ok, Object skipped, Object failed) {
    return '$ok uploaded, $skipped skipped, $failed failed.';
  }

  @override
  String filesUploadedMany(Object count) {
    return '$count files uploaded.';
  }

  @override
  String get filesUploadedOne => 'File uploaded.';

  @override
  String get folderPickerChoose => 'Choose';

  @override
  String get folderPickerChooseThis => 'Choose this folder';

  @override
  String folderPickerLoadFailed(Object error) {
    return 'Could not load the folders: $error';
  }

  @override
  String get folderPickerNoSubfolders => 'No subfolders.';

  @override
  String get folderPickerParent => 'Parent folder';

  @override
  String get folderPickerTitle => 'Choose folder';

  @override
  String get generalSettingsAbsenceReasons => 'Absence reasons';

  @override
  String get generalSettingsAddReason => 'Add reason';

  @override
  String get generalSettingsAddRule => 'Add rule';

  @override
  String get generalSettingsAllEvents => 'All events visible to members';

  @override
  String get generalSettingsAllEventsHelper => 'Enable so members can see all events of the instance on the sign-out page (not just their own). Their own events are highlighted.';

  @override
  String get generalSettingsAllTime => 'Entire history';

  @override
  String get generalSettingsAllTypes => 'All types';

  @override
  String get generalSettingsAllowRegister => 'Allow registration';

  @override
  String get generalSettingsAnd => 'AND (all rules must match)';

  @override
  String get generalSettingsAttTypes => 'Attendance types';

  @override
  String get generalSettingsAttendance => 'Attendance';

  @override
  String get generalSettingsAutoApprove => 'Auto-approval';

  @override
  String get generalSettingsAutoApproveHelper => 'Enable to approve new registrations automatically. Otherwise they must be approved manually.';

  @override
  String get generalSettingsBranding => 'Branding';

  @override
  String get generalSettingsCombine => 'Combination';

  @override
  String get generalSettingsCombineHelper => 'How this rule is combined with other rules';

  @override
  String get generalSettingsCount => 'Count';

  @override
  String get generalSettingsCriticalRules => 'Problem case rules';

  @override
  String get generalSettingsDays => 'Number of days';

  @override
  String get generalSettingsDaysHelper => 'Number of days checked backwards';

  @override
  String get generalSettingsDeleteRule => 'Delete rule?';

  @override
  String get generalSettingsDeleteRuleMessage => 'Do you really want to delete this rule?';

  @override
  String get generalSettingsDutyView => 'Duty roster view for My events';

  @override
  String get generalSettingsDutyViewHelper => '“My events” shows people in a duty team their duties, open duties and numbers instead of the attendance rate first. Other events are collapsed below.';

  @override
  String get generalSettingsFlutterAndHint => 'Person is critical if ALL rules apply';

  @override
  String get generalSettingsFlutterAndShort => 'AND';

  @override
  String get generalSettingsFlutterDaysSuffix => 'days';

  @override
  String generalSettingsFlutterDeleteRuleNamed(Object name) {
    return 'Do you really want to delete the rule \"$name\"?';
  }

  @override
  String get generalSettingsFlutterDisabled => 'Disabled';

  @override
  String get generalSettingsFlutterEditRule => 'Edit rule';

  @override
  String get generalSettingsFlutterExcuses => 'Excuses';

  @override
  String get generalSettingsFlutterExcusesHelper => 'Allows \"Excused\" as a status';

  @override
  String generalSettingsFlutterFieldsCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fields',
      one: '$count field',
    );
    return '$_temp0';
  }

  @override
  String get generalSettingsFlutterNoHolidays => 'No holidays';

  @override
  String get generalSettingsFlutterNoTypes => 'No event types available';

  @override
  String get generalSettingsFlutterOrHint => 'Person is critical if ANY of the rules applies';

  @override
  String get generalSettingsFlutterOrShort => 'OR';

  @override
  String get generalSettingsFlutterPracticeEnd => 'Rehearsal end';

  @override
  String get generalSettingsFlutterPracticeStart => 'Rehearsal start';

  @override
  String get generalSettingsFlutterRuleAdded => 'Rule added';

  @override
  String get generalSettingsFlutterRuleDeleted => 'Rule deleted';

  @override
  String get generalSettingsFlutterRuleEnabled => 'Rule enabled';

  @override
  String get generalSettingsFlutterRuleEnabledHelper => 'Disabled rules are not evaluated';

  @override
  String get generalSettingsFlutterRuleUpdated => 'Rule updated';

  @override
  String get generalSettingsFlutterStatusCritical => 'Status (counts as critical)';

  @override
  String get generalSettingsForeignInfo => 'Info text for other events';

  @override
  String get generalSettingsForeignInfoPh => 'You are not part of this event.';

  @override
  String get generalSettingsGeneral => 'General';

  @override
  String get generalSettingsGroupNameEmpty => 'The name must not be empty.';

  @override
  String get generalSettingsHolidayState => 'State for holidays';

  @override
  String get generalSettingsHolidaysHelper => 'Enable to highlight school holidays and public holidays when creating attendance (only available for Germany).';

  @override
  String get generalSettingsLastXDays => 'Last X days';

  @override
  String get generalSettingsLateExcusedShort => 'Late (excused)';

  @override
  String get generalSettingsLateReasons => 'Lateness reasons';

  @override
  String get generalSettingsMaintainTeachers => 'Manage teachers';

  @override
  String get generalSettingsMembersList => 'Member list for everyone';

  @override
  String get generalSettingsMembersListHelper => 'Enable to show members (members, helpers, section leaders) an overview of all people.';

  @override
  String get generalSettingsNameOptional => 'Name (optional)';

  @override
  String get generalSettingsNeutral => 'Neutral';

  @override
  String get generalSettingsNewRule => 'Add new rule';

  @override
  String get generalSettingsNoGroupsYet => 'There are no groups yet. Please create at least one group before enabling registration.';

  @override
  String get generalSettingsNoRules => 'No problem case rules yet. Rules define when a person is marked as a problem case.';

  @override
  String get generalSettingsNone => 'None';

  @override
  String get generalSettingsOr => 'OR (one rule must match)';

  @override
  String get generalSettingsOther => 'Other';

  @override
  String get generalSettingsParentsFeature => 'Parents feature';

  @override
  String get generalSettingsParentsHelper => 'Enable to let parents see their children\'s attendance and manage absences.';

  @override
  String get generalSettingsPercent => 'Percent';

  @override
  String get generalSettingsPeriodHelper => 'Defines the period that is counted';

  @override
  String get generalSettingsPeriodPositive => 'The period must be greater than 0.';

  @override
  String get generalSettingsPeriodType => 'Period type';

  @override
  String get generalSettingsReasonPh => 'Enter reason...';

  @override
  String get generalSettingsReasons => 'Absence & lateness reasons';

  @override
  String generalSettingsReasonsCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count reasons',
      one: '$count reason',
    );
    return '$_temp0 configured';
  }

  @override
  String get generalSettingsRegisterFields => 'Registration fields';

  @override
  String get generalSettingsRegisterFieldsHint => 'Choose the fields shown during registration. All selected fields are required.';

  @override
  String get generalSettingsRegisterHelper => 'Enable to let new people register in this instance. The link is generated automatically and can be copied after saving.';

  @override
  String get generalSettingsRegisterNoGroups => 'Registration cannot be enabled: please create at least one group first.';

  @override
  String get generalSettingsRegistration => 'Registration';

  @override
  String get generalSettingsReload => 'Reload';

  @override
  String get generalSettingsRestoreDefaults => 'Restore defaults';

  @override
  String get generalSettingsRulePh => 'e.g. Lateness warning';

  @override
  String get generalSettingsSaveFailed => 'Error updating the settings';

  @override
  String get generalSettingsSaved => 'Settings saved';

  @override
  String get generalSettingsSavedReload => 'The settings were saved. Please reload the page to see the changes.';

  @override
  String get generalSettingsSaving => 'Saving settings...';

  @override
  String get generalSettingsSeasonHelper => 'Attendance only counts for people from this date';

  @override
  String get generalSettingsSeasonStart => 'Season start';

  @override
  String get generalSettingsSelectStatus => 'Please select at least one status.';

  @override
  String get generalSettingsShareSongs => 'Share pieces publicly';

  @override
  String get generalSettingsShareSongsHelper => 'Enable to share pieces via a public link. Anyone with the link can view but not edit them. The link is generated automatically and can be copied after saving.';

  @override
  String get generalSettingsShiftPlans => 'Shift plans';

  @override
  String get generalSettingsShiftPresent => 'Shift/work-related = present';

  @override
  String get generalSettingsShiftPresentHelper => 'Enable to count absences excused for shift or work reasons as present in the percentage.';

  @override
  String get generalSettingsShortNameEmpty => 'The short name must not be empty.';

  @override
  String get generalSettingsShortNameHelper => 'Mainly used as file name for exports';

  @override
  String get generalSettingsShowHolidays => 'Show holidays';

  @override
  String get generalSettingsSinceSeason => 'Since season start';

  @override
  String get generalSettingsSongDb => 'Piece database';

  @override
  String get generalSettingsTeachersHelper => 'Enable to manage the members\' teachers.';

  @override
  String get generalSettingsTenantName => 'Instance name';

  @override
  String get generalSettingsTenantShort => 'Instance short name';

  @override
  String get generalSettingsThresholdPositive => 'The threshold must be greater than 0.';

  @override
  String get generalSettingsThresholdType => 'Threshold type';

  @override
  String get handoverAddFilter => 'Add filter';

  @override
  String handoverAlreadyThere(Object names) {
    return 'The following people could not be transferred because they already exist in the target instance:\n$names';
  }

  @override
  String get handoverArchiveNote => 'The people will be archived in this instance.';

  @override
  String handoverConfirm(Object count, Object tenant, Object note) {
    return 'Do you really want to transfer the $count selected people to the instance “$tenant”? $note';
  }

  @override
  String get handoverFailed => 'Handover failed';

  @override
  String handoverFailedWith(Object error) {
    return 'Handover failed: $error';
  }

  @override
  String get handoverGroupMapping => 'Group mapping';

  @override
  String get handoverInGroupDots => 'Is in group...';

  @override
  String get handoverIntro => 'Here you can hand over people within an organisation or copy them to another instance. If the person has an account, they will be informed.';

  @override
  String get handoverKeepHelper => 'The person is not archived in the current instance but stays active';

  @override
  String get handoverKeepInTenant => 'Keep people in instance';

  @override
  String get handoverMainGroupHelper => 'People in the main group are shown as well';

  @override
  String get handoverNoData => 'No data for the handover.';

  @override
  String get handoverNoOtherTenants => 'There are no other instances. Please add more instances to this organisation.';

  @override
  String get handoverNoneSelected => 'No people selected';

  @override
  String get handoverOlderThan => 'Older than';

  @override
  String get handoverOlderThanDots => 'Older than...';

  @override
  String get handoverPersonList => 'Person list';

  @override
  String get handoverRespectMainGroup => 'Consider main group';

  @override
  String get handoverSelectAll => 'Select all';

  @override
  String get handoverSelectGroup => 'Select group';

  @override
  String get handoverSettings => 'Settings';

  @override
  String get handoverStayNote => 'The people stay in this instance.';

  @override
  String get handoverTargetTenant => 'Target instance';

  @override
  String get handoverTitle => 'Person handover';

  @override
  String get handoverTransfer => 'Transfer';

  @override
  String handoverTransferred(Object count) {
    return '$count people were transferred.';
  }

  @override
  String get handoverTransferring => 'Transferring people...';

  @override
  String get handoverYoungerThan => 'Younger than';

  @override
  String get handoverYoungerThanDots => 'Younger than...';

  @override
  String get helpArticleNotFound => 'This article was not found.';

  @override
  String get helpArticles => 'Articles';

  @override
  String get helpGlossary => 'Glossary';

  @override
  String get helpLookup => 'Look up';

  @override
  String helpNoHits(Object term) {
    return 'No results for “$term”.';
  }

  @override
  String get helpNoTerms => 'No terms found.';

  @override
  String get helpSearchPlaceholder => 'Search question or keyword...';

  @override
  String get helpSearchTerm => 'Search term...';

  @override
  String get helpTitle => 'Help';

  @override
  String get helpTopics => 'Topics';

  @override
  String get historyAddSongs => 'Add piece(s)';

  @override
  String get historyDatePlaceholder => 'DD.MM.YYYY';

  @override
  String get historyFlutterEntryDeleted => 'Entry deleted';

  @override
  String get historyFlutterNoTenant => 'No tenant selected';

  @override
  String historyFlutterSongsAdded(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pieces added',
      one: 'Piece added',
    );
    return '$_temp0';
  }

  @override
  String get historyFlutterUnknownSong => 'Unknown piece';

  @override
  String get historyNoneFound => 'No pieces found';

  @override
  String get historyNoneSelected => 'No pieces selected';

  @override
  String get historyNoneYet => 'No pieces played yet';

  @override
  String historyRehearsals(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rehearsals',
      one: '$count rehearsal',
    );
    return '$_temp0';
  }

  @override
  String get historyRemoveConfirm => 'Do you really want to remove this entry?';

  @override
  String get historySearchSong => 'Search piece...';

  @override
  String get historySelectAtLeastOne => 'Please select at least one piece';

  @override
  String get historySelectSongs => 'Select pieces';

  @override
  String historySelectedCount(Object count) {
    return '$count piece(s) selected';
  }

  @override
  String get historySongs => 'Piece(s)';

  @override
  String get historyTitle => 'Piece history';

  @override
  String get homeDashboardAbsences => 'Absences & pauses';

  @override
  String get homeDashboardAllHidden => 'All cards are hidden. Configure the dashboard in the settings.';

  @override
  String get homeDashboardAverage => 'Average';

  @override
  String get homeDashboardBirthdayRange => 'Last and next 14 days';

  @override
  String get homeDashboardBirthdays => 'Birthdays';

  @override
  String get homeDashboardConfigure => 'Configure dashboard';

  @override
  String get homeDashboardCurrent => 'Current';

  @override
  String get homeDashboardCurrentPlan => 'Current run sheet';

  @override
  String get homeDashboardCurrentProblemCases => 'Current problem cases';

  @override
  String get homeDashboardCurrentSongs => 'Current pieces';

  @override
  String homeDashboardDaysAgo(Object count) {
    return '$count days ago';
  }

  @override
  String get homeDashboardEvents => 'Events';

  @override
  String get homeDashboardFlutterExit => 'Left';

  @override
  String get homeDashboardFlutterJoin => 'Joined';

  @override
  String homeDashboardFlutterLoadFailed(Object error) {
    return 'Error while loading: $error';
  }

  @override
  String get homeDashboardFlutterPause => 'Pause';

  @override
  String homeDashboardFlutterTimeRange(Object time) {
    return '$time';
  }

  @override
  String homeDashboardInDays(Object count) {
    return 'in $count days';
  }

  @override
  String get homeDashboardLast4Weeks => 'Last 4 weeks';

  @override
  String get homeDashboardLast60Days => 'Last 60 days';

  @override
  String get homeDashboardLastEvent => 'Last event';

  @override
  String homeDashboardLastSummary(Object present, Object total, Object excused) {
    return '$present/$total present · $excused excused';
  }

  @override
  String get homeDashboardLateExcusedShort => 'Late (excused)';

  @override
  String get homeDashboardLive => 'Live';

  @override
  String get homeDashboardMemberChanges => 'Member changes';

  @override
  String get homeDashboardNextAndLast => 'Next & last event';

  @override
  String get homeDashboardNoAbsences => 'No absences in this period.';

  @override
  String get homeDashboardNoBirthdays => 'No birthdays in this period.';

  @override
  String get homeDashboardNoChanges => 'No changes in this period.';

  @override
  String get homeDashboardNoEvents => 'No events found.';

  @override
  String get homeDashboardNoPlannedSongs => 'No planned pieces.';

  @override
  String get homeDashboardNoProblemCases => 'No problem cases.';

  @override
  String homeDashboardPlanTimes(Object start, Object end, num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '$count item',
    );
    return '$start – $end · $_temp0';
  }

  @override
  String get homeDashboardPlannedSongs => 'Planned pieces';

  @override
  String get homeDashboardProblemCases => 'Problem cases';

  @override
  String get homeDashboardRecently => 'Recently';

  @override
  String get homeDashboardShift => 'Shift';

  @override
  String homeDashboardShiftCount(Object count) {
    return '$count shift';
  }

  @override
  String get homeDashboardSignOuts => 'Sign-outs';

  @override
  String get homeDashboardSignedOut => 'Signed out';

  @override
  String homeDashboardTotalCount(Object count) {
    return '$count total';
  }

  @override
  String homeDashboardTurned(Object age) {
    return 'turned $age';
  }

  @override
  String homeDashboardTurns(Object age) {
    return 'turns $age';
  }

  @override
  String homeDashboardTurnsToday(Object age) {
    return 'turns $age today';
  }

  @override
  String get homeDashboardYesterday => 'Yesterday';

  @override
  String get imageViewerHint => 'Double-tap or pinch to zoom';

  @override
  String get imageViewerLoadFailed => 'Image could not be loaded';

  @override
  String get imageViewerZoomIn => 'Zoom in';

  @override
  String get imageViewerZoomOut => 'Zoom out';

  @override
  String get imageViewerZoomReset => 'Reset zoom';

  @override
  String get instrumentsAddGroup => 'Add group';

  @override
  String get instrumentsCannotDelete => 'You cannot delete this instrument because people play (or played) it';

  @override
  String get instrumentsCategories => 'Categories';

  @override
  String get instrumentsCategory => 'Category';

  @override
  String get instrumentsCategoryName => 'Category name';

  @override
  String get instrumentsDeleteCategory => 'Really delete the category? All groups in it lose their category.';

  @override
  String get instrumentsDeleteGroup => 'Really delete the group?';

  @override
  String get instrumentsDragCategories => 'Drag the categories to change the order. Click the tick to save.';

  @override
  String get instrumentsDragGroups => 'Drag the groups to change the order. Click the tick to save.';

  @override
  String get instrumentsEditCategory => 'Edit category';

  @override
  String get instrumentsEnterName => 'Please enter a name';

  @override
  String get instrumentsEs => 'E♭';

  @override
  String get instrumentsFlutterAddFailed => 'Could not add';

  @override
  String instrumentsFlutterClef(Object clef) {
    return '$clef clef';
  }

  @override
  String get instrumentsFlutterClefs => 'Clefs';

  @override
  String get instrumentsFlutterGenerateSynonyms => 'Generate synonyms';

  @override
  String get instrumentsFlutterNoCategories => 'No categories';

  @override
  String get instrumentsFlutterNoCategoriesHint => 'Tap + to create a category';

  @override
  String get instrumentsFlutterShortName => 'Short name';

  @override
  String get instrumentsGeneratingSynonyms => 'Generating synonyms...';

  @override
  String get instrumentsGroupPh => 'e.g. Girls, Trombone, Alto 1, etc.';

  @override
  String instrumentsGroupsCount(Object count) {
    return 'Groups ($count)';
  }

  @override
  String instrumentsMainGroup(Object name) {
    return '$name (main group)';
  }

  @override
  String get instrumentsNameFirst => 'Please enter a name first!';

  @override
  String get instrumentsNameRequired => 'Please enter a name!';

  @override
  String get instrumentsNewCategory => 'New category';

  @override
  String get instrumentsNoCategory => 'No category';

  @override
  String get instrumentsOrderFailed => 'Error saving the order';

  @override
  String get instrumentsRange => 'Range';

  @override
  String get instrumentsSavingOrder => 'Saving order...';

  @override
  String get instrumentsSynonyms => 'Synonyms';

  @override
  String get instrumentsSynonymsFailed => 'Error generating synonyms';

  @override
  String get instrumentsSynonymsGenerated => 'Synonyms generated!';

  @override
  String get instrumentsSynonymsHelper => 'Define synonyms so instruments are assigned automatically when adding files to pieces. Separate synonyms with commas.';

  @override
  String get instrumentsTuning => 'Tuning';

  @override
  String get instrumentsUpdate => 'Update';

  @override
  String instrumentsUpdated(Object name) {
    return '$name was updated';
  }

  @override
  String get legalLoadFailed => 'Content could not be loaded.';

  @override
  String get legalTitle => 'Legal notice & privacy';

  @override
  String get linkPersonsFailed => 'Linking failed';

  @override
  String get linkPersonsIgnore => 'Ignore';

  @override
  String get linkPersonsIntro => 'Possible matches from different instances. Linked people sync name, birthday, email and phone automatically.';

  @override
  String get linkPersonsLink => 'Link';

  @override
  String linkPersonsLinked(Object count) {
    return '$count people linked';
  }

  @override
  String linkPersonsLinkedCount(Object count) {
    return '$count people were linked.';
  }

  @override
  String get linkPersonsNoMore => 'No more suggestions.';

  @override
  String get linkPersonsReasonFirstNamePrefix => 'First name prefix';

  @override
  String get linkPersonsReasonLastNamePrefix => 'Last name prefix';

  @override
  String get linkPersonsReasonLinked => 'Linked person';

  @override
  String get linkPersonsReasonNearlyIdentical => 'Name nearly identical';

  @override
  String get linkPersonsReasonSameBirthday => 'Same birthday';

  @override
  String get linkPersonsReasonSameEmail => 'Same email';

  @override
  String get linkPersonsReasonSameFirstName => 'Same first name';

  @override
  String get linkPersonsReasonSameLastName => 'Same last name';

  @override
  String get linkPersonsReasonSimilarBirthday => 'Similar birthday';

  @override
  String get linkPersonsReasonSimilarName => 'Similar name';

  @override
  String get linkPersonsReasonSwapped => 'First/last name swapped';

  @override
  String get linkPersonsSelectOne => 'Please select at least one match';

  @override
  String get linkPersonsTitle => 'Link people';

  @override
  String get loginEmail => 'Email';

  @override
  String get loginEmailPlaceholder => 'Enter email...';

  @override
  String get loginFailedHeader => 'Sign-in failed';

  @override
  String get loginFailedMessage => 'Email or password is incorrect. If you have not set a password, you can sign in with a code by email instead.';

  @override
  String get loginFlutterAccessDenied => 'Access was denied.';

  @override
  String get loginFlutterBackToLogin => 'Back to login';

  @override
  String get loginFlutterCheckSpam => 'Please also check your spam folder.';

  @override
  String get loginFlutterConfirmEmail => 'Confirm email';

  @override
  String loginFlutterConfirmEmailSent(Object email) {
    return 'We sent an email to $email. Please click the link in it to activate your account.';
  }

  @override
  String get loginFlutterEnterPassword => 'Please enter your password';

  @override
  String get loginFlutterLinkFailed => 'The link could not be processed.';

  @override
  String get loginFlutterNewPassword => 'New password';

  @override
  String get loginFlutterOtherEmail => 'Use a different email';

  @override
  String get loginFlutterResetIntro => 'Enter your email address and we will send you a reset link.';

  @override
  String loginFlutterResetLinkSent(Object email) {
    return 'We sent a link to reset your password to $email.';
  }

  @override
  String get loginFlutterSendLink => 'Send link';

  @override
  String get loginFlutterToLogin => 'Go to login';

  @override
  String get loginFlutterUnexpectedError => 'An unexpected error occurred. Please try again.';

  @override
  String get loginForgotPassword => 'Forgot password?';

  @override
  String get loginInstallUpdate => 'Install update';

  @override
  String get loginLegal => 'Legal notice & privacy';

  @override
  String get loginLinkAndSignIn => 'Link & sign in';

  @override
  String get loginLinkNote => 'Link your Attendix account with Microsoft once. Sign in with your Attendix credentials – after that, Teams will sign you in automatically.';

  @override
  String get loginModeOtp => 'Code by email';

  @override
  String get loginModePassword => 'Password';

  @override
  String get loginNoAccountHeader => 'No account found';

  @override
  String get loginNoAccountMessage => 'There is no account for this email address yet. Do you want to sign up now?';

  @override
  String get loginNotConfirmedHeader => 'Email not confirmed';

  @override
  String get loginNotConfirmedMessage => 'Your email address has not been confirmed yet. Do you want to resend the confirmation email?';

  @override
  String get loginNotConfirmedResend => 'Resend';

  @override
  String get loginOtpLabel => 'Code from the email';

  @override
  String get loginPassword => 'Password';

  @override
  String get loginRegister => 'Sign up';

  @override
  String get loginResendCode => 'Resend code';

  @override
  String loginResendIn(Object seconds) {
    return 'Resend (${seconds}s)';
  }

  @override
  String get loginResetConfirm => 'Reset';

  @override
  String get loginResetHeader => 'Reset password';

  @override
  String get loginSendCode => 'Send code';

  @override
  String get loginShowPassword => 'Show password';

  @override
  String get loginSignIn => 'Sign in';

  @override
  String get loginStartDemo => 'Start demo';

  @override
  String get loginToastEnterEmail => 'Please enter your email address.';

  @override
  String get loginToastInvalidEmail => 'Please enter a valid email address.';

  @override
  String get loginToastMsLinked => 'Microsoft account linked. You will be signed in automatically from now on.';

  @override
  String get loginToastRegistered => 'Sign-up successful, please confirm your email address.';

  @override
  String loginVersion(Object version) {
    return 'Version $version';
  }

  @override
  String get messagesAllActive => 'All active members';

  @override
  String messagesAllCount(Object count) {
    return 'All $count';
  }

  @override
  String get messagesCountsFailed => 'The recipients could not be loaded.';

  @override
  String get messagesDeleteConfirm => 'Delete message?';

  @override
  String get messagesDeleteFailed => 'Could not delete';

  @override
  String get messagesDeleteHint => 'The message also disappears from the app for all recipients. Emails already sent remain.';

  @override
  String get messagesDeleteMessage => 'Delete message';

  @override
  String get messagesEarlier => 'Earlier messages';

  @override
  String get messagesEmail => 'Email';

  @override
  String get messagesEmailBounced => 'Email undeliverable';

  @override
  String messagesEmailCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count people have',
      one: '$count person has',
    );
    return '$_temp0 an email address';
  }

  @override
  String get messagesEmailDelivered => 'email delivered';

  @override
  String get messagesEmailDeliveredChip => 'Email delivered';

  @override
  String get messagesEmailFailed => 'Email failed';

  @override
  String messagesEmailOpened(Object time) {
    return 'Email opened $time';
  }

  @override
  String get messagesEmailOpenedApprox => 'email opened (approx.)';

  @override
  String get messagesEmailPending => 'Email pending';

  @override
  String get messagesEmailSent => 'Email sent';

  @override
  String get messagesFlutterHideMessage => 'Hide message';

  @override
  String messagesFlutterProblems(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count problems',
      one: '$count problem',
    );
    return '$_temp0';
  }

  @override
  String get messagesFlutterShowMessage => 'Show message';

  @override
  String messagesFrom(Object name, Object date) {
    return 'From $name · $date';
  }

  @override
  String get messagesInclMainGroup => 'incl. main group';

  @override
  String get messagesIsSending => 'Message is being sent';

  @override
  String get messagesListLoadFailed => 'Messages could not be loaded';

  @override
  String get messagesLoadFailed => 'Message could not be loaded';

  @override
  String get messagesMessage => 'Message';

  @override
  String get messagesMessages => 'Messages';

  @override
  String get messagesNewMessage => 'New message';

  @override
  String get messagesNoAccount => 'No app account';

  @override
  String get messagesNoAccountNoEmail => 'No app account, no email';

  @override
  String get messagesNoEmail => 'No email';

  @override
  String get messagesNoPeopleView => 'No people in this view.';

  @override
  String get messagesNone => 'No messages yet';

  @override
  String get messagesNoneHint => 'Inform your group with a message and see right away who has read it.';

  @override
  String get messagesNotAvailable => 'This message no longer exists or you have no access to it.';

  @override
  String get messagesOnlyGroups => 'Only certain groups';

  @override
  String messagesOpenCount(Object count) {
    return 'Open $count';
  }

  @override
  String get messagesOpenedEstimate => '\"Opened\" for emails is an estimate: some mail apps preload images, others block them.';

  @override
  String get messagesOverview => 'Overview';

  @override
  String messagesProblemsCount(Object count) {
    return 'Problems $count';
  }

  @override
  String get messagesPush => 'Push';

  @override
  String messagesPushCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count people have',
      one: '$count person has',
    );
    return '$_temp0 notifications enabled';
  }

  @override
  String get messagesPushDelivered => 'push/Telegram delivered';

  @override
  String get messagesPushFailed => 'Push failed';

  @override
  String get messagesPushOff => 'Push off';

  @override
  String get messagesPushTelegram => 'Push / Telegram';

  @override
  String messagesReadAt(Object time) {
    return '✓ Read $time';
  }

  @override
  String messagesReadCount(Object count) {
    return 'Read $count';
  }

  @override
  String get messagesReadInApp => 'read in the app';

  @override
  String messagesReadOf(Object read, Object total) {
    return '$read of $total read';
  }

  @override
  String get messagesRecipients => 'Recipients';

  @override
  String messagesRecipientsSummary(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count people',
      one: '$count person',
    );
    return '<strong>$_temp0</strong> will receive this message.';
  }

  @override
  String get messagesRetry => 'Try again';

  @override
  String get messagesSend => 'Send';

  @override
  String get messagesSendConfirm => 'Send message?';

  @override
  String messagesSendConfirmMessage(Object title, num count, Object channels) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count people',
      one: '$count person',
    );
    return '\"$title\" goes to $_temp0 ($channels). This cannot be undone.';
  }

  @override
  String get messagesSendFailed => 'Sending failed, please try again.';

  @override
  String get messagesSendVia => 'Send via';

  @override
  String get messagesSending => 'Sending …';

  @override
  String get messagesSendingNow => 'Sending …';

  @override
  String get messagesSent => 'Sent';

  @override
  String get messagesStillSending => 'Still sending. Pull down to refresh.';

  @override
  String get messagesTelegram => 'Telegram';

  @override
  String get messagesTitle => 'Title';

  @override
  String get messagesTitlePlaceholder => 'e.g. Saturday\'s rehearsal is cancelled';

  @override
  String messagesToPeople(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count people',
      one: '$count person',
    );
    return 'to $_temp0';
  }

  @override
  String get messagesUnreachable => 'Unreachable';

  @override
  String messagesUnreachableSummary(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count people can\'t be reached on any channel and only see',
      one: '$count person can\'t be reached on any channel and only sees',
    );
    return '$_temp0 the message when they open the app.';
  }

  @override
  String get messagesUnread => 'Unread';

  @override
  String messagesViaEmail(Object count) {
    return '$count by email';
  }

  @override
  String messagesViaPush(Object count) {
    return '$count via push/Telegram';
  }

  @override
  String get messagesWriteFirst => 'Write first message';

  @override
  String get notifAnnouncements => 'Announcements';

  @override
  String get notifAnnouncementsHelper => 'Messages from admins and responsibles of your instance';

  @override
  String get notifAppUpdates => 'App updates';

  @override
  String get notifAppUpdatesHelper => 'Get notified about app updates as soon as they are available';

  @override
  String get notifBirthdays => 'Birthdays';

  @override
  String get notifBirthdaysHelper => 'Get a notification every day at 8:00 if someone has a birthday today';

  @override
  String get notifBothChannels => 'Both channels at once';

  @override
  String get notifBothChannelsHelper => 'Push and Telegram are sent in parallel, not just as a fallback.';

  @override
  String get notifChecklist => 'Checklist reminders';

  @override
  String get notifChecklistHelper => 'Get reminders for due to-dos in your checklist. Only possible if you are responsible for a group.';

  @override
  String get notifConnect => 'Connect';

  @override
  String get notifDisconnect => 'Disconnect';

  @override
  String get notifDisconnectConfirm => 'Do you really want to disconnect?';

  @override
  String get notifDisconnectHint => 'The connection can be restored at any time';

  @override
  String get notifDuties => 'Duties';

  @override
  String get notifDutiesHelper => 'When you are assigned to a duty, reminded to confirm, or someone is needed to step in. Urgent requests still come through.';

  @override
  String get notifEnable => 'Enable notifications';

  @override
  String get notifEventReminders => 'Event reminders';

  @override
  String get notifFlutterConfigNotFound => 'Configuration not found';

  @override
  String notifFlutterLoadFailed(Object error) {
    return 'Error while loading: $error';
  }

  @override
  String get notifFlutterTelegramOpenFailed => 'Could not open Telegram';

  @override
  String get notifFlutterUpdateFailed => 'Error updating the configuration';

  @override
  String get notifFlutterUserIdCopied => 'User ID copied';

  @override
  String get notifLinked => 'Account linked';

  @override
  String get notifLiveActivity => 'Running run sheet';

  @override
  String get notifLiveActivityHelper => 'Shows the current item of a running run sheet on the lock screen.';

  @override
  String get notifLiveActivityHelperIos => 'Shows the current item of a running run sheet on the lock screen and in the Dynamic Island.';

  @override
  String get notifNewProblemCases => 'New problem cases';

  @override
  String get notifNewRegistrations => 'New registrations';

  @override
  String get notifPush => 'Push notifications';

  @override
  String get notifPushPreferred => 'Push is preferred. Telegram is only used as a fallback if push cannot be delivered.';

  @override
  String get notifResponsibleOnly => 'Only possible if you are responsible for a group.';

  @override
  String get notifSignIns => 'Sign-ups';

  @override
  String get notifSignOuts => 'Sign-outs';

  @override
  String get notifTasks => 'Task reminders';

  @override
  String get notifTasksHelper => 'Get reminders 2 days before tasks you are responsible for are due.';

  @override
  String get notifTelegram => 'Telegram link';

  @override
  String get notifTenantSettings => 'Instance settings';

  @override
  String get notifTitle => 'Notifications';

  @override
  String get notifUserId => 'User ID';

  @override
  String get openFileLinkFailed => 'The link could not be opened.';

  @override
  String get openFileNoTenantAccess => 'You have no access to this instance.';

  @override
  String get orgAppearancePlans => 'Appearance & plans';

  @override
  String get orgChoose => 'Select';

  @override
  String get orgCreate => 'Create organisation';

  @override
  String get orgCreateNew => 'Create new organisation';

  @override
  String get orgCreateOrLink => 'Create / link organisation';

  @override
  String get orgCreated => 'The organisation was created.';

  @override
  String get orgDisable => 'Disable';

  @override
  String get orgDisableSync => 'Disable sync?';

  @override
  String get orgDisableSyncMessage => 'The pieces of this instance will then be empty until own pieces are created. History entries pointing to pieces of the source instance can no longer be resolved.';

  @override
  String get orgFieldsAddOption => 'Please add at least one option.';

  @override
  String get orgFieldsApplyChanges => 'Apply changes';

  @override
  String get orgFieldsFlutterFirstOptionDefault => 'The first option is the default value';

  @override
  String get orgFieldsIntro => 'These fields and their values are shared for the same person across all instances of the organisation.';

  @override
  String get orgFieldsInvalid => 'Invalid organisation fields.';

  @override
  String get orgFieldsNameExists => 'A field with this name already exists.';

  @override
  String orgFieldsNeedsOptions(Object name) {
    return 'The selection field “$name” needs options.';
  }

  @override
  String get orgFieldsNone => 'No organisation-wide fields have been added yet.';

  @override
  String get orgFieldsSaved => 'Organisation fields saved.';

  @override
  String get orgFieldsTitle => 'Person fields';

  @override
  String orgFlutterFieldCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fields',
      one: '$count field',
    );
    return '$_temp0';
  }

  @override
  String get orgFlutterNoFields => 'No fields';

  @override
  String get orgFlutterUnlinkFailed => 'Error while unlinking';

  @override
  String get orgHandover => 'Handover';

  @override
  String get orgLinkPersonsHint => 'Connect people from different instances';

  @override
  String get orgNamePh => 'Enter name...';

  @override
  String get orgNoneAdminOnly => 'This instance is not assigned to an organisation. Only administrators can manage organisations.';

  @override
  String get orgNoneIntro => 'Create a new organisation or link this instance to an existing one to connect people across the organisation and share plans.';

  @override
  String get orgNoneLinked => 'No organisation linked';

  @override
  String get orgNoneOwnSongs => 'None (own pieces)';

  @override
  String get orgOrgPlans => 'Org plans';

  @override
  String get orgPersonFields => 'Person fields';

  @override
  String get orgPersonFieldsHint => 'Manage fields and values for linked people together';

  @override
  String get orgPersons => 'People';

  @override
  String get orgPleaseSelect => 'Please select an organisation.';

  @override
  String get orgRename => 'Rename organisation';

  @override
  String get orgRenamed => 'Organisation renamed';

  @override
  String get orgSelect => 'Select organisation';

  @override
  String get orgSelected => 'The organisation was selected.';

  @override
  String get orgSongSync => 'Piece sync';

  @override
  String get orgSongSyncIntro => 'Use the pieces of another instance. All changes are saved there.';

  @override
  String get orgSourceTenant => 'Source instance';

  @override
  String get orgSyncSaved => 'Piece sync saved.';

  @override
  String get orgTapRename => 'Tap to rename';

  @override
  String get orgTemplatesAddTemplate => 'Add template';

  @override
  String get orgTemplatesDefaultFields => 'Default fields';

  @override
  String get orgTemplatesDefaultFieldsHint => 'Default fields appear in the planning menu as quick-add fields for all instances of the organisation.';

  @override
  String orgTemplatesDuration(Object h, Object m) {
    return '$h h $m min';
  }

  @override
  String orgTemplatesDurationH(Object h) {
    return '$h h';
  }

  @override
  String orgTemplatesEndApprox(Object time) {
    return 'Ends approx. $time';
  }

  @override
  String get orgTemplatesEnterFieldName => 'Please enter a field name.';

  @override
  String get orgTemplatesEnterName => 'Please enter a name.';

  @override
  String get orgTemplatesFieldName => 'Field name';

  @override
  String get orgTemplatesFieldNamePh => 'Field name...';

  @override
  String get orgTemplatesMinutes => 'Minutes';

  @override
  String get orgTemplatesNoDefaultFields => 'No default fields yet';

  @override
  String get orgTemplatesNoTemplates => 'No templates yet';

  @override
  String get orgTemplatesPerformerOptPh => 'Performer (optional)...';

  @override
  String get orgTemplatesRenameTemplate => 'Rename template';

  @override
  String get orgTemplatesSongPlaceholder => 'Piece placeholder';

  @override
  String get orgTemplatesTemplateNamePh => 'Template name...';

  @override
  String get orgTemplatesTemplates => 'Templates';

  @override
  String get orgTemplatesTemplatesHint => 'Templates can be applied to the programme with one tap while planning; they replace the current run sheet.';

  @override
  String get orgTemplatesTitle => 'Plan templates & fields';

  @override
  String get orgTenants => 'Instances';

  @override
  String get orgThisTenant => 'This instance';

  @override
  String get orgTitle => 'Organisation';

  @override
  String get orgUnlink => 'Unlink organisation from instance?';

  @override
  String get orgUnlinkButton => 'Unlink';

  @override
  String orgUnlinkMessage(Object name) {
    return 'Do you really want to unlink the organisation “$name” from the instance?';
  }

  @override
  String get orgUnlinkTenant => 'Unlink instance';

  @override
  String get orgUnlinked => 'The organisation was unlinked from the instance.';

  @override
  String get orgValidName => 'Please enter a valid name.';

  @override
  String get peopleActivate => 'Activate';

  @override
  String get peopleActivating => 'Activating...';

  @override
  String get peopleActiveAgain => 'Person active again';

  @override
  String get peopleActivePeople => 'Active people';

  @override
  String peopleAgeShort(Object date, Object age) {
    return '$date ($age yrs)';
  }

  @override
  String peopleAgeYears(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count years',
      one: '$count year',
    );
    return '$_temp0';
  }

  @override
  String peopleAndMore(Object count) {
    return '… and $count more';
  }

  @override
  String get peopleArchive => 'Archive';

  @override
  String peopleArchiveTitle(Object name) {
    return 'Archive $name';
  }

  @override
  String get peopleAttendance => 'Attendance';

  @override
  String get peopleAttendanceAsc => 'Attendance ↑';

  @override
  String get peopleAttendanceDesc => 'Attendance ↓';

  @override
  String get peopleBirthday => 'Date of birth';

  @override
  String get peopleBirthdayAsc => 'Date of birth ↑';

  @override
  String get peopleBirthdayDesc => 'Date of birth ↓';

  @override
  String get peopleBirthdayToday => 'Birthday today';

  @override
  String peopleBirthdaysToday(Object count) {
    return '$count birthdays today';
  }

  @override
  String get peopleBulkEdit => 'Bulk edit';

  @override
  String get peopleBulkEditHint => 'Choose a field to edit its values for all people.';

  @override
  String get peopleCandidate => 'Candidate';

  @override
  String get peopleCandidates => 'Candidates';

  @override
  String get peopleCannotRemoveSelf => 'You can\'t remove yourself!';

  @override
  String get peopleCannotUndoExcl => 'This action cannot be undone!';

  @override
  String get peopleCheckingData => 'Checking data...';

  @override
  String get peopleChooseField => 'Choose field';

  @override
  String get peopleChooseFieldPlaceholder => 'Choose field...';

  @override
  String get peopleChooseFile => 'Choose file';

  @override
  String get peopleChooseGroupPlaceholder => 'Choose group...';

  @override
  String get peopleChooseInstance => 'Choose instance';

  @override
  String get peopleCreateAccounts => 'Create accounts';

  @override
  String get peopleCreateAccountsHint => 'User accounts are created for people with an email address and invitation emails are sent.';

  @override
  String get peopleCurrent => 'Current';

  @override
  String get peopleDemoUnavailable => 'This feature is not available in demo mode.';

  @override
  String get peopleDownloadTemplate => 'Download template';

  @override
  String peopleDuplicates(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count duplicates',
      one: '$count duplicate',
    );
    return '$_temp0';
  }

  @override
  String get peopleEmail => 'Email';

  @override
  String get peopleEnterValue => 'Enter value';

  @override
  String peopleErrorAt(Object tenant, Object error) {
    return 'Error at $tenant: $error';
  }

  @override
  String get peopleExtraFields => 'Additional fields';

  @override
  String peopleFailedCount(Object count) {
    return '$count failed.';
  }

  @override
  String peopleFaulty(Object count) {
    return '$count with errors';
  }

  @override
  String get peopleFileEmpty => 'The file contains no data.';

  @override
  String peopleFileRows(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rows',
      one: '$count row',
    );
    return '$_temp0';
  }

  @override
  String get peopleFileUnreadable => 'The file could not be read.';

  @override
  String get peopleFilter => 'Filter';

  @override
  String get peopleFiltersNoMatch => 'The active filters have no results.';

  @override
  String get peopleFirstName => 'First name';

  @override
  String get peopleFlutterAgeFrom => 'From';

  @override
  String get peopleFlutterAgeSuffix => 'y';

  @override
  String get peopleFlutterAgeTo => 'To';

  @override
  String get peopleFlutterAttention => 'Attention';

  @override
  String peopleFlutterBulkUpdated(Object count) {
    return '$count person(s) updated';
  }

  @override
  String get peopleFlutterContactCall => 'Call';

  @override
  String get peopleFlutterContactMail => 'Email';

  @override
  String get peopleFlutterContactMailHint => 'Write an email';

  @override
  String get peopleFlutterContactTelegramHint => 'Message on Telegram';

  @override
  String get peopleFlutterContactWhatsAppHint => 'Message on WhatsApp';

  @override
  String get peopleFlutterCreateAnyway => 'Create anyway';

  @override
  String get peopleFlutterDefaultView => 'Default';

  @override
  String get peopleFlutterDeselectAll => 'Clear selection';

  @override
  String peopleFlutterDuplicateMessage(Object name, Object count) {
    return 'A person named \"$name\" already exists (${count}x). Create anyway?';
  }

  @override
  String peopleFlutterErrorWith(Object error) {
    return 'Error: $error';
  }

  @override
  String get peopleFlutterFirstNameRequired => 'First name is required';

  @override
  String get peopleFlutterGroupsLoadFailed => 'Could not load the groups';

  @override
  String peopleFlutterHandoverCopied(Object count) {
    return '$count players copied successfully';
  }

  @override
  String get peopleFlutterHandoverCopy => 'Copy';

  @override
  String peopleFlutterHandoverCopyConfirm(Object count, Object tenant) {
    return 'Copy $count players to \"$tenant\"?';
  }

  @override
  String get peopleFlutterHandoverCopyNote => 'The selected players are copied to the target instance. They stay active in this instance. App access has to be linked again in the target instance.';

  @override
  String get peopleFlutterHandoverCopyQuestion => 'Copy players?';

  @override
  String get peopleFlutterHandoverCopyTitle => 'Copy players';

  @override
  String peopleFlutterHandoverCount(Object count, Object total) {
    return '$count of $total players';
  }

  @override
  String get peopleFlutterHandoverMappingHint => 'Map the groups of the source instance to the groups of the target instance:';

  @override
  String get peopleFlutterHandoverMode => 'Mode';

  @override
  String get peopleFlutterHandoverModeCopy => 'Players are copied (stay active here)';

  @override
  String get peopleFlutterHandoverModeTransfer => 'Players are transferred (archived here)';

  @override
  String get peopleFlutterHandoverNoMapping => '-- Do not map --';

  @override
  String get peopleFlutterHandoverNoPermission => 'No permission in the target instance';

  @override
  String get peopleFlutterHandoverNoTenants => 'No other instances available';

  @override
  String get peopleFlutterHandoverNoTenantsHint => 'You only have access to one instance. To transfer players you need access to at least two instances.';

  @override
  String peopleFlutterHandoverPartialCopied(Object success, Object duplicate, Object error) {
    return '$success copied, $duplicate already present, $error failed';
  }

  @override
  String peopleFlutterHandoverPartialTransferred(Object success, Object duplicate, Object error) {
    return '$success transferred, $duplicate already present, $error failed';
  }

  @override
  String get peopleFlutterHandoverPreparing => 'Preparing transfer...';

  @override
  String peopleFlutterHandoverProgress(Object name, Object current, Object total) {
    return 'Transferring $name ($current/$total)...';
  }

  @override
  String get peopleFlutterHandoverTargetNotFound => 'Target instance not found';

  @override
  String peopleFlutterHandoverTransferConfirm(Object count, Object tenant) {
    return 'Transfer $count players to \"$tenant\"? The players will be archived in this instance. This cannot be undone.';
  }

  @override
  String get peopleFlutterHandoverTransferNote => 'The selected players are transferred to the target instance. They are archived in this instance and app access is removed. This cannot be undone.';

  @override
  String get peopleFlutterHandoverTransferQuestion => 'Transfer players?';

  @override
  String get peopleFlutterHandoverTransferTitle => 'Transfer players';

  @override
  String peopleFlutterHandoverTransferred(Object count) {
    return '$count players transferred successfully';
  }

  @override
  String get peopleFlutterHandoverTransferring => 'Transferring...';

  @override
  String get peopleFlutterHint => 'Note';

  @override
  String get peopleFlutterLastNameRequired => 'Last name is required';

  @override
  String get peopleFlutterListLoadFailed => 'The list of people could not be loaded.';

  @override
  String get peopleFlutterLoadFailed => 'Loading failed';

  @override
  String get peopleFlutterNotesHint => 'Additional information...';

  @override
  String peopleFlutterOptional(Object label) {
    return '$label (optional)';
  }

  @override
  String peopleFlutterPausedToast(Object name) {
    return '$name was paused';
  }

  @override
  String get peopleFlutterPossibleDuplicate => 'Possible duplicate';

  @override
  String get peopleFlutterSaveOrder => 'Save order';

  @override
  String peopleFlutterSelectedCount(Object count) {
    return '$count selected';
  }

  @override
  String peopleFlutterTransferCount(Object count) {
    return 'Transfer $count';
  }

  @override
  String get peopleFlutterTransferPeople => 'Transfer people';

  @override
  String get peopleFromToday => 'From today';

  @override
  String get peopleFullName => 'Name (first and last)';

  @override
  String get peopleGroup => 'Group';

  @override
  String get peopleGroupPlaceholder => 'Group...';

  @override
  String get peopleIgnore => 'Ignore';

  @override
  String peopleImportCount(Object count) {
    return 'Import $count';
  }

  @override
  String get peopleImportIntro => 'Import people from an Excel (.xlsx/.xls) or CSV file. The first row must contain column headers. The easiest way is to download the template and fill it in.';

  @override
  String get peopleImportPeople => 'Import people';

  @override
  String peopleImportProgress(Object done, Object total) {
    return '$done / $total imported...';
  }

  @override
  String peopleImportedCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count people imported.',
      one: '$count person imported.',
    );
    return '$_temp0';
  }

  @override
  String get peopleInstruments => 'Instruments';

  @override
  String get peopleJoinAsc => 'Joining date ↑';

  @override
  String get peopleJoinDesc => 'Joining date ↓';

  @override
  String get peopleJoined => 'Joined';

  @override
  String get peopleLastName => 'Last name';

  @override
  String get peopleLeaveDate => 'Leaving date';

  @override
  String get peopleMapNames => 'Please map columns for first and last name.';

  @override
  String get peopleMappingIntro => 'Map the columns of your file to the person fields. First and last name (or a combined name column) are required.';

  @override
  String get peopleMappingMissing => 'Please map columns for first and last name (or a combined name column).';

  @override
  String get peopleMembers => 'Members';

  @override
  String get peopleMembersLoadFailed => 'Could not load members.';

  @override
  String get peopleNew => 'New';

  @override
  String get peopleNewPlayers => 'New players';

  @override
  String get peopleNextBirthday => 'Next birthday';

  @override
  String get peopleNoChanges => 'No changes';

  @override
  String get peopleNoEndDate => 'No end date chosen';

  @override
  String get peopleNoGroupAssigned => 'Without group';

  @override
  String get peopleNoMembersFound => 'No members found.';

  @override
  String get peopleNoPeopleFound => 'No people found';

  @override
  String get peopleNoPeopleYet => 'No people have been added yet';

  @override
  String get peopleNoResult => 'No result';

  @override
  String get peopleNoTeacher => 'No teacher';

  @override
  String get peopleNotImported => 'People not imported';

  @override
  String get peopleNote => 'Note';

  @override
  String get peopleNotePlaceholder => 'Note...';

  @override
  String get peopleNotes => 'Notes';

  @override
  String get peopleNothingToImport => 'No people to import.';

  @override
  String get peopleOrderSaveFailed => 'Could not save the order';

  @override
  String get peopleOrderSaved => 'Order saved';

  @override
  String get peopleOtherDuties => 'Other duties';

  @override
  String get peopleOtherInstanceMember => 'Member of another instance';

  @override
  String get peoplePassportPhoto => 'Photo';

  @override
  String get peoplePause => 'Pause';

  @override
  String get peoplePauseHint => 'With a start date in the past, the person is also removed from past attendances from that date on. If an end date is given, the person is reactivated automatically.';

  @override
  String get peoplePauseOthers => 'Pause in other instances too?';

  @override
  String peoplePauseOthersMessage(Object name) {
    return '$name is also active in other instances. In which should they be paused too?';
  }

  @override
  String peoplePauseTitle(Object name) {
    return 'Pause $name';
  }

  @override
  String get peoplePaused => 'Paused';

  @override
  String get peoplePausedFrom => 'Paused from (optional)';

  @override
  String get peoplePausing => 'Pausing...';

  @override
  String peoplePeopleCount(Object count) {
    return 'People ($count)';
  }

  @override
  String get peoplePhone => 'Phone';

  @override
  String get peoplePhonePlaceholder => 'Phone...';

  @override
  String get peoplePreviewFailed => 'Preview failed.';

  @override
  String get peopleProblemCase => 'Problem case';

  @override
  String get peopleProblemCases => 'Problem cases';

  @override
  String get peopleReactivateConfirm => 'Reactivate this person?';

  @override
  String get peopleReadingFile => 'Reading file...';

  @override
  String peopleReady(Object count) {
    return '$count ready';
  }

  @override
  String get peopleReasonPlaceholder => 'Please give a reason...';

  @override
  String get peopleReasonRequired => 'Reason *';

  @override
  String get peopleRemoveConfirm => 'Really remove this person?';

  @override
  String get peopleRemoved => 'Person removed.';

  @override
  String get peopleRemoving => 'Removing person...';

  @override
  String get peopleReorder => 'Change order';

  @override
  String get peopleResetFilter => 'Reset filters';

  @override
  String peopleSaveChanges(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Save $count changes',
      one: 'Save $count change',
    );
    return '$_temp0';
  }

  @override
  String get peopleSaveFailed => 'Could not save';

  @override
  String get peopleSaving => 'Saving...';

  @override
  String get peopleSavingOrder => 'Saving order...';

  @override
  String get peopleSearchPerson => 'Search person...';

  @override
  String get peopleSetForAll => 'Set for all';

  @override
  String get peopleShowAll => 'Show all';

  @override
  String get peopleSkip => 'Skip';

  @override
  String get peopleStandardFields => 'Standard fields';

  @override
  String get peopleTeacher => 'Teacher';

  @override
  String peopleTeacherName(Object name) {
    return 'Teacher: $name';
  }

  @override
  String get peopleTestResult => 'Test result';

  @override
  String get peopleTestResultMissing => 'Test result missing';

  @override
  String peopleUnresolvedGroups(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count people could not be assigned to a group.',
      one: '$count person could not be assigned to a group.',
    );
    return '$_temp0 Please check and adjust the group below. For now the main group is set.';
  }

  @override
  String get peopleVoiceLeader => 'Section leader';

  @override
  String peopleWithHint(Object count) {
    return '$count with notice';
  }

  @override
  String get peopleWithoutAccount => 'Without account';

  @override
  String get peopleWithoutTeacher => 'Without teacher';

  @override
  String get personAbsences => 'Absences';

  @override
  String personAbsencesCount(Object count) {
    return 'Absences ($count)';
  }

  @override
  String get personAccount => 'Account';

  @override
  String get personAccountBadge => 'Account';

  @override
  String get personAccountCreated => 'Account created';

  @override
  String get personAccountHelp => 'Once the email address has been entered, an account can be created. The user is notified by email. The password is generated automatically and sent to the email address.';

  @override
  String get personActions => 'Actions';

  @override
  String personActiveSince(Object date) {
    return 'Active again since $date';
  }

  @override
  String get personAddAbsence => 'Add absence';

  @override
  String personAddFailed(Object error) {
    return 'Could not add the person: $error';
  }

  @override
  String get personAdded => 'The person was added';

  @override
  String get personApprovePerson => 'Approve person';

  @override
  String get personApproving => 'Approving person...';

  @override
  String get personArchived => 'The person was archived';

  @override
  String personArchivedAt(Object date) {
    return 'Archived on $date';
  }

  @override
  String get personAssignMyUser => 'Assign my user';

  @override
  String get personAverage => 'Average';

  @override
  String personAverageLate(Object count) {
    return 'Average (${count}x late)';
  }

  @override
  String get personChooseEntry => 'Choose entry';

  @override
  String get personCloseSuggestions => 'Close suggestions';

  @override
  String get personCopied => 'The person was copied';

  @override
  String personCopiedAt(Object date) {
    return 'Copied on $date';
  }

  @override
  String get personCopyConfirm => 'Do you really want to copy this person to the other instance?';

  @override
  String personCopyFrom(Object name) {
    return 'Copy $name';
  }

  @override
  String get personCopyNotPossible => 'Copy not possible';

  @override
  String get personCopyOther => 'Copy to another instance';

  @override
  String get personCopyPerson => 'Copy person';

  @override
  String get personCreateAccountNow => 'Do you want to create an account for this person right away?';

  @override
  String get personDataTaken => 'The data was taken over';

  @override
  String get personDatePlaceholder => 'DD.MM.YYYY';

  @override
  String get personDecline => 'Decline';

  @override
  String get personDeclinePerson => 'Decline person';

  @override
  String get personDeclining => 'Declining person...';

  @override
  String get personDeleteAbsenceMessage => 'Delete this absence? Events already excused in this period are reset to \"Neutral\".';

  @override
  String get personDiscardChanges => 'Discard changes?';

  @override
  String get personDiscardChangesMessage => 'Do you really want to discard the unsaved changes?';

  @override
  String get personDone => 'Done';

  @override
  String get personEditName => 'Edit name';

  @override
  String get personEditPerson => 'Edit person';

  @override
  String get personEmailAdded => 'Email address added';

  @override
  String get personEmailTaken => 'Email already in use';

  @override
  String get personEmailUpdated => 'The email address was updated';

  @override
  String personEmailUsedBy(Object name) {
    return 'This email is used by $name in another instance. Take over the data?';
  }

  @override
  String get personEmailUsedMany => 'This email is already used in other instances. Whose data should be taken over?';

  @override
  String get personEnableVoiceLeader => 'Enable section leader';

  @override
  String get personEnterAbsence => 'Enter absence';

  @override
  String get personEnterNames => 'Please enter first and last name.';

  @override
  String get personEntryRemoveFailed => 'Could not delete the entry.';

  @override
  String get personEntryRemoved => 'Entry removed.';

  @override
  String get personExistingUserHint => 'If a user already exists for this email address, they are automatically added to the instance.';

  @override
  String personExistsWithEmail(Object tenant, Object email) {
    return 'A person with the email address \"$email\" already exists in the instance \"$tenant\".';
  }

  @override
  String personExistsWithName(Object tenant, Object name) {
    return 'A person named \"$name\" already exists in the instance \"$tenant\".';
  }

  @override
  String get personFlutterAbsenceDeleteFailed => 'Absence could not be deleted';

  @override
  String get personFlutterAbsenceSaveFailed => 'Absence could not be saved';

  @override
  String get personFlutterAccountCreatedMail => 'Account created. Password email sent.';

  @override
  String get personFlutterAllEntries => 'All entries';

  @override
  String get personFlutterApprove => 'Approve';

  @override
  String personFlutterApproveMessage(Object name) {
    return 'Approve $name as a member?';
  }

  @override
  String get personFlutterApproveQuestion => 'Approve person?';

  @override
  String get personFlutterApproved => 'Person approved';

  @override
  String get personFlutterArchiveReasonHint => 'Why is the person leaving?';

  @override
  String personFlutterAttendanceLate(Object count) {
    return 'Attendance (${count}x late)';
  }

  @override
  String personFlutterChooseLabel(Object label) {
    return 'Choose $label';
  }

  @override
  String get personFlutterChooseRange => 'Choose period';

  @override
  String get personFlutterCreateAccount => 'Create account';

  @override
  String personFlutterCreateAccountFailed(Object name, Object error) {
    return '$name - error creating the account: $error';
  }

  @override
  String personFlutterCreateAccountMessage(Object name, Object email) {
    return 'An account with the email $email will be created for $name. The person receives an email to set the password.';
  }

  @override
  String get personFlutterCreateAccountQuestion => 'Create account?';

  @override
  String get personFlutterCritical => 'Critical';

  @override
  String personFlutterDeclineMessage(Object name) {
    return '$name will be declined and archived.';
  }

  @override
  String get personFlutterDeclineReasonHint => 'Why is the person declined?';

  @override
  String get personFlutterDeclined => 'Person declined';

  @override
  String get personFlutterEmailRequiredForAccount => 'An email address is required to create an account.';

  @override
  String get personFlutterFrequentLate => 'Frequent late arrivals';

  @override
  String personFlutterFromSeasonStart(Object date) {
    return 'Since season start ($date)';
  }

  @override
  String get personFlutterInstrumentsHint => 'e.g. piano, guitar';

  @override
  String personFlutterLateCount(Object count, Object threshold) {
    return '$count× late (threshold: $threshold)';
  }

  @override
  String personFlutterLateUnexcusedCount(Object count, Object threshold) {
    return '$count× late without excuse (threshold: $threshold)';
  }

  @override
  String get personFlutterLinked => 'Linked';

  @override
  String get personFlutterMatchFound => 'Person found in another instance?';

  @override
  String get personFlutterMore => 'More';

  @override
  String get personFlutterNoAccountLinked => 'No account linked. A conductor can create an account.';

  @override
  String get personFlutterNoEmail => 'No email address';

  @override
  String get personFlutterNoHistory => 'No history';

  @override
  String get personFlutterNoNote => 'No note';

  @override
  String get personFlutterNoNotes => 'No notes';

  @override
  String get personFlutterNoPermissionArchive => 'No permission to archive';

  @override
  String get personFlutterNoPermissionCreateAccount => 'No permission to create accounts';

  @override
  String get personFlutterNoPermissionEdit => 'No permission to edit';

  @override
  String get personFlutterNoPermissionPause => 'No permission to pause';

  @override
  String get personFlutterNoPermissionReactivate => 'No permission to reactivate';

  @override
  String get personFlutterNoPermissionRoles => 'No permission to change roles';

  @override
  String get personFlutterNoPermissionUnlink => 'No permission to unlink accounts';

  @override
  String get personFlutterNoShiftPlan => 'No shift plan';

  @override
  String personFlutterNoneLabel(Object label) {
    return 'No $label';
  }

  @override
  String personFlutterNoneLabelMasc(Object label) {
    return 'No $label';
  }

  @override
  String get personFlutterNotAssigned => 'Not assigned';

  @override
  String get personFlutterNotFound => 'Person not found';

  @override
  String get personFlutterNotSelected => 'Not selected';

  @override
  String get personFlutterNotSpecified => 'Not specified';

  @override
  String get personFlutterNotesHint => 'Notes about the person...';

  @override
  String get personFlutterOtherDutiesHint => 'Other duties...';

  @override
  String personFlutterOtherInstancesCount(Object count) {
    return 'Other instances ($count)';
  }

  @override
  String personFlutterPausedUntil(Object date) {
    return 'Paused until $date';
  }

  @override
  String get personFlutterPending => 'Pending';

  @override
  String get personFlutterProblemSolved => 'Problem case resolved';

  @override
  String get personFlutterRangeHint => 'e.g. C3 - C5';

  @override
  String get personFlutterRemarksHint => 'What was discussed?';

  @override
  String get personFlutterRequired => 'Required';

  @override
  String get personFlutterRoleAdmin => 'Conductor (admin)';

  @override
  String get personFlutterRoleNone => 'No role';

  @override
  String personFlutterRoleUpdateFailed(Object error) {
    return 'Role could not be updated: $error';
  }

  @override
  String get personFlutterSaveOnly => 'Save only';

  @override
  String get personFlutterSearchOtherInstance => 'Search in other instance';

  @override
  String get personFlutterSeasonOnly => 'Season only';

  @override
  String get personFlutterShowAll => 'Show all';

  @override
  String get personFlutterTalkedToHint => 'Confirm that the problem was discussed';

  @override
  String get personFlutterTestResultHint => 'Enter result...';

  @override
  String get personFlutterUnlink => 'Unlink';

  @override
  String get personFlutterUnlinkAccount => 'Unlink account';

  @override
  String personFlutterUnlinkMessage(Object name) {
    return 'The account link for $name will be removed. The person can then no longer sign in to the app.';
  }

  @override
  String get personFlutterUnlinkQuestion => 'Unlink account?';

  @override
  String get personFlutterUnlinked => 'Account unlinked';

  @override
  String personFlutterUploadFailedWith(Object error) {
    return 'Upload failed: $error';
  }

  @override
  String get personFlutterUploadingPhoto => 'Uploading photo...';

  @override
  String get personFromRequired => 'From *';

  @override
  String get personGiveReasonShort => 'Give a reason.';

  @override
  String get personHelp => 'Help';

  @override
  String get personHistory => 'History';

  @override
  String get personInvalidEmail => 'Please enter a valid email address...';

  @override
  String get personJoinedOn => 'Joined on';

  @override
  String get personLateCounterReset => 'Late counter reset';

  @override
  String personLateExcusedExtra(Object count) {
    return 'Additionally late ${count}x with excuse.';
  }

  @override
  String personLateWarning(Object count) {
    return 'This person was late <strong>${count}x</strong> without excuse.';
  }

  @override
  String get personLateWarningTitle => '🕐 Frequent late arrivals';

  @override
  String get personLongAbsenceHint => 'For longer absences, use the pause function so the person does not appear in new events.';

  @override
  String get personMerge => 'Merge';

  @override
  String get personMergeFailed => 'Could not merge the people';

  @override
  String personMergeMessage(Object name, Object candidate) {
    return '$name will be merged with the existing person $candidate. Their attendance data is kept and the newly registered account is assigned to $candidate. This cannot be undone.';
  }

  @override
  String get personMergePeople => 'Merge people';

  @override
  String get personMerged => 'The people were merged';

  @override
  String get personMerging => 'Merging people...';

  @override
  String get personNoAbsences => 'No absences entered';

  @override
  String get personNoChurchFound => 'No church found.';

  @override
  String get personNoComment => 'No comment';

  @override
  String get personNoDateChosen => 'No date chosen';

  @override
  String get personNoMatchOther => 'No matching person was found in another instance';

  @override
  String get personNoShift => 'No shift assigned';

  @override
  String get personNotAvailable => 'Not available';

  @override
  String get personNotListed => 'Not listed';

  @override
  String get personNotSet => 'Not set';

  @override
  String get personNoteChanged => 'Note changed';

  @override
  String personNoteChangedAt(Object date) {
    return 'Note changed on $date';
  }

  @override
  String personOldNote(Object note) {
    return 'Old note: $note';
  }

  @override
  String get personOtherInstances => 'Other instances';

  @override
  String get personOtherOrchestras => 'Other orchestras';

  @override
  String get personParents => 'Parents';

  @override
  String get personPauseHintAuto => 'With a start date in the past, the person is also removed from past attendances from that date on. If an end date is given, the person is reactivated automatically afterwards.';

  @override
  String get personPauseReasonPlaceholder => 'Give a reason for the pause...';

  @override
  String personPauseTitle(Object name) {
    return 'Pause $name';
  }

  @override
  String personPausedAt(Object date) {
    return 'Paused on $date';
  }

  @override
  String get personPhoneNumber => 'Phone/mobile number';

  @override
  String get personPhotoChangeFailed => 'Could not change the photo, please try again later';

  @override
  String get personPhotoLoadFailed => 'Could not load the photo';

  @override
  String get personPhotoRemoved => 'The photo was removed';

  @override
  String get personPhotoTooLarge => 'The picture can be at most 2 MB.';

  @override
  String get personPlaysSince => 'Plays the instrument since';

  @override
  String get personPlaysWithTeacher => 'Plays with teacher';

  @override
  String get personPleaseChoose => 'Please choose';

  @override
  String get personReactivate => 'Reactivate';

  @override
  String get personReactivateConfirm => 'Do you really want to reactivate this person?';

  @override
  String get personReactivatePerson => 'Reactivate person';

  @override
  String get personReactivated => 'The person was reactivated';

  @override
  String personReactivatedAt(Object date) {
    return 'Reactivated on $date';
  }

  @override
  String get personRemarks => 'Remarks';

  @override
  String get personRemoveAccount => 'Remove account';

  @override
  String get personRemoveAccountMessage => 'Do you really want to remove the account from this instance? The person\'s data is kept.';

  @override
  String get personRemoveEntry => 'Remove entry permanently?';

  @override
  String get personRemovePersonMessage => 'Do you really want to remove this person? All related data (absences, notes, etc.) will be lost!';

  @override
  String get personRemovePhoto => 'Remove photo';

  @override
  String get personRemovePhotoMessage => 'Do you really want to remove the photo?';

  @override
  String get personRemoved => 'The person was removed';

  @override
  String get personReplace => 'Replace';

  @override
  String get personResetFailed => 'Reset failed';

  @override
  String get personResetTalked => 'Reset (talk held)';

  @override
  String get personResetting => 'Resetting...';

  @override
  String get personRole => 'Role';

  @override
  String get personRoleUpdated => 'The role was updated.';

  @override
  String get personSaveWithRole => 'Save with role';

  @override
  String get personSearchChurch => 'Search church';

  @override
  String get personShift => 'Shift';

  @override
  String get personShiftPlan => 'Shift plan';

  @override
  String get personSimilarExists => 'Similar person already exists';

  @override
  String get personStartDate => 'Start date';

  @override
  String get personTalkedTo => 'Talked to person';

  @override
  String personTalkedToAt(Object date) {
    return 'Talked to person ($date)';
  }

  @override
  String get personTargetGroup => 'Target group';

  @override
  String get personTargetInstance => 'Target instance';

  @override
  String get personTransferConfirm => 'Do you really want to transfer this person to the other instance? All related data (absences, notes, etc.) will be lost!';

  @override
  String personTransferFrom(Object name) {
    return 'Transfer $name';
  }

  @override
  String get personTransferNotPossible => 'Transfer not possible';

  @override
  String get personTransferOther => 'Transfer to another instance';

  @override
  String get personTransferPerson => 'Transfer person';

  @override
  String get personTransferred => 'The person was transferred';

  @override
  String personTransferredAt(Object date) {
    return 'Transferred on $date';
  }

  @override
  String get personUntilRequired => 'Until *';

  @override
  String personUpcomingEvents(Object count) {
    return 'Upcoming events ($count)';
  }

  @override
  String get personUpdateFailed => 'Could not update the person';

  @override
  String personUpdateFailedWith(Object error) {
    return 'Could not update the person: $error';
  }

  @override
  String get personUpdated => 'The person\'s data was updated.';

  @override
  String get personUserAssigned => 'User assigned';

  @override
  String get personUserRemoveFailed => 'Could not remove the user';

  @override
  String get personUserRemoved => 'The user was removed';

  @override
  String get personVocalRange => 'Vocal range';

  @override
  String personVoiceLeaderMessage(Object name) {
    return 'With the section leader role, $name can see the contact details and upcoming events of everyone in the section. Assign the role?';
  }

  @override
  String get personVoiceLeaderStatusOnly => 'Section leader status only';

  @override
  String get planningAddAnotherPlan => 'Add another run sheet';

  @override
  String get planningAddAnotherPlanMessage => 'Should the new plan copy the current run sheet or start empty?';

  @override
  String get planningAddBlock => 'Add program block';

  @override
  String get planningAddCurrentSongs => 'Add current pieces';

  @override
  String get planningAddField => 'Add field';

  @override
  String get planningAddNoteField => 'Add note field';

  @override
  String get planningAddSong => 'Add piece';

  @override
  String get planningAddSubItem => 'Add sub-item';

  @override
  String get planningAgenda => 'Agenda';

  @override
  String get planningAgendaExists => 'An agenda placeholder already exists';

  @override
  String get planningAgendaInsertPos => 'Agenda insert position';

  @override
  String planningAllPlans(Object count) {
    return 'All $count plans';
  }

  @override
  String get planningAlto => 'Alto';

  @override
  String planningAsOf(Object date) {
    return 'As of: $date';
  }

  @override
  String get planningAssignDay => 'Assign day';

  @override
  String get planningAssignOtherDay => 'Assign to another day';

  @override
  String get planningAttendanceNotes => 'Attendance notes';

  @override
  String get planningBass => 'Bass';

  @override
  String get planningBlockDurationHint => 'The duration is the sum of the sub-items.';

  @override
  String planningBlockHasItems(Object name, num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sub-items',
      one: '$count sub-item',
    );
    return '\"$name\" has $_temp0.';
  }

  @override
  String get planningBlockNamePlaceholder => 'Name, e.g. youth choir program';

  @override
  String planningBlockSubHeader(num count, Object min) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sub-items',
      one: '$count sub-item',
    );
    return '$_temp0 · $min min';
  }

  @override
  String get planningBlocks => 'Program blocks';

  @override
  String get planningChooseEventFirst => 'Please choose an event first.';

  @override
  String get planningChooseFieldMin => 'Please choose at least one field.';

  @override
  String get planningChooseSong => 'Choose piece';

  @override
  String get planningCollapseBlock => 'Collapse block';

  @override
  String get planningConductors => 'Conductors';

  @override
  String get planningCopy => 'Copy';

  @override
  String get planningCreateRunSheetFirst => 'Create a run sheet for this plan first.';

  @override
  String get planningCreateSectionalPlan => 'Create sectional rehearsal plan';

  @override
  String get planningCurrent => 'Current';

  @override
  String get planningDefaultTitle => 'Use default title';

  @override
  String get planningDefaultWord => 'Word ';

  @override
  String get planningDeleteAll => 'Delete all';

  @override
  String get planningDeleteBlockConfirm => 'Delete block?';

  @override
  String get planningDeleteBlockWithItems => 'Delete block with sub-items';

  @override
  String get planningDeletePlan => 'Delete plan';

  @override
  String get planningDeletePlanConfirm => 'Delete plan?';

  @override
  String planningDeletePlanMessage(Object label) {
    return 'The plan \"$label\" will be deleted.';
  }

  @override
  String get planningDeleteTemplate => 'Delete template';

  @override
  String get planningDeleteTemplateConfirm => 'Delete template?';

  @override
  String planningDeleteTemplateMessage(Object name) {
    return 'The template \"$name\" will be deleted. Existing plans stay unchanged.';
  }

  @override
  String get planningDissolveBlock => 'Dissolve block';

  @override
  String get planningEditBlock => 'Edit block';

  @override
  String get planningEditField => 'Edit field';

  @override
  String get planningEditLink => 'Edit link';

  @override
  String get planningEmpty => 'Empty';

  @override
  String get planningEnterFreeText => 'Enter free text...';

  @override
  String get planningEnterItem => 'Enter item...';

  @override
  String get planningEnterItemPlease => 'Please enter an item.';

  @override
  String get planningEnterNamePlease => 'Please enter a name.';

  @override
  String get planningEnterNote => 'Enter note...';

  @override
  String get planningEnterPerformer => 'Enter performer...';

  @override
  String get planningExpandBlock => 'Expand block';

  @override
  String get planningExport => 'Export';

  @override
  String get planningExportPdf => 'Export PDF';

  @override
  String get planningExportPdfA5 => 'Export PDF (2x A5)';

  @override
  String get planningExportPdfAll => 'Export PDF (all plans)';

  @override
  String get planningFields => 'Fields';

  @override
  String get planningFillRequired => 'Please fill in all required fields.';

  @override
  String get planningFirstEvent => 'This is currently the first event';

  @override
  String planningFlutterBlockEntry(Object name, Object min) {
    return 'Programme block: $name ($min min)';
  }

  @override
  String get planningFlutterConflictDraftApply => 'Apply draft';

  @override
  String get planningFlutterConflictDraftDiscard => 'Discard';

  @override
  String get planningFlutterConflictDraftMessage => 'An older draft was not applied because of a conflict.';

  @override
  String get planningFlutterConflictDraftTitle => 'Draft not applied';

  @override
  String get planningFlutterDraftLost => 'Run sheet could not be saved – changes are lost';

  @override
  String get planningFlutterDraftRestored => 'Unsaved changes restored';

  @override
  String get planningFlutterDraftSavedLocally => 'Run sheet could not be saved – draft kept on this device';

  @override
  String planningFlutterErrorWith(Object error) {
    return 'Error: $error';
  }

  @override
  String planningFlutterExportFailed(Object error) {
    return 'Export failed: $error';
  }

  @override
  String planningFlutterFieldEntry(Object name, Object min) {
    return 'Field: $name ($min min)';
  }

  @override
  String get planningFlutterLive => 'Live';

  @override
  String get planningFlutterLiveMode => 'Live mode';

  @override
  String get planningFlutterLiveModeEnd => 'End live mode';

  @override
  String get planningFlutterNoEvents => 'No events available';

  @override
  String get planningFlutterNoItems => 'No programme items';

  @override
  String get planningFlutterPdf2xA5 => 'PDF (2x A5)';

  @override
  String get planningFlutterPdfA4 => 'PDF (A4)';

  @override
  String get planningFlutterPlanChanged => 'The plan was changed in the meantime';

  @override
  String get planningFlutterPlanChangedDraftLost => 'The plan was changed in the meantime – changes are lost';

  @override
  String get planningFlutterPlanChangedDraftSaved => 'The plan was changed in the meantime – changes kept as a draft';

  @override
  String get planningFlutterPlanDeleted => 'The plan was deleted in the meantime';

  @override
  String get planningFlutterPlanDeletedDraftLost => 'The plan was deleted in the meantime – changes are lost';

  @override
  String get planningFlutterPlanDeletedDraftSaved => 'The plan was deleted in the meantime – changes kept as a draft';

  @override
  String planningFlutterPlanPosition(Object index, Object total) {
    return '$index of $total';
  }

  @override
  String planningFlutterSaveFailedWith(Object error) {
    return 'Error while saving: $error';
  }

  @override
  String planningFlutterShareFailedWith(Object error) {
    return 'Error while sharing: $error';
  }

  @override
  String get planningFlutterTelegramNotConfigured => 'Telegram is not configured';

  @override
  String get planningFlutterTelegramPdf2x => 'Send via Telegram (PDF 2x A5)';

  @override
  String get planningFlutterUnshareAction => 'Stop sharing';

  @override
  String get planningGroupName => 'Group name';

  @override
  String get planningGroups => 'Groups';

  @override
  String get planningHeadingLabel => 'Run sheet heading';

  @override
  String get planningIncludeBranding => 'Include branding';

  @override
  String get planningIndent => 'Indent';

  @override
  String get planningInfo => 'Info';

  @override
  String get planningInfoOptional => 'Info text (optional)';

  @override
  String get planningInfoOptionalEllipsis => 'Info text (optional)...';

  @override
  String get planningInsertAgenda => 'Insert agenda';

  @override
  String get planningItem => 'Item';

  @override
  String get planningLastEvent => 'This is currently the last event';

  @override
  String get planningLinkCopied => 'Link copied to clipboard';

  @override
  String get planningMinPlaceholder => 'min';

  @override
  String planningMinShort(Object min) {
    return '$min min';
  }

  @override
  String get planningMinutes => 'Minutes';

  @override
  String get planningMoveLeft => 'Move left';

  @override
  String get planningMoveRight => 'Move right';

  @override
  String get planningName => 'Name';

  @override
  String get planningNext => 'Next';

  @override
  String get planningNoPlan => 'No plan available';

  @override
  String get planningNoPlanAvailable => 'No run sheet available.';

  @override
  String get planningNoScoresInstrument => 'No scores for your instrument';

  @override
  String get planningNote => 'Note';

  @override
  String get planningOnlyDissolve => 'Only dissolve block';

  @override
  String planningOnlyLabel(Object label) {
    return 'Only $label';
  }

  @override
  String get planningOrgPlan => 'Organization plan';

  @override
  String get planningOutdent => 'Outdent';

  @override
  String get planningPerformance => 'Performed by';

  @override
  String get planningPerformanceOptional => 'Performed by (optional)';

  @override
  String get planningPerformer => 'Performer';

  @override
  String planningPlanHeader(Object label) {
    return 'Plan \"$label\"';
  }

  @override
  String get planningPlanOptions => 'Plan options';

  @override
  String get planningPrevious => 'Previous';

  @override
  String get planningReadOnlyLink => 'Read-only link';

  @override
  String get planningRelatedAttendance => 'Related attendance';

  @override
  String get planningRename => 'Rename';

  @override
  String get planningRenameHint => 'Leave empty for the automatic name.';

  @override
  String get planningRenamePlan => 'Rename plan';

  @override
  String get planningResetPlan => 'Reset plan';

  @override
  String get planningResetPlanMessage => 'Do you really want to reset the plan for this event? All changes will be lost.';

  @override
  String get planningRunSheet => 'Run sheet';

  @override
  String get planningSaveAsTemplate => 'Save as template';

  @override
  String get planningSectionalPlan => 'Sectional rehearsal plan';

  @override
  String planningSectionalPlanTitle(Object tenant) {
    return '$tenant sectional rehearsal plan';
  }

  @override
  String get planningSendingTelegram => 'Sending plan via Telegram...';

  @override
  String get planningShareLink => 'Share link';

  @override
  String get planningShareWithMembers => 'Share plan with members';

  @override
  String get planningSoprano => 'Soprano';

  @override
  String get planningStrings => 'Strings';

  @override
  String get planningSubItemInfoPlaceholder => 'Info text (optional), e.g. song title';

  @override
  String get planningSubItemPlaceholder => 'Item, e.g. group song';

  @override
  String get planningTelegramImageShort => 'Via Telegram (image)';

  @override
  String get planningTelegramPdfShort => 'Via Telegram (PDF)';

  @override
  String get planningTemplateSaveFailed => 'The template could not be saved.';

  @override
  String planningTemplateSaved(Object name) {
    return '\"$name\" saved as template';
  }

  @override
  String get planningTemplates => 'Templates';

  @override
  String get planningTenor => 'Tenor';

  @override
  String get planningTimeMinutes => 'Time in minutes';

  @override
  String get planningToday => '· today';

  @override
  String get planningUnshare => 'Stop sharing';

  @override
  String get planningUnshareConfirm => 'Stop sharing?';

  @override
  String get planningUnshareMessage => 'The public link will stop working. Continue?';

  @override
  String get planningUnshared => 'Sharing stopped';

  @override
  String get planningUpdate => 'Update';

  @override
  String get planningUpdateTemplate => 'Update template';

  @override
  String get planningWoodwinds => 'Woodwinds';

  @override
  String get plansAddFieldMin => 'Please add at least one field.';

  @override
  String get plansAddOrgFailed => 'Could not add to the organization';

  @override
  String plansAddedToOrg(Object org) {
    return 'Plan added to the organization \"$org\"';
  }

  @override
  String get plansApplyTemplate => 'Apply template';

  @override
  String get plansBranding => 'Branding';

  @override
  String plansCalendarLinkMessage(Object link) {
    return 'Copy the following link into your calendar app:\n\n$link';
  }

  @override
  String get plansCopyLink => 'Copy link';

  @override
  String get plansDate => 'Date';

  @override
  String get plansDeleteFailed => 'Could not delete';

  @override
  String plansDeletePlanForever(Object title) {
    return 'Delete \"$title\" permanently?';
  }

  @override
  String get plansDetailedCalendar => 'Detailed (per item)';

  @override
  String get plansDiscardNew => 'Discard the current plan and create a new one?';

  @override
  String get plansDurationMin => 'Duration (min)';

  @override
  String get plansEditStartTime => 'Edit start time';

  @override
  String get plansEditTitle => 'Edit title';

  @override
  String get plansEnterNotePlease => 'Please enter a note.';

  @override
  String get plansFillDurations => 'Please fill in all durations.';

  @override
  String get plansFlutterAddToOrg => 'Add to organisation';

  @override
  String plansFlutterFieldsCount(Object count) {
    return '$count fields';
  }

  @override
  String get plansFlutterHideTab => 'Hide tab';

  @override
  String plansFlutterInOrg(Object name) {
    return 'In organisation \"$name\"';
  }

  @override
  String get plansFlutterOrgPlansTitle => 'Organisation plans';

  @override
  String get plansFlutterShowAsTab => 'Show as tab';

  @override
  String get plansImageA4 => 'Image (A4)';

  @override
  String get plansLinkCopied => 'Link copied';

  @override
  String get plansLinkCreated => 'Link created and copied';

  @override
  String get plansLinkFailed => 'Could not create the link';

  @override
  String get plansLinkInvalid => 'Link invalid or expired.';

  @override
  String get plansManage => 'Manage';

  @override
  String get plansMyPlans => 'My plans';

  @override
  String get plansNewPlan => 'New plan';

  @override
  String get plansNoOrg => 'This instance is not assigned to an organization.';

  @override
  String get plansNoPlans => 'No plans yet.';

  @override
  String get plansNoTemplate => 'No template chosen.';

  @override
  String get plansNoUpcomingOrgPlans => 'No upcoming org plans. Plans can be added to the organization via run sheet planning.';

  @override
  String get plansNoUpcomingPlans => 'No upcoming org plans.';

  @override
  String get plansNotFound => 'Plan not found. The link may have expired or be invalid.';

  @override
  String get plansOpenGuide => 'Open guide';

  @override
  String get plansOpenPlanning => 'Open run sheet planning';

  @override
  String get plansOrgPlan => 'Org plan';

  @override
  String get plansOrgPlans => 'Org plans';

  @override
  String plansOrgSuffix(Object title) {
    return '$title (org)';
  }

  @override
  String get plansOrgTemplates => '── Org templates ──';

  @override
  String get plansPastPlans => 'Past plans';

  @override
  String get plansPerformerOptional => 'Performer (optional)';

  @override
  String get plansPlan => 'Plan';

  @override
  String get plansPlanning => 'Run sheet planning';

  @override
  String plansPoints(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '$count item',
    );
    return '$_temp0';
  }

  @override
  String get plansPublicLink => 'Public link';

  @override
  String get plansPublicLinkActive => 'Public link active. All org plans can be viewed by anyone with the link.';

  @override
  String get plansRemoveOrgFailed => 'Could not remove from the organization';

  @override
  String get plansRemovedFromOrg => 'Plan removed from organization';

  @override
  String get plansReplaceWithTemplate => 'Replace the current run sheet with the template?';

  @override
  String get plansRestore => 'Restore';

  @override
  String get plansRestoreTemplate => 'Restore template';

  @override
  String plansRestoreTemplateMessage(Object name) {
    return 'Discard all changes and restore the defaults of the template \"$name\"?';
  }

  @override
  String get plansRevokeLink => 'Revoke link';

  @override
  String get plansRunSheet => 'Run sheet';

  @override
  String get plansSaveFailed => 'Could not save';

  @override
  String get plansSavePlanFailed => 'Could not save the plan';

  @override
  String get plansShareExport => 'Share & export';

  @override
  String get plansSimpleCalendar => 'Simple (1 event per plan)';

  @override
  String get plansSubscribeCalendar => 'Subscribe to calendar';

  @override
  String get plansTemplate => 'Template';

  @override
  String get plansTitle => 'Title';

  @override
  String get protocolAdd => 'Add';

  @override
  String get protocolAddPoint => 'Add item';

  @override
  String get protocolAgenda => 'Agenda';

  @override
  String get protocolAgendaItem => 'Agenda item';

  @override
  String get protocolAlwaysVisible => 'Always visible, regardless of the item';

  @override
  String get protocolAutoSaved => 'Saved automatically';

  @override
  String protocolAutoSavedAt(Object time) {
    return 'Saved automatically · $time';
  }

  @override
  String get protocolChangesAutoSaved => 'Changes are saved automatically';

  @override
  String get protocolCloseFailed => 'Not all topics could be marked as done';

  @override
  String get protocolCloseTopics => 'Mark topics as done';

  @override
  String get protocolCreateFailed => 'Minutes could not be created';

  @override
  String protocolDecidedCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count topics',
      one: '$count topic',
    );
    return '$_temp0 decided';
  }

  @override
  String protocolDiscussedCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count topics',
      one: '$count topic',
    );
    return '$_temp0 discussed';
  }

  @override
  String get protocolDragResize => 'Drag to adjust the width (double-click resets)';

  @override
  String protocolDueShort(Object date) {
    return 'due $date';
  }

  @override
  String get protocolDurationMinutes => 'Duration in minutes';

  @override
  String get protocolEarlierItem => 'Earlier run sheet item';

  @override
  String get protocolEditAfterPublish => 'The leadership can still edit the minutes after publishing. Changes are shown with their date.';

  @override
  String protocolExcusedCount(Object count) {
    return '$count excused · ';
  }

  @override
  String protocolExcusedList(Object count) {
    return 'Excused ($count)';
  }

  @override
  String protocolFileName(Object title, Object date) {
    return 'Minutes $title $date';
  }

  @override
  String get protocolFlutterChooseLeft => 'Choose an item on the left.';

  @override
  String get protocolFlutterDoneLower => 'done';

  @override
  String get protocolFlutterKeepDraft => 'Keep as draft';

  @override
  String get protocolFlutterPlanEmptyShort => 'The run sheet is still empty.';

  @override
  String get protocolFlutterPublishNotify => 'Publish & notify';

  @override
  String get protocolFlutterRepublishNotify => 'Publish again & notify';

  @override
  String protocolForNames(Object names) {
    return 'for $names';
  }

  @override
  String get protocolFromAttendance => 'from attendance';

  @override
  String get protocolFurtherTasks => 'Further tasks';

  @override
  String get protocolGeneral => 'General';

  @override
  String get protocolGeneralNotes => 'General notes';

  @override
  String get protocolGeneralTask => 'Task for the general notes';

  @override
  String get protocolHasNotes => 'Contains notes';

  @override
  String get protocolListFromAttendance => 'The list comes from the event\'s attendance.';

  @override
  String get protocolLoadFailed => 'Minutes could not be loaded.';

  @override
  String get protocolMayRead => 'Who may read';

  @override
  String get protocolMoreNotes => 'Further notes';

  @override
  String get protocolMoreNotesHint => 'Notes on items that are no longer in the run sheet.';

  @override
  String protocolMoreNotesTitle(Object title) {
    return 'Further notes · $title';
  }

  @override
  String get protocolMoreTasks => 'Other tasks of this meeting';

  @override
  String get protocolNextPoint => 'Next item';

  @override
  String get protocolNoNotes => 'No notes';

  @override
  String get protocolNoTasksYet => 'No tasks yet. Create them directly at an item.';

  @override
  String get protocolNobodyPresent => 'Nobody marked as present';

  @override
  String get protocolNotInPlan => 'This item is no longer in the run sheet. The notes are kept.';

  @override
  String get protocolNotPublished => 'These minutes have not been published yet.';

  @override
  String get protocolNotPublishedHint => 'As soon as the leadership publishes them, you can read them here.';

  @override
  String get protocolNoted => 'Noted';

  @override
  String get protocolNotes => 'Notes';

  @override
  String get protocolNotesSaveFailed => 'Notes could not be saved. Check your connection.';

  @override
  String get protocolNotified => 'Who is notified';

  @override
  String get protocolOpen => 'Open';

  @override
  String protocolOthersList(Object count) {
    return 'Absent / open ($count)';
  }

  @override
  String get protocolOutcome => 'Outcome';

  @override
  String get protocolOutcomeSaveFailed => 'Outcome could not be saved';

  @override
  String protocolPage(Object i, Object n) {
    return 'Page $i of $n';
  }

  @override
  String get protocolParticipants => 'Participants';

  @override
  String get protocolPdfFailed => 'PDF could not be created';

  @override
  String get protocolPdfFailedNotify => 'PDF could not be created, the notification is sent without PDF';

  @override
  String protocolPdfTitle(Object title) {
    return 'Minutes · $title';
  }

  @override
  String get protocolPlanEmpty => 'The run sheet is still empty. Add an item or write in the notes.';

  @override
  String get protocolPoint => 'Item';

  @override
  String get protocolPointFailed => 'Item could not be added';

  @override
  String get protocolPointNotes => 'Notes on the item';

  @override
  String protocolPostponedCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count topics',
      one: '$count topic',
    );
    return '$_temp0 postponed';
  }

  @override
  String get protocolPresent => 'Present';

  @override
  String protocolPresentCount(Object count) {
    return '$count present';
  }

  @override
  String protocolPresentList(Object count) {
    return 'Present ($count)';
  }

  @override
  String get protocolPublish => 'Publish minutes';

  @override
  String get protocolPublishFailed => 'Minutes could not be published';

  @override
  String get protocolPublishShort => 'Publish';

  @override
  String get protocolPublished => 'Minutes published';

  @override
  String protocolReadAll(Object type) {
    return 'all members (event type “$type” has no groups)';
  }

  @override
  String protocolReadGroups(Object type) {
    return 'the groups of the event type “$type”';
  }

  @override
  String protocolRecipients(Object count) {
    return '$count present';
  }

  @override
  String get protocolRepublish => 'Publish again';

  @override
  String get protocolResizeAgenda => 'Adjust agenda width';

  @override
  String get protocolResizeGeneral => 'Adjust width of general notes';

  @override
  String protocolResponsible(Object name) {
    return 'Responsible: $name';
  }

  @override
  String get protocolRetry => 'Try again';

  @override
  String get protocolRunSheet => 'Run sheet';

  @override
  String protocolRunning(Object name, Object min) {
    return 'Running: $name · $min min left';
  }

  @override
  String get protocolSaving => 'Saving …';

  @override
  String get protocolSendPdf => 'Attach minutes as PDF';

  @override
  String protocolSessionTasks(Object count) {
    return 'Tasks of this meeting · $count';
  }

  @override
  String get protocolSharePdf => 'Share as PDF';

  @override
  String get protocolShortcutNext => '⌘/Ctrl ↓';

  @override
  String get protocolSpontaneous => 'Spontaneous item';

  @override
  String get protocolSpontaneousHint => 'Will be created as a new topic and added to the run sheet.';

  @override
  String get protocolSuggestNext => ' · will be suggested at the next event';

  @override
  String get protocolSummary => 'Summary';

  @override
  String protocolTaskCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tasks',
      one: '$count task',
    );
    return '$_temp0';
  }

  @override
  String protocolTaskOwners(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count people',
      one: '$count person',
    );
    return ' · $_temp0 with tasks';
  }

  @override
  String protocolTaskRef(Object title) {
    return 'Task: $title';
  }

  @override
  String get protocolTitle => 'Minutes';

  @override
  String protocolTop(Object n) {
    return 'Item $n';
  }

  @override
  String protocolTopicRef(Object title) {
    return 'Topic: $title';
  }

  @override
  String get protocolViaTelegram => 'Via Telegram as a document';

  @override
  String get protocolVisibility => 'Visibility';

  @override
  String get protocolWholeMeeting => 'Applies to the whole meeting, regardless of the item.';

  @override
  String protocolWithoutNotes(Object count) {
    return 'No notes yet: $count';
  }

  @override
  String protocolWithoutOutcome(Object count) {
    return 'Without outcome: $count';
  }

  @override
  String redesignAbsenceAffects(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'This affects $count events',
      one: 'This affects 1 event',
      zero: 'You have no events in this period.',
    );
    return '$_temp0';
  }

  @override
  String get redesignAbsenceChooseEnd => 'Tap the last day.';

  @override
  String get redesignAbsenceChooseStart => 'Tap the first day.';

  @override
  String get redesignAbsenceNextMonth => 'Next month';

  @override
  String get redesignAbsencePause => 'Pause';

  @override
  String get redesignAbsencePauseButton => 'Pause …';

  @override
  String get redesignAbsencePauseHint => 'If you can\'t come for a longer time, you can pause yourself. The leaders then see that you are currently not taking part.';

  @override
  String get redesignAbsencePeriod => 'Period';

  @override
  String get redesignAbsencePrevMonth => 'Previous month';

  @override
  String get redesignAbsenceRange => 'Away for a period';

  @override
  String get redesignAbsenceReason => 'Reason';

  @override
  String get redesignAbsenceReasonHint => 'e.g. holiday';

  @override
  String get redesignAbsenceReset => 'Reset period';

  @override
  String get redesignAbsenceSubmit => 'Enter absence';

  @override
  String get redesignAbsenceTitle => 'Absence';

  @override
  String get redesignAdminTitle => 'Administration';

  @override
  String get redesignAppearanceAppIcon => 'App icon';

  @override
  String get redesignAppearanceAppIconFollow => 'App icon in colour theme';

  @override
  String get redesignAppearanceAppIconHint => 'The icon on your home screen changes with the colour theme.';

  @override
  String get redesignAppearanceAutoHint => 'Automatic follows your device setting.';

  @override
  String get redesignAppearanceBrightness => 'Light or dark';

  @override
  String get redesignAppearanceDeviceOnly => 'These settings apply to this device only.';

  @override
  String get redesignAppearanceModeAuto => 'Automatic';

  @override
  String get redesignAppearanceModeDark => 'Dark';

  @override
  String get redesignAppearanceModeLight => 'Light';

  @override
  String get redesignAppearancePreview => 'Preview of the chosen colour theme';

  @override
  String get redesignAppearancePreviewTitle => 'Rehearsal';

  @override
  String get redesignAppearanceStageAlwaysDark => 'Stage is always dark.';

  @override
  String get redesignAppearanceTitle => 'Appearance';

  @override
  String get redesignAppearanceWorld => 'Colour theme';

  @override
  String get redesignAppearanceWorldClear => 'Clear';

  @override
  String get redesignAppearanceWorldClearHint => 'Black on white, highest contrast';

  @override
  String get redesignAppearanceWorldConcertHall => 'Concert hall';

  @override
  String get redesignAppearanceWorldConcertHallHint => 'Warm, with serif headings';

  @override
  String get redesignAppearanceWorldNightBlue => 'Night blue';

  @override
  String get redesignAppearanceWorldNightBlueHint => 'Bold and round';

  @override
  String get redesignAppearanceWorldPetrol => 'Petrol';

  @override
  String get redesignAppearanceWorldPetrolHint => 'Calm and clear (default)';

  @override
  String get redesignAppearanceWorldStage => 'Stage';

  @override
  String get redesignAppearanceWorldStageHint => 'Always dark, for evenings and rehearsals';

  @override
  String get redesignApplicantOtherGroup => 'Join another group';

  @override
  String get redesignApplicantTitle => 'Application';

  @override
  String get redesignApplicantWaiting => 'Your registration is being reviewed';

  @override
  String redesignApplicantWaitingFor(Object group) {
    return 'Your registration with $group is being reviewed';
  }

  @override
  String get redesignBulkActionArchive => 'Archive';

  @override
  String get redesignBulkActionGroup => 'Section';

  @override
  String get redesignBulkActionPause => 'Pause';

  @override
  String redesignBulkArchiveConfirm(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Archive $count people?',
      one: 'Archive 1 person?',
    );
    return '$_temp0';
  }

  @override
  String get redesignBulkArchiveHint => 'Archived members are listed under Archive.';

  @override
  String get redesignBulkClear => 'Clear selection';

  @override
  String redesignBulkDone(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count people changed',
      one: '1 person changed',
    );
    return '$_temp0';
  }

  @override
  String redesignBulkFailed(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count changes failed',
      one: '1 change failed',
    );
    return '$_temp0';
  }

  @override
  String get redesignBulkHint => 'Tap members, then choose an action below.';

  @override
  String get redesignBulkNoGroup => 'No section';

  @override
  String get redesignBulkPauseReason => 'Reason for the pause';

  @override
  String get redesignBulkPickGroup => 'New section';

  @override
  String get redesignBulkSearch => 'Search member';

  @override
  String redesignBulkSelectGroup(Object group) {
    return 'All in $group';
  }

  @override
  String redesignBulkSelected(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count selected',
      one: '1 selected',
      zero: 'Nothing selected',
    );
    return '$_temp0';
  }

  @override
  String get redesignBulkTitle => 'Edit members';

  @override
  String get redesignCommonAll => 'All';

  @override
  String get redesignCommonCancel => 'Cancel';

  @override
  String get redesignCommonDone => 'Done';

  @override
  String get redesignCommonRetry => 'Try again';

  @override
  String get redesignComposeBody => 'Text';

  @override
  String get redesignComposeGroups => 'Choose sections';

  @override
  String get redesignComposeHint => 'The message appears for all recipients under Messages.';

  @override
  String get redesignComposeMissing => 'Subject, text and at least one channel are still missing.';

  @override
  String get redesignComposeSend => 'Send';

  @override
  String get redesignComposeSubject => 'Subject';

  @override
  String get redesignComposeTitle => 'Write message';

  @override
  String get redesignComposeTo => 'To whom?';

  @override
  String get redesignCreateChooseType => 'Choose type';

  @override
  String get redesignCreateDate => 'Date';

  @override
  String redesignCreateDays(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String get redesignCreateDeadline => 'Sign-out deadline';

  @override
  String get redesignCreateDeadline24h => '24 h before';

  @override
  String get redesignCreateDeadline2d => '2 days before';

  @override
  String get redesignCreateDeadlineHint => 'After that, members can no longer sign in or out themselves.';

  @override
  String get redesignCreateDeadlineNone => 'None';

  @override
  String get redesignCreateDeadlineWeek => '1 week before';

  @override
  String get redesignCreateDiscard => 'Discard';

  @override
  String get redesignCreateDiscardBody => 'Your input will be lost.';

  @override
  String get redesignCreateDiscardTitle => 'Discard event?';

  @override
  String get redesignCreateDuration => 'Duration';

  @override
  String redesignCreateDuty(Object weekday) {
    return 'Needed on $weekday';
  }

  @override
  String redesignCreateDutyCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count events',
      one: '1 event',
    );
    return '$_temp0';
  }

  @override
  String get redesignCreateEnd => 'End';

  @override
  String get redesignCreateFewer => 'Fewer';

  @override
  String get redesignCreateFewerDays => 'One day less';

  @override
  String redesignCreateHolidayHits(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count events fall on holidays',
      one: '1 event falls on a holiday',
    );
    return '$_temp0';
  }

  @override
  String get redesignCreateInvited => 'Who is invited?';

  @override
  String redesignCreateInvitedAll(Object count) {
    return 'Everyone · $count';
  }

  @override
  String redesignCreateInvitedGroups(Object groups, Object count) {
    return '$groups · $count';
  }

  @override
  String get redesignCreateInvitedHint => 'Set by the type';

  @override
  String get redesignCreateKeepEditing => 'Keep editing';

  @override
  String get redesignCreateLaterHint => 'Edit info text, attachment, checklist and schedule in the event afterwards.';

  @override
  String get redesignCreateMore => 'More';

  @override
  String get redesignCreateMoreDates => 'More dates';

  @override
  String get redesignCreateMoreDatesNone => 'None';

  @override
  String get redesignCreateMoreDays => 'One day more';

  @override
  String get redesignCreateNoPermission => 'You may not create events.';

  @override
  String get redesignCreateNoTypes => 'There is no event type yet. Create one in the settings first.';

  @override
  String get redesignCreatePlace => 'Place';

  @override
  String get redesignCreatePlaceHint => 'e.g. rehearsal room, 1 Main St';

  @override
  String redesignCreateRepeatBiweekly(Object date) {
    return 'Every 2 weeks until $date';
  }

  @override
  String get redesignCreateRepeatBiweeklyOption => 'Every 2 weeks';

  @override
  String redesignCreateRepeatCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count events',
      one: '1 event',
    );
    return '$_temp0';
  }

  @override
  String redesignCreateRepeatCustom(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count more days',
      one: '1 more day',
    );
    return '$_temp0';
  }

  @override
  String get redesignCreateRepeatCustomOption => 'Single days';

  @override
  String get redesignCreateRepeatHoliday => 'Holiday';

  @override
  String redesignCreateRepeatMax(Object count) {
    return 'At most $count events at once.';
  }

  @override
  String get redesignCreateRepeatOnce => 'Once';

  @override
  String get redesignCreateRepeatPick => 'Pick days in the calendar';

  @override
  String get redesignCreateRepeatSkipHolidays => 'Skip holidays';

  @override
  String get redesignCreateRepeatUntil => 'Until';

  @override
  String redesignCreateRepeatWeekly(Object weekday, Object date) {
    return 'Every $weekday until $date';
  }

  @override
  String get redesignCreateRepeatWeeklyOption => 'Every week';

  @override
  String get redesignCreateSongs => 'Pieces';

  @override
  String redesignCreateSongsCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pieces',
      one: '1 piece',
    );
    return '$_temp0';
  }

  @override
  String get redesignCreateSongsNone => 'None';

  @override
  String get redesignCreateStart => 'Start';

  @override
  String get redesignCreateSubmit => 'Create';

  @override
  String redesignCreateSubmitMany(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Create $count events',
      one: 'Create event',
    );
    return '$_temp0';
  }

  @override
  String redesignCreateSummaryBiweekly(Object weekday) {
    return 'every 2 weeks on $weekday';
  }

  @override
  String redesignCreateSummaryCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count events will be created',
      one: '1 event will be created',
    );
    return '$_temp0';
  }

  @override
  String redesignCreateSummaryRange(Object from, Object until) {
    return '$from to $until';
  }

  @override
  String redesignCreateSummaryWeekly(Object weekday) {
    return 'every $weekday';
  }

  @override
  String get redesignCreateTemplate => 'Template';

  @override
  String get redesignCreateTemplateHint => 'Fills in type, title, time and place. Everything stays editable.';

  @override
  String get redesignCreateTime => 'Time';

  @override
  String get redesignCreateTitle => 'New event';

  @override
  String get redesignCreateTitleLabel => 'Title';

  @override
  String get redesignCreateType => 'Type';

  @override
  String redesignEventAllDone(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count people marked present',
      one: '1 person marked present',
    );
    return '$_temp0';
  }

  @override
  String get redesignEventAllOpenPresent => 'Mark all open as present';

  @override
  String get redesignEventAnswers => 'Responses';

  @override
  String get redesignEventBusyLeave => 'Please wait until everything is saved.';

  @override
  String redesignEventCountAbsent(Object count) {
    return '$count missing';
  }

  @override
  String redesignEventCountExcused(Object count) {
    return '$count excused';
  }

  @override
  String redesignEventCountLate(Object count) {
    return '$count late';
  }

  @override
  String redesignEventCountNoAnswer(Object count) {
    return '$count without answer';
  }

  @override
  String redesignEventCountOpen(Object count) {
    return '$count open';
  }

  @override
  String redesignEventCountPresent(Object count) {
    return '$count there';
  }

  @override
  String get redesignEventDelete => 'Delete event';

  @override
  String get redesignEventDeleted => 'Event deleted';

  @override
  String get redesignEventDetails => 'All details';

  @override
  String redesignEventInvited(Object count) {
    return '$count invited';
  }

  @override
  String get redesignEventKeyboardHint => 'Keyboard: A present · V late · F absent · ↑↓ next person · ⌘Z or Ctrl+Z undo';

  @override
  String get redesignEventMore => 'All details and editing';

  @override
  String get redesignEventMoreHint => 'Schedule, checklist, works and notes';

  @override
  String redesignEventMoreStatus(Object name) {
    return 'More statuses and note for $name';
  }

  @override
  String get redesignEventNeutralHint => 'does not count';

  @override
  String get redesignEventNoMatch => 'Nobody matches your search.';

  @override
  String get redesignEventNoPersons => 'No people have been added to this event yet.';

  @override
  String get redesignEventNotFound => 'This event could not be found.';

  @override
  String get redesignEventNote => 'Note for this event';

  @override
  String get redesignEventNoteHint => 'e.g. reason or time';

  @override
  String get redesignEventPlan => 'View schedule';

  @override
  String get redesignEventPlanHint => 'Run sheet, live on the day';

  @override
  String redesignEventRegisterEmpty(Object group, Object count) {
    return '$group: 0 of $count there.';
  }

  @override
  String redesignEventRegisterNames(num count, Object names) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$names have signed out.',
      one: '$names has signed out.',
    );
    return '$_temp0';
  }

  @override
  String get redesignEventSaving => 'Saving …';

  @override
  String get redesignEventSearch => 'Search person';

  @override
  String get redesignEventSearchClose => 'Close search';

  @override
  String get redesignEventSearchHint => 'Name';

  @override
  String get redesignEventSignouts => 'Sign-outs';

  @override
  String get redesignEventStatus => 'Status';

  @override
  String get redesignEventTabOverview => 'Overview';

  @override
  String get redesignEventTabRecord => 'Attendance';

  @override
  String redesignEventToastReset(Object name) {
    return '$name: reset';
  }

  @override
  String redesignEventToastSet(Object name, Object status) {
    return '$name: $status';
  }

  @override
  String get redesignEventUndo => 'Undo';

  @override
  String get redesignEventUndone => 'Undone';

  @override
  String get redesignEventsAbsent => 'Away …';

  @override
  String get redesignEventsCreateFirst => 'Create first event';

  @override
  String get redesignEventsEmpty => 'No events yet. Create the first rehearsal.';

  @override
  String get redesignEventsLastWeek => 'Last 7 days';

  @override
  String get redesignEventsNew => 'New event';

  @override
  String get redesignEventsNo => 'Sign out';

  @override
  String get redesignEventsNoMatch => 'No events match your search.';

  @override
  String get redesignEventsNoPast => 'No past events yet.';

  @override
  String get redesignEventsPast => 'Past';

  @override
  String redesignEventsPastAverage(Object percent) {
    return 'Past · Ø $percent %';
  }

  @override
  String redesignEventsPastOwn(Object percent) {
    return 'Past · $percent % attended';
  }

  @override
  String redesignEventsPercentPresent(Object percent) {
    return '$percent % present';
  }

  @override
  String get redesignEventsSearch => 'Search events';

  @override
  String get redesignEventsSearchClose => 'Close search';

  @override
  String get redesignEventsSearchHint => 'Title or place';

  @override
  String get redesignEventsShowAll => 'Show all events again';

  @override
  String get redesignEventsUpcoming => 'Upcoming';

  @override
  String redesignEventsWaiting(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count events are waiting for your answer',
      one: '1 event is waiting for your answer',
    );
    return '$_temp0';
  }

  @override
  String get redesignEventsYes => 'I\'m in';

  @override
  String redesignFilesActions(Object name) {
    return 'Actions for $name';
  }

  @override
  String get redesignFilesColName => 'Name';

  @override
  String get redesignFilesColPart => 'Part';

  @override
  String get redesignFilesColType => 'Type';

  @override
  String redesignFilesConflictMessage(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files have the same name or the same part as existing files:',
      one: '1 file has the same name or the same part as an existing file:',
    );
    return '$_temp0';
  }

  @override
  String get redesignFilesConflictTitle => 'Already there';

  @override
  String get redesignFilesDelete => 'Delete';

  @override
  String redesignFilesDeletedMany(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files deleted',
      one: '1 file deleted',
    );
    return '$_temp0';
  }

  @override
  String redesignFilesDeletedOne(Object name) {
    return '“$name” deleted';
  }

  @override
  String get redesignFilesDismiss => 'Dismiss';

  @override
  String get redesignFilesDone => 'Done';

  @override
  String get redesignFilesDownload => 'Download';

  @override
  String get redesignFilesDownloadAll => 'All as ZIP';

  @override
  String get redesignFilesDownloadZip => 'Download as ZIP';

  @override
  String get redesignFilesDropHint => 'Drag files here or choose “Upload”.';

  @override
  String redesignFilesDropOverlay(Object name) {
    return 'Release to upload them to “$name”';
  }

  @override
  String get redesignFilesFailed => 'Failed';

  @override
  String get redesignFilesKeepBoth => 'Keep both';

  @override
  String get redesignFilesOpen => 'Open';

  @override
  String get redesignFilesOtherCategory => 'Other …';

  @override
  String get redesignFilesPickHint => 'Click to choose files.';

  @override
  String redesignFilesQueueDone(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files uploaded',
      one: '1 file uploaded',
    );
    return '$_temp0';
  }

  @override
  String redesignFilesQueueTitle(Object done, Object total) {
    return 'Uploading: $done of $total';
  }

  @override
  String get redesignFilesRename => 'Rename';

  @override
  String get redesignFilesReplace => 'Replace';

  @override
  String get redesignFilesRestored => 'Restored';

  @override
  String redesignFilesSaveFailed(Object error) {
    return 'Saving failed: $error';
  }

  @override
  String get redesignFilesSelectAll => 'Select all';

  @override
  String redesignFilesSelected(Object count) {
    return '$count selected';
  }

  @override
  String get redesignFilesShortcuts => 'Keyboard shortcuts';

  @override
  String redesignFilesShortcutsHelp(Object mod) {
    return '↑ ↓ select · Shift+↑↓ several · Enter open · Space preview/play · Del delete · $mod+U upload · $mod+A all · $mod+D download · $mod+Z undo · F2 rename';
  }

  @override
  String get redesignFilesTitle => 'Files';

  @override
  String get redesignFilesUpload => 'Upload';

  @override
  String get redesignFilesUploading => 'Uploading …';

  @override
  String get redesignFilesWaiting => 'Waiting';

  @override
  String get redesignFilesZipPreparing => 'Creating ZIP …';

  @override
  String get redesignGroupsLoadFailed => 'Your groups could not be loaded.';

  @override
  String get redesignGroupsManage => 'Manage groups';

  @override
  String get redesignGroupsSwitchFailed => 'Switching failed. Please try again.';

  @override
  String redesignGroupsSwitchHint(Object name) {
    return 'Group: $name. Tap to switch';
  }

  @override
  String get redesignGroupsTitle => 'Switch group';

  @override
  String get redesignManageAnnouncementsHint => 'View sent messages';

  @override
  String get redesignManageAreaCommunication => 'Communication';

  @override
  String get redesignManageAreaData => 'Statistics & data';

  @override
  String get redesignManageAreaEvents => 'Events & planning';

  @override
  String get redesignManageAreaGroup => 'Group';

  @override
  String get redesignManageAreaMembers => 'Members, sections & roles';

  @override
  String get redesignManageAreaWorks => 'Works & files';

  @override
  String get redesignManageClassic => 'All settings (previous view)';

  @override
  String get redesignManageExtraFieldsHint => 'Custom fields for people and works';

  @override
  String redesignManageFooter(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'All $count previous entries sit in these areas and can be reached directly via the search.',
      one: 'The previous entry sits in these areas and can be reached directly via the search.',
    );
    return '$_temp0';
  }

  @override
  String get redesignManageGeneralHint => 'Name, season, reasons, registration';

  @override
  String get redesignManageGeneralTitle => 'General settings';

  @override
  String get redesignManageMissingHint => 'Members with an e-mail but no access';

  @override
  String get redesignManageNoMatch => 'No setting matches the search.';

  @override
  String redesignManagePending(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count people are waiting for approval',
      one: '1 person is waiting for approval',
    );
    return '$_temp0';
  }

  @override
  String get redesignManagePendingTitle => 'Approvals';

  @override
  String get redesignManageRecent => 'Recently opened';

  @override
  String get redesignManageSearch => 'Search settings';

  @override
  String get redesignManageSearchLabel => 'Search administration';

  @override
  String get redesignMeAbsence => 'Report absence';

  @override
  String get redesignMeAccount => 'Account';

  @override
  String get redesignMeAdmin => 'Administration';

  @override
  String get redesignMeAdminHint => 'Members, event types, permissions and more';

  @override
  String get redesignMeAllSettings => 'All settings';

  @override
  String get redesignMeApp => 'App';

  @override
  String get redesignMeBeta => 'New design (beta)';

  @override
  String get redesignMeBetaHint => 'On this device only. You can switch it off any time.';

  @override
  String get redesignMeCalendar => 'Subscribe to calendar';

  @override
  String get redesignMeFeedback => 'Send feedback';

  @override
  String get redesignMeForMe => 'For me';

  @override
  String get redesignMeGroups => 'My groups';

  @override
  String redesignMeGroupsCount(Object count) {
    return '$count groups';
  }

  @override
  String get redesignMeHelp => 'Help';

  @override
  String get redesignMeLogout => 'Log out';

  @override
  String get redesignMeNotifications => 'Notifications';

  @override
  String get redesignMeWhatsNew => 'New in this version';

  @override
  String redesignMembersAbsentFrom(Object date) {
    return 'away from $date';
  }

  @override
  String redesignMembersAbsentUntil(Object date) {
    return 'away until $date';
  }

  @override
  String redesignMembersActive(Object count) {
    return 'Active · $count';
  }

  @override
  String get redesignMembersAdd => 'Add person';

  @override
  String redesignMembersAverage(Object percent) {
    return 'Ø $percent %';
  }

  @override
  String redesignMembersBirthdayIn(Object count) {
    return 'Birthday in $count days';
  }

  @override
  String get redesignMembersBirthdayToday => 'Birthday today';

  @override
  String get redesignMembersBirthdayTomorrow => 'Birthday tomorrow';

  @override
  String get redesignMembersEmpty => 'No members yet.';

  @override
  String get redesignMembersEmptyPaused => 'Nobody is paused.';

  @override
  String get redesignMembersEmptyPending => 'Nobody is waiting for approval.';

  @override
  String get redesignMembersLeader => 'Section leader';

  @override
  String get redesignMembersLow => 'below 50 %';

  @override
  String get redesignMembersNoMatch => 'Nobody matches the search.';

  @override
  String redesignMembersPaused(Object count) {
    return 'Paused · $count';
  }

  @override
  String redesignMembersPausedUntil(Object date) {
    return 'paused until $date';
  }

  @override
  String redesignMembersPending(Object count) {
    return 'Waiting · $count';
  }

  @override
  String get redesignMembersPendingHint => 'Tap a person to review and approve them.';

  @override
  String redesignMembersPercent(Object percent) {
    return '$percent %';
  }

  @override
  String get redesignMembersSearch => 'Name, instrument, section';

  @override
  String get redesignMembersSearchLabel => 'Search members';

  @override
  String redesignMembersSection(Object title, Object count) {
    return '$title · $count';
  }

  @override
  String get redesignMembersStats => 'Statistics';

  @override
  String get redesignNotifForMe => 'For me';

  @override
  String get redesignNotifGroups => 'Groups';

  @override
  String get redesignNotifGroupsHint => 'Each group can be muted on its own.';

  @override
  String get redesignNotifHow => 'How';

  @override
  String get redesignNotifLead => 'As a leader';

  @override
  String get redesignNotifTelegram => 'Telegram';

  @override
  String get redesignNotifTelegramConnect => 'Connect';

  @override
  String get redesignNotifTelegramConnected => 'Connected';

  @override
  String get redesignNotifTelegramDisconnect => 'Disconnect';

  @override
  String get redesignOwnInfos => 'Event info';

  @override
  String get redesignOwnMore => 'More';

  @override
  String get redesignOwnNotFound => 'This event is no longer in your list.';

  @override
  String get redesignOwnRoute => 'Directions';

  @override
  String get redesignPersonAbsence => 'Away';

  @override
  String redesignPersonAbsenceRange(Object from, Object until) {
    return '$from to $until';
  }

  @override
  String get redesignPersonAllTermine => 'Show all events';

  @override
  String get redesignPersonArchive => 'Archive';

  @override
  String get redesignPersonAttendance => 'Attendance';

  @override
  String get redesignPersonBirthday => 'Birthday';

  @override
  String get redesignPersonEdit => 'Edit';

  @override
  String get redesignPersonHistory => 'History';

  @override
  String redesignPersonInDays(Object count) {
    return 'in $count days';
  }

  @override
  String get redesignPersonJoined => 'Member since';

  @override
  String redesignPersonLastTermine(Object count) {
    return 'Last $count events, newest on the right';
  }

  @override
  String get redesignPersonNoTermine => 'No past events yet.';

  @override
  String get redesignPersonNotFound => 'This person is no longer here.';

  @override
  String get redesignPersonNotes => 'Note';

  @override
  String redesignPersonOfTermine(Object attended, Object total) {
    return '$attended of $total events';
  }

  @override
  String get redesignPersonOverall => 'Overall';

  @override
  String get redesignPersonPause => 'Pause';

  @override
  String get redesignPersonPaused => 'Paused';

  @override
  String get redesignPersonPausedOpen => 'no end date';

  @override
  String get redesignPersonPending => 'Waiting for approval.';

  @override
  String redesignPersonPercent(Object percent) {
    return '$percent %';
  }

  @override
  String get redesignPersonResume => 'Active again';

  @override
  String get redesignPersonReview => 'Review and approve';

  @override
  String redesignPersonSince(Object year) {
    return 'since $year';
  }

  @override
  String redesignPersonSinceDate(Object date) {
    return 'since $date';
  }

  @override
  String get redesignPersonToday => 'today';

  @override
  String get redesignPersonTomorrow => 'tomorrow';

  @override
  String get redesignPultAllOpen => 'All open present';

  @override
  String get redesignPultBack => 'Event';

  @override
  String get redesignPultDone => 'Done';

  @override
  String redesignPultGroupCount(Object present, Object total) {
    return '$present / $total present';
  }

  @override
  String get redesignPultHint => 'Tap = present · tap again = back · press and hold = more statuses';

  @override
  String get redesignPultOpen => 'Stand mode';

  @override
  String get redesignPultOpenHint => 'Big tiles to tap, made for the tablet on the stand';

  @override
  String get redesignPultStatusOpen => 'open';

  @override
  String redesignPultTitle(Object title) {
    return '$title · Stand mode';
  }

  @override
  String get redesignSignoutCannot => 'I can\'t come';

  @override
  String get redesignSignoutLater => 'I\'ll be late';

  @override
  String get redesignSignoutOther => 'Other reason';

  @override
  String get redesignSignoutOtherHint => 'Describe briefly (at least 5 characters)';

  @override
  String get redesignSignoutPrivacy => 'Only the leaders see your reason.';

  @override
  String get redesignSignoutReason => 'Reason';

  @override
  String get redesignSignoutSubmit => 'Sign out';

  @override
  String get redesignSignoutSubmitLate => 'Report delay';

  @override
  String get redesignSplitEventsEmpty => 'Choose an event on the left.';

  @override
  String get redesignSplitMembersEmpty => 'Choose a person on the left.';

  @override
  String get redesignSplitWorksEmpty => 'Choose a work on the left.';

  @override
  String get redesignStatsAvg => 'Ø attendance';

  @override
  String redesignStatsBar(Object date, Object percent) {
    return '$date: $percent %';
  }

  @override
  String get redesignStatsEmpty => 'There are no events in this period.';

  @override
  String get redesignStatsEvents => 'Events';

  @override
  String get redesignStatsLoadFailed => 'Could not load the insights.';

  @override
  String redesignStatsLow(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count people below 50 %',
      one: '1 person below 50 %',
    );
    return '$_temp0';
  }

  @override
  String get redesignStatsMembers => 'Active';

  @override
  String get redesignStatsPerEvent => 'Attendance per event';

  @override
  String redesignStatsPerEventHint(Object count) {
    return 'The last $count events';
  }

  @override
  String get redesignStatsPerGroup => 'Per section';

  @override
  String get redesignStatsRange12m => '12 months';

  @override
  String get redesignStatsRange3m => '3 months';

  @override
  String get redesignStatsRangeSeason => 'Season';

  @override
  String get redesignStatsTitle => 'Insights';

  @override
  String get redesignStatusAbsent => 'Absent';

  @override
  String get redesignStatusExcused => 'Excused';

  @override
  String get redesignStatusLate => 'Late';

  @override
  String get redesignStatusLater => 'Coming later';

  @override
  String get redesignStatusOpen => 'Open';

  @override
  String get redesignStatusYes => 'Attending';

  @override
  String get redesignTabEvents => 'Events';

  @override
  String get redesignTabMe => 'Me';

  @override
  String get redesignTabMembers => 'Members';

  @override
  String get redesignTabToday => 'Today';

  @override
  String get redesignTabWorks => 'Works';

  @override
  String get redesignTodayAllEvents => 'All events';

  @override
  String get redesignTodayAnswerChildren => 'Answer for my children';

  @override
  String get redesignTodayAnswered => 'All answered';

  @override
  String get redesignTodayAnsweredLater => 'You said you will come later.';

  @override
  String get redesignTodayAnsweredNo => 'You signed out.';

  @override
  String get redesignTodayAnsweredYes => 'Great, you are coming.';

  @override
  String get redesignTodayAttention => 'Needs your attention';

  @override
  String redesignTodayBirthday(Object name, Object day) {
    return 'Birthday: $name ($day)';
  }

  @override
  String redesignTodayBirthdayMore(Object name, Object day, Object count) {
    return 'Birthday: $name ($day) +$count';
  }

  @override
  String redesignTodayCountAbsent(Object count) {
    return '$count absent';
  }

  @override
  String redesignTodayCountExcused(Object count) {
    return '$count excused';
  }

  @override
  String redesignTodayCountLater(Object count) {
    return '$count later';
  }

  @override
  String redesignTodayCountOpen(Object count) {
    return '$count open';
  }

  @override
  String redesignTodayCountYes(Object count) {
    return '$count attending';
  }

  @override
  String redesignTodayCritical(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count members often missing',
      one: '$count member often missing',
    );
    return '$_temp0';
  }

  @override
  String get redesignTodayCriticalHint => 'Below the attendance limit';

  @override
  String get redesignTodayDayToday => 'Today';

  @override
  String get redesignTodayDayTomorrow => 'Tomorrow';

  @override
  String get redesignTodayDutyQuestion => 'You have been assigned. Do you confirm?';

  @override
  String redesignTodayGreeting(Object name) {
    return 'Hi $name';
  }

  @override
  String redesignTodayInHours(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'in $count h',
      one: 'in $count h',
    );
    return '$_temp0';
  }

  @override
  String redesignTodayInMinutes(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'in $count min',
      one: 'in $count min',
    );
    return '$_temp0';
  }

  @override
  String get redesignTodayLater => 'I\'ll be late …';

  @override
  String get redesignTodayLoadFailed => 'This could not be loaded.';

  @override
  String get redesignTodayLoading => 'Loading …';

  @override
  String get redesignTodayMore => 'More about this event';

  @override
  String get redesignTodayMySection => 'My section';

  @override
  String get redesignTodayMySectionHint => 'Attendance of your section';

  @override
  String get redesignTodayNextEvent => 'Next event';

  @override
  String get redesignTodayNo => 'Can\'t make it';

  @override
  String get redesignTodayNoAfterAll => 'Sign out';

  @override
  String get redesignTodayNoChildren => 'No children are linked to your account yet.';

  @override
  String get redesignTodayNoDone => 'Signed out';

  @override
  String get redesignTodayNoMember => 'You are not listed as a member of this group.';

  @override
  String get redesignTodayNoUpcoming => 'There are no upcoming events.';

  @override
  String get redesignTodayNotPart => 'You are not part of this event.';

  @override
  String get redesignTodayNothingElse => 'Nothing else is planned yet.';

  @override
  String get redesignTodayNotifications => 'Notifications';

  @override
  String redesignTodayNotificationsUnread(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Notifications, $count unread',
      one: 'Notifications, $count unread',
    );
    return '$_temp0';
  }

  @override
  String get redesignTodayOtherReason => 'Other reason …';

  @override
  String redesignTodayPending(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count new registrations',
      one: '$count new registration',
    );
    return '$_temp0';
  }

  @override
  String get redesignTodayPendingHint => 'Review and approve';

  @override
  String get redesignTodayQuestion => 'Are you coming?';

  @override
  String get redesignTodayRecord => 'Take attendance';

  @override
  String get redesignTodayRunning => 'now';

  @override
  String redesignTodaySignouts(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sign-outs for the next event',
      one: '$count sign-out for the next event',
    );
    return '$_temp0';
  }

  @override
  String get redesignTodaySignoutsHint => 'See reasons';

  @override
  String get redesignTodayThisWeek => 'This week';

  @override
  String get redesignTodayUpNext => 'Up next';

  @override
  String get redesignTodayWeekEmpty => 'Nothing else this week.';

  @override
  String get redesignTodayWhyNot => 'Why can\'t you make it?';

  @override
  String get redesignTodayYes => 'I\'m coming';

  @override
  String get redesignTodayYesAfterAll => 'Coming after all';

  @override
  String get redesignTodayYesDone => 'Attending';

  @override
  String get redesignTodayYourAnswer => 'Your answer';

  @override
  String get redesignWorkAllFiles => 'All files';

  @override
  String get redesignWorkAllParts => 'All parts';

  @override
  String get redesignWorkEdit => 'Edit';

  @override
  String redesignWorkFileCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files',
      one: '1 file',
    );
    return '$_temp0';
  }

  @override
  String get redesignWorkLastPlayed => 'Last played';

  @override
  String get redesignWorkLastSung => 'Last sung';

  @override
  String get redesignWorkLink => 'Link';

  @override
  String get redesignWorkLyrics => 'Lyrics';

  @override
  String get redesignWorkNever => 'Never';

  @override
  String get redesignWorkNoFiles => 'There are no files for this work yet.';

  @override
  String get redesignWorkNoPart => 'There is no sheet music for your part yet.';

  @override
  String get redesignWorkNormalSpeed => 'Play at normal speed';

  @override
  String get redesignWorkNotFound => 'This work no longer exists here.';

  @override
  String redesignWorkNumber(Object number) {
    return 'No. $number';
  }

  @override
  String get redesignWorkOpen => 'Open';

  @override
  String get redesignWorkPause => 'Pause';

  @override
  String get redesignWorkPlanned => 'Planned';

  @override
  String get redesignWorkPlay => 'Play';

  @override
  String get redesignWorkRecording => 'Recording';

  @override
  String redesignWorkRecordingFrom(Object date) {
    return 'Recording from $date';
  }

  @override
  String get redesignWorkScore => 'Score';

  @override
  String get redesignWorkShare => 'Share';

  @override
  String redesignWorkShareFile(Object name) {
    return 'Share $name';
  }

  @override
  String get redesignWorkSlower => 'Play slower';

  @override
  String get redesignWorkYourPart => 'Your part';

  @override
  String get redesignWorksAdd => 'Add work';

  @override
  String redesignWorksAll(Object count) {
    return 'All · $count';
  }

  @override
  String get redesignWorksAudio => 'Audio';

  @override
  String get redesignWorksCurrent => 'In rehearsal';

  @override
  String get redesignWorksEmpty => 'No works yet.';

  @override
  String get redesignWorksFiles => 'Files';

  @override
  String get redesignWorksFilesLabel => 'Files of the group';

  @override
  String get redesignWorksFilter => 'Filter & view';

  @override
  String get redesignWorksFilterActive => 'Filter active';

  @override
  String get redesignWorksMore => 'More';

  @override
  String get redesignWorksNoMatch => 'No work matches the search.';

  @override
  String get redesignWorksPdf => 'PDF';

  @override
  String get redesignWorksResetFilter => 'Reset filter';

  @override
  String get redesignWorksSearch => 'Title, composer, number';

  @override
  String get redesignWorksSearchLabel => 'Search works';

  @override
  String get registerCreate => 'Create instance now';

  @override
  String registerCreateFailed(Object error) {
    return 'Could not create the instance: $error';
  }

  @override
  String get registerCreating => 'Creating instance...';

  @override
  String get registerDeleteAccount => 'Delete account';

  @override
  String get registerDeleteConfirm => 'Delete permanently';

  @override
  String get registerDeleteDone => 'Your account has been deleted.';

  @override
  String registerDeleteFailed(Object error) {
    return 'Could not delete: $error';
  }

  @override
  String get registerDeleteHeader => 'Really delete account?';

  @override
  String get registerDeleteMessage => 'Your account will be removed permanently. This action cannot be undone.';

  @override
  String get registerDeleteRunning => 'Deleting account...';

  @override
  String get registerFillAll => 'Please fill in all fields to continue.';

  @override
  String get registerFillAllToast => 'Please fill in all fields.';

  @override
  String get registerFlutterMainGroupInfo => 'What is the main group?';

  @override
  String get registerFullName => 'Full name';

  @override
  String get registerFullNameHelper => 'The name is shown in the app';

  @override
  String get registerGroupType => 'Group type';

  @override
  String get registerGroupTypeQuestion => 'What describes your group best?';

  @override
  String get registerHelpChoir => 'Optimised for choirs with voice sections (soprano, alto, tenor, bass).';

  @override
  String get registerHelpGeneral => 'Ideal for clubs, teams or other groups.';

  @override
  String get registerHelpOrchestra => 'Optimised for orchestras/music groups with instrument sections.';

  @override
  String get registerIntroHtml => 'An <strong>instance</strong> is your own space for your orchestra, choir or group. This is where you manage members, events and attendance.';

  @override
  String get registerJoinHeading => 'Do you want to join an existing instance?';

  @override
  String get registerJoinText => 'Ask the person in charge to invite you by email. You only need a new instance if you want to be an administrator yourself.';

  @override
  String get registerLogout => 'Sign out';

  @override
  String get registerMainGroupHelper => 'e.g. leadership, conductors, board';

  @override
  String get registerMainGroupInfoHtml => '<h3>What is the main group?</h3><p>The main group is a special group for people in a leading role (e.g. conductors, choir directors, board).</p><p><strong>Special features:</strong></p><ul><li>Cannot be deleted</li><li>Members automatically get extended rights</li><li>Ideal for people who manage the instance</li></ul><p><em>You can add more groups (e.g. soprano, violins) later.</em></p>';

  @override
  String get registerMainGroupName => 'Name of the main group';

  @override
  String get registerMissingMainGroup => 'Main group name is missing';

  @override
  String get registerMissingName => 'Instance name is missing';

  @override
  String get registerMissingShortName => 'Instance abbreviation is missing';

  @override
  String get registerModalAcceptPrivacy => 'Accept privacy policy';

  @override
  String get registerModalAcceptPrivacyToast => 'Please accept the privacy policy';

  @override
  String get registerModalConfirm => 'Confirm';

  @override
  String get registerModalConfirmPassword => 'Confirm password';

  @override
  String get registerModalConfirmPasswordPlaceholder => 'Enter password again';

  @override
  String get registerModalEmailPlaceholder => 'you@example.com';

  @override
  String get registerModalFailed => 'Sign-up failed';

  @override
  String get registerModalHintOtp => 'After signing up we will send you a 6-digit code by email. Enter it here to activate your account.';

  @override
  String get registerModalHintPassword => 'After signing up we will send you a confirmation email. Please click the link in it to activate your account.';

  @override
  String get registerModalIntro => 'Create an account to manage your attendance or to set up a new instance for your group, choir or orchestra.';

  @override
  String get registerModalInvalidEmail => 'Invalid email address';

  @override
  String get registerModalPasswordMismatch => 'Passwords do not match';

  @override
  String get registerModalPasswordPlaceholder => 'At least 6 characters';

  @override
  String get registerModalPasswordTooShort => 'Password must be at least 6 characters long';

  @override
  String get registerModalPrivacyAfter => '.';

  @override
  String get registerModalPrivacyBefore => 'I accept the terms of use and have read the';

  @override
  String get registerModalPrivacyLink => 'privacy policy';

  @override
  String get registerModalRunning => 'Signing up...';

  @override
  String get registerModalSubmitting => 'Signing up...';

  @override
  String get registerModalTitle => 'Sign up';

  @override
  String get registerModalWelcome => 'Welcome to Attendix!';

  @override
  String get registerPlaceholderChoirMain => 'e.g. Choir leadership';

  @override
  String get registerPlaceholderChoirName => 'e.g. Harmony Gospel Choir';

  @override
  String get registerPlaceholderChoirShort => 'e.g. HGC';

  @override
  String get registerPlaceholderGeneralMain => 'e.g. Board';

  @override
  String get registerPlaceholderGeneralName => 'e.g. Springfield Sports Club';

  @override
  String get registerPlaceholderGeneralShort => 'e.g. SSC';

  @override
  String get registerPlaceholderOrchestraMain => 'e.g. Conductors';

  @override
  String get registerPlaceholderOrchestraName => 'e.g. Springfield City Orchestra';

  @override
  String get registerPlaceholderOrchestraShort => 'e.g. SCO';

  @override
  String get registerShortName => 'Instance abbreviation';

  @override
  String get registerShortNameHelper => 'Used where space is limited';

  @override
  String get registerStep1 => 'Choose the type of group';

  @override
  String get registerStep2 => 'Name of your instance';

  @override
  String get registerStep3 => 'Set the main group';

  @override
  String get registerSummary => 'Summary';

  @override
  String registerSummaryMainGroup(Object name) {
    return 'Main group: $name';
  }

  @override
  String registerSummaryType(Object type) {
    return 'Type: $type';
  }

  @override
  String get registerTitle => 'Create new instance';

  @override
  String get registerTypeChoir => 'Choir';

  @override
  String get registerTypeChoirOption => 'Choir / vocal group';

  @override
  String get registerTypeGeneral => 'General group';

  @override
  String get registerTypeOrchestra => 'Orchestra';

  @override
  String get registerTypeOrchestraOption => 'Orchestra / music group';

  @override
  String get registerWelcome => 'Welcome!';

  @override
  String get rolePermAbsencesHelper => 'If enabled, people with this role can enter planned absences for themselves.';

  @override
  String get rolePermAllGroups => 'Manage all groups';

  @override
  String get rolePermAllGroupsHelper => 'If disabled, people with this role can only manage attendance of their assigned group.';

  @override
  String get rolePermAllowPause => 'Allow pausing oneself';

  @override
  String get rolePermChecklistHelper => 'If enabled, people with this role can see the checklist in the attendance view.';

  @override
  String get rolePermCreateAttendance => 'Create attendance';

  @override
  String get rolePermCreateHelper => 'If disabled, people with this role cannot create new attendance records.';

  @override
  String get rolePermDiscard => 'Discard';

  @override
  String get rolePermEnterAbsences => 'Enter planned absences';

  @override
  String get rolePermFiles => 'File storage';

  @override
  String get rolePermFilesForAll => 'File storage for all members';

  @override
  String get rolePermFilesHelper => 'Admins, responsibles and helpers always see the file storage. If enabled, all other members except applicants can read it too. Uploading stays reserved for admins and responsibles.';

  @override
  String rolePermFlutterLoadFailed(Object error) {
    return 'Error loading role permissions\n$error';
  }

  @override
  String get rolePermNotesHelper => 'If enabled, people with this role can see the members\' notes in the attendance view.';

  @override
  String get rolePermPauseHelper => 'If enabled, members can pause and reactivate themselves.';

  @override
  String get rolePermSaveFailed => 'Error saving the role permissions';

  @override
  String get rolePermSaved => 'Role permissions saved';

  @override
  String get rolePermSeeChecklist => 'See checklist';

  @override
  String get rolePermSeeNotes => 'See member notes';

  @override
  String get rolePermTitle => 'Roles & permissions';

  @override
  String get rolePermUnsaved => 'Unsaved changes';

  @override
  String get rolePermUnsavedMessage => 'You have unsaved changes. Do you want to save them before leaving the page?';

  @override
  String get rolesAdministrator => 'Administrator';

  @override
  String get rolesApplicant => 'Applicant';

  @override
  String get rolesHelper => 'Helper';

  @override
  String get rolesMember => 'Member';

  @override
  String get rolesParent => 'Parent';

  @override
  String get rolesParents => 'Parents';

  @override
  String get rolesResponsible => 'Responsible';

  @override
  String get rolesViewer => 'Observer';

  @override
  String get rolesVoiceLeader => 'Section leader';

  @override
  String get rolesVoiceLeaderHelper => 'Section leader helper';

  @override
  String get selfServiceAllEvents => 'All events';

  @override
  String get selfServiceAllKidsSignInOut => 'Sign all children in or out';

  @override
  String get selfServiceAttachment => 'Attachment';

  @override
  String get selfServiceByInstance => 'By instance';

  @override
  String get selfServiceChronological => 'Chronological';

  @override
  String selfServiceDeadline(Object date) {
    return 'Sign-up deadline: $date';
  }

  @override
  String get selfServiceFlutterChild => 'Child';

  @override
  String get selfServiceFlutterNoKids => 'No children found';

  @override
  String get selfServiceFlutterNoKidsHint => 'No children are linked to your\nparent account.';

  @override
  String get selfServiceFlutterNoValidEntries => 'No valid entries found';

  @override
  String selfServiceFlutterSignInUntil(Object date) {
    return 'Sign in until $date';
  }

  @override
  String selfServiceFlutterSwitchFailed(Object error) {
    return 'Error while switching: $error';
  }

  @override
  String get selfServiceLoadingEvents => 'Loading events...';

  @override
  String get selfServiceNoEvents => 'No events found';

  @override
  String get selfServiceNoUpcoming => 'No upcoming events';

  @override
  String get selfServiceParentsThanksLate => 'Thank you for letting us know, and God bless!';

  @override
  String get selfServiceParentsThanksSignout => 'Thank you for letting us know in time, and God bless!';

  @override
  String get selfServiceShalom => 'Shalom!';

  @override
  String get selfServiceShowCurrentSongs => 'Show current pieces';

  @override
  String get selfServiceThanksForSignIn => 'Thanks for signing up 🙂';

  @override
  String selfServiceYouManageKids(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count children',
      one: '$count child',
    );
    return 'You manage $_temp0:';
  }

  @override
  String get settingsAccountsCreated => 'The accounts were created';

  @override
  String get settingsAdHocPlanning => 'Ad-hoc run sheet';

  @override
  String get settingsAddAdmin => 'Add admin';

  @override
  String get settingsAddParent => 'Add parent';

  @override
  String get settingsAddViewer => 'Add observer';

  @override
  String get settingsAdminAdded => 'The admin was added.';

  @override
  String get settingsAdminRemoved => 'The admin was removed.';

  @override
  String get settingsAdmins => 'Administrators';

  @override
  String get settingsAdminsHint => 'Administrators have all rights in the instance and can also delete it.';

  @override
  String get settingsAnalyticsData => 'Analytics & data';

  @override
  String get settingsAnnouncements => 'Announcements';

  @override
  String get settingsAnonymous => 'Anonymous';

  @override
  String get settingsAppStore => 'Download on the App Store';

  @override
  String get settingsArchive => 'Archive';

  @override
  String get settingsAsApp => '📱 Attendix as an app';

  @override
  String get settingsAsAppText => 'Attendix is now available as a native app with push notifications and faster access.';

  @override
  String settingsCalendarMessage(Object link) {
    return 'Copy the following link into your calendar app to subscribe to the events:\n\n$link';
  }

  @override
  String get settingsCannotDeleteTenant => 'You cannot delete this instance.';

  @override
  String get settingsCannotRemoveSelf => 'You cannot remove yourself.';

  @override
  String get settingsCertificates => 'Generate certificates';

  @override
  String get settingsCertificatesFailed => 'Error creating the certificates.';

  @override
  String get settingsCertificatesFor => 'For which groups should certificates be created?';

  @override
  String get settingsChange => 'Change';

  @override
  String get settingsChangePassword => 'Change password';

  @override
  String get settingsCommunication => 'Communication';

  @override
  String get settingsConfigureDashboard => 'Configure dashboard';

  @override
  String get settingsContactOnly => 'Only used to contact you if we have questions';

  @override
  String get settingsContactTelegram => 'Contact via Telegram';

  @override
  String get settingsContinue => 'Continue';

  @override
  String get settingsCopyLink => 'Copy link';

  @override
  String get settingsCreateAccounts => 'Create accounts';

  @override
  String settingsCreateAccountsFailed(Object error) {
    return 'Error creating the accounts: $error';
  }

  @override
  String settingsCreateAccountsMessage(Object names) {
    return 'The following accounts will be created: $names';
  }

  @override
  String get settingsCreateMissing => 'Create missing accounts';

  @override
  String get settingsCreatingCertificates => 'Creating certificates...';

  @override
  String get settingsCurrent => 'Current';

  @override
  String get settingsDeleteAccount => 'Delete account';

  @override
  String get settingsDeleteTenant => 'Delete instance?';

  @override
  String settingsDeleteTenantMessage(Object name) {
    return 'Do you really want to delete the instance “$name”? This cannot be undone! If you really want to delete it, enter the name of the instance:';
  }

  @override
  String get settingsEmailAddress => 'Email address';

  @override
  String get settingsEnableTenantSelect => 'Enable instance selection';

  @override
  String get settingsExport => 'Export';

  @override
  String get settingsExtraFields => 'Additional fields';

  @override
  String settingsFavoriteRemoved(Object name) {
    return 'The instance “$name” was removed from favourites.';
  }

  @override
  String settingsFavoriteSet(Object name) {
    return 'The instance “$name” was set as favourite.';
  }

  @override
  String get settingsFeedback => 'Feedback';

  @override
  String settingsFeedbackFailed(Object error) {
    return 'Error sending the feedback: $error';
  }

  @override
  String get settingsFeedbackPh => 'Enter your feedback...';

  @override
  String get settingsFeedbackSent => 'Your feedback was sent. Thank you!';

  @override
  String get settingsFileStorage => 'File storage';

  @override
  String get settingsFiles => 'Files';

  @override
  String get settingsFlutterAddFailed => 'Error while adding';

  @override
  String get settingsFlutterAdminAddedNotNotified => 'The admin was added but could not be notified.';

  @override
  String get settingsFlutterApplicantText => 'An administrator will review your registration.';

  @override
  String get settingsFlutterApplicantTitle => 'Membership under review';

  @override
  String get settingsFlutterArchiveHint => 'Archived members appear here';

  @override
  String get settingsFlutterBatchAllHaveAccount => 'All players with email already have an account.';

  @override
  String settingsFlutterBatchCreateButton(Object count) {
    return 'Create accounts for $count players';
  }

  @override
  String get settingsFlutterBatchEligible => 'Account can be created (with email)';

  @override
  String settingsFlutterBatchEligibleList(Object count) {
    return 'Players without account ($count)';
  }

  @override
  String settingsFlutterBatchFailed(Object count) {
    return '$count failed';
  }

  @override
  String get settingsFlutterBatchNoEmail => 'Without email (manual)';

  @override
  String settingsFlutterBatchProcessed(Object processed, Object total) {
    return '$processed / $total processed';
  }

  @override
  String settingsFlutterBatchSucceeded(Object count) {
    return '$count succeeded';
  }

  @override
  String get settingsFlutterBatchTitle => 'Create accounts';

  @override
  String get settingsFlutterBatchWithAccount => 'With account';

  @override
  String get settingsFlutterCalendarIntro => 'Copy the following link into your calendar app to subscribe to the events:';

  @override
  String get settingsFlutterChangeEmail => 'Change email';

  @override
  String settingsFlutterChangeEmailFailed(Object error) {
    return 'Error changing the email address: $error';
  }

  @override
  String get settingsFlutterConfirmEmailChange => 'Please confirm the change via the link in the email sent to your new address.';

  @override
  String get settingsFlutterCopyLinkFailed => 'Link could not be copied';

  @override
  String settingsFlutterCreateFailed(Object error) {
    return 'Error while creating: $error';
  }

  @override
  String settingsFlutterCurrentEmail(Object email) {
    return 'Current: $email';
  }

  @override
  String get settingsFlutterEmailRequired => 'Email is required';

  @override
  String settingsFlutterErrorDetail(Object error) {
    return 'Error: $error';
  }

  @override
  String get settingsFlutterFirstNameRequired => 'First name is required';

  @override
  String get settingsFlutterInvalidEmail => 'Please enter a valid email address.';

  @override
  String get settingsFlutterLastNameRequired => 'Last name is required';

  @override
  String settingsFlutterLoadFailed(Object error) {
    return 'Error while loading: $error';
  }

  @override
  String get settingsFlutterNewEmailPh => 'New email address...';

  @override
  String get settingsFlutterNoProfile => 'No profile found';

  @override
  String get settingsFlutterParentRemoved => 'Parent removed';

  @override
  String get settingsFlutterPendingApprove => 'Approve';

  @override
  String settingsFlutterPendingApproveMessage(Object name) {
    return 'Do you want to approve $name as a member?';
  }

  @override
  String get settingsFlutterPendingApproveTitle => 'Approve registration?';

  @override
  String settingsFlutterPendingApproved(Object name) {
    return '$name has been approved';
  }

  @override
  String settingsFlutterPendingDeclineMessage(Object name) {
    return 'Do you want to decline the registration of $name? The entry will be deleted.';
  }

  @override
  String get settingsFlutterPendingDeclineTitle => 'Decline registration?';

  @override
  String get settingsFlutterPendingDeclined => 'Registration declined';

  @override
  String get settingsFlutterPendingEmpty => 'No pending registrations';

  @override
  String get settingsFlutterPendingEmptyHint => 'New registrations appear here automatically';

  @override
  String get settingsFlutterPendingInvalidId => 'Invalid player ID';

  @override
  String get settingsFlutterPwaAndroidStep1 => 'Tap the menu (⋮)';

  @override
  String get settingsFlutterPwaAndroidStep2 => '\"Install app\" or \"Add to Home screen\"';

  @override
  String get settingsFlutterPwaIosStep1 => 'Tap the share icon';

  @override
  String get settingsFlutterPwaIosStep2 => '\"Add to Home Screen\"';

  @override
  String get settingsFlutterPwaIosStep3 => '\"Add\"';

  @override
  String get settingsFlutterPwaText => 'For a better experience you can install this app:';

  @override
  String get settingsFlutterPwaTitle => 'Install app';

  @override
  String settingsFlutterReactivateMessage(Object name) {
    return 'Do you want to reactivate $name?';
  }

  @override
  String settingsFlutterReactivated(Object name) {
    return '$name has been reactivated';
  }

  @override
  String get settingsFlutterSameEmail => 'That is already your email address.';

  @override
  String get settingsFlutterUserMgmtAdd => 'Add user';

  @override
  String get settingsFlutterUserMgmtAddFailed => 'Error adding the user';

  @override
  String get settingsFlutterUserMgmtAdded => 'User added';

  @override
  String get settingsFlutterUserMgmtEmailPh => 'email@example.com';

  @override
  String get settingsFlutterUserMgmtLastAdmin => 'The last administrator cannot be demoted. Please add another admin first.';

  @override
  String get settingsFlutterUserMgmtNoAdmins => 'No administrators';

  @override
  String get settingsFlutterUserMgmtNoAdminsHint => 'Add admins using the + button';

  @override
  String get settingsFlutterUserMgmtNoParents => 'No parents';

  @override
  String get settingsFlutterUserMgmtNoParentsHint => 'Parents can sign their children in and out';

  @override
  String get settingsFlutterUserMgmtNoRole => 'No role';

  @override
  String get settingsFlutterUserMgmtNoUsers => 'No users available';

  @override
  String get settingsFlutterUserMgmtNoViewers => 'No observers';

  @override
  String get settingsFlutterUserMgmtNoViewersHint => 'Observers can view attendance but not edit it';

  @override
  String get settingsFlutterUserMgmtPlayers => 'Players';

  @override
  String get settingsFlutterUserMgmtResponsibles => 'Responsible persons';

  @override
  String get settingsFlutterUserMgmtRoleChangeFailed => 'Error changing the role';

  @override
  String settingsFlutterUserMgmtRoleChanged(Object role) {
    return 'Role changed to $role';
  }

  @override
  String get settingsFlutterUserMgmtSelfDemoteConfirm => 'Yes, change role';

  @override
  String get settingsFlutterUserMgmtSelfDemoteMessage => 'You are about to remove your own admin role. You will lose access to user management. Do you want to continue?';

  @override
  String get settingsFlutterUserMgmtSelfDemoteTitle => 'Change your own role?';

  @override
  String get settingsFlutterUserMgmtTabAdmins => 'Admins';

  @override
  String get settingsFlutterUserMgmtTabAll => 'All users';

  @override
  String get settingsFlutterUserMgmtTitle => 'User management';

  @override
  String get settingsFlutterUsers => 'Users';

  @override
  String get settingsFlutterViewerRemoved => 'Observer removed';

  @override
  String get settingsGenerate => 'Generate';

  @override
  String get settingsGiveFeedback => 'Give feedback';

  @override
  String get settingsGooglePlay => 'Get it on Google Play';

  @override
  String get settingsGroups => 'Groups';

  @override
  String get settingsHelp => 'Help';

  @override
  String get settingsHelpFeedback => 'Help & feedback';

  @override
  String get settingsHelpQuestion => 'Help/question';

  @override
  String get settingsHideCancelled => 'Hide cancelled events';

  @override
  String get settingsImageTooBig => 'The image may be at most 2 MB.';

  @override
  String get settingsInstallUpdate => 'Install update';

  @override
  String get settingsInvite => 'Invite';

  @override
  String get settingsLanguageHint => 'Applies to the app and to push messages, Telegram and emails sent to you.';

  @override
  String get settingsLanguageTitle => 'Language';

  @override
  String settingsLeftOn(Object date) {
    return 'Left: $date';
  }

  @override
  String get settingsLinkCopied => 'The link was copied to the clipboard';

  @override
  String get settingsLogout => 'Log out';

  @override
  String get settingsMessageAll => 'Send a message to everyone';

  @override
  String get settingsMobile => 'Mobile number';

  @override
  String get settingsMyData => 'My details';

  @override
  String get settingsMyVoice => 'My section';

  @override
  String get settingsNew => 'NEW';

  @override
  String get settingsNewPasswordPh => 'Enter new password...';

  @override
  String get settingsNoArchived => 'No archived people';

  @override
  String get settingsNoChurch => 'No church found.';

  @override
  String get settingsNoPersonsInGroups => 'No people found in the selected groups.';

  @override
  String get settingsNotLinked => 'Not linked';

  @override
  String get settingsNotListed => 'Not listed';

  @override
  String get settingsNotifications => 'Notifications';

  @override
  String get settingsOpenGuide => 'Open guide';

  @override
  String get settingsOr => 'or';

  @override
  String get settingsOrganisation => 'Organisation';

  @override
  String get settingsParents => 'Parents';

  @override
  String get settingsParentsHint => 'Parents can see their children\'s attendance and manage absences.';

  @override
  String get settingsPassPhoto => 'Photo';

  @override
  String get settingsPasswordChanged => 'The password was changed';

  @override
  String get settingsPasswordFailed => 'Error changing your password. Please try again later.';

  @override
  String get settingsPasswordTooShort => 'The password must be at least 6 characters long.';

  @override
  String get settingsPasswordsMismatch => 'The passwords do not match.';

  @override
  String settingsPendingCount(Object count) {
    return '$count pending registration(s)';
  }

  @override
  String get settingsPendingPersons => 'Pending people';

  @override
  String get settingsPhonePh => 'Enter mobile number...';

  @override
  String get settingsPhotoChangeFailed => 'Error changing the photo, please try again later';

  @override
  String get settingsPhotoChanged => 'The photo was changed.';

  @override
  String get settingsPhotoRemoveFailed => 'Error removing the photo, please try again later';

  @override
  String get settingsPhotoRemoved => 'The photo was removed';

  @override
  String get settingsPlanning => 'Planning';

  @override
  String get settingsPleaseSelect => 'Please select';

  @override
  String get settingsProfilePicture => 'Profile picture';

  @override
  String get settingsProfileUpdated => 'Your profile was updated.';

  @override
  String settingsQuestionFailed(Object error) {
    return 'Error sending the request: $error';
  }

  @override
  String get settingsQuestionSent => 'Your request was sent. We\'ll get back to you as soon as possible.';

  @override
  String get settingsRatingRequired => 'Please give a rating.';

  @override
  String get settingsRemoveAdmin => 'Remove admin?';

  @override
  String settingsRemoveMessage(Object name) {
    return 'Do you really want to remove $name?';
  }

  @override
  String get settingsRemoveParent => 'Remove parent?';

  @override
  String get settingsRemovePhoto => 'Remove photo';

  @override
  String get settingsRemovePhotoConfirm => 'Do you really want to remove your photo?';

  @override
  String get settingsRemoveViewer => 'Remove observer?';

  @override
  String get settingsRemovingTenant => 'Removing instance...';

  @override
  String get settingsRepeatPasswordPh => 'Repeat password...';

  @override
  String get settingsReplacePhoto => 'Replace photo';

  @override
  String get settingsRolesPerms => 'Roles & permissions';

  @override
  String get settingsRunSheets => 'Run sheets';

  @override
  String get settingsSearchChurch => 'Search church';

  @override
  String get settingsSelectGroups => 'Select groups';

  @override
  String get settingsSelectOneGroup => 'Please select at least one group.';

  @override
  String get settingsSettings => 'Settings';

  @override
  String get settingsSongs => 'Pieces';

  @override
  String get settingsSongsRehearsals => 'Pieces & rehearsals';

  @override
  String get settingsSubmit => 'Submit';

  @override
  String get settingsSubscribeCalendar => 'Subscribe to calendar';

  @override
  String get settingsSwitchTenant => 'Switch instance';

  @override
  String get settingsSystem => 'System';

  @override
  String get settingsTeachers => 'Teachers';

  @override
  String get settingsTemplatesFields => 'Plan templates & fields';

  @override
  String get settingsTenantAdmin => 'Instance management';

  @override
  String get settingsTenantNamePh => 'Enter the instance name...';

  @override
  String get settingsTenantSelectHelper => 'If this option is enabled, you are always asked which instance to open before the app opens.';

  @override
  String settingsTenantsCount(Object count) {
    return 'Instances ($count)';
  }

  @override
  String get settingsUserCreated => 'The user was created.';

  @override
  String get settingsUsersRoles => 'Users & roles';

  @override
  String get settingsViewPhoto => 'View photo';

  @override
  String get settingsViewers => 'Observers';

  @override
  String get settingsViewersHint => 'Observers can only read the attendance overview and person data.';

  @override
  String get settingsVoiceLeader => 'Section leader';

  @override
  String get settingsWaitingApproval => 'People are waiting for approval';

  @override
  String get settingsWhatsNew => 'What\'s new?';

  @override
  String get settingsWrongName => 'The name you entered is not correct.';

  @override
  String get settingsYourFeedback => 'Your feedback';

  @override
  String get settingsYourMobileOptional => 'Your mobile number (optional)';

  @override
  String get settingsYourQuestion => 'Your question';

  @override
  String get settingsYourQuestionPh => 'Enter your question...';

  @override
  String get settingsYourRating => 'Your rating';

  @override
  String get shiftsChooseTarget => 'Choose the instance to copy the shift plan to.';

  @override
  String get shiftsComputed => 'Calculated shifts';

  @override
  String shiftsComputedLine(Object start, Object end, Object hours) {
    return '$start – $end, $hours hours';
  }

  @override
  String shiftsCopied(Object tenant) {
    return 'Shift plan copied to “$tenant”.';
  }

  @override
  String shiftsCopiedAssigned(Object tenant, num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count people',
      one: '$count person',
    );
    return 'Shift plan copied to “$tenant” and assigned to $_temp0.';
  }

  @override
  String shiftsCopiedNoMatch(Object tenant) {
    return 'Shift plan copied to “$tenant”. No matching people found in the target instance.';
  }

  @override
  String get shiftsCopyAssignments => 'Copy assignments?';

  @override
  String shiftsCopyAssignmentsMessage(num count, Object tenant) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count people',
      one: '$count person',
    );
    return 'The shift plan is assigned to $_temp0. Should these assignments be copied to “$tenant” too?';
  }

  @override
  String get shiftsCopyFailed => 'Error copying the shift plan.';

  @override
  String get shiftsCopyFromOther => 'Copy shift plan from another instance';

  @override
  String get shiftsCopyToTenant => 'Copy to instance';

  @override
  String get shiftsCopying => 'Copying shift plan...';

  @override
  String get shiftsCreate => 'Create shift plan';

  @override
  String get shiftsDecimalHelper => 'If the shift length is not a whole number, use a dot for decimals (e.g. 8.5 for 8½ hours).';

  @override
  String get shiftsDefinition => 'Definition';

  @override
  String get shiftsDelete => 'Delete shift plan';

  @override
  String get shiftsDeleteFailed => 'Error deleting the shift plan';

  @override
  String get shiftsDeleteMessage => 'Do you really want to delete the shift plan? All its shifts are deleted too. People assigned to it lose their assignment. This cannot be undone.';

  @override
  String get shiftsDeleted => 'Shift plan deleted';

  @override
  String get shiftsDeleting => 'Deleting shift plan...';

  @override
  String get shiftsDurationHours => 'Duration (in hours)';

  @override
  String get shiftsEdit => 'Edit shift plan';

  @override
  String get shiftsEditIntro => 'Add the shifts the plan consists of here. Each shift corresponds to a day on which a person works a shift. The plan starts over once all shifts have been run through.';

  @override
  String get shiftsEnterName => 'Please enter a name for the shift plan.';

  @override
  String get shiftsExample => 'Example calculation';

  @override
  String get shiftsFixedIntro => 'Define fixed shifts that recur regularly. If none are defined, the start date can be set when assigning the plan to a person.';

  @override
  String get shiftsFixedOptional => 'Fixed shifts (optional)';

  @override
  String get shiftsFlutterAddSegment => 'Add segment';

  @override
  String get shiftsFlutterAddSegmentsHint => 'Add segments to see the preview';

  @override
  String get shiftsFlutterAddShift => 'Add shift';

  @override
  String shiftsFlutterAssigningPeople(Object count) {
    return 'Assigning $count people...';
  }

  @override
  String get shiftsFlutterCopyAssignments => 'Copy assignments';

  @override
  String shiftsFlutterCopyAssignmentsHint(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count people use',
      one: '$count person uses',
    );
    return '$_temp0 this shift plan. Try to assign matching people in the target instance.';
  }

  @override
  String shiftsFlutterCopyFailedWith(Object error) {
    return 'Error while copying: $error';
  }

  @override
  String shiftsFlutterCopyInfo(Object name) {
    return 'The shift plan \"$name\" will be copied to the selected instance. The definition and fixed shifts are included.';
  }

  @override
  String get shiftsFlutterCopyInfoAssignments => 'Assignments are mapped by the people\'s app ID (appId).';

  @override
  String get shiftsFlutterCopyingShort => 'Copying...';

  @override
  String shiftsFlutterCreateFailed(Object error) {
    return 'Error while creating: $error';
  }

  @override
  String shiftsFlutterCreated(Object name) {
    return 'Shift plan \"$name\" created';
  }

  @override
  String get shiftsFlutterCreatingPlan => 'Creating shift plan...';

  @override
  String shiftsFlutterCycle(Object count) {
    return 'Cycle: $count days';
  }

  @override
  String shiftsFlutterCycleDays(Object count) {
    return '$count-day cycle';
  }

  @override
  String shiftsFlutterDayN(Object n) {
    return 'Day $n';
  }

  @override
  String get shiftsFlutterDeleteConfirm => 'Do you really want to delete this shift plan?';

  @override
  String shiftsFlutterDeleteConfirmUsed(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count members use this shift plan.',
      one: '$count member uses this shift plan.',
    );
    return '$_temp0 Do you still want to delete it?';
  }

  @override
  String get shiftsFlutterDescriptionHint => 'e.g. early, late, night';

  @override
  String get shiftsFlutterDurationHint => 'e.g. 8.0';

  @override
  String get shiftsFlutterEditSegment => 'Edit segment';

  @override
  String shiftsFlutterErrorWith(Object error) {
    return 'Error: $error';
  }

  @override
  String get shiftsFlutterFirstSegment => 'First segment';

  @override
  String get shiftsFlutterFixedHint => 'Fixed shifts define concrete start dates for the shift cycle.';

  @override
  String get shiftsFlutterFixedShifts => 'Fixed shifts';

  @override
  String get shiftsFlutterFreeHint => 'Employee is off on this day';

  @override
  String get shiftsFlutterInfoText => 'Shift plans enable automatic excuses based on work shifts. Assign a shift plan to a member to detect conflicts with events automatically.';

  @override
  String get shiftsFlutterInfoTitle => 'Automatic excuses';

  @override
  String get shiftsFlutterLabelHint => 'e.g. early shift';

  @override
  String get shiftsFlutterNameHint => 'e.g. 3-shift system';

  @override
  String shiftsFlutterNext30From(Object date) {
    return 'Next 30 days from $date';
  }

  @override
  String get shiftsFlutterNext30Today => 'Next 30 days from today';

  @override
  String get shiftsFlutterNoDefinition => 'No definition';

  @override
  String get shiftsFlutterNoDefinitionYet => 'No definition yet';

  @override
  String get shiftsFlutterNoFixed => 'No fixed shifts';

  @override
  String get shiftsFlutterNoSegments => 'No shift segments defined';

  @override
  String get shiftsFlutterNotFound => 'Shift plan not found';

  @override
  String get shiftsFlutterNote => 'Note';

  @override
  String get shiftsFlutterOneDay => '1 day';

  @override
  String get shiftsFlutterPlan => 'Shift plan';

  @override
  String get shiftsFlutterPreview => 'Preview';

  @override
  String shiftsFlutterPreviewOf(Object name) {
    return 'Preview: $name';
  }

  @override
  String shiftsFlutterRepeatTimes(Object count) {
    return 'repeat ${count}x';
  }

  @override
  String get shiftsFlutterRepetitionsHint => 'Number of consecutive days';

  @override
  String get shiftsFlutterSearchingPeople => 'Searching matching people in target instance...';

  @override
  String shiftsFlutterSegments(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count segments',
      one: '$count segment',
    );
    return '$_temp0';
  }

  @override
  String shiftsFlutterShiftsCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count shifts',
      one: '$count shift',
    );
    return '$_temp0';
  }

  @override
  String get shiftsFlutterStart => 'Start';

  @override
  String shiftsFlutterStartDateToday(Object date) {
    return 'Start date: today ($date)';
  }

  @override
  String shiftsFlutterStartDateWith(Object date, Object name) {
    return 'Start date: $date ($name)';
  }

  @override
  String get shiftsFlutterTargetTenant => 'Target instance';

  @override
  String shiftsFlutterUsage(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count members use this shift plan',
      one: '$count member uses this shift plan',
    );
    return '$_temp0';
  }

  @override
  String get shiftsFlutterWillCopy => 'Will be copied:';

  @override
  String get shiftsFree => 'Off';

  @override
  String get shiftsImportant => 'IMPORTANT: People\'s attendance is updated whenever new attendance is created and when a shift plan is assigned to a person.';

  @override
  String get shiftsIntro => 'Manage shift plans to automatically excuse people who are unavailable because of shifts. You can create several plans and assign them to people. People are only marked as “excused” if they are assigned to a shift that takes place at the time of the event. The note “Schichtbedingt” (shift-related) is then added automatically.';

  @override
  String get shiftsLabel => 'Label';

  @override
  String get shiftsNoOtherTenants => 'No other instances available.';

  @override
  String get shiftsNoShifts => 'No shifts added.';

  @override
  String get shiftsNone => 'No shift plans.';

  @override
  String get shiftsOnlyPlan => 'Shift plan only';

  @override
  String get shiftsPlans => 'Shift plans';

  @override
  String get shiftsRepetitions => 'Repetitions';

  @override
  String get shiftsRepetitionsHelper => 'Number of repetitions of this shift in the plan.';

  @override
  String get shiftsSaveFailed => 'Error saving the shift plan';

  @override
  String get shiftsSaved => 'Shift plan saved';

  @override
  String shiftsSection(Object n) {
    return 'Section $n';
  }

  @override
  String get shiftsSelectTenant => 'Please select an instance.';

  @override
  String get shiftsStartDate => 'Start date';

  @override
  String get shiftsStartTime => 'Start time';

  @override
  String get shiftsWarning => 'WARNING: Changing the shift definition can lead to inconsistencies. If the plan is already assigned to someone, fixed shifts can no longer be changed or removed! Create a new shift plan instead.';

  @override
  String get shiftsWithAssignments => 'With assignments';

  @override
  String get signoutAbsenceDeleted => 'Absence deleted';

  @override
  String get signoutAbsenceEntered => 'Absence entered';

  @override
  String signoutAbsenceEnteredCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count events',
      one: '$count event',
    );
    return 'Absence entered ($_temp0 excused)';
  }

  @override
  String get signoutAbsenceTileSub => 'absence';

  @override
  String get signoutAbsenceTileTitle => 'Report';

  @override
  String get signoutAccept => 'Accept';

  @override
  String signoutAllCount(Object count) {
    return 'All $count';
  }

  @override
  String get signoutAllDutiesFilled => 'All duties are filled right now. Thank you!';

  @override
  String get signoutAttendance => 'Attendance';

  @override
  String signoutAttendancePercent(Object perc) {
    return '$perc% attendance';
  }

  @override
  String get signoutCannot => 'Can\'t';

  @override
  String get signoutCannotAfterAll => 'Can\'t make it after all';

  @override
  String get signoutChooseEnd => 'Choose end day';

  @override
  String signoutChooseLyricsFor(Object song) {
    return 'Choose lyrics for $song';
  }

  @override
  String signoutChooseScoresFor(Object song) {
    return 'Choose sheet music for $song';
  }

  @override
  String get signoutChooseStart => 'Choose start day';

  @override
  String signoutConductor(Object name) {
    return 'Conductor: $name';
  }

  @override
  String get signoutConfirmPause => 'Confirm pause';

  @override
  String get signoutConfirmed => 'confirmed';

  @override
  String get signoutCurrent => 'Current';

  @override
  String get signoutCurrentSongs => 'Current pieces';

  @override
  String signoutDeadline(Object date) {
    return 'Sign-up deadline: $date';
  }

  @override
  String get signoutDeadlinePassed => 'Sign-up deadline has passed';

  @override
  String get signoutDecline => 'Decline';

  @override
  String get signoutDeleteAbsence => 'Delete absence';

  @override
  String get signoutDeleteAbsenceMessage => 'Delete this absence? Events in this period that were already excused will be reset to the default status of their event type.';

  @override
  String get signoutDescription => 'Description';

  @override
  String get signoutDownloadRecording => 'Download recording';

  @override
  String get signoutDownloadScores => 'Download sheet music';

  @override
  String signoutDutiesThisMonth(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'duties',
      one: 'duty',
    );
    return '$_temp0 this month';
  }

  @override
  String get signoutDuty => 'Duty';

  @override
  String get signoutDutyConfirmed => 'Thanks, your duty is confirmed 🙂';

  @override
  String get signoutDutyFull => 'Someone was faster, the duty is already full.';

  @override
  String get signoutDutyNotAllowed => 'You cannot take this duty.';

  @override
  String signoutDutyOccupied(Object occupied, Object required) {
    return '$occupied of $required filled';
  }

  @override
  String get signoutDutySignedUp => 'Thanks, you\'re signed up 🙂';

  @override
  String get signoutEditNote => 'Edit note';

  @override
  String get signoutEditRegistrationFields => 'Edit sign-up fields';

  @override
  String get signoutEndPause => 'End pause';

  @override
  String get signoutEndPauseMessage => 'Do you really want to end your pause and become active again?';

  @override
  String get signoutEnterAbsence => 'Enter absence';

  @override
  String get signoutEnterLate => 'Report late arrival';

  @override
  String get signoutEnterNote => 'Enter your note here';

  @override
  String get signoutFiles => 'Files';

  @override
  String signoutFillField(Object field) {
    return 'Please fill in \"$field\"';
  }

  @override
  String get signoutFillRequired => 'Please fill in all required fields';

  @override
  String get signoutFlutterAbsenceSaveFailed => 'Absence could not be saved';

  @override
  String signoutFlutterError(Object error) {
    return 'Error: $error';
  }

  @override
  String signoutFlutterEventsCount(Object count) {
    return '$count events';
  }

  @override
  String get signoutFlutterFieldsSaveFailed => 'Registration fields could not be saved.';

  @override
  String get signoutFlutterFileDownloadFailed => 'File could not be downloaded';

  @override
  String get signoutFlutterFileOpenFailed => 'File could not be opened';

  @override
  String signoutFlutterFilesSkipped(Object count) {
    return '$count file(s) could not be included.';
  }

  @override
  String get signoutFlutterLinkOpenFailed => 'Link could not be opened';

  @override
  String get signoutFlutterNoCurrentSongs => 'No current pieces';

  @override
  String get signoutFlutterNoPerson => 'No person was found for your account in this instance.';

  @override
  String get signoutFlutterNoPrintableScores => 'No printable scores found.';

  @override
  String get signoutFlutterNoteSaveFailed => 'Note could not be saved.';

  @override
  String get signoutFlutterPrintAllScores => 'Print all scores';

  @override
  String signoutFlutterShowAll(Object count) {
    return 'Show all $count';
  }

  @override
  String get signoutFlutterShowLess => 'Show less';

  @override
  String get signoutFlutterSigninFailed => 'Sign-in failed. Please try again.';

  @override
  String get signoutFlutterSignoutFailed => 'Sign-out failed. Please try again.';

  @override
  String get signoutFlutterSwitchTenantFailed => 'Could not switch instance';

  @override
  String get signoutGiveReason => 'Please give a reason!';

  @override
  String get signoutGladYouCome => 'Great that you\'re coming 🙂';

  @override
  String signoutGreeting(Object name) {
    return 'Shalom $name!';
  }

  @override
  String get signoutIllTakeIt => 'I\'ll take it';

  @override
  String get signoutInfos => 'Info';

  @override
  String get signoutLastEventsStatus => 'Status of the last events';

  @override
  String get signoutLateButton => 'Late';

  @override
  String signoutLateCount(Object count) {
    return '$count× late';
  }

  @override
  String get signoutLegend => 'Legend';

  @override
  String get signoutLegendAccepted => 'Accepted';

  @override
  String get signoutLegendAcceptedPresent => 'Accepted / present';

  @override
  String get signoutLegendLate => 'Late';

  @override
  String get signoutLegendLateReported => 'Late arrival reported';

  @override
  String get signoutLegendLateReportedExcused => 'Late arrival reported (excused)';

  @override
  String get signoutListenRecording => 'Listen to recording';

  @override
  String get signoutLongAbsenceHint => 'For longer absences, use the pause function so you do not appear in new events.';

  @override
  String get signoutMoreEvents => 'More events';

  @override
  String get signoutMoreOptions => 'More options';

  @override
  String get signoutMyDuties => 'My duties';

  @override
  String get signoutNextDuty => 'Next duty';

  @override
  String get signoutNoActions => 'No actions are available for this event.';

  @override
  String get signoutNoEndDate => 'No end date selected';

  @override
  String get signoutNoScoresForInstrument => 'Unfortunately there is no sheet music for your instrument.';

  @override
  String get signoutNoScoresFound => 'No sheet music found for your instrument.';

  @override
  String get signoutNoSongActions => 'No actions are available for this piece.';

  @override
  String signoutNoteChip(Object note) {
    return 'Note: $note';
  }

  @override
  String get signoutNoteForSignin => 'Note for your sign-up';

  @override
  String get signoutNoteUpdated => 'Note updated.';

  @override
  String get signoutOpenAttachment => 'Open attachment';

  @override
  String get signoutOpenDuties => 'Open duties';

  @override
  String get signoutOpenFiles => 'Open file storage';

  @override
  String get signoutOpenInTeam => 'open in the team';

  @override
  String get signoutOpenNavigation => 'Open navigation';

  @override
  String get signoutOpenScoreLink => 'Open sheet music link';

  @override
  String get signoutPast => 'Past';

  @override
  String get signoutPause => 'Pause';

  @override
  String get signoutPauseReasonPlaceholder => 'Why do you want to pause?';

  @override
  String get signoutPaused => 'Paused';

  @override
  String get signoutPausedUntil => 'Paused until (optional)';

  @override
  String get signoutPlannedAbsences => 'Planned absences';

  @override
  String get signoutPleaseConfirm => 'Please confirm';

  @override
  String get signoutPrintScores => 'Print sheet music';

  @override
  String signoutPrintScoresFor(Object song) {
    return 'Print sheet music for $song';
  }

  @override
  String get signoutReactivate => 'Reactivate';

  @override
  String get signoutReasonPlaceholder => 'e.g. holiday, illness...';

  @override
  String get signoutReasonRequired => 'Reason *';

  @override
  String get signoutRegistrationFieldsSaved => 'Sign-up fields saved.';

  @override
  String get signoutRegistrationSubmitted => 'Your registration has been submitted. You will be notified as soon as it has been processed.';

  @override
  String get signoutRegularlyUnavailable => 'Regularly unavailable';

  @override
  String get signoutRegularlyUnavailableHint => 'e.g. every Wednesday because of children\'s church';

  @override
  String get signoutReportAbsence => 'Report absence';

  @override
  String get signoutRoute => 'Route';

  @override
  String get signoutRunSheet => 'Run sheet';

  @override
  String get signoutShowDescription => 'Show description';

  @override
  String get signoutShowRunSheet => 'Show run sheet';

  @override
  String get signoutShowScores => 'Show sheet music';

  @override
  String get signoutSignIn => 'Sign up';

  @override
  String get signoutSignInWithNote => 'Sign up with note';

  @override
  String get signoutSignOut => 'Can\'t attend';

  @override
  String get signoutThanksLate => 'Thank you for letting us know, and God bless you!';

  @override
  String get signoutThanksSignout => 'Thank you for letting us know in time, and God bless you.';

  @override
  String get signoutToConfirm => 'to confirm';

  @override
  String get signoutUndoSignout => 'Undo absence';

  @override
  String get signoutUpcoming => 'Upcoming';

  @override
  String get signoutUrgent => 'Urgent';

  @override
  String get signoutViewLyrics => 'View lyrics';

  @override
  String signoutWithTeam(Object names) {
    return ' · with $names';
  }

  @override
  String get signoutYou => 'You';

  @override
  String get signoutYouAreAssigned => 'You are assigned';

  @override
  String get signoutYourDutyRoster => 'Your duty roster';

  @override
  String get songsAddCategory => 'Add category';

  @override
  String get songsAddSong => 'Add piece';

  @override
  String get songsAddWithoutReplace => 'Add without replacing';

  @override
  String get songsAllSongs => 'All pieces';

  @override
  String get songsCatalogPdf => 'Catalog of pieces as PDF';

  @override
  String songsCatalogTitle(Object tenant) {
    return '$tenant catalog of pieces';
  }

  @override
  String get songsCategories => 'Categories';

  @override
  String get songsCategoryAdded => 'Category added';

  @override
  String get songsCategoryDeleted => 'Category deleted';

  @override
  String get songsCategoryName => 'Category name';

  @override
  String get songsCategoryNameEmpty => 'The category name can\'t be empty';

  @override
  String get songsCategorySaved => 'Category saved';

  @override
  String get songsChangeCategory => 'Change category';

  @override
  String get songsChoir => 'Choir';

  @override
  String get songsChoirOrchShort => 'Choir/orch.';

  @override
  String get songsChoirOrchestra => 'Choir & orchestra';

  @override
  String get songsChooseGroup => 'Choose group';

  @override
  String get songsChooseGroupPlease => 'Please choose a group.';

  @override
  String get songsChooseGroups => 'Choose groups';

  @override
  String get songsConductors => 'Conductors';

  @override
  String get songsCopied => 'Piece copied';

  @override
  String get songsCopiesPerGroup => 'How many copies per group?';

  @override
  String get songsCopy => 'Copy';

  @override
  String songsCopyFailed(Object error) {
    return 'Could not copy the piece: $error';
  }

  @override
  String songsCopyInfo(Object name) {
    return 'The piece \"$name\" is copied to the selected instance. All files are copied too. The category is not taken over. Instrument assignments are mapped automatically by name.';
  }

  @override
  String get songsCopyLink => 'Copy link';

  @override
  String get songsCopySong => 'Copy piece';

  @override
  String get songsCopyToOther => 'Copy piece to another instance';

  @override
  String get songsCopying => 'Copying piece...';

  @override
  String songsCopyingFile(Object current, Object total) {
    return 'Copying file $current of $total...';
  }

  @override
  String get songsCreatingPdf => 'Creating PDF...';

  @override
  String get songsCurrent => 'Current pieces';

  @override
  String get songsDeleteAll => 'Delete all files';

  @override
  String get songsDeleteAllConfirm => 'Do you really want to delete all files of this piece?';

  @override
  String get songsDeleteCategory => 'Delete category';

  @override
  String get songsDeleteCategoryMessage => 'Do you really want to delete this category? Pieces in it will not be assigned to a new category.';

  @override
  String get songsDeleteConfirm => 'Really delete the piece?';

  @override
  String get songsDeleteFile => 'Delete file';

  @override
  String songsDeleteFileConfirm(Object name) {
    return 'Do you really want to delete the file \"$name\"?';
  }

  @override
  String get songsDeleteSong => 'Delete piece';

  @override
  String songsDeleteSyncedMessage(Object names) {
    return 'The pieces are shared with $names. The piece will be deleted there too, including the history of all instances involved. Really delete the piece?';
  }

  @override
  String get songsDeleting => 'Deleting piece...';

  @override
  String get songsDeletingFiles => 'Deleting files...';

  @override
  String get songsDifficulty => 'Difficulty';

  @override
  String get songsDifficulty123 => 'Difficulty (1/2/3)';

  @override
  String get songsDifficultyShort => 'Difficulty';

  @override
  String get songsDontClose => 'Please do not close the window until the upload is finished.';

  @override
  String get songsDownloadAll => 'Download all files';

  @override
  String get songsDownloadFile => 'Download file';

  @override
  String get songsDownloadRecording => 'Download recording';

  @override
  String get songsDownloadingFiles => 'Downloading files...';

  @override
  String get songsDropHere => 'Drag files here or tap to choose';

  @override
  String get songsEasy => '1 - Easy';

  @override
  String get songsEditCategory => 'Edit category';

  @override
  String get songsEditSong => 'Edit piece';

  @override
  String get songsEnterCategory => 'Enter category...';

  @override
  String get songsEvery2 => 'Every 2nd person';

  @override
  String get songsEvery3 => 'Every 3rd person';

  @override
  String get songsEvery4 => 'Every 4th person';

  @override
  String get songsFileActions => 'File actions';

  @override
  String songsFileTooLarge(Object name) {
    return 'The file $name exceeds the maximum size of 20 MB.';
  }

  @override
  String get songsFiles => 'Files';

  @override
  String songsFlutterCopiesCount(Object count) {
    return '$count copies';
  }

  @override
  String get songsFlutterCopiesPerInstrument => 'Copies per instrument:';

  @override
  String get songsFlutterCreateFailed => 'Song could not be created';

  @override
  String get songsFlutterCreatingInTarget => 'Creating song in target instance...';

  @override
  String get songsFlutterDeleteFailed => 'Song could not be deleted';

  @override
  String get songsFlutterDetectNone => 'Not recognised – please assign';

  @override
  String get songsFlutterDetectUnsure => 'Unsure – please check';

  @override
  String get songsFlutterDownloadFileFailed => 'File could not be downloaded';

  @override
  String songsFlutterErrorWith(Object error) {
    return 'Error: $error';
  }

  @override
  String songsFlutterFileDownloadFailed(Object name) {
    return 'File could not be downloaded: $name';
  }

  @override
  String songsFlutterFilesSkipped(Object count) {
    return '$count file(s) could not be included.';
  }

  @override
  String songsFlutterFilesWillBeCopied(Object count) {
    return '$count files will be copied:';
  }

  @override
  String get songsFlutterFilterAndView => 'Filter & view';

  @override
  String get songsFlutterFirstPage => 'First page';

  @override
  String get songsFlutterFullscreen => 'Full screen';

  @override
  String get songsFlutterHideTab => 'Hide tab';

  @override
  String get songsFlutterInvalidId => 'Invalid song ID';

  @override
  String get songsFlutterLastPage => 'Last page';

  @override
  String get songsFlutterLearnFailed => 'The terms could not be saved';

  @override
  String songsFlutterLearnTerm(Object term, Object group) {
    return 'Recognise “$term” as $group from now on';
  }

  @override
  String songsFlutterListAnd(Object rest, Object last) {
    return '$rest and $last';
  }

  @override
  String get songsFlutterLoadingTargetGroups => 'Loading target groups...';

  @override
  String get songsFlutterMenu => 'Menu';

  @override
  String get songsFlutterNextPage => 'Next page';

  @override
  String get songsFlutterNoPlayers => 'No players found';

  @override
  String get songsFlutterNoSongs => 'No songs available';

  @override
  String get songsFlutterNotFound => 'Song not found';

  @override
  String get songsFlutterOneEach => '1 each';

  @override
  String get songsFlutterOpenFileFailed => 'Could not open file';

  @override
  String songsFlutterPdfCreateFailed(Object error) {
    return 'Error while creating the PDF: $error';
  }

  @override
  String get songsFlutterPdfLoadFailed => 'PDF could not be loaded';

  @override
  String get songsFlutterPdfLoading => 'Loading PDF...';

  @override
  String get songsFlutterPdfPagedMode => 'Turn page by page';

  @override
  String get songsFlutterPdfScrollMode => 'Scroll continuously';

  @override
  String get songsFlutterPreviousPage => 'Previous page';

  @override
  String songsFlutterPrintFailed(Object error) {
    return 'Error while printing: $error';
  }

  @override
  String get songsFlutterPrintFileFailed => 'File could not be printed';

  @override
  String get songsFlutterPrintJobSent => 'Print job sent';

  @override
  String get songsFlutterPrinting => 'Printing...';

  @override
  String get songsFlutterReorderCategoriesHint => 'Drag categories to reorder them';

  @override
  String get songsFlutterReviewHint => 'The part of these files is not clear. Please check the assignment before uploading.';

  @override
  String get songsFlutterReviewTitle => 'Check parts';

  @override
  String get songsFlutterReviewUpload => 'Upload';

  @override
  String get songsFlutterShowAsTab => 'Show as tab';

  @override
  String get songsFlutterSong => 'Song';

  @override
  String get songsFlutterTelegramSent => 'File sent via Telegram';

  @override
  String songsFlutterUploadFailedWith(Object error) {
    return 'Error while uploading: $error';
  }

  @override
  String get songsFlutterVisionReading => 'Reading the first page …';

  @override
  String songsFlutterVisionSure(Object label) {
    return 'Recognised on page 1: $label';
  }

  @override
  String get songsFlutterVisionUnsure => 'Guessed from page 1 – please check';

  @override
  String get songsFreeText => 'Free text';

  @override
  String get songsGroup => 'Group';

  @override
  String get songsGroupDirectory => 'Group directory';

  @override
  String get songsHard => '3 - Hard';

  @override
  String songsHistoryCount(Object count) {
    return 'History (${count}x)';
  }

  @override
  String get songsImportIntro => 'Import pieces from an Excel (.xlsx/.xls) or CSV file. The first row must contain column headers. The easiest way is to download the template and fill it in.';

  @override
  String get songsImportSongs => 'Import pieces';

  @override
  String get songsImportantInfo => 'Important info';

  @override
  String songsImportedCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pieces imported.',
      one: '$count piece imported.',
    );
    return '$_temp0';
  }

  @override
  String get songsInstrument => 'Instrument';

  @override
  String get songsInstrumentation => 'Instrumentation';

  @override
  String get songsInvalidLink => 'The link is not valid';

  @override
  String get songsInvalidShareLink => 'Invalid share link.';

  @override
  String get songsLastPlayed => 'Last played';

  @override
  String songsLastPlayedOn(Object date, Object conductor) {
    return 'Last played on $date | $conductor';
  }

  @override
  String get songsLastSung => 'Last sung';

  @override
  String songsLastSungOn(Object date, Object conductor) {
    return 'Last sung on $date | $conductor';
  }

  @override
  String get songsLink => 'Link';

  @override
  String get songsLinkCopied => 'The link was copied to the clipboard';

  @override
  String get songsLyrics => 'Lyrics';

  @override
  String get songsLyricsWarning => 'Warning: lyrics format';

  @override
  String songsLyricsWarningMessage(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files were',
      one: '$count file was',
    );
    String _temp1 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'are not PDFs',
      one: 'is not a PDF',
    );
    return '$_temp0 categorized as \"Lyrics\" but $_temp1. Players and singers therefore can\'t see them in their overview of current pieces.';
  }

  @override
  String get songsMapNumberName => 'Please map columns for number and name.';

  @override
  String get songsMappingIntro => 'Map the columns of your file to the piece fields. Number and name are required.';

  @override
  String get songsMedium => '2 - Medium';

  @override
  String get songsMissingInstruments => 'Missing instruments';

  @override
  String get songsName => 'Name';

  @override
  String get songsNameAsc => 'Name ↑';

  @override
  String get songsNameDesc => 'Name ↓';

  @override
  String get songsNoCategories => 'No categories have been created yet.';

  @override
  String get songsNoCategory => 'No category';

  @override
  String get songsNoFiles => 'No files yet.';

  @override
  String get songsNoGroupPdfs => 'No group PDFs found to print';

  @override
  String get songsNoGroupsWithPeople => 'No groups with assigned people found';

  @override
  String get songsNoScoresCurrent => 'No scores found for this group in the current pieces.';

  @override
  String get songsNoScoresGroup => 'No scores for this group.';

  @override
  String get songsNotDefined => 'Not defined';

  @override
  String get songsNotImported => 'Pieces not imported';

  @override
  String get songsNotPlayedYet => 'Not played yet · ';

  @override
  String get songsNotSungYet => 'Not sung yet · ';

  @override
  String get songsNothingToImport => 'No pieces to import.';

  @override
  String get songsNumber => 'Number';

  @override
  String get songsNumberAsc => 'Number ↑';

  @override
  String get songsNumberDesc => 'Number ↓';

  @override
  String get songsNumberShort => 'No.';

  @override
  String get songsNumberTaken => 'This number is already taken';

  @override
  String get songsOnlyGroupsWithFiles => 'Only groups with files are shown.';

  @override
  String get songsOpenExternalLink => 'Open external score link';

  @override
  String get songsOpenFile => 'Open file';

  @override
  String get songsOrchestra => 'Orchestra';

  @override
  String get songsOther => 'Other';

  @override
  String get songsOtherFreeText => 'Other (free text)';

  @override
  String get songsPerGroup => '1 per group';

  @override
  String get songsPerPerson => 'Everyone (1 per person)';

  @override
  String songsPlannedOn(Object date) {
    return 'Planned on $date';
  }

  @override
  String get songsPlayRecording => 'Play recording';

  @override
  String get songsPrefix => 'Prefix';

  @override
  String get songsPrefixHelper => 'E.g. to mark Christmas songs (e.g. C for Christmas -> C1)';

  @override
  String get songsPrefixOptional => 'Prefix (optional)';

  @override
  String get songsPrint => 'Print';

  @override
  String get songsPrintFile => 'Print file';

  @override
  String get songsPrintGroupPdfs => 'Print group PDFs';

  @override
  String get songsPrintOptions => 'Print options';

  @override
  String songsPrintPrepared(Object summary) {
    return 'Print prepared: $summary';
  }

  @override
  String get songsPrintScores => 'Print scores';

  @override
  String get songsRecording => 'Recording';

  @override
  String get songsReplaceAndAdd => 'Replace & add';

  @override
  String songsReplaces(Object name) {
    return 'Replaces: $name';
  }

  @override
  String get songsSendTelegram => 'Send via Telegram';

  @override
  String get songsSendingFile => 'Sending file...';

  @override
  String get songsShowCurrent => 'Show current pieces';

  @override
  String get songsSolo => 'Solo';

  @override
  String get songsSongCategories => 'Piece categories';

  @override
  String songsSongsCount(Object count) {
    return 'Pieces ($count)';
  }

  @override
  String get songsSourceInstance => 'the source instance';

  @override
  String get songsUnknownCategory => 'Unknown category';

  @override
  String get songsUpload => 'Upload';

  @override
  String get songsUploadAnyway => 'Upload anyway';

  @override
  String songsUploadDone(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files uploaded.',
      one: '$count file uploaded.',
    );
    return '$_temp0';
  }

  @override
  String get songsUploadFile => 'Upload file';

  @override
  String get songsUploadFiles => 'Upload files';

  @override
  String get songsUploadInfo => '- The instrumentation is updated automatically from the selected instruments after uploading.<br>- Add synonyms to the instruments (<a href=\"/tabs/settings/instruments\">group settings</a>) to improve automatic file matching.<br>- Uploading several files can take a while depending on file size and connection. Please do not close the window until the upload is finished.';

  @override
  String songsUploadPartialFail(Object failed, Object total) {
    return '$failed of $total file(s) could not be uploaded.';
  }

  @override
  String songsUploadProgress(Object done, Object total) {
    return '$done of $total files uploaded';
  }

  @override
  String get songsUploading => 'Uploading file...';

  @override
  String get songsWhichReplace => 'Which files should be replaced?';

  @override
  String get songsWithSolo => 'With solo';

  @override
  String get songsWithSoloSinging => 'With solo singing';

  @override
  String get statsActiveMembers => 'Active members';

  @override
  String get statsAgeChart => 'Age distribution 🎂';

  @override
  String get statsAgeDistribution => '🎂 Age distribution';

  @override
  String statsAllCount(Object count) {
    return 'All ($count)';
  }

  @override
  String get statsAttendancePercent => 'Attendance %';

  @override
  String get statsAvgAgeChart => 'Average age per instrument';

  @override
  String get statsAvgAgeInstrument => '📊 Average age per instrument';

  @override
  String get statsAvgAttendance => 'Ø attendance';

  @override
  String get statsBest => 'Best attendance';

  @override
  String get statsCount => 'Count';

  @override
  String get statsEventsInPeriod => 'Events in period';

  @override
  String get statsFilterTenants => 'Filter instances';

  @override
  String statsFlutterAbsencesCount(Object count) {
    return '$count absences';
  }

  @override
  String get statsFlutterNoBirthdays => 'No birthdays available';

  @override
  String get statsFlutterNoData => 'No data available';

  @override
  String get statsFlutterNoDataInPeriod => 'No data in the selected period';

  @override
  String get statsFlutterNoUnexcused => 'No unexcused absences';

  @override
  String statsFlutterOrganisation(Object name) {
    return 'Organisation: $name';
  }

  @override
  String statsFlutterSelectedOf(Object selected, Object total) {
    return '$selected of $total selected';
  }

  @override
  String statsFlutterTenantsCount(Object count) {
    return '$count instances';
  }

  @override
  String get statsHistoryChart => 'Attendance history (last 20 events)';

  @override
  String get statsInstrumentChart => 'Attendance rate by instrument';

  @override
  String get statsLeft => 'Left';

  @override
  String get statsMembers => '👥 Members';

  @override
  String get statsOrgTenants => 'Instances of the organisation';

  @override
  String get statsOverview => '📊 Attendance overview';

  @override
  String get statsPausing => 'Paused';

  @override
  String get statsPerInstrument => '🎻 Attendance per instrument';

  @override
  String get statsPeriod => '📅 Period';

  @override
  String get statsPersonCount => 'Number of people';

  @override
  String get statsPersonsAllTenants => 'People across all instances';

  @override
  String statsPersonsCount(Object count) {
    return 'People ($count)';
  }

  @override
  String statsPieLabel(Object label, Object perc) {
    return '$label ($perc%)';
  }

  @override
  String get statsStatusChart => 'Status distribution (in %)';

  @override
  String get statsStatusDistribution => '📉 Status distribution';

  @override
  String get statsTenants => 'Instances';

  @override
  String get statsTitle => 'Statistics';

  @override
  String get statsTop20 => '🏆 Top 20 attendance';

  @override
  String get statsTop20Chart => 'Top 20 – attendance elite 🏆';

  @override
  String get statsTrend => '📈 Attendance trend';

  @override
  String get statsUnexcused => '⚠️ Unexcused absences';

  @override
  String get statsUnexcusedAbsences => 'Unexcused absences';

  @override
  String get statsUnexcusedChart => 'Unexcused absences';

  @override
  String get statsWorst => 'Lowest attendance';

  @override
  String get statsYears => 'Years';

  @override
  String get svcActivate => 'Activate';

  @override
  String get svcAddAttendanceFailed => 'Could not add the event';

  @override
  String get svcAddCategoryFailed => 'Could not add the category';

  @override
  String get svcAddGroupCategoryFailed => 'Could not add the group category';

  @override
  String get svcAddPersonAttendancesFailed => 'Could not add the attendance entries';

  @override
  String get svcAddShiftFailed => 'Could not add the shift';

  @override
  String get svcAddSongCategoryFailed => 'Could not add the piece category';

  @override
  String get svcAddSongHistoryFailed => 'Could not add the songs to the history';

  @override
  String get svcAddTypeFailed => 'Could not add the event type';

  @override
  String get svcAddUserToTenantFailed => 'Could not add the user to the instance';

  @override
  String get svcApplyToPlannedFailed => 'Could not apply to planned events';

  @override
  String get svcAssignFailed => 'Could not assign';

  @override
  String get svcCheckShiftUsageFailed => 'Could not check where the shift is used';

  @override
  String get svcCleanupAttendancesFailed => 'Could not clean up the attendance entries';

  @override
  String get svcConfirmFailed => 'Could not confirm';

  @override
  String get svcCreateChurchFailed => 'Could not create the church';

  @override
  String get svcCreateOrgFailed => 'Could not create the organisation';

  @override
  String get svcCreatePublicLinkFailed => 'Could not create the public link';

  @override
  String get svcCreateTenantFailed => 'Could not create the instance';

  @override
  String get svcDeleteAbsenceFailed => 'Could not delete the absence';

  @override
  String get svcDeleteCategoryFailed => 'Could not delete the category';

  @override
  String get svcDeleteChurchFailed => 'Could not delete the church';

  @override
  String get svcDeleteEntryFailed => 'Could not delete the entry';

  @override
  String get svcDeleteFailed => 'Could not delete';

  @override
  String get svcDeletePersonAttendanceFailed => 'Could not delete the attendance entry';

  @override
  String get svcDeletePersonAttendancesFailed => 'Could not delete the attendance entries';

  @override
  String get svcDeleteSharedFieldValuesFailed => 'Could not delete the shared extra field values';

  @override
  String get svcDeleteShiftFailed => 'Could not delete the shift';

  @override
  String get svcDeleteSongFailed => 'Could not delete the piece';

  @override
  String get svcDeleteTenantFailed => 'Could not delete the instance';

  @override
  String get svcDeleteTypeFailed => 'Could not delete the event type';

  @override
  String get svcFileLoading => 'Loading file...';

  @override
  String get svcFolderIntoItself => 'A folder cannot be moved into itself.';

  @override
  String get svcInvalidFileName => 'Invalid file name.';

  @override
  String get svcInvalidFolderName => 'Invalid folder name.';

  @override
  String get svcInvalidName => 'Invalid name.';

  @override
  String get svcLater => 'Later';

  @override
  String get svcLinkFailed => 'Linking failed';

  @override
  String get svcLinkOrgFailed => 'Could not link the organisation';

  @override
  String get svcLinkPeopleFailed => 'Could not link the people';

  @override
  String get svcLoadAbsencesFailed => 'Could not load the absences';

  @override
  String get svcLoadAdminsFailed => 'Could not load the admins';

  @override
  String get svcLoadAttendancesFailed => 'Could not load the events';

  @override
  String get svcLoadAvailabilityFailed => 'Could not load the availability';

  @override
  String get svcLoadCategoriesFailed => 'Could not load the categories';

  @override
  String get svcLoadChurchesFailed => 'Could not load the churches';

  @override
  String get svcLoadGroupMembersFailed => 'Could not load the group members';

  @override
  String get svcLoadMainGroupPeopleFailed => 'Could not load the main group members';

  @override
  String get svcLoadOrgFailed => 'Could not load the organisation';

  @override
  String get svcLoadOrgPlansFailed => 'Could not load the organisation plans';

  @override
  String get svcLoadOrgsFailed => 'Could not load the organisations';

  @override
  String get svcLoadParentsFailed => 'Could not load the parents';

  @override
  String get svcLoadPersonAttendancesFailed => 'Could not load the attendance entries';

  @override
  String get svcLoadPlayersFailed => 'Could not load the members';

  @override
  String get svcLoadRolePermissionsFailed => 'Could not load the role permissions';

  @override
  String get svcLoadSharedFieldsFailed => 'Could not load the shared extra fields';

  @override
  String get svcLoadShiftPeopleFailed => 'Could not load the people with shifts';

  @override
  String get svcLoadShiftsFailed => 'Could not load the shifts';

  @override
  String get svcLoadTenantFailed => 'Could not load the instance';

  @override
  String get svcLoadTenantFailed2 => 'Could not load the instance';

  @override
  String get svcLoadTypesFailed => 'Could not load the event types';

  @override
  String get svcLoadUsersFailed => 'Could not load the users';

  @override
  String get svcLoadViewersFailed => 'Could not load the observers';

  @override
  String get svcMergeScoresFailed => 'Could not merge the sheet music.';

  @override
  String get svcMergingPdfs => 'Merging PDFs...';

  @override
  String get svcMessageSent => 'Message sent successfully!';

  @override
  String get svcNoDeletePermission => 'No permission to delete';

  @override
  String get svcNoPlayerFound => 'No person could be found.';

  @override
  String get svcNoPrintableScores => 'No printable sheet music (PDF/image) found.';

  @override
  String get svcNotification => 'Notification';

  @override
  String get svcOfflineSaved => 'Offline changes saved';

  @override
  String get svcOnlyOneMainGroup => 'There can only be one main group';

  @override
  String get svcOrgNotFound => 'Organisation not found';

  @override
  String get svcPdfDownloaded => 'PDF downloaded – please print it manually';

  @override
  String get svcPushPrompt => 'Do you want to turn on push notifications? You will be informed about events, checklists and important updates.';

  @override
  String get svcPushTitle => 'Push notifications';

  @override
  String get svcRemoveOrgFailed => 'Could not remove the organisation';

  @override
  String get svcRenameOrgFailed => 'Could not rename the organisation';

  @override
  String get svcRevokePublicLinkFailed => 'Could not revoke the public link';

  @override
  String get svcSaveAbsenceFailed => 'Could not save the absence';

  @override
  String get svcSaveBrandingFailed => 'Could not save the branding';

  @override
  String get svcSaveDefaultFieldsFailed => 'Could not save the default fields';

  @override
  String get svcSaveFailed => 'Could not save';

  @override
  String get svcSaveOrgFieldsFailed => 'Could not save the organisation extra fields';

  @override
  String get svcSavePlanTemplatesFailed => 'Could not save the plan templates';

  @override
  String get svcSaveSharedFieldsFailed => 'Could not save the shared extra fields';

  @override
  String get svcScores => 'Sheet music';

  @override
  String get svcSearchTargetPeopleFailed => 'Could not search the people in the target instance';

  @override
  String get svcSendFeedbackFailed => 'Could not send the feedback';

  @override
  String get svcSendMessageFailed => 'Could not send the message, please try again later!';

  @override
  String get svcSendQuestionFailed => 'Could not send the question';

  @override
  String get svcShow => 'Show';

  @override
  String get svcSignUpFailed => 'Could not sign up';

  @override
  String get svcSignedUrlFailed => 'Could not create a signed URL.';

  @override
  String get svcTransferAbsencesFailed => 'Could not transfer the absences';

  @override
  String get svcTransferPersonAttendancesFailed => 'Could not transfer the attendance entries';

  @override
  String get svcUnassignFailed => 'Could not remove';

  @override
  String get svcUpdateAttendanceFailed => 'Could not update the attendance';

  @override
  String get svcUpdateCategoryFailed => 'Could not update the category';

  @override
  String get svcUpdateCategoryOrderFailed => 'Could not update the category order';

  @override
  String get svcUpdateChurchFailed => 'Could not update the church';

  @override
  String get svcUpdateConfigFailed => 'Could not update the configuration, please try again later.';

  @override
  String get svcUpdateEntryFailed => 'Could not update the entry';

  @override
  String get svcUpdateExtraFieldsFailed => 'Could not update the extra fields';

  @override
  String get svcUpdateFieldFailed => 'Could not update the field';

  @override
  String get svcUpdateGroupFailed => 'Could not update the group';

  @override
  String get svcUpdateRolePermissionFailed => 'Could not update the role permission';

  @override
  String get svcUpdateSettingsFailed => 'Could not update the settings';

  @override
  String get svcUpdateShiftFailed => 'Could not update the shift';

  @override
  String get svcUpdateTenantDataFailed => 'Could not update the instance data';

  @override
  String get svcUpdateTenantUserFailed => 'Could not update the instance user';

  @override
  String get svcUpdateTypeFailed => 'Could not update the event type';

  @override
  String get tabsDashboard => 'Dashboard';

  @override
  String get tabsEvents => 'Events';

  @override
  String get tabsMembers => 'Members';

  @override
  String get tabsMore => 'More';

  @override
  String get tabsMyEvents => 'My events';

  @override
  String get tabsOrg => 'Org';

  @override
  String get tabsOverview => 'Overview';

  @override
  String get tabsPeople => 'People';

  @override
  String get tabsSongs => 'Pieces';

  @override
  String tasksAssignedTo(Object name) {
    return 'Assigned to $name';
  }

  @override
  String get tasksAssignedToYou => 'Assigned to you';

  @override
  String get tasksCreated => 'Task created';

  @override
  String get tasksDeleteConfirm => 'Delete task?';

  @override
  String get tasksDeleteFailed => 'Delete failed';

  @override
  String get tasksDeleteMessage => 'The task will be removed permanently.';

  @override
  String get tasksDeleted => 'Task deleted';

  @override
  String get tasksDescription => 'Description';

  @override
  String get tasksDescriptionOptional => 'Description (optional)';

  @override
  String get tasksDetails => 'Details';

  @override
  String get tasksDone => 'Done';

  @override
  String get tasksDoneThanks => 'Done, thanks!';

  @override
  String tasksDueLabel(Object label) {
    return 'Due $label';
  }

  @override
  String get tasksDueOn => 'Due on';

  @override
  String get tasksEnterTitle => 'Please enter a title';

  @override
  String tasksEventFrom(Object type, Object date) {
    return '$type on $date';
  }

  @override
  String get tasksFlutterAllTasks => 'All tasks';

  @override
  String get tasksFlutterEditTask => 'Edit task';

  @override
  String get tasksFlutterNewTask => 'New task';

  @override
  String get tasksFlutterNoDate => 'No date';

  @override
  String get tasksFlutterReopen => 'Reopen';

  @override
  String tasksFlutterShowAllCount(Object count) {
    return 'Show all ($count)';
  }

  @override
  String get tasksInProgress => 'In progress';

  @override
  String get tasksMarkDone => 'Mark as done';

  @override
  String get tasksMyTasks => 'My tasks';

  @override
  String get tasksNoDue => 'No due date';

  @override
  String get tasksNoPersonFound => 'No person found';

  @override
  String get tasksNobody => 'Nobody';

  @override
  String get tasksNotAssigned => 'Not assigned yet';

  @override
  String get tasksNotAvailable => 'This task no longer exists or you can\'t see it.';

  @override
  String tasksNotify(Object name) {
    return 'Notify $name';
  }

  @override
  String get tasksNotifyHint => 'Right away via push or Telegram';

  @override
  String tasksOpenCount(Object count) {
    return '$count open';
  }

  @override
  String get tasksOrigin => 'Origin';

  @override
  String tasksOverdueCount(Object count) {
    return '$count overdue';
  }

  @override
  String tasksOverdueLabel(Object label) {
    return 'Overdue $label';
  }

  @override
  String get tasksOverdueSuffix => '· overdue';

  @override
  String get tasksPerson => 'person';

  @override
  String get tasksPriority => 'Priority';

  @override
  String get tasksProtocol => 'Minutes';

  @override
  String get tasksReminderOther => 'The responsible person gets a reminder 2 days before the due date and another one if the task becomes overdue.';

  @override
  String get tasksReminderSelf => 'You get a reminder 2 days before the due date and another one if the task becomes overdue.';

  @override
  String get tasksResponsible => 'Responsible';

  @override
  String get tasksSaveFailed => 'Task could not be saved';

  @override
  String get tasksSaved => 'Saved';

  @override
  String get tasksSearchPerson => 'Search person';

  @override
  String get tasksStatusCompleted => 'Done';

  @override
  String get tasksStatusFailed => 'Status could not be changed';

  @override
  String get tasksStatusInProgress => 'In progress';

  @override
  String get tasksStatusOpen => 'Open';

  @override
  String get tasksTask => 'Task';

  @override
  String get tasksTitle => 'Title';

  @override
  String get tasksTopic => 'Topic';

  @override
  String get tasksWhatToDo => 'What needs to be done?';

  @override
  String get tasksWhoWhen => 'Who & by when';

  @override
  String get teachersAdd => 'Add teacher';

  @override
  String get teachersContact => 'Contact';

  @override
  String get teachersEdit => 'Edit teacher';

  @override
  String get teachersFillAll => 'Please fill in all fields...';

  @override
  String get teachersFlutterDelete => 'Delete teacher';

  @override
  String teachersFlutterDeleteConfirm(Object name) {
    return 'Do you really want to delete \"$name\"?';
  }

  @override
  String get teachersFlutterDeleted => 'Teacher deleted';

  @override
  String get teachersFlutterLoadFailed => 'Teachers could not be loaded';

  @override
  String get teachersInstruments => 'Instruments';

  @override
  String teachersPlayerCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count members',
      one: '$count member',
    );
    return '$_temp0';
  }

  @override
  String get teachersPlayers => 'Members';

  @override
  String get teachersPrivate => 'Private teacher';

  @override
  String get teachersTitle => 'Teachers';

  @override
  String get teachersUpdate => 'Update teacher';

  @override
  String get teachersUpdated => 'Teacher updated!';

  @override
  String get teamOrgAcceptSuggestion => 'Accept suggestion';

  @override
  String get teamOrgAcceptedByLeaders => 'Accepted by the leadership';

  @override
  String get teamOrgAddTopics => 'Add topics';

  @override
  String teamOrgAllCount(Object count) {
    return 'All · $count';
  }

  @override
  String get teamOrgAllDecided => 'All suggestions have been decided.';

  @override
  String get teamOrgChange => 'Change';

  @override
  String get teamOrgChangeDate => 'Change date of this event';

  @override
  String get teamOrgChosenEvent => 'Selected event';

  @override
  String get teamOrgCreateEvent => 'Create event';

  @override
  String get teamOrgCreateTask => 'Create task';

  @override
  String get teamOrgCreateTopic => 'Create topic';

  @override
  String teamOrgDaysAgo(Object count) {
    return '$count days ago';
  }

  @override
  String get teamOrgDecisionFailed => 'Decision could not be saved';

  @override
  String get teamOrgDescPlaceholder => 'What is it about? (optional)';

  @override
  String get teamOrgDoneDisappear => 'Completed tasks disappear from the list after 30 days.';

  @override
  String get teamOrgDraft => 'Draft';

  @override
  String teamOrgEditedOn(Object text, Object date) {
    return '$text · changed on $date';
  }

  @override
  String get teamOrgEmptyAll => 'No tasks yet. Create the first one with + or directly from minutes.';

  @override
  String get teamOrgEmptyMine => 'You have no tasks. All done!';

  @override
  String get teamOrgEmptyMineAssigned => 'No tasks are assigned to you right now. Enjoy the calm!';

  @override
  String get teamOrgEmptyPerson => 'Nothing open here.';

  @override
  String get teamOrgFilter => 'Filter';

  @override
  String get teamOrgFlutterAnd => 'and';

  @override
  String teamOrgFlutterCreateType(Object name) {
    return 'Create $name';
  }

  @override
  String get teamOrgFlutterMember => 'Member';

  @override
  String teamOrgFlutterNewSuggestions(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count new suggestions',
      one: '$count new suggestion',
    );
    return '$_temp0';
  }

  @override
  String get teamOrgGroupNone => 'No date';

  @override
  String get teamOrgGroupOverdue => 'Overdue';

  @override
  String get teamOrgGroupWeek => 'This week';

  @override
  String get teamOrgLeadersPlan => 'The leadership plans topics and agendas. You are not in any group with minutes & agenda.';

  @override
  String teamOrgMineCount(Object count) {
    return 'Mine · $count';
  }

  @override
  String teamOrgMinutes(Object min) {
    return '$min min';
  }

  @override
  String get teamOrgMySuggestions => 'My suggestions';

  @override
  String get teamOrgNextEvent => 'Next event';

  @override
  String get teamOrgNoHits => 'No results';

  @override
  String get teamOrgNoOpenTopics => 'No open topics. Create a new one with +.';

  @override
  String get teamOrgNoProtocolEvent => 'No event with minutes & agenda scheduled.';

  @override
  String teamOrgNoProtocolMatch(Object search) {
    return 'No minutes match “$search”.';
  }

  @override
  String get teamOrgNoProtocols => 'No minutes yet';

  @override
  String get teamOrgNoProtocolsHint => 'You write minutes directly in the event: open the event and tap “Minutes”.';

  @override
  String get teamOrgNoPublished => 'No minutes published yet';

  @override
  String get teamOrgNoPublishedHint => 'As soon as the leadership publishes minutes, you\'ll find them here.';

  @override
  String get teamOrgNoTopsYet => 'No topics on the agenda yet.';

  @override
  String get teamOrgNobodyAssigned => 'Nobody assigned';

  @override
  String get teamOrgNobodyResponsible => 'Nobody responsible yet';

  @override
  String get teamOrgNothingSuggested => 'You haven\'t suggested anything yet.';

  @override
  String teamOrgOpenCount(Object count) {
    return '$count open';
  }

  @override
  String get teamOrgOpenTopic => 'Open topic';

  @override
  String get teamOrgOutcomeDecided => 'Decided';

  @override
  String get teamOrgOutcomeDiscussed => 'Discussed';

  @override
  String teamOrgPersonInformed(Object name) {
    return '$name will be informed. A short reason helps.';
  }

  @override
  String get teamOrgPlanForWhich => 'Plan for which event?';

  @override
  String get teamOrgPlannedLower => 'planned';

  @override
  String get teamOrgPostponedLower => 'postponed';

  @override
  String get teamOrgProposal => 'Suggestion';

  @override
  String get teamOrgPublished => 'Published';

  @override
  String teamOrgPublishedOn(Object date) {
    return 'Published on $date';
  }

  @override
  String get teamOrgReasonOptional => 'Reason (optional)';

  @override
  String get teamOrgReject => 'Decline';

  @override
  String get teamOrgRejectSuggestion => 'Decline suggestion';

  @override
  String get teamOrgRemoveFailed => 'Topic could not be removed';

  @override
  String get teamOrgRemoveFromEvent => 'Remove from this event';

  @override
  String get teamOrgRemovedStays => 'Removed from the event, stays in the topic store';

  @override
  String get teamOrgReview => 'Review';

  @override
  String get teamOrgSearchProtocols => 'Search event or date';

  @override
  String get teamOrgSendSuggestion => 'Send suggestion';

  @override
  String teamOrgShowDone(Object count) {
    return 'Show completed ($count)';
  }

  @override
  String get teamOrgShowOlderDone => 'Show older completed';

  @override
  String teamOrgSince(Object date) {
    return 'since $date';
  }

  @override
  String get teamOrgSubmittedByMembers => 'Submitted by members';

  @override
  String teamOrgSubmittedOn(Object date) {
    return 'Submitted on $date';
  }

  @override
  String get teamOrgSuggestHint => 'Got something for the next meeting? The leadership decides whether it goes on the agenda.';

  @override
  String get teamOrgSuggestTopic => 'Suggest topic';

  @override
  String get teamOrgSuggestionAccepted => 'Accepted';

  @override
  String get teamOrgSuggestionFailed => 'Suggestion could not be sent';

  @override
  String get teamOrgSuggestionRejected => 'Declined';

  @override
  String get teamOrgSuggestionSent => 'Suggestion sent';

  @override
  String get teamOrgSuggestionWaiting => 'Pending';

  @override
  String get teamOrgSuggestions => 'Suggestions';

  @override
  String get teamOrgSuggestionsHint => 'Accepted suggestions go to the topic store. Whoever suggested it is informed of your decision.';

  @override
  String get teamOrgTabProtocols => 'Minutes';

  @override
  String get teamOrgTabTasks => 'Tasks';

  @override
  String get teamOrgTabTopics => 'Topics';

  @override
  String get teamOrgTasksLoadFailed => 'Tasks could not be loaded';

  @override
  String get teamOrgThePerson => 'The person';

  @override
  String get teamOrgTitle => 'Team organisation';

  @override
  String get teamOrgTitlePlaceholder => 'e.g. New music stands';

  @override
  String get teamOrgToday => 'today';

  @override
  String get teamOrgTodayCap => 'Today';

  @override
  String get teamOrgTomorrow => 'Tomorrow';

  @override
  String teamOrgTopName(Object n, Object name) {
    return 'Item $n · $name';
  }

  @override
  String get teamOrgWhichPriority => 'With which priority should the topic go to the topic store?';

  @override
  String get teamOrgYesterday => 'yesterday';

  @override
  String get teamsChoose => 'Choose which Attendix instance to show in this channel.';

  @override
  String get teamsNoAccount => 'No Attendix account found. Please log in to the Attendix tab first.';

  @override
  String get teamsOnlyInTeams => 'This page is only used inside Microsoft Teams.';

  @override
  String get teamsSaveFailed => 'Configuration could not be saved';

  @override
  String get teamsSetup => 'Set up Attendix tab';

  @override
  String get tenantRegisterAcceptTerms => 'Accept terms of use and privacy policy';

  @override
  String get tenantRegisterAcceptTermsToast => 'Please accept the terms of use and privacy policy.';

  @override
  String get tenantRegisterAccount => 'Account';

  @override
  String get tenantRegisterAlreadyRegistered => 'You are already registered in this instance.';

  @override
  String get tenantRegisterBirthDate => 'Date of birth';

  @override
  String get tenantRegisterBirthDateRequired => 'Please enter a valid date of birth.';

  @override
  String get tenantRegisterChoosePicture => 'Choose a profile photo (max. 15 MB)';

  @override
  String get tenantRegisterChurchNamePlaceholder => 'Name of your church';

  @override
  String get tenantRegisterChurchNameRequired => 'Please enter the name of your church.';

  @override
  String get tenantRegisterChurchNotListed => 'Church not listed? Please enter its name';

  @override
  String get tenantRegisterChurchRequired => 'Please choose a church.';

  @override
  String get tenantRegisterConfirmCode => 'Confirm code';

  @override
  String get tenantRegisterEmailAddress => 'Email address';

  @override
  String tenantRegisterFailed(Object error) {
    return 'Registration failed: $error';
  }

  @override
  String tenantRegisterFieldAccept(Object field) {
    return 'You must agree to \"$field\" to continue.';
  }

  @override
  String tenantRegisterFieldDate(Object field) {
    return 'Please enter a valid date for the field \"$field\".';
  }

  @override
  String tenantRegisterFieldNumber(Object field) {
    return 'Please enter a valid number for the field \"$field\".';
  }

  @override
  String tenantRegisterFieldRequired(Object field) {
    return 'Please fill in the field \"$field\".';
  }

  @override
  String tenantRegisterFieldValue(Object field) {
    return 'Please enter a valid value for the field \"$field\".';
  }

  @override
  String get tenantRegisterFinish => 'Complete registration';

  @override
  String get tenantRegisterFirstName => 'First name';

  @override
  String get tenantRegisterFlutterCreateChurchFailed => 'Error creating the church.';

  @override
  String get tenantRegisterFlutterGroupRequired => 'Group is required';

  @override
  String get tenantRegisterFlutterInvalidLink => 'Invalid registration link.';

  @override
  String get tenantRegisterFlutterLoadChurchesFailed => 'Error loading churches';

  @override
  String tenantRegisterFlutterLoadError(Object error) {
    return 'Error while loading: $error';
  }

  @override
  String get tenantRegisterFlutterLoadGroupsFailed => 'Error loading groups';

  @override
  String get tenantRegisterFlutterMaxSize => 'Max. 15 MB';

  @override
  String get tenantRegisterFlutterMinFiveChars => 'At least 5 characters';

  @override
  String get tenantRegisterFlutterRegisterFailedRetry => 'Registration failed. Please try again.';

  @override
  String get tenantRegisterFlutterRegistrationAt => 'Registration at';

  @override
  String get tenantRegisterFlutterSignInExisting => 'Sign in with your existing account.';

  @override
  String get tenantRegisterFlutterTermsAccept => ' accept';

  @override
  String get tenantRegisterFlutterTermsLink => 'Terms of use and privacy policy';

  @override
  String get tenantRegisterFlutterToLogin => 'Go to sign in';

  @override
  String get tenantRegisterHaveAccount => 'Already have an account? Click here';

  @override
  String get tenantRegisterIntro => 'Use this form to register for the instance shown above.';

  @override
  String get tenantRegisterInvalidLink => 'Invalid sharing link.';

  @override
  String get tenantRegisterLastName => 'Last name';

  @override
  String get tenantRegisterMoreInfo => 'Further information';

  @override
  String get tenantRegisterNameRequired => 'Please enter your first and last name.';

  @override
  String get tenantRegisterNoChurchFound => 'No church found.';

  @override
  String get tenantRegisterNoGroups => 'Registration is not possible right now: the administrator has not created any groups yet. Please try again later.';

  @override
  String get tenantRegisterNoGroupsToast => 'Registration not possible: no groups are available.';

  @override
  String get tenantRegisterNotListed => 'Not listed';

  @override
  String get tenantRegisterNotes => 'Notes (optional)';

  @override
  String get tenantRegisterPasswordMismatch => 'The passwords do not match.';

  @override
  String get tenantRegisterPasswordTooShort => 'The password must be at least 6 characters long.';

  @override
  String get tenantRegisterPersonalData => 'Personal details';

  @override
  String get tenantRegisterPhone => 'Mobile number';

  @override
  String get tenantRegisterPhoneRequired => 'Please enter a valid phone number.';

  @override
  String get tenantRegisterPictureFailed => 'Could not change the photo, please try again later';

  @override
  String get tenantRegisterPictureRequired => 'Please choose a profile photo.';

  @override
  String get tenantRegisterPictureTooLarge => 'The selected image is too large. Please choose an image under 15 MB.';

  @override
  String get tenantRegisterPleaseChoose => 'Please choose';

  @override
  String get tenantRegisterReplacePicture => 'Replace photo';

  @override
  String get tenantRegisterSearchChurch => 'Search church';

  @override
  String tenantRegisterSignedInAs(Object email) {
    return 'You are signed in as $email.';
  }

  @override
  String get tenantRegisterSuccessHeader => 'Registration successful';

  @override
  String get tenantRegisterSuccessJoined => 'Your registration was successful! You are now part of the instance.';

  @override
  String get tenantRegisterSuccessNewConfirm => 'Your account has been created. Please confirm your email so you can sign in. If no email arrives, please check your spam folder. After that you can sign in.';

  @override
  String get tenantRegisterSuccessNewPending => 'Your account has been created and is waiting for an administrator to approve it. Please confirm your email so you can sign in. If no email arrives, please check your spam folder.';

  @override
  String get tenantRegisterSuccessPending => 'Your registration was successful! Please wait for an administrator to approve it.';

  @override
  String get tenantRegisterTitle => 'Registration';

  @override
  String get tenantSelectFlutterCreatedAt => 'Created on';

  @override
  String get tenantSelectFlutterDangerZone => 'Danger zone';

  @override
  String get tenantSelectFlutterDeleteAllData => 'All data of this instance will be permanently deleted.';

  @override
  String get tenantSelectFlutterDeleteTenant => 'Delete instance';

  @override
  String get tenantSelectFlutterDeleteTenantHint => 'Permanently delete this group';

  @override
  String get tenantSelectFlutterDeleted => 'Instance deleted';

  @override
  String get tenantSelectFlutterDetailsLoadFailed => 'Error loading the instance details';

  @override
  String get tenantSelectFlutterDetailsTitle => 'Instance details';

  @override
  String get tenantSelectFlutterEmptyText => 'You are not assigned to any instance yet. Please contact an administrator or create a new instance.';

  @override
  String get tenantSelectFlutterEmptyTitle => 'No instances';

  @override
  String get tenantSelectFlutterEnterNameToConfirm => 'Please enter the name of the instance to confirm the deletion:';

  @override
  String get tenantSelectFlutterInfo => 'Information';

  @override
  String get tenantSelectFlutterLoadFailed => 'Error while loading';

  @override
  String get tenantSelectFlutterNewTenant => 'New instance';

  @override
  String get tenantSelectFlutterNoRole => 'No role';

  @override
  String get tenantSelectFlutterNotFound => 'Instance not found';

  @override
  String get tenantSelectFlutterRegion => 'Region';

  @override
  String get tenantSelectFlutterTenantSelection => 'Instance selection';

  @override
  String get tenantSelectFlutterYourRole => 'Your role';

  @override
  String get termsAcceptAfter => '.';

  @override
  String get termsAcceptAria => 'Accept terms of use and privacy policy';

  @override
  String get termsAcceptBefore => 'I accept the terms of use and have read the';

  @override
  String get termsAcceptContinue => 'Accept and continue';

  @override
  String get termsBeforeStart => 'Just before we start';

  @override
  String get termsIntro => 'To use Attendix, we need your one-time consent to our terms of use and privacy policy.';

  @override
  String get termsPleaseAccept => 'Please accept the terms of use and privacy policy.';

  @override
  String get termsPrivacy => 'privacy policy';

  @override
  String get termsRead => 'Read privacy policy & imprint';

  @override
  String get termsSafe => 'Your data is safe';

  @override
  String get termsSafeText => 'We only store the data needed to run the app and do not pass it on to third parties.';

  @override
  String get termsSaveFailed => 'Error saving. Please try again.';

  @override
  String get termsSessionExpired => 'Your session has expired. Please log in again.';

  @override
  String get termsTitle => 'Privacy & use';

  @override
  String get termsUsage => 'What is your data used for?';

  @override
  String get termsUsageText => 'Only to manage your attendance and for communication within your group or choir.';

  @override
  String get typeSettingsActive => 'Active';

  @override
  String get typeSettingsActiveHelper => 'If you disable this option, the type is no longer offered when creating attendance.';

  @override
  String get typeSettingsActiveReminders => 'Active reminders';

  @override
  String get typeSettingsAddField => 'Add field';

  @override
  String get typeSettingsAddNoteField => 'Add note field';

  @override
  String get typeSettingsAddReminder => 'Add reminder';

  @override
  String get typeSettingsAddTodo => 'Add to-do';

  @override
  String get typeSettingsAfter1Day => 'after 1 day';

  @override
  String get typeSettingsAfter2Days => 'after 2 days';

  @override
  String get typeSettingsAfter3Days => 'after 3 days';

  @override
  String get typeSettingsAfter7Days => 'after 7 days';

  @override
  String get typeSettingsAgenda => 'Agenda';

  @override
  String get typeSettingsAgendaExists => 'An agenda placeholder already exists';

  @override
  String get typeSettingsAgendaPlaceholder => 'Agenda placeholder';

  @override
  String get typeSettingsAllDay => 'All day';

  @override
  String get typeSettingsAllDayHelper => 'If you enable this option, attendance of this type has no time but a duration.';

  @override
  String get typeSettingsAppearance => 'Appearance';

  @override
  String get typeSettingsAttendanceTypes => 'Attendance types';

  @override
  String get typeSettingsAvailableStatus => 'Available attendance statuses';

  @override
  String get typeSettingsChecklist => 'Checklist';

  @override
  String get typeSettingsChecklistHelper => 'Enable the checklist to define to-dos for this type. They are added automatically to new events.';

  @override
  String get typeSettingsCircleHint => 'You define the circle of people as usual via relevant groups or under “Filter” with an additional field (e.g. yes/no field “Sound”). Duties count towards the attendance rate, but only for assigned people.';

  @override
  String get typeSettingsColor => 'Colour';

  @override
  String get typeSettingsColorHint => 'The colour only matters for the calendar (when creating attendance).';

  @override
  String get typeSettingsConfigureReminders => 'Configure reminders';

  @override
  String get typeSettingsCountForAvg => 'Count for Ø';

  @override
  String get typeSettingsCountForAvgHelper => 'If enabled, this type counts towards the attendance average.';

  @override
  String get typeSettingsCreateFailed => 'Error creating the attendance type';

  @override
  String get typeSettingsCreated => 'Attendance type created';

  @override
  String get typeSettingsCustom => 'Custom';

  @override
  String get typeSettingsCustomDots => 'Custom...';

  @override
  String typeSettingsDaysBeforeN(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days before',
      one: '$count day before',
    );
    return '$_temp0';
  }

  @override
  String get typeSettingsDeadline => 'Deadline';

  @override
  String get typeSettingsDefaultDays => 'Default duration (in days)';

  @override
  String get typeSettingsDefaultStatus => 'Default attendance status';

  @override
  String get typeSettingsDeleteFailed => 'Error deleting the attendance type';

  @override
  String get typeSettingsDeleteType => 'Delete attendance type';

  @override
  String typeSettingsDeleteTypeMessage(Object name) {
    return 'Do you really want to delete the attendance type “$name”? All attendance of this type will be deleted too. This cannot be undone.';
  }

  @override
  String get typeSettingsDeleted => 'Attendance type deleted';

  @override
  String get typeSettingsDiscardChanges => 'Discard changes?';

  @override
  String get typeSettingsDiscardMessage => 'You have already entered data. Do you really want to discard it?';

  @override
  String get typeSettingsDutyHelper => 'For duties like sound engineering: a fixed number of people is assigned per event. Only those assigned are expected; everyone else in the circle is a stand-in.';

  @override
  String get typeSettingsDutyMode => 'Duty mode';

  @override
  String get typeSettingsDutyRoster => 'Duty roster';

  @override
  String get typeSettingsDutyViewActive => 'Duty roster view is active';

  @override
  String get typeSettingsEditField => 'Edit field';

  @override
  String get typeSettingsEditTodo => 'Edit to-do';

  @override
  String get typeSettingsEnableChecklist => 'Enable checklist';

  @override
  String get typeSettingsEnableLocation => 'Enable location / navigation';

  @override
  String get typeSettingsEnd => 'End';

  @override
  String get typeSettingsEnterFieldLabel => 'Please enter a field label';

  @override
  String get typeSettingsEnterItem => 'Please enter a programme item.';

  @override
  String get typeSettingsEnterName => 'Please enter a name for the attendance type.';

  @override
  String get typeSettingsEnterTodo => 'Please enter a text for the to-do';

  @override
  String get typeSettingsEventReminder => 'Event reminder';

  @override
  String get typeSettingsEventReminderHelper => 'If this option is enabled, reminders exist and notifications are on, people get an event reminder.';

  @override
  String get typeSettingsEventReminders => 'Event reminders';

  @override
  String get typeSettingsExtraFilter => 'Additional field filter';

  @override
  String get typeSettingsExtraFilterHelper => 'Only people with the selected field value are included when creating attendance of this type.';

  @override
  String get typeSettingsFieldLabel => 'Field label';

  @override
  String get typeSettingsFieldLabelPh => 'e.g. Bring instrument?';

  @override
  String get typeSettingsFilter => 'Filter';

  @override
  String get typeSettingsFlutterAllGroupsHint => 'Empty = applies to all groups';

  @override
  String get typeSettingsFlutterCreateType => 'Create type';

  @override
  String typeSettingsFlutterCreatedNamed(Object name) {
    return 'Attendance type \"$name\" created';
  }

  @override
  String get typeSettingsFlutterDeadlineLabel => 'Deadline (hours before, optional)';

  @override
  String get typeSettingsFlutterDeadlinePh => 'e.g. 24 for 1 day';

  @override
  String get typeSettingsFlutterDurationMinutes => 'Duration (minutes)';

  @override
  String get typeSettingsFlutterDurationPh => 'e.g. 10';

  @override
  String get typeSettingsFlutterExtraField => 'Additional field';

  @override
  String get typeSettingsFlutterExtraFilterHint => 'Only include players with this additional field value';

  @override
  String get typeSettingsFlutterFieldNamePh => 'e.g. warm-up, break';

  @override
  String get typeSettingsFlutterHidden => 'Hidden';

  @override
  String typeSettingsFlutterMinutes(Object minutes) {
    return '$minutes min.';
  }

  @override
  String get typeSettingsFlutterNamePh => 'e.g. rehearsal, concert, dress rehearsal';

  @override
  String get typeSettingsFlutterNamePhShort => 'e.g. rehearsal, concert';

  @override
  String get typeSettingsFlutterNewField => 'New field';

  @override
  String get typeSettingsFlutterNewType => 'New attendance type';

  @override
  String get typeSettingsFlutterNoTypes => 'No attendance types available';

  @override
  String get typeSettingsFlutterNotFound => 'Type not found';

  @override
  String get typeSettingsFlutterPlanHeadingPh => 'e.g. rehearsal plan';

  @override
  String get typeSettingsFlutterReorder => 'Change order';

  @override
  String get typeSettingsFlutterSaveOrderFailed => 'Error while saving. Please try again.';

  @override
  String get typeSettingsFlutterTodoPh => 'e.g. prepare sheet music';

  @override
  String typeSettingsFlutterTotalMinutes(Object minutes) {
    return 'Total: $minutes min.';
  }

  @override
  String get typeSettingsFlutterTypeTitle => 'Attendance type';

  @override
  String typeSettingsFlutterUsageWarning(Object count) {
    return 'Used in $count event(s). Changes affect existing entries.';
  }

  @override
  String get typeSettingsFlutterWithProgramme => 'With programme';

  @override
  String get typeSettingsFreeTextPh => 'Enter free text...';

  @override
  String get typeSettingsH12 => '12 h before';

  @override
  String get typeSettingsH24 => '24 h before';

  @override
  String get typeSettingsH48 => '48 h before';

  @override
  String get typeSettingsH6 => '6 h before';

  @override
  String get typeSettingsH72 => '72 h before';

  @override
  String get typeSettingsHideName => 'Hide name';

  @override
  String get typeSettingsHideNameHelper => 'If you enable this option, the name of this type is hidden in the list. Only the additional info (if any) is shown.';

  @override
  String get typeSettingsHighlight => 'Highlight';

  @override
  String get typeSettingsHighlightHelper => 'If you enable this option, this type is shown in bold in the list.';

  @override
  String get typeSettingsHoursBefore => 'Hours before event';

  @override
  String typeSettingsHoursBeforeN(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hours before',
      one: '$count hour before',
    );
    return '$_temp0';
  }

  @override
  String typeSettingsHoursBeforeStart(Object count) {
    return '$count hour(s) before the event starts';
  }

  @override
  String get typeSettingsHoursPlaceholder => 'e.g. 12 for 12 hours before';

  @override
  String get typeSettingsHowEvery5 => 'Reminders are checked and sent <strong>every 5 minutes</strong>.';

  @override
  String get typeSettingsHowMax => 'At most <strong>3 reminders</strong> per event type.';

  @override
  String get typeSettingsHowRemaining => 'The reminder is sent as soon as the <strong>remaining time</strong> matches the configured value.';

  @override
  String get typeSettingsHowReminders => 'How reminders work';

  @override
  String get typeSettingsInfo => 'Info';

  @override
  String get typeSettingsInfoOptional => 'Info text (optional)';

  @override
  String get typeSettingsInfoOptionalDots => 'Info text (optional)...';

  @override
  String get typeSettingsInsertPlaceholder => 'Insert placeholder';

  @override
  String get typeSettingsLearnMore => 'Learn more';

  @override
  String get typeSettingsLocationHelper => 'If enabled, events of this type can have a location, shown as a navigation link in Google Maps or Apple Maps.';

  @override
  String get typeSettingsManageSongs => 'Manage pieces';

  @override
  String get typeSettingsMax3 => 'At most 3 reminders per type';

  @override
  String get typeSettingsMaxReached => 'Maximum of 3 reminders reached. Remove one to add a new one.';

  @override
  String get typeSettingsMinPh => 'min';

  @override
  String get typeSettingsMulti => 'Multiple choice';

  @override
  String get typeSettingsName => 'Name';

  @override
  String get typeSettingsNeededPeople => 'People needed';

  @override
  String get typeSettingsNewTodo => 'New to-do';

  @override
  String get typeSettingsNoDeadline => 'No deadline';

  @override
  String get typeSettingsNoFilter => 'No filter';

  @override
  String get typeSettingsNoReminders => 'No reminders configured';

  @override
  String get typeSettingsNoRemindersYet => 'No reminders configured yet';

  @override
  String get typeSettingsNoSignupFields => 'No sign-up fields configured';

  @override
  String get typeSettingsNoTodos => 'No to-dos yet';

  @override
  String get typeSettingsNormalView => 'No, normal view';

  @override
  String get typeSettingsNote => 'Note';

  @override
  String get typeSettingsNotePh => 'Enter note...';

  @override
  String get typeSettingsNotifyGroup => 'Notify group on cancellation';

  @override
  String get typeSettingsNotifyGroupHelper => 'If an assigned person cancels and the duty is understaffed, everyone in the circle gets a message.';

  @override
  String get typeSettingsOff => 'Off';

  @override
  String get typeSettingsOption => 'Option';

  @override
  String get typeSettingsOptions => 'Options';

  @override
  String get typeSettingsOptionsComma => 'Options (comma-separated)';

  @override
  String get typeSettingsOptionsPh => 'Option A, Option B, Option C';

  @override
  String get typeSettingsOrderSaved => 'Order saved';

  @override
  String get typeSettingsOrgPlanDefault => 'Run sheet is an organisation plan by default';

  @override
  String get typeSettingsPerformer => 'Performer';

  @override
  String get typeSettingsPerformerPh => 'Enter performer...';

  @override
  String get typeSettingsPlaceholderHint => 'The “Agenda” placeholder in the default run sheet decides where topics are inserted. Without it they go to the end.';

  @override
  String get typeSettingsPlanHeading => 'Run sheet heading';

  @override
  String get typeSettingsPositiveInt => 'Please enter a positive whole number';

  @override
  String get typeSettingsPostponedHelper => 'At the next event of this type, postponed topics are listed first when adding topics.';

  @override
  String get typeSettingsProgrammeItem => 'Programme item';

  @override
  String get typeSettingsProgrammeItemPh => 'Enter programme item...';

  @override
  String get typeSettingsProtocolAgenda => 'Minutes & agenda';

  @override
  String get typeSettingsProtocolHelper => 'Events of this type get an agenda in the run sheet and minutes. The relevant groups decide who belongs.';

  @override
  String get typeSettingsQuickSelect => 'Quick select';

  @override
  String get typeSettingsRelevantGroups => 'Relevant groups';

  @override
  String get typeSettingsRelevantGroupsHelper => 'Only the relevant groups are included when creating attendance of this type. If no group is selected, all groups are included.';

  @override
  String get typeSettingsRemindUnconfirmed => 'Remind if unconfirmed';

  @override
  String get typeSettingsReminderExists => 'This reminder already exists';

  @override
  String get typeSettingsReminders => 'Reminders';

  @override
  String typeSettingsRemindersActive(Object count) {
    return '$count reminder(s) active';
  }

  @override
  String get typeSettingsRunSheet => 'Run sheet';

  @override
  String get typeSettingsSameTime => 'At the same time';

  @override
  String get typeSettingsSavingOrder => 'Saving order...';

  @override
  String get typeSettingsSelectFieldType => 'Please select a field type';

  @override
  String get typeSettingsSelfAssign => 'Self sign-up allowed';

  @override
  String get typeSettingsSelfAssignHelper => 'People in the circle can take open duties themselves.';

  @override
  String get typeSettingsSignupFields => 'Sign-up fields';

  @override
  String get typeSettingsSingle => 'Single choice';

  @override
  String get typeSettingsSongPlaceholder => 'Piece placeholder';

  @override
  String typeSettingsSongPlaceholderN(Object n) {
    return 'Piece placeholder $n';
  }

  @override
  String get typeSettingsSongsHelper => 'If you enable this option, you can add pieces when creating attendance of this type; they are relevant for upcoming rehearsals and automatically included in the rehearsal plan.';

  @override
  String get typeSettingsStart => 'Start';

  @override
  String get typeSettingsStartAllDay => 'Start time of the run sheet for all-day events';

  @override
  String get typeSettingsStartShort => 'Start';

  @override
  String get typeSettingsSuggestPostponed => 'Suggest postponed topics';

  @override
  String get typeSettingsTenantNameBefore => 'Instance name before pieces';

  @override
  String get typeSettingsTenantNameHelper => 'If enabled, the instance name is shown before every piece in the run sheet.';

  @override
  String get typeSettingsText => 'Text';

  @override
  String get typeSettingsTimesHint => 'The times can be adjusted individually in each attendance later';

  @override
  String get typeSettingsTitleHelper => 'This title is shown when exporting a run sheet. If there is type info, it is shown in brackets after it (e.g. Rehearsal plan (Cantata rehearsal)).';

  @override
  String get typeSettingsTodoPlaceholder => 'Enter to-do text...';

  @override
  String get typeSettingsTodoTextPh => 'To-do text...';

  @override
  String get typeSettingsTopicMinutes => 'Default duration per topic (min.)';

  @override
  String get typeSettingsTopicsHere => 'Topics are inserted here';

  @override
  String get typeSettingsTwoOptions => 'Please enter at least 2 options';

  @override
  String get typeSettingsTwoStatus => 'Please select at least two available statuses.';

  @override
  String get typeSettingsType => 'Type';

  @override
  String get typeSettingsTypes => 'Types';

  @override
  String get typeSettingsTypesIntro => 'Manage your own attendance types. You can set individual names, a default status, rehearsal templates and start and end times, and configure attendance for specific groups only.';

  @override
  String get typeSettingsUpdate => 'Update';

  @override
  String get typeSettingsUpdateFailed => 'Error updating the attendance type';

  @override
  String get typeSettingsUpdated => 'Attendance type updated';

  @override
  String get typeSettingsUrgentHelper => 'One urgent push to everyone in the circle and the leadership.';

  @override
  String get typeSettingsUrgentIfOpen => 'Urgent if still open';

  @override
  String get typeSettingsUseDutyView => 'Use duty roster view?';

  @override
  String get typeSettingsUseDutyViewMessage => 'Are duties the norm for you? Then “My events” shows everyone in the duty team their duties, open duties and numbers instead of the attendance rate first. You can change this any time under More → Settings.';

  @override
  String get typeSettingsUseIt => 'Yes, use it';

  @override
  String get typeSettingsValidHours => 'Valid values: 0–168 hours (max. 1 week before)';

  @override
  String get typeSettingsValue => 'Value';

  @override
  String get typeSettingsViewFailed => 'Could not switch the view';

  @override
  String get typeSettingsYesNo => 'Yes / No';

  @override
  String get usageActive7 => 'Active (7d)';

  @override
  String get usageActiveTenants => 'Active instances';

  @override
  String get usageDays30 => '30 days';

  @override
  String get usageDays7 => '7 days';

  @override
  String get usageDays90 => '90 days';

  @override
  String get usageDevices => 'Devices';

  @override
  String get usageDistribution => 'Event distribution';

  @override
  String get usageEventsPerDay => 'Events per day';

  @override
  String get usageNoEvents => 'No events in the selected period.';

  @override
  String get usageTitle => 'Usage dashboard';

  @override
  String get usageTopEvent => 'Top event';

  @override
  String get usageTopEvents => 'Top events';

  @override
  String get usageTopTenants => 'Top instances';

  @override
  String get usageTotalEvents => 'Total events';

  @override
  String voiceLeaderFlutterMemberCount(Object count) {
    return '$count members';
  }

  @override
  String voiceLeaderFlutterMoreCount(Object count) {
    return '+$count more';
  }

  @override
  String get voiceLeaderFlutterNoGroup => 'You are not assigned to a section yet.';

  @override
  String get voiceLeaderFlutterVoiceGroup => 'Section';

  @override
  String get voiceLeaderLoadFailed => 'Error loading the group members.';

  @override
  String get voiceLeaderMyVoice => 'My section';

  @override
  String get voiceLeaderNoContact => 'No contact details';

  @override
  String get voiceLeaderNoMembers => 'No members found in your section.';

  @override
  String get voiceLeaderNoProfile => 'No member profile found.';

  @override
  String get voiceLeaderProfilePicture => 'Profile picture';

  @override
  String get voiceLeaderSfShort => 'SL';

  @override
  String get voiceLeaderUpcomingAbsences => 'Upcoming absences:';
}
