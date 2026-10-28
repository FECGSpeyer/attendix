import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../features/public_links/presentation/pages/app_redirect_page.dart'
    show appStoreUrl, playStoreUrl;
import 'native_app_ad_storage.dart';
import '../../../l10n/l10n.dart';
import '../adaptive/adaptive.dart'; // IOS_LOOK

/// LINKS_STARTUP: set on a fresh sign-in (Ionic `listenToAuthChanges`
/// SIGNED_IN → `showNativeAppAd`); consumed once the app shell is visible.
final nativeAppAdPendingProvider = StateProvider<bool>((ref) => false);

/// Store target of the ad, chosen by the user agent like Ionic.
@immutable
class NativeAppAdStore {
  const NativeAppAdStore({required this.name, required this.url});

  factory NativeAppAdStore.forUserAgent({required bool isIos}) => isIos
      ? const NativeAppAdStore(name: 'App Store', url: appStoreUrl)
      : const NativeAppAdStore(name: 'Play Store', url: playStoreUrl);

  final String name;
  final String url;
}

/// The Ionic alert "Attendix als App verfügbar!" (de.json `app.nativeAd`).
Future<void> showNativeAppAdDialog(
  BuildContext context,
  NativeAppAdStore store,
) {
  return showAppDialog<void>(
    context: context,
    builder: (dialogContext) => AppAlertDialog(
      title: Text(dialogContext.l10n.appNativeAdHeader),
      content: Text(dialogContext.l10n.appNativeAdMessage(store.name)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(dialogContext.l10n.svcLater),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(dialogContext).pop();
            try {
              launchUrl(Uri.parse(store.url),
                  mode: LaunchMode.externalApplication);
            } catch (_) {}
          },
          child: Text(dialogContext.l10n.appNativeAdGoTo(store.name)),
        ),
      ],
    ),
  );
}

/// Wraps the app shell and shows the native app ad once after the first web
/// sign-in (Ionic: web only, `localStorage native_app_ad_shown`).
class NativeAppAdGate extends ConsumerStatefulWidget {
  const NativeAppAdGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<NativeAppAdGate> createState() => _NativeAppAdGateState();
}

class _NativeAppAdGateState extends ConsumerState<NativeAppAdGate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShow());
  }

  void _maybeShow() {
    if (!mounted || !kIsWeb) return;
    if (!ref.read(nativeAppAdPendingProvider)) return;
    ref.read(nativeAppAdPendingProvider.notifier).state = false;
    if (nativeAppAdWasShown()) return;
    markNativeAppAdShown();
    showNativeAppAdDialog(
      context,
      NativeAppAdStore.forUserAgent(isIos: isIosUserAgent()),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(nativeAppAdPendingProvider, (_, pending) {
      if (pending) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShow());
      }
    });
    return widget.child;
  }
}
