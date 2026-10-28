import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../shared/widgets/common/swipe_actions.dart';
import '../../../../l10n/l10n.dart';

/// SETTINGS2: Ionic type.page "Erinnerungen" (reminders modal content).
///
/// Max. 3 reminders, 0-168 hours, no duplicates, predefined 1/24/48/72 h.
class TypeRemindersEditor extends StatefulWidget {
  const TypeRemindersEditor({
    super.key,
    required this.reminders,
    required this.onChanged,
  });

  final List<int> reminders;
  final ValueChanged<List<int>> onChanged;

  static const int maxReminders = 3;
  static const List<int> predefined = [1, 24, 48, 72];

  /// Ionic `getFormattedReminder`.
  static String format(int hours) {
    final l10n = l10nWithoutContext;
    if (hours == 0) return l10n.typeSettingsSameTime;
    if (hours < 24) return l10n.typeSettingsHoursBeforeN(hours);
    return l10n.typeSettingsDaysBeforeN(hours ~/ 24);
  }

  /// Ionic `addReminder` validation. Returns the error text or null.
  static String? validate(List<int> reminders, int? hours) {
    final l10n = l10nWithoutContext;
    if (hours == null || hours < 0) {
      return l10n.typeSettingsPositiveInt;
    }
    if (hours > 168) {
      return l10n.typeSettingsValidHours;
    }
    if (reminders.contains(hours)) return l10n.typeSettingsReminderExists;
    if (reminders.length >= maxReminders) {
      return l10n.typeSettingsMax3;
    }
    return null;
  }

  @override
  State<TypeRemindersEditor> createState() => _TypeRemindersEditorState();
}

class _TypeRemindersEditorState extends State<TypeRemindersEditor> {
  final _customController = TextEditingController();

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  void _add(int? hours) {
    final error = TypeRemindersEditor.validate(widget.reminders, hours);
    if (error != null) {
      ToastHelper.showError(context, error);
      return;
    }
    widget.onChanged([...widget.reminders, hours!]..sort());
    _customController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final reminders = widget.reminders;
    final canAdd = reminders.length < TypeRemindersEditor.maxReminders;
    final small = Theme.of(context).textTheme.bodySmall;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.l10n.typeSettingsHowReminders,
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                _info(Icons.schedule,
                    _stripHtml(context.l10n.typeSettingsHowEvery5), small),
                _info(Icons.calculate_outlined,
                    _stripHtml(context.l10n.typeSettingsHowRemaining),
                    small),
                _info(Icons.notifications_outlined,
                    _stripHtml(context.l10n.typeSettingsHowMax), small),
              ],
            ),
          ),
        ),
        Row(
          children: [
            Text(context.l10n.typeSettingsActiveReminders, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(width: 8),
            Badge(
              label: Text('${reminders.length}/${TypeRemindersEditor.maxReminders}'),
              backgroundColor: AppColors.medium,
            ),
          ],
        ),
        const SizedBox(height: 4),
        if (reminders.isEmpty)
          Text(context.l10n.typeSettingsNoRemindersYet, style: small)
        else
          // Ionic: ion-item-sliding with a trash option.
          ...reminders.map((h) => SwipeActions.delete(
                key: ValueKey('reminder-$h'),
                onDelete: () => widget.onChanged([...reminders]..remove(h)),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: const Icon(Icons.alarm, color: AppColors.primary),
                  title: Text(TypeRemindersEditor.format(h)),
                  subtitle: Text(context.l10n.typeSettingsHoursBeforeStart(h)),
                ),
              )),
        const SizedBox(height: 8),
        if (canAdd) ...[
          Text(context.l10n.typeSettingsQuickSelect, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: TypeRemindersEditor.predefined.map((h) {
              final exists = reminders.contains(h);
              return ActionChip(
                label: Text(TypeRemindersEditor.format(h)),
                onPressed: exists ? null : () => _add(h),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _customController,
                  decoration: InputDecoration(
                    labelText: context.l10n.typeSettingsHoursBefore,
                    hintText: context.l10n.typeSettingsHoursPlaceholder,
                    helperText: context.l10n.typeSettingsValidHours,
                    isDense: true,
                  ),
                  keyboardType: TextInputType.number,
                  onSubmitted: (v) => _add(int.tryParse(v.trim())),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                tooltip: context.l10n.typeSettingsAddReminder,
                icon: const Icon(Icons.add),
                onPressed: () => _add(int.tryParse(_customController.text.trim())),
              ),
            ],
          ),
        ] else
          Card(
            color: AppColors.warning.withValues(alpha: 0.15),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_outlined, color: AppColors.warning),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(context.l10n.typeSettingsMaxReached),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  /// Ionic renders the `*Html` keys via innerHTML; here the tags are dropped.
  static String _stripHtml(String html) => html.replaceAll(RegExp(r'<[^>]+>'), '');

  Widget _info(IconData icon, String text, TextStyle? style) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(child: Text(text, style: style)),
          ],
        ),
      );
}
