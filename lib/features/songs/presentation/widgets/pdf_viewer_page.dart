import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/l10n.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../core/services/pdf_bytes_loader.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';

/// How the PDF viewer shows the pages (remembered on the device; until
/// switched, tablets start page by page and phones scroll).
enum PdfViewMode {
  /// All pages below each other, scrolled freely.
  scroll,

  /// One page at a time, a vertical swipe snaps to the next page.
  pages,
}

const pdfViewModeStorageKey = 'pdfViewer.mode';

/// In-app PDF viewer. PDF_SCROLL: a full-screen page (not a bottom sheet, its
/// drag-to-close gesture took every vertical swipe). Either all pages below
/// each other (scroll with one finger, zoom with two) or page by page (a
/// vertical swipe or a tap on the top / bottom edge turns the page; while
/// zoomed in, a swipe moves the page). The page pill at the bottom shows
/// "Seite x von y" and jumps a page up or down.
class PdfViewerPage extends StatefulWidget {
  final String url;
  final String fileName;

  const PdfViewerPage({
    super.key,
    required this.url,
    required this.fileName,
  });

  @override
  State<PdfViewerPage> createState() => _PdfViewerPageState();
}

class _PdfViewerPageState extends State<PdfViewerPage> {
  PdfDocument? _document;
  PdfControllerPinch? _scrollController;
  PdfController? _pagesController;
  PdfViewMode _mode = PdfViewMode.scroll;
  bool _isLoading = true;
  String? _error;
  int _currentPage = 1;
  int _totalPages = 0;

  @override
  void initState() {
    super.initState();
    _loadPdf();
  }

  @override
  void dispose() {
    _disposeControllers();
    _document?.close();
    super.dispose();
  }

  void _disposeControllers() {
    _scrollController?.dispose();
    _pagesController?.dispose();
    _scrollController = null;
    _pagesController = null;
  }

  /// A controller for the current mode, starting on the current page.
  void _createController() {
    final document = _document;
    if (document == null) return;
    _disposeControllers();
    if (_mode == PdfViewMode.scroll) {
      _scrollController = PdfControllerPinch(
        document: Future.value(document),
        initialPage: _currentPage,
      );
    } else {
      _pagesController = PdfController(
        document: Future.value(document),
        initialPage: _currentPage,
      );
    }
  }

  /// The mode chosen before on this device, null when never switched.
  static Future<PdfViewMode?> _storedMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final name = prefs.getString(pdfViewModeStorageKey);
      return PdfViewMode.values.where((m) => m.name == name).firstOrNull;
    } catch (_) {
      return null;
    }
  }

  void _toggleMode() {
    setState(() {
      _mode = _mode == PdfViewMode.scroll ? PdfViewMode.pages : PdfViewMode.scroll;
      _createController();
    });
    final mode = _mode;
    SharedPreferences.getInstance()
        .then((prefs) => prefs.setString(pdfViewModeStorageKey, mode.name))
        .catchError((_) => false);
  }

  Future<void> _loadPdf() async {
    try {
      // Cached on iOS/Android: opens offline after the first time.
      final bytes = await PdfBytesLoader.load(widget.url);
      final document = await PdfDocument.openData(bytes);
      final stored = await _storedMode();

      if (!mounted) {
        document.close();
        return;
      }
      // Tablets (on the stand) start page by page, phones scroll.
      final mode = stored ??
          (MediaQuery.sizeOf(context).shortestSide >= 600 ? PdfViewMode.pages : PdfViewMode.scroll);
      setState(() {
        _document = document;
        _totalPages = document.pagesCount;
        _mode = mode;
        _createController();
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = friendlyErrorMessage(e);
          _isLoading = false;
        });
      }
    }
  }

  void _goToPage(int page) {
    if (page < 1 || page > _totalPages) return;
    const duration = Duration(milliseconds: 300);
    _scrollController?.animateToPage(pageNumber: page, duration: duration, curve: Curves.easeInOut);
    _pagesController?.animateToPage(page, duration: duration, curve: Curves.easeInOut);
  }

  void _openExternally() => launchUrl(
        Uri.parse(widget.url),
        mode: LaunchMode.externalApplication,
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      // Grey behind the white pages, like iOS Vorschau.
      backgroundColor: theme.brightness == Brightness.dark
          ? Colors.black
          : const Color(0xFFE5E5EA),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.fileName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (_document != null && _totalPages > 1)
            IconButton(
              icon: Icon(_mode == PdfViewMode.scroll
                  ? Icons.auto_stories_outlined
                  : Icons.view_agenda_outlined),
              tooltip: _mode == PdfViewMode.scroll
                  ? context.l10n.songsFlutterPdfPagedMode
                  : context.l10n.songsFlutterPdfScrollMode,
              onPressed: _toggleMode,
            ),
          IconButton(
            icon: const Icon(Icons.open_in_new),
            tooltip: context.l10n.coreFlutterOpenExternally,
            onPressed: _openExternally,
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(child: _buildContent()),
          if (!_isLoading && _error == null && _totalPages > 1)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: AppDimensions.paddingM),
                  child: Center(child: _buildPagePill()),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const AppSpinner(),
            const SizedBox(height: AppDimensions.paddingM),
            Text(context.l10n.songsFlutterPdfLoading),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.paddingL),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: AppColors.danger),
              const SizedBox(height: AppDimensions.paddingM),
              Text(
                context.l10n.songsFlutterPdfLoadFailed,
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppDimensions.paddingS),
              Text(
                _error!,
                style: const TextStyle(color: AppColors.medium),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppDimensions.paddingL),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                    _error = null;
                  });
                  _loadPdf();
                },
                icon: const Icon(Icons.refresh),
                label: IonButtonLabel(context.l10n.messagesRetry),
              ),
              // Fallback when the in-app viewer is unavailable (e.g. pdf.js
              // blocked on web): open the file in the browser / system viewer.
              const SizedBox(height: AppDimensions.paddingS),
              TextButton.icon(
                onPressed: _openExternally,
                icon: const Icon(Icons.open_in_new),
                label: IonButtonLabel(context.l10n.coreFlutterOpenExternally),
              ),
            ],
          ),
        ),
      );
    }

    final builders = PdfViewBuilders<DefaultBuilderOptions>(
      options: const DefaultBuilderOptions(),
      documentLoaderBuilder: (_) => const Center(child: AppSpinner()),
      pageLoaderBuilder: (_) => const Center(child: AppSpinner()),
      errorBuilder: (_, error) => Center(
        child: Text(context.l10n.songsFlutterErrorWith(friendlyErrorMessage(error))),
      ),
    );

    final pagesController = _pagesController;
    if (pagesController != null) {
      // One page at a time, fitted to the screen; a vertical swipe snaps to
      // the next page. A tap on the top / bottom fifth turns the page too
      // (the edge areas only take taps, drags reach the pages).
      return LayoutBuilder(
        builder: (context, constraints) {
          final edge = constraints.maxHeight / 5;
          return Stack(
            children: [
              Positioned.fill(
                child: PdfView(
                  key: const ValueKey('pdf-pages'),
                  controller: pagesController,
                  scrollDirection: Axis.vertical,
                  pageSnapping: true,
                  onPageChanged: (page) => setState(() => _currentPage = page),
                  builders: builders,
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: edge,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  excludeFromSemantics: true,
                  onTap: () => _goToPage(_currentPage - 1),
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: edge,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  excludeFromSemantics: true,
                  onTap: () => _goToPage(_currentPage + 1),
                ),
              ),
            ],
          );
        },
      );
    }

    // All pages below each other, fitted to the width.
    return PdfViewPinch(
      key: const ValueKey('pdf-scroll'),
      controller: _scrollController!,
      scrollDirection: Axis.vertical,
      padding: 8,
      onPageChanged: (page) {
        setState(() => _currentPage = page);
      },
      builders: PdfViewPinchBuilders<DefaultBuilderOptions>(
        options: const DefaultBuilderOptions(),
        documentLoaderBuilder: (_) => const Center(
          child: AppSpinner(),
        ),
        pageLoaderBuilder: (_) => const Center(
          child: AppSpinner(),
        ),
        errorBuilder: (_, error) => Center(
          child: Text(context.l10n.songsFlutterErrorWith(friendlyErrorMessage(error))),
        ),
      ),
    );
  }

  /// Floating "Seite x von y" with a page up / down.
  Widget _buildPagePill() {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface.withValues(alpha: 0.94),
      elevation: 3,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_up),
            onPressed: _currentPage > 1 ? () => _goToPage(_currentPage - 1) : null,
            tooltip: context.l10n.songsFlutterPreviousPage,
          ),
          Text(
            context.l10n.protocolPage(_currentPage, _totalPages),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down),
            onPressed: _currentPage < _totalPages
                ? () => _goToPage(_currentPage + 1)
                : null,
            tooltip: context.l10n.songsFlutterNextPage,
          ),
        ],
      ),
    );
  }
}

/// Opens [url] in the full-screen PDF viewer (above the tab bar).
Future<void> showPdfViewer(
  BuildContext context, {
  required String url,
  required String fileName,
}) {
  return Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (context) => PdfViewerPage(
        url: url,
        fileName: fileName,
      ),
    ),
  );
}
