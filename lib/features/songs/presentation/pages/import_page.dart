import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/providers/debug_providers.dart';
import '../../../../core/providers/group_providers.dart';
import '../../../../core/providers/pwa_providers.dart';
import '../../../../core/providers/song_providers.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/utils/instrument_matcher.dart';
import '../../../../core/theme/design_theme.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/song/song.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/adaptive/app_dialog.dart';
import '../../../../shared/widgets/layout/route_leave_guard.dart';
import '../../data/import/import_ai.dart';
import '../../data/import/import_controller.dart';
import '../../data/import/import_drive.dart';
import '../../data/import/import_logic.dart';
import '../../data/collections_logic.dart';
import '../../../../core/logic/words.dart';
import '../widgets/import/import_widgets.dart';
import '../../../settings/presentation/widgets/manage/settings_sheets.dart' show showRdTextSheet;
import '../../../../shared/widgets/components/components.dart';
import '../widgets/works/collections_ui.dart';
import '../../../today/presentation/widgets/today_common.dart' show RdInfoCard;
import 'import_work_page.dart';

part 'import_page_question_cards.dart';
part 'import_page_review_step.dart';
part 'import_page_source_step.dart';

/// REDESIGN: Werke › "Noten importieren" (canvas "Werke-Import Mock-up",
/// R2–R6 / H2–H10): a shared Google Drive folder (link) or a ZIP from
/// Dropbox, OneDrive or the computer is read, unknown part names are asked
/// once, every Werk can be checked and only then the files are uploaded.
/// Route [RedesignRoutes.worksImport]; the controller refreshes the Werke
/// after the upload.
class RdImportPage extends ConsumerStatefulWidget {
  const RdImportPage({super.key});

  @override
  ConsumerState<RdImportPage> createState() => _RdImportPageState();
}

enum _Filter { open, created, all }

enum _Source { drive, zip }

/// [GoRoute.onExit] of the page in the browser: its back button changes the
/// address without a pop, so [PopScope] does not see it. Asks the page's
/// leave guard (tab and account switches ask it too).
Future<bool> rdImportOnExit(BuildContext context, GoRouterState state) =>
    ProviderScope.containerOf(context, listen: false).read(routeLeaveGuardRegistryProvider).canLeave();

/// Text of [error].
String rdImportReadErrorText(AppLocalizations l10n, RdImportReadError error) => switch (error) {
      RdImportReadError.notZip => l10n.redesignImportErrorNotZip,
      RdImportReadError.empty => l10n.redesignImportErrorEmpty,
      RdImportReadError.noData => l10n.redesignImportErrorNoData,
      RdImportReadError.tooLargeWeb => l10n.redesignImportErrorTooLargeWeb,
      RdImportReadError.otherLibrary => l10n.redesignImportErrorOtherLibrary,
      RdImportReadError.badLink => l10n.redesignImportErrorBadLink,
      RdImportReadError.notFolder => l10n.redesignImportErrorNotFolder,
      RdImportReadError.dropbox => l10n.redesignImportErrorDropbox,
      RdImportReadError.notFound => l10n.redesignImportErrorNotFound,
      RdImportReadError.notSetUp => l10n.redesignImportErrorNotSetUp,
      RdImportReadError.tooMany => l10n.redesignImportErrorTooMany,
      RdImportReadError.limit => l10n.redesignImportErrorLimit,
      RdImportReadError.forbidden => l10n.redesignImportErrorForbidden,
      RdImportReadError.failed => l10n.redesignImportErrorFailed,
    };

/// From this many questions on they are shown by instrument.
const _groupFrom = 8;

class _RdImportPageState extends ConsumerState<RdImportPage> {
  _Filter? _filter;

  /// The questions still open when "Fragen beantworten" was tapped in the
  /// review: only they are shown (answered ones stay until the review);
  /// null = the questions step with everything.
  Set<String>? _openOnly;

  /// The questions were opened from the review ("Fragen beantworten"):
  /// back goes there, also after "Alle Fragen zeigen".
  bool _fromReview = false;

  /// Groups of questions opened or closed by hand ([rdImportQuestionGroups],
  /// by their title); the unclear one is open, the others closed at first.
  final Map<String, bool> _groupOpen = {};


  /// "Zur Prüfung" was tapped and the plan is made again (a second or so
  /// with thousands of files): the button says so meanwhile.
  bool _preparing = false;

  /// Which source is being set up (null = the choice).
  _Source? _mode;
  final _link = TextEditingController();

  /// The link last checked and the answer.
  String _checked = '';
  bool _checking = false;
  RdLinkCheck? _check;

  /// Reading the folder or the ZIP failed; shown as a card with a way out.
  RdImportReadError? _error;

  /// A tab switch replaces the page with `context.go`, which skips
  /// [PopScope]; the shell asks this guard first (like "Neuer Termin").
  late final RouteLeaveGuardRegistry _leaveGuards;

  /// Leaving was confirmed (or nothing is lost): the guard lets go.
  bool _leaving = false;

  /// The result of the upload was shown ([RdImportController.resultSeen]).
  bool _seen = false;

  RdImportController get _controller => ref.read(rdImportProvider.notifier);

  /// "Neue Sammlung" is being made ([_addCollection]).
  bool _addingCollection = false;

  void _update(VoidCallback fn) => setState(fn);

  @override
  void initState() {
    super.initState();
    _leaveGuards = ref.read(routeLeaveGuardRegistryProvider);
    _leaveGuards.add(_onLeave);
  }

  @override
  void dispose() {
    _leaveGuards.remove(_onLeave);
    _link.dispose();
    super.dispose();
  }

  /// Ask before throwing away answers and decisions (also while the dates
  /// of Fassungen are read after the questions); the upload goes on when
  /// the page is left (the bar in the shell shows it).
  Future<bool> _onLeave() async {
    if (_leaving || !mounted) return true;
    final state = ref.read(rdImportProvider);
    switch (state.step) {
      case RdImportStep.reading when state.plan != null:
      case RdImportStep.questions:
      case RdImportStep.review:
        final ok = await _confirmDiscard();
        if (ok) _leaving = true;
        return ok;
      case RdImportStep.source:
      case RdImportStep.reading:
      case RdImportStep.uploading:
      case RdImportStep.done:
        return true;
    }
  }

  Future<bool> _confirmDiscard() {
    final l10n = context.l10n;
    return showAppConfirm(
      context,
      title: l10n.redesignImportDiscardTitle,
      message: l10n.redesignImportDiscardMessage,
      confirmText: l10n.redesignImportDiscardConfirm,
      destructive: true,
    );
  }

  /// Back to the Werke (or to them when the page was opened directly).
  void _leave() {
    _leaving = true;
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    } else {
      GoRouter.maybeOf(context)?.go(RedesignRoutes.works);
    }
  }

  Future<void> _checkLink(String text) async {
    final t = text.trim();
    if (t.isEmpty || t == _checked) return;
    setState(() {
      _checked = t;
      _checking = true;
      _check = null;
      _error = null;
    });
    final result = await _controller.checkLink(t);
    if (!mounted || _checked != t) return;
    setState(() {
      _checking = false;
      _check = result;
    });
  }

  void _linkChanged(String text) {
    if (rdParseDriveLink(text) != null) {
      _checkLink(text);
    } else {
      // Always rebuilt: the hint "kein Drive-Link" follows the text.
      setState(() {
        _checked = '';
        _checking = false;
        _check = null;
        _error = null;
      });
    }
  }

  /// "Los" on the keyboard: reads a found folder, else checks the link.
  void _linkSubmitted(String text) {
    if (_check?.folder != null && _error == null && text.trim() == _checked) {
      _readLink();
    } else {
      _checkLink(text);
    }
  }

  Future<void> _paste() async {
    String? text;
    try {
      text = (await Clipboard.getData(Clipboard.kTextPlain))?.text?.trim();
    } catch (_) {
      // No clipboard access (PWA): the field takes a long press.
    }
    if (text == null || text.isEmpty || !mounted) return;
    _link.text = text;
    await _checkLink(text);
  }

  Future<void> _readLink() async {
    final check = _check;
    final folder = check?.folder;
    if (folder == null) return;
    FocusScope.of(context).unfocus();
    setState(() => _error = null);
    final error = await _controller.readLink(folder, check?.name ?? '');
    if (!mounted || error == null) return;
    setState(() => _error = error);
  }

  /// "Erneut versuchen": the link check or the reading again.
  void _retry() {
    if (_mode == _Source.zip) {
      _pick();
    } else if (_error != null) {
      _readLink();
    } else {
      final text = _link.text;
      setState(() => _checked = '');
      _checkLink(text);
    }
  }

  /// Dropbox or the link import not set up: a ZIP instead.
  void _useZip() {
    setState(() {
      _mode = _Source.zip;
      _error = null;
    });
    _pick();
  }

  /// Google Drive (or the shared folder), in the Drive app when it is on
  /// the phone, else in the browser.
  Future<void> _openDrive([RdDriveRef? folder]) async {
    final page = folder == null ? Uri.https('drive.google.com', '/drive/my-drive') : rdDriveFolderUrl(folder);
    final intents = ref.read(pwaServiceProvider).opensAndroidIntents();
    for (final (uri, mode) in rdDriveLaunches(page, platform: defaultTargetPlatform, web: kIsWeb, intents: intents)) {
      try {
        if (await launchUrl(uri, mode: mode)) return;
      } catch (_) {}
    }
  }

  Future<void> _pick() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['zip'],
      allowMultiple: true,
      // In the browser the size is checked before the ZIP is read.
      withReadStream: kIsWeb,
    );
    if (result == null || !mounted) return;
    await _read(result.files);
  }

  Future<void> _read(List<PlatformFile> files) async {
    final zips = files.where((f) => f.name.toLowerCase().endsWith('.zip')).toList();
    if (zips.isEmpty) {
      setState(() => _error = RdImportReadError.notZip);
      return;
    }
    setState(() => _error = null);
    final error = await _controller.read(zips);
    if (!mounted || error == null) return;
    setState(() => _error = error);
  }

  /// Back link and system back: one step back; leaving the answers asks
  /// first; during the upload the page is left, the upload goes on.
  Future<void> _back() async {
    final state = ref.read(rdImportProvider);
    switch (state.step) {
      case RdImportStep.source when _mode != null:
        setState(() {
          _mode = null;
          _error = null;
        });
      // Dates read after the questions: back to them.
      case RdImportStep.reading when state.plan != null:
        _controller.goTo(RdImportStep.questions);
      case RdImportStep.source:
      case RdImportStep.reading:
      case RdImportStep.uploading:
      case RdImportStep.done:
        _leave();
      case RdImportStep.questions when _fromReview:
        await _toReview();
      case RdImportStep.questions:
        if (await _confirmDiscard() && mounted) {
          setState(() {
            _error = null;
            _filter = null;
          });
          _controller.restart();
        }
      case RdImportStep.review:
        _controller.goTo(RdImportStep.questions);
    }
  }

  /// "Weitere Noten importieren": everything from the start.
  void _startOver() {
    setState(() {
      _mode = null;
      _link.clear();
      _checked = '';
      _check = null;
      _error = null;
      _filter = null;
      _openOnly = null;
      _fromReview = false;
    });
    _controller.restart();
  }

  /// "Import abbrechen": asked first; the files under way still arrive.
  Future<void> _cancelUpload() async {
    final l10n = context.l10n;
    final ok = await showAppConfirm(
      context,
      title: l10n.redesignImportCancelTitle,
      message: l10n.redesignImportCancelMessage,
      confirmText: l10n.redesignImportCancel,
      cancelText: l10n.redesignImportCancelKeep,
      destructive: true,
    );
    if (ok && mounted) _controller.cancelUpload();
  }

  Future<void> _startUpload() async {
    final state = ref.read(rdImportProvider);
    final plan = state.plan;
    if (plan == null) return;
    final l10n = context.l10n;
    final summary = rdImportSummary(plan, state.decisions);
    final ok = await showAppConfirm(
      context,
      title: l10n.redesignImportConfirmTitle,
      message: [
        l10n.redesignImportConfirmMessage(summary.take, l10n.redesignImportConfirmWorks(summary.ready)),
        if (summary.newWorks > 0) l10n.redesignImportConfirmNewWorks(summary.newWorks),
        l10n.redesignImportConfirmKeepOpen,
      ].join(' '),
      confirmText: l10n.redesignImportConfirmButton,
    );
    if (ok && mounted) await _controller.upload();
  }

  @override
  Widget build(BuildContext context) {
    // The Werke stay loaded while the assistant is open.
    ref.watch(songsListDataProvider(null));
    final state = ref.watch(rdImportProvider);
    final canPop = (state.step == RdImportStep.source && _mode == null) ||
        state.step == RdImportStep.uploading ||
        state.step == RdImportStep.done;
    // The result is seen here: the bar in the shell goes, and the import
    // with the page.
    if (state.step == RdImportStep.done && !_seen) {
      _seen = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _controller.resultSeen();
      });
    } else if (state.step != RdImportStep.done) {
      _seen = false;
    }
    final page = switch (state.step) {
      RdImportStep.source => _source(context),
      RdImportStep.reading => _reading(context, state),
      RdImportStep.questions => _questions(context, state),
      RdImportStep.review => _review(context, state),
      RdImportStep.uploading || RdImportStep.done => _upload(context, state),
    };
    return PopScope(
      canPop: canPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      // Every step starts at the top.
      child: KeyedSubtree(key: ValueKey((state.step, _mode)), child: page),
    );
  }

  /// Why reading failed, with a way out where there is one.
  Widget _errorCard(BuildContext context, RdImportReadError error) {
    final l10n = context.l10n;
    final Widget? action = _mode == _Source.zip
        ? null
        : switch (error) {
            RdImportReadError.dropbox || RdImportReadError.notSetUp => RdOutlineButton(
                label: l10n.redesignImportUseZip,
                icon: Icons.folder_zip_outlined,
                onPressed: _useZip,
              ),
            RdImportReadError.limit ||
            RdImportReadError.failed ||
            RdImportReadError.notFound ||
            RdImportReadError.noData =>
              RdOutlineButton(label: l10n.redesignCommonRetry, icon: Icons.refresh, onPressed: _retry),
            _ => null,
          };
    return Semantics(
      liveRegion: true,
      child: RdInfoCard(text: rdImportReadErrorText(l10n, error), icon: Icons.error_outline, action: action),
    );
  }
}

/// The ways to open the Drive [page], best first. On a phone the Drive app
/// comes first: the app by its own link on iOS, an app-only launch of the
/// page in the app, and in Chrome on Android ([intents]) an intent link that
/// falls back to the page itself. Otherwise the browser.
@visibleForTesting
List<(Uri, LaunchMode)> rdDriveLaunches(
  Uri page, {
  required TargetPlatform platform,
  required bool web,
  bool intents = false,
}) {
  final browser = (page, LaunchMode.externalApplication);
  final phone = platform == TargetPlatform.iOS || platform == TargetPlatform.android;
  if (!phone) return [browser];
  if (web) {
    // iOS and other browsers have no way to the app without an error page
    // when it is missing; Drive's page offers the app itself.
    if (platform != TargetPlatform.android || !intents) return [browser];
    final fallback = Uri.encodeComponent(page.toString());
    final rest = page.hasQuery ? '${page.path}?${page.query}' : page.path;
    return [
      (
        Uri.parse('intent://${page.host}$rest#Intent;scheme=https;package=com.google.android.apps.docs;S.browser_fallback_url=$fallback;end'),
        LaunchMode.externalApplication,
      ),
    ];
  }
  return [
    if (platform == TargetPlatform.iOS && page.path == '/drive/my-drive') (Uri.parse('googledrive://'), LaunchMode.externalApplication),
    (page, LaunchMode.externalNonBrowserApplication),
    browser,
  ];
}
