import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/instrument/instrument.dart';
import '../../../../data/models/song/song.dart';

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

  /// Label of a file category (Ionic `getInstrumentName`)
  static String fileLabel(SongFile file, List<Group> instruments) {
    final id = file.instrumentId;
    if (id == null || id == 0) return file.note ?? 'Sonstige';
    if (id == 1) return 'Aufnahme';
    if (id == 2) return 'Liedtext';
    for (final g in instruments) {
      if (g.id == id) return g.name;
    }
    return 'Unbekannt';
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
        return AppColors.medium;
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
      if (id == null && f.note == 'Chor') return '4';
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
  static String missingInstrumentsText(
    List<int> instrumentIds,
    List<Group> groups,
    List<GroupCategory> groupCategories,
  ) {
    final nonMain = groups.where((g) => g.maingroup != true).toList();
    final missing = nonMain.where((g) => !instrumentIds.contains(g.id)).toList();
    if (missing.isEmpty) return '';
    if (missing.length == 1) return 'Ohne ${missing.first.name}';

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
          fullCategories.add('Sonstige');
        } else {
          fullCategories.add(
            groupCategories.where((c) => c.id == catId).firstOrNull?.name ??
                'Unbekannt',
          );
        }
      } else {
        individual.addAll(list);
      }
    });

    final parts = [...fullCategories, ...individual.map((g) => g.name)];
    return 'Ohne ${formatList(parts)}';
  }

  /// German conjunction list ("a, b und c")
  static String formatList(List<String> items) {
    if (items.isEmpty) return '';
    if (items.length == 1) return items.first;
    return '${items.sublist(0, items.length - 1).join(', ')} und ${items.last}';
  }

  /// dd.MM.yyyy (Ionic `common.ngDate`)
  static String formatDate(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    return DateFormat('dd.MM.yyyy').format(d.toLocal());
  }

  /// Difficulty label (Ionic songs.easy/medium/hard)
  static String difficultyLabel(int? difficulty) {
    switch (difficulty) {
      case 1:
        return '1 - Leicht';
      case 2:
        return '2 - Mittel';
      case 3:
        return '3 - Schwer';
      default:
        return 'Nicht definiert';
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

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: icon != null
          ? Icon(icon, size: 14, color: Colors.white)
          : Text(
              label ?? '',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
    );
  }
}
