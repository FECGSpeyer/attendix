import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendix/core/services/audio_player/audio_player_service.dart';
import '../../../l10n/l10n.dart';

/// Mini audio player bar. Hidden when no file is loaded.
///
/// Mirrors Ionic v4.0.5 `audio-player.component.html` layout:
/// `[play/pause] [title]   [close]
///                [time]   [slider]   [time]`
class AudioPlayerWidget extends ConsumerStatefulWidget {
  const AudioPlayerWidget({super.key});

  @override
  ConsumerState<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends ConsumerState<AudioPlayerWidget> {
  // Local drag value for smooth slider feedback during a drag gesture.
  double? _dragValueMs;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(audioPlayerServiceProvider);
    if (!state.hasFile) return const SizedBox.shrink();

    final svc = ref.read(audioPlayerServiceProvider.notifier);
    final queue = ref.watch(audioQueueInfoProvider); // INTEGRATION
    final maxMs =
        state.duration.inMilliseconds.toDouble().clamp(1.0, double.infinity);
    final value = _dragValueMs ?? state.currentTime.inMilliseconds.toDouble();
    final clamped = value.clamp(0.0, maxMs);

    return Material(
      elevation: 4,
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            // INTEGRATION: queue controls (Ionic audio player: previous/next)
            if (queue.hasQueue)
              IconButton(
                icon: const Icon(Icons.skip_previous),
                tooltip: context.l10n.commonBack,
                onPressed: svc.previous,
              ),
            IconButton(
              icon: Icon(
                state.isPlaying
                    ? Icons.pause_circle_filled
                    : Icons.play_circle_fill,
                size: 36,
              ),
              onPressed: svc.togglePlayPause,
            ),
            if (queue.hasQueue)
              IconButton(
                icon: const Icon(Icons.skip_next),
                tooltip: context.l10n.commonNext,
                onPressed: queue.hasNext ? svc.next : null,
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          state.currentSongName.isNotEmpty
                              ? state.currentSongName
                              : (state.currentFileName ?? ''),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        tooltip: context.l10n.commonClose,
                        onPressed: svc.stop,
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Text(
                        AudioPlayerService.formatTime(state.currentTime),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      Expanded(
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
                      Text(
                        AudioPlayerService.formatTime(state.duration),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
