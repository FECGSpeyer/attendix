import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:web/web.dart' as web;

final ValueNotifier<EdgeInsets> _insets = ValueNotifier(EdgeInsets.zero);

/// The browser's `env(safe-area-inset-*)` in logical (CSS) pixels.
final ValueListenable<EdgeInsets> webSafeAreaInsets = _insets;

web.HTMLElement? _probe;

void initWebSafeArea() {
  if (_probe != null) return;
  try {
    _enableViewportFitCover();

    // Hidden element whose padding is the safe area: the browser resolves
    // `env()` into pixels, read back with getComputedStyle.
    final probe = web.document.createElement('div') as web.HTMLElement;
    probe.setAttribute('aria-hidden', 'true');
    probe.style.cssText = 'position:fixed;top:0;left:0;width:0;height:0;'
        'visibility:hidden;pointer-events:none;'
        'padding:env(safe-area-inset-top,0px) env(safe-area-inset-right,0px) '
        'env(safe-area-inset-bottom,0px) env(safe-area-inset-left,0px);';
    web.document.body?.appendChild(probe);
    _probe = probe;

    void update(web.Event _) => _measure();
    web.window.addEventListener('resize', update.toJS);
    web.window.addEventListener('orientationchange', update.toJS);
    web.window.visualViewport?.addEventListener('resize', update.toJS);
    // The insets change without a window resize when WebKit applies the new
    // viewport-fit, and when Safari's toolbar collapses.
    web.ResizeObserver(
      ((JSArray<web.ResizeObserverEntry> _, web.ResizeObserver __) =>
          _measure()).toJS,
    ).observe(probe, web.ResizeObserverOptions(box: 'border-box'));

    _measure();
    // WebKit applies a changed viewport meta tag asynchronously.
    Timer(const Duration(milliseconds: 300), _measure);
    Timer(const Duration(seconds: 1), _measure);
  } catch (_) {
    // Not fatal: the app then simply has no safe area padding, as before.
  }
}

/// Flutter replaces every viewport meta tag with its own (without
/// `viewport-fit`) when the engine starts; add `viewport-fit=cover` to it so
/// the browser reports the safe area insets (same as the Ionic PWA).
void _enableViewportFitCover() {
  final metas = web.document.head?.querySelectorAll('meta[name="viewport"]');
  if (metas == null || metas.length == 0) {
    final meta = web.document.createElement('meta') as web.HTMLMetaElement;
    meta.name = 'viewport';
    meta.content = 'width=device-width, initial-scale=1.0, maximum-scale=5.0, '
        'viewport-fit=cover';
    web.document.head?.appendChild(meta);
    return;
  }
  for (var i = 0; i < metas.length; i++) {
    final meta = metas.item(i) as web.HTMLMetaElement;
    if (!meta.content.contains('viewport-fit')) {
      meta.content = '${meta.content}, viewport-fit=cover';
    }
  }
}

void _measure() {
  final probe = _probe;
  if (probe == null) return;
  try {
    final style = web.window.getComputedStyle(probe);
    double px(String property) =>
        double.tryParse(
          style.getPropertyValue(property).replaceAll('px', '').trim(),
        ) ??
        0;
    final insets = EdgeInsets.fromLTRB(
      px('padding-left'),
      px('padding-top'),
      px('padding-right'),
      px('padding-bottom'),
    );
    if (insets != _insets.value) _insets.value = insets;
  } catch (_) {}
}
