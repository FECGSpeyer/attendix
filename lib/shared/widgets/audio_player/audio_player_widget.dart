import 'package:flutter/material.dart';
import 'package:attendix/core/theme/app_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:attendix/core/services/audio_player/audio_player_service.dart';
import '../../../l10n/l10n.dart';
import '../../../core/utils/toast_helper.dart';
import '../../../core/utils/error_message.dart';

/// Mini audio player bar. Hidden when no file is loaded.
///
/// Mirrors Ionic v4.0.5 `audio-player.component.html` layout:
/// `[play/pause] [title]   [close]
///                [time]   [slider]   [time]`
class AudioPlayerWidget extends ConsumerStatefulWidget {
  const AudioPlayerWidget({super.key, this.showSpeed = false});

  /// REDESIGN: "0,8×" in the bar (Beta: the only player, the Werk page
  /// shows the recordings as rows without own controls).
  final bool showSpeed;

  @override
  ConsumerState<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends ConsumerState<AudioPlayerWidget> {
  // Local drag value for smooth slider feedback during a drag gesture.
  double? _dragValueMs;

  /// Ionic onPrevious/onNext: errors end in 'Fehler beim Abspielen: {error}'.
  Future<void> _skip(BuildContext context, Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      if (context.mounted) {
        ToastHelper.showError(context, context.l10n.audioPlayFailed(friendlyErrorMessage(e)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(audioPlayerServiceProvider);
    if (!state.hasFile) return const SizedBox.shrink();

    final svc = ref.read(audioPlayerServiceProvider.notifier);
    final queue = ref.watch(audioQueueInfoProvider);
    final maxMs =
        state.duration.inMilliseconds.toDouble().clamp(1.0, double.infinity);
    final value = _dragValueMs ?? state.currentTime.inMilliseconds.toDouble();
    final clamped = value.clamp(0.0, maxMs);

    // UX_SONGS_SELF: Ionic `.audio-player-bar`: floating rounded bar
    // (iOS: 17px inset, radius 29; md: 8px, radius 19), translucent
    // background with shadow, primary play/skip icons, 13px semibold title,
    // grey close-circle, 10px time labels and a thin primary seek bar.
    final ios = Theme.of(context).platform == TargetPlatform.iOS;
    final theme = Theme.of(context);
    const medium = Color(0xFF92949C);
    final primary = theme.colorScheme.primary;
    Widget iconButton(IconData icon, double size, Color color, VoidCallback? onTap,
        {String? tooltip}) {
      final button = InkResponse(
        onTap: onTap,
        radius: size * 0.7,
        child: Icon(icon, size: size, color: onTap == null ? color.withValues(alpha: 0.35) : color),
      );
      return tooltip == null ? button : Tooltip(message: tooltip, child: button);
    }

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(ios ? 17 : 8, 6, ios ? 17 : 8, 8),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(ios ? 29 : 19),
            boxShadow: const [
              BoxShadow(color: Color(0x1A000000), blurRadius: 20, offset: Offset(0, 2)),
            ],
          ),
          child: Material(
            type: MaterialType.transparency,
            child: Row(
              children: [
                // INTEGRATION: queue controls (Ionic audio player: previous/next)
                if (queue.hasQueue) ...[
                  iconButton(AppIcons.skipPrevious, 22, primary, () => _skip(context, svc.previous),
                      tooltip: context.l10n.commonBack),
                  const SizedBox(width: 4),
                ],
                iconButton(
                  state.isPlaying ? AppIcons.pauseCircleFilled : AppIcons.playCircleFill,
                  36,
                  primary,
                  svc.togglePlayPause,
                ),
                if (queue.hasQueue) ...[
                  const SizedBox(width: 4),
                  iconButton(AppIcons.skipNext, 22, primary, queue.hasNext ? () => _skip(context, svc.next) : null,
                      tooltip: context.l10n.commonNext),
                ],
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        height: 22,
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                state.currentSongName.isNotEmpty
                                    ? state.currentSongName
                                    : (state.currentFileName ?? ''),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                            ),
                            if (queue.hasQueue) ...[
                              const SizedBox(width: 8),
                              Text(
                                '${queue.index + 1}/${queue.length}',
                                style: const TextStyle(fontSize: 10, color: medium),
                              ),
                            ],
                            const SizedBox(width: 8),
                            iconButton(AppIcons.cancel, 18, medium, svc.stop,
                                tooltip: context.l10n.commonClose),
                          ],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          SizedBox(
                            width: 30,
                            child: Text(
                              AudioPlayerService.formatTime(state.currentTime),
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 10, color: medium),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: SizedBox(
                              height: 16,
                              child: SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  trackHeight: 3,
                                  activeTrackColor: primary,
                                  inactiveTrackColor: medium.withValues(alpha: 0.25),
                                  thumbColor: primary,
                                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                                  overlayShape: SliderComponentShape.noOverlay,
                                  trackShape: const RoundedRectSliderTrackShape(),
                                ),
                                child: Slider(
                                  min: 0,
                                  max: maxMs,
                                  value: clamped,
                                  onChangeStart: (_) {
                                    svc.startSeeking();
                                  },
                                  onChanged: (v) {
                                    setState(() => _dragValueMs = v);
                                  },
                                  onChangeEnd: (v) async {
                                    setState(() => _dragValueMs = null);
                                    await svc.stopSeeking(
                                      Duration(milliseconds: v.round()),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          SizedBox(
                            width: 30,
                            child: Text(
                              AudioPlayerService.formatTime(state.duration),
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 10, color: medium),
                            ),
                          ),
                          if (widget.showSpeed) ...[
                            const SizedBox(width: 8),
                            _SpeedButton(primary: primary),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// REDESIGN: toggles 0,8× / 1× (the same speed for every track).
class _SpeedButton extends ConsumerWidget {
  const _SpeedButton({required this.primary});

  final Color primary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final slow = ref.watch(audioPlaybackSpeedProvider) < 1;
    final speed = NumberFormat.decimalPattern(currentIntlLocale()).format(slow ? 0.8 : 1);
    return Semantics(
      button: true,
      label: slow ? l10n.redesignWorkNormalSpeed : l10n.redesignWorkSlower,
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => ref.read(audioPlayerServiceProvider.notifier).setSpeed(slow ? 1.0 : 0.8),
        child: Container(
          height: 24,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: slow ? primary.withValues(alpha: 0.15) : null,
            border: Border.all(color: slow ? primary : const Color(0x8092949C)),
          ),
          child: Text(
            '$speed×',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: slow ? primary : null),
          ),
        ),
      ),
    );
  }
}
