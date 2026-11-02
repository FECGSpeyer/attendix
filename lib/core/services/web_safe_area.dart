import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'web_safe_area_stub.dart'
    if (dart.library.js_interop) 'web_safe_area_web.dart' as impl;

/// WEB_SAFE_AREA: safe area (home indicator, notch) for the web app.
///
/// Flutter 3.47 web always reports `MediaQuery.padding` as zero and writes its
/// own viewport meta tag without `viewport-fit=cover`, so the browser reports
/// no `env(safe-area-inset-*)` either. On the iPhone home screen web app the
/// tab bar therefore sat right on the home indicator, unlike the native app.
/// Like the Ionic PWA (`viewport-fit=cover` + `env(safe-area-inset-*)`), the
/// web build opts into a full-bleed viewport and hands the browser's insets
/// to the app as MediaQuery padding, so `SafeArea` and the tab bars work as on
/// native.

/// Sets `viewport-fit=cover` and starts tracking the browser's insets.
/// Call once before `runApp`. Does nothing outside the web.
void initWebSafeArea() {
  if (kIsWeb) impl.initWebSafeArea();
}

/// Adds the browser's safe area insets to the MediaQuery of [child] (web
/// only). Each side takes the larger of Flutter's own padding and the
/// browser's inset, so it never counts an inset twice should a later Flutter
/// version report it itself.
class WebSafeArea extends StatelessWidget {
  const WebSafeArea({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return child;
    return ValueListenableBuilder<EdgeInsets>(
      valueListenable: impl.webSafeAreaInsets,
      child: child,
      builder: (context, insets, child) {
        if (insets == EdgeInsets.zero) return child!;
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: applyWebSafeArea(mq, insets),
          child: child!,
        );
      },
    );
  }
}

/// [mq] with the browser [insets] merged into `viewPadding` and `padding`
/// (`padding` = `viewPadding` minus what the keyboard covers, as on native).
@visibleForTesting
MediaQueryData applyWebSafeArea(MediaQueryData mq, EdgeInsets insets) {
  EdgeInsets max(EdgeInsets a, EdgeInsets b) => EdgeInsets.fromLTRB(
        a.left > b.left ? a.left : b.left,
        a.top > b.top ? a.top : b.top,
        a.right > b.right ? a.right : b.right,
        a.bottom > b.bottom ? a.bottom : b.bottom,
      );
  final viewPadding = max(mq.viewPadding, insets);
  final keyboard = mq.viewInsets;
  return mq.copyWith(
    viewPadding: viewPadding,
    padding: EdgeInsets.fromLTRB(
      (viewPadding.left - keyboard.left).clamp(0.0, double.infinity),
      (viewPadding.top - keyboard.top).clamp(0.0, double.infinity),
      (viewPadding.right - keyboard.right).clamp(0.0, double.infinity),
      (viewPadding.bottom - keyboard.bottom).clamp(0.0, double.infinity),
    ),
  );
}
