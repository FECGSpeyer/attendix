import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/config/supabase_config.dart';
import 'core/providers/locale_provider.dart';
import 'core/providers/redesign_providers.dart';
import 'core/router/app_router.dart';
import 'core/router/legacy_url.dart';
import 'core/services/app_update_service.dart';
import 'core/services/offline_queue_service.dart';
import 'core/services/attendance_detail_cache.dart'
    show clearOfflineReadCaches, shouldClearOfflineReadCaches;
import 'core/services/public_plan_draft_storage.dart'
    show clearPublicPlanDrafts;
import 'core/services/planning_draft_store.dart' show clearPlanningDrafts;
import 'core/services/live_activity_service.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/redesign/rd_theme.dart';
import 'core/utils/toast_helper.dart';
import 'features/auth/data/auth_link_listener.dart';
import 'core/services/teams/teams_service.dart';
import 'core/services/app_icon_service.dart';
import 'core/providers/push_providers.dart';
import 'l10n/l10n.dart';
import 'shared/widgets/dialogs/ion_modal.dart';
import 'shared/widgets/adaptive/app_toolbar.dart' show IonToolbarMetrics;
import 'core/services/error_reporter.dart';
import 'core/constants/app_constants.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Like Ionic's `?ionic:mode=ios|md`: on the web `?mode=ios` forces the
  // iPhone look (and `?mode=md` the Material look) regardless of the browser.
  if (kIsWeb) applyWebModeOverride(Uri.base);

  // IOS_SHELL2: like Ionic's router, pushed sub-pages (Mehr → Werke, Hilfe,
  // Benachrichtigungen …) change the browser URL, so reload, browser back
  // and deep links work (go_router keeps the URL on push by default).
  GoRouter.optionURLReflectsImperativeAPIs = true;

  // I18N_INFRA: date symbols for every enabled language (de_DE, en_GB) and
  // the start language: stored choice -> device language -> 'de'.
  for (final lang in enabledLanguages) {
    await initializeDateFormatting(intlLocales[lang]!, null);
  }
  final initialLanguage = await loadInitialLanguage();
  // REDESIGN: "Neues Design (Beta)", Farbwelt and hell/dunkel of this device
  final initialRedesign = await loadInitialRedesignSettings();

  // Load environment variables
  try {
    await dotenv.load(fileName: '.env.app');
  } catch (e) {
    if (kDebugMode) {
      print('Warning: Could not load .env file: $e');
    }
  }

  // Error monitoring: no-op without SENTRY_DSN (tests, local builds).
  await ErrorReporter.init(
    dsn: dotenv.isInitialized ? dotenv.maybeGet('SENTRY_DSN') : null,
    release: AppConstants.appVersion,
    environment: dotenv.isInitialized ? dotenv.maybeGet('SENTRY_ENVIRONMENT') : null,
  );
  final previousOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    ErrorReporter.report(details.exception, details.stack, where: 'FlutterError');
    previousOnError?.call(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    ErrorReporter.report(error, stack, where: 'PlatformDispatcher');
    return false; // keep the default handling (console / crash)
  };

  // Initialize Supabase
  await SupabaseConfig.initialize();

  // LINKS_STARTUP: path links (/tabs/..., /open-attendance?..) → #/... so the
  // hash-based router sees them (after Supabase read auth params from the URL)
  if (kIsWeb) promoteLegacyPathToHash();
  // TEAMS: detect a Microsoft Teams tab (no-op outside an iframe / on native).
  // Not awaited (REVIEW_FIX2): a non-Teams iframe would otherwise keep the
  // app blank until the SDK timeouts; SSO/theme react once it completes.
  unawaited(TeamsService.instance.init());

  runApp(
    ProviderScope(
      overrides: [
        initialLanguageProvider.overrideWithValue(initialLanguage),
        initialRedesignSettingsProvider.overrideWithValue(initialRedesign),
      ],
      child: const AttendixApp(),
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
    // Start update listener (web: service worker; NATIVE_MISC: native store check)
    ref.read(appUpdateServiceProvider).startListening();
    // PROFILE_OFFLINE: replay queued offline attendance writes
    Future.microtask(
        () => ref.read(offlineQueueNotifierProvider.notifier).init());
    // AUTH: password-recovery / signup-confirmation links (Ionic handleAuthUrl)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // PUSH: native push listeners + token registration (no-op on the web)
      if (mounted && isNativePushPlatform) ref.read(pushBootstrapProvider);
      if (mounted) initAuthLinkHandling(ref, ref.read(routerProvider));
      // LIVE_ACTIVITY: iOS Live Activity for running Ablaufpläne (no-op elsewhere)
      if (mounted) ref.read(liveActivityBootstrapProvider);
      // REDESIGN: home screen icon of the Farbwelt (iOS; native skips a no-op)
      if (mounted) {
        unawaited(AppIconService.setIcon(ref.read(redesignSettingsProvider).appIconName));
      }
      // TEAMS: silent Microsoft SSO inside a Teams tab, once detection is done
      final teams = ref.read(teamsServiceProvider);
      unawaited(teams.init().then((_) {
        if (!mounted || !teams.isInTeams()) return;
        trySsoSignIn(
          teams: teams,
          hasSession:
              ref.read(supabaseClientProvider).auth.currentSession != null,
          go: (location) => ref.read(routerProvider).go(location),
        );
      }));
    });
  }

  @override
  Widget build(BuildContext context) {
    // SOL_FIX4: the offline queue follows the signed-in account (recount and
    // replay only that user's writes on login / logout / account switch).
    ref.listen(currentUserProvider, (previous, next) {
      if (previous?.valueOrNull?.id != next.valueOrNull?.id) {
        // SOL_FIX7: sign-out / account switch removes the offline read
        // caches (attendance detail/list, songs) of the previous account.
        if (shouldClearOfflineReadCaches(
            previous?.valueOrNull?.id, next.valueOrNull?.id)) {
          unawaited(clearOfflineReadCaches());
          // SOL_FIX12: the previous account's Ablaufplanung draft (plan id +
          // edit key) must not reach the next account.
          unawaited(clearPublicPlanDrafts(previous?.valueOrNull?.id));
          // SOL_FIX27: Ablaufplan editor drafts of the previous account.
          unawaited(clearPlanningDrafts());
        }
        unawaited(
            ref.read(offlineQueueNotifierProvider.notifier).onUserChanged());
      }
    });
    final router = ref.watch(routerProvider);
    final updateAvailable = ref.watch(appUpdateAvailableProvider);
    final updateService = ref.read(appUpdateServiceProvider);
    final locale = ref.watch(localeProvider);
    final redesign = ref.watch(redesignSettingsProvider);

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
      // REDESIGN: the new design brings its Farbwelt and hell/dunkel choice
      theme: redesign.enabled
          ? buildRdTheme(redesign.world, Brightness.light)
          : AppTheme.light,
      darkTheme: redesign.enabled
          ? buildRdTheme(redesign.world, Brightness.dark)
          : AppTheme.dark,
      themeMode: ref.watch(teamsThemeModeProvider) ??
          (redesign.enabled ? redesign.themeMode : ThemeMode.system),
      routerConfig: router,
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      // IOS_SHELL: Ionic iOS has no tooltips – hide Material tooltips (tap /
      // long-press / hover) on iOS; their semantics labels stay.
      // IOS_THEME2: Ionic md (desktop / Android) has none either.
      builder: (context, child) => TooltipVisibility(
        visible: false,
        // PARITY_R3: Ionic ion-modal sheet sizes (600 wide on desktop).
        child: IonModalTheme(
          // IOS_R4: Ionic iOS toolbar height (safe area dependent)
          child: IonToolbarMetrics(child: child ?? const SizedBox.shrink()),
        ),
      ),
      // I18N_INFRA: UI language from localeProvider (de default, en optional)
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        FlutterQuillLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
    );
  }

  void _showUpdateSnackbar() {
    // IOS_SHELL2: on iOS the tab shell shows the notice as an Ionic glass
    // toast above the tab bar (MainShell) instead of a SnackBar over the
    // page content; outside the tabs the login banner / "Update installieren"
    // row in Mehr remain (Ionic shows no toast at all).
    final messengerContext = rootScaffoldMessengerKey.currentContext;
    if (messengerContext != null &&
        Theme.of(messengerContext).platform == TargetPlatform.iOS) {
      return;
    }
    ToastHelper.showUpdateAvailable(
      rootScaffoldMessengerKey.currentState,
      onUpdate: () {
        ref.read(appUpdateServiceProvider).applyUpdate();
      },
    );
  }
}

/// Web only: `?mode=ios` / `?ionic:mode=ios` → iOS look, `md` → Material.
@visibleForTesting
TargetPlatform? webModeOverride(Uri uri) {
  final mode = (uri.queryParameters['mode'] ?? uri.queryParameters['ionic:mode'])
      ?.toLowerCase();
  return switch (mode) {
    'ios' => TargetPlatform.iOS,
    'md' => TargetPlatform.android,
    _ => null,
  };
}

/// WEB_MODE_FIX: only the look follows the override (release-safe);
/// `debugDefaultTargetPlatformOverride` throws outside debug builds.
void applyWebModeOverride(Uri uri) {
  final platform = webModeOverride(uri);
  if (platform != null) AppTheme.webLookOverride = platform;
}
