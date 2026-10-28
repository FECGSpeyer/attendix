import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../shared/widgets/common/swipe_actions.dart';

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
    if (hours == 0) return 'Zur gleichen Zeit';
    if (hours < 24) return hours == 1 ? '1 Stunde vorher' : '$hours Stunden vorher';
    final days = hours ~/ 24;
    return days == 1 ? '1 Tag vorher' : '$days Tage vorher';
  }

  /// Ionic `addReminder` validation. Returns the error text or null.
  static String? validate(List<int> reminders, int? hours) {
    if (hours == null || hours < 0) {
      return 'Bitte geben Sie eine positive Ganzzahl ein';
    }
    if (hours > 168) {
      return 'Gültige Werte: 0-168 Stunden (max. 1 Woche vorher)';
    }
    if (reminders.contains(hours)) return 'Diese Erinnerung existiert bereits';
    if (reminders.length >= maxReminders) {
      return 'Maximal 3 Erinnerungen pro Typ möglich';
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
                Text('So funktionieren Erinnerungen',
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                _info(Icons.schedule,
                    'Erinnerungen werden alle 5 Minuten geprüft und versendet.', small),
                _info(Icons.calculate_outlined,
                    'Die Erinnerung wird versendet, sobald die verbleibende Zeit dem konfigurierten Wert entspricht.',
                    small),
                _info(Icons.notifications_outlined,
                    'Maximal 3 Erinnerungen pro Termintyp möglich.', small),
              ],
            ),
          ),
        ),
        Row(
          children: [
            Text('Aktive Erinnerungen', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(width: 8),
            Badge(
              label: Text('${reminders.length}/${TypeRemindersEditor.maxReminders}'),
              backgroundColor: AppColors.medium,
            ),
          ],
        ),
        const SizedBox(height: 4),
        if (reminders.isEmpty)
          Text('Noch keine Erinnerungen konfiguriert', style: small)
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
                  subtitle: Text(h == 1 ? '1 Stunde vor Terminbeginn' : '$h Stunden vor Terminbeginn'),
                ),
              )),
        const SizedBox(height: 8),
        if (canAdd) ...[
          Text('Schnellauswahl', style: Theme.of(context).textTheme.titleSmall),
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
                  decoration: const InputDecoration(
                    labelText: 'Stunden vor Termin',
                    hintText: 'z.B. 12 für 12 Stunden vorher',
                    helperText: 'Gültige Werte: 0-168 Stunden (max. 1 Woche vorher)',
                    isDense: true,
                  ),
                  keyboardType: TextInputType.number,
                  onSubmitted: (v) => _add(int.tryParse(v.trim())),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                tooltip: 'Erinnerung hinzufügen',
                icon: const Icon(Icons.add),
                onPressed: () => _add(int.tryParse(_customController.text.trim())),
              ),
            ],
          ),
        ] else
          Card(
            color: AppColors.warning.withValues(alpha: 0.15),
            child: const Padding(
              padding: EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_outlined, color: AppColors.warning),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Maximum von 3 Erinnerungen erreicht. Entferne eine bestehende '
                      'Erinnerung, um eine neue hinzuzufügen.',
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

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
