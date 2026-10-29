import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import 'ion_badge_text.dart'; // PARITY_R8
import '../../../l10n/l10n.dart';

/// A badge that displays a percentage value with color coding
/// - Green (success): >= 75%
/// - Yellow (warning): >= 50%
/// - Red (danger): < 50%
class PercentageBadge extends StatelessWidget {
  const PercentageBadge({
    super.key,
    required this.percentage,
    this.showBackground = true,
    this.compact = false,
    this.fontSize,
    this.showPrefix = false,
  });

  /// The percentage value (0-100)
  final double percentage;

  /// Whether to show the colored background
  final bool showBackground;

  /// Use compact sizing
  final bool compact;

  /// Custom font size
  final double? fontSize;

  /// Show "Ø" prefix before percentage
  final bool showPrefix;

  Color get _color {
    if (percentage >= 75) return AppColors.success;
    if (percentage >= 50) return AppColors.warning;
    return AppColors.danger;
  }

  @override
  Widget build(BuildContext context) {
    final effectiveFontSize = fontSize ?? (compact ? 12.0 : 14.0);

    final text = showPrefix
        ? 'Ø ${percentage.round()}%'
        : '${percentage.round()}%';

    if (!showBackground) {
      return Text(
        text,
        style: ionBadgeFont(TextStyle(
          color: _color,
          fontSize: effectiveFontSize,
          fontWeight: FontWeight.bold,
        )), // PARITY_R8
      );
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? AppDimensions.paddingS : AppDimensions.paddingM,
        vertical: compact ? AppDimensions.paddingXS : AppDimensions.paddingS,
      ),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
      ),
      child: Text(
        text,
        style: ionBadgeFont(TextStyle(
          color: _color,
          fontSize: effectiveFontSize,
          fontWeight: FontWeight.bold,
        )), // PARITY_R8
      ),
    );
  }
}

/// A large percentage badge for display in cards/headers
class LargePercentageBadge extends StatelessWidget {
  const LargePercentageBadge({
    super.key,
    required this.percentage,
    this.size = 80,
    this.showLabel = true,
    this.label,
  });

  final double percentage;
  final double size;
  final bool showLabel;
  final String? label;

  Color get _color {
    if (percentage >= 75) return AppColors.success;
    if (percentage >= 50) return AppColors.warning;
    return AppColors.danger;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Theme.of(context).cardColor,
            boxShadow: [
              BoxShadow(
                color: _color.withValues(alpha: 0.3),
                blurRadius: 12,
                spreadRadius: 2,
              ),
            ],
            border: Border.all(
              color: _color.withValues(alpha: 0.5),
              width: 3,
            ),
          ),
          child: Center(
            child: Text(
              '${percentage.round()}%',
              style: TextStyle(
                fontSize: size * 0.28,
                fontWeight: FontWeight.bold,
                color: _color,
              ),
            ),
          ),
        ),
        if (showLabel) ...[
          const SizedBox(height: AppDimensions.paddingS),
          Text(
            label ?? context.l10n.peopleAttendance,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.medium,
            ),
          ),
        ],
      ],
    );
  }
}
