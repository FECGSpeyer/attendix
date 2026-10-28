import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/supabase_config.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/enums.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/providers/user_preferences_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../legal/presentation/widgets/legal_content_view.dart';

/// Login page
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _startDemo() {
    _emailController.text = AppConstants.demoMail;
    _passwordController.text = AppConstants.demoPassword;
    _login();  // Fire-and-forget OK — _login has its own try-catch + mounted checks
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final supabase = ref.read(supabaseClientProvider);
      final response = await supabase.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (response.user != null && mounted) {
        // Check if user wants to skip tenant selection
        final userPrefs =
            UserPreferences.fromUserMetadata(response.user!.userMetadata);

        if (!userPrefs.wantInstanceSelection &&
            userPrefs.currentTenantId != null) {
          // Try to auto-navigate to saved tenant
          final navigated = await _tryAutoNavigateToTenant(
            userPrefs.currentTenantId!,
          );
          if (navigated) return;
        }

        // Default: show tenant selection
        if (mounted) {
          context.go('/tenants');
        }
      } else if (mounted) {
        setState(() {
          _errorMessage =
              'Login fehlgeschlagen. Benutzer konnte nicht authentifiziert werden.';
        });
      }
    } catch (e) {
      debugPrint('Login error: $e');
      String errorMessage;
      if (e is AuthException) {
        errorMessage = switch (e.message) {
          'Invalid login credentials' =>
            'E-Mail oder Passwort ist falsch.',
          'Email not confirmed' =>
            'Bitte bestätige zuerst deine E-Mail-Adresse.',
          'User not found' =>
            'Kein Konto mit dieser E-Mail gefunden.',
          'Too many requests' =>
            'Zu viele Versuche. Bitte warte einen Moment.',
          'User banned' || 'User is banned' =>
            'Dein Konto wurde gesperrt. Bitte kontaktiere den Administrator.',
          _ when e.message.contains('rate limit') =>
            'Zu viele Anfragen. Bitte warte einen Moment.',
          _ when e.message.contains('network') =>
            'Netzwerkfehler. Bitte prüfe deine Internetverbindung.',
          _ => 'Login fehlgeschlagen: ${e.message}',
        };
      } else {
        errorMessage =
            'Ein unerwarteter Fehler ist aufgetreten. Bitte versuche es erneut.';
      }
      if (!mounted) return;
      setState(() {
        _errorMessage = errorMessage;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Try to auto-navigate to the saved tenant
  /// Returns true if navigation was successful, false otherwise
  Future<bool> _tryAutoNavigateToTenant(int tenantId) async {
    try {
      // Load user's tenants to verify access
      final tenants = await ref.read(userTenantsProvider.future);
      final savedTenant = tenants.where((t) => t.id == tenantId).firstOrNull;

      if (savedTenant == null) {
        // User no longer has access to this tenant
        return false;
      }

      // Get user's role FIRST, before any state changes
      final role = await _getTenantUserRole(tenantId);

      if (!mounted) return false;

      // Set tenant locally WITHOUT triggering auth sync
      await ref.read(currentTenantProvider.notifier).setTenantLocal(savedTenant);

      // Wait for currentTenantUserProvider to load so router doesn't redirect back
      await ref.read(currentTenantUserProvider.future);

      if (!mounted) return false;

      // Get notifier BEFORE navigation (widget may be disposed after go())
      final prefsNotifier = ref.read(userPreferencesNotifierProvider.notifier);

      // Navigate FIRST
      context.go(role.defaultRoute);

      // Auth sync AFTER navigation (fire and forget, notifier captured above)
      prefsNotifier.updateCurrentTenantId(tenantId);

      return true;
    } catch (e) {
      debugPrint('Auto-navigation failed: $e');
      return false;
    }
  }

  /// Get the user's role for a specific tenant
  Future<Role> _getTenantUserRole(int tenantId) async {
    final supabase = ref.read(supabaseClientProvider);
    final userId = supabase.auth.currentUser?.id;

    if (userId == null) return Role.none;

    final response = await supabase
        .from('tenantUsers')
        .select('role')
        .eq('tenantId', tenantId)
        .eq('userId', userId)
        .maybeSingle();

    if (response == null) return Role.none;
    return Role.fromValue(response['role'] as int? ?? 99);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppDimensions.paddingL),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: AppDimensions.maxFormWidth),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Logo/Title
                    const Icon(
                      Icons.people_outline,
                      size: 80,
                      color: AppColors.primary,
                    ),
                    const SizedBox(height: AppDimensions.paddingM),
                    Text(
                      'Attendix',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppDimensions.paddingXS),
                    Text(
                      'Anwesenheitsverwaltung',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.medium,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppDimensions.paddingXL),

                    // Error message
                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(AppDimensions.paddingM),
                        decoration: BoxDecoration(
                          color: AppColors.danger.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: AppColors.danger),
                            const SizedBox(width: AppDimensions.paddingS),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(color: AppColors.danger),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppDimensions.paddingM),
                    ],

                    // Email field
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: 'E-Mail',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Bitte E-Mail eingeben';
                        }
                        if (!value.contains('@')) {
                          return 'Bitte gültige E-Mail eingeben';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppDimensions.paddingM),

                    // Password field
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _login(),
                      decoration: InputDecoration(
                        labelText: 'Passwort',
                        prefixIcon: const Icon(Icons.lock_outlined),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Bitte Passwort eingeben';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppDimensions.paddingS),

                    // Forgot password link
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => context.push('/forgot-password'),
                        child: const Text('Passwort vergessen?'),
                      ),
                    ),
                    const SizedBox(height: AppDimensions.paddingM),

                    // Login button
                    ElevatedButton(
                      onPressed: _isLoading ? null : _login,
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text('Anmelden'),
                    ),
                    const SizedBox(height: AppDimensions.paddingL),

                    // Register link
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Text('Noch kein Konto?'),
                        TextButton(
                          onPressed: () {
                            final email = _emailController.text.trim();
                            final path = email.isNotEmpty
                                ? '/register?email=${Uri.encodeComponent(email)}'
                                : '/register';
                            context.push(path);
                          },
                          child: const Text('Registrieren'),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppDimensions.paddingL),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'v${AppConstants.appVersion}',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.medium,
                          ),
                        ),
                        if (AppConstants.demoMail.isNotEmpty && AppConstants.demoPassword.isNotEmpty) ...[
                          Text(
                            ' | ',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.medium,
                            ),
                          ),
                          GestureDetector(
                            onTap: _startDemo,
                            child: Text(
                              'Demo starten',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                        // LEGAL_HELP: Impressum & Datenschutz modal
                        Text(
                          ' | ',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.medium,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => showLegalModal(context),
                          child: Text(
                            'Impressum & Datenschutz',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}