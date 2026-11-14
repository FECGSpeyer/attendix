import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:attendix/shared/widgets/layout/sheet_drag.dart';
import 'package:attendix/core/theme/app_icons.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/providers/attendance_detail_providers.dart';
import '../../../../../core/providers/attendance_providers.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/redesign/rd_theme.dart';
import '../../../../../core/utils/quill_utils.dart';
import '../../../../../core/utils/toast_helper.dart';
import '../../../../../data/models/attendance/attendance.dart';
import '../../../../../l10n/l10n.dart';
import '../../../../../core/utils/error_message.dart';
import '../../../../../shared/widgets/adaptive/adaptive.dart';
import '../../../../../core/services/native/native_file_service.dart';
import '../../../../redesign/presentation/widgets/rd_widgets.dart';

/// "Beschreibung & Anhang" editor of a Termin (Ionic descriptionModal):
/// rich text description (stored as HTML like the Ionic quill editor) and
/// one file attachment (upload, open, remove).
Future<void> showDescriptionAttachmentSheet(BuildContext context, {required Attendance attendance}) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true, // IOS_SHELL2: above the tab bar
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: context.rdSkin != null ? context.rd.bg : null,
    builder:
        (ctx) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: AppDraggableSheet(
            expand: false,
            initialChildSize: 0.8,
            minChildSize: 0.4,
            maxChildSize: 0.95,
            builder:
                (ctx, controller) => DescriptionAttachmentEditor(attendance: attendance, scrollController: controller),
          ),
        ),
  );
}

class DescriptionAttachmentEditor extends ConsumerStatefulWidget {
  const DescriptionAttachmentEditor({super.key, required this.attendance, this.scrollController});

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
      if (mounted) {
        ToastHelper.showError(context, context.l10n.attendanceFlutterSaveFailedWith(friendlyErrorMessage(e)));
      }
    }
  }

  Future<void> _upload() async {
    final repo = ref.read(attendanceRepositoryWithTenantProvider);
    final result = await FilePicker.platform.pickFiles(withData: true);
    final file = result?.files.firstOrNull;
    if (file == null || file.bytes == null) return;
    setState(() => _busy = true);
    try {
      final uploaded = await repo.uploadAttachment(_id, file.bytes!, file.name, previousFileName: _attachmentName);
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
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    // Ionic Browser.open: in-app browser in the native app.
    await NativeFileService.openLinkInApp(uri);
  }

  Widget _toolbar() => QuillSimpleToolbar(
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
  );

  Widget _editor() => QuillEditor.basic(
    controller: _quill,
    focusNode: _focus,
    config: QuillEditorConfig(scrollable: false, placeholder: context.l10n.attendanceDescriptionPlaceholder),
  );

  /// Beta (redesign) layout: editor in a card, attachment as a list row.
  Widget _buildBeta(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final name = _attachmentName ?? l10n.selfServiceAttachment;
    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        Semantics(header: true, child: Text(l10n.attendanceDescriptionAttachment, style: RdType.cardTitle(p))),
        const SizedBox(height: 16),
        RdCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _toolbar(),
              Divider(height: 1, thickness: 1, color: p.line),
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 200),
                child: Padding(padding: const EdgeInsets.all(14), child: _editor()),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        RdGroupLabel(l10n.selfServiceAttachment),
        RdGroupedList(
          children: [
            if (_busy)
              RdListRow(
                title: _attachmentUrl == null ? l10n.attendanceFlutterAddAttachment : name,
                leading: const RdRowIcon(Icons.attach_file),
                trailing: const SizedBox(width: 20, height: 20, child: AppSpinner(strokeWidth: 2)),
                showChevron: false,
              )
            else if (_attachmentUrl == null)
              RdListRow(
                key: const Key('rd-desc-add-attachment'),
                title: l10n.attendanceFlutterAddAttachment,
                titleColor: p.link,
                leading: const RdRowIcon(Icons.attach_file),
                showChevron: false,
                onTap: _upload,
              )
            else ...[
              RdListRow(title: name, leading: const RdRowIcon(Icons.description_outlined), onTap: _open),
              RdListRow(
                key: const Key('rd-desc-remove-attachment'),
                title: l10n.attendanceFlutterRemoveAttachment,
                titleColor: p.absent,
                leading: RdRowIcon(Icons.delete_outline, color: p.absent, background: p.absentSoft),
                showChevron: false,
                onTap: _remove,
              ),
            ],
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (context.rdSkin != null) return _buildBeta(context);
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
              _toolbar(),
              const Divider(height: 1),
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 200),
                child: Padding(padding: const EdgeInsets.all(12), child: _editor()),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Text(context.l10n.selfServiceAttachment, style: const TextStyle(fontWeight: FontWeight.w500)),
            ),
            if (_busy)
              const SizedBox(width: 24, height: 24, child: AppSpinner(strokeWidth: 2))
            else if (_attachmentUrl == null)
              IconButton(
                tooltip: context.l10n.attendanceFlutterAddAttachment,
                icon: Icon(AppIcons.attachFile),
                onPressed: _upload,
              )
            else ...[
              Flexible(
                child: ActionChip(
                  avatar: Icon(AppIcons.descriptionOutlined, size: 18),
                  label: Text(_attachmentName ?? context.l10n.selfServiceAttachment, overflow: TextOverflow.ellipsis),
                  onPressed: _open,
                ),
              ),
              IconButton(
                tooltip: context.l10n.attendanceFlutterRemoveAttachment,
                icon: Icon(AppIcons.cancelOutlined, color: AppColors.danger),
                onPressed: _remove,
              ),
            ],
          ],
        ),
      ],
    );
  }
}
