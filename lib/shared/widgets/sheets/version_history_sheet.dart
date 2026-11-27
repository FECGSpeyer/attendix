import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../data/models/version_history/version_history.dart';
import '../../../core/theme/redesign/rd_theme.dart';
import '../redesign/rd_widgets.dart';
import '../../../l10n/l10n.dart';
import '../../../core/utils/error_message.dart';
import '../adaptive/adaptive.dart';

/// User-facing version history ("Was ist neu"): the continued Ionic history
/// with the store versions, topmost entry = [AppConstants.displayVersion].
/// The internal 0.x history (`assets/version_history.json`) is not shown.
const versionHistoryUserAsset = 'assets/version_history_user.json';

/// Bottom sheet showing version history (What's New)
class VersionHistorySheet extends StatefulWidget {
  const VersionHistorySheet({super.key});

  @override
  State<VersionHistorySheet> createState() => _VersionHistorySheetState();
}

class _VersionHistorySheetState extends State<VersionHistorySheet> {
  VersionHistory? _versionHistory;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadVersionHistory();
  }

  Future<void> _loadVersionHistory() async {
    try {
      final jsonString = await rootBundle.loadString(versionHistoryUserAsset);
      final jsonData = json.decode(jsonString) as Map<String, dynamic>;
      if (mounted) {
        setState(() {
          _versionHistory = VersionHistory.fromJson(jsonData);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = friendlyErrorMessage(e);
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final versions = _versionHistory?.versions ?? const <VersionEntry>[];
    final Widget body;
    if (_isLoading) {
      body = const Padding(padding: EdgeInsets.all(32), child: Center(heightFactor: 1, child: AppSpinner()));
    } else if (_error != null || versions.isEmpty) {
      body = Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          _error != null ? l10n.coreFlutterErrorWith('$_error') : l10n.coreFlutterNoVersionHistory,
          style: RdType.meta(p, size: 15),
          textAlign: TextAlign.center,
        ),
      );
    } else {
      body = ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          for (final v in versions) ...[
            RdGroupLabel(v.date != null ? '${v.version} · ${v.date}' : v.version),
            RdGroupedList(
              children: [
                for (final change in v.changes)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Text(change, style: RdType.body(p)),
                  ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ],
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RdSheetTitle(l10n.redesignMeWhatsNew),
        Flexible(child: body),
      ],
    );
  }
}

/// Shows the version history sheet as a bottom sheet
Future<void> showVersionHistorySheet(BuildContext context) =>
    showRdSheet<void>(context, const VersionHistorySheet());
