import 'package:attendix/features/redesign/data/rd_type_flags.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Ablauf as type template: Werke become placeholders, agenda one marker, no per-Termin data', () {
    final fields = rdPlanAsTypeTemplate(
      [
        {'id': 'x', 'name': 'Einsingen', 'time': '15', 'conductor': 'Anna', 'currentTime': '19:00', 'uid': 'u1'},
        {'id': '12', 'songId': 12, 'name': '3 Großer Gott', 'time': '20'},
        {'id': 'a1', 'agendaItemId': 'a1', 'name': 'Thema 1', 'time': '10'},
        {'id': 'a2', 'agendaItemId': 'a2', 'name': 'Thema 2', 'time': '10'},
        {'id': '13', 'songId': 13, 'name': '7 Halleluja', 'time': '25'},
      ],
      songPlaceholderName: (n) => 'Werk $n',
      agendaMarker: () => {'id': 'agenda', 'name': 'Tagesordnung', 'time': '0'},
      agendaMarkerId: 'agenda',
    );
    expect(fields, [
      {'id': 'x', 'name': 'Einsingen', 'time': '15'},
      {'id': 'song-placeholder-1', 'name': 'Werk 1', 'time': '20'},
      {'id': 'agenda', 'name': 'Tagesordnung', 'time': '0'},
      {'id': 'song-placeholder-2', 'name': 'Werk 2', 'time': '25'},
    ]);
  });
}
