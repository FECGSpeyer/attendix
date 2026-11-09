import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// KEYBOARD_TAB: the iPhone/iPad app on a Mac (and an iPad with a hardware
/// keyboard) never passes Tab to Flutter: UIKit's own keyboard focus
/// navigation takes it first, so Tab did not move from E-Mail to Passwort.
/// The FlutterViewController in ios/Runner/AppDelegate.swift claims Tab and
/// Shift-Tab with priority over the system and reports them on this channel;
/// they become the same focus intents Flutter uses for Tab everywhere else.
const keyboardFocusChannel = MethodChannel('de.attendix/keyboard_focus');

/// Listens for the native Tab / Shift-Tab reports (iOS only, no-op elsewhere).
void initKeyboardFocusBridge() {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return;
  keyboardFocusChannel.setMethodCallHandler(handleKeyboardFocusCall);
}

/// Moves the focus like Flutter's own Tab handling: through the focused
/// widget's Actions (dialogs and traversal groups keep their rules), falling
/// back to plain traversal when nothing handles the intent.
@visibleForTesting
Future<bool> handleKeyboardFocusCall(MethodCall call) async {
  final forward = switch (call.method) {
    'next' => true,
    'previous' => false,
    _ => null,
  };
  if (forward == null) return false;
  final node = FocusManager.instance.primaryFocus;
  final context = node?.context;
  if (node == null || context == null) return false;
  final Intent intent =
      forward ? const NextFocusIntent() : const PreviousFocusIntent();
  if (Actions.maybeFind<Intent>(context, intent: intent) != null) {
    Actions.invoke(context, intent);
    return true;
  }
  return forward ? node.nextFocus() : node.previousFocus();
}
