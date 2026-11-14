import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:attendix/core/theme/app_icons.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/redesign/rd_theme.dart' show RdSkinContext;
import 'file_drop_platform.dart';
import 'file_drop_types.dart';
import '../../../../../l10n/l10n.dart';

export 'file_drop_platform.dart' show isFileDropSupported;

/// Area that accepts files dragged from the desktop (web and desktop apps; on
/// iOS / Android it just renders [builder] with `hovering == false`).
///
/// When several targets are mounted, only the most recently mounted one is
/// active, so an open upload sheet takes precedence over the page behind it.
class FileDropTarget extends StatefulWidget {
  const FileDropTarget({
    super.key,
    required this.builder,
    required this.onFiles,
    this.enabled = true,
  });

  final Widget Function(BuildContext context, bool hovering) builder;
  final ValueChanged<List<PlatformFile>> onFiles;
  final bool enabled;

  @override
  State<FileDropTarget> createState() => _FileDropTargetState();
}

class _FileDropTargetState extends State<FileDropTarget> {
  bool _hovering = false;
  FileDropHandlers? _handlers;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(covariant FileDropTarget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled != widget.enabled) _sync();
  }

  void _sync() {
    if (!isFileDropSupported) return;
    if (widget.enabled && _handlers == null) {
      final handlers = FileDropHandlers(
        hitTest: _hitTest,
        onHover: (v) {
          if (mounted) setState(() => _hovering = v);
        },
        onDrop: (files) {
          if (!mounted || !widget.enabled) return;
          widget.onFiles([
            for (final f in files)
              PlatformFile(name: f.name, size: f.size, bytes: f.bytes),
          ]);
        },
      );
      _handlers = handlers;
      registerFileDropTarget(handlers);
    } else if (!widget.enabled && _handlers != null) {
      unregisterFileDropTarget(_handlers!);
      _handlers = null;
      _hovering = false;
    }
  }

  bool _hitTest(double x, double y) {
    if (!mounted) return false;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return false;
    final origin = box.localToGlobal(Offset.zero);
    return (origin & box.size).contains(Offset(x, y));
  }

  @override
  void dispose() {
    if (_handlers != null) unregisterFileDropTarget(_handlers!);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _hovering);
}

/// Ionic `.drop-zone`: bordered box "Dateien hierher ziehen oder tippen zum
/// Auswählen"; a tap opens the file picker, a drop (web, desktop apps) adds the files.
class FileDropZone extends StatelessWidget {
  const FileDropZone({
    super.key,
    required this.onTap,
    required this.onFiles,
    this.label,
  });

  final VoidCallback? onTap;
  final ValueChanged<List<PlatformFile>> onFiles;
  /// Defaults to `songs.dropHere`.
  final String? label;

  @override
  Widget build(BuildContext context) {
    return FileDropTarget(
      onFiles: onFiles,
      enabled: onTap != null,
      builder: (context, hovering) {
        final color = hovering ? AppColors.primary : AppColors.medium;
        // WER-27: Ionic `border: 2px dashed` (Beta: the solid border).
        final dashed = context.rdSkin == null;
        final material = Material(
          color: hovering ? AppColors.primary.withAlpha(20) : Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: dashed ? BorderSide.none : BorderSide(color: color, width: 2),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
              child: Column(
                children: [
                  Icon(AppIcons.cloudUploadOutlined, size: 36, color: color),
                  const SizedBox(height: 8),
                  Text(
                    label ?? context.l10n.songsDropHere,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: color),
                  ),
                ],
              ),
            ),
          ),
        );
        if (!dashed) return material;
        return CustomPaint(
          foregroundPainter: DashedRRectPainter(color: color, radius: 12),
          child: material,
        );
      },
    );
  }
}

/// A CSS `border: <width> dashed <color>` around a rounded rectangle
/// (Ionic `.drop-zone`, `.files-drop-area--active` outline).
class DashedRRectPainter extends CustomPainter {
  const DashedRRectPainter({
    required this.color,
    this.radius = 12,
    this.strokeWidth = 2,
    this.dash = 6,
    this.gap = 4,
    this.outset = 0,
  });

  final Color color;
  final double radius;
  final double strokeWidth;
  final double dash;
  final double gap;

  /// Draws outside the box (CSS `outline`) instead of inside (`border`).
  final double outset;

  @override
  void paint(Canvas canvas, Size size) {
    final half = strokeWidth / 2;
    final rect = (Offset.zero & size).deflate(half - outset);
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, d + dash), paint);
        d += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(DashedRRectPainter old) =>
      old.color != color ||
      old.radius != radius ||
      old.strokeWidth != strokeWidth ||
      old.outset != outset;
}
