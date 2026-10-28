import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/config/supabase_config.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/organisation_providers.dart';
import '../../../../core/providers/plan_providers.dart';
import '../../../../core/providers/song_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/services/plan_export_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/plan_utils.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/plan/plan.dart';
import '../../../../data/models/song/song.dart';
import '../../../../data/repositories/public_plan_repository.dart';
import '../widgets/plan_export_actions.dart';
import '../widgets/plan_field_dialogs.dart';
import '../widgets/plan_fields_editor.dart';
import '../widgets/plan_song_helper.dart';
import 'planning_page.dart' show planSongsProvider;

/// Predefined template of the public planning page (Ionic `PUBLIC_PLANNING_TEMPLATES`).
class PublicPlanningTemplate {
  const PublicPlanningTemplate({required this.id, required this.name, this.startTime, this.fields = const []});
  final String id;
  final String name;
  final String? startTime;
  final List<PlanField> fields;
}

/// Branding selectable on the public planning page (Ionic `PUBLIC_BRANDINGS`).
class PublicBranding {
  const PublicBranding(this.id, this.name);
  final String id;
  final String name;
}

const publicBrandings = [
  PublicBranding('none', 'Kein Branding'),
  PublicBranding('fecg-speyer', 'FECG Speyer'),
  PublicBranding('fecg-schwegenheim', 'FECG Schwegenheim'),
];

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

/// Ad-hoc Ablaufplanung (Ionic `PublicPlanningPage`).
///
/// Works without login (`/planung`, local only + anonymous share links) and
/// in the app (`/settings/planung`, saved to `shared_plans` of the user).
class PublicPlanningPage extends ConsumerStatefulWidget {
  const PublicPlanningPage({super.key, this.inApp = false, this.fromOrgPlans = false});

  /// Opened inside the app (logged in).
  final bool inApp;
  final bool fromOrgPlans;

  @override
  ConsumerState<PublicPlanningPage> createState() => _PublicPlanningPageState();
}

class _PublicPlanningPageState extends ConsumerState<PublicPlanningPage> {
  static const _storageKey = 'attendix-public-plan';

  final _titleController = TextEditingController(text: 'Ablaufplan');
  String? _templateId;
  String _brandingId = 'none';
  DateTime _date = DateTime.now();
  String _time = '10:00';
  List<PlanField> _fields = [];
  String? _planId;
  String? _editKey;
  bool _isOrgPlan = false;
  bool _ready = false;
  bool _resolvedSongs = false;
  Timer? _dbTimer;

  bool get _loggedIn => ref.read(supabaseClientProvider).auth.currentSession != null;

  @override
  void initState() {
    super.initState();
    if (_loggedIn && !widget.inApp) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/settings/planung');
      });
      return;
    }
    _restore();
  }

  @override
  void dispose() {
    _dbTimer?.cancel();
    _titleController.dispose();
    super.dispose();
  }

  String get _dateStr =>
      '${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}';

  String get _end => PlanUtils.computeEnd(_time, _fields);

  String get _title => _titleController.text.trim().isEmpty ? 'Ablaufplan' : _titleController.text.trim();

  // ---------------------------------------------------------------------------
  // Persistence
  // ---------------------------------------------------------------------------

  Future<void> _restore() async {
    var restored = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw != null) {
        final s = jsonDecode(raw) as Map<String, dynamic>;
        if (s['selectedFields'] is List) {
          _titleController.text = s['planTitle'] as String? ?? 'Ablaufplan';
          _date = DateTime.tryParse(s['date'] as String? ?? '') ?? _date;
          final t = PlanUtils.formatTime(s['time'] as String?);
          if (t.isNotEmpty) _time = t;
          _templateId = s['selectedTemplateId'] as String?;
          _brandingId = s['selectedBrandingId'] as String? ?? 'none';
          _fields = (s['selectedFields'] as List)
              .map((e) => PlanField.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();
          _planId = s['currentPlanId'] as String?;
          _editKey = s['currentEditKey'] as String?;
          restored = true;
        }
      }
    } catch (_) {
      // Storage unavailable / corrupt: start with the first template.
    }
    if (!restored) {
      _templateId = publicPlanningTemplates.first.id;
      _applyTemplate(publicPlanningTemplates.first, persist: false);
    }
    if (mounted) setState(() => _ready = true);
  }

  Future<void> _persistLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _storageKey,
        jsonEncode({
          'planTitle': _titleController.text,
          'date': _dateStr,
          'time': '${_dateStr}T$_time',
          'end': '${_dateStr}T$_end',
          'selectedTemplateId': _templateId,
          'selectedBrandingId': _brandingId,
          'selectedFields': _fields.map((f) => f.toJson()).toList(),
          'currentPlanId': _planId,
          'currentEditKey': _editKey,
        }),
      );
    } catch (_) {}
  }

  /// Ionic `calculateEnd`: normalize, persist locally and (logged in) debounce the DB save.
  void _changed() {
    _fields = PlanUtils.normalizeGroups(_fields);
    _persistLocal();
    if (_loggedIn) {
      _dbTimer?.cancel();
      _dbTimer = Timer(const Duration(milliseconds: 500), _persistToDb);
    }
  }

  SharedPlan _currentShared(String id, String editKey) => SharedPlan(
        id: id,
        editKey: editKey,
        planTitle: _title,
        date: _dateStr,
        time: '${_dateStr}T$_time',
        endTime: '${_dateStr}T$_end',
        fields: _fields,
        brandingId: _brandingId != 'none' ? _brandingId : null,
      );

  Future<void> _persistToDb() async {
    if (!_loggedIn) return;
    if (_planId == null) {
      _planId = PlanUtils.randomKey();
      _editKey = PlanUtils.randomKey();
      _persistLocal();
    }
    try {
      await ref.read(planRepositoryWithTenantProvider).upsertMySharedPlan(_currentShared(_planId!, _editKey!));
      ref.invalidate(mySharedPlansProvider);
      if (_isOrgPlan) ref.invalidate(orgPlansProvider);
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // Templates
  // ---------------------------------------------------------------------------

  List<SongHistory> get _history =>
      (ref.read(currentSongsProvider).valueOrNull ?? const []).expand((e) => e.history).toList();

  List<Song> get _songs => _loggedIn ? (ref.read(planSongsProvider).valueOrNull ?? const []) : const [];

  String _numberPrefix(Song song) => '${song.number ?? ''}. ';

  /// Replaces "Chor/Orchester" / "Werk N" rows with the current Werke (logged in only).
  List<PlanField> _resolvePublicTemplateFields(List<PlanField> fields) {
    final history = _history;
    final songs = _songs;
    if (history.isEmpty || songs.isEmpty) return fields;
    final pattern = RegExp(r'^(Chor\/Orchester|Werk\s+\d+)', caseSensitive: false);
    final added = <int>{};
    return fields.map((field) {
      if (!pattern.hasMatch(field.name)) return field;
      final h = history.where((h) => h.songId != null && !added.contains(h.songId)).firstOrNull;
      if (h == null) return field;
      added.add(h.songId!);
      final song = songs.where((s) => s.id == h.songId).firstOrNull;
      if (song == null) return field;
      return field.copyWith(
        id: '${song.id}',
        name: '${_numberPrefix(song)}${song.name}',
        conductor: (h.conductorName?.isNotEmpty ?? false) ? h.conductorName : (field.conductor ?? ''),
        songId: song.id,
      );
    }).toList();
  }

  void _applyTemplate(PublicPlanningTemplate tpl, {bool persist = true}) {
    setState(() {
      _titleController.text = tpl.name;
      if (tpl.startTime != null) _time = tpl.startTime!;
      _fields = _resolvePublicTemplateFields(cloneTemplateFields(tpl));
    });
    if (persist) _changed();
  }

  Future<bool> _confirmReplace() async {
    if (_fields.isEmpty) return true;
    return showPlanConfirm(
      context,
      title: 'Vorlage anwenden',
      message: 'Aktuellen Ablauf durch die Vorlage ersetzen?',
      confirmText: 'Ersetzen',
    );
  }

  Future<void> _onTemplateChange(String? id) async {
    if (id == null) return;
    final previous = _templateId;
    setState(() => _templateId = id);
    if (!await _confirmReplace()) {
      if (mounted) setState(() => _templateId = previous);
      return;
    }
    if (id.startsWith('org:')) {
      final org = ref.read(currentOrganisationProvider).valueOrNull;
      final templates = org?.planningTemplates ?? const <Plan>[];
      final idx = int.tryParse(id.substring(4)) ?? -1;
      if (idx < 0 || idx >= templates.length) return;
      final tpl = templates[idx];
      setState(() {
        _fields = PlanSongHelper.resolvePlaceholders(tpl.fields,
            history: _history, songs: _songs, prefix: _numberPrefix);
        if ((tpl.title ?? '').isNotEmpty) _titleController.text = tpl.title!;
        final t = PlanUtils.formatTime(tpl.time);
        if (t.isNotEmpty) _time = t;
      });
      _changed();
      return;
    }
    final tpl = publicPlanningTemplates.where((t) => t.id == id).firstOrNull;
    if (tpl != null) _applyTemplate(tpl);
  }

  Future<void> _resetToTemplate() async {
    final tpl = publicPlanningTemplates.where((t) => t.id == _templateId).firstOrNull;
    if (tpl == null) {
      ToastHelper.showWarning(context, 'Keine Vorlage ausgewählt.');
      return;
    }
    final ok = await showPlanConfirm(
      context,
      title: 'Vorlage wiederherstellen',
      message: 'Alle Änderungen verwerfen und die Standardwerte der Vorlage „${tpl.name}“ wiederherstellen?',
      confirmText: 'Wiederherstellen',
    );
    if (ok) _applyTemplate(tpl);
  }

  // ---------------------------------------------------------------------------
  // Fields
  // ---------------------------------------------------------------------------

  Future<void> _showAddMenu() async {
    final loggedIn = _loggedIn;
    final isGeneral = ref.read(currentTenantProvider)?.type == 'general';
    final org = loggedIn ? ref.read(currentOrganisationProvider).valueOrNull : null;
    final orgFields = org?.defaultFields ?? const <PlanField>[];
    final blockTemplates = loggedIn
        ? (ref.read(planBlockTemplatesProvider).valueOrNull ?? const <PlanBlockTemplate>[])
        : const <PlanBlockTemplate>[];
    final action = await showPlanActionSheet<String>(
      context,
      actions: [
        const PlanSheetAction('field', 'Feld hinzufügen', icon: Icons.add),
        const PlanSheetAction('group', 'Programmblock hinzufügen', icon: Icons.view_agenda_outlined),
        const PlanSheetAction('note', 'Notizfeld hinzufügen', icon: Icons.sticky_note_2_outlined),
        if (loggedIn && !isGeneral) ...[
          const PlanSheetAction('current', 'Aktuelle Werke hinzufügen', icon: Icons.library_music_outlined),
          if (_songs.isNotEmpty) const PlanSheetAction('song', 'Werk hinzufügen', icon: Icons.music_note_outlined),
        ],
        for (var i = 0; i < orgFields.length; i++)
          PlanSheetAction('orgfield:$i', 'Feld: ${orgFields[i].name} (${orgFields[i].time} min)'),
        for (final tpl in blockTemplates)
          PlanSheetAction('block:${tpl.id}', 'Programmblock: ${tpl.name} (${PlanUtils.templateMinutes(tpl)} min)'),
      ],
    );
    if (action == null || !mounted) return;
    if (action.startsWith('orgfield:')) {
      setState(() => _fields = [..._fields, orgFields[int.parse(action.substring(9))]]);
      _changed();
      return;
    }
    if (action.startsWith('block:')) {
      final tpl = blockTemplates.where((t) => t.id == action.substring(6)).firstOrNull;
      if (tpl == null) return;
      setState(() => _fields = [..._fields, ...PlanUtils.cloneBlock(tpl.fields)]);
      _changed();
      return;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    switch (action) {
      case 'field':
        final r = await showPlanFieldDialog(context,
            title: 'Feld hinzufügen', conductorHint: 'Ausführender (optional)', withMinutes: false);
        if (r == null) return;
        setState(() => _fields = [
              ..._fields,
              PlanField(id: '${r.name}-$now', name: r.name, conductor: r.conductor, info: r.info, time: '20'),
            ]);
      case 'note':
        final r = await showPlanFieldDialog(context,
            title: 'Notizfeld hinzufügen',
            nameLabel: 'Notiz',
            nameHint: 'Notiz eingeben...',
            emptyNameMessage: 'Bitte eine Notiz eingeben.',
            withConductor: false,
            withInfo: false,
            withMinutes: false);
        if (r == null) return;
        setState(() =>
            _fields = [..._fields, PlanField(id: 'noteFld ${r.name}-$now', name: r.name, conductor: '', time: '0')]);
      case 'group':
        await _addGroup();
        return;
      case 'current':
        final added = PlanSongHelper.currentSongFields(_fields,
            history: _history, songs: _songs, prefix: _numberPrefix);
        setState(() => _fields = [..._fields, ...added]);
      case 'song':
        final song = await showPlanSongPicker(context, _songs);
        if (song == null) return;
        setState(() => _fields = [
              ..._fields,
              PlanSongHelper.songField(song, history: _history, prefix: _numberPrefix),
            ]);
    }
    _changed();
  }

  Future<void> _addGroup() async {
    final r = await showPlanFieldDialog(
      context,
      title: 'Programmblock hinzufügen',
      message: 'Die Dauer ergibt sich aus den Unterpunkten.',
      nameLabel: 'Name',
      nameHint: 'Name, z. B. Programm Jugendchor',
      conductorLabel: 'Ausführung',
      conductorHint: 'Ausführung (optional)',
      confirmText: 'Anlegen',
      emptyNameMessage: 'Bitte einen Namen eingeben.',
      withMinutes: false,
    );
    if (r == null || !mounted) return;
    final head = PlanUtils.newGroupHead(r.name, conductor: r.conductor, info: r.info);
    setState(() => _fields = [..._fields, head]);
    _changed();
    final sub = await showPlanFieldDialog(
      context,
      title: 'Unterpunkt hinzufügen',
      subtitle: head.name,
      nameHint: 'Programmpunkt, z. B. Gruppenlied',
      infoHint: 'Info-Text (optional), z. B. Liedtitel',
      initialMinutes: 5,
    );
    if (sub == null) return;
    setState(() => _fields = PlanUtils.addSubItem(
          _fields,
          head.id,
          PlanField(
            id: 'fld-${PlanUtils.uuid()}',
            name: sub.name,
            conductor: sub.conductor,
            info: sub.info,
            time: '${sub.minutes ?? 5}',
          ),
        ));
    _changed();
  }

  // ---------------------------------------------------------------------------
  // Plans of the user / organisation
  // ---------------------------------------------------------------------------

  Future<void> _newPlan() async {
    if (_fields.isNotEmpty) {
      final ok = await showPlanConfirm(
        context,
        title: 'Neuer Plan',
        message: 'Aktuellen Plan verwerfen und einen neuen erstellen?',
        confirmText: 'Neuer Plan',
      );
      if (!ok) return;
    }
    setState(() {
      _planId = null;
      _editKey = null;
      _titleController.text = 'Ablaufplan';
      _date = DateTime.now();
      _time = '10:00';
      _fields = [];
      _templateId = null;
      _brandingId = 'none';
      _isOrgPlan = false;
    });
    _persistLocal();
  }

  void _loadPlan(SharedPlan plan) {
    setState(() {
      _planId = plan.id;
      _editKey = plan.editKey;
      _titleController.text = (plan.planTitle?.isNotEmpty ?? false) ? plan.planTitle! : 'Ablaufplan';
      _date = DateTime.tryParse(plan.date ?? '') ?? DateTime.now();
      final t = PlanUtils.formatTime(plan.time);
      _time = t.isEmpty ? '10:00' : t;
      _fields = [...plan.fields];
      _brandingId = plan.brandingId ?? 'none';
      _isOrgPlan = plan.orgId != null;
    });
    _persistLocal();
  }

  Future<void> _openMyPlans() async {
    final plan = await showModalBottomSheet<SharedPlan>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _MyPlansSheet(),
    );
    if (plan != null) _loadPlan(plan);
  }

  Future<void> _toggleOrg() async {
    final org = ref.read(currentOrganisationProvider).valueOrNull;
    if (org?.id == null) return;
    final repo = ref.read(planRepositoryWithTenantProvider);
    if (_isOrgPlan) {
      if (_planId == null) return;
      try {
        await repo.setMySharedPlanOrg(_planId!, null);
        setState(() => _isOrgPlan = false);
        ref.invalidate(orgPlansProvider);
        if (mounted) ToastHelper.showSuccess(context, 'Plan aus Organisation entfernt');
      } catch (_) {
        if (mounted) ToastHelper.showError(context, 'Fehler beim Entfernen aus der Organisation');
      }
      return;
    }
    if (!_validate()) return;
    await _persistToDb();
    if (_planId == null) {
      if (mounted) ToastHelper.showError(context, 'Fehler beim Speichern des Plans');
      return;
    }
    try {
      await repo.setMySharedPlanOrg(_planId!, org!.id);
      setState(() => _isOrgPlan = true);
      ref.invalidate(orgPlansProvider);
      if (mounted) ToastHelper.showSuccess(context, 'Plan zur Organisation "${org.name}" hinzugefügt');
    } catch (_) {
      if (mounted) ToastHelper.showError(context, 'Fehler beim Hinzufügen zur Organisation');
    }
  }

  // ---------------------------------------------------------------------------
  // Share / export
  // ---------------------------------------------------------------------------

  bool _validate() {
    if (_time.isEmpty || _fields.isEmpty) {
      ToastHelper.showWarning(context, 'Bitte mindestens ein Feld hinzufügen.');
      return false;
    }
    if (!_fields.every((f) => PlanUtils.isNote(f) || PlanUtils.isGroupHead(f) || f.time.trim().isNotEmpty)) {
      ToastHelper.showWarning(context, 'Bitte alle Dauern ausfüllen.');
      return false;
    }
    return true;
  }

  List<PlanExportPage> _pages() => [
        PlanExportPage(
          title: _title,
          subtitle: PlanUtils.longDate(_date),
          time: _time,
          end: _end,
          fields: _fields,
        ),
      ];

  String get _fileName =>
      '${_title}_${_date.day.toString().padLeft(2, '0')}_${_date.month.toString().padLeft(2, '0')}_${_date.year}';

  Future<void> _showExportOptions() async {
    if (!_validate()) return;
    await showPlanExportSheet(context, ref, pages: _pages, fileName: _fileName);
  }

  Future<void> _shareCurrentPlan() async {
    if (!_validate()) return;
    await showPlanExportSheet(
      context,
      ref,
      title: 'Teilen & Exportieren',
      pages: _pages,
      fileName: _fileName,
      extraActions: const [
        PlanSheetAction('read', 'Nur-Lesen-Link', icon: Icons.link),
        PlanSheetAction('edit', 'Bearbeitungs-Link', icon: Icons.edit_note),
      ],
      onExtraAction: (a) => _doShare(a == 'edit'),
    );
  }

  Future<void> _doShare(bool editLink) async {
    String id;
    String editKey;
    if (_loggedIn) {
      if (_planId == null) await _persistToDb();
      if (_planId == null) {
        if (mounted) ToastHelper.showError(context, 'Fehler beim Erstellen des Links');
        return;
      }
      id = _planId!;
      editKey = _editKey!;
    } else {
      // Anonymous: one-off insert without creator.
      id = PlanUtils.randomKey();
      editKey = PlanUtils.randomKey();
      try {
        await ref.read(publicPlanRepositoryProvider).insertAnonymousSharedPlan(_currentShared(id, editKey));
      } catch (_) {
        if (mounted) ToastHelper.showError(context, 'Fehler beim Erstellen des Links');
        return;
      }
    }
    final base = '/plan?key=$id';
    final url = planPublicUrl(editLink ? '$base&edit=$editKey' : base);
    if (mounted) await sharePlanLink(context, url, title: _title);
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      locale: const Locale('de', 'DE'),
    );
    if (picked == null) return;
    setState(() => _date = picked);
    _changed();
  }

  Future<void> _pickTime() async {
    final m = PlanUtils.parseTimeToMinutes(_time) ?? 600;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: m ~/ 60, minute: m % 60),
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() => _time = PlanUtils.formatMinutes(picked.hour * 60 + picked.minute));
    _changed();
  }

  @override
  Widget build(BuildContext context) {
    final loggedIn = _loggedIn;
    final org = loggedIn ? ref.watch(currentOrganisationProvider).valueOrNull : null;
    if (loggedIn) {
      ref.watch(planSongsProvider);
      final history = ref.watch(currentSongsProvider);
      // Re-resolve placeholder rows once songs and history are loaded (Ionic ngOnInit).
      if (_ready && !_resolvedSongs && history.hasValue && ref.read(planSongsProvider).hasValue) {
        _resolvedSongs = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() => _fields = _resolvePublicTemplateFields(_fields));
        });
      }
    }
    final orgTemplates = org?.planningTemplates ?? const <Plan>[];

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: widget.inApp,
        title: const Text('Ablaufplanung'),
        actions: [
          if (loggedIn)
            IconButton(tooltip: 'Meine Pläne', icon: const Icon(Icons.list), onPressed: _openMyPlans),
          IconButton(tooltip: 'Teilen & Exportieren', icon: const Icon(Icons.ios_share), onPressed: _shareCurrentPlan),
        ],
      ),
      body: !_ready
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.only(bottom: 32),
              children: [
                Card(
                  margin: const EdgeInsets.all(AppDimensions.paddingM),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Focus(
                            onFocusChange: (f) {
                              if (!f) _changed();
                            },
                            child: TextField(
                              controller: _titleController,
                              textCapitalization: TextCapitalization.sentences,
                              decoration: const InputDecoration(labelText: 'Titel', hintText: 'Ablaufplan'),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                          child: DropdownButtonFormField<String>(
                            key: ValueKey('tpl-$_templateId'),
                            value: _templateId,
                            isExpanded: true,
                            decoration: const InputDecoration(labelText: 'Vorlage'),
                            items: [
                              for (final t in publicPlanningTemplates)
                                DropdownMenuItem(value: t.id, child: Text(t.name)),
                              if (loggedIn && orgTemplates.isNotEmpty) ...[
                                const DropdownMenuItem(
                                    value: '', enabled: false, child: Text('── Org-Vorlagen ──')),
                                for (var i = 0; i < orgTemplates.length; i++)
                                  DropdownMenuItem(value: 'org:$i', child: Text('${orgTemplates[i].title ?? ''} (Org)')),
                              ],
                            ],
                            onChanged: _onTemplateChange,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                          child: DropdownButtonFormField<String>(
                            key: ValueKey('brand-$_brandingId'),
                            value: _brandingId,
                            isExpanded: true,
                            decoration: const InputDecoration(labelText: 'Branding'),
                            items: [
                              for (final b in publicBrandings) DropdownMenuItem(value: b.id, child: Text(b.name)),
                            ],
                            onChanged: (v) {
                              setState(() => _brandingId = v ?? 'none');
                              _changed();
                            },
                          ),
                        ),
                        ListTile(
                          title: const Text('Datum'),
                          trailing: TextButton(
                            onPressed: _pickDate,
                            child: Text(
                                '${_date.day.toString().padLeft(2, '0')}.${_date.month.toString().padLeft(2, '0')}.${_date.year}'),
                          ),
                        ),
                        ListTile(
                          leading: const Icon(Icons.refresh, color: AppColors.primary),
                          title: const Text('Vorlage wiederherstellen', style: TextStyle(color: AppColors.primary)),
                          onTap: _resetToTemplate,
                        ),
                        if (org != null)
                          ListTile(
                            leading: Icon(_isOrgPlan ? Icons.check_circle : Icons.business_outlined,
                                color: _isOrgPlan ? AppColors.success : AppColors.primary),
                            title: Text(
                              _isOrgPlan ? 'In Organisation "${org.name}"' : 'Zur Organisation hinzufügen',
                              style: TextStyle(color: _isOrgPlan ? AppColors.success : AppColors.primary),
                            ),
                            onTap: _toggleOrg,
                          ),
                        if (loggedIn)
                          ListTile(
                            leading: const Icon(Icons.add_circle_outline, color: AppColors.medium),
                            title: const Text('Neuer Plan', style: TextStyle(color: AppColors.medium)),
                            onTap: _newPlan,
                          ),
                      ],
                    ),
                  ),
                ),
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingM),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ListTile(
                        title: const Text('Ablauf', style: TextStyle(fontWeight: FontWeight.bold)),
                        trailing: IconButton(icon: const Icon(Icons.add), onPressed: _showAddMenu),
                      ),
                      ListTile(
                        title: const Text('Start'),
                        trailing: TextButton(onPressed: _pickTime, child: Text('$_time Uhr')),
                      ),
                      const Divider(height: 1),
                      PlanFieldsEditor(
                        fields: _fields,
                        startTime: _time,
                        onChanged: (f) {
                          setState(() => _fields = f);
                          _changed();
                        },
                      ),
                      if (_fields.isNotEmpty)
                        ListTile(
                          title: const Text('Ende'),
                          trailing: Text('$_end Uhr', style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(AppDimensions.paddingM),
                  child: FilledButton.icon(
                    onPressed: _showExportOptions,
                    icon: const Icon(Icons.ios_share),
                    label: const Text('Exportieren'),
                  ),
                ),
              ],
            ),
    );
  }
}

/// "Meine Pläne" (Ionic `MyPlansComponent`).
class _MyPlansSheet extends ConsumerWidget {
  const _MyPlansSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plansAsync = ref.watch(mySharedPlansProvider);
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.85,
        child: Column(
          children: [
            ListTile(
              title: const Text('Meine Pläne', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              trailing: TextButton(onPressed: () => Navigator.pop(context), child: const Text('Schließen')),
            ),
            Expanded(
              child: plansAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Fehler: $e')),
                data: (plans) {
                  if (plans.isEmpty) {
                    return const Center(
                      child: Text('Keine Pläne vorhanden.', style: TextStyle(color: AppColors.medium)),
                    );
                  }
                  return ListView.builder(
                    itemCount: plans.length,
                    itemBuilder: (_, i) {
                      final plan = plans[i];
                      final d = DateTime.tryParse(plan.date ?? '');
                      final date = d == null
                          ? ''
                          : '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
                      final count = plan.fields.length;
                      final title = (plan.planTitle?.isNotEmpty ?? false) ? plan.planTitle! : 'Ablaufplan';
                      return Dismissible(
                        key: ValueKey(plan.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          color: AppColors.danger,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 16),
                          child: const Icon(Icons.delete_outline, color: Colors.white),
                        ),
                        confirmDismiss: (_) async {
                          final ok = await showPlanConfirm(
                            context,
                            title: 'Plan löschen',
                            message: '"$title" endgültig löschen?',
                            confirmText: 'Löschen',
                            destructive: true,
                          );
                          if (!ok) return false;
                          try {
                            await ref.read(planRepositoryWithTenantProvider).deleteMySharedPlan(plan.id);
                            ref.invalidate(mySharedPlansProvider);
                            return true;
                          } catch (_) {
                            if (context.mounted) ToastHelper.showError(context, 'Fehler beim Löschen');
                            return false;
                          }
                        },
                        child: ListTile(
                          title: Text(title),
                          subtitle: Text('$date${count > 0 ? ' · $count Felder' : ''}'),
                          trailing: const Icon(Icons.chevron_right, color: AppColors.medium),
                          onTap: () => Navigator.pop(context, plan),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
