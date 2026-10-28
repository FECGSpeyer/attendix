import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/locale_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/adaptive/app_select.dart'; // IOS_THEME2
import 'settings_list.dart';

/// I18N_INFRA – Ionic settings "System" item:
/// `ion-item` with `language-outline` icon and an `ion-select
/// interface="popover"` labelled "Sprache" + green "NEU" badge.
/// Only shown when more than one language is enabled.
class LanguagePickerTile extends ConsumerWidget {
  const LanguagePickerTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (enabledLanguages.length <= 1) return const SizedBox.shrink();
    final l10n = context.l10n;
    final current = ref.watch(localeProvider).languageCode;
    final ios = ionIsIos(context);

    // IOS_THEME2: on iOS the ion-select popover opens under the value
    // (right) with a checkmark on the current language.
    BuildContext? valueContext;
    // UX_SETTINGS (WAVE 8): same item look as the other System entries;
    // label + green ion-badge "NEU", the selected value at the end.
    SettingsListTile tile({VoidCallback? onTap}) => SettingsListTile(
          // Ionic language-outline (文A).
          icon: Icons.translate,
          title: l10n.settingsLanguageTitle,
          detail: false,
          onTap: onTap,
          titleWidget: Row(
            children: [
              Flexible(child: Text(l10n.settingsLanguageTitle)),
              const SizedBox(width: 6),
              IonBadge(text: l10n.settingsNew, color: AppColors.success),
            ],
          ),
          trailing: Builder(builder: (c) {
            valueContext = c;
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  languageNames[current] ?? current,
                  style: TextStyle(
                    fontSize: 16,
                    color: ios ? IonIos.text(context) : AppColors.medium,
                  ),
                ),
                const SizedBox(width: 4),
                // ion-select ios: `chevron-expand` toggle icon.
                ios
                    ? const IonSelectIcon(key: Key('languagePickerChevron'))
                    : const Icon(Icons.arrow_drop_down,
                        color: AppColors.medium),
              ],
            );
          }),
        );

    if (ios) {
      return KeyedSubtree(
        key: const Key('languagePicker'),
        child: tile(
          onTap: () async {
            final picked = await showAppSelect<String>(
              context: valueContext ?? context,
              value: current,
              options: [
                for (final lang in enabledLanguages)
                  AppSelectOption<String>(
                    value: lang,
                    label: languageNames[lang] ?? lang,
                  ),
              ],
            );
            if (picked == null || picked.value == current) return;
            ref.read(localeProvider.notifier).setLanguage(picked.value);
          },
        ),
      );
    }

    // PARITY_R3: Ionic md select popover marks the current option with
    // `.item-radio-checked` – a primary 8 % row background (no grey
    // Material "initial value" highlight, no radio circle).
    final primary = Theme.of(context).colorScheme.primary;
    return PopupMenuButton<String>(
      key: const Key('languagePicker'),
      tooltip: l10n.settingsLanguageTitle,
      position: PopupMenuPosition.under,
      onSelected: (value) {
        if (value == current) return;
        ref.read(localeProvider.notifier).setLanguage(value);
      },
      itemBuilder: (_) => [
        for (final lang in enabledLanguages)
          PopupMenuItem<String>(
            value: lang,
            padding: EdgeInsets.zero,
            child: Container(
              key: Key('languageOption_$lang'),
              constraints: const BoxConstraints(minHeight: 48),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: AlignmentDirectional.centerStart,
              color: lang == current ? primary.withValues(alpha: 0.08) : null,
              child: Text(languageNames[lang] ?? lang),
            ),
          ),
      ],
      child: tile(),
    );
  }
}
