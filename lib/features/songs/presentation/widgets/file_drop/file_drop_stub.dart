import 'file_drop_types.dart';

/// Native platforms: dragging files from the OS is not supported (Ionic only
/// offers it in desktop browsers as well).
bool get isFileDropSupported => false;

void registerFileDropTarget(FileDropHandlers handlers) {}

void unregisterFileDropTarget(FileDropHandlers handlers) {}
