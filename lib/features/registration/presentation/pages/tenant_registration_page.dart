import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:attendix/core/theme/app_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../../core/config/supabase_config.dart';
import '../../../../core/constants/enums.dart';
import '../../../../core/providers/church_providers.dart';
import '../../../../core/router/go_replace.dart';
import '../../../../core/providers/redesign_providers.dart';
import '../../../../core/theme/redesign/rd_theme.dart';
import '../../../../shared/widgets/display/attendix_logo.dart';
import '../../../redesign/presentation/widgets/rd_logo.dart' show rdLogoColors;
import '../../../redesign/presentation/widgets/rd_widgets.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/providers/user_preferences_provider.dart';
import '../../../../core/utils/dashboard_logic.dart';
import '../../../../data/models/tenant/tenant.dart';
import '../../../auth/data/auth_flow_service.dart';
import '../../../auth/presentation/widgets/ion_form_list.dart';
import '../../../auth/presentation/widgets/otp_widgets.dart';
import '../../../profile/presentation/widgets/church_picker.dart';
import '../../../../data/models/church/church.dart';
import '../../../legal/presentation/widgets/legal_content_view.dart';
import '../../data/providers/registration_providers.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/common/error_state_view.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';
import '../../../../shared/widgets/layout/ionic_ios.dart'
    show IonTranslucentAppBar, IonContentTopInset;

/// Public tenant registration page
class TenantRegistrationPage extends ConsumerStatefulWidget {
  const TenantRegistrationPage({
    super.key,
    required this.registerId,
  });

  final String registerId;

  @override
  ConsumerState<TenantRegistrationPage> createState() => _TenantRegistrationPageState();
}

class _TenantRegistrationPageState extends ConsumerState<TenantRegistrationPage> {
  final _formKey = GlobalKey<FormState>();
  final _formData = RegistrationFormData();
  // FN-007: Controller as state variable to prevent memory leak
  final _birthdayController = TextEditingController();

  bool _isLoading = false;
  Uint8List? _profileImageBytes;
  String? _profileImageMimeType;
  bool _hasCheckedRegistration = false;
  bool _defaultsApplied = false;

  // AUTH: account block (Ionic tenant-register): password or e-mail code,
  // terms checkbox, prefill from an existing profile.
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _cooldown = ResendCooldown();
  AuthMode _mode = AuthMode.password;
  bool _otpSent = false;
  bool _privacyAccepted = false;
  bool _noGroupsAvailable = false;

  /// "Wen möchtest du anmelden?": null until chosen, true for "Mein Kind"
  /// (an Elternteil registers one or more children).
  bool? _forChildren;

  /// iOS large title (`collapse="condense"`): the toolbar title appears once
  /// the large title has scrolled away.
  final _scrollController = ScrollController();
  final _showToolbarTitle = ValueNotifier<bool>(false);

  bool get _isLoggedIn => ref.read(supabaseClientProvider).auth.currentUser != null;

  @override
  void initState() {
    super.initState();
    // Ionic default: birth date 18 years ago.
    final now = DateTime.now();
    _formData.birthDate = DateTime(now.year - 18, now.month, now.day);
    _scrollController.addListener(() {
      _showToolbarTitle.value =
          _scrollController.hasClients && _scrollController.offset > 30;
    });
  }

  @override
  void dispose() {
    _birthdayController.dispose();
    _scrollController.dispose();
    _showToolbarTitle.dispose();
    _emailController.dispose();
    _otpController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _cooldown.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tenantAsync = ref.watch(tenantByRegisterIdProvider(widget.registerId));

    if (ref.watch(redesignEnabledProvider)) return _buildBeta(tenantAsync);
    final ios = ionIsIos(context);
    final hasData = tenantAsync.valueOrNull != null;
    return Scaffold(
      // IOS_R6: Ionic `ion-content [fullscreen]` under the translucent header
      extendBodyBehindAppBar: ios,
      // Ionic tenant-register: no back/close on the left, a home button on
      // the right (goHome()).
      // IOS_R6: `ion-header [translucent]` (blur once the large title has
      // scrolled away; always while there is no large title).
      appBar: IonTranslucentAppBar(
        condensed: !hasData,
        condensedListenable: hasData ? _showToolbarTitle : null,
        child: AppBar(
        title: ionIsIos(context) &&
                ref.watch(tenantByRegisterIdProvider(widget.registerId)).valueOrNull !=
                    null
            ? ValueListenableBuilder<bool>(
                valueListenable: _showToolbarTitle,
                builder: (context, show, child) => AnimatedOpacity(
                  opacity: show ? 1 : 0,
                  duration: const Duration(milliseconds: 150),
                  child: child,
                ),
                child: Text(context.l10n.tenantRegisterTitle),
              )
            : Text(context.l10n.tenantRegisterTitle),
        automaticallyImplyLeading: false,
        // SEL-13: Ionic `ion-buttons slot="end"` (iOS glass capsule).
        actions: [
          ToolbarButtonGroup(children: [
            IconButton(
              icon: Icon(AppIcons.homeOutlined),
              tooltip: context.l10n.coreFlutterRouterGoHome,
              onPressed: _goHome,
            ),
          ]),
        ],
      ),
      ),
      body: tenantAsync.when(
        // A retry shows the spinner again instead of the stale error.
        skipLoadingOnRefresh: false,
        loading: () => const Center(child: AppSpinner()),
        error: (error, stack) => _buildErrorState(error: error),
        data: (tenant) {
          if (tenant == null) {
            return _buildErrorState(
                message: context.l10n.tenantRegisterFlutterInvalidLink);
          }
          return _buildForm(tenant);
        },
      ),
    );
  }

  /// Ionic `goHome()`: signed-in member of a tenant -> that tenant's home,
  /// otherwise the login page.
  void _goHome() {
    final user = ref.read(supabaseAuthProvider).currentUser;
    final tenant = ref.read(currentTenantProvider);
    final role = ref.read(currentRoleProvider);
    if (user != null && tenant?.id != null && role != Role.none) {
      context.go(homeRouteFor(role, tenant!.id, user.userMetadata));
    } else {
      context.go('/login');
    }
  }

  /// Load failure (with retry) or invalid link: same centred
  /// [ErrorStateView] as the other pre-login pages.
  Widget _buildErrorState({String? message, Object? error}) {
    return ErrorStateView(
      error: error,
      title: error != null ? context.l10n.coreFlutterLoadFailed : null,
      message: message,
      onRetry: error == null
          ? null
          : () => ref.invalidate(tenantByRegisterIdProvider(widget.registerId)),
      secondaryLabel: context.l10n.tenantRegisterFlutterToLogin,
      onSecondary: () => context.go('/login'),
    );
  }

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
    final theme = Theme.of(context);
    final ios = ionIsIos(context);
    final inputStyle = ionItemInputStyle(context);
    final dateFormat = DateFormat(dateFmt());

    final beta = ref.watch(redesignEnabledProvider);
    Widget header(String text) => beta ? RdGroupLabel(text) : IonListHeader(text);

    // Ionic tenant-register: one inset list with a card (instance name +
    // intro), then the "Account", "Persönliche Daten" and "Weitere
    // Informationen" groups and the primary "Registrierung abschließen" item.
    // REDESIGN (E5): in the Beta the same groups sit in the card over the
    // login photo; the card header with the group comes from [_buildBeta].
    final children = <Widget>[
          if (!beta) const IonContentTopInset(),
          // ion-header collapse="condense": large title on iOS
          if (ios && !beta)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Text(
                context.l10n.tenantRegisterTitle,
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),

          // ion-card: business icon, instance name (ion-title), intro
          if (!beta) Container(
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
            decoration: BoxDecoration(
              color: theme.cardTheme.color ?? theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(ios ? 24 : 4),
              boxShadow: [
                BoxShadow(
                  color: ios ? const Color(0x1F000000) : const Color(0x33000000),
                  blurRadius: ios ? 12 : 2,
                  offset: Offset(0, ios ? 4 : 1),
                ),
              ],
            ),
            child: Column(
              children: [
                Icon(AppIcons.businessOutlined,
                    size: 64, color: Color(0xFF666666)),
                const SizedBox(height: 12),
                Text(
                  tenant.longName.isNotEmpty ? tenant.longName : tenant.shortName,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  context.l10n.tenantRegisterIntro,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: Color(0xFF666666)),
                ),
              ],
            ),
          ),

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
                        ? Icon(AppIcons.person, color: AppColors.medium)
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
                        setState(() => _formData.groupId = value);
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

          // ion-item color="primary" button: Registrierung abschließen
          if (beta)
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
            )
          else
          IonInsetGroup(
            children: [
              IonButtonItem(
                key: const ValueKey('tenant-register-finish'),
                filled: true,
                icon: AppIcons.checkCircleOutline,
                label: _finishLabel,
                onTap: _isLoading ||
                        _noGroupsAvailable ||
                        (!_isLoggedIn && _mode == AuthMode.otp)
                    ? null
                    : () => _submit(tenant),
              ),
            ],
          ),
          if (_isLoading && !beta)
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: Center(child: AppSpinner()),
            ),
    ];
    if (beta) {
      return Form(
        key: _formKey,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
      );
    }
    return Form(
      key: _formKey,
      child: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.only(bottom: 32),
        children: children,
      ),
    );
  }

  String get _finishLabel => _forChildren == true
      ? context.l10n.parentRegisterFinish(_formData.children.length)
      : context.l10n.tenantRegisterFinish;

  void _choose(bool forChildren) {
    setState(() {
      _forChildren = forChildren;
      _formData.forChildren = forChildren;
    });
  }

  /// "Wen möchtest du anmelden?": "Mich selbst" (the old form) or "Mein
  /// Kind" (an Elternteil registers children). Nothing is preselected, so
  /// parents never register themselves as members by mistake.
  Widget _buildChoice(Tenant tenant) {
    final beta = ref.watch(redesignEnabledProvider);
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
      if (!beta) ...[
        const IonContentTopInset(),
        // The Beta card shows the group above; the old page names it here.
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Text(
            tenant.longName.isNotEmpty ? tenant.longName : tenant.shortName,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
        ),
      ],
      beta ? RdGroupLabel(l10n.parentRegisterWhoTitle) : IonListHeader(l10n.parentRegisterWhoTitle),
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
    if (beta) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
    }
    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.only(bottom: 32),
      children: children,
    );
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
            onPressed: _isLoading ? null : () => setState(() => _forChildren = null),
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
                    if (value != null && mounted) setState(() => kids[i].groupId = value);
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
                onTap: _isLoading ? null : () => setState(() => kids.removeAt(i)),
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
                : () => setState(() => kids.add(ChildRegistrationData(lastName: _lastNameController.text.trim()))),
          ),
        ],
      ),
    ];
  }

  Future<void> _pickChildBirthday(ChildRegistrationData child) async {
    final now = DateTime.now();
    final date = await showAppDatePicker(
      context: context,
      initialDate: child.birthDate ?? DateTime(now.year - 10, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (date != null && mounted) setState(() => child.birthDate = date);
  }

  // REDESIGN (E5): the form groups sit flush inside the Beta card.
  EdgeInsetsGeometry? get _betaGroupMargin =>
      ref.read(redesignEnabledProvider) ? const EdgeInsets.only(bottom: 8) : null;
  Color? get _betaGroupColor => ref.read(redesignEnabledProvider) ? context.rd.bg : null;

  /// REDESIGN (E5): same photo and logo as the login, a Beta card with the
  /// group on top that scrolls with the form; "Registrierung abschließen"
  /// at the end of the card. Form, fields and flow are the old ones.
  Widget _buildBeta(AsyncValue<Tenant?> tenantAsync) {
    final p = context.rd;
    final l10n = context.l10n;
    final tenant = tenantAsync.valueOrNull;
    final Widget content;
    if (tenantAsync.isLoading && tenant == null) {
      content = const Padding(padding: EdgeInsets.all(32), child: Center(child: AppSpinner()));
    } else if (tenantAsync.hasError && tenant == null) {
      content = _buildErrorState(error: tenantAsync.error);
    } else if (tenant == null) {
      content = _buildErrorState(message: l10n.tenantRegisterFlutterInvalidLink);
    } else {
      final name = tenant.longName.isNotEmpty ? tenant.longName : tenant.shortName;
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(name, textAlign: TextAlign.center, style: RdType.section(p)),
          const SizedBox(height: 4),
          Text(l10n.tenantRegisterIntro, textAlign: TextAlign.center, style: RdType.meta(p, size: 14)),
          const SizedBox(height: 16),
          _buildForm(tenant),
        ],
      );
    }
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/login_bg.jpg',
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => ColoredBox(color: p.primary),
          ),
          SafeArea(
            bottom: false,
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: EdgeInsets.fromLTRB(10, 72, 10, 32 + MediaQuery.paddingOf(context).bottom),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.topCenter,
                    children: [
                      Container(
                        padding: const EdgeInsets.fromLTRB(20, 64, 20, 20),
                        decoration: BoxDecoration(
                          color: p.surface,
                          borderRadius: BorderRadius.circular(p.cardRadius),
                          boxShadow: const [
                            BoxShadow(color: Color(0x73000000), blurRadius: 60, spreadRadius: -15, offset: Offset(0, 20)),
                          ],
                        ),
                        child: content,
                      ),
                      Positioned(
                        top: -56,
                        child: Container(
                          width: 104,
                          height: 104,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: p.surface,
                            boxShadow: const [
                              BoxShadow(color: Color(0x8F000000), blurRadius: 38, spreadRadius: -12, offset: Offset(0, 16)),
                            ],
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: AttendixLogo(size: 104, radius: 0, colors: rdLogoColors(ref.watch(redesignSettingsProvider).world)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: SafeArea(
              child: IconButton(
                icon: Icon(AppIcons.homeOutlined, color: Colors.white),
                tooltip: l10n.coreFlutterRouterGoHome,
                onPressed: _goHome,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickBirthday() async {
    final date = await showAppDatePicker(
      context: context,
      initialDate: _formData.birthDate ?? DateTime(DateTime.now().year - 18),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (date != null) {
      setState(() {
        _formData.birthDate = date;
        _birthdayController.text = DateFormat(dateFmt()).format(date);
      });
    }
  }

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
              end: Switch.adaptive(
                value: value,
                onChanged: (newValue) => setState(
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
                    setState(
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
                    setState(() {
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

  /// Ionic changeImg(): with a picture already chosen, ask first
  /// ("Passbild ersetzen" / "Abbrechen").
  Future<void> _changeImage() async {
    if (_profileImageBytes != null) {
      final replace = await showAppActionSheet<bool>(
        context,
        actions: [
          AppActionSheetAction(
            label: context.l10n.tenantRegisterReplacePicture,
            value: true,
          ),
        ],
      );
      if (replace != true || !mounted) return;
    }
    await _pickImage();
  }

  /// Ionic onImageSelect(): `<input type="file" accept="image/*">` – the
  /// system offers camera and photo library, the original file is uploaded
  /// (max. 15 MB). In the browser the file input still offers both.
  /// Content type from the file name when the picker gives none.
  static String _mimeTypeFor(String name) {
    final ext = name.split('.').last.toLowerCase();
    return switch (ext) {
      'png' => 'image/png',
      'gif' => 'image/gif',
      'webp' => 'image/webp',
      'heic' => 'image/heic',
      'heif' => 'image/heif',
      _ => 'image/jpeg',
    };
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      var source = ImageSource.gallery;
      // Camera / gallery choice only where the plugin has a camera (not on
      // macOS, it throws there); otherwise straight to the gallery.
      if (!kIsWeb && picker.supportsImageSource(ImageSource.camera)) {
        final picked = await showAppActionSheet<ImageSource>(
          context,
          actions: [
            AppActionSheetAction(
              label: context.l10n.attendanceFlutterCamera,
              value: ImageSource.camera,
              icon: AppIcons.photoCameraOutlined,
            ),
            AppActionSheetAction(
              label: context.l10n.attendanceFlutterGallery,
              value: ImageSource.gallery,
              icon: AppIcons.photoLibraryOutlined,
            ),
          ],
        );
        if (picked == null || !mounted) return;
        source = picked;
      }
      final image = await picker.pickImage(source: source);
      if (image == null) return;

      final bytes = await image.readAsBytes();

      // Check file size (max 15MB)
      if (bytes.length > 15 * 1024 * 1024) {
        if (mounted) {
          ToastHelper.showError(context,
              context.l10n.tenantRegisterPictureTooLarge);
        }
        return;
      }

      setState(() {
        _profileImageBytes = bytes;
        _profileImageMimeType = image.mimeType ?? _mimeTypeFor(image.name);
      });
    } catch (e) {
      if (mounted) {
        ToastHelper.showError(context,
            context.l10n.tenantRegisterPictureFailed);
      }
    }
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
                        setState(() {
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

  Future<void> _checkExistingRegistration(Tenant tenant) async {
    if (!_isLoggedIn || tenant.id == null) return;
    final route = ModalRoute.of(context);
    final router = GoRouter.of(context);

    try {
      final supabase = ref.read(supabaseClientProvider);
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      final existing = await supabase
          .from('tenantUsers')
          .select('id, role')
          .eq('tenantId', tenant.id!)
          .eq('userId', userId)
          .maybeSingle();

      // An Elternteil may register another child via the link.
      if (existing != null && existing['role'] == Role.parent.value && mounted) {
        _choose(true);
        await _prefillFromParent(userId, tenant.id!);
        return;
      }
      if (existing != null && mounted) {
        // EINST-61: opened in the running app this page sits on top of the
        // tab shell; going back into it before the page is shown left the
        // start page blank (shared shell navigator key).
        if (!await untilReadyToLeave(route) || !mounted) return;
        ToastHelper.showWarning(
            context, context.l10n.tenantRegisterAlreadyRegistered);
        router.go('/login');
        return;
      }
      await _prefillFromProfile(userId);
    } catch (e) {
      debugPrint('Check existing registration failed: $e');
    }
  }

  Future<void> _showLoginDialog(Tenant tenant) async {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    var loginError = '';

    try {
      final result = await showAppDialog<bool>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) {
            return AppAlertDialog(
              title: Text(context.l10n.loginSignIn),
              // Ionic alert: `email` + `password` inputs with placeholders
              // (tenant-register.page.ts login); the hint / a login error is
              // the alert message.
              content: AppAlertInputGroup(
                // SEL-07: Ionic has no message; only a login error is shown.
                message: loginError.isNotEmpty ? Text(loginError) : null,
                children: [
                  AppAlertInput(
                    controller: emailController,
                    placeholder: context.l10n.tenantRegisterEmailAddress,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  AppAlertInput(
                    controller: passwordController,
                    placeholder: context.l10n.loginModePassword,
                    obscureText: true,
                  ),
                ],
                beta: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(context.l10n.tenantRegisterFlutterSignInExisting),
                    const SizedBox(height: 16),
                    TextField(
                      controller: emailController,
                      decoration: InputDecoration(
                        labelText: context.l10n.loginEmail,
                        prefixIcon: Icon(AppIcons.emailOutlined),
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: passwordController,
                      decoration: InputDecoration(
                        labelText: context.l10n.loginPassword,
                        prefixIcon: Icon(AppIcons.lockOutlined),
                      ),
                      obscureText: true,
                    ),
                    if (loginError.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(loginError, style: const TextStyle(color: AppColors.danger, fontSize: 12)),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(context.l10n.commonCancel),
                ),
                // SEL-07: classic = plain Ionic alert button (Beta keeps
                // its raised button).
                (context.rdSkin != null ? ElevatedButton.new : TextButton.new)(
                  onPressed: () async {
                    try {
                      await ref.read(authFlowServiceProvider).signInWithPassword(
                            emailController.text.trim(),
                            passwordController.text,
                          );
                      if (context.mounted) Navigator.pop(context, true);
                    } on LoginFailure catch (failure) {
                      setDialogState(() {
                        loginError = failure.message ??
                            context.l10n.authConfirmEmailFirst;
                      });
                    } catch (e) {
                      setDialogState(() {
                        loginError = context.l10n.dbLoginFailed;
                      });
                    }
                  },
                  child: Text(context.l10n.loginSignIn),
                ),
              ],
            );
          },
        ),
      );

      if (result == true && mounted) {
        // Rebuild page to show logged-in state
        setState(() => _hasCheckedRegistration = false);
      }
    } finally {
      emailController.dispose();
      passwordController.dispose();
    }
  }

  // ---------------------------------------------------------------------------
  // AUTH: account block (Ionic tenant-register "Account")
  // ---------------------------------------------------------------------------

  Widget _buildAccountGroup() {
    if (_isLoggedIn) {
      final email = ref.read(supabaseClientProvider).auth.currentUser?.email ?? '';
      return IonInsetGroup(
        margin: _betaGroupMargin,
        color: _betaGroupColor,
        children: [IonItem(label: context.l10n.tenantRegisterSignedInAs(email))],
      );
    }

    final inputStyle = ionItemInputStyle(context);
    return IonInsetGroup(
      margin: _betaGroupMargin,
      color: _betaGroupColor,
      children: [
        IonButtonItem(
          label: context.l10n.tenantRegisterHaveAccount,
          onTap: _isLoading ? null : _showLoginDialogForCurrentTenant,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: AuthModeSegment(
            mode: _mode,
            enabled: !_isLoading,
            trackAlpha: 0.1,
            fontSize: 13.6,
            onChanged: (mode) {
              setState(() {
                _mode = mode;
                _otpSent = false;
                _otpController.clear();
              });
              _cooldown.reset();
            },
          ),
        ),
        IonInputItem(
          child: TextFormField(
            controller: _emailController,
            style: inputStyle,
            readOnly: _mode == AuthMode.otp && _otpSent,
            decoration: ionItemInputDecoration(
                context, context.l10n.tenantRegisterEmailAddress),
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            onSaved: (value) => _formData.email = value?.trim() ?? '',
          ),
        ),
        if (_mode == AuthMode.password) ...[
          IonInputItem(
            child: TextFormField(
              style: inputStyle,
              decoration: ionItemInputDecoration(
                  context, context.l10n.loginModePassword),
              obscureText: true,
              autofillHints: const [AutofillHints.newPassword],
              onChanged: (value) => _formData.password = value,
              onSaved: (value) => _formData.password = value ?? '',
            ),
          ),
          IonInputItem(
            child: TextFormField(
              style: inputStyle,
              decoration: ionItemInputDecoration(
                  context, context.l10n.registerModalConfirmPassword),
              obscureText: true,
              autofillHints: const [AutofillHints.newPassword],
              onSaved: (value) => _formData.confirmPassword = value ?? '',
            ),
          ),
        ] else if (_otpSent) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: ref.read(redesignEnabledProvider)
                // Beta card is narrower: shrink the code boxes to the space
                // that is left (e.g. 320 px screens) instead of clipping.
                ? FittedBox(
                    fit: BoxFit.scaleDown,
                    child: OtpCodeField(
                      controller: _otpController,
                      enabled: !_isLoading,
                      onCompleted: (_) => _verifyCode(),
                    ),
                  )
                : OtpCodeField(
                    controller: _otpController,
                    enabled: !_isLoading,
                    onCompleted: (_) => _verifyCode(),
                  ),
          ),
          ListenableBuilder(
            listenable: _otpController,
            builder: (context, _) => IonButtonItem(
              label: context.l10n.tenantRegisterConfirmCode,
              onTap: _isLoading || _otpController.text.isEmpty
                  ? null
                  : _verifyCode,
            ),
          ),
          ListenableBuilder(
            listenable: _cooldown,
            builder: (context, _) => IonButtonItem(
              label: _cooldown.active
                  ? context.l10n.loginResendIn(_cooldown.remaining)
                  : context.l10n.loginResendCode,
              onTap: _isLoading || _cooldown.active ? null : _requestCode,
            ),
          ),
        ] else
          IonButtonItem(
            label: context.l10n.loginSendCode,
            onTap: _isLoading ? null : _requestCode,
          ),
        _buildTermsCheckbox(),
      ],
    );
  }

  /// Ionic privacy-item: round checkbox (iOS) + "Ich akzeptiere die
  /// Datenschutzerklärung." with the link.
  Widget _buildTermsCheckbox() {
    const privacyStyle = TextStyle(fontSize: 14.4, height: 1.4);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 16, 6),
      child: Row(
        children: [
          Checkbox(
            value: _privacyAccepted,
            shape: ionIsIos(context) ? const CircleBorder() : null,
            onChanged: (v) => setState(() => _privacyAccepted = v ?? false),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: privacyStyle.copyWith(
                    color: Theme.of(context).colorScheme.onSurface),
                children: [
                  TextSpan(text: '${context.l10n.registerModalPrivacyBefore} '),
                  WidgetSpan(
                    alignment: PlaceholderAlignment.baseline,
                    baseline: TextBaseline.alphabetic,
                    child: InkWell(
                      onTap: () => showLegalModal(context),
                      child: Text(
                        context.l10n.registerModalPrivacyLink,
                        style: privacyStyle.copyWith(
                          color: AppColors.primary,
                          decoration: TextDecoration.underline,
                          decorationColor: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                  TextSpan(text: context.l10n.registerModalPrivacyAfter),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showLoginDialogForCurrentTenant() async {
    final tenant =
        ref.read(tenantByRegisterIdProvider(widget.registerId)).valueOrNull;
    if (tenant != null) await _showLoginDialog(tenant);
  }

  /// Ionic requestCode(): registration surface → may create the account.
  Future<void> _requestCode() async {
    final email = _emailController.text.trim().toLowerCase();
    if (!isValidEmail(email)) {
      ToastHelper.showError(context, context.l10n.loginToastInvalidEmail);
      return;
    }
    if (!_privacyAccepted) {
      ToastHelper.showError(context,
          context.l10n.tenantRegisterAcceptTermsToast);
      return;
    }
    setState(() => _isLoading = true);
    final result = await ref
        .read(authFlowServiceProvider)
        .sendEmailOtp(email, allowCreate: true);
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (result.success) {
      setState(() => _otpSent = true);
      _cooldown.start();
      ToastHelper.showSuccess(context, result.message);
    } else {
      ToastHelper.showError(context, result.message);
    }
  }

  /// Ionic verifyCode(): sign in, stamp terms, then stay on the page so the
  /// user can complete the profile.
  Future<void> _verifyCode() async {
    final code = _otpController.text.trim();
    if (code.isEmpty || _isLoading) return;
    setState(() => _isLoading = true);
    final service = ref.read(authFlowServiceProvider);
    final result = await service.verifyEmailOtp(
        _emailController.text.trim().toLowerCase(), code);
    if (!result.success) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ToastHelper.showError(context, result.message);
      return;
    }
    await service.stampTermsAccepted();
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _hasCheckedRegistration = false; // re-run check + prefill
    });
  }

  /// "Mein Kind" for an Elternteil of this group: the parent's own name.
  Future<void> _prefillFromParent(String userId, int tenantId) async {
    try {
      final row = await ref
          .read(supabaseClientProvider)
          .from('parents')
          .select('firstName, lastName')
          .eq('appId', userId)
          .eq('tenantId', tenantId)
          .limit(1)
          .maybeSingle();
      if (row == null || !mounted) return;
      setState(() {
        _firstNameController.text = row['firstName'] as String? ?? '';
        _lastNameController.text = row['lastName'] as String? ?? '';
      });
    } catch (e) {
      debugPrint('Prefill from parent failed: $e');
    }
  }

  /// Ionic prefillFromProfile(): names/phone (and birth date) from the
  /// user's first existing person profile.
  ///
  /// NOTE (Multi-Tenant): reads only the signed-in user's own rows (appId).
  Future<void> _prefillFromProfile(String userId) async {
    try {
      final row = await ref
          .read(supabaseClientProvider)
          .from('player')
          .select('firstName, lastName, phone, birthday')
          .eq('appId', userId)
          .limit(1)
          .maybeSingle();
      if (row == null || !mounted) return;
      final tenant =
          ref.read(tenantByRegisterIdProvider(widget.registerId)).valueOrNull;
      setState(() {
        final first = row['firstName'] as String?;
        final last = row['lastName'] as String?;
        final phone = row['phone'] as String?;
        if (first != null && first.isNotEmpty) _firstNameController.text = first;
        if (last != null && last.isNotEmpty) _lastNameController.text = last;
        if (phone != null && phone.isNotEmpty) _phoneController.text = phone;
        final birthday = DateTime.tryParse(row['birthday']?.toString() ?? '');
        if (birthday != null &&
            (tenant?.registrationFields ?? const []).contains('birthDate')) {
          _formData.birthDate = birthday;
          _birthdayController.text = DateFormat(dateFmt()).format(birthday);
        }
      });
    } catch (e) {
      debugPrint('Prefill from profile failed: $e');
    }
  }

  /// Ionic validate(): first error as toast.
  String? _validate(Tenant tenant) {
    if (_noGroupsAvailable) {
      return context.l10n.tenantRegisterNoGroupsToast;
    }
    if (!_isLoggedIn) {
      if (!_privacyAccepted) {
        return context.l10n.tenantRegisterAcceptTermsToast;
      }
      if (!isValidEmail(_formData.email)) {
        return context.l10n.loginToastInvalidEmail;
      }
      if (_formData.password.length < 6) {
        return context.l10n.tenantRegisterPasswordTooShort;
      }
      if (_formData.password != _formData.confirmPassword) {
        return context.l10n.tenantRegisterPasswordMismatch;
      }
    }
    if (_formData.firstName.isEmpty || _formData.lastName.isEmpty) {
      return context.l10n.tenantRegisterNameRequired;
    }
    final registrationFields = tenant.registrationFields ?? const [];
    if (_forChildren == true) {
      // "Mein Kind": names (and the birth date when asked) of every child;
      // no picture of the parent.
      for (final child in _formData.children) {
        if (child.firstName.trim().isEmpty || child.lastName.trim().isEmpty) {
          return context.l10n.parentRegisterChildNameRequired;
        }
        if (child.groupId == null) return context.l10n.tenantRegisterNoGroupsToast;
        if (registrationFields.contains('birthDate') && child.birthDate == null) {
          return context.l10n.parentRegisterChildBirthDateRequired;
        }
      }
    } else {
      if (registrationFields.contains('picture') && _profileImageBytes == null) {
        return context.l10n.tenantRegisterPictureRequired;
      }
      if (registrationFields.contains('birthDate') && _formData.birthDate == null) {
        return context.l10n.tenantRegisterBirthDateRequired;
      }
    }
    if (registrationFields.contains('phone') &&
        !isValidPhoneNumber(
            (_formData.phone ?? '').replaceAll(RegExp(r'\s+'), ''))) {
      return context.l10n.tenantRegisterPhoneRequired;
    }

    for (final field in orderedRegistrationFields(
        registrationFields, tenant.additionalFields ?? const <ExtraField>[])) {
      final value = _formData.additionalFields[field.id];
      switch (field.type) {
        case 'text':
        case 'textarea':
          if (value is! String || value.trim().isEmpty) {
            return context.l10n.tenantRegisterFieldRequired(field.name);
          }
        case 'number':
          // Ionic isNaN(Number(value)): an empty value (null) passes.
          if (value != null && num.tryParse(value.toString()) == null) {
            return context.l10n.tenantRegisterFieldNumber(field.name);
          }
        case 'date':
          if (value == null || DateTime.tryParse(value.toString()) == null) {
            return context.l10n.tenantRegisterFieldDate(field.name);
          }
        case 'boolean':
          // Ionic: no boolean value (no default, toggle untouched) → toast.
          if (value is! bool) {
            return context.l10n.tenantRegisterFieldValue(field.name);
          }
          if (!value && field.name.toLowerCase().contains('einverständnis')) {
            return context.l10n.tenantRegisterFieldAccept(field.name);
          }
        case 'bfecg_church':
          if (value is! String) return context.l10n.tenantRegisterChurchRequired;
          final custom =
              _formData.additionalFields['_custom_church']?.toString() ?? '';
          if (value.isEmpty && custom.trim().length < 5) {
            return context.l10n.tenantRegisterChurchNameRequired;
          }
      }
    }
    return null;
  }

  Future<void> _submit(Tenant tenant) async {
    _formKey.currentState!.save();
    final error = _validate(tenant);
    if (error != null) {
      ToastHelper.showError(context, error);
      return;
    }

    setState(() => _isLoading = true);

    // Handle custom church creation (bfecg_church field)
    final customChurchName = _formData.additionalFields.remove('_custom_church');
    if (_formData.additionalFields['bfecg_church'] == '' &&
        customChurchName != null &&
        customChurchName.toString().isNotEmpty) {
      final churchId = await ref
          .read(churchNotifierProvider.notifier)
          .createChurch(customChurchName.toString());
      if (churchId != null) {
        _formData.additionalFields['bfecg_church'] = churchId;
      } else {
        setState(() => _isLoading = false);
        if (!mounted) return;
        ToastHelper.showError(context, context.l10n.tenantRegisterFlutterCreateChurchFailed);
        return;
      }
    }

    // Attach profile image bytes if selected
    _formData.profileImageBytes = _profileImageBytes;
    _formData.profileImageMimeType = _profileImageMimeType;

    final service = ref.read(registrationServiceProvider);
    final result = _forChildren == true
        ? await service.registerChildren(
            tenant: tenant,
            formData: _formData,
            otpMode: _mode == AuthMode.otp,
          )
        : await service.register(
            tenant: tenant,
            formData: _formData,
            otpMode: _mode == AuthMode.otp,
          );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (!result.success && result.memberBlocked) {
      // Q3: say plainly why, nothing was saved.
      await showAppDialog(
        context: context,
        builder: (context) => AppAlertDialog(
          title: Text(context.l10n.parentRegisterMemberBlockedTitle),
          content: Text(result.errorMessage ?? ''),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.l10n.commonOk),
            ),
          ],
        ),
      );
      return;
    }
    if (!result.success) {
      final message = result.errorMessage ?? context.l10n.commonUnknown;
      ToastHelper.showError(
        context,
        message.startsWith(context.l10n.dbCreateAccountFailed)
            ? message
            : context.l10n.tenantRegisterFailed(message),
      );
      return;
    }

    await showAppDialog(
      context: context,
      builder: (context) => AppAlertDialog(
        title: Text(context.l10n.tenantRegisterSuccessHeader),
        content: Text(result.successMessage),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.l10n.commonOk),
          ),
        ],
      ),
    );
    if (!mounted) return;

    if (!result.isNewAccount && _isLoggedIn) {
      // Existing account added to a new tenant — switch directly into it.
      await _enterTenant(tenant, result.role);
    } else {
      context.go('/login');
    }
  }

  /// Ionic routeAfterAuth(undefined, tenantId).
  Future<void> _enterTenant(Tenant tenant, Role role) async {
    try {
      ref.invalidate(userTenantsProvider);
      await ref.read(currentTenantProvider.notifier).setTenantLocal(tenant);
      await ref.read(currentTenantUserProvider.future);
      if (!mounted) return;
      final prefsNotifier = ref.read(userPreferencesNotifierProvider.notifier);
      context.go(homeRouteFor(role, tenant.id,
          ref.read(supabaseAuthProvider).currentUser?.userMetadata));
      prefsNotifier.updateCurrentTenantId(tenant.id!);
    } catch (e) {
      debugPrint('Enter tenant after registration failed: $e');
      if (mounted) context.go('/tenants');
    }
  }
}
