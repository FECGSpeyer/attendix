import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:attendix/shared/widgets/layout/sheet_drag.dart';
import 'package:attendix/core/theme/app_icons.dart';
import 'package:pdfx/pdfx.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/l10n.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../core/services/native/native_file_service.dart';
import '../../../../core/services/pdf_bytes_loader.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';
import '../../../../shared/widgets/common/escape_to_close.dart';

/// WERKE-33: pdfx tells the page from the visible pages of the previous
/// transform (its own listener runs before the view updates them), so the
/// last scroll step could leave the counter on the old page ("Seite 1 von 2"
/// while page 2 shows). Re-reads the page once all listeners ran.
VoidCallback _pdfPageSync(
  PdfControllerPinch controller, {
  required bool Function() alive,
  required int Function() current,
  required ValueChanged<int> onPage,
}) {
  var queued = false;
  return () {
    if (queued) return;
    queued = true;
    scheduleMicrotask(() {
      queued = false;
      if (!alive()) return;
      int page;
      try {
        page = controller.page;
      } catch (_) {
        return; // view not attached (yet / any more)
      }
      if (page != current()) onPage(page);
    });
  };
}

/// Bottom sheet for viewing PDF files in-app
class PdfViewerSheet extends StatefulWidget {
  final String url;
  final String fileName;

  const PdfViewerSheet({
    super.key,
    required this.url,
    required this.fileName,
  });

  @override
  State<PdfViewerSheet> createState() => _PdfViewerSheetState();
}

class _PdfViewerSheetState extends State<PdfViewerSheet> {
  PdfControllerPinch? _pdfController;

  /// The loaded file: the full-screen view opens its own document from it
  /// (a [PdfControllerPinch] can only drive one [PdfViewPinch]).
  Uint8List? _bytes;
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
    _pdfController?.dispose();
    super.dispose();
  }

  Future<void> _loadPdf() async {
    try {
      // Cached on iOS/Android: opens offline after the first time.
      final bytes = await PdfBytesLoader.load(widget.url);
      final document = await PdfDocument.openData(bytes);

      if (mounted) {
        final controller = PdfControllerPinch(
          document: Future.value(document),
        );
        controller.addListener(_pdfPageSync(
          controller,
          alive: () => mounted && _pdfController == controller,
          current: () => _currentPage,
          onPage: (page) => setState(() => _currentPage = page),
        ));
        setState(() {
          _bytes = bytes;
          _totalPages = document.pagesCount;
          _pdfController = controller;
          _isLoading = false;
        });
      }
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
    if (_pdfController != null && page >= 1 && page <= _totalPages) {
      _pdfController!.animateToPage(
        pageNumber: page,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _openFullscreen() async {
    final bytes = _bytes;
    if (bytes == null) return;
    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (context) => EscapeToClose(
          child: _FullscreenPdfViewer(
            // WERKE-33: own controller + own document. Sharing the sheet's
            // controller with a second PdfViewPinch left the full-screen
            // view black. A copy of the bytes, because pdf.js may take over
            // (detach) the buffer it is given on the web.
            bytes: Uint8List.fromList(bytes),
            fileName: widget.fileName,
            totalPages: _totalPages,
            currentPage: _currentPage,
            onPageChanged: (page) {
              if (mounted) {
                setState(() => _currentPage = page);
              }
            },
          ),
        ),
      ),
    );
    // Back in the sheet on the page the full-screen view ended on.
    if (mounted && _pdfController != null) {
      _pdfController!.jumpToPage(_currentPage);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppDraggableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppDimensions.borderRadiusL),
            ),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.medium.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.all(AppDimensions.paddingM),
                child: Row(
                  children: [
                    Icon(AppIcons.pictureAsPdf, color: AppColors.danger),
                    const SizedBox(width: AppDimensions.paddingS),
                    Expanded(
                      child: Text(
                        widget.fileName,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (!_isLoading && _pdfController != null)
                      IconButton(
                        icon: Icon(AppIcons.fullscreen),
                        onPressed: _openFullscreen,
                        tooltip: context.l10n.songsFlutterFullscreen,
                      ),
                    IconButton(
                      icon: Icon(AppIcons.close, semanticLabel: context.l10n.commonClose),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Content
              Expanded(
                child: _buildContent(),
              ),
              // Bottom navigation
              if (!_isLoading && _error == null && _totalPages > 1)
                _buildPageNavigation(),
            ],
          ),
        );
      },
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
              Icon(AppIcons.errorOutline, size: 64, color: AppColors.danger),
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
              IonButton(
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                    _error = null;
                  });
                  _loadPdf();
                },
                icon: AppIcons.refresh,
                label: context.l10n.messagesRetry,
              ),
              // Fallback when the in-app viewer is unavailable (e.g. pdf.js
              // blocked on web): open the file in the browser / system viewer.
              const SizedBox(height: AppDimensions.paddingS),
              TextButton.icon(
                // Installed web app (Ionic 4.17.19): no new windows → download.
                onPressed: () => NativeFileService.isInstalledWebApp
                    ? NativeFileService.downloadInBrowser(
                        widget.url, NativeFileService.fileNameFromUrl(widget.url))
                    : NativeFileService.openExternal(Uri.parse(widget.url)),
                icon: Icon(AppIcons.openInNew),
                label: IonButtonLabel(context.l10n.coreFlutterOpenExternally),
              ),
            ],
          ),
        ),
      );
    }

    return PdfViewPinch(
      controller: _pdfController!,
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

  Widget _buildPageNavigation() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingM,
        vertical: AppDimensions.paddingS,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: Icon(AppIcons.firstPage),
            onPressed: _currentPage > 1 ? () => _goToPage(1) : null,
            tooltip: context.l10n.songsFlutterFirstPage,
          ),
          IconButton(
            icon: Icon(AppIcons.chevronLeft),
            onPressed:
                _currentPage > 1 ? () => _goToPage(_currentPage - 1) : null,
            tooltip: context.l10n.songsFlutterPreviousPage,
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              context.l10n.protocolPage(_currentPage, _totalPages),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
          IconButton(
            icon: Icon(AppIcons.chevronRight),
            onPressed: _currentPage < _totalPages
                ? () => _goToPage(_currentPage + 1)
                : null,
            tooltip: context.l10n.songsFlutterNextPage,
          ),
          IconButton(
            icon: Icon(AppIcons.lastPage),
            onPressed:
                _currentPage < _totalPages ? () => _goToPage(_totalPages) : null,
            tooltip: context.l10n.songsFlutterLastPage,
          ),
        ],
      ),
    );
  }
}

/// Fullscreen PDF viewer
class _FullscreenPdfViewer extends StatefulWidget {
  final Uint8List bytes;
  final String fileName;
  final int totalPages;
  final int currentPage;
  final ValueChanged<int> onPageChanged;

  const _FullscreenPdfViewer({
    required this.bytes,
    required this.fileName,
    required this.totalPages,
    required this.currentPage,
    required this.onPageChanged,
  });

  @override
  State<_FullscreenPdfViewer> createState() => _FullscreenPdfViewerState();
}

class _FullscreenPdfViewerState extends State<_FullscreenPdfViewer> {
  late int _currentPage;
  late final PdfControllerPinch _controller;
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.currentPage;
    _controller = PdfControllerPinch(
      document: PdfDocument.openData(widget.bytes),
      initialPage: widget.currentPage,
    );
    _controller.addListener(_pdfPageSync(
      _controller,
      alive: () => mounted,
      current: () => _currentPage,
      onPage: (page) {
        setState(() => _currentPage = page);
        widget.onPageChanged(page);
      },
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleControls,
        child: Stack(
          children: [
            // PDF view
            PdfViewPinch(
              controller: _controller,
              onPageChanged: (page) {
                setState(() => _currentPage = page);
                widget.onPageChanged(page);
              },
              builders: PdfViewPinchBuilders<DefaultBuilderOptions>(
                options: const DefaultBuilderOptions(),
                documentLoaderBuilder: (_) => const Center(
                  child: AppSpinner(color: Colors.white),
                ),
                pageLoaderBuilder: (_) => const Center(
                  child: AppSpinner(color: Colors.white),
                ),
              ),
            ),
            // Top bar
            if (_showControls)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  // WERKE-33: a dark bar instead of a fading gradient – the
                  // white title stays readable on a white page.
                  color: Colors.black.withValues(alpha: 0.6),
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.all(AppDimensions.paddingS),
                      child: Row(
                        children: [
                          IconButton(
                            icon: Icon(AppIcons.close, color: Colors.white, semanticLabel: context.l10n.commonClose),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                          Expanded(
                            child: Text(
                              widget.fileName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            // Bottom bar
            if (_showControls && widget.totalPages > 1)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.7),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(AppDimensions.paddingM),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: Icon(AppIcons.chevronLeft,
                                color: Colors.white, size: 32, semanticLabel: context.l10n.a11yPreviousPage),
                            onPressed: _currentPage > 1
                                ? () => _controller.animateToPage(
                                      pageNumber: _currentPage - 1,
                                      duration:
                                          const Duration(milliseconds: 300),
                                      curve: Curves.easeInOut,
                                    )
                                : null,
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            // WERKE-33: dark pill, readable on a white page.
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '$_currentPage / ${widget.totalPages}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: Icon(AppIcons.chevronRight,
                                color: Colors.white, size: 32, semanticLabel: context.l10n.a11yNextPage),
                            onPressed: _currentPage < widget.totalPages
                                ? () => _controller.animateToPage(
                                      pageNumber: _currentPage + 1,
                                      duration:
                                          const Duration(milliseconds: 300),
                                      curve: Curves.easeInOut,
                                    )
                                : null,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Shows the PDF viewer sheet as a bottom sheet
Future<void> showPdfViewerSheet(
  BuildContext context, {
  required String url,
  required String fileName,
}) {
  return showModalBottomSheet(
    context: context,
    useRootNavigator: true, // IOS_SHELL2: above the tab bar
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => EscapeToClose(
      child: PdfViewerSheet(
        url: url,
        fileName: fileName,
      ),
    ),
  );
}
