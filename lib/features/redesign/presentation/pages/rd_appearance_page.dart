import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/redesign_providers.dart';
import '../../../../core/router/redesign_routes.dart';
import '../../../../core/services/app_icon_service.dart';
import '../../../../core/theme/redesign/rd_palette.dart';
import '../../../../core/theme/redesign/rd_theme.dart';
import '../../../../l10n/l10n.dart';
import '../widgets/rd_logo.dart';
import '../widgets/rd_widgets.dart';

/// Name of a Farbwelt ("Petrol", "Konzertsaal" …).
String rdWorldName(AppLocalizations l10n, RdFarbwelt world) => switch (world) {
      RdFarbwelt.petrol => l10n.redesignAppearanceWorldPetrol,
      RdFarbwelt.konzertsaal => l10n.redesignAppearanceWorldConcertHall,
      RdFarbwelt.nachtblau => l10n.redesignAppearanceWorldNightBlue,
      RdFarbwelt.klar => l10n.redesignAppearanceWorldClear,
      RdFarbwelt.buehne => l10n.redesignAppearanceWorldStage,
    };

String _worldHint(AppLocalizations l10n, RdFarbwelt world) => switch (world) {
      RdFarbwelt.petrol => l10n.redesignAppearanceWorldPetrolHint,
      RdFarbwelt.konzertsaal => l10n.redesignAppearanceWorldConcertHallHint,
      RdFarbwelt.nachtblau => l10n.redesignAppearanceWorldNightBlueHint,
      RdFarbwelt.klar => l10n.redesignAppearanceWorldClearHint,
      RdFarbwelt.buehne => l10n.redesignAppearanceWorldStageHint,
    };

/// "Automatisch", "Hell", "Dunkel".
String rdModeName(AppLocalizations l10n, RdBrightnessMode mode) => switch (mode) {
      RdBrightnessMode.auto => l10n.redesignAppearanceModeAuto,
      RdBrightnessMode.light => l10n.redesignAppearanceModeLight,
      RdBrightnessMode.dark => l10n.redesignAppearanceModeDark,
    };

/// REDESIGN: Ich › Darstellung (canvas E2): Farbwelt and hell/dunkel,
/// stored on this device only. Each Farbwelt shows the logo in its colours;
/// on iOS the home screen icon can follow it.
class RdAppearancePage extends ConsumerWidget {
  const RdAppearancePage({super.key, this.showAppIcon});

  /// Tests: show the app icon switch off iOS.
  final bool? showAppIcon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.rd;
    final l10n = context.l10n;
    final settings = ref.watch(redesignSettingsProvider);
    final notifier = ref.read(redesignSettingsProvider.notifier);
    final stage = settings.world.alwaysDark;

    return RdPage(
      children: [
        RdBackLink(
          label: l10n.redesignTabMe,
          onTap: () => context.canPop() ? context.pop() : context.go(RedesignRoutes.me),
        ),
        const SizedBox(height: 4),
        Semantics(
          header: true,
          child: Text(l10n.redesignAppearanceTitle, style: RdType.largeTitle(p)),
        ),
        const SizedBox(height: 18),
        const _PreviewCard(),
        const SizedBox(height: 24),
        RdGroupLabel(l10n.redesignAppearanceWorld),
        RdGroupedList(
          children: [
            for (final world in RdFarbwelt.values)
              RdListRow(
                leading: RdLogo(world: world, size: 36),
                title: rdWorldName(l10n, world),
                subtitle: _worldHint(l10n, world),
                selected: world == settings.world,
                showChevron: false,
                trailing: world == settings.world
                    ? Icon(Icons.check_circle, color: p.primary)
                    : null,
                onTap: () => notifier.setWorld(world),
              ),
          ],
        ),
        const SizedBox(height: 24),
        RdGroupLabel(l10n.redesignAppearanceBrightness),
        RdSegmented<RdBrightnessMode>(
          values: RdBrightnessMode.values,
          selected: stage ? RdBrightnessMode.dark : settings.mode,
          labelOf: (m) => rdModeName(l10n, m),
          enabled: !stage,
          semanticLabel: l10n.redesignAppearanceBrightness,
          onChanged: notifier.setMode,
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            stage ? l10n.redesignAppearanceStageAlwaysDark : l10n.redesignAppearanceAutoHint,
            style: RdType.meta(p, size: 13),
          ),
        ),
        if (showAppIcon ?? AppIconService.isSupported) ...[
          const SizedBox(height: 24),
          RdGroupLabel(l10n.redesignAppearanceAppIcon),
          RdGroupedList(
            children: [
              RdListRow(
                leading: RdLogo(world: settings.appIcon ? settings.world : RdFarbwelt.petrol, size: 36),
                title: l10n.redesignAppearanceAppIconFollow,
                subtitle: l10n.redesignAppearanceAppIconHint,
                showChevron: false,
                trailing: Switch.adaptive(
                  value: settings.appIcon,
                  activeTrackColor: p.primary,
                  onChanged: notifier.setAppIcon,
                ),
                onTap: () => notifier.setAppIcon(!settings.appIcon),
              ),
            ],
          ),
        ],
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(l10n.redesignAppearanceDeviceOnly, style: RdType.meta(p, size: 13)),
        ),
      ],
    );
  }
}

/// Small "Heute" card in the chosen colours.
class _PreviewCard extends StatelessWidget {
  const _PreviewCard();

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    return Semantics(
      label: l10n.redesignAppearancePreview,
      excludeSemantics: true,
      child: RdCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: RdEyebrow('${l10n.redesignTodayNextEvent} · ${l10n.redesignTodayDayToday}')),
                RdPill(l10n.redesignTodayInHours(3), tone: RdTone.primary),
              ],
            ),
            const SizedBox(height: 8),
            Text(l10n.redesignAppearancePreviewTitle, style: RdType.cardTitle(p)),
            const SizedBox(height: 4),
            Text('19:30–21:30', style: RdType.meta(p, size: 15)),
            const SizedBox(height: 14),
            RdStatusBar(
              total: 34,
              segments: [
                RdBarSegment(24, p.present),
                RdBarSegment(2, p.late),
                RdBarSegment(3, p.excused),
              ],
              semanticLabel: '',
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                RdPill(l10n.redesignStatusYes, tone: RdTone.present),
                RdPill(l10n.redesignStatusLater, tone: RdTone.late),
                RdPill(l10n.redesignStatusExcused, tone: RdTone.excused),
                RdPill(l10n.redesignStatusAbsent, tone: RdTone.absent),
              ],
            ),
            const SizedBox(height: 14),
            // Only a preview of the colours: looks like the real button but
            // takes no taps or keyboard focus and is not announced as a button.
            IgnorePointer(
              child: ExcludeFocus(
                child: ExcludeSemantics(
                  child: SizedBox(
                    width: double.infinity,
                    child: RdPrimaryButton(
                      label: l10n.redesignTodayRecord,
                      icon: Icons.checklist_rounded,
                      onPressed: () {},
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
