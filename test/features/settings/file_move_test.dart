import 'package:attendix/features/settings/data/file_move.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const noten = MoveItem(path: 'Noten', isFolder: true);
  const pdf = MoveItem(path: 'Noten/a.pdf', isFolder: false);

  test('a folder can move into a sibling with the same prefix', () {
    expect(canMoveInto('Noten-Archiv', [noten]), isTrue);
    expect(canMoveInto('Noten', [noten]), isFalse);
    expect(canMoveInto('Noten/2026', [noten]), isFalse);
  });

  test('moving into the current folder is a no-op', () {
    expect(isCurrentLocation('Noten', [pdf]), isTrue);
    expect(canMoveInto('', [pdf]), isTrue);
  });

  test('ancestors from the root', () {
    expect(ancestorFilePaths('/a//b/'), ['', 'a', 'a/b']);
    expect(ancestorFilePaths(''), ['']);
  });
}
