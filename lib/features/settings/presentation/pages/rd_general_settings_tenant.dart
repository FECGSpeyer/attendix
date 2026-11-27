part of 'rd_general_settings_page.dart';

/// Sheet editors and validation helpers for tenant-wide settings sections
/// (name, season, visibility, reasons, registration, sharing, holidays).
extension _RdTenantSettingsEditors on _RdTenantSettingsBlockState {
  Future<void> _editName(Tenant t, {required bool short}) async {
    final l10n = context.l10n;
    final value = await showRdTextSheet(
      context,
      title: short ? l10n.rdSettingsShortName : l10n.rdSettingsName,
      initial: short ? t.shortName : t.longName,
      helper: short ? l10n.generalSettingsShortNameHelper : null,
      required: true,
      capitalization: TextCapitalization.words,
    );
    if (value == null || !mounted) return;
    await _save(t.id, {
      short ? 'shortName' : 'longName': value,
    }, (c) => short ? c.copyWith(shortName: value) : c.copyWith(longName: value));
  }

  DateTime _seasonOf(Tenant t) =>
      (t.seasonStart != null ? DateTime.tryParse(t.seasonStart!)?.toLocal() : null) ?? DateTime(2023, 1, 1);

  String _isoDate(DateTime d) => d.toIso8601String().split('T')[0];

  Future<void> _editSeason(Tenant t) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final first = DateTime(1900);
    final before = t.seasonStart;
    var initial = _seasonOf(t);
    if (initial.isAfter(today)) initial = today;
    if (initial.isBefore(first)) initial = first;
    final picked = await showAppDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: today,
      locale: Locale(currentLanguage()),
    );
    if (picked == null || !mounted) return;
    final value = _isoDate(picked);
    final ok = await _save(t.id, {'seasonStart': value}, (c) => c.copyWith(seasonStart: value), evaluate: true);
    if (!ok) return;
    // The season start changes every percentage: offer to undo it.
    messenger?.showSnackBar(
      SnackBar(
        content: Text(l10n.rdSettingsSeasonSaved(DateFormat(dateFmt()).format(picked))),
        duration: const Duration(seconds: 6),
        action: SnackBarAction(
          label: l10n.rdSettingsUndo,
          onPressed: () {
            if (mounted) _save(t.id, {'seasonStart': before}, (c) => c.copyWith(seasonStart: before), evaluate: true);
          },
        ),
      ),
    );
  }

  Future<void> _toggleAllEvents(Tenant t, bool on) async {
    final info = normalizeShowAllInfoText(
      enabled: on,
      text: t.showAllAttendancesInfoText ?? '',
      defaultText: context.l10n.defaultsShowAllInfoText,
    );
    await _save(t.id, {
      'show_all_attendances': on,
      'show_all_attendances_info_text': info,
    }, (c) => c.copyWith(showAllAttendances: on, showAllAttendancesInfoText: info));
  }

  Future<void> _editInfoText(Tenant t) async {
    final l10n = context.l10n;
    final value = await showRdTextSheet(
      context,
      title: l10n.rdSettingsInfoText,
      initial: t.showAllAttendancesInfoText ?? '',
      hint: l10n.generalSettingsForeignInfoPh,
      maxLines: 3,
    );
    if (value == null || !mounted) return;
    final info = normalizeShowAllInfoText(enabled: true, text: value, defaultText: l10n.defaultsShowAllInfoText);
    await _save(t.id, {'show_all_attendances_info_text': info}, (c) => c.copyWith(showAllAttendancesInfoText: info));
  }

  Future<void> _editReasons(Tenant t, {required bool late}) async {
    final l10n = context.l10n;
    final list = await showRdReasonsSheet(
      context,
      title: late ? l10n.generalSettingsLateReasons : l10n.generalSettingsAbsenceReasons,
      reasons: late ? EventListUtils.lateReasonsOf(t.lateReasons) : EventListUtils.absenceReasonsOf(t.absenceReasons),
      defaults: late ? EventListUtils.defaultLateReasons : EventListUtils.defaultAbsenceReasons,
    );
    if (list == null || !mounted) return;
    final value = normalizeReasons(list);
    await _save(t.id, {
      late ? 'late_reasons' : 'absence_reasons': value,
    }, (c) => late ? c.copyWith(lateReasons: value) : c.copyWith(absenceReasons: value));
  }

  /// Loads data a change needs; on failure shows the error and drops the
  /// failed result, so tapping again loads it anew. Returns null then.
  Future<T?> _load<T>(FutureProvider<T> provider) async {
    final container = ProviderScope.containerOf(context, listen: false);
    try {
      return await container.read(provider.future);
    } catch (e) {
      container.invalidate(provider);
      if (mounted) ToastHelper.showError(context, context.l10n.settingsFlutterLoadFailed(friendlyErrorMessage(e)));
      return null;
    }
  }

  bool _hasSelectableGroups() => (ref.read(groupsProvider).valueOrNull ?? const []).any((g) => g.maingroup != true);

  Future<void> _toggleRegistration(Tenant t, bool on) async {
    if (on) {
      // Ionic: registration needs a group to choose (not the main group).
      final groups = await _load(groupsProvider);
      if (groups == null || !mounted) return;
      if (!groups.any((g) => g.maingroup != true)) {
        ToastHelper.showError(context, context.l10n.rdWordsNoGroupsYet(ref.read(rdGroupKindProvider)));
        return;
      }
      final id = (t.registerId ?? '').isNotEmpty ? t.registerId! : const Uuid().v4();
      final fields = initialRegistrationFields(t.registrationFields);
      await _save(t.id, {
        'register_id': id,
        'registration_fields': fields,
      }, (c) => c.copyWith(registerId: id, registrationFields: fields));
    } else {
      // The link dies with the switch: said before, since a new one has to
      // be handed out again.
      final confirmed = await showAppConfirm(
        context,
        title: context.l10n.rdSettingsRegisterOffTitle,
        message: context.l10n.rdSettingsRegisterOffMessage,
        confirmText: context.l10n.rdSettingsRegisterOffConfirm,
        destructive: true,
      );
      if (!confirmed || !mounted) return;
      // Ionic: off -> no link, no auto approval, no fields.
      await _save(t.id, {
        'register_id': null,
        'auto_approve_registrations': false,
        'registration_fields': <String>[],
      }, (c) => c.copyWith(registerId: null, autoApproveRegistrations: false, registrationFields: const []));
    }
  }

  Future<void> _editRegistrationFields(Tenant t) async {
    final l10n = context.l10n;
    final kind = ref.read(rdGroupKindProvider);
    final options = <RdMultiOption>[
      (key: 'firstName', label: l10n.peopleFirstName, locked: true),
      (key: 'lastName', label: l10n.peopleLastName, locked: true),
      (key: 'group', label: l10n.rdWordsGroup(kind), locked: true),
      (key: 'picture', label: l10n.settingsPassPhoto, locked: false),
      (key: 'birthDate', label: l10n.peopleBirthday, locked: false),
      (key: 'phone', label: l10n.settingsMobile, locked: false),
      for (final f in t.additionalFields ?? const <ExtraField>[]) (key: f.id, label: f.name, locked: false),
    ];
    final selected = await showRdMultiChoiceSheet(
      context,
      title: l10n.rdSettingsRegisterFields,
      options: options,
      selected: initialRegistrationFields(t.registrationFields),
      hint: l10n.rdSettingsRegisterFieldsHint(kind),
    );
    if (selected == null || !mounted) return;
    await _save(t.id, {'registration_fields': selected}, (c) => c.copyWith(registrationFields: selected));
  }

  String _registrationFieldsLabel(Tenant t) {
    final l10n = context.l10n;
    final labels = {
      'firstName': l10n.peopleFirstName,
      'lastName': l10n.peopleLastName,
      'group': l10n.rdWordsGroup(ref.read(rdGroupKindProvider)),
      'picture': l10n.settingsPassPhoto,
      'birthDate': l10n.peopleBirthday,
      'phone': l10n.settingsMobile,
      for (final f in t.additionalFields ?? const <ExtraField>[]) f.id: f.name,
    };
    return initialRegistrationFields(t.registrationFields).map((k) => labels[k]).whereType<String>().join(', ');
  }

  Future<void> _toggleSharing(Tenant t, bool on) async {
    final id = on ? ((t.songSharingId ?? '').isNotEmpty ? t.songSharingId! : const Uuid().v4()) : null;
    await _save(t.id, {'song_sharing_id': id}, (c) => c.copyWith(songSharingId: id));
  }

  Future<void> _copyLink(String link) async {
    try {
      await Clipboard.setData(ClipboardData(text: link));
    } catch (_) {
      if (mounted) ToastHelper.showError(context, context.l10n.settingsFlutterCopyLinkFailed);
      return;
    }
    if (mounted) ToastHelper.showSuccess(context, context.l10n.settingsLinkCopied);
  }

  Future<void> _pickRegion(Tenant t) async {
    final l10n = context.l10n;
    final region = await showRdChoiceSheet<String>(
      context,
      title: l10n.rdSettingsRegion,
      selected: t.region ?? '',
      options: [for (final r in holidayRegions) (r.$1, r.$1.isEmpty ? l10n.rdTextNoRegion : r.$2)],
    );
    if (region == null || !mounted) return;
    final value = region.isEmpty ? null : region;
    await _save(t.id, {'region': value}, (c) => c.copyWith(region: value));
  }

  String _regionLabel(Tenant t) {
    final region = t.region ?? '';
    if (region.isEmpty) return context.l10n.rdTextNoRegion;
    return holidayRegions.where((r) => r.$1 == region).map((r) => r.$2).firstOrNull ?? region;
  }
}
