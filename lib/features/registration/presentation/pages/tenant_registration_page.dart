import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../../core/config/supabase_config.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/enums.dart';
import '../../../../core/providers/church_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/string_utils.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/providers/user_preferences_provider.dart';
import '../../../../core/utils/dashboard_logic.dart';
import '../../../../data/models/tenant/tenant.dart';
import '../../../auth/data/auth_flow_service.dart';
import '../../../auth/presentation/widgets/otp_widgets.dart';
import '../../../legal/presentation/widgets/legal_content_view.dart';
import '../../data/providers/registration_providers.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/common/error_state_view.dart';

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
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
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

  bool get _isLoggedIn => ref.read(supabaseClientProvider).auth.currentUser != null;

  @override
  void initState() {
    super.initState();
    // Ionic default: birth date 18 years ago.
    final now = DateTime.now();
    _formData.birthDate = DateTime(now.year - 18, now.month, now.day);
  }

  @override
  void dispose() {
    _birthdayController.dispose();
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

    return Scaffold(
      // Ionic tenant-register: no back/close on the left, a home button on
      // the right (goHome()).
      appBar: AppBar(
        title: Text(context.l10n.tenantRegisterTitle),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.home_outlined),
            tooltip: context.l10n.coreFlutterRouterGoHome,
            onPressed: _goHome,
          ),
        ],
      ),
      body: tenantAsync.when(
        // A retry shows the spinner again instead of the stale error.
        skipLoadingOnRefresh: false,
        loading: () => const Center(child: CircularProgressIndicator()),
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

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(AppDimensions.paddingM),
        children: [
          // Tenant info header
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.paddingM),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppColors.primaryLight,
                    child: Text(
                      StringUtils.getTenantInitials(
                        tenant.shortName,
                        tenant.longName,
                      ),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppDimensions.paddingM),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n.tenantRegisterFlutterRegistrationAt,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.medium,
                              ),
                        ),
                        Text(
                          tenant.shortName.isNotEmpty ? tenant.shortName : tenant.longName,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppDimensions.paddingS),
          Text(
            context.l10n.tenantRegisterIntro,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppDimensions.paddingL),

          // Account section (Ionic: "Account")
          ..._buildAccountSection(),

          // Personal data section
          Text(
            context.l10n.tenantRegisterPersonalData,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: AppDimensions.paddingM),
          TextFormField(
            controller: _firstNameController,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: '${context.l10n.tenantRegisterFirstName} *',
              prefixIcon: Icon(Icons.person_outlined),
            ),
            onSaved: (value) => _formData.firstName = value?.trim() ?? '',
          ),
          const SizedBox(height: AppDimensions.paddingM),
          TextFormField(
            controller: _lastNameController,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: '${context.l10n.tenantRegisterLastName} *',
              prefixIcon: Icon(Icons.person_outlined),
            ),
            onSaved: (value) => _formData.lastName = value?.trim() ?? '',
          ),
          const SizedBox(height: AppDimensions.paddingM),

          // Group selection
          groupsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => Text(context.l10n.tenantRegisterFlutterLoadGroupsFailed),
            data: (groups) {
              _noGroupsAvailable = groups.isEmpty;
              if (groups.isEmpty) {
                return Card(
                  color: AppColors.danger.withValues(alpha: 0.1),
                  child: Padding(
                    padding: EdgeInsets.all(AppDimensions.paddingM),
                    child: Text(
                      context.l10n.tenantRegisterNoGroups,
                      style: TextStyle(color: AppColors.danger),
                    ),
                  ),
                );
              }
              // Ionic: first group preselected.
              _formData.groupId ??= groups.first['id'] as int;
              return DropdownButtonFormField<int>(
                value: _formData.groupId,
                decoration: InputDecoration(
                  labelText: '${context.l10n.commonGroupLabelGroup} *',
                  prefixIcon: Icon(Icons.group_outlined),
                ),
                items: groups.map((g) {
                  return DropdownMenuItem<int>(
                    value: g['id'] as int,
                    child: Text(g['name'] as String),
                  );
                }).toList(),
                validator: (value) {
                  if (value == null) {
                    return context.l10n.tenantRegisterFlutterGroupRequired;
                  }
                  return null;
                },
                onChanged: (value) => _formData.groupId = value,
                onSaved: (value) => _formData.groupId = value,
              );
            },
          ),

          // Profile picture
          if (registrationFields.contains('picture')) ...[
            const SizedBox(height: AppDimensions.paddingM),
            _buildProfilePictureField(),
          ],

          // Optional fields based on registration_fields
          if (registrationFields.contains('birthDate')) ...[
            const SizedBox(height: AppDimensions.paddingM),
            _buildBirthdayField(),
          ],

          if (registrationFields.contains('phone')) ...[
            const SizedBox(height: AppDimensions.paddingM),
            TextFormField(
              controller: _phoneController,
              decoration: InputDecoration(
                labelText: context.l10n.tenantRegisterPhone,
                prefixIcon: Icon(Icons.phone_outlined),
              ),
              keyboardType: TextInputType.phone,
              onSaved: (value) => _formData.phone = value,
            ),
          ],

          // Dynamic additional fields
          ..._buildAdditionalFields(registrationFields, additionalFields),

          // Notes field
          const SizedBox(height: AppDimensions.paddingM),
          TextFormField(
            decoration: InputDecoration(
              labelText: context.l10n.tenantRegisterNotes,
              prefixIcon: Icon(Icons.notes_outlined),
              alignLabelWithHint: true,
            ),
            maxLines: 3,
            onSaved: (value) => _formData.notes = value,
          ),

          const SizedBox(height: AppDimensions.paddingL),

          // Submit button
          FilledButton(
            onPressed: _isLoading ||
                    _noGroupsAvailable ||
                    (!_isLoggedIn && _mode == AuthMode.otp)
                ? null
                : () => _submit(tenant),
            child: _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(context.l10n.tenantRegisterFinish),
          ),

          const SizedBox(height: AppDimensions.paddingL),
        ],
      ),
    );
  }

  Widget _buildBirthdayField() {
    final dateFormat = DateFormat(dateFmt());
    // FN-007: Use state-managed controller and update text on date change
    if (_formData.birthDate != null && _birthdayController.text.isEmpty) {
      _birthdayController.text = dateFormat.format(_formData.birthDate!);
    }
    return TextFormField(
      decoration: InputDecoration(
        labelText: context.l10n.tenantRegisterBirthDate,
        prefixIcon: const Icon(Icons.cake_outlined),
        suffixIcon: const Icon(Icons.calendar_today),
        hintText: _formData.birthDate != null
            ? dateFormat.format(_formData.birthDate!)
            : null,
      ),
      readOnly: true,
      controller: _birthdayController,
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: _formData.birthDate ?? DateTime(DateTime.now().year - 18),
          firstDate: DateTime(1900),
          lastDate: DateTime.now(),
        );
        if (date != null) {
          setState(() {
            _formData.birthDate = date;
            _birthdayController.text = dateFormat.format(date);
          });
        }
      },
    );
  }

  List<Widget> _buildAdditionalFields(
    List<String> registrationFields,
    List<ExtraField> additionalFields,
  ) {
    final widgets = <Widget>[];

    for (final field in additionalFields) {
      // Only show if in registration_fields
      if (!registrationFields.contains(field.id)) continue;

      widgets.add(const SizedBox(height: AppDimensions.paddingM));

      switch (field.type) {
        case 'text':
        case 'textarea':
          widgets.add(
            TextFormField(
              decoration: InputDecoration(
                labelText: field.name,
                prefixIcon: const Icon(Icons.text_fields),
              ),
              maxLines: field.type == 'textarea' ? 3 : 1,
              initialValue: field.defaultValue?.toString(),
              onSaved: (value) {
                if (value != null && value.isNotEmpty) {
                  _formData.additionalFields[field.id] = value;
                }
              },
            ),
          );
          break;

        case 'number':
          widgets.add(
            TextFormField(
              decoration: InputDecoration(
                labelText: field.name,
                prefixIcon: const Icon(Icons.numbers),
              ),
              keyboardType: TextInputType.number,
              initialValue: field.defaultValue?.toString(),
              onSaved: (value) {
                if (value != null && value.isNotEmpty) {
                  _formData.additionalFields[field.id] = int.tryParse(value) ?? value;
                }
              },
            ),
          );
          break;

        case 'boolean':
          widgets.add(
            StatefulBuilder(
              builder: (context, setFieldState) {
                final value = _formData.additionalFields[field.id] as bool? ??
                    field.defaultValue as bool? ??
                    false;
                return SwitchListTile(
                  title: Text(field.name),
                  value: value,
                  onChanged: (newValue) {
                    setFieldState(() {
                      _formData.additionalFields[field.id] = newValue;
                    });
                  },
                );
              },
            ),
          );
          break;

        case 'select':
          if (field.options != null && field.options!.isNotEmpty) {
            widgets.add(
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: field.name,
                  prefixIcon: const Icon(Icons.list),
                ),
                value: _formData.additionalFields[field.id] as String? ??
                    field.defaultValue?.toString(),
                items: field.options!.map((option) {
                  return DropdownMenuItem<String>(
                    value: option,
                    child: Text(option),
                  );
                }).toList(),
                onChanged: (value) {
                  _formData.additionalFields[field.id] = value;
                },
                onSaved: (value) {
                  if (value != null) {
                    _formData.additionalFields[field.id] = value;
                  }
                },
              ),
            );
          }
          break;

        case 'date':
          widgets.add(
            StatefulBuilder(
              builder: (context, setFieldState) {
                final dateFormat = DateFormat(dateFmt());
                final currentValue = _formData.additionalFields[field.id];
                final currentDate = currentValue != null
                    ? DateTime.tryParse(currentValue.toString())
                    : null;

                return TextFormField(
                  decoration: InputDecoration(
                    labelText: field.name,
                    prefixIcon: const Icon(Icons.calendar_today),
                  ),
                  readOnly: true,
                  controller: TextEditingController(
                    text: currentDate != null ? dateFormat.format(currentDate) : '',
                  ),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: currentDate ?? DateTime.now(),
                      firstDate: DateTime(1900),
                      lastDate: DateTime(2100),
                    );
                    if (date != null) {
                      setFieldState(() {
                        _formData.additionalFields[field.id] =
                            date.toIso8601String().split('T').first;
                      });
                    }
                  },
                );
              },
            ),
          );
          break;

        case 'bfecg_church':
          widgets.add(_buildChurchField(field));
          break;
      }
    }

    return widgets;
  }

  Widget _buildProfilePictureField() {
    return FormField<Uint8List>(
      builder: (fieldState) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: _pickImage,
            borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
            child: Container(
              padding: const EdgeInsets.all(AppDimensions.paddingM),
              decoration: BoxDecoration(
                border: Border.all(
                  color: fieldState.hasError ? AppColors.danger : AppColors.light,
                ),
                borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: AppColors.primaryLight,
                    backgroundImage: _profileImageBytes != null
                        ? MemoryImage(_profileImageBytes!)
                        : null,
                    child: _profileImageBytes == null
                        ? const Icon(Icons.person, size: 30, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(width: AppDimensions.paddingM),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _profileImageBytes != null
                              ? context.l10n.tenantRegisterReplacePicture
                              : context.l10n.tenantRegisterChoosePicture,
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          context.l10n.tenantRegisterFlutterMaxSize,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.medium,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.photo_camera, color: AppColors.primary),
                ],
              ),
            ),
          ),
          if (fieldState.hasError)
            Padding(
              padding: const EdgeInsets.only(
                left: AppDimensions.paddingM,
                top: AppDimensions.paddingXS,
              ),
              child: Text(
                fieldState.errorText!,
                style: TextStyle(color: AppColors.danger, fontSize: 12),
              ),
            ),
        ],
      ),
    );
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

  Widget _buildChurchField(ExtraField field) {
    final churchesAsync = ref.watch(churchesProvider);

    return churchesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => Text(context.l10n.tenantRegisterFlutterLoadChurchesFailed),
      data: (churches) {
        return StatefulBuilder(
          builder: (context, setFieldState) {
            final selectedChurchId =
                _formData.additionalFields[field.id]?.toString();
            final isCustom = selectedChurchId == '';

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: field.name.isNotEmpty ? field.name : context.l10n.exportChurch,
                    prefixIcon: const Icon(Icons.church_outlined),
                  ),
                  value: selectedChurchId,
                  isExpanded: true,
                  items: [
                    DropdownMenuItem<String>(
                      value: '',
                      child: Text(context.l10n.tenantRegisterNotListed),
                    ),
                    ...churches.map((c) => DropdownMenuItem<String>(
                          value: c.id,
                          child: Text(c.name),
                        )),
                  ],
                  onChanged: (value) {
                    setFieldState(() {
                      _formData.additionalFields[field.id] = value;
                      if (value != '') {
                        _formData.additionalFields.remove('_custom_church');
                      }
                    });
                  },
                ),
                if (isCustom) ...[
                  const SizedBox(height: AppDimensions.paddingM),
                  TextFormField(
                    decoration: InputDecoration(
                      labelText: context.l10n.tenantRegisterChurchNotListed,
                      hintText: context.l10n.tenantRegisterChurchNamePlaceholder,
                      prefixIcon: const Icon(Icons.edit),
                      helperText: context.l10n.tenantRegisterFlutterMinFiveChars,
                    ),
                    onSaved: (value) {
                      _formData.additionalFields['_custom_church'] =
                          value?.trim();
                    },
                  ),
                ],
              ],
            );
          },
        );
      },
    );
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
      final result = await showDialog<bool>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
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

  List<Widget> _buildAccountSection() {
    final theme = Theme.of(context);
    final title = Text(
      context.l10n.tenantRegisterAccount,
      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
    );

    if (_isLoggedIn) {
      final email = ref.read(supabaseClientProvider).auth.currentUser?.email ?? '';
      return [
        title,
        const SizedBox(height: AppDimensions.paddingS),
        Card(
          color: AppColors.success.withValues(alpha: 0.08),
          child: ListTile(
            leading: const Icon(Icons.verified_user_outlined,
                color: AppColors.success),
            title: Text(context.l10n.tenantRegisterSignedInAs(email)),
          ),
        ),
        const SizedBox(height: AppDimensions.paddingL),
      ];
    }

    return [
      title,
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton(
          onPressed: _isLoading ? null : _showLoginDialogForCurrentTenant,
          child: Text(context.l10n.tenantRegisterHaveAccount),
        ),
      ),
      AuthModeSegment(
        mode: _mode,
        enabled: !_isLoading,
        onChanged: (mode) {
          setState(() {
            _mode = mode;
            _otpSent = false;
            _otpController.clear();
          });
          _cooldown.reset();
        },
      ),
      const SizedBox(height: AppDimensions.paddingM),
      TextFormField(
        controller: _emailController,
        readOnly: _mode == AuthMode.otp && _otpSent,
        decoration: InputDecoration(
          labelText: '${context.l10n.tenantRegisterEmailAddress} *',
          prefixIcon: const Icon(Icons.email_outlined),
        ),
        keyboardType: TextInputType.emailAddress,
        autofillHints: const [AutofillHints.email],
        onSaved: (value) => _formData.email = value?.trim() ?? '',
      ),
      const SizedBox(height: AppDimensions.paddingM),
      if (_mode == AuthMode.password) ...[
        TextFormField(
          decoration: InputDecoration(
            labelText: '${context.l10n.loginPassword} *',
            prefixIcon: const Icon(Icons.lock_outlined),
            suffixIcon: IconButton(
              tooltip: context.l10n.loginShowPassword,
              icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
          obscureText: _obscurePassword,
          autofillHints: const [AutofillHints.newPassword],
          onChanged: (value) => _formData.password = value,
          onSaved: (value) => _formData.password = value ?? '',
        ),
        const SizedBox(height: AppDimensions.paddingM),
        TextFormField(
          decoration: InputDecoration(
            labelText: '${context.l10n.registerModalConfirmPassword} *',
            prefixIcon: const Icon(Icons.lock_outlined),
            suffixIcon: IconButton(
              icon: Icon(_obscureConfirmPassword
                  ? Icons.visibility
                  : Icons.visibility_off),
              onPressed: () => setState(
                  () => _obscureConfirmPassword = !_obscureConfirmPassword),
            ),
          ),
          obscureText: _obscureConfirmPassword,
          onSaved: (value) => _formData.confirmPassword = value ?? '',
        ),
        const SizedBox(height: AppDimensions.paddingS),
      ] else if (_otpSent) ...[
        OtpCodeField(
          controller: _otpController,
          enabled: !_isLoading,
          onCompleted: (_) => _verifyCode(),
        ),
        const SizedBox(height: AppDimensions.paddingS),
      ],
      _buildTermsCheckbox(),
      if (_mode == AuthMode.otp) ...[
        const SizedBox(height: AppDimensions.paddingS),
        if (!_otpSent)
          OutlinedButton(
            onPressed: _isLoading ? null : _requestCode,
            child: Text(context.l10n.loginSendCode),
          )
        else ...[
          OutlinedButton(
            onPressed: _isLoading ? null : _verifyCode,
            child: Text(context.l10n.tenantRegisterConfirmCode),
          ),
          Center(
            child: ResendCodeButton(
              cooldown: _cooldown,
              enabled: !_isLoading,
              onResend: _requestCode,
            ),
          ),
        ],
      ],
      const SizedBox(height: AppDimensions.paddingL),
    ];
  }

  Widget _buildTermsCheckbox() {
    return CheckboxListTile(
      value: _privacyAccepted,
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      onChanged: (v) => setState(() => _privacyAccepted = v ?? false),
      title: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          InkWell(
            onTap: () => showLegalModal(context),
            child: Text(
              context.l10n.tenantRegisterFlutterTermsLink,
              style: const TextStyle(
                color: AppColors.primary,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
          Text(context.l10n.tenantRegisterFlutterTermsAccept),
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

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
