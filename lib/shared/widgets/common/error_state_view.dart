import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/l10n.dart';
import '../../../core/utils/error_message.dart';
import '../adaptive/ion_button_label.dart';

/// Full-page error state: icon, friendly message, retry button.
///
/// Never shows raw exceptions: pass the thrown object as [error] and it is
/// turned into a user-facing text via [friendlyErrorMessage] (network errors
/// become "Keine Internetverbindung vorhanden"). Content is padded and capped
/// at [AppDimensions.maxContentWidth] so it stays readable on desktop.
class ErrorStateView extends StatelessWidget {
  const ErrorStateView({
    super.key,
    this.error,
    this.title,
    this.message,
    this.onRetry,
    this.secondaryLabel,
    this.onSecondary,
    this.icon,
  });

  /// The thrown object; mapped to a friendly text when [message] is null.
  final Object? error;

  /// Optional headline (e.g. "Inhalt konnte nicht geladen werden.").
  final String? title;

  /// Explicit text; overrides the text derived from [error].
  final String? message;

  /// Shows an "Erneut versuchen" button when set.
  final VoidCallback? onRetry;

  /// Optional second action (e.g. "Zur Anmeldung").
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final offline = isNetworkError(error);
    final text = message ??
        (error != null ? friendlyErrorMessage(error, l10n) : null);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimensions.paddingL),
        child: ConstrainedBox(
          constraints:
              const BoxConstraints(maxWidth: AppDimensions.maxContentWidth),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon ?? (offline ? Icons.cloud_off_outlined : Icons.error_outline),
                size: 56,
                color: offline ? AppColors.medium : AppColors.danger,
              ),
              const SizedBox(height: AppDimensions.paddingM),
              if (title != null) ...[
                Text(
                  title!,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppDimensions.paddingS),
              ],
              if (text != null && text != title)
                Text(
                  text,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: title != null ? AppColors.medium : null,
                  ),
                  textAlign: TextAlign.center,
                ),
              if (onRetry != null) ...[
                const SizedBox(height: AppDimensions.paddingL),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: IonButtonLabel(l10n.messagesRetry),
                ),
              ],
              if (onSecondary != null && secondaryLabel != null) ...[
                const SizedBox(height: AppDimensions.paddingS),
                TextButton(
                  onPressed: onSecondary,
                  child: IonButtonLabel(secondaryLabel!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
