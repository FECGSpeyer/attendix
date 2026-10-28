import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/dashboard_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/services/teams/teams_service.dart'; // TEAMS
import '../../../../l10n/l10n.dart';

/// SETTINGS2: Ionic settings "📱 Attendix als App" promo card.
///
/// Like Ionic `checkAppPromo`: only on the web (not native), only for the
/// super developer until the native apps are public, dismissible
/// (`appPromoDismissed`).
class AppPromoCard extends ConsumerStatefulWidget {
  const AppPromoCard({super.key});

  static const String dismissedKey = 'appPromoDismissed';
  static const String iosUrl = 'https://apps.apple.com/app/attendix/id6771119302';
  static const String androidUrl =
      'https://play.google.com/store/apps/details?id=io.stephanus.attendix';

  @override
  ConsumerState<AppPromoCard> createState() => _AppPromoCardState();
}

class _AppPromoCardState extends ConsumerState<AppPromoCard> {
  bool _dismissed = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() => _dismissed = prefs.getBool(AppPromoCard.dismissedKey) ?? false);
      }
    } catch (_) {}
  }

  Future<void> _dismiss() async {
    setState(() => _dismissed = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(AppPromoCard.dismissedKey, true);
    } catch (_) {}
  }

  Future<void> _open(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    // TEAMS: no native-app promotion inside a Teams tab (Ionic checkAppPromo)
    if (!kIsWeb ||
        _dismissed ||
        !ref.watch(isSuperDeveloperProvider) ||
        ref.watch(isInTeamsProvider)) {
      return const SizedBox.shrink();
    }
    final platform = defaultTargetPlatform;
    final isMobile =
        platform == TargetPlatform.iOS || platform == TargetPlatform.android;
    final isIos = platform == TargetPlatform.iOS;
    const buttonStyle = ButtonStyle(
      backgroundColor: WidgetStatePropertyAll(Colors.white),
      foregroundColor: WidgetStatePropertyAll(AppColors.tertiary),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.paddingM),
      child: Card(
        color: AppColors.tertiary,
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.paddingM),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      context.l10n.settingsAsApp,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: _dismiss,
                  ),
                ],
              ),
              Text(
                context.l10n.settingsAsAppText,
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: AppDimensions.paddingM),
              if (isMobile)
                FilledButton.icon(
                  style: buttonStyle,
                  icon: Icon(isIos ? Icons.apple : Icons.shop),
                  label: Text(isIos ? context.l10n.settingsAppStore : context.l10n.settingsGooglePlay),
                  onPressed: () =>
                      _open(isIos ? AppPromoCard.iosUrl : AppPromoCard.androidUrl),
                )
              else ...[
                FilledButton.icon(
                  style: buttonStyle,
                  icon: const Icon(Icons.apple),
                  label: Text(context.l10n.settingsAppStore),
                  onPressed: () => _open(AppPromoCard.iosUrl),
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  style: buttonStyle,
                  icon: const Icon(Icons.shop),
                  label: Text(context.l10n.settingsGooglePlay),
                  onPressed: () => _open(AppPromoCard.androidUrl),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
