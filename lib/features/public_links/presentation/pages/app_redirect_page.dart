import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
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
    return Scaffold(
      body: Center(
        child: !_showLanding
            ? const AppSpinner()
            : ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Image.asset(
                        'assets/icons/app_icon.png',
                        height: 96,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.event_available, size: 96),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Attendix',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        context.l10n.appRedirectLoadApp,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () => _open(appStoreUrl),
                        icon: const Icon(Icons.apple),
                        label: const Text('App Store'),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: () => _open(playStoreUrl),
                        icon: const Icon(Icons.shop),
                        label: const Text('Google Play'),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
