/// Ionic 4.19.1 `utilities/file-move.ts`: pure helpers for moving in the
/// Dateiablage (check the target folder, folder tree). Paths are relative to
/// the tenant root.
library;

class MoveItem {
  const MoveItem({required this.path, required this.isFolder});

  final String path;
  final bool isFolder;
}

String normalizeFilePath(String? path) =>
    (path ?? '').split('/').where((s) => s.isNotEmpty).join('/');

String parentFilePath(String path) {
  final segments = normalizeFilePath(path).split('/').where((s) => s.isNotEmpty).toList();
  if (segments.isEmpty) return '';
  return segments.sublist(0, segments.length - 1).join('/');
}

/// true when [path] equals [folder] or lies inside it.
bool isSameOrInside(String path, String folder) {
  final p = normalizeFilePath(path);
  final f = normalizeFilePath(folder);
  if (f.isEmpty) return true;
  return p == f || p.startsWith('$f/');
}

/// Folders nothing may be moved into: the moved folders and everything below.
bool isBlockedTarget(String target, List<MoveItem> items) =>
    items.any((item) => item.isFolder && isSameOrInside(target, item.path));

/// true when all items already lie directly in [target] (a no-op move).
bool isCurrentLocation(String target, List<MoveItem> items) {
  final t = normalizeFilePath(target);
  return items.isNotEmpty && items.every((item) => parentFilePath(item.path) == t);
}

bool canMoveInto(String target, List<MoveItem> items) =>
    items.isNotEmpty && !isBlockedTarget(target, items) && !isCurrentLocation(target, items);

/// Folder paths from the root down to [path], e.g. 'a/b' → ['', 'a', 'a/b'].
List<String> ancestorFilePaths(String path) {
  final segments = normalizeFilePath(path).split('/').where((s) => s.isNotEmpty).toList();
  return [
    '',
    for (var i = 0; i < segments.length; i++) segments.sublist(0, i + 1).join('/'),
  ];
}
