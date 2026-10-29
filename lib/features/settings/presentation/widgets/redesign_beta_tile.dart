import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/redesign_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/l10n.dart';
import '../../../redesign/presentation/rd_actions.dart';
import 'settings_list.dart';

/// REDESIGN: "Neues Design (Beta)" in the System section. Switches the new
/// design on for this device only; the old design stays the default.
class RedesignBetaTile extends ConsumerWidget {
  const RedesignBetaTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final enabled = ref.watch(redesignEnabledProvider);
    return SettingsListTile(
      key: const Key('redesignBetaTile'),
      icon: Icons.auto_awesome_outlined,
      title: l10n.redesignMeBeta,
      subtitle: l10n.redesignMeBetaHint,
      detail: false,
      titleWidget: Row(
        children: [
          Flexible(child: Text(l10n.redesignMeBeta)),
          const SizedBox(width: 6),
          IonBadge(text: l10n.settingsNew, color: AppColors.success),
        ],
      ),
      trailing: Switch.adaptive(
        value: enabled,
        onChanged: (v) => rdSetRedesignEnabled(context, ref, v),
      ),
      onTap: () => rdSetRedesignEnabled(context, ref, !enabled),
    );
  }
}
