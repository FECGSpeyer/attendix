import 'dart:typed_data';

/// A file dropped onto the browser window (web only).
class DroppedFile {
  const DroppedFile({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;
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
