import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/church_providers.dart';
import '../../../../core/providers/cross_tenant_person_providers.dart';
import '../../../../core/providers/group_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/router/redesign_routes.dart';
import '../../../../core/theme/redesign/rd_theme.dart';
import '../../../../core/utils/dialog_helper.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../core/utils/person_matcher.dart' show RankedMatch;
import '../../../../core/utils/tenant_label_utils.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/church/church.dart';
import '../../../../data/models/person/person.dart';
import '../../../../data/repositories/cross_tenant_person_repository.dart';
import '../../../../data/repositories/extra_fields_repository.dart' show extraFieldDefaultValue;
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';
import '../../../../shared/widgets/layout/route_leave_guard.dart';
import '../../../people/person_write.dart';
import '../../../people/presentation/widgets/person_detail/allgemein_accordion.dart' show personExtraFields;
import '../../../people/presentation/widgets/person_image_picker.dart';
import '../../../people/presentation/widgets/person_match_suggestions.dart' show showEmailTakenDialog;
import '../widgets/manage/rd_manage_entries.dart' show rdManageAccessProvider;
import '../widgets/event/rd_form_widgets.dart';
import '../widgets/members/rd_person_form.dart';
import '../widgets/rd_widgets.dart';
import '../widgets/today/rd_today_common.dart' show RdInfoCard;

/// REDESIGN: "Neue Person" (canvas "Einheitliche Beta-UX", board A):
/// Passbild and name in one card, the group as chips, contact (e-mail gives
/// access to the app), everything rare under "Weitere Angaben". Saving runs
/// the same code as the person page of the normal app
/// ([createPersonWithChecks]).
class RdPersonCreatePage extends ConsumerStatefulWidget {
  const RdPersonCreatePage({super.key});

  @override
  ConsumerState<RdPersonCreatePage> createState() => _RdPersonCreatePageState();
}

class _RdPersonCreatePageState extends ConsumerState<RdPersonCreatePage> {
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _emailFocus = FocusNode();

  /// Ionic newPlayer: birthday, playsSince and joined = today, the birthday
  /// counts as unconfirmed until it is edited.
  late Person _draft = () {
    final today = personUtcMidnightIso(DateTime.now());
    return Person(birthday: today, playsSince: today, joined: today, correctBirthday: false);
  }();
  bool _groupPicked = false;
  final Map<String, dynamic> _additional = {};
  final Set<String> _defaulted = {};
  Uint8List? _pickedImage;
  String? _adoptedImg;
  bool _showMore = false;
  bool _saving = false;
  bool _submitted = false;
  bool _touched = false;

  // Cross-tenant matching (Ionic person.page onNameInput / onEmailBlur).
  Timer? _nameDebounce;
  int _nameLookupSeq = 0;
  String? _dismissedFor;
  String _lastEmailLookup = '';
  List<RankedMatch<CrossTenantPersonCandidate>> _suggestions = const [];

  late final RouteLeaveGuardRegistry _leaveGuards;

  @override
  void initState() {
    super.initState();
    _leaveGuards = ref.read(routeLeaveGuardRegistryProvider);
    _leaveGuards.add(_onLeave);
    _first.addListener(_onNameInput);
    _last.addListener(_onNameInput);
    _emailFocus.addListener(() {
      if (!_emailFocus.hasFocus) _onEmailBlur();
    });
  }

  @override
  void dispose() {
    _leaveGuards.remove(_onLeave);
    _nameDebounce?.cancel();
    for (final c in [_first, _last, _email, _phone]) {
      c.dispose();
    }
    _emailFocus.dispose();
    super.dispose();
  }

  bool get _canEdit {
    final role = ref.watch(currentRoleProvider);
    return role.isAdmin || role.isResponsible;
  }

  bool get _hasInput =>
      _touched || _pickedImage != null || [_first, _last, _email, _phone].any((c) => c.text.trim().isNotEmpty);

  Future<bool> _onLeave() async {
    if (_saving) return false;
    if (!await _confirmDiscard()) return false;
    _touched = false;
    return true;
  }

  /// Ionic dismiss(): with input ask "Änderungen verwerfen?" first.
  Future<bool> _confirmDiscard() async {
    if (!_hasInput) return true;
    return showAppConfirm(
      context,
      title: context.l10n.personDiscardChanges,
      message: context.l10n.redesignCreateDiscardBody,
      confirmText: context.l10n.redesignCreateDiscard,
      cancelText: context.l10n.redesignCreateKeepEditing,
      destructive: true,
    );
  }

  Future<void> _cancel() async {
    if (!await _confirmDiscard() || !mounted) return;
    _touched = false;
    _close();
  }

  void _close() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(RedesignRoutes.members);
    }
  }

  void _change(Map<String, dynamic> columns, {bool typing = false}) => setState(() {
        _touched = true;
        _draft = applyPersonColumns(_draft, columns);
      });

  void _changeExtra(String id, dynamic value, {bool typing = false}) => setState(() {
        _touched = true;
        _additional[id] = value;
      });

  String get _nameKey => '${_first.text.trim()}|${_last.text.trim()}';

  void _onNameInput() {
    _nameDebounce?.cancel();
    _nameDebounce = Timer(const Duration(milliseconds: 250), _lookupByName);
  }

  Future<void> _lookupByName() async {
    if (!mounted) return;
    final repo = ref.read(crossTenantPersonRepositoryWithTenantProvider);
    final first = _first.text.trim();
    final last = _last.text.trim();
    if (first.length < 2 && last.length < 2) {
      if (_suggestions.isNotEmpty) setState(() => _suggestions = const []);
      return;
    }
    if (_dismissedFor == _nameKey) return;
    _dismissedFor = null;
    final seq = ++_nameLookupSeq;
    try {
      final linkedIds = await ref.read(linkedTenantIdsProvider.future);
      if (linkedIds.isEmpty) return;
      final matches = await repo.getPossiblePersonsByName(first, last, linkedTenantIds: linkedIds);
      if (!mounted || seq != _nameLookupSeq) return;
      setState(() => _suggestions = matches);
    } catch (_) {
      if (mounted) ToastHelper.showError(context, context.l10n.dbLoadPeopleFailed);
    }
  }

  Future<void> _onEmailBlur() async {
    if (!mounted) return;
    final repo = ref.read(crossTenantPersonRepositoryWithTenantProvider);
    final email = _email.text.trim();
    if (email.isEmpty || !isValidPersonEmail(email) || email == _lastEmailLookup) return;
    _lastEmailLookup = email;
    List<CrossTenantPersonCandidate> matches;
    try {
      final linkedIds = await ref.read(linkedTenantIdsProvider.future);
      matches = await repo.getPossiblePersonsByEmail(email, linkedTenantIds: linkedIds);
    } catch (_) {
      if (mounted) ToastHelper.showError(context, context.l10n.dbLoadPeopleFailed);
      return;
    }
    if (matches.isEmpty || !mounted) return;
    final chosen = await showEmailTakenDialog(
      context,
      matches,
      usedBy: context.l10n.redesignPersonFormEmailUsedBy,
      usedMany: context.l10n.redesignPersonFormEmailUsedMany,
    );
    if (chosen != null && mounted) _applyMatch(chosen);
  }

  /// Ionic applyMatchedPerson: take over the data of the person found in
  /// another instance of the organisation.
  void _applyMatch(CrossTenantPersonCandidate match) {
    final m = match.person;
    final groups = ref.read(groupsProvider).valueOrNull ?? const [];
    final group = groups.where((g) => g.name == match.groupName).firstOrNull;
    _nameDebounce?.cancel();
    setState(() {
      _first.text = m.firstName;
      _last.text = m.lastName;
      _email.text = m.email ?? '';
      _lastEmailLookup = _email.text.trim();
      _draft = _draft.copyWith(
        birthday: m.correctBirthday && m.birthday != null ? m.birthday : _draft.birthday,
        otherExercise: m.otherExercise,
        range: m.range,
        instrument: group?.id ?? _draft.instrument,
      );
      if (group != null) _groupPicked = true;
      _adoptedImg = m.img;
      _suggestions = const [];
      _dismissedFor = _nameKey;
    });
    _nameDebounce?.cancel();
    ToastHelper.showSuccess(context, context.l10n.personDataTaken);
  }

  bool _isMainGroup(int? groupId) {
    final main = ref.read(mainGroupProvider).valueOrNull;
    return main?.id != null && main!.id == groupId;
  }

  Future<void> _onAvatarTap() async {
    final hasImage = _pickedImage != null || (_adoptedImg?.isNotEmpty ?? false);
    if (hasImage) {
      final action = await showAppActionSheet<String>(
        context,
        actions: [
          AppActionSheetAction(value: 'replace', icon: Icons.photo_camera_outlined, label: context.l10n.personReplace),
          AppActionSheetAction(value: 'remove', icon: Icons.delete_outline, label: context.l10n.commonRemove, destructive: true),
        ],
      );
      if (!mounted) return;
      if (action == 'remove') {
        // Ionic removeImgFromViewer (new person): confirm, reset locally.
        final confirmed = await DialogHelper.showConfirmation(
          context,
          title: context.l10n.personRemovePhoto,
          message: context.l10n.personRemovePhotoMessage,
          confirmText: context.l10n.commonRemove,
          cancelText: context.l10n.commonCancel,
          isDestructive: true,
        );
        if (!confirmed || !mounted) return;
        setState(() {
          _pickedImage = null;
          _adoptedImg = null;
        });
        ToastHelper.showSuccess(context, context.l10n.personPhotoRemoved);
        return;
      }
      if (action != 'replace') return;
    }
    try {
      final image = await pickPersonImage(context, ref);
      if (image == null) return;
      final bytes = await image.readAsBytes();
      if (!mounted) return;
      if (bytes.length > kPersonImageMaxBytes) {
        ToastHelper.showError(context, context.l10n.personPhotoTooLarge);
        return;
      }
      setState(() {
        _pickedImage = bytes;
        _adoptedImg = null;
      });
    } catch (_) {
      if (mounted) ToastHelper.showError(context, context.l10n.personPhotoLoadFailed);
    }
  }

  Future<void> _save() async {
    final role = ref.read(currentRoleProvider);
    if (!(role.isAdmin || role.isResponsible) || _saving) return;
    setState(() => _submitted = true);
    final first = _first.text.trim();
    final last = _last.text.trim();
    if (first.isEmpty || last.isEmpty) return;
    String? text(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();
    final groupId = _draft.instrument;
    final person = _draft.copyWith(
      firstName: first,
      lastName: last,
      email: text(_email),
      phone: text(_phone),
      img: _adoptedImg,
      additionalFields: _additional.isNotEmpty ? Map.of(_additional) : null,
      teacher: _draft.hasTeacher ? _draft.teacher : null,
    );
    setState(() => _saving = true);
    try {
      final created = await createPersonWithChecks(
        context,
        ref,
        person,
        isMainGroup: _isMainGroup(groupId),
        imageBytes: _pickedImage,
      );
      if (!created || !mounted) return;
      _touched = false;
      _first.clear();
      _last.clear();
      _email.clear();
      _phone.clear();
      _pickedImage = null;
      ToastHelper.showSuccess(context, context.l10n.personAdded);
      _close();
    } catch (e) {
      if (mounted) ToastHelper.showError(context, context.l10n.personAddFailed(friendlyErrorMessage(e)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _fillDefaults() {
    // Ionic: a new person starts in the first group.
    if (!_groupPicked && _draft.instrument == null) {
      final first = ref.watch(groupsProvider).valueOrNull?.firstOrNull?.id;
      if (first != null) _draft = _draft.copyWith(instrument: first);
    }
    // Ionic getFieldTypeDefaultValue per Zusatzfeld (Gemeinde = first church).
    final fields = personExtraFields(ref, ref.watch(currentTenantProvider));
    final hasChurch = fields.any((f) => f.type == 'bfecg_church');
    final churches = hasChurch ? ref.watch(churchesProvider) : null;
    if (churches != null && churches.isLoading) return;
    final churchIds = <Object>[
      for (final c in churches?.valueOrNull ?? const <Church>[])
        if (c.id != null) c.id!,
    ];
    for (final f in fields) {
      if (!_defaulted.add(f.id)) continue;
      _additional[f.id] ??= extraFieldDefaultValue(f.type, defaultValue: f.defaultValue, options: f.options, churchIds: churchIds);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final canEdit = _canEdit;
    _fillDefaults();

    return PopScope(
      canPop: !_saving && !_hasInput,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _cancel();
      },
      child: Scaffold(
        backgroundColor: p.bg,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              RdFormTopBar(
                title: l10n.redesignPersonFormNewTitle,
                cancel: l10n.redesignCommonCancel,
                submit: l10n.redesignPersonFormCreate,
                saving: _saving,
                onCancel: _saving ? null : _cancel,
                onSubmit: canEdit ? _save : null,
                submitKey: const Key('rd-person-create'),
              ),
              Expanded(
                child: canEdit
                    ? _form(context)
                    : RdFormBody(children: [RdInfoCard(text: l10n.redesignPersonFormNotAllowed, icon: Icons.lock_outline)]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _form(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final tenant = ref.watch(currentTenantProvider);
    final textStyle = TextStyle(fontSize: 17, color: p.text);
    final firstMissing = _submitted && _first.text.trim().isEmpty;
    final lastMissing = _submitted && _last.text.trim().isEmpty;

    Widget hint(String text, {Color? color}) => Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
          child: Text(text, style: RdType.meta(p, size: 13).copyWith(color: color)),
        );

    return RdFormBody(
      children: [
        RdCard(
          padding: EdgeInsets.zero,
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.all(14),
                child: RdPersonAvatar(
                  name: '${_first.text} ${_last.text}',
                  imageBytes: _pickedImage,
                  imageUrl: _adoptedImg,
                  onTap: _onAvatarTap,
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    RdFieldRow(
                      label: '${l10n.peopleFirstName} *',
                      child: TextField(
                        key: const Key('rd-person-first'),
                        controller: _first,
                        autofocus: true,
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.next,
                        style: textStyle,
                        decoration: rdInputDecoration(p, 'Max'),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    Divider(height: 1, thickness: 1, color: p.line),
                    RdFieldRow(
                      label: '${l10n.peopleLastName} *',
                      child: TextField(
                        key: const Key('rd-person-last'),
                        controller: _last,
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.next,
                        style: textStyle,
                        decoration: rdInputDecoration(p, 'Mustermann'),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (firstMissing) hint(l10n.peopleFlutterFirstNameRequired, color: p.absent),
        if (lastMissing) hint(l10n.peopleFlutterLastNameRequired, color: p.absent),
        if (_suggestions.isNotEmpty) ...[
          const SizedBox(height: 12),
          RdPersonMatchList(
            matches: _suggestions,
            onSelected: _applyMatch,
            onDismiss: () => setState(() {
              _dismissedFor = _nameKey;
              _suggestions = const [];
            }),
          ),
        ],
        const SizedBox(height: 20),
        RdGroupLabel(groupLabel(tenant?.type)),
        RdPersonGroupChips(
          onManage: ref.watch(rdManageAccessProvider).isAdmin ? () => context.push(RedesignRoutes.groups) : null,
          selected: _draft.instrument,
          onSelected: (id) => setState(() {
            _touched = true;
            _groupPicked = true;
            _draft = _draft.copyWith(instrument: id);
          }),
        ),
        const SizedBox(height: 20),
        RdGroupLabel(l10n.redesignPersonFormContact),
        RdGroupedList(
          children: [
            RdFieldRow(
              label: l10n.peopleFlutterOptional(l10n.peopleEmail),
              child: TextField(
                key: const Key('rd-person-email'),
                controller: _email,
                focusNode: _emailFocus,
                autocorrect: false,
                keyboardType: TextInputType.emailAddress,
                style: textStyle,
                decoration: rdInputDecoration(p, 'max@example.com'),
                onChanged: (_) => setState(() {}),
              ),
            ),
            RdFieldRow(
              label: l10n.peopleFlutterOptional(l10n.peoplePhone),
              child: TextField(
                key: const Key('rd-person-phone'),
                controller: _phone,
                keyboardType: TextInputType.phone,
                style: textStyle,
                decoration: rdInputDecoration(p, '+49 123 456789'),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ],
        ),
        hint(l10n.redesignPersonFormEmailHint),
        hint('${l10n.personAccountHelp}\n${l10n.redesignPersonFormExistingUserHint}'),
        const SizedBox(height: 20),
        RdGroupedList(
          children: [
            RdListRow(
              key: const Key('rd-person-more'),
              title: l10n.redesignPersonFormMore,
              subtitle: l10n.redesignPersonFormMoreHint,
              showChevron: false,
              trailing: Icon(_showMore ? Icons.expand_less : Icons.expand_more, color: p.text2),
              onTap: () => setState(() => _showMore = !_showMore),
            ),
          ],
        ),
        if (_showMore) ...[
          const SizedBox(height: 12),
          RdPersonMoreFields(
            person: _draft,
            isMainGroup: _isMainGroup(_draft.instrument),
            additionalValues: _additional,
            birthdayHighlight: !_draft.correctBirthday,
            onColumns: _change,
            onExtra: _changeExtra,
          ),
        ],
        const SizedBox(height: 24),
      ],
    );
  }
}
