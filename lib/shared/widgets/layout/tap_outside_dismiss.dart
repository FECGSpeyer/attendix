import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

/// PLATFORM: closes the keyboard when the user taps outside a text field on
/// iOS / Android, like the Ionic web view (tapping outside blurs the input).
///
/// Flutter keeps the focus on touch taps outside a field on mobile, so
/// keyboards without a return key (number pad) could not be closed at all.
/// A tap (pointer up close to its pointer down) outside every text field
/// unfocuses; a drag (scrolling) keeps the keyboard open, as in the web
/// view. Mouse/stylus and web keep Flutter's default (unfocus on down).
class TapOutsideToDismissKeyboard extends StatefulWidget {
  const TapOutsideToDismissKeyboard({super.key, required this.child});

  final Widget child;

  @override
  State<TapOutsideToDismissKeyboard> createState() =>
      _TapOutsideToDismissKeyboardState();
}

class _TapOutsideToDismissKeyboardState
    extends State<TapOutsideToDismissKeyboard> {
  PointerDownEvent? _down;

  void _onDown(EditableTextTapOutsideIntent intent) {
    final event = intent.pointerDownEvent;
    if (event.kind != PointerDeviceKind.touch || kIsWeb) {
      // Flutter's default for these cases.
      if (event.kind != PointerDeviceKind.trackpad) intent.focusNode.unfocus();
      return;
    }
    _down = event;
  }

  void _onUp(EditableTextTapUpOutsideIntent intent) {
    final down = _down;
    _down = null;
    final up = intent.pointerUpEvent;
    if (down == null || down.pointer != up.pointer) return;
    if ((up.position - down.position).distance > kTouchSlop) return;
    intent.focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Actions(
      actions: <Type, Action<Intent>>{
        EditableTextTapOutsideIntent:
            CallbackAction<EditableTextTapOutsideIntent>(
          onInvoke: (intent) {
            _onDown(intent);
            return null;
          },
        ),
        EditableTextTapUpOutsideIntent:
            CallbackAction<EditableTextTapUpOutsideIntent>(
          onInvoke: (intent) {
            _onUp(intent);
            return null;
          },
        ),
      },
      child: widget.child,
    );
  }
}
