import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/supabase_config.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/repositories/account_repository.dart';
import '../../../legal/presentation/widgets/legal_content_view.dart';

/// Register page
class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key, this.email});

  final String? email;

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _errorMessage;
  bool _registrationSuccess = false;
  // LEGAL_HELP: privacy consent (Ionic register modal)
  bool _privacyAccepted = false;

  @override
  void initState() {
    super.initState();
    if (widget.email != null && widget.email!.isNotEmpty) {
      _emailController.text = widget.email!;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_privacyAccepted) {
      setState(() {
        _errorMessage =
            'Bitte stimme der Datenschutzerklärung zu';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final supabase = ref.read(supabaseClientProvider);
      await supabase.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        // Stamp terms acceptance (checkbox accepted), like Ionic.
        data: {
          AccountRepository.termsAcceptedAtKey:
              DateTime.now().toUtc().toIso8601String(),
        },
      );

      if (!mounted) return;
      setState(() {
        _registrationSuccess = true;
      });
    } catch (e) {
      if (!mounted) return;
      String errorMessage;
      if (e is AuthException) {
        errorMessage = switch (e.message) {
          'User already registered' =>
            'Diese E-Mail-Adresse ist bereits registriert.',
          _ when e.message.contains('password') =>
            'Das Passwort erfüllt nicht die Anforderungen.',
          _ when e.message.contains('rate limit') || e.message.contains('Too many') =>
            'Zu viele Versuche. Bitte warte einen Moment.',
          _ when e.message.contains('email') =>
            'Bitte gib eine gültige E-Mail-Adresse ein.',
          _ => 'Registrierung fehlgeschlagen: ${e.message}',
        };
      } else {
        errorMessage =
            'Registrierung fehlgeschlagen. Bitte versuche es erneut.';
      }
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

  @override
  Widget build(BuildContext context) {
    if (_registrationSuccess) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.paddingL),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: AppDimensions.maxFormWidth),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.mark_email_read_outlined,
                      size: 80,
                      color: AppColors.success,
                    ),
                    const SizedBox(height: AppDimensions.paddingL),
                    Text(
                      'E-Mail bestätigen',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppDimensions.paddingM),
                    Text(
                      'Wir haben dir eine E-Mail an ${_emailController.text} gesendet. '
                      'Bitte klicke auf den Link in der E-Mail, um deine Registrierung abzuschließen.',
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppDimensions.paddingXL),
                    ElevatedButton(
                      onPressed: () => context.go('/login'),
                      child: const Text('Zum Login'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Registrieren'),
      ),
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
                      textInputAction: TextInputAction.next,
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
                        if (value.length < 8) {
                          return 'Passwort muss mindestens 8 Zeichen haben';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppDimensions.paddingM),

                    // Confirm password field
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirmPassword,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _register(),
                      decoration: InputDecoration(
                        labelText: 'Passwort bestätigen',
                        prefixIcon: const Icon(Icons.lock_outlined),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirmPassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscureConfirmPassword = !_obscureConfirmPassword;
                            });
                          },
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Bitte Passwort bestätigen';
                        }
                        if (value != _passwordController.text) {
                          return 'Passwörter stimmen nicht überein';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppDimensions.paddingM),

                    // LEGAL_HELP: privacy consent checkbox
                    CheckboxListTile(
                      value: _privacyAccepted,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      onChanged: (v) =>
                          setState(() => _privacyAccepted = v ?? false),
                      title: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          const Text(
                              'Ich akzeptiere die Nutzungsbedingungen und habe die '),
                          InkWell(
                            onTap: () => showLegalModal(context),
                            child: const Text(
                              'Datenschutzerklärung',
                              style: TextStyle(
                                color: AppColors.primary,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                          const Text(' gelesen.'),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppDimensions.paddingM),

                    // Register button
                    ElevatedButton(
                      onPressed: _isLoading || !_privacyAccepted ? null : _register,
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text('Registrieren'),
                    ),
                    const SizedBox(height: AppDimensions.paddingL),

                    // Login link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Bereits ein Konto?'),
                        TextButton(
                          onPressed: () => context.go('/login'),
                          child: const Text('Anmelden'),
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