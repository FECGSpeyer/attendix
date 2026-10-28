import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';

/// An info row that can be tapped to edit the value.
/// Used for inline-editing in detail pages.
class EditableInfoRow extends StatelessWidget {
  const EditableInfoRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
    this.onEdit,
    this.editable = false,
    this.highlight = false,
    this.highlightColor,
    this.subtitle,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final bool editable;
  final bool highlight;
  final Color? highlightColor;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final effectiveHighlightColor = highlightColor ?? AppColors.warning;

    return InkWell(
      onTap: editable ? onEdit : onTap,
      borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: AppDimensions.paddingS,
          horizontal: AppDimensions.paddingXS,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: highlight
                    ? effectiveHighlightColor.withValues(alpha: 0.1)
                    : AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 20,
                color: highlight ? effectiveHighlightColor : AppColors.primary,
              ),
            ),
            const SizedBox(width: AppDimensions.paddingM),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: highlight ? effectiveHighlightColor : AppColors.medium,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 15,
                      color: highlight ? effectiveHighlightColor : null,
                      fontWeight: highlight ? FontWeight.w500 : null,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.medium,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (onTap != null && !editable)
              const Icon(Icons.chevron_right, color: AppColors.medium),
            if (editable)
              Icon(
                Icons.edit,
                size: 18,
                color: AppColors.primary.withValues(alpha: 0.6),
              ),
          ],
        ),
      ),
    );
  }
}

/// A read-only info row (non-editable version).
/// For display-only fields or when editing is not permitted.
class InfoRow extends StatelessWidget {
  const InfoRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
    this.highlight = false,
    this.highlightColor,
    this.subtitle,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;
  final bool highlight;
  final Color? highlightColor;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return EditableInfoRow(
      icon: icon,
      label: label,
      value: value,
      onTap: onTap,
      highlight: highlight,
      highlightColor: highlightColor,
      subtitle: subtitle,
      editable: false,
    );
  }
}

/// A toggle row for boolean values with inline switch.
class EditableToggleRow extends StatelessWidget {
  const EditableToggleRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.onChanged,
    this.editable = false,
    this.subtitle,
  });

  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool editable;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: AppDimensions.paddingXS,
        horizontal: AppDimensions.paddingXS,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 20,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: AppDimensions.paddingM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.medium,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.medium,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: editable ? onChanged : null,
            activeColor: AppColors.success,
          ),
        ],
      ),
    );
  }
}
