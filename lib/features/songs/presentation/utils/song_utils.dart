import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/choir_file_utils.dart';
import '../../../../data/models/instrument/instrument.dart';
import '../../../../data/models/song/song.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/display/ion_badge_text.dart';

/// Shared helpers for the songs feature (ports of Ionic Utils / song.page).
class SongUtils {
  SongUtils._();

  static const List<String> _audioExtensions = [
    'mp3', 'wav', 'ogg', 'm4a', 'aac', 'flac', 'wma'
  ];

  static String _extension(String fileName) {
    final idx = fileName.lastIndexOf('.');
    return idx >= 0 ? fileName.substring(idx + 1).toLowerCase() : '';
  }

  /// fileType is a MIME type for files uploaded via Ionic ("application/pdf")
  /// and an extension for older Flutter uploads ("pdf") - accept both.
  static bool isPdf(SongFile file) {
    final type = file.fileType.toLowerCase();
    return type == 'application/pdf' ||
        type == 'pdf' ||
        _extension(file.fileName) == 'pdf';
  }

  static bool isImage(SongFile file) {
    final type = file.fileType.toLowerCase();
    return type.startsWith('image/') ||
        ['png', 'jpg', 'jpeg', 'gif', 'webp'].contains(type) ||
        ['png', 'jpg', 'jpeg', 'gif', 'webp'].contains(_extension(file.fileName));
  }

  static bool isAudio(SongFile file) {
    final type = file.fileType.toLowerCase();
    return type.startsWith('audio/') ||
        _audioExtensions.contains(type) ||
        _audioExtensions.contains(_extension(file.fileName));
  }

  /// Label of a file category (Ionic `getInstrumentName`). In choirs a
  /// file for all singers is labelled "Chor (alle)" (Ionic 4.17.16).
  static String fileLabel(SongFile file, List<Group> instruments, {bool isChoir = false}) {
    final id = file.instrumentId;
    if (id == null || id == 0) {
      if (isChoir && isChoirAllFile(note: file.note)) return l10nWithoutContext.songsChoirAll;
      return file.note ?? l10nWithoutContext.songsOther;
    }
    if (id == 1) return l10nWithoutContext.songsRecording;
    if (id == 2) return l10nWithoutContext.songsLyrics;
    for (final g in instruments) {
      if (g.id == id) return g.name;
    }
    return l10nWithoutContext.commonUnknown;
  }

  /// Badge color of a file category (Ionic `getBadgeColor`)
  static Color fileBadgeColor(SongFile file) {
    final id = file.instrumentId;
    if (id == 1) return AppColors.primary; // Aufnahme
    if (id == 2) return AppColors.warning; // Liedtext
    if (id != null) return AppColors.secondary; // instrument group
    switch (file.note) {
      case 'Sibelius':
        return const Color(0xFF6A1B9A);
      case 'Klavierauszug':
      case 'Partitur':
        return AppColors.success;
      case 'Chor':
        return AppColors.tertiary;
      default:
        // Ionic 4.17.16: "Chor (alle)" detected tolerantly
        return isChoirAllFile(instrumentId: id, note: file.note)
            ? AppColors.tertiary
            : AppColors.medium;
    }
  }

  /// Ionic `fileSortKey`: Aufnahme, Partitur, Sibelius, Liedtext, Chor,
  /// Klavierauszug, other notes, then groups in their configured order.
  static List<SongFile> sortedFiles(List<SongFile> files, List<Group> instruments) {
    String key(SongFile f) {
      final id = f.instrumentId;
      if (id == 1) return '0';
      if (id == null && f.note == 'Partitur') return '1';
      if (id == null && f.note == 'Sibelius') return '2';
      if (id == 2) return '3';
      if (isChoirAllFile(instrumentId: id, note: f.note)) return '4';
      if (id == null && f.note == 'Klavierauszug') return '5';
      if (id == null) return '6';
      final idx = instruments.indexWhere((g) => g.id == id);
      final order = idx < 0 ? 9999 : idx;
      return '7_${order.toString().padLeft(6, '0')}';
    }

    final copy = [...files];
    final keys = {for (final f in copy) f: key(f)};
    copy.sort((a, b) => keys[a]!.compareTo(keys[b]!));
    return copy;
  }

  /// Ionic `Utils.getInstrumentText`: "Ohne ..." text for missing groups.
  /// Categories missing completely are named by category.
  ///
  /// With [playerCounts] (active players per group) only groups somebody
  /// plays in count: a group nobody plays now (Celesta, an empty Violine 3)
  /// is not "missing" from a work. Without counts every group counts.
  static String missingInstrumentsText(
    List<int> instrumentIds,
    List<Group> groups,
    List<GroupCategory> groupCategories, {
    Map<int, int>? playerCounts,
  }) {
    final occupied = playerCounts == null || playerCounts.isEmpty
        ? null
        : {for (final e in playerCounts.entries) if (e.value > 0) e.key};
    final nonMain = groups
        .where((g) => g.maingroup != true && (occupied == null || occupied.contains(g.id)))
        .toList();
    final missing = nonMain.where((g) => !instrumentIds.contains(g.id)).toList();
    if (missing.isEmpty) return '';
    if (missing.length == 1) return l10nWithoutContext.commonWithout(missing.first.name);

    final byCategory = <int, List<Group>>{};
    for (final g in missing) {
      byCategory.putIfAbsent(g.categoryId ?? -1, () => []).add(g);
    }

    final fullCategories = <String>[];
    final individual = <Group>[];
    byCategory.forEach((catId, list) {
      final total = nonMain.where((g) => (g.categoryId ?? -1) == catId).length;
      if (list.length == total) {
        if (catId == -1) {
          fullCategories.add(l10nWithoutContext.commonOtherPlural);
        } else {
          fullCategories.add(
            groupCategories.where((c) => c.id == catId).firstOrNull?.name ??
                l10nWithoutContext.commonUnknown,
          );
        }
      } else {
        individual.addAll(list);
      }
    });

    final parts = [...fullCategories, ...individual.map((g) => g.name)];
    return l10nWithoutContext.commonWithout(formatList(parts));
  }

  /// Conjunction list ("a, b und c" / "a, b and c")
  static String formatList(List<String> items) {
    if (items.isEmpty) return '';
    if (items.length == 1) return items.first;
    return l10nWithoutContext.songsFlutterListAnd(items.sublist(0, items.length - 1).join(', '), items.last);
  }

  /// dd.MM.yyyy (Ionic `common.ngDate`)
  static String formatDate(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    return DateFormat(dateFmt()).format(d.toLocal());
  }

  /// Difficulty label (Ionic songs.easy/medium/hard)
  static String difficultyLabel(int? difficulty) {
    switch (difficulty) {
      case 1:
        return l10nWithoutContext.songsEasy;
      case 2:
        return l10nWithoutContext.songsMedium;
      case 3:
        return l10nWithoutContext.songsHard;
      default:
        return l10nWithoutContext.songsNotDefined;
    }
  }

  static Color difficultyColor(int? difficulty) {
    switch (difficulty) {
      case 1:
        return AppColors.success;
      case 2:
        return AppColors.warning;
      case 3:
        return AppColors.danger;
      default:
        return AppColors.medium;
    }
  }

  /// Ionic `isValidHttpUrl`
  static bool isValidHttpUrl(String link) {
    final uri = Uri.tryParse(link.trim());
    return uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
  }

  /// Public song sharing link (Ionic `getSongSharingLink`)
  static String shareLink(String sharingId, [int? songId]) =>
      songId == null
          ? 'https://attendix.de/$sharingId'
          : 'https://attendix.de/$sharingId/$songId';
}

/// Small colored badge like Ionic `ion-badge`
class SongBadge extends StatelessWidget {
  const SongBadge({super.key, required this.color, this.label, this.icon});

  final Color color;
  final String? label;
  final IconData? icon;

  /// Ionic `--ion-color-*-contrast`: black on warning / medium.
  static Color contrastOf(Color color) =>
      color == AppColors.warning || color == AppColors.medium
          ? Colors.black
          : Colors.white;

  @override
  Widget build(BuildContext context) {
    // Ionic ion-badge: iOS radius 10 / padding 3 8, md radius 4 / padding
    // 3 4; 13px bold, global `margin-left: .25rem`.
    final ios = Theme.of(context).platform == TargetPlatform.iOS;
    final fg = contrastOf(color);
    return Container(
      margin: const EdgeInsets.only(left: 4),
      padding: EdgeInsets.symmetric(horizontal: ios ? 8 : 4, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(ios ? 10 : 4),
      ),
      child: icon != null
          ? Icon(icon, size: 14, color: fg)
          : Text(
              label ?? '',
              // PARITY_R8: real bold (700) also on the web
              style: ionBadgeTextStyle(color: fg, height: 1.1),
            ),
    );
  }
}
