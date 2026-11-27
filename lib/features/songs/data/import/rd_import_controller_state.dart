part of 'rd_import_controller.dart';

// State models, step/error enums, progress helpers, and Riverpod providers
// for the Noten-Import workflow.

enum RdImportStep { source, reading, questions, review, uploading, done }

/// A file that could not be uploaded.
class RdImportFailure {
  const RdImportFailure({required this.path, required this.work, required this.error, this.cancelled = false});

  final String path;
  final String work;
  final String error;

  /// Not uploaded because the import was cancelled (no error).
  final bool cancelled;
}

/// Progress and result of the upload.
class RdImportUpload {
  const RdImportUpload({
    required this.total,
    this.done = 0,
    this.succeeded = 0,
    this.current,
    this.failures = const [],
    this.newWorks = 0,
    this.newGroups = 0,
    this.learned = 0,
    this.finished = false,
    this.learnFailed = false,
    this.aborted = false,
    this.cancelled = false,
    this.filesSince,
    this.filesFrom = 0,
  });

  final int total;
  final int done;

  /// Files that are in Attendix now.
  final int succeeded;

  /// File being uploaded ("120 Wie wunderbar · Viola.pdf").
  final String? current;
  final List<RdImportFailure> failures;
  final int newWorks;
  final int newGroups;

  /// Part names saved as terms of a group.
  final int learned;
  final bool finished;
  final bool learnFailed;

  /// Stopped because the group was switched meanwhile.
  final bool aborted;

  /// Cancelled by hand ("Abbrechen"): the files being uploaded still
  /// arrive, the others are not uploaded.
  final bool cancelled;

  /// When the files started (after new groups and Werke) and how many were
  /// [done] then: for the time left ([rdImportTimeLeft]).
  final DateTime? filesSince;
  final int filesFrom;

  RdImportUpload copyWith({
    int? done,
    int? succeeded,
    String? current,
    List<RdImportFailure>? failures,
    int? newWorks,
    int? newGroups,
    int? learned,
    bool? finished,
    bool? learnFailed,
    bool? aborted,
    bool? cancelled,
    DateTime? filesSince,
    int? filesFrom,
  }) =>
      RdImportUpload(
        total: total,
        done: done ?? this.done,
        succeeded: succeeded ?? this.succeeded,
        current: current ?? this.current,
        failures: failures ?? this.failures,
        newWorks: newWorks ?? this.newWorks,
        newGroups: newGroups ?? this.newGroups,
        learned: learned ?? this.learned,
        finished: finished ?? this.finished,
        learnFailed: learnFailed ?? this.learnFailed,
        aborted: aborted ?? this.aborted,
        cancelled: cancelled ?? this.cancelled,
        filesSince: filesSince ?? this.filesSince,
        filesFrom: filesFrom ?? this.filesFrom,
      );

}

/// About how long the upload still takes at [now], from the pace of the
/// files so far; null until a few files are done (the first ones say
/// little).
Duration? rdImportTimeLeft(RdImportUpload upload, DateTime now) {
  final since = upload.filesSince;
  final done = upload.done - upload.filesFrom;
  if (since == null || upload.finished || done < 3) return null;
  final elapsed = now.difference(since);
  if (elapsed < const Duration(seconds: 5)) return null;
  final left = upload.total - upload.done;
  if (left <= 0) return Duration.zero;
  return elapsed * (left / done);
}

/// The upload of the Noten-Import while it runs, and its result until it
/// was seen: the bar in the shell shows it on every other page (the upload
/// goes on when the import page is left). Written by [RdImportController].
final rdImportRunProvider = StateProvider<RdImportUpload?>((ref) => null);

class RdImportState {
  const RdImportState({
    this.step = RdImportStep.source,
    this.sourceName,
    this.progress = 0,
    this.plan,
    this.decisions = const RdImportDecisions(),
    this.upload,
    this.error,
    this.fileCount = 0,
    this.driveFolder,
    this.useAi = true,
    this.aiStatus = RdImportAiStatus.off,
    this.ai = const {},
    this.aiFilled = const {},
    this.readingDates = false,
    this.collectionId,
    this.pages = const (done: 0, total: 0, limit: false),
  });

  final RdImportStep step;

  /// Name of the ZIP or the Drive folder ("Noten (Speyer)").
  final String? sourceName;

  /// The shared Drive folder read (to stop sharing it afterwards).
  final RdDriveRef? driveFolder;

  /// Reading progress 0–1.
  final double progress;

  /// Files found in the ZIP (without system files).
  final int fileCount;
  final RdImportPlan? plan;
  final RdImportDecisions decisions;
  final RdImportUpload? upload;

  /// Reading failed (no ZIP, empty ZIP, nothing loaded).
  final String? error;

  /// Suggestions of the KI for the questions (switch "Vorschläge der KI").
  final bool useAi;
  final RdImportAiStatus aiStatus;

  /// The KI's guess by question key.
  final Map<String, RdImportAiAnswer> ai;

  /// Questions whose answer the KI filled in and nobody confirmed or
  /// changed since. They must be confirmed before the review
  /// ([RdImportController.confirmAi]): only then are they used and learned.
  final Set<String> aiFilled;

  /// Dates of Fassungen that only showed after a decision are being read:
  /// "Passt so" and the upload wait.
  final bool readingDates;

  /// Sammlung the Noten go into (null: Repertoire): Werke are compared
  /// with its Werke, new ones are created in it with its Kürzel.
  final int? collectionId;

  /// First pages the KI reads in the review: done of total, and whether
  /// the day's budget ran out.
  final ({int done, int total, bool limit}) pages;

  RdImportState copyWith({
    RdImportStep? step,
    String? sourceName,
    double? progress,
    RdImportPlan? plan,
    RdImportDecisions? decisions,
    RdImportUpload? upload,
    String? error,
    bool clearError = false,
    int? fileCount,
    RdDriveRef? driveFolder,
    bool? useAi,
    RdImportAiStatus? aiStatus,
    Map<String, RdImportAiAnswer>? ai,
    Set<String>? aiFilled,
    bool? readingDates,
    int? collectionId,
    bool toRepertoire = false,
    ({int done, int total, bool limit})? pages,
  }) =>
      RdImportState(
        step: step ?? this.step,
        sourceName: sourceName ?? this.sourceName,
        progress: progress ?? this.progress,
        plan: plan ?? this.plan,
        decisions: decisions ?? this.decisions,
        upload: upload ?? this.upload,
        error: clearError ? null : (error ?? this.error),
        fileCount: fileCount ?? this.fileCount,
        driveFolder: driveFolder ?? this.driveFolder,
        useAi: useAi ?? this.useAi,
        aiStatus: aiStatus ?? this.aiStatus,
        ai: ai ?? this.ai,
        aiFilled: aiFilled ?? this.aiFilled,
        readingDates: readingDates ?? this.readingDates,
        collectionId: toRepertoire ? null : (collectionId ?? this.collectionId),
        pages: pages ?? this.pages,
      );
}

/// First pages the KI reads at most in one import.
const int rdImportMaxPageReads = 300;

/// ZIPs read in the browser are held in memory: more than this together
/// is refused there (the Drive link or the app can take it).
const int rdImportMaxWebBytes = 1024 * 1024 * 1024;

/// Why reading stopped.
enum RdImportReadError {
  notZip,
  empty,
  noData,

  /// Too large to hold in the browser's memory ([rdImportMaxWebBytes]).
  tooLargeWeb,

  /// The group shows the Werke of another one ([rdImportOwnLibraryProvider]).
  otherLibrary,

  /// No link to a folder.
  badLink,

  /// A Drive link to a file or document, not a folder.
  notFolder,

  /// Dropbox links are not read yet (ZIP instead).
  dropbox,

  /// Folder not found or not shared with "Anyone with the link".
  notFound,

  /// The link import is not set up on the server yet.
  notSetUp,

  /// More files than one import can take.
  tooMany,

  /// The day's budget is used up, or Google is busy.
  limit,
  forbidden,
  failed,
}

/// Whether the current group's Werke are its own. A group that shows the
/// Werke of another one (Werk-Synchronisierung) imports nothing: the Noten
/// would go to the other group's Werke.
final rdImportOwnLibraryProvider = FutureProvider<bool>((ref) async {
  final tenantId = ref.watch(currentTenantIdProvider);
  final source = (await ref.watch(songTenantSettingsProvider.future)).songSourceTenantId;
  return source == null || source == tenantId;
});

RdImportReadError _readErrorOf(RdDriveError error) => switch (error) {
      RdDriveError.notSetUp => RdImportReadError.notSetUp,
      RdDriveError.notFound => RdImportReadError.notFound,
      RdDriveError.notFolder => RdImportReadError.notFolder,
      RdDriveError.limit || RdDriveError.busy => RdImportReadError.limit,
      RdDriveError.tooMany => RdImportReadError.tooMany,
      RdDriveError.forbidden => RdImportReadError.forbidden,
      RdDriveError.exists || RdDriveError.failed => RdImportReadError.failed,
    };

/// A checked Drive link: the folder and its name, or why not.
class RdLinkCheck {
  const RdLinkCheck({this.folder, this.name, this.error});

  final RdDriveRef? folder;
  final String? name;
  final RdImportReadError? error;
}

/// Text of a failed upload.
String _uploadError(Object e) {
  if (e is RdDriveException) {
    final l10n = l10nWithoutContext;
    return switch (e.error) {
      RdDriveError.notFound => l10n.redesignImportDriveFileGone,
      RdDriveError.limit || RdDriveError.busy => l10n.redesignImportErrorLimit,
      RdDriveError.notSetUp => l10n.redesignImportErrorNotSetUp,
      _ => l10n.commonUnknownError,
    };
  }
  if (e is FormatException) return l10nWithoutContext.redesignImportFileBroken;
  return friendlyErrorMessage(e);
}
