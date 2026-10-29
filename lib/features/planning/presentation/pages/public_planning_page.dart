import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show GoTrueClient;

import '../../../../core/config/supabase_config.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/organisation_providers.dart';
import '../../../../core/providers/plan_providers.dart';
import '../../../../core/providers/song_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/services/plan_export_service.dart';
import '../../../../core/services/public_plan_draft_storage.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/plan_utils.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/plan/plan.dart';
import '../../../../data/models/song/song.dart';
import '../../../../data/repositories/plan_repository.dart';
import '../../../../data/repositories/public_plan_repository.dart';
import '../../data/shared_plan_save_chain.dart';
import '../widgets/plan_export_actions.dart';
import '../widgets/plan_field_dialogs.dart';
import '../widgets/plan_fields_editor.dart';
import '../widgets/plan_song_helper.dart';
import '../widgets/ion_items.dart';
import 'planning_page.dart' show planSongsProvider;
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/layout/centered_content.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart'; // IOS_LOOK

export '../widgets/ion_items.dart' show IonDatetimeChip;

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
  /// SOL_FIX12: the draft belongs to the auth user that opened the page
  /// (anonymous drafts separate) — never a global key shared by accounts.
  String? _draftUserId;
  String get _storageKey => PublicPlanDraftStorage.keyFor(_draftUserId);

  /// SOL_FIX15: auth client and provider container captured in initState,
  /// so a save flushed from [dispose] never touches `ref`.
  GoTrueClient? _auth;
  late final ProviderContainer _container;

  String? get _currentUserId => _auth?.currentUser?.id;

  /// SOL_FIX15: serialised, account-bound DB saves per plan.
  late final _saveChain = SharedPlanSaveChain(currentUserId: () => _currentUserId);

  /// SOL_FIX15: id / edit key of a plan that was never saved successfully.
  /// They become [_planId] / [_editKey] only after the first successful save.
  String? _unsavedPlanId;
  String? _unsavedEditKey;

  /// Tenant repository captured when the debounced save was scheduled.
  PlanRepository? _dbRepo;

  final _titleController = TextEditingController(text: l10nWithoutContext.plansRunSheet);
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

  bool get _loggedIn => _auth?.currentSession != null;

  @override
  void initState() {
    super.initState();
    _container = ProviderScope.containerOf(context, listen: false);
    try {
      _auth = ref.read(supabaseClientProvider).auth;
    } catch (_) {
      _auth = null; // Supabase not initialised (tests): local only.
    }
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
    // SOL_FIX15: leaving the page within the debounce window still saves
    // the last changes (through the per-plan chain, bound to the account).
    if (_dbTimer?.isActive ?? false) unawaited(_persistToDb(repo: _dbRepo));
    _dbTimer?.cancel();
    _titleController.dispose();
    super.dispose();
  }

  String get _dateStr =>
      '${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}';

  String get _end => PlanUtils.computeEnd(_time, _fields);

  String get _title => _titleController.text.trim().isEmpty ? l10nWithoutContext.plansRunSheet : _titleController.text.trim();

  // ---------------------------------------------------------------------------
  // Persistence
  // ---------------------------------------------------------------------------

  Future<void> _restore() async {
    var restored = false;
    _draftUserId = _currentUserId;
    try {
      final prefs = await SharedPreferences.getInstance();
      await PublicPlanDraftStorage.dropLegacy(prefs);
      final raw = prefs.getString(_storageKey);
      if (raw != null) {
        final s = jsonDecode(raw) as Map<String, dynamic>;
        if (s['selectedFields'] is List) {
          _titleController.text = s['planTitle'] as String? ?? l10nWithoutContext.plansRunSheet;
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
    // SOL_FIX12: never write a draft once the account has changed (sign-out
    // clears it; a late write must not recreate it or leak into another key).
    if (_currentUserId != _draftUserId) return;
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
      _dbRepo = ref.read(planRepositoryWithTenantProvider);
      _dbTimer?.cancel();
      _dbTimer = Timer(const Duration(milliseconds: 500), _autosave);
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

  /// Debounced autosave; a failed save shows an error toast.
  Future<void> _autosave() async {
    final account = _draftUserId;
    final ok = await _persistToDb();
    if (!ok && mounted && account != null && _currentUserId == account) {
      ToastHelper.showError(context, context.l10n.plansSavePlanFailed);
    }
  }

  /// SOL_FIX15: saves the current state through the per-plan save chain,
  /// bound to the account that opened the page, and reports explicitly
  /// whether it reached the database. A new plan gets its id / edit key
  /// (and keeps them in the local draft) only after a successful save.
  Future<bool> _persistToDb({PlanRepository? repo}) async {
    _dbTimer?.cancel();
    final account = _draftUserId;
    if (!_loggedIn || account == null || _currentUserId != account) return false;
    final PlanRepository planRepo = repo ?? ref.read(planRepositoryWithTenantProvider);
    final isNew = _planId == null;
    final id = _planId ?? (_unsavedPlanId ??= PlanUtils.randomKey());
    final editKey = _editKey ?? (_unsavedEditKey ??= PlanUtils.randomKey());
    // Snapshot now: a later edit is saved by its own (later) chain entry.
    final snapshot = _currentShared(id, editKey);
    final isOrgPlan = _isOrgPlan;
    final ok = await _saveChain.save(
      id,
      accountId: account,
      write: () => planRepo.upsertMySharedPlan(snapshot, expectedUserId: account),
    );
    if (!ok) return false;
    if (isNew && _planId == null && _unsavedPlanId == id) {
      _planId = id;
      _editKey = editKey;
      _unsavedPlanId = null;
      _unsavedEditKey = null;
      await _persistLocal();
    }
    _container.invalidate(mySharedPlansProvider);
    if (isOrgPlan) _container.invalidate(orgPlansProvider);
    return true;
  }

  /// SOL_FIX15: saves pending (debounced) changes of the current plan
  /// before another plan replaces it on the page.
  void _flushPendingSave() {
    if (_dbTimer?.isActive ?? false) unawaited(_persistToDb(repo: _dbRepo));
    _unsavedPlanId = null;
    _unsavedEditKey = null;
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
      title: context.l10n.plansApplyTemplate,
      message: context.l10n.plansReplaceWithTemplate,
      confirmText: context.l10n.personReplace,
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
      ToastHelper.showWarning(context, context.l10n.plansNoTemplate);
      return;
    }
    final ok = await showPlanConfirm(
      context,
      title: context.l10n.plansRestoreTemplate,
      message: context.l10n.plansRestoreTemplateMessage(tpl.name),
      confirmText: context.l10n.plansRestore,
    );
    if (ok) _applyTemplate(tpl);
  }

  // ---------------------------------------------------------------------------
  // Fields
  // ---------------------------------------------------------------------------

  /// Ionic `ion-popover` (trigger="add-trigger") anchored below the "+"
  /// button of the run-sheet header: plain items, then dividers with small
  /// bold section labels for org fields and block templates.
  Future<void> _showAddMenu(BuildContext anchorContext) async {
    final loggedIn = _loggedIn;
    final isGeneral = ref.read(currentTenantProvider)?.type == 'general';
    final org = loggedIn ? ref.read(currentOrganisationProvider).valueOrNull : null;
    final orgFields = org?.defaultFields ?? const <PlanField>[];
    final blockTemplates = loggedIn
        ? (ref.read(planBlockTemplatesProvider).valueOrNull ?? const <PlanBlockTemplate>[])
        : const <PlanBlockTemplate>[];
    final l10n = context.l10n;
    PopupMenuItem<String> item(String value, String label, [String? note]) => PopupMenuItem<String>(
          value: value,
          child: Text.rich(TextSpan(children: [
            TextSpan(text: label),
            if (note != null) TextSpan(text: ' $note', style: const TextStyle(color: AppColors.medium)),
          ])),
        );
    PopupMenuItem<String> section(String label) => PopupMenuItem<String>(
          enabled: false,
          height: 32,
          child: Text(label,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyMedium?.color)),
        );
    final box = anchorContext.findRenderObject() as RenderBox;
    final overlay = Navigator.of(anchorContext).overlay!.context.findRenderObject() as RenderBox;
    final topLeft = box.localToGlobal(Offset(0, box.size.height), ancestor: overlay);
    final bottomRight = box.localToGlobal(box.size.bottomRight(Offset.zero), ancestor: overlay);
    final action = await showMenu<String>(
      context: anchorContext,
      position: RelativeRect.fromRect(Rect.fromPoints(topLeft, bottomRight), Offset.zero & overlay.size),
      items: [
        item('field', l10n.planningAddField),
        item('group', l10n.planningAddBlock),
        item('note', l10n.planningAddNoteField),
        if (loggedIn && !isGeneral) ...[
          item('current', l10n.planningAddCurrentSongs),
          if (_songs.isNotEmpty) item('song', l10n.planningAddSong),
        ],
        if (orgFields.isNotEmpty) ...[
          const PopupMenuDivider(),
          section(l10n.planningFields),
          for (var i = 0; i < orgFields.length; i++)
            item('orgfield:$i', orgFields[i].name, l10n.planningMinShort(orgFields[i].time)),
        ],
        if (blockTemplates.isNotEmpty) ...[
          const PopupMenuDivider(),
          section(l10n.planningBlocks),
          for (final tpl in blockTemplates)
            item('block:${tpl.id}', tpl.name, l10n.planningMinShort(PlanUtils.templateMinutes(tpl))),
        ],
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
            title: context.l10n.planningAddField,
            conductorHint: context.l10n.plansPerformerOptional,
            withMinutes: false);
        if (r == null) return;
        setState(() => _fields = [
              ..._fields,
              PlanField(id: '${r.name}-$now', name: r.name, conductor: r.conductor, info: r.info, time: '20'),
            ]);
      case 'note':
        final r = await showPlanFieldDialog(context,
            title: context.l10n.planningAddNoteField,
            nameLabel: context.l10n.planningNote,
            nameHint: context.l10n.planningEnterNote,
            emptyNameMessage: context.l10n.plansEnterNotePlease,
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
      title: context.l10n.planningAddBlock,
      message: context.l10n.planningBlockDurationHint,
      nameLabel: context.l10n.planningName,
      nameHint: context.l10n.planningBlockNamePlaceholder,
      conductorLabel: context.l10n.planningPerformance,
      conductorHint: context.l10n.planningPerformanceOptional,
      confirmText: context.l10n.commonCreate,
      emptyNameMessage: context.l10n.planningEnterNamePlease,
      withMinutes: false,
    );
    if (r == null || !mounted) return;
    final head = PlanUtils.newGroupHead(r.name, conductor: r.conductor, info: r.info);
    setState(() => _fields = [..._fields, head]);
    _changed();
    final sub = await showPlanFieldDialog(
      context,
      title: context.l10n.planningAddSubItem,
      subtitle: head.name,
      nameHint: context.l10n.planningSubItemPlaceholder,
      infoHint: context.l10n.planningSubItemInfoPlaceholder,
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
        title: context.l10n.plansNewPlan,
        message: context.l10n.plansDiscardNew,
        confirmText: context.l10n.plansNewPlan,
      );
      if (!ok) return;
    }
    _flushPendingSave(); // SOL_FIX15
    setState(() {
      _planId = null;
      _editKey = null;
      _titleController.text = l10nWithoutContext.plansRunSheet;
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
    _flushPendingSave(); // SOL_FIX15
    setState(() {
      _planId = plan.id;
      _editKey = plan.editKey;
      _titleController.text = (plan.planTitle?.isNotEmpty ?? false) ? plan.planTitle! : l10nWithoutContext.plansRunSheet;
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
    // Ionic: full ion-modal (MyPlansComponent).
    final plan = await Navigator.of(context, rootNavigator: true).push<SharedPlan>(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => const _MyPlansSheet(),
    ));
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
        if (mounted) ToastHelper.showSuccess(context, context.l10n.plansRemovedFromOrg);
      } catch (_) {
        if (mounted) ToastHelper.showError(context, context.l10n.plansRemoveOrgFailed);
      }
      return;
    }
    if (!_validate()) return;
    // SOL_FIX15: only a successfully saved plan can be added.
    if (!await _persistToDb() || _planId == null) {
      if (mounted) ToastHelper.showError(context, context.l10n.plansSavePlanFailed);
      return;
    }
    try {
      await repo.setMySharedPlanOrg(_planId!, org!.id);
      setState(() => _isOrgPlan = true);
      ref.invalidate(orgPlansProvider);
      if (mounted) ToastHelper.showSuccess(context, context.l10n.plansAddedToOrg(org.name));
    } catch (_) {
      if (mounted) ToastHelper.showError(context, context.l10n.plansAddOrgFailed);
    }
  }

  // ---------------------------------------------------------------------------
  // Share / export
  // ---------------------------------------------------------------------------

  bool _validate() {
    if (_time.isEmpty || _fields.isEmpty) {
      ToastHelper.showWarning(context, context.l10n.plansAddFieldMin);
      return false;
    }
    if (!_fields.every((f) => PlanUtils.isNote(f) || PlanUtils.isGroupHead(f) || f.time.trim().isNotEmpty)) {
      ToastHelper.showWarning(context, context.l10n.plansFillDurations);
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
      title: context.l10n.plansShareExport,
      pages: _pages,
      fileName: _fileName,
      extraActions: [
        PlanSheetAction('read', context.l10n.planningReadOnlyLink, icon: Icons.link),
        PlanSheetAction('edit', context.l10n.planningEditLink, icon: Icons.edit_note),
      ],
      onExtraAction: (a) => _doShare(a == 'edit'),
    );
  }

  Future<void> _doShare(bool editLink) async {
    String id;
    String editKey;
    if (_loggedIn) {
      // SOL_FIX15: share only a plan whose current state was saved.
      if (!await _persistToDb() || _planId == null) {
        if (mounted) ToastHelper.showError(context, context.l10n.plansLinkFailed);
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
        if (mounted) ToastHelper.showError(context, context.l10n.plansLinkFailed);
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
    final picked = await showAppDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      locale: Locale(currentLanguage()),
    );
    if (picked == null) return;
    setState(() => _date = picked);
    _changed();
  }

  Future<void> _pickTime() async {
    final m = PlanUtils.parseTimeToMinutes(_time) ?? 600;
    final picked = await showAppTimePicker(
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

    // Ionic: ion-header + `collapse="condense"` large title (iOS).
    return IonCondenseScaffold(
      automaticallyImplyLeading: widget.inApp,
      title: context.l10n.plansPlanning,
      // IOS_PAGES3: iOS → the end ion-buttons share one glass capsule
      actions: [
        ToolbarButtonGroup(children: [
          if (loggedIn)
            IconButton(tooltip: context.l10n.plansMyPlans, icon: const Icon(Icons.list), onPressed: _openMyPlans),
          IconButton(tooltip: context.l10n.plansShareExport, icon: const Icon(Icons.ios_share), onPressed: _shareCurrentPlan),
        ]),
      ],
      bodyBuilder: (context, largeTitle) => !_ready
          ? const Center(child: AppSpinner())
          : ListView(
              padding: centeredListPadding(context, bottom: 32),
              children: [
                if (largeTitle != null) largeTitle,
                // Ionic: ion-list [inset]="true" with full-width item lines.
                _InsetList(
                  margin: const EdgeInsets.all(AppDimensions.paddingM),
                  // lines="none" on the action items
                  dividerCount: 3,
                  children: [
                    // ion-input labelPlacement="stacked" (no box)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                      child: Focus(
                        onFocusChange: (f) {
                          if (!f) _changed();
                        },
                        child: TextField(
                          controller: _titleController,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: InputDecoration(
                            labelText: context.l10n.plansTitle,
                            hintText: context.l10n.plansRunSheet,
                            floatingLabelBehavior: FloatingLabelBehavior.always,
                            filled: false,
                            isDense: true,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: const EdgeInsets.only(top: 6, bottom: 4),
                          ),
                        ),
                      ),
                    ),
                    // ion-select interface="popover": label left, value right
                    IonSelect<String>(
                      key: ValueKey('tpl-$_templateId'),
                      label: context.l10n.plansTemplate,
                      value: _templateId,
                      items: [
                        for (final t in publicPlanningTemplates)
                          DropdownMenuItem(value: t.id, child: Text(t.name)),
                        if (loggedIn && orgTemplates.isNotEmpty) ...[
                          DropdownMenuItem(value: '', enabled: false, child: Text(context.l10n.plansOrgTemplates)),
                          for (var i = 0; i < orgTemplates.length; i++)
                            DropdownMenuItem(
                                value: 'org:$i', child: Text(context.l10n.plansOrgSuffix(orgTemplates[i].title ?? ''))),
                        ],
                      ],
                      onChanged: _onTemplateChange,
                    ),
                    IonSelect<String>(
                      key: ValueKey('brand-$_brandingId'),
                      label: context.l10n.plansBranding,
                      value: _brandingId,
                      items: [
                        for (final b in publicBrandings)
                          DropdownMenuItem(
                              value: b.id, child: Text(b.id == 'none' ? context.l10n.coreFlutterNoBranding : b.name)),
                      ],
                      onChanged: (v) {
                        setState(() => _brandingId = v ?? 'none');
                        _changed();
                      },
                    ),
                    ListTile(
                      title: Text(context.l10n.plansDate),
                      trailing: IonDatetimeChip(
                        text: DateFormat(dateFmt()).format(_date),
                        onTap: _pickDate,
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.refresh, color: AppColors.primary),
                      title: Text(context.l10n.plansRestoreTemplate, style: const TextStyle(color: AppColors.primary)),
                      onTap: _resetToTemplate,
                    ),
                    if (org != null)
                      ListTile(
                        leading: Icon(_isOrgPlan ? Icons.check_circle : Icons.business_outlined,
                            color: _isOrgPlan ? AppColors.success : AppColors.primary),
                        title: Text(
                          _isOrgPlan ? context.l10n.plansFlutterInOrg(org.name) : context.l10n.plansFlutterAddToOrg,
                          style: TextStyle(color: _isOrgPlan ? AppColors.success : AppColors.primary),
                        ),
                        onTap: _toggleOrg,
                      ),
                    if (loggedIn)
                      ListTile(
                        leading: const Icon(Icons.add_circle_outline, color: AppColors.medium),
                        title: Text(context.l10n.plansNewPlan, style: const TextStyle(color: AppColors.medium)),
                        onTap: _newPlan,
                      ),
                  ],
                ),
                // ion-list-header: bold title with the "+" popover trigger
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppDimensions.paddingM, 8, AppDimensions.paddingM, 0),
                  child: IonListHeader(
                    title: context.l10n.planningRunSheet,
                    trailing: Builder(
                      builder: (anchor) => IconButton(
                        key: const ValueKey('plan-add-trigger'),
                        color: AppColors.primary,
                        tooltip: context.l10n.planningAddField,
                        icon: const Icon(Icons.add),
                        onPressed: () => _showAddMenu(anchor),
                      ),
                    ),
                  ),
                ),
                _InsetList(
                  margin: const EdgeInsets.fromLTRB(AppDimensions.paddingM, 4, AppDimensions.paddingM, 0),
                  dividerCount: 1,
                  children: [
                    ListTile(
                      title: Text(context.l10n.attendanceStartLabel),
                      trailing: IonDatetimeChip(text: _time, onTap: _pickTime),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
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
                            title: Text(context.l10n.attendanceEnd),
                            // Ionic: disabled ion-datetime-button (same chip, read-only)
                            trailing: IonDatetimeChip(text: _end),
                          ),
                      ],
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.all(AppDimensions.paddingM),
                  child: FilledButton.icon(
                    onPressed: _showExportOptions,
                    icon: const Icon(Icons.ios_share),
                    label: IonButtonLabel(context.l10n.planningExport),
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
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(context.l10n.plansMyPlans),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: IonButtonLabel(context.l10n.commonClose)),
        ],
      ),
      body: plansAsync.when(
        loading: () => const Center(child: AppSpinner()),
        error: (e, _) => Center(child: Text(context.l10n.planningFlutterErrorWith(friendlyErrorMessage(e)))),
        // Ionic: inset list, ion-item-sliding with a danger option; empty
        // text as a centered grey item.
        data: (plans) => ListView(
          padding: const EdgeInsets.only(bottom: 16),
          children: [
            SlidableAutoCloseBehavior(
              child: IonInsetList(
                children: plans.isEmpty
                    ? [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(context.l10n.plansNoPlans,
                              textAlign: TextAlign.center, style: const TextStyle(color: AppColors.medium)),
                        ),
                      ]
                    : [for (final p in plans) _MyPlanTile(plan: p)],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MyPlanTile extends ConsumerWidget {
  const _MyPlanTile({required this.plan});

  final SharedPlan plan;

  /// Ionic `deletePlan`: alert, then delete.
  Future<void> _delete(BuildContext context, WidgetRef ref, String title) async {
    final planRepo = ref.read(planRepositoryWithTenantProvider);
    final ok = await showPlanConfirm(
      context,
      title: context.l10n.planningDeletePlan,
      message: context.l10n.plansDeletePlanForever(title),
      confirmText: context.l10n.commonDelete,
      destructive: true,
    );
    if (!ok) return;
    try {
      await planRepo.deleteMySharedPlan(plan.id);
      ref.invalidate(mySharedPlansProvider);
    } catch (_) {
      if (context.mounted) ToastHelper.showError(context, context.l10n.plansDeleteFailed);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = DateTime.tryParse(plan.date ?? '');
    final date = d == null
        ? ''
        : DateFormat(dateFmt()).format(d);
    final count = plan.fields.length;
    final title = (plan.planTitle?.isNotEmpty ?? false) ? plan.planTitle! : context.l10n.plansRunSheet;
    return Slidable(
      key: ValueKey(plan.id),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.22,
        children: [
          SlidableAction(
            onPressed: (_) => _delete(context, ref, title),
            backgroundColor: AppColors.danger,
            foregroundColor: Colors.white,
            icon: Icons.delete_outline,
          ),
        ],
      ),
      child: ListTile(
        title: Text(title),
        subtitle: Text('$date${count > 0 ? ' · ${context.l10n.plansFlutterFieldsCount(count)}' : ''}'),
        trailing: const IonDetailIcon(),
        onTap: () => Navigator.pop(context, plan),
      ),
    );
  }
}


/// Ionic `ion-list [inset]="true"`: rounded white card; the first
/// [dividerCount] children are separated by full-width item lines.
class _InsetList extends StatelessWidget {
  const _InsetList({required this.children, required this.margin, this.dividerCount = 0});

  final List<Widget> children;
  final EdgeInsets margin;
  final int dividerCount;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: margin,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i < dividerCount && i < children.length - 1) const Divider(height: 1, indent: 16),
          ],
        ],
      ),
    );
  }
}
