import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/config/supabase_config.dart';
import 'core/router/app_router.dart';
import 'core/services/app_update_service.dart';
import 'core/services/offline_queue_service.dart'; // PROFILE_OFFLINE
import 'core/theme/app_theme.dart';
import 'core/utils/toast_helper.dart';
import 'features/auth/data/auth_link_listener.dart'; // AUTH
import 'core/services/teams/teams_service.dart'; // TEAMS

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize locale data for German date formatting
  await initializeDateFormatting('de_DE', null);

  // Load environment variables
  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    if (kDebugMode) {
      print('Warning: Could not load .env file: $e');
    }
  }

  // Initialize Supabase
  await SupabaseConfig.initialize();

  // TEAMS: detect a Microsoft Teams tab (no-op outside an iframe / on native)
  await TeamsService.instance.init();

  runApp(
    const ProviderScope(
      child: AttendixApp(),
    ),
  );
}

/// Main application widget
class AttendixApp extends ConsumerStatefulWidget {
  const AttendixApp({super.key});

  @override
  ConsumerState<AttendixApp> createState() => _AttendixAppState();
}

class _AttendixAppState extends ConsumerState<AttendixApp> {
  @override
  void initState() {
    super.initState();
    // Start update listener (web only)
    if (kIsWeb) {
      ref.read(appUpdateServiceProvider).startListening();
    }
    // PROFILE_OFFLINE: replay queued offline attendance writes
    Future.microtask(
        () => ref.read(offlineQueueNotifierProvider.notifier).init());
    // AUTH: password-recovery / signup-confirmation links (Ionic handleAuthUrl)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) initAuthLinkHandling(ref, ref.read(routerProvider));
      // TEAMS: silent Microsoft SSO inside a Teams tab
      if (mounted) {
        trySsoSignIn(
          teams: ref.read(teamsServiceProvider),
          hasSession:
              ref.read(supabaseClientProvider).auth.currentSession != null,
          go: (location) => ref.read(routerProvider).go(location),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final updateAvailable = ref.watch(appUpdateAvailableProvider);
    final updateService = ref.read(appUpdateServiceProvider);

    // Show update snackbar when available (only once)
    if (updateAvailable && !updateService.wasDialogShown) {
      updateService.markDialogShown();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showUpdateSnackbar();
        }
      });
    }

    return MaterialApp.router(
      title: 'Attendix',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ref.watch(teamsThemeModeProvider) ?? ThemeMode.system, // TEAMS
      routerConfig: router,
      scaffoldMessengerKey: rootScaffoldMessengerKey, // PROFILE_OFFLINE
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        FlutterQuillLocalizations.delegate,
      ],
      supportedLocales: const [Locale('de', 'DE'), Locale('en', 'US')],
    );
  }

  void _showUpdateSnackbar() {
    ToastHelper.showUpdateAvailable(
      context,
      onUpdate: () {
        ref.read(appUpdateServiceProvider).applyUpdate();
      },
    );
  }
}
