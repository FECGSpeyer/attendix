import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart'; // IOS_LOOK

const appStoreUrl = 'https://apps.apple.com/app/attendix/id6771119302';
const playStoreUrl = 'https://play.google.com/store/apps/details?id=io.stephanus.attendix';

/// `/app` (Ionic `app-redirect`): sends mobile browsers to the matching store
/// and shows both store buttons on desktop. Inside the installed app it falls
/// back to the normal login flow.
class AppRedirectPage extends StatefulWidget {
  const AppRedirectPage({super.key});

  @override
  State<AppRedirectPage> createState() => _AppRedirectPageState();
}

class _AppRedirectPageState extends State<AppRedirectPage> {
  bool _showLanding = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _redirect());
  }

  void _redirect() {
    if (!mounted) return;
    if (!kIsWeb) {
      context.go('/login');
      return;
    }
    // On web the target platform is derived from the browser user agent
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        _open(appStoreUrl);
      case TargetPlatform.android:
        _open(playStoreUrl);
      default:
        setState(() => _showLanding = true);
    }
  }

  Future<void> _open(String url) async {
    try {
      await launchUrl(Uri.parse(url), webOnlyWindowName: '_self');
    } catch (_) {
      if (mounted) setState(() => _showLanding = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_showLanding) {
      return const Scaffold(body: Center(child: AppSpinner()));
    }
    // UX_SONGS_SELF: Ionic `.landing`: top aligned (48px), max 420px, 96px
    // logo (radius 22), h1 28px semibold, medium text, light block buttons.
    final buttonStyle = ElevatedButton.styleFrom(
      elevation: 0,
      backgroundColor: AppColors.light,
      foregroundColor: Colors.black,
      minimumSize: const Size.fromHeight(44),
    );
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 48),
                  Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: Image.asset(
                        'assets/icons/app_icon.png',
                        width: 96,
                        height: 96,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.event_available, size: 96),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Attendix',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.l10n.appRedirectLoadApp,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.medium),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    style: buttonStyle,
                    onPressed: () => _open(appStoreUrl),
                    icon: const Icon(Icons.apple),
                    label: const Text('App Store'),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    style: buttonStyle,
                    onPressed: () => _open(playStoreUrl),
                    icon: const Icon(Icons.shop),
                    label: const Text('Google Play'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
