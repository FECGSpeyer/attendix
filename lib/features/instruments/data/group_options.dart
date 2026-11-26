import '../../../l10n/l10n.dart';

/// Tuning options for instruments.
const groupTuningOptions = ['C', 'Es', 'B', 'F'];

/// Clef options.
const groupClefOptions = ['G', 'F', 'C'];

/// Localized clef name (`common.clef.*`).
String groupClefLabel(AppLocalizations l10n, String clef) =>
    switch (clef.toUpperCase()) {
      'G' => l10n.commonClefG,
      'F' => l10n.commonClefF,
      'C' => l10n.commonClefC,
      _ => l10n.instrumentsFlutterClef(clef.toUpperCase()),
    };
