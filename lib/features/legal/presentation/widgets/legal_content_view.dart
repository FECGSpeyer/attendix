import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/legal_providers.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/quill_utils.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/common/error_state_view.dart';
import '../../../../shared/widgets/dialogs/ion_modal.dart';

/// Renders the legal HTML (Impressum & Datenschutz) loaded from
/// `legal_content`. Port of Ionic `LegalContentComponent`.
///
/// Fills its parent (use it as a page/modal body): the text scrolls and is
/// capped at 800px like the `/legal` page; loading and error states are
/// centred, and a retry shows the spinner again (no stale error while
/// refreshing).
///
/// The HTML is converted to a Quill document and shown read-only (same
/// approach as meeting notes) so no extra HTML-rendering dependency is needed.
class LegalContentView extends ConsumerWidget {
  const LegalContentView({super.key});

  /// Max content width (Ionic `/legal` reading width).
  static const double maxWidth = 800;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contentAsync = ref.watch(legalContentProvider);
    return contentAsync.when(
      skipLoadingOnRefresh: false,
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => ErrorStateView(
        error: error,
        title: context.l10n.legalLoadFailed,
        onRetry: () => ref.invalidate(legalContentProvider),
      ),
      data: (html) => SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimensions.paddingM),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: maxWidth),
            child: _LegalHtml(html: html),
          ),
        ),
      ),
    );
  }
}

/// Ionic legal-modal.component.scss typography: h1 1.5rem, h2 1.25rem,
/// h3 1.1rem, h4 1rem (1rem top margin), p/ul 0.95rem with line-height 1.5.
DefaultStyles legalTextStyles(BuildContext context) {
  final color = Theme.of(context).textTheme.bodyMedium?.color;
  DefaultTextBlockStyle heading(double size) => DefaultTextBlockStyle(
        TextStyle(
            fontSize: size,
            height: 1.25,
            fontWeight: FontWeight.w600,
            color: color),
        HorizontalSpacing.zero,
        const VerticalSpacing(16, 4),
        VerticalSpacing.zero,
        null,
      );
  return DefaultStyles(
    h1: heading(24),
    h2: heading(20),
    h3: heading(17.6),
    h4: heading(16),
    paragraph: DefaultTextBlockStyle(
      TextStyle(fontSize: 15.2, height: 1.5, color: color),
      HorizontalSpacing.zero,
      VerticalSpacing.zero,
      VerticalSpacing.zero,
      null,
    ),
  );
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
      config: QuillEditorConfig(
        showCursor: false,
        scrollable: false,
        padding: EdgeInsets.zero,
        customStyles: legalTextStyles(context),
      ),
    );
  }
}

/// Opens the legal text like Ionic `LegalModalComponent`: a centred
/// 600 × 500 modal on desktop, full screen on phones.
Future<void> showLegalModal(BuildContext context) {
  return showIonModal<void>(
    context,
    builder: (context) {
      final theme = Theme.of(context);
      return Scaffold(
        // Ionic: --background: var(--ion-background-color, #fff)
        backgroundColor: theme.cardTheme.color ?? theme.colorScheme.surface,
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
        body: const LegalContentView(),
      );
    },
  );
}
