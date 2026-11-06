import 'package:flutter/widgets.dart';

/// Anchor of the system share sheet. On the iPad share_plus shows a popover
/// and fails without a non-empty `sharePositionOrigin`
/// (FPPSharePlusPlugin.m); Ionic `navigator.share` opens it anyway.
///
/// Uses the render box of [context] (the tapped button or the page) and
/// otherwise the middle of the screen, so callers without a widget (file
/// exports from services) work on the iPad too. iPhone and Android ignore it.
Rect shareOriginFor([BuildContext? context]) {
  if (context != null && context.mounted) {
    final box = context.findRenderObject();
    if (box is RenderBox && box.attached && box.hasSize && !box.size.isEmpty) {
      return box.localToGlobal(Offset.zero) & box.size;
    }
  }
  final views = WidgetsBinding.instance.platformDispatcher.views;
  if (views.isNotEmpty) {
    final view = views.first;
    final size = view.physicalSize / view.devicePixelRatio;
    if (!size.isEmpty) {
      return Rect.fromCenter(center: size.center(Offset.zero), width: 1, height: 1);
    }
  }
  return const Rect.fromLTWH(0, 0, 1, 1);
}
