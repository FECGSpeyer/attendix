import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/providers/song_providers.dart';
import '../../../../core/theme/redesign/rd_theme.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/adaptive/app_dialog.dart';
import '../../data/import/rd_import_controller.dart';
import '../../data/import/rd_import_drive.dart';
import '../../data/import/rd_import_logic.dart';
import '../widgets/import/rd_import_widgets.dart';
import '../widgets/rd_widgets.dart';
import 'rd_import_work_page.dart';

/// REDESIGN: Werke › "Noten importieren" (canvas "Werke-Import Mock-up",
/// R2–R6 / H2–H10): a shared Google Drive folder (link) or a ZIP from
/// Dropbox, OneDrive or the computer is read, unknown part names are asked
/// once, every Werk can be checked and only then the files are uploaded.
/// Pops with true when something was uploaded.
class RdImportPage extends ConsumerStatefulWidget {
  const RdImportPage({super.key});

  @override
  ConsumerState<RdImportPage> createState() => _RdImportPageState();
}

enum _Filter { open, created, all }

enum _Source { drive, zip }

/// Text of [error].
String rdImportReadErrorText(AppLocalizations l10n, RdImportReadError error) => switch (error) {
      RdImportReadError.notZip => l10n.redesignImportErrorNotZip,
      RdImportReadError.empty => l10n.redesignImportErrorEmpty,
      RdImportReadError.noData => l10n.redesignImportErrorNoData,
      RdImportReadError.tooLargeWeb => l10n.redesignImportErrorTooLargeWeb,
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

class _RdImportPageState extends ConsumerState<RdImportPage> {
  _Filter? _filter;

  /// Which source is being set up (null = the choice).
  _Source? _mode;
  final _link = TextEditingController();

  /// The link last checked and the answer.
  String _checked = '';
  bool _checking = false;
  RdLinkCheck? _check;

  RdImportController get _controller => ref.read(rdImportProvider.notifier);

  @override
  void dispose() {
    _link.dispose();
    super.dispose();
  }

  Future<void> _checkLink(String text) async {
    final t = text.trim();
    if (t.isEmpty || t == _checked) return;
    setState(() {
      _checked = t;
      _checking = true;
      _check = null;
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
    } else if (_checked.isNotEmpty) {
      setState(() {
        _checked = '';
        _checking = false;
        _check = null;
      });
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
    final error = await _controller.readLink(folder, check?.name ?? '');
    if (!mounted || error == null) return;
    ToastHelper.showError(context, rdImportReadErrorText(context.l10n, error));
  }

  Future<void> _openDrive([RdDriveRef? folder]) async {
    final uri = folder == null ? Uri.https('drive.google.com', '/') : rdDriveFolderUrl(folder);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
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
    final l10n = context.l10n;
    final zips = files.where((f) => f.name.toLowerCase().endsWith('.zip')).toList();
    if (zips.isEmpty) {
      ToastHelper.showError(context, l10n.redesignImportErrorNotZip);
      return;
    }
    final error = await _controller.read(zips);
    if (!mounted || error == null) return;
    ToastHelper.showError(context, rdImportReadErrorText(l10n, error));
  }

  /// Back link and system back: one step back; leaving the answers asks
  /// first, during the upload it waits.
  Future<void> _back() async {
    final state = ref.read(rdImportProvider);
    final l10n = context.l10n;
    switch (state.step) {
      case RdImportStep.source when _mode != null:
        setState(() => _mode = null);
      case RdImportStep.source:
      case RdImportStep.reading:
        Navigator.of(context).pop(false);
      case RdImportStep.questions:
        final ok = await showAppConfirm(
          context,
          title: l10n.redesignImportDiscardTitle,
          message: l10n.redesignImportDiscardMessage,
          confirmText: l10n.redesignImportDiscardConfirm,
          destructive: true,
        );
        if (ok && mounted) _controller.restart();
      case RdImportStep.review:
        _controller.goTo(RdImportStep.questions);
      case RdImportStep.uploading:
        ToastHelper.showInfo(context, l10n.redesignImportBusy);
      case RdImportStep.done:
        Navigator.of(context).pop(true);
    }
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
      message: l10n.redesignImportConfirmMessage(summary.take, summary.ready, summary.newWorks),
      confirmText: l10n.redesignImportConfirmButton,
    );
    if (ok && mounted) await _controller.upload();
  }

  @override
  Widget build(BuildContext context) {
    // The Werke stay loaded while the assistant is open.
    ref.watch(songsListDataProvider(null));
    final state = ref.watch(rdImportProvider);
    final canPop = (state.step == RdImportStep.source && _mode == null) || state.step == RdImportStep.done;
    return PopScope(
      canPop: canPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: switch (state.step) {
        RdImportStep.source => _source(context),
        RdImportStep.reading => _reading(context, state),
        RdImportStep.questions => _questions(context, state),
        RdImportStep.review => _review(context, state),
        RdImportStep.uploading || RdImportStep.done => _upload(context, state),
      },
    );
  }

  // -------------------------------------------------------------------------
  // 1 Quelle

  Widget _source(BuildContext context) => switch (_mode) {
        null => _sourceChoice(context),
        _Source.drive => _sourceDrive(context),
        _Source.zip => _sourceZip(context),
      };

  Widget _sourceChoice(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    return RdImportFrame(
      backLabel: l10n.redesignTabWorks,
      onBack: _back,
      title: l10n.redesignImportTitle,
      step: 1,
      children: [
        RdSectionHeader(l10n.redesignImportSourceWhere),
        RdGroupedList(
          children: [
            RdListRow(
              leading: const RdRowIcon(Icons.add_to_drive_outlined),
              title: l10n.redesignImportSourceDrive,
              subtitle: l10n.redesignImportSourceDriveDetail,
              trailing: RdPill(l10n.redesignImportSourceRecommended, tone: RdTone.primary),
              onTap: () => setState(() => _mode = _Source.drive),
            ),
            RdListRow(
              leading: const RdRowIcon(Icons.folder_zip_outlined),
              title: l10n.redesignImportSourceZip,
              subtitle: l10n.redesignImportSourceZipDetail,
              onTap: () => setState(() => _mode = _Source.zip),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 12, 4, 0),
          child: Text(l10n.redesignImportSourceSafe, style: RdType.meta(p, size: 13)),
        ),
      ],
    );
  }

  Widget _sourceDrive(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final check = _check;
    final error = check?.error;
    return RdImportFrame(
      backLabel: l10n.redesignImportStepSource,
      onBack: _back,
      title: l10n.redesignImportSourceDrive,
      step: 1,
      bottom: RdPrimaryButton(
        label: l10n.redesignImportDriveStart,
        onPressed: check?.folder == null ? null : _readLink,
      ),
      children: [
        RdCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (i, text) in [
                l10n.redesignImportDriveStep1,
                l10n.redesignImportDriveStep2,
                l10n.redesignImportDriveStep3,
              ].indexed) ...[
                if (i > 0) const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ExcludeSemantics(child: RdCountBadge(i + 1)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Text(text, style: RdType.body(p)),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              RdOutlineButton(label: l10n.redesignImportDriveOpen, icon: Icons.open_in_new, onPressed: _openDrive),
            ],
          ),
        ),
        const SizedBox(height: 20),
        RdSectionHeader(l10n.redesignImportDriveLinkLabel),
        RdCard(
          padding: const EdgeInsets.fromLTRB(16, 6, 6, 6),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _link,
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  enableSuggestions: false,
                  textInputAction: TextInputAction.go,
                  style: TextStyle(fontSize: 16, color: p.text),
                  decoration: InputDecoration(
                    isDense: true,
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    hintText: l10n.redesignImportDriveLinkHint,
                    hintStyle: TextStyle(color: p.text2),
                  ),
                  onChanged: _linkChanged,
                  onSubmitted: _checkLink,
                ),
              ),
              const SizedBox(width: 8),
              RdPillButton(icon: Icons.content_paste, label: l10n.redesignImportDrivePaste, onPressed: _paste),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (_checking)
          Row(
            children: [
              SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: p.primary)),
              const SizedBox(width: 10),
              Text(l10n.redesignImportDriveChecking, style: RdType.meta(p)),
            ],
          )
        else if (check?.folder != null)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: p.presentSoft, borderRadius: BorderRadius.circular(14)),
            child: Row(
              children: [
                Icon(Icons.check, color: p.present),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.redesignImportDriveFound(check!.name ?? ''),
                    style: RdType.body(p).copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          )
        else if (error != null)
          Semantics(
            liveRegion: true,
            child: Text(rdImportReadErrorText(l10n, error), style: RdType.body(p).copyWith(color: p.absent)),
          ),
        const SizedBox(height: 12),
        Text(l10n.redesignImportDriveUnshareNote, style: RdType.meta(p, size: 13)),
      ],
    );
  }

  Widget _sourceZip(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    return RdImportFrame(
      backLabel: l10n.redesignImportStepSource,
      onBack: _back,
      title: l10n.redesignImportSourceZip,
      step: 1,
      children: [
        RdCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.redesignImportSourceIntro, style: RdType.body(p)),
              const SizedBox(height: 16),
              RdPrimaryButton(label: l10n.redesignImportSourcePick, icon: Icons.folder_zip_outlined, onPressed: _pick),
            ],
          ),
        ),
        const SizedBox(height: 20),
        RdSectionHeader(l10n.redesignImportSourceHowTitle),
        RdCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (i, (icon, text)) in [
                (Icons.add_to_drive_outlined, l10n.redesignImportSourceHowDrive),
                (Icons.cloud_download_outlined, l10n.redesignImportSourceHowDropbox),
                (Icons.computer_outlined, l10n.redesignImportSourceHowComputer),
              ].indexed) ...[
                if (i > 0) const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, size: 20, color: p.text2),
                    const SizedBox(width: 12),
                    Expanded(child: Text(text, style: RdType.body(p))),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // 2 Einlesen

  Widget _reading(BuildContext context, RdImportState state) {
    final p = context.rd;
    final l10n = context.l10n;
    return RdImportFrame(
      backLabel: l10n.redesignTabWorks,
      onBack: _back,
      title: l10n.redesignImportTitle,
      step: 2,
      children: [
        RdCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.redesignImportReadingTitle, style: RdType.section(p)),
              if (state.sourceName != null) ...[
                const SizedBox(height: 4),
                Text('${state.sourceName} · ${l10n.redesignImportFoundFiles(state.fileCount)}', style: RdType.meta(p)),
              ],
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: state.progress <= 0 ? null : state.progress,
                  minHeight: 8,
                  color: p.primary,
                  backgroundColor: p.track,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _mode == _Source.drive && state.progress <= 0
                    ? l10n.redesignImportDriveReading
                    : l10n.redesignImportReadingDetail,
                style: RdType.meta(p, size: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _questions(BuildContext context, RdImportState state) {
    final p = context.rd;
    final l10n = context.l10n;
    final plan = state.plan!;
    final d = state.decisions;
    final existing = plan.works.where((w) => w.match.songId != null).length;
    final created = plan.works.where((w) => rdDefaultTarget(plan, w).isNew).length;
    return RdImportFrame(
      backLabel: l10n.redesignImportStepSource,
      onBack: _back,
      title: l10n.redesignImportTitle,
      step: 2,
      bottom: RdPrimaryButton(
        label: l10n.redesignImportToReview,
        onPressed: () {
          setState(() => _filter = null);
          _controller.goTo(RdImportStep.review);
        },
      ),
      children: [
        RdCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(state.sourceName ?? '', style: RdType.section(p)),
              const SizedBox(height: 4),
              Text(
                [
                  l10n.redesignImportFoundFiles(plan.fileCount),
                  l10n.redesignImportFoundWorks(plan.works.length),
                ].join(' · '),
                style: RdType.body(p),
              ),
              const SizedBox(height: 4),
              Text(
                [
                  l10n.redesignImportFoundExisting(existing),
                  l10n.redesignImportFoundNew(created),
                ].join(' · '),
                style: RdType.meta(p),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (plan.questions.isEmpty)
          RdCard(child: Text(l10n.redesignImportQuestionsNone, style: RdType.body(p)))
        else ...[
          RdSectionHeader(l10n.redesignImportQuestionsTitle(plan.questions.length)),
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(l10n.redesignImportQuestionsIntro, style: RdType.meta(p, size: 13)),
          ),
          for (final q in plan.questions) ...[
            _QuestionCard(plan: plan, question: q, answer: d.answers[q.key], onAnswer: (a) => _controller.answer(q.key, a)),
            const SizedBox(height: 10),
          ],
        ],
        const SizedBox(height: 10),
        RdSectionHeader(l10n.redesignImportKnownTitle),
        RdCard(child: Text(l10n.redesignImportKnownText(plan.instruments.length), style: RdType.body(p))),
        const SizedBox(height: 20),
        RdSectionHeader(l10n.redesignImportOptionsTitle),
        RdGroupedList(
          children: [
            RdImportSwitchRow(
              title: l10n.redesignImportOptionFassung,
              detail: l10n.redesignImportOptionFassungDetail,
              value: d.proposeFassung,
              onChanged: _controller.setProposeFassung,
            ),
            RdImportSwitchRow(
              title: l10n.redesignImportOptionWord,
              detail: l10n.redesignImportOptionWordDetail,
              value: d.skipWordBesidePdf,
              onChanged: _controller.setSkipWordBesidePdf,
            ),
          ],
        ),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // 3 Prüfen

  Widget _review(BuildContext context, RdImportState state) {
    final p = context.rd;
    final l10n = context.l10n;
    final plan = state.plan!;
    final d = state.decisions;
    final states = {for (final w in plan.works) w.key: rdWorkState(plan, d, w)};
    final summary = rdImportSummary(plan, d);
    final open = plan.works.where((w) => states[w.key]!.open).toList();
    final created = plan.works.where((w) => states[w.key]!.target.isNew).toList();
    final filter = _filter ?? (open.isNotEmpty ? _Filter.open : _Filter.all);
    final shown = switch (filter) {
      _Filter.open => [for (final w in plan.works) if (states[w.key]!.open || d.confirmed.contains(w.key) && states[w.key]!.flags.isNotEmpty) w],
      _Filter.created => created,
      _Filter.all => plan.works,
    };
    return RdImportFrame(
      backLabel: l10n.redesignImportStepRead,
      onBack: _back,
      title: l10n.redesignImportStepReview,
      step: 3,
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (summary.open > 0) ...[
            Text(l10n.redesignImportOpenHint(summary.open), style: RdType.meta(p, size: 13)),
            const SizedBox(height: 8),
          ],
          RdPrimaryButton(
            label: l10n.redesignImportUploadButton(summary.take),
            onPressed: summary.take == 0 ? null : _startUpload,
          ),
        ],
      ),
      children: [
        RdSegmented<_Filter>(
          values: _Filter.values,
          selected: filter,
          labelOf: (f) => switch (f) {
            _Filter.open => l10n.redesignImportReviewOpen(open.length),
            _Filter.created => l10n.redesignImportReviewNew(created.length),
            _Filter.all => l10n.redesignImportReviewAll(plan.works.length),
          },
          onChanged: (f) => setState(() => _filter = f),
        ),
        const SizedBox(height: 12),
        Text(l10n.redesignImportReviewIntro, style: RdType.meta(p, size: 13)),
        const SizedBox(height: 12),
        if (shown.isEmpty)
          RdCard(child: Text(l10n.redesignImportReviewEmpty, style: RdType.body(p)))
        else
          RdGroupedList(
            children: [
              for (final w in shown)
                _WorkRow(
                  title: w.folderName,
                  subtitle: [
                    rdImportTargetText(context, plan, states[w.key]!.target),
                    if (!states[w.key]!.target.skip)
                      l10n.redesignImportReviewCounts(states[w.key]!.takeCount, states[w.key]!.skipCount),
                  ].join(' · '),
                  pills: rdImportFlagPills(context, states[w.key]!),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => RdImportWorkPage(workKey: w.key)),
                  ),
                ),
            ],
          ),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // 4 Hochladen

  Widget _upload(BuildContext context, RdImportState state) {
    final p = context.rd;
    final l10n = context.l10n;
    final upload = state.upload;
    final plan = state.plan;
    if (upload == null || plan == null) return _source(context);
    final finished = state.step == RdImportStep.done;
    final ok = upload.succeeded;
    final summary = rdImportSummary(plan, state.decisions);
    final retry = {for (final f in upload.failures) if (f.path.isNotEmpty) f.path};

    if (!finished) {
      final value = upload.total == 0 ? 0.0 : upload.done / upload.total;
      return RdImportFrame(
        backLabel: l10n.redesignTabWorks,
        onBack: _back,
        title: l10n.redesignImportUploadTitle,
        step: 4,
        children: [
          RdCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.redesignImportUploadProgress(upload.done, upload.total),
                        style: RdType.section(p),
                      ),
                    ),
                    Text('${(value * 100).round()} %', style: RdType.meta(p)),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(value: value, minHeight: 10, color: p.primary, backgroundColor: p.track),
                ),
                if (upload.current != null) ...[
                  const SizedBox(height: 10),
                  Text(upload.current!, style: RdType.meta(p, size: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: p.soft, borderRadius: BorderRadius.circular(14)),
                  child: Text(l10n.redesignImportKeepOpen, style: TextStyle(color: p.softText, fontSize: 14)),
                ),
              ],
            ),
          ),
        ],
      );
    }

    final failures = upload.failures;
    return RdImportFrame(
      backLabel: l10n.redesignTabWorks,
      onBack: _back,
      title: l10n.redesignImportDoneTitle,
      step: 4,
      bottom: RdPrimaryButton(label: l10n.redesignImportDoneToWorks, onPressed: () => Navigator.of(context).pop(true)),
      children: [
        RdCard(
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: failures.isEmpty ? p.presentSoft : p.lateSoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(failures.isEmpty ? Icons.check : Icons.priority_high, color: failures.isEmpty ? p.present : p.late),
              ),
              const SizedBox(width: 14),
              Expanded(child: Text(l10n.redesignImportDoneText(ok), style: RdType.body(p))),
            ],
          ),
        ),
        if (upload.aborted) ...[
          const SizedBox(height: 12),
          RdCard(child: Text(l10n.redesignImportDoneAborted, style: RdType.body(p).copyWith(color: p.absent))),
        ],
        if (state.driveFolder != null) ...[
          const SizedBox(height: 12),
          RdCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l10n.redesignImportUnshareTitle, style: RdType.section(p)),
                const SizedBox(height: 4),
                Text(l10n.redesignImportUnshareText, style: RdType.body(p)),
                const SizedBox(height: 12),
                RdOutlineButton(
                  label: l10n.redesignImportUnshareOpen,
                  icon: Icons.open_in_new,
                  onPressed: () => _openDrive(state.driveFolder),
                ),
              ],
            ),
          ),
        ],
        if (upload.learnFailed) ...[
          const SizedBox(height: 12),
          RdCard(child: Text(l10n.songsFlutterLearnFailed, style: RdType.body(p).copyWith(color: p.late))),
        ],
        const SizedBox(height: 16),
        RdGroupedList(
          children: [
            RdListRow(title: l10n.redesignImportDoneNewWorks, value: '${upload.newWorks}', showChevron: false),
            if (upload.newGroups > 0) RdListRow(title: l10n.redesignImportDoneNewGroups, value: '${upload.newGroups}', showChevron: false),
            RdListRow(title: l10n.redesignImportDoneLearned, value: '${upload.learned}', showChevron: false),
            RdListRow(title: l10n.redesignImportDoneSkipped, value: '${summary.skip}', showChevron: false),
            if (summary.open > 0) RdListRow(title: l10n.redesignImportDoneOpen, value: '${summary.open}', showChevron: false),
            if (failures.isNotEmpty)
              RdListRow(title: l10n.redesignImportDoneFailed, value: '${failures.length}', showChevron: false, titleColor: p.absent),
          ],
        ),
        if (failures.isNotEmpty) ...[
          const SizedBox(height: 16),
          RdGroupedList(
            children: [
              for (final f in failures.take(50))
                RdListRow(
                  title: f.path.isEmpty ? f.error : f.path.split('/').last,
                  subtitle: f.path.isEmpty ? null : '${f.work} · ${f.error}',
                  showChevron: false,
                ),
            ],
          ),
          if (retry.isNotEmpty) ...[
            const SizedBox(height: 12),
            RdOutlineButton(
              label: l10n.redesignImportDoneRetry,
              icon: Icons.refresh,
              onPressed: () => _controller.upload(only: retry),
            ),
          ],
        ],
        if (summary.open > 0) ...[
          const SizedBox(height: 16),
          Text(
            state.driveFolder != null ? l10n.redesignImportDoneAgainHintDrive : l10n.redesignImportDoneAgainHint,
            style: RdType.meta(p, size: 13),
          ),
        ],
        const SizedBox(height: 16),
        RdTextLink(
          label: l10n.redesignImportDoneAnother,
          onTap: () {
            setState(() {
              _mode = null;
              _link.clear();
              _checked = '';
              _check = null;
            });
            _controller.restart();
          },
        ),
      ],
    );
  }
}

/// A question about an unknown part name with its answers as chips.
class _QuestionCard extends StatelessWidget {
  const _QuestionCard({required this.plan, required this.question, required this.answer, required this.onAnswer});

  final RdImportPlan plan;
  final RdImportQuestion question;
  final RdImportCategory? answer;
  final ValueChanged<RdImportCategory?> onAnswer;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final suggestion = question.suggestion == null ? null : RdImportCategory(instrumentId: question.suggestion);
    final label = question.label;
    final newName = label.isEmpty ? label : label[0].toUpperCase() + label.substring(1);
    final newGroup = answer?.newGroup != null ? answer! : RdImportCategory(newGroup: newName);
    final picked = answer != null && answer != suggestion && answer?.newGroup == null && answer != RdImportCategory.other ? answer : null;
    void toggle(RdImportCategory c) => onAnswer(answer == c ? null : c);
    return RdCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.redesignImportQuestionTitle(label), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: p.text)),
          const SizedBox(height: 2),
          Text(l10n.redesignImportQuestionWhere(question.fileCount, question.works.join(', ')), style: RdType.meta(p, size: 13)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (suggestion != null)
                RdChoiceChip(
                  label: rdImportCategoryLabel(context, plan, suggestion),
                  selected: answer == suggestion,
                  onTap: () => toggle(suggestion),
                ),
              if (picked != null)
                RdChoiceChip(label: rdImportCategoryLabel(context, plan, picked), selected: true, onTap: () => onAnswer(null)),
              RdChoiceChip(
                label: l10n.redesignImportAnswerOther,
                selected: false,
                onTap: () async {
                  final c = await rdPickImportCategory(context, plan, current: answer, title: l10n.redesignImportQuestionTitle(label));
                  if (c != null) onAnswer(c);
                },
              ),
              if (newName.isNotEmpty)
                RdChoiceChip(
                  label: l10n.redesignImportAnswerNewGroup(newGroup.newGroup!),
                  selected: answer == newGroup,
                  onTap: () async {
                    if (answer == newGroup) return onAnswer(null);
                    final name = await showAppPrompt(
                      context,
                      title: l10n.redesignImportNewGroupTitle,
                      initialValue: newName,
                      confirmText: l10n.redesignImportNewGroupTitle,
                    );
                    if (name != null && name.trim().isNotEmpty) onAnswer(RdImportCategory(newGroup: name.trim()));
                  },
                ),
              RdChoiceChip(
                label: l10n.redesignImportAnswerNone,
                selected: answer == RdImportCategory.other,
                onTap: () => toggle(RdImportCategory.other),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A Werk in the review list: name, target and counts, the pills below.
class _WorkRow extends StatelessWidget {
  const _WorkRow({required this.title, required this.subtitle, required this.pills, required this.onTap});

  final String title;
  final String subtitle;
  final List<Widget> pills;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: p.text)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: RdType.meta(p, size: 13)),
                    if (pills.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(spacing: 6, runSpacing: 6, children: pills),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, size: 20, color: p.text2),
            ],
          ),
        ),
      ),
    );
  }
}
