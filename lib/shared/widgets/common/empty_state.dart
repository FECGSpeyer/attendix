import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../adaptive/ion_button_label.dart';

/// Empty state size variants
enum EmptyStateSize {
  /// Small - for inline/card empty states
  small,

  /// Medium - default size
  medium,

  /// Large - for full page empty states
  large,
}

/// Generic empty state widget with icon, title, subtitle and optional action
/// Includes fade-in animation and optional icon animation
class EmptyStateWidget extends StatefulWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onAction;
  final String? actionLabel;

  /// Custom widget to show instead of icon (e.g., Lottie animation, custom illustration)
  final Widget? customIllustration;

  /// Whether to animate the icon with a subtle pulse effect
  final bool animateIcon;

  /// Size variant
  final EmptyStateSize size;

  /// Whether to animate the entrance
  final bool animateEntrance;

  const EmptyStateWidget({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onAction,
    this.actionLabel,
    this.customIllustration,
    this.animateIcon = true,
    this.size = EmptyStateSize.medium,
    this.animateEntrance = true,
  });

  @override
  State<EmptyStateWidget> createState() => _EmptyStateWidgetState();
}

class _EmptyStateWidgetState extends State<EmptyStateWidget>
    with TickerProviderStateMixin {
  late AnimationController _entranceController;
  late AnimationController _iconController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _iconScaleAnimation;

  @override
  void initState() {
    super.initState();

    // Entrance animation
    _entranceController = AnimationController(
      duration: AppDurations.slow,
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOutCubic,
    ));

    // Icon pulse animation
    _iconController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _iconScaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.08)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.08, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 50,
      ),
    ]).animate(_iconController);

    if (widget.animateEntrance) {
      _entranceController.forward();
    } else {
      _entranceController.value = 1.0;
    }

    if (widget.animateIcon) {
      _iconController.repeat();
    }
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _iconController.dispose();
    super.dispose();
  }

  double get _iconSize {
    switch (widget.size) {
      case EmptyStateSize.small:
        return 48;
      case EmptyStateSize.medium:
        return 64;
      case EmptyStateSize.large:
        return 80;
    }
  }

  EdgeInsets get _padding {
    switch (widget.size) {
      case EmptyStateSize.small:
        return const EdgeInsets.all(16.0);
      case EmptyStateSize.medium:
        return const EdgeInsets.all(32.0);
      case EmptyStateSize.large:
        return const EdgeInsets.all(48.0);
    }
  }

  TextStyle? _titleStyle(ThemeData theme) {
    switch (widget.size) {
      case EmptyStateSize.small:
        return theme.textTheme.titleMedium?.copyWith(
          color: theme.colorScheme.onSurface,
        );
      case EmptyStateSize.medium:
        return theme.textTheme.titleLarge?.copyWith(
          color: theme.colorScheme.onSurface,
        );
      case EmptyStateSize.large:
        return theme.textTheme.headlineSmall?.copyWith(
          color: theme.colorScheme.onSurface,
        );
    }
  }

  TextStyle? _subtitleStyle(ThemeData theme) {
    switch (widget.size) {
      case EmptyStateSize.small:
        return theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        );
      case EmptyStateSize.medium:
        return theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        );
      case EmptyStateSize.large:
        return theme.textTheme.bodyLarge?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget content = Center(
      child: Padding(
        padding: _padding,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon or custom illustration
            if (widget.customIllustration != null)
              widget.customIllustration!
            else
              AnimatedBuilder(
                animation: _iconController,
                builder: (context, child) {
                  return Transform.scale(
                    scale: widget.animateIcon ? _iconScaleAnimation.value : 1.0,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        widget.icon,
                        size: _iconSize,
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  );
                },
              ),

            SizedBox(height: widget.size == EmptyStateSize.small ? 12 : 16),

            // Title
            Text(
              widget.title,
              style: _titleStyle(theme),
              textAlign: TextAlign.center,
            ),

            // Subtitle
            if (widget.subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                widget.subtitle!,
                style: _subtitleStyle(theme),
                textAlign: TextAlign.center,
              ),
            ],

            // Action button
            if (widget.onAction != null) ...[
              SizedBox(height: widget.size == EmptyStateSize.small ? 16 : 24),
              FilledButton.tonal(
                onPressed: widget.onAction,
                child: IonButtonLabel(widget.actionLabel ?? 'Action'),
              ),
            ],
          ],
        ),
      ),
    );

    // Wrap with entrance animation
    if (widget.animateEntrance) {
      return FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: content,
        ),
      );
    }

    return content;
  }
}

/// Compact inline empty state for cards or sections
class InlineEmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final VoidCallback? onAction;
  final String? actionLabel;

  const InlineEmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.onAction,
    this.actionLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 20,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(width: 12),
          Text(
            message,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (onAction != null) ...[
            const SizedBox(width: 12),
            TextButton(
              onPressed: onAction,
              child: IonButtonLabel(actionLabel ?? 'Action'),
            ),
          ],
        ],
      ),
    );
  }
}
