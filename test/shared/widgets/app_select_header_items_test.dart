import 'package:attendix/shared/widgets/adaptive/app_select.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fromMenuItems skips disabled caption items without a value', () {
    // Bulk edit "Feld auswählen": section captions are disabled items with a
    // null value in a `String` select; they used to throw on the cast.
    final options = AppSelectOption.fromMenuItems<String>(const [
      DropdownMenuItem<String>(enabled: false, child: Text('Standard-Felder')),
      DropdownMenuItem<String>(value: 'firstName', child: Text('Vorname')),
      DropdownMenuItem<String>(value: 'lastName', child: Text('Nachname')),
    ]);
    expect(options.map((o) => o.value), ['firstName', 'lastName']);
  });

  test('fromMenuItems keeps a null option of a nullable select', () {
    final options = AppSelectOption.fromMenuItems<String?>(const [
      DropdownMenuItem<String?>(value: null, child: Text('Keine')),
      DropdownMenuItem<String?>(value: 'a', child: Text('A')),
    ]);
    expect(options.map((o) => o.value), [null, 'a']);
  });
}
