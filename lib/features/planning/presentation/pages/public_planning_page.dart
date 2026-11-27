import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:attendix/core/theme/app_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show GoTrueClient;

import '../../../../core/config/supabase_config.dart';
import '../../../../core/providers/organisation_providers.dart';
import '../../../../core/providers/plan_providers.dart';
import '../../../../core/providers/song_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/services/plan_export_service.dart';
import '../../../../core/services/public_plan_draft_storage.dart';
import '../../../../core/utils/plan_utils.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/plan/plan.dart';
import '../../../../data/models/song/song.dart';
import '../../../../data/repositories/plan_repository.dart';
import '../../../../data/repositories/public_plan_repository.dart';
import '../../data/public_planning_templates.dart';
import '../../data/shared_plan_save_chain.dart';
import '../../../../core/services/pdf_branding.dart';
import '../public_brandings.dart';
import '../widgets/plan_export_actions.dart';
import '../widgets/plan_field_dialogs.dart';
import '../widgets/plan_fields_editor.dart';
import '../widgets/plan_song_helper.dart';
import 'planning_page.dart' show planSongsProvider;
import '../../../../l10n/l10n.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../core/services/error_reporter.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';

import '../../../../core/theme/redesign/rd_theme.dart';
import '../../../../data/models/organisation/organisation.dart' show Organisation;
import '../../../../shared/widgets/redesign/rd_widgets.dart';
import '../widgets/rd_plan_widgets.dart';

export '../../data/public_planning_templates.dart';

part 'public_planning_page_view.dart';
part 'public_planning_page_actions.dart';

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

  /// `setState` bridge for extension part files.
  void _update(VoidCallback fn) => setState(fn);

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
          // Ionic 4.17.15: the org assignment is part of the local backup.
          _isOrgPlan = s['isOrgPlan'] == true;
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
    if (restored) unawaited(_syncOrgStateFromDb());
  }

  /// Ionic 4.17.15 `syncOrgStateFromDb`: the DB row (`shared_plans.org_id`)
  /// is the source of truth for the org assignment, not the local backup.
  Future<void> _syncOrgStateFromDb() async {
    final planId = _planId;
    if (planId == null || !_loggedIn) return;
    try {
      final row = await ref.read(planRepositoryWithTenantProvider).getMySharedPlanOrg(planId);
      if (row == null || !mounted || _planId != planId) return;
      final isOrgPlan = row.orgId != null;
      if (isOrgPlan != _isOrgPlan) setState(() => _isOrgPlan = isOrgPlan);
      unawaited(_persistLocal());
    } catch (_) {
      // Offline / not reachable: keep the local state.
    }
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
          'isOrgPlan': _isOrgPlan,
        }),
      );
    } catch (e, st) {
      ErrorReporter.report(e, st, where: 'public_planning_page');
    }
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
    if (!mounted) return; // TERMINE-22: no ref after the page is gone
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

  @override
  Widget build(BuildContext context) {
    final loggedIn = _loggedIn;
    final org = loggedIn ? ref.watch(currentOrganisationProvider).valueOrNull : null;
    if (loggedIn) {
      ref.watch(planSongsProvider);
      ref.watch(songCollectionsProvider);
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
    return _rdBuild(context, loggedIn: loggedIn, org: org);
  }
}
