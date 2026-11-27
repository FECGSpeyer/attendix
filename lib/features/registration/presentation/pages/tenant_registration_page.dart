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
import '../../../../core/providers/redesign_providers.dart' show redesignSettingsProvider;
import '../../../../core/theme/redesign/rd_theme.dart';
import '../../../../shared/widgets/display/attendix_logo.dart';
import '../../../../shared/widgets/redesign/rd_logo.dart' show rdLogoColors;
import '../../../../shared/widgets/redesign/rd_widgets.dart';
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

part 'tenant_registration_account.dart';
part 'tenant_registration_form.dart';
part 'tenant_registration_submit.dart';

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


  void _update(VoidCallback fn) => setState(fn);

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
    return _buildView(tenantAsync);
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

  void _choose(bool forChildren) {
    setState(() {
      _forChildren = forChildren;
      _formData.forChildren = forChildren;
    });
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

  /// Card with the group on top that scrolls with the form; "Registrierung
  /// abschließen" sits at the end of the card.
  Widget _buildView(AsyncValue<Tenant?> tenantAsync) {
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
}
