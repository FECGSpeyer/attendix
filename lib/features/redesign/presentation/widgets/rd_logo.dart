import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/redesign_providers.dart';
import '../../../../core/theme/redesign/rd_palette.dart';
import '../../../../shared/widgets/display/attendix_logo.dart';

/// REDESIGN: the Attendix logo in the colours of each Farbwelt. Petrol is
/// the Ionic app's original; the home screen icons (ios/Runner/
/// Assets.xcassets/AppIcon*) use the same colours.
AttendixLogoColors rdLogoColors(RdFarbwelt world) => switch (world) {
      RdFarbwelt.petrol => AttendixLogoColors.original,
      RdFarbwelt.konzertsaal => const AttendixLogoColors(
          tile: Color(0xFF6A2C4A),
          glyph: Color(0xFFFBF7F2),
          check: Color(0xFFC9973B),
        ),
      RdFarbwelt.nachtblau => const AttendixLogoColors(
          tile: Color(0xFF2B3FBF),
          glyph: Color(0xFFFFFFFF),
          check: Color(0xFF39C37E),
        ),
      RdFarbwelt.klar => const AttendixLogoColors(
          tile: Color(0xFF111827),
          glyph: Color(0xFFFFFFFF),
          check: Color(0xFF39C37E),
        ),
      RdFarbwelt.buehne => const AttendixLogoColors(
          tile: Color(0xFF25343A),
          glyph: Color(0xFFF3F4F6),
          check: Color(0xFF3EA5AE),
        ),
    };

/// The logo in the chosen Farbwelt (or in [world]).
class RdLogo extends ConsumerWidget {
  const RdLogo({super.key, this.size = 40, this.world, this.semanticLabel});

  final double size;
  final RdFarbwelt? world;

  /// null: decorative.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final RdFarbwelt w = world ?? ref.watch(redesignSettingsProvider).world;
    return AttendixLogo(size: size, colors: rdLogoColors(w), semanticLabel: semanticLabel);
  }
}
