import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'file_drop_types.dart';

/// Web: HTML5 drag & drop of files from the desktop (Ionic `(dragover)` /
/// `(drop)` on the song page). Flutter renders into a canvas, so the events
/// are taken from the document and routed to the topmost registered target
/// (e.g. the upload sheet wins over the file list behind it).
bool get isFileDropSupported => true;

final List<FileDropHandlers> _targets = [];
bool _installed = false;

FileDropHandlers? get _top => _targets.isEmpty ? null : _targets.last;

void registerFileDropTarget(FileDropHandlers handlers) {
  _install();
  for (final t in _targets) {
    _setHover(t, false);
  }
  _targets.add(handlers);
}

void unregisterFileDropTarget(FileDropHandlers handlers) {
  _targets.remove(handlers);
}

void _setHover(FileDropHandlers t, bool value) {
  if (t.hovering == value) return;
  t.hovering = value;
  try {
    t.onHover(value);
  } catch (_) {}
}

void _clearHover() {
  for (final t in _targets) {
    _setHover(t, false);
  }
}

bool _hasFiles(web.DragEvent e) {
  final types = e.dataTransfer?.types.toDart ?? const <JSString>[];
  return types.any((t) => t.toDart == 'Files');
}

void _install() {
  if (_installed) return;
  _installed = true;
  try {
    web.document.addEventListener(
      'dragover',
      ((web.DragEvent e) {
        final top = _top;
        if (top == null || !_hasFiles(e)) return;
        // Required so the browser allows the drop (instead of opening the file).
        e.preventDefault();
        _setHover(top, top.hitTest(e.clientX.toDouble(), e.clientY.toDouble()));
      }).toJS,
    );
    web.document.addEventListener(
      'dragleave',
      ((web.DragEvent e) {
        // relatedTarget == null: the pointer left the browser window.
        if (e.relatedTarget == null) _clearHover();
      }).toJS,
    );
    web.document.addEventListener(
      'drop',
      ((web.DragEvent e) {
        final top = _top;
        if (top == null || !_hasFiles(e)) return;
        e.preventDefault();
        final inside = top.hitTest(e.clientX.toDouble(), e.clientY.toDouble());
        _clearHover();
        if (!inside) return;
        final list = e.dataTransfer?.files;
        if (list == null || list.length == 0) return;
        final files = <web.File>[];
        for (var i = 0; i < list.length; i++) {
          final f = list.item(i);
          if (f != null) files.add(f);
        }
        _read(files).then((dropped) {
          if (dropped.isNotEmpty && _targets.contains(top)) top.onDrop(dropped);
        });
      }).toJS,
    );
  } catch (_) {
    // Drag & drop is a convenience only.
  }
}

Future<List<DroppedFile>> _read(List<web.File> files) async {
  final result = <DroppedFile>[];
  for (final f in files) {
    try {
      final buffer = await f.arrayBuffer().toDart;
      result.add(DroppedFile(name: f.name, bytes: buffer.toDart.asUint8List()));
    } catch (_) {
      // Folders or unreadable entries are skipped.
    }
  }
  return result;
}
