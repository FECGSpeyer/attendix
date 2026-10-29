import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/redesign_providers.dart';
import '../../../../core/router/redesign_routes.dart';
import '../../../../core/theme/redesign/rd_palette.dart';
import '../../../../core/theme/redesign/rd_theme.dart';
import '../../../../l10n/l10n.dart';
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
/// stored on this device only.
class RdAppearancePage extends ConsumerWidget {
  const RdAppearancePage({super.key});

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
                leading: _Swatches(world),
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
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(l10n.redesignAppearanceDeviceOnly, style: RdType.meta(p, size: 13)),
        ),
      ],
    );
  }
}

/// Three dots: primary, soft, background of [world].
class _Swatches extends StatelessWidget {
  const _Swatches(this.world);

  final RdFarbwelt world;

  @override
  Widget build(BuildContext context) {
    final line = context.rd.line;
    return ExcludeSemantics(
      child: SizedBox(
        width: 54,
        height: 22,
        child: Stack(
          children: [
            for (final (i, c) in rdSwatches(world).indexed)
              Positioned(
                left: i * 16.0,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: Border.all(color: line, width: 1.5),
                  ),
                ),
              ),
          ],
        ),
      ),
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
            SizedBox(
              width: double.infinity,
              child: RdPrimaryButton(
                label: l10n.redesignTodayRecord,
                icon: Icons.checklist_rounded,
                onPressed: () {},
              ),
            ),
          ],
        ),
      ),
    );
  }
}
