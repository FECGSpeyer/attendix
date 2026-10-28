import 'dart:js_interop';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

/// Handle of a registered drop listener.
abstract class FileDropListener {
  void dispose();
}

/// Web: listens to document drag events and reports drops inside the zone.
FileDropListener? registerFileDropListener({
  required bool Function(Offset globalPosition) hitTest,
  required void Function(bool over) onHover,
  required void Function(List<PlatformFile> files) onDrop,
}) {
  try {
    return _WebFileDropListener(hitTest, onHover, onDrop);
  } catch (_) {
    return null;
  }
}

class _WebFileDropListener implements FileDropListener {
  _WebFileDropListener(this._hitTest, this._onHover, this._onDrop) {
    _dragOver = _handleDragOver.toJS;
    _dragLeave = _handleDragLeave.toJS;
    _drop = _handleDrop.toJS;
    web.document.addEventListener('dragover', _dragOver);
    web.document.addEventListener('dragleave', _dragLeave);
    web.document.addEventListener('drop', _drop);
  }

  final bool Function(Offset) _hitTest;
  final void Function(bool) _onHover;
  final void Function(List<PlatformFile>) _onDrop;

  late final JSFunction _dragOver;
  late final JSFunction _dragLeave;
  late final JSFunction _drop;

  static bool _hasFiles(web.DragEvent event) {
    final types = event.dataTransfer?.types.toDart ?? const [];
    return types.any((t) => t.toDart == 'Files');
  }

  Offset _position(web.DragEvent event) =>
      Offset(event.clientX.toDouble(), event.clientY.toDouble());

  void _handleDragOver(web.DragEvent event) {
    if (!_hasFiles(event)) return;
    // Keep the browser from opening the file instead of dropping it.
    event.preventDefault();
    final over = _hitTest(_position(event));
    event.dataTransfer?.dropEffect = over ? 'copy' : 'none';
    _onHover(over);
  }

  void _handleDragLeave(web.DragEvent event) {
    // Leaving the window reports (0, 0).
    if (event.clientX == 0 && event.clientY == 0) _onHover(false);
  }

  void _handleDrop(web.DragEvent event) {
    if (!_hasFiles(event)) return;
    event.preventDefault();
    _onHover(false);
    if (!_hitTest(_position(event))) return;
    final list = event.dataTransfer?.files;
    if (list == null || list.length == 0) return;
    final files = <web.File>[
      for (var i = 0; i < list.length; i++)
        if (list.item(i) case final f?) f,
    ];
    _readFiles(files);
  }

  Future<void> _readFiles(List<web.File> files) async {
    final result = <PlatformFile>[];
    for (final file in files) {
      try {
        final buffer = await file.arrayBuffer().toDart;
        final bytes = buffer.toDart.asUint8List();
        result.add(PlatformFile(name: file.name, size: bytes.length, bytes: bytes));
      } catch (_) {
        // Folders or unreadable entries are skipped.
      }
    }
    if (result.isNotEmpty) _onDrop(result);
  }

  @override
  void dispose() {
    try {
      web.document.removeEventListener('dragover', _dragOver);
      web.document.removeEventListener('dragleave', _dragLeave);
      web.document.removeEventListener('drop', _drop);
    } catch (_) {}
  }
}
