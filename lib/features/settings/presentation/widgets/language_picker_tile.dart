import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/locale_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/l10n.dart';

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
      child: ListTile(
        leading: const Icon(Icons.language, color: AppColors.medium),
        title: Row(
          children: [
            Flexible(child: Text(l10n.settingsLanguageTitle)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.success,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                l10n.settingsNew,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              languageNames[current] ?? current,
              style: const TextStyle(color: AppColors.medium),
            ),
            const Icon(Icons.arrow_drop_down, color: AppColors.medium),
          ],
        ),
      ),
    );
  }
}
