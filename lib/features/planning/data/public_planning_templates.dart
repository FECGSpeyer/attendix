import '../../../../data/models/plan/plan.dart';

/// Predefined template of the public planning page (Ionic `PUBLIC_PLANNING_TEMPLATES`).
class PublicPlanningTemplate {
  const PublicPlanningTemplate({required this.id, required this.name, this.startTime, this.fields = const []});

  final String id;
  final String name;
  final String? startTime;
  final List<PlanField> fields;
}

PlanField _f(String id, String name, String time, [String? conductor, String? info]) =>
    PlanField(id: id, name: name, time: time, conductor: conductor, info: info);

const _dir = 'Dirigenten';

final publicPlanningTemplates = <PublicPlanningTemplate>[
  PublicPlanningTemplate(id: 'gottesdienst', name: 'Gottesdienst', startTime: '09:35', fields: [
    _f('g-1', 'Gemeinsamer Gesang', '25', _dir),
    _f('g-2', 'Segensgebet', '5'),
    _f('g-3', 'Gemeinsamer Gesang', '5', _dir),
    _f('g-4', '1. Predigt', '15'),
    _f('g-5', 'Gebet', '5'),
    _f('g-6', 'Gemeinsamer Gesang', '5', _dir, '4 & 5 jährige Kinder gehen zur Sonntgsschule'),
    _f('g-7', 'Chor/Orchester', '5'),
    _f('g-8', 'Programm', '15'),
    _f('g-9', 'Chor/Orchester', '5'),
    _f('g-10', 'Gemeinsamer Gesang', '5', _dir),
    _f('g-11', '2. Predigt', '15'),
    _f('g-12', 'Chor/Orchester', '3'),
    _f('g-13', 'Gemeinsamer Gesang', '2', _dir),
    _f('g-14', 'Abschlusspredigt mit Gebet', '25'),
    _f('g-15', 'Vermeldungen', '10'),
  ]),
  PublicPlanningTemplate(id: 'gottesdienst_wednesday', name: 'Gottesdienst (Mittwoch)', startTime: '19:15', fields: [
    _f('g-1', 'Gemeinsamer Gesang', '15', _dir),
    _f('g-2', 'Segensgebet', '5'),
    _f('g-3', 'Gemeinsamer Gesang', '5', _dir),
    _f('g-4', '1. Predigt', '15'),
    _f('g-5', 'Gebet', '5'),
    _f('g-6', 'Chor/Orchester', '5'),
    _f('g-7', 'Gemeinsamer Gesang', '5', _dir),
    _f('g-8', 'Programm', '10'),
    _f('g-9', 'Chor/Orchester', '5'),
    _f('g-12', 'Gemeinsamer Gesang', '5', _dir),
    _f('g-13', 'Abschlusspredigt mit Gebet', '25'),
    _f('g-14', 'Vermeldungen', '5'),
  ]),
  PublicPlanningTemplate(id: 'chorprobe', name: 'Chorprobe', startTime: '19:30', fields: [
    _f('c-1', 'Segensgebet', '10'),
    _f('c-2', 'Einsingen', '10'),
    _f('c-3', 'Werk 1', '22'),
    _f('c-4', 'Werk 2', '22'),
    _f('c-5', 'Werk 3', '22'),
    _f('c-6', 'Abschluss', '4'),
  ]),
  PublicPlanningTemplate(id: 'orchesterprobe', name: 'Orchesterprobe', startTime: '19:30', fields: [
    _f('o-1', 'Segensgebet', '10'),
    _f('o-2', 'Registerproben', '20'),
    _f('o-3', 'Werk 1', '20'),
    _f('o-4', 'Werk 2', '20'),
    _f('o-5', 'Werk 3', '20'),
  ]),
  const PublicPlanningTemplate(id: 'leer', name: 'Leerer Ablauf'),
];

/// Clones template fields with fresh ids (Ionic `cloneTemplateFields`).
List<PlanField> cloneTemplateFields(PublicPlanningTemplate tpl) {
  final stamp = DateTime.now().millisecondsSinceEpoch;
  return [
    for (var i = 0; i < tpl.fields.length; i++)
      tpl.fields[i].copyWith(id: tpl.fields[i].id.startsWith('noteFld') ? 'noteFld $stamp-$i' : '$stamp-$i'),
  ];
}
