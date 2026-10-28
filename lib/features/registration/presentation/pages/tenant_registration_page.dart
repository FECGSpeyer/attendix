import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../../core/config/supabase_config.dart';
import '../../../../core/constants/enums.dart';
import '../../../../core/providers/church_providers.dart';
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
import '../../../../shared/widgets/adaptive/adaptive.dart'; // IOS_LOOK
import '../../../../shared/widgets/layout/ionic_ios.dart'
    show IonTranslucentAppBar, IonContentTopInset; // IOS_R6

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
  bool _hasCheckedRegistration = false;

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
        actions: [
          IconButton(
            icon: const Icon(Icons.home_outlined),
            tooltip: context.l10n.coreFlutterRouterGoHome,
            onPressed: _goHome,
          ),
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

    final groupsAsync = ref.watch(registrationGroupsProvider(tenant.id!));
    final registrationFields = tenant.registrationFields ?? [];
    final additionalFields = tenant.additionalFields ?? [];
    final theme = Theme.of(context);
    final ios = ionIsIos(context);
    final inputStyle = ionItemInputStyle(context);
    final dateFormat = DateFormat(dateFmt());

    // Ionic tenant-register: one inset list with a card (instance name +
    // intro), then the "Account", "Persönliche Daten" and "Weitere
    // Informationen" groups and the primary "Registrierung abschließen" item.
    return Form(
      key: _formKey,
      child: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          const IonContentTopInset(), // IOS_R6
          // ion-header collapse="condense": large title on iOS
          if (ios)
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
          Container(
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
                const Icon(Icons.business_outlined,
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

          // Account
          IonListHeader(context.l10n.tenantRegisterAccount),
          _buildAccountGroup(),

          // Persönliche Daten
          IonListHeader(context.l10n.tenantRegisterPersonalData),
          IonInsetGroup(
            children: [
              if (registrationFields.contains('picture'))
                IonItem(
                  onTap: _pickImage,
                  start: CircleAvatar(
                    radius: 20,
                    backgroundColor: AppColors.light,
                    backgroundImage: _profileImageBytes != null
                        ? MemoryImage(_profileImageBytes!)
                        : null,
                    child: _profileImageBytes == null
                        ? const Icon(Icons.person, color: AppColors.medium)
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
              if (registrationFields.contains('birthDate'))
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

          // Weitere Informationen
          IonListHeader(context.l10n.tenantRegisterMoreInfo),
          IonInsetGroup(
            children: [
              groupsAsync.when(
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
                        start: const Icon(Icons.warning_amber_outlined,
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
          IonInsetGroup(
            children: [
              IonButtonItem(
                key: const ValueKey('tenant-register-finish'),
                filled: true,
                icon: Icons.check_circle_outline,
                label: context.l10n.tenantRegisterFinish,
                onTap: _isLoading ||
                        _noGroupsAvailable ||
                        (!_isLoggedIn && _mode == AuthMode.otp)
                    ? null
                    : () => _submit(tenant),
              ),
            ],
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: Center(child: AppSpinner()),
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

    for (final field in additionalFields) {
      // Only show if in registration_fields
      if (!registrationFields.contains(field.id)) continue;

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
                initialValue: field.defaultValue?.toString(),
                onSaved: (value) {
                  if (value != null && value.isNotEmpty) {
                    _formData.additionalFields[field.id] = value;
                  }
                },
              ),
            ),
          );

        case 'number':
          widgets.add(
            IonInputItem(
              child: TextFormField(
                style: inputStyle,
                decoration: ionItemInputDecoration(context, field.name),
                keyboardType: TextInputType.number,
                initialValue: field.defaultValue?.toString(),
                onSaved: (value) {
                  if (value != null && value.isNotEmpty) {
                    _formData.additionalFields[field.id] =
                        int.tryParse(value) ?? value;
                  }
                },
              ),
            ),
          );

        case 'boolean':
          final value = _formData.additionalFields[field.id] as bool? ??
              field.defaultValue as bool? ??
              false;
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
            final current = _formData.additionalFields[field.id] as String? ??
                field.defaultValue?.toString();
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

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 80,
      );
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

      setState(() => _profileImageBytes = bytes);
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
                child: Text(churchLabel()),
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

    try {
      final supabase = ref.read(supabaseClientProvider);
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      final existing = await supabase
          .from('tenantUsers')
          .select('id')
          .eq('tenantId', tenant.id!)
          .eq('userId', userId)
          .maybeSingle();

      if (existing != null && mounted) {
        ToastHelper.showWarning(
            context, context.l10n.tenantRegisterAlreadyRegistered);
        context.go('/login');
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
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(context.l10n.tenantRegisterFlutterSignInExisting),
                  const SizedBox(height: 16),
                  TextField(
                    controller: emailController,
                    decoration: InputDecoration(
                      labelText: context.l10n.loginEmail,
                      prefixIcon: const Icon(Icons.email_outlined),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: passwordController,
                    decoration: InputDecoration(
                      labelText: context.l10n.loginPassword,
                      prefixIcon: const Icon(Icons.lock_outlined),
                    ),
                    obscureText: true,
                  ),
                  if (loginError.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(loginError, style: const TextStyle(color: AppColors.danger, fontSize: 12)),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(context.l10n.commonCancel),
                ),
                ElevatedButton(
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
        children: [IonItem(label: context.l10n.tenantRegisterSignedInAs(email))],
      );
    }

    final inputStyle = ionItemInputStyle(context);
    return IonInsetGroup(
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
            child: OtpCodeField(
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
    if (registrationFields.contains('picture') && _profileImageBytes == null) {
      return context.l10n.tenantRegisterPictureRequired;
    }
    if (registrationFields.contains('birthDate') && _formData.birthDate == null) {
      return context.l10n.tenantRegisterBirthDateRequired;
    }
    if (registrationFields.contains('phone') &&
        !isValidPhoneNumber(
            (_formData.phone ?? '').replaceAll(RegExp(r'\s+'), ''))) {
      return context.l10n.tenantRegisterPhoneRequired;
    }

    for (final field in tenant.additionalFields ?? const <ExtraField>[]) {
      if (!registrationFields.contains(field.id)) continue;
      final value = _formData.additionalFields[field.id];
      switch (field.type) {
        case 'text':
        case 'textarea':
          if (value is! String || value.trim().isEmpty) {
            return context.l10n.tenantRegisterFieldRequired(field.name);
          }
        case 'number':
          if (value == null || num.tryParse(value.toString()) == null) {
            return context.l10n.tenantRegisterFieldNumber(field.name);
          }
        case 'date':
          if (value == null || DateTime.tryParse(value.toString()) == null) {
            return context.l10n.tenantRegisterFieldDate(field.name);
          }
        case 'boolean':
          final boolValue = value is bool
              ? value
              : (field.defaultValue is bool ? field.defaultValue as bool : false);
          _formData.additionalFields[field.id] = boolValue;
          if (!boolValue && field.name.toLowerCase().contains('einverständnis')) {
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

    final result = await ref.read(registrationServiceProvider).register(
          tenant: tenant,
          formData: _formData,
          otpMode: _mode == AuthMode.otp,
        );

    if (!mounted) return;
    setState(() => _isLoading = false);

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
