import 'package:flutter/material.dart';
import 'package:attendix/core/theme/app_icons.dart';

import '../../../core/theme/design_theme.dart';
import '../../../l10n/l10n.dart';

/// Groups header actions in an [AppBar].
class ToolbarButtonGroup extends StatelessWidget {
  const ToolbarButtonGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    return Row(mainAxisSize: MainAxisSize.min, children: children);
  }
}

/// Close button for a modal header.
class IonCloseButton extends StatelessWidget {
  const IonCloseButton({super.key, this.onPressed, this.tooltip});

  final VoidCallback? onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final onTap = onPressed ?? () => Navigator.of(context).maybePop();
    return IconButton(
      icon: Icon(AppIcons.close),
      tooltip: tooltip ?? context.l10n.commonClose,
      onPressed: onTap,
    );
  }
}

/// Height of a modal sheet header toolbar.
const double kIonModalToolbarHeight = 64;

/// Default modal header title font size.
const double kIonTitleFontSize = 17;

/// `toolbarHeight` for an [AppBar] inside a sheet / modal.
double? ionModalToolbarHeight(BuildContext context) =>
    Theme.of(context).platform == TargetPlatform.iOS ? kIonModalToolbarHeight : null;

/// Header of a sheet / modal: centred semibold title, optional start button,
/// end button (default: [IonCloseButton]) and a 1px divider below.
class IonModalHeader extends StatelessWidget implements PreferredSizeWidget {
  const IonModalHeader({
    super.key,
    required this.title,
    this.leading,
    this.trailing,
    this.showClose = true,
    this.onClose,
    this.showDivider = true,
  });

  final Widget title;
  final Widget? leading;
  final Widget? trailing;
  final bool showClose;
  final VoidCallback? onClose;
  final bool showDivider;

  @override
  Size get preferredSize => const Size.fromHeight(kIonModalToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final rd = context.rd;
    final end = trailing ??
        (showClose ? IonCloseButton(onPressed: onClose) : null);
    return Container(
      height: kIonModalToolbarHeight,
      decoration: BoxDecoration(
        color: rd.bg,
        border: showDivider ? Border(bottom: BorderSide(color: rd.line)) : null,
      ),
      child: NavigationToolbar(
        leading: leading,
        trailing: end,
        middle: DefaultTextStyle.merge(
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: rd.text),
          child: title,
        ),
        centerMiddle: true,
        middleSpacing: 8,
      ),
    );
  }
}
