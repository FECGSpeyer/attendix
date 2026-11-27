import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/design_theme.dart';
import '../../../../l10n/l10n.dart';

/// Design-system buttons, links, and sub-page back navigation helpers.

/// Filled primary button, 48 px high.
class RdPrimaryButton extends StatelessWidget {
  const RdPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.color,
    this.foreground,
    this.height = 48,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? color;
  final Color? foreground;
  final double height;

  /// Shows a spinner instead of [icon] and blocks taps (e.g. while a PDF
  /// is built).
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    return SizedBox(
      height: height,
      child: FilledButton(
        onPressed: loading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: color ?? p.primary,
          foregroundColor: foreground ?? p.onPrimary,
          disabledBackgroundColor: p.track,
          disabledForegroundColor: p.text2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(p.buttonRadius),
          ),
          // Theme font (web font on the PWA), only size and weight change.
          textStyle: (Theme.of(context).textTheme.labelLarge ?? const TextStyle())
              .copyWith(fontSize: 16, fontWeight: FontWeight.w600),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loading) ...[
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: p.text2),
              ),
              const SizedBox(width: 10),
            ] else if (icon != null) ...[
              Icon(icon, size: 20),
              const SizedBox(width: 8),
            ],
            Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
          ],
        ),
      ),
    );
  }
}

/// Outlined button, 48 px high ("Abmelden" while not chosen).
class RdOutlineButton extends StatelessWidget {
  const RdOutlineButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.color,
    this.height = 48,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  /// Text and border colour (default: secondary text / hairline).
  final Color? color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final fg = color ?? p.text;
    return SizedBox(
      height: height,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: fg,
          backgroundColor: p.surface,
          side: BorderSide(color: color ?? p.offBorder, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(p.buttonRadius),
          ),
          // Theme font (web font on the PWA), only size and weight change.
          textStyle: (Theme.of(context).textTheme.labelLarge ?? const TextStyle())
              .copyWith(fontSize: 16, fontWeight: FontWeight.w600),
          padding: const EdgeInsets.symmetric(horizontal: 12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: 6)],
            Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
          ],
        ),
      ),
    );
  }
}

/// Round 44 × 44 icon button on the page background (bell).
class RdCircleButton extends StatelessWidget {
  const RdCircleButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.dot = false,
    this.primary = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  /// Red dot (unread notifications).
  final bool dot;

  /// Filled in the primary colour: the one "+" of a list on desktop.
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: primary ? p.primary : p.surface,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(icon, size: 22, color: primary ? p.onPrimary : p.text),
                if (dot)
                  Positioned(
                    top: 9,
                    right: 10,
                    child: Container(
                      width: 11,
                      height: 11,
                      decoration: BoxDecoration(
                        color: p.absent,
                        shape: BoxShape.circle,
                        border: Border.all(color: p.surface, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// White pill with icon and label ("Abwesend", "Dateien").
class RdPillButton extends StatelessWidget {
  const RdPillButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.semanticLabel,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  /// Longer label for screen readers ("Dateien der Gruppe").
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: semanticLabel != null,
      child: Material(
        color: p.surface,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onPressed,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 18, color: p.link),
                  const SizedBox(width: 6),
                  Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: p.link)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Text action in the top bar ("Bearbeiten").
class RdTextLink extends StatelessWidget {
  const RdTextLink({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Center(
              widthFactor: 1,
              child: Text(label, style: TextStyle(fontSize: 17, color: p.link)),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Filter" (with the number of active filters) above a list; opens the
/// "Sortieren & Filtern" sheet.
class RdFilterLink extends StatelessWidget {
  const RdFilterLink({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.tune, size: 18, color: p.link),
                const SizedBox(width: 6),
                Text(label, style: TextStyle(fontSize: 15, color: p.link)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Whether the page on top was pushed (`context.push`) rather than reached
/// by its URL or `context.go`.
bool rdIsPushed(BuildContext context) =>
    GoRouter.of(context).routerDelegate.currentConfiguration.lastOrNull is ImperativeRouteMatch;

/// Label of the back link on a page that is opened from several places:
/// the opener names itself in `?from=` (heute, ich, werke), so the link
/// says where it really leads; without it [fallback] (the parent route).
String rdBackLabel(BuildContext context, {required String fallback}) {
  final l10n = context.l10n;
  // Shown outside a route (a sheet, a split pane): the parent route.
  final String? from;
  try {
    from = GoRouterState.of(context).uri.queryParameters['from'];
  } on GoError {
    return fallback;
  }
  return switch (from) {
    'heute' => l10n.redesignTabToday,
    'ich' => l10n.redesignTabMe,
    'werke' => l10n.redesignTabWorks,
    _ => fallback,
  };
}

/// Back from a sub page whose parent route is not where it is opened from
/// (Werkhistorie under Ich › Verwaltung, opened from the Werke tab): pops
/// when the page was pushed, otherwise goes to [fallback]. Opened by its
/// URL (reload, link), the router builds the parent routes beneath it, so
/// `canPop` alone would land there instead of on [fallback].
void rdBack(BuildContext context, String fallback) {
  final router = GoRouter.of(context);
  if (rdIsPushed(context) && router.canPop()) {
    router.pop();
  } else {
    router.go(fallback);
  }
}

/// Back link of a sub page ("‹ Ich").
class RdBackLink extends StatelessWidget {
  const RdBackLink({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    return Align(
      alignment: Alignment.centerLeft,
      child: Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.chevron_left, size: 26, color: p.link),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 17, color: p.link),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
