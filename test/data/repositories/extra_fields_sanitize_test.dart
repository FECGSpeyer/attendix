import 'package:attendix/data/models/tenant/tenant.dart';
import 'package:attendix/data/repositories/extra_fields_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const size = ExtraField(id: 'groesse', name: 'Größe', type: 'select', options: ['S', 'Medium'], defaultValue: 'S');

  test('sanitizeExtraFieldValues keeps internal keys and moves a renamed option', () {
    final before = [const ExtraField(id: 'groesse', name: 'Größe', type: 'select', options: ['S', 'M']),
        const ExtraField(id: 'alt', name: 'Alt', type: 'text')];
    final renamed = renamedExtraFieldOptions(before, const [size]);
    expect(renamed, {'groesse': {'M': 'Medium'}});

    final result = sanitizeExtraFieldValues(
      {'groesse': 'M', 'alt': 'x', 'aushilfeBis': '2026-11-30', '_handover_request': {'a': 1}, 'fremd': 1},
      const [size],
      previousIds: before.map((f) => f.id).toSet(),
      renamedOptions: renamed,
    );
    expect(result, {'groesse': 'Medium', 'aushilfeBis': '2026-11-30', '_handover_request': {'a': 1}, 'fremd': 1});
  });
}
