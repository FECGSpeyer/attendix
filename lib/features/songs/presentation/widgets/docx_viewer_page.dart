import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/native/native_file_service.dart';
import '../../../../core/services/pdf_bytes_loader.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';
import '../../../../shared/widgets/common/escape_to_close.dart';
import '../../data/docx_document.dart';

const docxMimeType = 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';

/// DOCX_VIEWER: in-app viewer for Word files, the same full-screen page as
/// the PDF viewer (grey background, white page, file name on top). The text
/// flows to the screen width; on iPhone/iPad/Android the share button hands
/// the original file to Word, Pages, print …, elsewhere "open externally"
/// opens it in Word / Pages / the browser.
class DocxViewerPage extends StatefulWidget {
  final String url;
  final String fileName;

  const DocxViewerPage({super.key, required this.url, required this.fileName});

  @override
  State<DocxViewerPage> createState() => _DocxViewerPageState();
}

class _DocxViewerPageState extends State<DocxViewerPage> {
  DocxDocument? _document;
  Uint8List? _bytes;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      // Cached on iOS/Android like the PDFs: opens offline after the first time.
      final bytes = await PdfBytesLoader.load(widget.url);
      final document = await compute(DocxDocument.parse, bytes);
      if (!mounted) return;
      setState(() {
        _bytes = bytes;
        _document = document;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is FormatException ? e.message : friendlyErrorMessage(e);
        _isLoading = false;
      });
    }
  }

  /// iPhone/iPad and Android: the system share sheet (Word, Pages, print,
  /// AirDrop, Dateien …).
  static bool get _canShareFile =>
      !kIsWeb && (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.android);

  Future<void> _openExternally() async {
    final ok = await NativeFileService.openUrl(widget.url, fileName: widget.fileName);
    if (!ok && mounted) ToastHelper.showError(context, context.l10n.songsFlutterOpenFileFailed);
  }

  Future<void> _share(BuildContext button) async {
    final bytes = _bytes;
    if (bytes == null) return _openExternally();
    final box = button.findRenderObject() as RenderBox?;
    final origin = box == null || !box.hasSize ? null : box.localToGlobal(Offset.zero) & box.size;
    final name =
        widget.fileName.toLowerCase().endsWith('.docx')
            ? widget.fileName
            : '${widget.fileName.isEmpty ? 'dokument' : widget.fileName}.docx';
    try {
      final result = await Share.shareXFiles(
        [XFile.fromData(bytes, name: name, mimeType: docxMimeType)],
        subject: widget.fileName,
        fileNameOverrides: [name],
        sharePositionOrigin: origin,
      );
      if (result.status != ShareResultStatus.unavailable) return;
    } catch (_) {
      // No file sharing here: fall back to the external app.
    }
    await _openExternally();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.brightness == Brightness.dark ? Colors.black : const Color(0xFFE5E5EA),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(widget.fileName, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          if (_canShareFile && _error == null)
            Builder(
              builder:
                  (button) => IconButton(
                    icon: Icon(Icons.adaptive.share),
                    tooltip: context.l10n.redesignWorkFileShare,
                    onPressed: _bytes == null ? null : () => _share(button),
                  ),
            )
          else
            IconButton(
              icon: const Icon(Icons.open_in_new),
              tooltip: context.l10n.coreFlutterOpenExternally,
              onPressed: _openExternally,
            ),
        ],
      ),
      body: _buildContent(),
    );
  }

  Widget _buildContent() {
    final l10n = context.l10n;
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const AppSpinner(),
            const SizedBox(height: AppDimensions.paddingM),
            Text(l10n.songsFlutterDocxLoading),
          ],
        ),
      );
    }
    final document = _document;
    if (_error != null || document == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.paddingL),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: AppColors.danger),
              const SizedBox(height: AppDimensions.paddingM),
              Text(
                l10n.songsFlutterDocxLoadFailed,
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppDimensions.paddingS),
              Text(_error ?? '', style: const TextStyle(color: AppColors.medium), textAlign: TextAlign.center),
              const SizedBox(height: AppDimensions.paddingL),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                    _error = null;
                  });
                  _load();
                },
                icon: const Icon(Icons.refresh),
                label: IonButtonLabel(l10n.messagesRetry),
              ),
              const SizedBox(height: AppDimensions.paddingS),
              TextButton.icon(
                onPressed: _openExternally,
                icon: const Icon(Icons.open_in_new),
                label: IonButtonLabel(l10n.coreFlutterOpenExternally),
              ),
            ],
          ),
        ),
      );
    }

    final narrow = MediaQuery.sizeOf(context).width < 600;
    return SingleChildScrollView(
      padding: EdgeInsets.all(narrow ? 8 : 24),
      child: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            // About the width of an A4 page.
            constraints: const BoxConstraints(maxWidth: 820),
            child: Material(
              color: Colors.white,
              elevation: 1,
              borderRadius: BorderRadius.circular(2),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: narrow ? 20 : 64, vertical: narrow ? 24 : 56),
                child:
                    document.blocks.isEmpty
                        ? Text(l10n.songsFlutterDocxEmpty, style: const TextStyle(color: Colors.black54))
                        : SelectionArea(child: DocxView(document: document)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The blocks of a [DocxDocument] on a white page (always black text, also
/// in dark mode, like paper).
class DocxView extends StatelessWidget {
  final DocxDocument document;

  const DocxView({super.key, required this.document});

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle.merge(
      style: const TextStyle(color: Colors.black, fontSize: _basePx, height: 1.35),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: _blocks(document.blocks)),
    );
  }

  /// 11 pt (Word's default) shown at 15 logical pixels.
  static const double _basePx = 15;
  static double _px(double pt) => pt * _basePx / 11;

  static List<Widget> _blocks(List<DocxBlock> blocks) => [
    for (final block in blocks)
      switch (block) {
        DocxParagraph() => _paragraph(block),
        DocxTable() => Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: _table(block)),
      },
  ];

  static const _headingSizes = <int, double>{0: 26, 1: 20, 2: 16, 3: 14, 4: 12, 5: 11, 6: 11};

  static Widget _paragraph(DocxParagraph p) {
    final heading = p.headingLevel;
    final spans = <InlineSpan>[];
    for (final inline in p.inlines) {
      switch (inline) {
        case DocxText():
          spans.add(TextSpan(text: inline.text, style: _textStyle(inline, heading)));
        case DocxImage():
          spans.add(WidgetSpan(child: _image(inline)));
      }
    }
    if (spans.isEmpty || p.isEmpty) {
      // An empty paragraph keeps its line (Word users space with them).
      return const SizedBox(height: _basePx * 1.35);
    }
    final text = Text.rich(
      TextSpan(children: spans),
      textAlign: switch (p.align) {
        DocxAlign.center => TextAlign.center,
        DocxAlign.right => TextAlign.right,
        DocxAlign.justify => TextAlign.justify,
        DocxAlign.left => TextAlign.left,
      },
    );
    final topGap = heading == null ? 0.0 : (heading <= 1 ? 14.0 : 10.0);
    final label = p.listLabel;
    Widget child = text;
    if (label != null) {
      child = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 18.0 * p.listLevel),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 24),
            child: Padding(padding: const EdgeInsets.only(right: 6), child: Text(label)),
          ),
          Expanded(child: text),
        ],
      );
    } else if (p.indent > 0) {
      child = Padding(padding: EdgeInsets.only(left: _px(p.indent)), child: text);
    }
    return Padding(padding: EdgeInsets.only(top: topGap, bottom: label == null ? 6 : 2), child: child);
  }

  static TextStyle _textStyle(DocxText t, int? heading) {
    final size =
        t.fontSize != null
            ? _px(t.fontSize!)
            : heading != null
            ? _px(_headingSizes[heading]!)
            : null;
    final script = t.superscript || t.subscript;
    final decorations = [if (t.underline) TextDecoration.underline, if (t.strike) TextDecoration.lineThrough];
    return TextStyle(
      fontWeight: t.bold || (heading != null && t.fontSize == null) ? FontWeight.bold : null,
      fontStyle: t.italic ? FontStyle.italic : null,
      decoration: decorations.isEmpty ? null : TextDecoration.combine(decorations),
      fontSize: script ? (size ?? _basePx) * 0.7 : size,
      color: t.color == null ? null : Color(t.color!),
      backgroundColor: t.background == null ? null : Color(t.background!),
      fontFeatures: [
        if (t.superscript) const FontFeature.superscripts(),
        if (t.subscript) const FontFeature.subscripts(),
      ],
    );
  }

  /// The size from the document, shrunk to the page width (keeps the
  /// aspect ratio; no LayoutBuilder, tables measure their cells).
  static Widget _image(DocxImage image) {
    return Image.memory(
      image.bytes,
      width: image.width,
      fit: BoxFit.contain,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
    );
  }

  static Widget _table(DocxTable table) {
    const border = BorderSide(color: Colors.black38, width: 0.5);
    return Container(
      decoration: const BoxDecoration(border: Border(top: border, left: border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final row in table.rows)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final cell in row)
                    Expanded(
                      flex: cell.span,
                      child: Container(
                        decoration: BoxDecoration(
                          color: cell.background == null ? null : Color(cell.background!),
                          border: const Border(right: border, bottom: border),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisSize: MainAxisSize.min,
                          children: _blocks(cell.blocks),
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Opens [url] in the full-screen Word viewer (above the tab bar).
Future<void> showDocxViewer(BuildContext context, {required String url, required String fileName}) {
  return Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (context) => EscapeToClose(child: DocxViewerPage(url: url, fileName: fileName)),
    ),
  );
}
