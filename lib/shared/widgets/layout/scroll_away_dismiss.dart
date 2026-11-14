import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// PLATFORM: closes the keyboard when the focused text field is scrolled out
/// of its list (native iOS / Android).
///
/// Scrolling with the keyboard open stays possible (as in the Ionic web view,
/// see [TapOutsideToDismissKeyboard]). But once the field leaves the visible
/// part of its list, Flutter stops telling iOS where the field is, and iOS
/// keeps painting the field's blue text selection highlight at its last spot
/// over the list (seen on the member search). Dropping the focus then removes
/// the native field together with that highlight, and the keyboard no longer
/// types into a field the user can't see.
///
/// The web keeps the browser's behaviour.
class ScrollAwayDismissesKeyboard extends StatefulWidget {
  const ScrollAwayDismissesKeyboard({super.key, required this.child});

  final Widget child;

  @override
  State<ScrollAwayDismissesKeyboard> createState() => _ScrollAwayDismissesKeyboardState();
}

class _ScrollAwayDismissesKeyboardState extends State<ScrollAwayDismissesKeyboard> {
  BuildContext? _scrolling;
  bool _checkScheduled = false;

  /// Less than this share of the field still visible counts as scrolled away.
  static const double _minVisible = 0.5;

  static bool get _enabled =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);

  // Also momentum after the finger lifts and jumps (no drag details): a
  // field only ever loses the focus when it is out of view.
  bool _onScroll(ScrollUpdateNotification n) {
    if (!_enabled) return false;
    _scrolling = n.context;
    // The notification comes before layout: check the new positions after
    // the frame, once per frame.
    if (!_checkScheduled) {
      _checkScheduled = true;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _checkScheduled = false;
        final scrolling = _scrolling;
        _scrolling = null;
        if (mounted && scrolling != null) _check(scrolling);
      });
    }
    return false;
  }

  void _check(BuildContext scrolling) {
    final focus = FocusManager.instance.primaryFocus;
    final focusContext = focus?.context;
    if (focus == null || focusContext == null || !focusContext.mounted) return;
    // Only text fields (the focus node sits in their EditableText).
    if (focusContext.findAncestorStateOfType<EditableTextState>() == null) return;
    if (!scrolling.mounted) return;
    // A field's own text scrolling (long text, multi line) is not "away".
    if (scrolling.findAncestorWidgetOfExactType<EditableText>() != null) return;

    final field = focusContext.findRenderObject();
    final viewport = scrolling.findRenderObject();
    if (field is! RenderBox || viewport is! RenderBox) return;
    if (!field.attached || !viewport.attached || !field.hasSize || !viewport.hasSize) return;
    // Only a field inside the list that scrolls moves with it.
    if (!_isDescendant(field, viewport)) return;

    final fieldRect = MatrixUtils.transformRect(field.getTransformTo(null), Offset.zero & field.size);
    final viewRect = MatrixUtils.transformRect(viewport.getTransformTo(null), Offset.zero & viewport.size);
    if (fieldRect.height <= 0) return;
    final visible = fieldRect.intersect(viewRect);
    final visibleShare = (visible.width <= 0 || visible.height <= 0) ? 0.0 : visible.height / fieldRect.height;
    if (visibleShare < _minVisible) focus.unfocus();
  }

  static bool _isDescendant(RenderObject child, RenderObject ancestor) {
    RenderObject? node = child.parent;
    while (node != null) {
      if (identical(node, ancestor)) return true;
      node = node.parent;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollUpdateNotification>(
      onNotification: _onScroll,
      child: widget.child,
    );
  }
}
