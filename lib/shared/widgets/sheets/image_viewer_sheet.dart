import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../l10n/l10n.dart';

/// Fullscreen image viewer (Ionic image viewer):
/// - pinch / mouse wheel zoom (1x - 5x), pan when zoomed
/// - double tap zooms to 2.5x at the tapped point and back
/// - swipe down closes the viewer when not zoomed
/// - single tap toggles the controls, zoom pill (- / % / +)
/// - keyboard: Esc closes, + / - zoom, 0 resets
class ImageViewerSheet extends StatefulWidget {
  final String url;
  final String fileName;

  const ImageViewerSheet({
    super.key,
    required this.url,
    required this.fileName,
  });

  @override
  State<ImageViewerSheet> createState() => _ImageViewerSheetState();
}

class _ImageViewerSheetState extends State<ImageViewerSheet>
    with SingleTickerProviderStateMixin {
  static const double _minScale = 1;
  static const double _maxScale = 5;
  static const double _doubleTapScale = 2.5;
  static const double _closeDistance = 120;

  final _controller = TransformationController();
  late final AnimationController _animation;
  Animation<Matrix4>? _matrixAnimation;
  final _focusNode = FocusNode();

  Offset? _doubleTapPosition;
  Size _viewport = Size.zero;
  bool _showControls = true;
  bool _showHint = true;
  Timer? _hintTimer;

  // Swipe-down-to-close (only when not zoomed)
  int _pointers = 0;
  Offset? _dragStart;
  double _dragOffset = 0;

  double get _scale => _controller.value.getMaxScaleOnAxis();
  bool get _isZoomed => _scale > 1.01;

  @override
  void initState() {
    super.initState();
    _animation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    )..addListener(() {
        final anim = _matrixAnimation;
        if (anim != null) _controller.value = anim.value;
      });
    _controller.addListener(_onTransform);
    _hintTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showHint = false);
    });
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    _controller.removeListener(_onTransform);
    _controller.dispose();
    _animation.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  double _lastScale = 1;

  void _onTransform() {
    final s = _scale;
    // Rebuild only when the zoom level visibly changes (pill, pan state)
    if ((s - _lastScale).abs() > 0.009) {
      _lastScale = s;
      setState(() {});
    }
  }

  void _animateTo(Matrix4 target) {
    _matrixAnimation = Matrix4Tween(begin: _controller.value, end: target)
        .animate(CurvedAnimation(parent: _animation, curve: Curves.easeOut));
    _animation.forward(from: 0);
  }

  /// Matrix zooming to [scale] while keeping [focal] (viewport coords) fixed.
  Matrix4 _zoomAround(double scale, Offset focal) {
    final current = _controller.value;
    final currentScale = _scale;
    // Scene point under the focal point
    final tx = current.getTranslation();
    final sceneX = (focal.dx - tx.x) / currentScale;
    final sceneY = (focal.dy - tx.y) / currentScale;
    final s = scale.clamp(_minScale, _maxScale);
    var newTx = focal.dx - sceneX * s;
    var newTy = focal.dy - sceneY * s;
    // Keep the image inside the viewport
    newTx = newTx.clamp(_viewport.width * (1 - s), 0.0);
    newTy = newTy.clamp(_viewport.height * (1 - s), 0.0);
    return Matrix4.diagonal3Values(s, s, 1)..setTranslationRaw(newTx, newTy, 0);
  }

  void _zoomBy(double factor) {
    final center = Offset(_viewport.width / 2, _viewport.height / 2);
    final target = (_scale * factor).clamp(_minScale, _maxScale);
    if (target <= 1.001) {
      _animateTo(Matrix4.identity());
    } else {
      _animateTo(_zoomAround(target, center));
    }
  }

  void _reset() => _animateTo(Matrix4.identity());

  void _onDoubleTap() {
    if (_isZoomed) {
      _reset();
    } else {
      final pos = _doubleTapPosition ??
          Offset(_viewport.width / 2, _viewport.height / 2);
      _animateTo(_zoomAround(_doubleTapScale, pos));
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final char = event.character;
    if (key == LogicalKeyboardKey.escape) {
      Navigator.of(context).maybePop();
      return KeyEventResult.handled;
    }
    if (char == '+' || char == '=' || key == LogicalKeyboardKey.numpadAdd) {
      _zoomBy(1.5);
      return KeyEventResult.handled;
    }
    if (char == '-' || key == LogicalKeyboardKey.numpadSubtract) {
      _zoomBy(1 / 1.5);
      return KeyEventResult.handled;
    }
    if (char == '0' || key == LogicalKeyboardKey.numpad0) {
      _reset();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  // ---- swipe down to close ------------------------------------------------

  void _pointerDown(PointerDownEvent e) {
    _pointers++;
    _dragStart = (_pointers == 1 && !_isZoomed) ? e.position : null;
    if (_pointers > 1 && _dragOffset != 0) setState(() => _dragOffset = 0);
  }

  void _pointerMove(PointerMoveEvent e) {
    final start = _dragStart;
    if (start == null || _pointers != 1 || _isZoomed) return;
    final dy = math.max(0.0, e.position.dy - start.dy);
    final dx = (e.position.dx - start.dx).abs();
    if (dy > dx) setState(() => _dragOffset = dy);
  }

  void _pointerUp(PointerEvent e) {
    _pointers = math.max(0, _pointers - 1);
    if (_dragStart != null && _dragOffset > _closeDistance) {
      _dragStart = null;
      Navigator.of(context).maybePop();
      return;
    }
    _dragStart = null;
    if (_dragOffset != 0) setState(() => _dragOffset = 0);
  }

  @override
  Widget build(BuildContext context) {
    final opacity = (1 - _dragOffset / 400).clamp(0.3, 1.0);
    final percent = (_scale * 100).round();

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Scaffold(
        backgroundColor: Colors.black.withAlpha((opacity * 255).round()),
        body: Stack(
          children: [
            Positioned.fill(
              child: LayoutBuilder(builder: (context, constraints) {
                _viewport = constraints.biggest;
                return Listener(
                  onPointerDown: _pointerDown,
                  onPointerMove: _pointerMove,
                  onPointerUp: _pointerUp,
                  onPointerCancel: _pointerUp,
                  child: GestureDetector(
                    onTap: () => setState(() => _showControls = !_showControls),
                    onDoubleTapDown: (d) => _doubleTapPosition = d.localPosition,
                    onDoubleTap: _onDoubleTap,
                    child: Transform.translate(
                      offset: Offset(0, _dragOffset),
                      child: InteractiveViewer(
                        transformationController: _controller,
                        minScale: _minScale,
                        maxScale: _maxScale,
                        panEnabled: _isZoomed,
                        clipBehavior: Clip.none,
                        child: SizedBox(
                          width: constraints.maxWidth,
                          height: constraints.maxHeight,
                          child: CachedNetworkImage(
                            imageUrl: widget.url,
                            fit: BoxFit.contain,
                            placeholder: (context, url) => const Center(
                              child: CircularProgressIndicator(color: Colors.white),
                            ),
                            errorWidget: (context, url, error) => Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.broken_image_outlined,
                                      size: 64, color: Colors.white70),
                                  const SizedBox(height: 12),
                                  Text(
                                    context.l10n.imageViewerLoadFailed,
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
            // Top bar
            AnimatedPositioned(
              duration: const Duration(milliseconds: 200),
              top: _showControls ? 0 : -120,
              left: 0,
              right: 0,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xB3000000), Color(0x00000000)],
                  ),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Row(
                      children: [
                        // Ionic top bar: title left, close button right.
                        const SizedBox(width: 8),
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
                        IconButton(
                          tooltip: context.l10n.commonClose,
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.of(context).maybePop(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Zoom pill
            AnimatedPositioned(
              duration: const Duration(milliseconds: 200),
              bottom: _showControls ? 24 + MediaQuery.paddingOf(context).bottom : -80,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0x99000000),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: context.l10n.imageViewerZoomOut,
                        icon: const Icon(Icons.remove, color: Colors.white),
                        onPressed: _scale > _minScale + 0.01 ? () => _zoomBy(1 / 1.5) : null,
                      ),
                      // MEDIA_REALTIME: Ionic zoom-value button
                      // (aria-label imageViewer.zoomReset).
                      Tooltip(
                        message: context.l10n.imageViewerZoomReset,
                        child: Semantics(
                          button: true,
                          label: context.l10n.imageViewerZoomReset,
                          child: InkWell(
                            key: const ValueKey('image-viewer-zoom-reset'),
                            onTap: _reset,
                            borderRadius: BorderRadius.circular(16),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                              child: Text(
                                '$percent\u00A0%',
                                style: const TextStyle(color: Colors.white, fontSize: 14),
                              ),
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: context.l10n.imageViewerZoomIn,
                        icon: const Icon(Icons.add, color: Colors.white),
                        onPressed: _scale < _maxScale - 0.01 ? () => _zoomBy(1.5) : null,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Hint
            Positioned(
              bottom: 96 + MediaQuery.paddingOf(context).bottom,
              left: 16,
              right: 16,
              child: IgnorePointer(
                child: AnimatedOpacity(
                  opacity: _showHint && !_isZoomed ? 1 : 0,
                  duration: const Duration(milliseconds: 400),
                  child: Center(
                    child: DecoratedBox(
                      decoration: const BoxDecoration(
                        color: Color(0x99000000),
                        borderRadius: BorderRadius.all(Radius.circular(16)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: Text(
                          context.l10n.imageViewerHint,
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
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

/// Shows the image viewer fullscreen (name kept for existing callers).
Future<void> showImageViewerSheet(
  BuildContext context, {
  required String url,
  required String fileName,
}) {
  return Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (_, __, ___) => ImageViewerSheet(url: url, fileName: fileName),
      transitionsBuilder: (_, animation, __, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );
}
