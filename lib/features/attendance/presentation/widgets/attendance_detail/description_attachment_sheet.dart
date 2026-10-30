import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../../core/providers/attendance_detail_providers.dart';
import '../../../../../core/providers/attendance_providers.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/utils/quill_utils.dart';
import '../../../../../core/utils/toast_helper.dart';
import '../../../../../data/models/attendance/attendance.dart';
import '../../../../../l10n/l10n.dart';
import '../../../../../core/utils/error_message.dart';
import '../../../../../shared/widgets/adaptive/adaptive.dart';

/// "Beschreibung & Anhang" editor of a Termin (Ionic descriptionModal):
/// rich text description (stored as HTML like the Ionic quill editor) and
/// one file attachment (upload, open, remove).
Future<void> showDescriptionAttachmentSheet(
  BuildContext context, {
  required Attendance attendance,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true, // IOS_SHELL2: above the tab bar
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.8,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (ctx, controller) => DescriptionAttachmentEditor(
          attendance: attendance,
          scrollController: controller,
        ),
      ),
    ),
  );
}

class DescriptionAttachmentEditor extends ConsumerStatefulWidget {
  const DescriptionAttachmentEditor({
    super.key,
    required this.attendance,
    this.scrollController,
  });

  final Attendance attendance;
  final ScrollController? scrollController;

  @override
  ConsumerState<DescriptionAttachmentEditor> createState() => _DescriptionAttachmentEditorState();
}

class _DescriptionAttachmentEditorState extends ConsumerState<DescriptionAttachmentEditor> {
  late final QuillController _quill;
  final FocusNode _focus = FocusNode();
  late String? _savedHtml = widget.attendance.description;
  late String? _attachmentUrl = widget.attendance.attachmentUrl;
  late String? _attachmentName = widget.attendance.attachmentName;
  bool _busy = false;
  // Kept so the description can still be saved from dispose().
  late final ProviderContainer _container = ProviderScope.containerOf(context, listen: false);

  @override
  void initState() {
    super.initState();
    _quill = QuillController(
      document: QuillUtils.documentFromNotesString(widget.attendance.description),
      selection: const TextSelection.collapsed(offset: 0),
    );
    // Ionic saves on blur
    _container; // resolve while the element is mounted
    _focus.addListener(() {
      if (!_focus.hasFocus) _saveDescription();
    });
  }

  @override
  void dispose() {
    // Save pending changes when the sheet is closed.
    _saveDescription();
    _focus.dispose();
    _quill.dispose();
    super.dispose();
  }

  int get _id => widget.attendance.id!;

  Future<void> _saveDescription() async {
    final html = QuillUtils.notesHtmlFromDocument(_quill.document);
    if (html == _savedHtml) return;
    _savedHtml = html;
    try {
      final repo = _container.read(attendanceRepositoryWithTenantProvider);
      if (!repo.hasTenantId) return;
      await repo.updateAttendance(_id, {'description': html});
      _container.invalidate(attendanceDetailProvider(_id));
    } catch (e) {
      if (mounted) ToastHelper.showError(context, context.l10n.attendanceFlutterSaveFailedWith(friendlyErrorMessage(e)));
    }
  }

  Future<void> _upload() async {
    final repo = ref.read(attendanceRepositoryWithTenantProvider);
    final result = await FilePicker.platform.pickFiles(withData: true);
    final file = result?.files.firstOrNull;
    if (file == null || file.bytes == null) return;
    setState(() => _busy = true);
    try {
      final uploaded = await repo.uploadAttachment(_id, file.bytes!, file.name,
          previousFileName: _attachmentName);
      if (!mounted) return;
      setState(() {
        _attachmentUrl = uploaded.url;
        _attachmentName = uploaded.name;
      });
      ref.invalidate(attendanceDetailProvider(_id));
      ToastHelper.showSuccess(context, context.l10n.attendanceAttachmentUploaded);
    } catch (_) {
      if (mounted) ToastHelper.showError(context, context.l10n.attendanceUploadFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove() async {
    setState(() => _busy = true);
    try {
      final repo = ref.read(attendanceRepositoryWithTenantProvider);
      await repo.removeAttachment(_id, _attachmentName);
      if (!mounted) return;
      setState(() {
        _attachmentUrl = null;
        _attachmentName = null;
      });
      ref.invalidate(attendanceDetailProvider(_id));
    } catch (e) {
      if (mounted) ToastHelper.showError(context, context.l10n.attendanceFlutterErrorWith(friendlyErrorMessage(e)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _open() async {
    final url = _attachmentUrl;
    if (url == null) return;
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        Text(context.l10n.attendanceDescriptionAttachment, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              QuillSimpleToolbar(
                controller: _quill,
                config: const QuillSimpleToolbarConfig(
                  multiRowsDisplay: false,
                  showBoldButton: true,
                  showItalicButton: true,
                  showUnderLineButton: true,
                  showListBullets: true,
                  showListNumbers: true,
                  showLink: true,
                  showStrikeThrough: false,
                  showHeaderStyle: false,
                  showListCheck: false,
                  showColorButton: false,
                  showBackgroundColorButton: false,
                  showClearFormat: false,
                  showInlineCode: false,
                  showCodeBlock: false,
                  showQuote: false,
                  showIndent: false,
                  showSearchButton: false,
                  showSubscript: false,
                  showSuperscript: false,
                  showFontFamily: false,
                  showFontSize: false,
                  showAlignmentButtons: false,
                  showDirection: false,
                  showSmallButton: false,
                  showUndo: false,
                  showRedo: false,
                ),
              ),
              const Divider(height: 1),
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 200),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: QuillEditor.basic(
                    controller: _quill,
                    focusNode: _focus,
                    config: QuillEditorConfig(
                      scrollable: false,
                      placeholder: context.l10n.attendanceDescriptionPlaceholder,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: Text(context.l10n.selfServiceAttachment, style: const TextStyle(fontWeight: FontWeight.w500))),
            if (_busy)
              const SizedBox(width: 24, height: 24, child: AppSpinner(strokeWidth: 2))
            else if (_attachmentUrl == null)
              IconButton(
                tooltip: context.l10n.attendanceFlutterAddAttachment,
                icon: const Icon(Icons.attach_file),
                onPressed: _upload,
              )
            else ...[
              Flexible(
                child: ActionChip(
                  avatar: const Icon(Icons.description_outlined, size: 18),
                  label: Text(_attachmentName ?? context.l10n.selfServiceAttachment, overflow: TextOverflow.ellipsis),
                  onPressed: _open,
                ),
              ),
              IconButton(
                tooltip: context.l10n.attendanceFlutterRemoveAttachment,
                icon: const Icon(Icons.cancel_outlined, color: AppColors.danger),
                onPressed: _remove,
              ),
            ],
          ],
        ),
      ],
    );
  }
}
