import 'dart:typed_data';

/// A file dropped onto the browser window or the desktop app.
class DroppedFile {
  const DroppedFile({required this.name, required Uint8List this.bytes}) : _size = null;

  /// A file too large to read: only its size is passed on, so the upload
  /// dialogs reject it with "zu groß".
  const DroppedFile.tooLarge({required this.name, required int size})
      : bytes = null,
        _size = size;

  final String name;
  final Uint8List? bytes;
  final int? _size;

  int get size => _size ?? bytes!.length;
}

/// Callbacks of one registered drop target.
class FileDropHandlers {
  FileDropHandlers({
    required this.hitTest,
    required this.onHover,
    required this.onDrop,
  });

  /// Whether the viewport position (CSS / logical pixels) is inside the target.
  final bool Function(double x, double y) hitTest;

  /// Hover state changed (files dragged over the target or not).
  final void Function(bool hovering) onHover;

  /// Files were dropped onto the target.
  final void Function(List<DroppedFile> files) onDrop;

  bool hovering = false;
}
