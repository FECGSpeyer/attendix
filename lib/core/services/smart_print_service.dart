import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:printing/printing.dart';

import '../providers/group_providers.dart';
import '../providers/player_providers.dart';
import '../../data/models/instrument/instrument.dart';
import '../../l10n/l10n.dart';

/// Model for print copy information per instrument
class PrintCopyInfo {
  final Group group;
  final int playerCount;
  int copies;

  PrintCopyInfo({
    required this.group,
    required this.playerCount,
    int? copies,
  }) : copies = copies ?? playerCount;

  /// Creates a copy with updated values
  PrintCopyInfo copyWith({int? copies}) {
    return PrintCopyInfo(
      group: group,
      playerCount: playerCount,
      copies: copies ?? this.copies,
    );
  }
}

/// Service for smart printing with instrument-based copy calculation
class SmartPrintService {
  final Ref _ref;

  SmartPrintService(this._ref);

  /// Get print copy info for all instruments
  /// If instrumentId is provided, only that instrument is included
  /// Otherwise, all instruments with players are included
  Future<List<PrintCopyInfo>> getPrintCopyInfo({int? instrumentId}) async {
    final playerCounts = await _ref.read(playerCountByInstrumentProvider.future);
    final groups = await _ref.read(groupsProvider.future);

    final result = <PrintCopyInfo>[];

    if (instrumentId != null) {
      // Single instrument mode
      final group = groups.firstWhere(
        (g) => g.id == instrumentId,
        orElse: () => Group(id: instrumentId, name: l10nWithoutContext.commonUnknown),
      );
      final count = playerCounts[instrumentId] ?? 1;
      result.add(PrintCopyInfo(
        group: group,
        playerCount: count,
      ));
    } else {
      // All instruments mode
      for (final group in groups) {
        if (group.id == null) continue;
        final count = playerCounts[group.id!];
        if (count == null || count == 0) continue;

        result.add(PrintCopyInfo(
          group: group,
          playerCount: count,
        ));
      }

      // Sort by group order or name
      result.sort((a, b) {
        final orderA = a.group.index ?? 999;
        final orderB = b.group.index ?? 999;
        if (orderA != orderB) return orderA.compareTo(orderB);
        return a.group.name.compareTo(b.group.name);
      });
    }

    return result;
  }

  /// Print a PDF with the specified number of copies per section
  Future<void> printPdf({
    required String url,
    required List<PrintCopyInfo> copyInfos,
    String? fileName,
  }) async {
    // Download PDF
    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) {
      throw Exception(l10nWithoutContext.coreFlutterPdfLoadFailed(response.statusCode));
    }

    final pdfData = response.bodyBytes;

    // Calculate total copies
    final totalCopies = copyInfos.fold<int>(0, (sum, info) => sum + info.copies);

    if (totalCopies == 0) {
      throw Exception(l10nWithoutContext.coreFlutterNoCopiesSelected);
    }

    // Print using the printing package
    // Note: The printing package handles the print dialog natively
    await Printing.layoutPdf(
      onLayout: (_) async => pdfData,
      name: fileName ?? l10nWithoutContext.coreFlutterSheetMusic,
    );
  }

  /// Print a PDF with a specific number of copies
  Future<void> printPdfWithCopies({
    required String url,
    required int copies,
    String? fileName,
  }) async {
    if (copies <= 0) {
      throw Exception(l10nWithoutContext.coreFlutterInvalidCopyCount);
    }

    // Download PDF
    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) {
      throw Exception(l10nWithoutContext.coreFlutterPdfLoadFailed(response.statusCode));
    }

    final pdfData = response.bodyBytes;

    // Print using the printing package
    await Printing.layoutPdf(
      onLayout: (_) async => pdfData,
      name: fileName ?? l10nWithoutContext.coreFlutterSheetMusic,
    );
  }
}

/// Provider for SmartPrintService
final smartPrintServiceProvider = Provider<SmartPrintService>((ref) {
  return SmartPrintService(ref);
});
