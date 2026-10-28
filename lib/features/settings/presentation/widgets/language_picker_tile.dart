import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/locale_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/l10n.dart';
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

    return PopupMenuButton<String>(
      key: const Key('languagePicker'),
      initialValue: current,
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
            child: Text(languageNames[lang] ?? lang),
          ),
      ],
      // UX_SETTINGS (WAVE 8): same item look as the other System entries;
      // label + green ion-badge "NEU", the selected value at the end.
      child: SettingsListTile(
        // Ionic language-outline (文A).
        icon: Icons.translate,
        title: l10n.settingsLanguageTitle,
        detail: false,
        titleWidget: Row(
          children: [
            Flexible(child: Text(l10n.settingsLanguageTitle)),
            const SizedBox(width: 6),
            IonBadge(text: l10n.settingsNew, color: AppColors.success),
          ],
        ),
        trailing: Row(
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
            // ion-select ios: `chevron-expand` toggle icon, 1.125rem,
            // --ion-color-step-650.
            ios
                ? Icon(
                    CupertinoIcons.chevron_up_chevron_down,
                    key: const Key('languagePickerChevron'),
                    size: 18,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFFA6A6A6)
                        : const Color(0xFF595959),
                  )
                : const Icon(Icons.arrow_drop_down, color: AppColors.medium),
          ],
        ),
      ),
    );
  }
}
