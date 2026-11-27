part of 'tenant_registration_page.dart';

extension _TenantRegistrationForm on _TenantRegistrationPageState {
  /// Ionic `common.groupLabel.*` for the group select of tenant-register.
  String _groupLabel(Tenant tenant) {
    if (tenant.type == 'choir' && tenant.id != 194) {
      return context.l10n.commonGroupLabelVoice;
    }
    if (tenant.type == 'orchestra') return context.l10n.commonGroupLabelInstrument;
    return context.l10n.commonGroupLabelGroup;
  }

  Widget _buildForm(Tenant tenant) {
    // Check if logged-in user is already registered in this tenant
    if (!_hasCheckedRegistration && _isLoggedIn) {
      _hasCheckedRegistration = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _checkExistingRegistration(tenant);
      });
    }

    if (_forChildren == null) return _buildChoice(tenant);

    final groupsAsync = ref.watch(registrationGroupsProvider(tenant.id!));
    final registrationFields = tenant.registrationFields ?? [];
    final additionalFields = tenant.additionalFields ?? [];
    if (!_defaultsApplied) {
      _defaultsApplied = true;
      _formData.additionalFields.addAll(
          registrationFieldDefaults(registrationFields, additionalFields));
    }
    final inputStyle = ionItemInputStyle(context);
    final dateFormat = DateFormat(dateFmt());

    Widget header(String text) => RdGroupLabel(text);

    // Registration groups sit inside the card over the login photo.
    final children = <Widget>[
          _buildChosenRow(),

          // Account
          header(context.l10n.tenantRegisterAccount),
          _buildAccountGroup(),

          // Persönliche Daten (for "Mein Kind": the parent's own)
          header(_forChildren == true
              ? context.l10n.parentRegisterParentData
              : context.l10n.tenantRegisterPersonalData),
          IonInsetGroup(
            margin: _betaGroupMargin,
            color: _betaGroupColor,
            children: [
              if (registrationFields.contains('picture') && _forChildren != true)
                IonItem(
                  onTap: _changeImage,
                  start: CircleAvatar(
                    radius: 20,
                    backgroundColor: AppColors.light,
                    backgroundImage: _profileImageBytes != null
                        ? MemoryImage(_profileImageBytes!)
                        : null,
                    child: _profileImageBytes == null
                        ? Icon(AppIcons.person, color: AppColors.mediumOf(context))
                        : null,
                  ),
                  label: _profileImageBytes != null
                      ? context.l10n.tenantRegisterReplacePicture
                      : context.l10n.tenantRegisterChoosePicture,
                  labelColor: AppColors.primary,
                ),
              IonInputItem(
                child: TextFormField(
                  controller: _firstNameController,
                  style: inputStyle,
                  textCapitalization: TextCapitalization.words,
                  autofillHints: const [AutofillHints.givenName],
                  decoration: ionItemInputDecoration(
                      context, context.l10n.tenantRegisterFirstName),
                  onSaved: (value) => _formData.firstName = value?.trim() ?? '',
                ),
              ),
              IonInputItem(
                child: TextFormField(
                  controller: _lastNameController,
                  style: inputStyle,
                  textCapitalization: TextCapitalization.words,
                  autofillHints: const [AutofillHints.familyName],
                  decoration: ionItemInputDecoration(
                      context, context.l10n.tenantRegisterLastName),
                  onSaved: (value) => _formData.lastName = value?.trim() ?? '',
                ),
              ),
              if (registrationFields.contains('birthDate') && _forChildren != true)
                IonItem(
                  label: context.l10n.tenantRegisterBirthDate,
                  end: IonDateButton(
                    onTap: _pickBirthday,
                    text: _formData.birthDate != null
                        ? dateFormat.format(_formData.birthDate!)
                        : context.l10n.tenantRegisterPleaseChoose,
                  ),
                ),
              if (registrationFields.contains('phone'))
                IonInputItem(
                  child: TextFormField(
                    controller: _phoneController,
                    style: inputStyle,
                    keyboardType: TextInputType.phone,
                    autofillHints: const [AutofillHints.telephoneNumber],
                    decoration: ionItemInputDecoration(
                        context, context.l10n.tenantRegisterPhone),
                    onSaved: (value) => _formData.phone = value,
                  ),
                ),
            ],
          ),

          if (_forChildren == true)
            ..._buildChildren(tenant, groupsAsync, header),

          // Weitere Informationen
          header(context.l10n.tenantRegisterMoreInfo),
          IonInsetGroup(
            margin: _betaGroupMargin,
            color: _betaGroupColor,
            children: [
              if (_forChildren != true) groupsAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: AppSpinner()),
                ),
                error: (_, __) => IonItem(
                  label: context.l10n.tenantRegisterFlutterLoadGroupsFailed,
                  labelColor: AppColors.danger,
                ),
                data: (groups) {
                  _noGroupsAvailable = groups.isEmpty;
                  if (groups.isEmpty) {
                    // ion-item color="warning" with warning icon
                    return ColoredBox(
                      color: AppColors.warning,
                      child: IonItem(
                        start: Icon(AppIcons.warningAmberOutlined,
                            color: Colors.black),
                        title: Text(
                          context.l10n.tenantRegisterNoGroups,
                          style: const TextStyle(
                              fontSize: 14, color: Colors.black),
                        ),
                      ),
                    );
                  }
                  // Ionic: first group preselected.
                  _formData.groupId ??= groups.first['id'] as int;
                  final selected = groups
                      .where((g) => g['id'] == _formData.groupId)
                      .firstOrNull;
                  final label = _groupLabel(tenant);
                  return IonItem(
                    label: label,
                    onTap: () async {
                      final value = await showIonSelectOptions<int>(
                        context,
                        title: label,
                        options: [
                          for (final g in groups)
                            (g['id'] as int, g['name'] as String),
                        ],
                        selected: _formData.groupId,
                      );
                      if (value != null && mounted) {
                        _update(() => _formData.groupId = value);
                      }
                    },
                    end: IonSelectValue(
                      text: selected?['name'] as String? ?? '',
                    ),
                  );
                },
              ),
              ..._buildAdditionalFields(registrationFields, additionalFields),
              IonInputItem(
                child: TextFormField(
                  style: inputStyle,
                  minLines: 1,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: ionItemInputDecoration(
                      context, context.l10n.tenantRegisterNotes),
                  onSaved: (value) => _formData.notes = value,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: RdPrimaryButton(
              key: const ValueKey('tenant-register-finish'),
              icon: Icons.check_circle_outline,
              label: _finishLabel,
              loading: _isLoading,
              onPressed: _isLoading ||
                      _noGroupsAvailable ||
                      (!_isLoggedIn && _mode == AuthMode.otp)
                  ? null
                  : () => _submit(tenant),
            ),
          ),
    ];
    return Form(
      key: _formKey,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    );
  }

  String get _finishLabel => _forChildren == true
      ? context.l10n.parentRegisterFinish(_formData.children.length)
      : context.l10n.tenantRegisterFinish;

  /// "Wen möchtest du anmelden?": "Mich selbst" (the old form) or "Mein
  /// Kind" (an Elternteil registers children). Nothing is preselected, so
  /// parents never register themselves as members by mistake.
  Widget _buildChoice(Tenant tenant) {
    final l10n = context.l10n;
    Widget tile(Key key, IconData icon, String title, String hint, bool forChildren) => IonItem(
          key: key,
          start: Icon(icon, color: AppColors.primary),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(hint),
          detail: true,
          minHeight: 64,
          onTap: () => _choose(forChildren),
        );
    final children = <Widget>[
      RdGroupLabel(l10n.parentRegisterWhoTitle),
      IonInsetGroup(
        margin: _betaGroupMargin,
        color: _betaGroupColor,
        children: [
          tile(const ValueKey('tenant-register-self'), AppIcons.personOutline, l10n.parentRegisterSelf,
              l10n.parentRegisterSelfHint, false),
          tile(const ValueKey('tenant-register-child'), AppIcons.familyRestroom, l10n.parentRegisterChild,
              l10n.parentRegisterChildHint, true),
        ],
      ),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
  }

  /// "Anmeldung für: …" with "Ändern" back to the choice.
  Widget _buildChosenRow() {
    final l10n = context.l10n;
    return IonInsetGroup(
      margin: _betaGroupMargin,
      color: _betaGroupColor,
      children: [
        IonItem(
          key: const ValueKey('tenant-register-chosen'),
          label: _forChildren == true ? l10n.parentRegisterForChild : l10n.parentRegisterForSelf,
          end: TextButton(
            onPressed: _isLoading ? null : () => _update(() => _forChildren = null),
            child: Text(l10n.parentRegisterChange),
          ),
        ),
      ],
    );
  }

  /// "Mein Kind": one group per child (name, group, birth date when the
  /// group asks for it), "Weiteres Kind hinzufügen" below.
  List<Widget> _buildChildren(
    Tenant tenant,
    AsyncValue<List<Map<String, dynamic>>> groupsAsync,
    Widget Function(String) header,
  ) {
    final l10n = context.l10n;
    final inputStyle = ionItemInputStyle(context);
    final dateFormat = DateFormat(dateFmt());
    final hasBirthDate = (tenant.registrationFields ?? const []).contains('birthDate');
    final groups = groupsAsync.valueOrNull ?? const <Map<String, dynamic>>[];
    // Like the self registration: no groups → warning and no sending.
    if (groupsAsync.hasValue) _noGroupsAvailable = groups.isEmpty;
    final label = _groupLabel(tenant);
    final kids = _formData.children;
    return [
      for (var i = 0; i < kids.length; i++) ...[
        header(l10n.parentRegisterChildTitle(i + 1)),
        IonInsetGroup(
          key: ObjectKey(kids[i]),
          margin: _betaGroupMargin,
          color: _betaGroupColor,
          children: [
            IonInputItem(
              child: TextFormField(
                initialValue: kids[i].firstName,
                style: inputStyle,
                textCapitalization: TextCapitalization.words,
                decoration: ionItemInputDecoration(context, l10n.tenantRegisterFirstName),
                onChanged: (v) => kids[i].firstName = v.trim(),
              ),
            ),
            IonInputItem(
              child: TextFormField(
                initialValue: kids[i].lastName.isEmpty ? _lastNameController.text.trim() : kids[i].lastName,
                style: inputStyle,
                textCapitalization: TextCapitalization.words,
                decoration: ionItemInputDecoration(context, l10n.tenantRegisterLastName),
                onChanged: (v) => kids[i].lastName = v.trim(),
                onSaved: (v) => kids[i].lastName = v?.trim() ?? '',
              ),
            ),
            if (groupsAsync.isLoading && !groupsAsync.hasValue)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: AppSpinner()),
              )
            else if (groupsAsync.hasError && !groupsAsync.hasValue)
              IonItem(
                label: l10n.tenantRegisterFlutterLoadGroupsFailed,
                labelColor: AppColors.danger,
              )
            else if (groups.isEmpty)
              IonItem(
                start: Icon(AppIcons.warningAmberOutlined, color: AppColors.warning),
                label: l10n.tenantRegisterNoGroups,
              )
            else
              Builder(builder: (_) {
                kids[i].groupId ??= groups.first['id'] as int;
                final selected = groups.where((g) => g['id'] == kids[i].groupId).firstOrNull;
                return IonItem(
                  label: label,
                  onTap: () async {
                    final value = await showIonSelectOptions<int>(
                      context,
                      title: label,
                      options: [for (final g in groups) (g['id'] as int, g['name'] as String)],
                      selected: kids[i].groupId,
                    );
                    if (value != null && mounted) _update(() => kids[i].groupId = value);
                  },
                  end: IonSelectValue(text: selected?['name'] as String? ?? ''),
                );
              }),
            if (hasBirthDate)
              IonItem(
                label: l10n.tenantRegisterBirthDate,
                end: IonDateButton(
                  onTap: () => _pickChildBirthday(kids[i]),
                  text: kids[i].birthDate != null
                      ? dateFormat.format(kids[i].birthDate!)
                      : l10n.tenantRegisterPleaseChoose,
                ),
              ),
            if (kids.length > 1)
              IonItem(
                label: l10n.parentRegisterRemoveChild,
                labelColor: AppColors.danger,
                onTap: _isLoading ? null : () => _update(() => kids.removeAt(i)),
              ),
          ],
        ),
      ],
      IonInsetGroup(
        margin: _betaGroupMargin,
        color: _betaGroupColor,
        children: [
          IonItem(
            key: const ValueKey('tenant-register-add-child'),
            start: Icon(AppIcons.add, color: AppColors.primary),
            label: l10n.parentRegisterAddChild,
            labelColor: AppColors.primary,
            onTap: _isLoading
                ? null
                : () => _update(() => kids.add(ChildRegistrationData(lastName: _lastNameController.text.trim()))),
          ),
        ],
      ),
    ];
  }

  // Form groups sit flush inside the card.
  EdgeInsetsGeometry? get _betaGroupMargin => const EdgeInsets.only(bottom: 8);
  Color? get _betaGroupColor => context.rd.bg;

  List<Widget> _buildAdditionalFields(
    List<String> registrationFields,
    List<ExtraField> additionalFields,
  ) {
    final widgets = <Widget>[];
    final inputStyle = ionItemInputStyle(context);

    // Ionic: in the order of registration_fields.
    for (final field
        in orderedRegistrationFields(registrationFields, additionalFields)) {
      switch (field.type) {
        case 'text':
        case 'textarea':
          widgets.add(
            IonInputItem(
              child: TextFormField(
                style: inputStyle,
                textCapitalization: TextCapitalization.sentences,
                decoration: ionItemInputDecoration(context, field.name),
                maxLines: field.type == 'textarea' ? 3 : 1,
                // Ionic: text fields created without a default carry
                // `false` (emptyField); ion-input shows that as empty and the
                // required check below then shows the toast.
                initialValue: field.defaultValue is bool
                    ? ''
                    : field.defaultValue?.toString(),
                // Ionic stores the input value as is (validated below).
                onSaved: (value) =>
                    _formData.additionalFields[field.id] = value ?? '',
              ),
            ),
          );

        case 'number':
          widgets.add(
            IonInputItem(
              child: TextFormField(
                style: inputStyle,
                decoration: ionItemInputDecoration(context, field.name),
                // Ionic ion-input type=number: decimals and negatives allowed.
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true, signed: true),
                initialValue: field.defaultValue?.toString(),
                // Ionic stores null for a cleared number input, otherwise the
                // number (parseFloat); unparsable input stays a string so the
                // check below shows the toast.
                onSaved: (value) => _formData.additionalFields[field.id] =
                    value == null || value.trim().isEmpty
                        ? null
                        : parseRegistrationNumber(value) ?? value,
              ),
            ),
          );

        case 'boolean':
          // Ionic ion-toggle: off until a boolean value is set.
          final raw = _formData.additionalFields[field.id];
          final value = raw is bool ? raw : false;
          widgets.add(
            IonItem(
              title: Text(field.name),
              end: IonSwitch(
                value: value,
                onChanged: (newValue) => _update(
                    () => _formData.additionalFields[field.id] = newValue),
              ),
            ),
          );

        case 'select':
          if (field.options != null && field.options!.isNotEmpty) {
            // Prefilled with defaultValue (Ionic field.value).
            final current = _formData.additionalFields[field.id]?.toString();
            widgets.add(
              IonItem(
                label: field.name,
                onTap: () async {
                  final value = await showIonSelectOptions<String>(
                    context,
                    title: field.name,
                    options: [for (final o in field.options!) (o, o)],
                    selected: current,
                  );
                  if (value != null && mounted) {
                    _update(
                        () => _formData.additionalFields[field.id] = value);
                  }
                },
                end: IonSelectValue(
                  text: current ?? context.l10n.tenantRegisterPleaseChoose,
                  placeholder: current == null,
                ),
              ),
            );
          }

        case 'date':
          final currentValue = _formData.additionalFields[field.id];
          final currentDate = currentValue != null
              ? DateTime.tryParse(currentValue.toString())
              : null;
          widgets.add(
            IonItem(
              label: field.name,
              end: IonDateButton(
                text: currentDate != null
                    ? DateFormat(dateFmt()).format(currentDate)
                    : context.l10n.tenantRegisterPleaseChoose,
                onTap: () async {
                  final date = await showAppDatePicker(
                    context: context,
                    initialDate: currentDate ?? DateTime.now(),
                    firstDate: DateTime(1900),
                    lastDate: DateTime(2100),
                  );
                  if (date != null && mounted) {
                    _update(() {
                      _formData.additionalFields[field.id] =
                          date.toIso8601String().split('T').first;
                    });
                  }
                },
              ),
            ),
          );

        case 'bfecg_church':
          widgets.addAll(_buildChurchField(field));
      }
    }

    return widgets;
  }

  /// Ionic: label + clear button with the church name (opens the searchable
  /// church modal); "Nicht gelistet" adds an item for the church name.
  List<Widget> _buildChurchField(ExtraField field) {
    final churchesAsync = ref.watch(churchesProvider);
    final churches = churchesAsync.valueOrNull ?? const <Church>[];
    final selectedChurchId = _formData.additionalFields[field.id]?.toString();
    final isCustom = selectedChurchId == '';
    final name =
        field.name.isNotEmpty ? field.name : context.l10n.exportChurch;

    String churchLabel() {
      if (selectedChurchId == null) {
        return context.l10n.tenantRegisterPleaseChoose;
      }
      if (selectedChurchId.isEmpty) return context.l10n.tenantRegisterNotListed;
      return churches.where((c) => c.id == selectedChurchId).firstOrNull?.name ??
          context.l10n.tenantRegisterPleaseChoose;
    }

    return [
      IonItem(
        label: name,
        end: churchesAsync.hasError
            ? Text(context.l10n.tenantRegisterFlutterLoadChurchesFailed,
                style: const TextStyle(color: AppColors.danger, fontSize: 13))
            : TextButton(
                onPressed: churchesAsync.isLoading
                    ? null
                    : () async {
                        final selected = await showChurchPicker(
                          context,
                          title: name,
                          churches: churches,
                          selectedId: selectedChurchId,
                          searchHint: context.l10n.tenantRegisterSearchChurch,
                          notListedLabel: context.l10n.tenantRegisterNotListed,
                          noChurchLabel: context.l10n.tenantRegisterNoChurchFound,
                        );
                        if (selected == null || !mounted) return;
                        _update(() {
                          _formData.additionalFields[field.id] = selected;
                          if (selected != '') {
                            _formData.additionalFields.remove('_custom_church');
                          }
                        });
                      },
                child: IonButtonLabel(churchLabel()),
              ),
      ),
      if (isCustom)
        IonInputItem(
          child: TextFormField(
            style: ionItemInputStyle(context),
            textCapitalization: TextCapitalization.words,
            decoration: ionItemInputDecoration(
              context,
              context.l10n.tenantRegisterChurchNotListed,
              hint: context.l10n.tenantRegisterChurchNamePlaceholder,
            ),
            onSaved: (value) {
              _formData.additionalFields['_custom_church'] = value?.trim();
            },
          ),
        ),
    ];
  }
}
