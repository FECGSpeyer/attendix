import 'dart:io';
import 'dart:ui';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/foundation.dart';

import 'file_drop_types.dart';

/// Native apps: dragging files from Finder / Explorer works on desktop
/// (macOS, Windows, Linux) via `desktop_drop`; iOS and Android have no drop.
/// Like on the web, the events go to the topmost registered target.
bool get isFileDropSupported => switch (defaultTargetPlatform) {
  TargetPlatform.macOS || TargetPlatform.windows || TargetPlatform.linux => true,
  _ => false,
};

/// Upload limit of all file dialogs (20 MiB); larger files are not read.
const int maxDroppedFileBytes = 20 * 1024 * 1024;

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

/// Windows reports physical pixels, macOS and Linux logical ones.
Offset _logical(Offset point) {
  if (defaultTargetPlatform != TargetPlatform.windows) return point;
  final views = PlatformDispatcher.instance.views;
  final ratio = views.isEmpty ? 1.0 : views.first.devicePixelRatio;
  return point / ratio;
}

void _install() {
  if (_installed) return;
  _installed = true;
  try {
    DesktopDrop.instance.init();
    DesktopDrop.instance.addRawDropEventListener(_onEvent);
  } catch (_) {
    // Drag & drop is a convenience only.
  }
}

void _onEvent(DropEvent e) {
  final top = _top;
  if (top == null) return;
  final p = _logical(e.location);
  switch (e) {
    case DropEnterEvent() || DropUpdateEvent():
      _setHover(top, top.hitTest(p.dx, p.dy));
    case DropExitEvent():
      _clearHover();
    case DropDoneEvent(:final files):
      final inside = top.hitTest(p.dx, p.dy);
      _clearHover();
      if (!inside) return;
      _read(files).then((dropped) {
        if (dropped.isNotEmpty && _targets.contains(top)) top.onDrop(dropped);
      });
    default:
      break;
  }
}

/// Reads the dropped files right away: under the macOS sandbox the access
/// to a file from Finder only lasts while its security-scoped bookmark is open.
Future<List<DroppedFile>> _read(List<DropItem> items) async {
  final result = <DroppedFile>[];
  for (final item in items) {
    // Folders are skipped, as on the web.
    if (item is DropItemDirectory) continue;
    final bookmark = item.extraAppleBookmark ?? Uint8List(0);
    var scoped = false;
    try {
      if (bookmark.isNotEmpty) {
        scoped = await DesktopDrop.instance.startAccessingSecurityScopedResource(bookmark: bookmark);
      }
      final file = File(item.path);
      if (!await file.exists()) continue;
      final name = item.path.split(Platform.pathSeparator).last;
      final size = await file.length();
      // Never read huge files into memory; the dialogs report them as too large.
      if (size > maxDroppedFileBytes) {
        result.add(DroppedFile.tooLarge(name: name, size: size));
        continue;
      }
      result.add(DroppedFile(name: name, bytes: await file.readAsBytes()));
    } catch (_) {
      // Unreadable entries are skipped.
    } finally {
      if (scoped) {
        try {
          await DesktopDrop.instance.stopAccessingSecurityScopedResource(bookmark: bookmark);
        } catch (_) {}
      }
    }
  }
  return result;
}
