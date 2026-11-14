import 'package:flutter/material.dart';
import 'package:attendix/core/theme/app_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/redesign/rd_theme.dart' show RdSkinContext;
import '../../../planning/presentation/widgets/ion_items.dart' show IonChip;
import '../../../../core/utils/toast_helper.dart';
import '../../../../shared/widgets/common/swipe_actions.dart';
import '../../../../l10n/l10n.dart';
import 'strong_html_text.dart';
import 'settings_form_items.dart';
import 'settings_list.dart';
import '../../../../shared/widgets/adaptive/ion_button.dart';
import '../../../../shared/widgets/layout/ionic_md.dart';

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
    if (context.rdSkin == null) return _buildClassic(context);
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
                _info(AppIcons.schedule,
                    context.l10n.typeSettingsHowEvery5, small),
                _info(AppIcons.calculateOutlined,
                    context.l10n.typeSettingsHowRemaining,
                    small),
                _info(AppIcons.notificationsOutlined,
                    context.l10n.typeSettingsHowMax, small),
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
                  leading: Icon(AppIcons.alarm, color: AppColors.primary),
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
              if (context.rdSkin != null) {
                return ActionChip(
                  label: Text(TypeRemindersEditor.format(h)),
                  onPressed: exists ? null : () => _add(h),
                );
              }
              // ion-chip: primary with an add icon, medium + disabled once
              // the reminder exists.
              return IonChip(
                icon: AppIcons.addCircleOutline,
                label: TypeRemindersEditor.format(h),
                color: exists ? AppColors.medium : AppColors.primary,
                disabled: exists,
                onTap: () => _add(h),
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
                icon: Icon(AppIcons.add),
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
                  Icon(AppIcons.warningAmberOutlined, color: AppColors.warning),
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


  /// EIA-06: classic design – the Ionic reminders modal content: inset
  /// lists with list headers (info items, active reminders with an
  /// `ion-badge`, quick select chips, custom stacked input + block button),
  /// warning `ion-card` once three reminders exist.
  Widget _buildClassic(BuildContext context) {
    final reminders = widget.reminders;
    final canAdd = reminders.length < TypeRemindersEditor.maxReminders;
    final ios = ionIsIos(context);
    final b = Theme.of(context).brightness;
    final pStyle = TextStyle(
      fontSize: 14,
      height: ios ? 1.4 : IonMd.pLineHeight,
      color: ios ? IonIos.labelP(context) : IonMd.labelP(b),
    );
    Widget info(IconData icon, String text) => ListTile(
          leading: Icon(icon, color: AppColors.primary),
          title: StrongHtmlText(text, style: pStyle),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsListSection(
          title: context.l10n.typeSettingsHowReminders,
          // Ionic: `lines="none"` items (one group child = no lines).
          children: [
            Column(children: [
              info(AppIcons.schedule, context.l10n.typeSettingsHowEvery5),
              info(AppIcons.calculateOutlined, context.l10n.typeSettingsHowRemaining),
              info(AppIcons.notificationsOutlined, context.l10n.typeSettingsHowMax),
            ]),
          ],
        ),
        SettingsListSection(
          title: context.l10n.typeSettingsActiveReminders,
          headerAction: Padding(
            padding: const EdgeInsets.only(right: 12, bottom: 2),
            child: IonBadge(
              text: '${reminders.length}/${TypeRemindersEditor.maxReminders}',
              color: AppColors.medium,
            ),
          ),
          children: [
            if (reminders.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  children: [
                    Icon(AppIcons.notificationsOffOutlined, size: 32, color: AppColors.medium),
                    const SizedBox(height: 4),
                    Text(
                      context.l10n.typeSettingsNoRemindersYet,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 14, color: AppColors.medium),
                    ),
                  ],
                ),
              )
            else
              for (final h in reminders)
                // Ionic: ion-item-sliding with a trash option.
                SwipeActions.delete(
                  key: ValueKey('reminder-$h'),
                  onDelete: () => widget.onChanged([...reminders]..remove(h)),
                  child: ListTile(
                    leading: Icon(AppIcons.alarm, color: AppColors.primary),
                    title: Text(TypeRemindersEditor.format(h)),
                    subtitle: Text(context.l10n.typeSettingsHoursBeforeStart(h)),
                  ),
                ),
          ],
        ),
        if (canAdd) ...[
          SettingsListSection(
            title: context.l10n.typeSettingsQuickSelect,
            children: [
              Padding(
                // type.page.scss `.reminder-chips`: padding 12 16, gap 8.
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final h in TypeRemindersEditor.predefined)
                      IonChip(
                        icon: AppIcons.addCircleOutline,
                        label: TypeRemindersEditor.format(h),
                        color: reminders.contains(h) ? AppColors.medium : AppColors.primary,
                        disabled: reminders.contains(h),
                        onTap: () => _add(h),
                      ),
                  ],
                ),
              ),
            ],
          ),
          SettingsListSection(
            title: context.l10n.typeSettingsCustom,
            children: [
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              SettingsStackedField(
                label: context.l10n.typeSettingsHoursBefore,
                hint: context.l10n.typeSettingsHoursPlaceholder,
                helper: context.l10n.typeSettingsValidHours,
                builder: (decoration) => TextField(
                  controller: _customController,
                  decoration: decoration,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (v) => _add(int.tryParse(v.trim())),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                child: IonButton(
                  label: context.l10n.typeSettingsAddReminder,
                  icon: AppIcons.addCircleOutline,
                  expand: true,
                  onPressed: _customController.text.trim().isEmpty
                      ? null
                      : () {
                          _add(int.tryParse(_customController.text.trim()));
                          setState(() {});
                        },
                ),
              ),
              ]),
            ],
          ),
        ] else
          // `ion-card color="warning"`.
          IonCardBox(
            color: AppColors.warning,
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(AppIcons.warningAmberOutlined, color: Colors.black, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      context.l10n.typeSettingsMaxReached,
                      style: const TextStyle(color: Colors.black, fontSize: 14),
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
            Expanded(child: StrongHtmlText(text, style: style)),
          ],
        ),
      );
}
