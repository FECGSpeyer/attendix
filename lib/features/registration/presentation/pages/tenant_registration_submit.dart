part of 'tenant_registration_page.dart';

/// Validation, form submission, and post-registration routing for [TenantRegistrationPage].
extension _TenantRegistrationSubmit on _TenantRegistrationPageState {
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
        !isValidPhoneNumber((_formData.phone ?? '').replaceAll(RegExp(r'\s+'), ''))) {
      return context.l10n.tenantRegisterPhoneRequired;
    }

    for (final field in orderedRegistrationFields(
      registrationFields,
      tenant.additionalFields ?? const <ExtraField>[],
    )) {
      final error = _validateExtraField(field);
      if (error != null) return error;
    }
    return null;
  }

  String? _validateExtraField(ExtraField field) {
    final value = _formData.additionalFields[field.id];
    switch (field.type) {
      case 'text':
      case 'textarea':
        if (value is! String || value.trim().isEmpty) {
          return context.l10n.tenantRegisterFieldRequired(field.name);
        }
      case 'number':
        if (value != null && num.tryParse(value.toString()) == null) {
          return context.l10n.tenantRegisterFieldNumber(field.name);
        }
      case 'date':
        if (value == null || DateTime.tryParse(value.toString()) == null) {
          return context.l10n.tenantRegisterFieldDate(field.name);
        }
      case 'boolean':
        if (value is! bool) {
          return context.l10n.tenantRegisterFieldValue(field.name);
        }
        if (!value && field.name.toLowerCase().contains('einverständnis')) {
          return context.l10n.tenantRegisterFieldAccept(field.name);
        }
      case 'bfecg_church':
        if (value is! String) return context.l10n.tenantRegisterChurchRequired;
        final custom = _formData.additionalFields['_custom_church']?.toString() ?? '';
        if (value.isEmpty && custom.trim().length < 5) {
          return context.l10n.tenantRegisterChurchNameRequired;
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

    _update(() => _isLoading = true);

    // Handle custom church creation (bfecg_church field)
    final customChurchName = _formData.additionalFields.remove('_custom_church');
    if (_formData.additionalFields['bfecg_church'] == '' &&
        customChurchName != null &&
        customChurchName.toString().isNotEmpty) {
      final churchId = await ref.read(churchNotifierProvider.notifier).createChurch(customChurchName.toString());
      if (churchId != null) {
        _formData.additionalFields['bfecg_church'] = churchId;
      } else {
        _update(() => _isLoading = false);
        if (!mounted) return;
        ToastHelper.showError(context, context.l10n.tenantRegisterFlutterCreateChurchFailed);
        return;
      }
    }

    // Attach profile image bytes if selected
    _formData.profileImageBytes = _profileImageBytes;
    _formData.profileImageMimeType = _profileImageMimeType;

    final service = ref.read(registrationServiceProvider);
    final result =
        _forChildren == true
            ? await service.registerChildren(tenant: tenant, formData: _formData, otpMode: _mode == AuthMode.otp)
            : await service.register(tenant: tenant, formData: _formData, otpMode: _mode == AuthMode.otp);

    if (!mounted) return;
    _update(() => _isLoading = false);

    if (!result.success && result.memberBlocked) {
      await showAppDialog(
        context: context,
        builder:
            (context) => AppAlertDialog(
              title: Text(context.l10n.parentRegisterMemberBlockedTitle),
              content: Text(result.errorMessage ?? ''),
              actions: [FilledButton(onPressed: () => Navigator.of(context).pop(), child: Text(context.l10n.commonOk))],
            ),
      );
      return;
    }
    if (!result.success) {
      final message = result.errorMessage ?? context.l10n.commonUnknown;
      ToastHelper.showError(
        context,
        message.startsWith(context.l10n.dbCreateAccountFailed) ? message : context.l10n.tenantRegisterFailed(message),
      );
      return;
    }

    await showAppDialog(
      context: context,
      builder:
          (context) => AppAlertDialog(
            title: Text(context.l10n.tenantRegisterSuccessHeader),
            content: Text(result.successMessage),
            actions: [FilledButton(onPressed: () => Navigator.of(context).pop(), child: Text(context.l10n.commonOk))],
          ),
    );
    if (!mounted) return;

    if (!result.isNewAccount && _isLoggedIn) {
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
      context.go(homeRouteFor(role, tenant.id, ref.read(supabaseAuthProvider).currentUser?.userMetadata));
      prefsNotifier.updateCurrentTenantId(tenant.id!);
    } catch (e) {
      debugPrint('Enter tenant after registration failed: $e');
      if (mounted) context.go('/tenants');
    }
  }
}
