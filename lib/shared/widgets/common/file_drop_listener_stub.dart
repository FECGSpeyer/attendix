import 'package:file_picker/file_picker.dart';
import 'package:flutter/widgets.dart';

/// Handle of a registered drop listener.
abstract class FileDropListener {
  void dispose();
}

/// Non-web platforms: no browser drag & drop (returns null).
FileDropListener? registerFileDropListener({
  required bool Function(Offset globalPosition) hitTest,
  required void Function(bool over) onHover,
  required void Function(List<PlatformFile> files) onDrop,
}) =>
    null;
