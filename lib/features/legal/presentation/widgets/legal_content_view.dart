import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/legal_providers.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/quill_utils.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/common/error_state_view.dart';

/// Renders the legal HTML (Impressum & Datenschutz) loaded from
/// `legal_content`. Port of Ionic `LegalContentComponent`.
///
/// The HTML is converted to a Quill document and shown read-only (same
/// approach as meeting notes) so no extra HTML-rendering dependency is needed.
class LegalContentView extends ConsumerWidget {
  const LegalContentView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contentAsync = ref.watch(legalContentProvider);
    return contentAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(AppDimensions.paddingL),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => ErrorStateView(
        error: error,
        title: context.l10n.legalLoadFailed,
        onRetry: () => ref.invalidate(legalContentProvider),
      ),
      data: (html) => _LegalHtml(html: html),
    );
  }
}

class _LegalHtml extends StatefulWidget {
  const _LegalHtml({required this.html});

  final String html;

  @override
  State<_LegalHtml> createState() => _LegalHtmlState();
}

class _LegalHtmlState extends State<_LegalHtml> {
  late QuillController _controller;

  @override
  void initState() {
    super.initState();
    _controller = _build(widget.html);
  }

  @override
  void didUpdateWidget(covariant _LegalHtml oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.html != widget.html) {
      _controller.dispose();
      _controller = _build(widget.html);
    }
  }

  QuillController _build(String html) => QuillController(
        document: QuillUtils.documentFromNotesString(html),
        selection: const TextSelection.collapsed(offset: 0),
        readOnly: true,
      );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return QuillEditor.basic(
      controller: _controller,
      config: const QuillEditorConfig(
        showCursor: false,
        scrollable: false,
        padding: EdgeInsets.zero,
      ),
    );
  }
}

/// Opens the legal text as a full-screen modal (Ionic `LegalModalComponent`).
Future<void> showLegalModal(BuildContext context) {
  return Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (context) => Scaffold(
        appBar: AppBar(
          title: Text(context.l10n.legalTitle),
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: context.l10n.commonClose,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
        body: const SingleChildScrollView(
          padding: EdgeInsets.all(AppDimensions.paddingM),
          child: LegalContentView(),
        ),
      ),
    ),
  );
}
