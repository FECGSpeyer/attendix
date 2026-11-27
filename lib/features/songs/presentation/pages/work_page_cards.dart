part of 'work_page.dart';

/// One file: a tap opens it, "•••" holds the rest.
class _FileRow extends StatelessWidget {
  const _FileRow({
    required this.file,
    required this.label,
    required this.detail,
    required this.onOpen,
    required this.onMore,
  });

  final SongFile file;
  final String label;
  final String detail;
  final VoidCallback onOpen;
  final void Function(BuildContext button) onMore;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final audio = rdIsAudioFile(file);
    return RdListRow(
      leading: RdRowIcon(
        audio
            ? Icons.graphic_eq
            : (SongUtils.isPdf(file) ? Icons.description_outlined : Icons.insert_drive_file_outlined),
        color: audio ? p.text2 : p.softText,
        background: audio ? p.track : p.soft,
      ),
      title: label,
      subtitle: detail,
      showChevron: false,
      onTap: onOpen,
      trailing: Builder(
        builder:
            (button) => IconButton(
              tooltip: context.l10n.redesignWorkFileMore(label),
              icon: Icon(Icons.more_horiz, color: p.link),
              onPressed: () => onMore(button),
            ),
      ),
    );
  }
}

/// "Horn fehlt noch": somebody plays in these groups, but there are no
/// Noten for them yet. Calm info, not a warning: not every Werk has a part
/// for every group.
class _MissingRow extends StatelessWidget {
  const _MissingRow({required this.missing, required this.onUpload});

  final List<Group> missing;
  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final one = missing.length == 1;
    return RdListRow(
      leading: RdRowIcon(Icons.info_outline, color: p.softText, background: p.soft),
      title: one ? l10n.redesignWorkMissingOne(missing.single.name) : l10n.redesignWorkMissingMany(missing.length),
      subtitle: one ? l10n.redesignWorkMissingOneHint(missing.single.name) : missing.map((g) => g.name).join(', '),
      showChevron: false,
      trailing: TextButton(
        style: TextButton.styleFrom(
          foregroundColor: p.link,
          minimumSize: const Size(0, 40),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        onPressed: onUpload,
        child: Text(l10n.redesignWorkUpload),
      ),
    );
  }
}

/// "+ Hinzufügen" on the right of "Noten & Dateien".
class _AddLink extends StatelessWidget {
  const _AddLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    return TextButton.icon(
      style: TextButton.styleFrom(
        foregroundColor: p.link,
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
      ),
      onPressed: onTap,
      icon: const Icon(Icons.add, size: 20),
      label: Text(label),
    );
  }
}

/// Werk without files, for editors: the next step right there.
class _AddFilesCard extends StatelessWidget {
  const _AddFilesCard({required this.onPick});

  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    return RdCard(
      onTap: onPick,
      border: Border.all(color: p.offBorder, width: 1.5),
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Column(
        children: [
          RdRowIcon(Icons.upload_outlined, color: p.softText, background: p.soft),
          const SizedBox(height: 10),
          Text(l10n.redesignWorkAddTitle, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: p.text)),
          const SizedBox(height: 4),
          Text(l10n.redesignWorkAddHint, textAlign: TextAlign.center, style: RdType.meta(p, size: 14)),
          const SizedBox(height: 12),
          RdPrimaryButton(
            label: l10n.redesignWorkAddPick,
            icon: Icons.folder_open_outlined,
            height: 44,
            onPressed: onPick,
          ),
          // "Am Computer": not on a phone-sized browser window.
          if (isFileDropSupported && MediaQuery.sizeOf(context).width >= 600) ...[
            const SizedBox(height: 8),
            Text(l10n.redesignWorkAddDrop, textAlign: TextAlign.center, style: RdType.meta(p, size: 13)),
          ],
        ],
      ),
    );
  }
}

/// The top card with "Öffnen": "Deine Stimme" (the person's part), or for
/// conductors the score or all parts. The whole card opens it too; sharing
/// and the rest are in the file's "•••" under Noten & Dateien.
class _PartCard extends StatelessWidget {
  const _PartCard({
    required this.eyebrow,
    required this.title,
    required this.detail,
    required this.onOpen,
    this.recordings = const [],
  });

  final String eyebrow;
  final String title;
  final String detail;
  final VoidCallback onOpen;

  /// Recording rows in the same card, below the file.
  final List<Widget> recordings;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    // Only "Öffnen": the file's "•••" is in Noten & Dateien below.
    final actions = [
      FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: p.primary,
          foregroundColor: p.onPrimary,
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(p.buttonRadius)),
          // Theme font (web font on the PWA), like RdPrimaryButton.
          textStyle: (Theme.of(context).textTheme.labelLarge ?? const TextStyle()).copyWith(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        onPressed: onOpen,
        child: Text(l10n.redesignWorkOpen),
      ),
    ];
    final info = Row(
      children: [
        ExcludeSemantics(
          child: Container(
            width: 52,
            height: 68,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            decoration: BoxDecoration(
              color: p.bg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: p.offBorder),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [for (var i = 0; i < 5; i++) Container(height: 2, color: p.text2.withValues(alpha: 0.5))],
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RdEyebrow(eyebrow),
              const SizedBox(height: 2),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: p.text),
              ),
              Text(detail, maxLines: 1, overflow: TextOverflow.ellipsis, style: RdType.meta(p, size: 13)),
            ],
          ),
        ),
      ],
    );
    final file = LayoutBuilder(
      builder: (context, constraints) {
        // Small phones and large text: the buttons move below the text,
        // next to it they would squeeze the title into one letter a line.
        final compact = constraints.maxWidth < MediaQuery.textScalerOf(context).scale(300);
        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              info,
              const SizedBox(height: 10),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: actions),
            ],
          );
        }
        return Row(children: [Expanded(child: info), const SizedBox(width: 8), ...actions]);
      },
    );
    if (recordings.isEmpty) return RdCard(padding: const EdgeInsets.all(14), onTap: onOpen, child: file);
    return RdCard(
      padding: EdgeInsets.zero,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(onTap: onOpen, child: Padding(padding: const EdgeInsets.all(14), child: file)),
          for (final row in recordings) ...[Divider(height: 1, thickness: 1, color: p.line), row],
        ],
      ),
    );
  }
}

/// The recordings without a card on top (no own part / nothing on top).
class _RecordingsCard extends StatelessWidget {
  const _RecordingsCard({required this.rows});

  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    return RdCard(
      padding: EdgeInsets.zero,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) Divider(height: 1, thickness: 1, color: p.line),
            rows[i],
          ],
        ],
      ),
    );
  }
}

/// A recording as one row: play / pause, title, "Läuft · 1:12 von 3:48"
/// while it is the loaded track, and "•••". Progress, seeking and 0,8× are
/// in the player bar at the bottom of the app.
class _RecordingRow extends ConsumerWidget {
  const _RecordingRow({required this.song, required this.file, this.title, this.onMore});

  final Song song;
  final SongFile file;

  /// Instead of "Aufnahme vom …" (practice recording of a voice).
  final String? title;
  final void Function(BuildContext button)? onMore;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.rd;
    final l10n = context.l10n;
    final audio = ref.watch(audioPlayerServiceProvider);
    final service = ref.read(audioPlayerServiceProvider.notifier);
    final mine = audio.currentUrl == file.url;
    final playing = mine && audio.isPlaying;
    final created = DateTime.tryParse(file.createdAt ?? '');
    final name =
        title ??
        (created == null
            ? l10n.redesignWorkRecording
            : l10n.redesignWorkRecordingFrom(DateFormat.Md(currentIntlLocale()).format(created.toLocal())));
    final position = AudioPlayerService.formatTime(audio.currentTime);
    final length = audio.duration > Duration.zero ? AudioPlayerService.formatTime(audio.duration) : '–:––';
    final detail =
        !mine
            ? rdFileKind(file)
            : playing
            ? l10n.redesignWorkPlayingAt(position, length)
            : l10n.redesignWorkPausedAt(position, length);

    void toggle() {
      if (mine) {
        service.togglePlayPause();
      } else {
        service.playFromUrl(file.url, file.fileName, song.name);
      }
    }

    return InkWell(
      onTap: toggle,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
        child: Row(
          children: [
            Semantics(
              container: true,
              button: true,
              label: playing ? l10n.redesignWorkPause : l10n.redesignWorkPlay,
              excludeSemantics: true,
              child: Material(
                color: playing ? p.primary : p.soft,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: toggle,
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: Icon(playing ? Icons.pause : Icons.play_arrow, color: playing ? p.onPrimary : p.softText),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: p.text),
                  ),
                  Text(
                    detail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: mine ? FontWeight.w600 : FontWeight.w400,
                      color: mine ? p.link : p.text2,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
            if (onMore != null)
              Builder(
                builder:
                    (button) => IconButton(
                      tooltip: l10n.redesignWorkFileMore(name),
                      icon: Icon(Icons.more_horiz, color: p.link),
                      onPressed: () => onMore!(button),
                    ),
              ),
          ],
        ),
      ),
    );
  }
}
