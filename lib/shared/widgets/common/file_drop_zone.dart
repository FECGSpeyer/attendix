import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import 'file_drop_listener_stub.dart'
    if (dart.library.js_interop) 'file_drop_listener_web.dart' as impl;

/// MEDIA_REALTIME: drop zone for file uploads (Ionic song.page.html
/// `.drop-zone` with `(dragover)` / `(dragleave)` / `(drop)` /
/// `(click)="fileInput.click()"`).
///
/// On the web, files dragged from the desktop onto the zone are read and
/// passed to [onFilesDropped]. On other platforms the zone is a tap target
/// that calls [onTap] (e.g. the file picker), like Ionic on mobile.
class FileDropZone extends StatefulWidget {
  const FileDropZone({
    super.key,
    required this.onTap,
    required this.onFilesDropped,
    this.label = 'Dateien hierher ziehen oder tippen zum Auswählen',
    this.enabled = true,
  });

  final VoidCallback onTap;
  final ValueChanged<List<PlatformFile>> onFilesDropped;

  /// Ionic `songs.dropHere`.
  final String label;
  final bool enabled;

  @override
  State<FileDropZone> createState() => _FileDropZoneState();
}

class _FileDropZoneState extends State<FileDropZone> {
  final _zoneKey = GlobalKey();
  impl.FileDropListener? _listener;
  bool _dragOver = false;

  @override
  void initState() {
    super.initState();
    _listener = impl.registerFileDropListener(
      hitTest: _hitTest,
      onHover: (over) {
        if (mounted && over != _dragOver) setState(() => _dragOver = over);
      },
      onDrop: (files) {
        if (!mounted) return;
        setState(() => _dragOver = false);
        if (widget.enabled && files.isNotEmpty) widget.onFilesDropped(files);
      },
    );
  }

  /// True when the browser position (CSS px == logical px on Flutter web)
  /// lies inside the zone.
  bool _hitTest(Offset globalPosition) {
    if (!widget.enabled) return false;
    final box = _zoneKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize || !box.attached) return false;
    final local = box.globalToLocal(globalPosition);
    return (Offset.zero & box.size).contains(local);
  }

  @override
  void dispose() {
    _listener?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _dragOver ? AppColors.primary : theme.colorScheme.outline;
    return Material(
      key: _zoneKey,
      color: _dragOver
          ? AppColors.primary.withValues(alpha: 0.08)
          : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color, width: 2),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: widget.enabled ? widget.onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_upload_outlined, size: 40, color: color),
              const SizedBox(height: 8),
              Text(
                widget.label,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
