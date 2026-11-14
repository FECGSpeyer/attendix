import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/redesign/rd_theme.dart';
import '../../../../core/utils/plan_utils.dart';
import '../../../../data/models/plan/plan.dart';
import '../../../../data/models/song/song.dart';
import '../../../../l10n/l10n.dart';
import '../../../redesign/presentation/widgets/rd_widgets.dart';
import '../pages/public_planning_page.dart' show publicPlanningTemplates;
import 'plan_song_helper.dart';

// REDESIGN: how a new Ablauf starts ("Aus einer Vorlage", "Wie die Probe
// vom …"), shared by the Termin page (Reiter Programm) and the Ablauf
// editor.

/// What the Ablauf editor does first for a Termin, chosen on the Termin
/// page: "works" (the Werke of the Termin that are not in the Ablauf),
/// "copy" (like the last Termin of the Terminart), `tpl:<id>` (a Vorlage,
/// see [rdPlanTemplates]) or "empty". The editor takes it once; it is not
/// part of the address, so a reload does not repeat it.
final rdPlanStartProvider = StateProvider<({int attendanceId, String action})?>((ref) => null);

/// One Vorlage for a new Ablauf. [block]: a saved Programmblock (a part,
/// not a whole Ablauf).
typedef RdPlanTemplate = ({String id, String name, List<PlanField> fields, bool block});

/// "probe" (the Terminart is called "…probe"), "auftritt" (hervorgehobene
/// Terminart) or "other": the word the texts use for the Termin ("Werke
/// dieser Probe").
String rdPlanWorksKind({required String? typeName, required bool highlight}) {
  if (highlight) return 'auftritt';
  return (typeName ?? '').toLowerCase().contains('probe') ? 'probe' : 'other';
}

/// The Vorlagen offered for the Ablauf of a Termin, the nearest first:
/// the one of its Terminart, those of the Organisation, the built-in ones
/// that fit (an Auftritt: Gottesdienst; else the Probe of the group type)
/// and the saved Programmblöcke.
List<RdPlanTemplate> rdPlanTemplates({
  required PlanAttendanceType? type,
  required bool auftritt,
  required String? tenantType,
  required List<Plan> orgTemplates,
  required List<PlanBlockTemplate> blockTemplates,
}) {
  final typeFields = type?.defaultPlan?.fields ?? const <PlanField>[];
  final builtIn = switch ((auftritt, tenantType)) {
    (_, 'general') => const <String>[],
    (true, _) => const ['gottesdienst', 'gottesdienst_wednesday'],
    (false, 'choir') => const ['chorprobe'],
    (false, 'orchestra') => const ['orchesterprobe'],
    _ => const ['chorprobe', 'orchesterprobe'],
  };
  return [
    if (type != null && typeFields.isNotEmpty) (id: 'type', name: type.name, fields: typeFields, block: false),
    for (var i = 0; i < orgTemplates.length; i++)
      if (orgTemplates[i].fields.isNotEmpty)
        (id: 'org:$i', name: orgTemplates[i].title ?? '', fields: orgTemplates[i].fields, block: false),
    for (final tpl in publicPlanningTemplates)
      if (builtIn.contains(tpl.id)) (id: 'builtin:${tpl.id}', name: tpl.name, fields: tpl.fields, block: false),
    for (final tpl in blockTemplates) (id: 'block:${tpl.id}', name: tpl.name, fields: tpl.fields, block: true),
  ];
}

/// Main plan of the newest earlier Termin of the same Terminart that has
/// items ("Wie die Probe vom 26.11.").
({PlanAttendance att, Plan plan})? rdPreviousPlan(PlanAttendance att, List<PlanAttendance> attendances) {
  final date = DateTime.tryParse(att.date);
  if (date == null) return null;
  ({PlanAttendance att, Plan plan, DateTime day})? best;
  for (final a in attendances) {
    final d = DateTime.tryParse(a.date);
    if (a.id == att.id || d == null || !d.isBefore(date) || a.typeId != att.typeId) continue;
    final plan = a.plan;
    if (plan == null || !plan.fields.any((f) => f.agendaItemId == null && !PlanUtils.isAgendaPlaceholder(f))) continue;
    if (best == null || d.isAfter(best.day)) best = (att: a, plan: plan, day: d);
  }
  return best == null ? null : (att: best.att, plan: best.plan);
}

/// Whether [field] is a place for a Werk in a Vorlage: "Chor/Orchester"
/// (Gottesdienst) or "Werk 1" (Probe).
bool rdIsWorkSlot(PlanField field) {
  if (field.isGroup || field.songId != null || PlanUtils.isNote(field)) return false;
  final name = field.name.trim().toLowerCase();
  return name == 'chor/orchester' || RegExp(r'^werk \d+$').hasMatch(name);
}

/// Puts [works] in order into the Werk places of [fields] (see
/// [rdIsWorkSlot]), spread evenly, the earlier places first. A place that
/// takes one Werk keeps its minutes unless the Werk has its own duration;
/// several Werke in one place each get theirs (5 Min by default). A place
/// without a Werk stays as it is. [row] builds the row of a Werk.
///
/// Returns the new rows and how many Werke were placed (0: unchanged).
({List<PlanField> fields, int placed}) rdFillWorkSlots(
  List<PlanField> fields,
  List<Song> works, {
  required PlanField Function(Song song, String time) row,
}) {
  final slots = fields.where(rdIsWorkSlot).length;
  if (slots == 0 || works.isEmpty) return (fields: fields, placed: 0);
  final base = works.length ~/ slots;
  final extra = works.length % slots;
  final result = <PlanField>[];
  var slot = 0;
  var next = 0;
  for (final field in fields) {
    if (!rdIsWorkSlot(field)) {
      result.add(field);
      continue;
    }
    final take = base + (slot < extra ? 1 : 0);
    slot++;
    if (take == 0) {
      result.add(field);
      continue;
    }
    for (var i = 0; i < take; i++) {
      final song = works[next++];
      final own = PlanSongHelper.ownMinutes(song);
      final placed = row(song, take == 1 && own == null ? field.time : PlanSongHelper.betaTime(song));
      result.add(placed.copyWith(groupId: field.groupId));
    }
  }
  return (fields: result, placed: next);
}

/// "6 Werke, je 5 Min"; "6 Werke" when one of them has its own duration.
String rdPlanStartWorksHint(AppLocalizations l10n, List<Song> works) =>
    works.any((s) => PlanSongHelper.ownMinutes(s) != null)
        ? l10n.redesignPlanEventWorksCount(works.length)
        : l10n.redesignPlanStartWorksHint(works.length, PlanSongHelper.betaMinutes);

/// "15 Punkte · 2 Std. 25 Min" / "Block · 15 Min".
String rdPlanTemplateHint(AppLocalizations l10n, RdPlanTemplate tpl) {
  if (tpl.block) {
    return l10n.redesignPlanBlockTemplateHint(PlanUtils.templateMinutes(PlanBlockTemplate(id: '', name: '', fields: tpl.fields)));
  }
  final items = tpl.fields.where((f) => !f.isGroup).toList();
  final minutes = PlanUtils.totalMinutes(tpl.fields);
  final rest = minutes % 60;
  final duration = minutes < 60
      ? l10n.redesignPlanMinutes(minutes)
      : (rest == 0 ? l10n.redesignPlanHours(minutes ~/ 60) : l10n.redesignPlanHoursMinutes(minutes ~/ 60, rest));
  return [l10n.redesignPlanItemCount(items.length), if (minutes > 0) duration].join(' · ');
}

/// "Vorlage wählen": the id of the chosen one of [templates].
/// [startTime]: "16:00", when the Ablauf begins (the Termin's start).
Future<String?> showRdPlanTemplateSheet(
  BuildContext context,
  List<RdPlanTemplate> templates, {
  String startTime = '',
}) {
  final l10n = context.l10n;
  return showRdSheet<String>(
    context,
    Builder(
      builder: (ctx) {
        final p = ctx.rd;
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(header: true, child: Text(l10n.redesignPlanTemplatePick, style: RdType.cardTitle(p))),
              if (startTime.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(l10n.redesignPlanTemplateStarts(startTime), style: RdType.meta(p, size: 15)),
              ],
              const SizedBox(height: 16),
              RdGroupedList(children: [
                for (final tpl in templates)
                  RdListRow(
                    key: ValueKey('rd-plan-template-${tpl.id}'),
                    leading: RdRowIcon(tpl.block ? Icons.view_agenda_outlined : Icons.view_day_outlined),
                    title: tpl.name,
                    subtitle: rdPlanTemplateHint(l10n, tpl),
                    onTap: () => Navigator.of(ctx).pop(tpl.id),
                  ),
              ]),
            ],
          ),
        );
      },
    ),
  );
}
