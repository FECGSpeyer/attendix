import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Closes the surrounding route when Escape is pressed (Mac, iPad keyboard,
/// web). For read-only full-screen viewers (PDF, Ablaufplan): forms should
/// not use it, Escape would throw away the input.
///
/// Uses `maybePop`, so a [PopScope] on the page can still veto. The child is
/// wrapped in an autofocus [Focus] so the key reaches it right after the
/// route opens, without a click into the page first.
class EscapeToClose extends StatelessWidget {
  final Widget child;

  const EscapeToClose({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.of(context).maybePop(),
      },
      child: Focus(autofocus: true, child: child),
    );
  }
}
