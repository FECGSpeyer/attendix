import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../l10n/l10n.dart';
import '../../shared/widgets/adaptive/adaptive.dart';
import '../config/supabase_config.dart';
import '../utils/toast_helper.dart';
import 'native/native_file_service.dart';

/// SharedPreferences key storing dismissed legacy calendar hit timestamps (ms).
const kIcalMigrationDismissedKey = 'icalMigrationDismissed';

/// After "Erledigt" the notice comes back only if the old address is still
/// fetched at least this long afterwards.
const kIcalMigrationReshowAfter = Duration(days: 2);

/// One entry returned by Supabase RPC `my_ical_legacy_hits`.
class LegacyIcalHit {
  const LegacyIcalHit({
    required this.fn,
    required this.query,
    required this.lastSeen,
  });

  factory LegacyIcalHit.fromJson(Map<String, dynamic> json) {
    final parsedDate = DateTime.tryParse(json['last_seen']?.toString() ?? '');
    return LegacyIcalHit(
      fn: json['fn']?.toString() ?? '',
      query: json['query']?.toString() ?? '',
      lastSeen: parsedDate ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }

  final String fn;
  final String query;
  final DateTime lastSeen;
}

/// Stable identifier per calendar subscription so multiple fetches from
/// different devices, languages or `hideExcused` toggles collapse to one notice.
String legacyIcalHitId(LegacyIcalHit hit) {
  final params = Uri(query: hit.query).queryParameters;
  return [
    hit.fn,
    params['tenantId'] ?? '',
    params['personId'] ?? '',
    params['key'] ?? '',
    params['detailed'] ?? '',
  ].join('|');
}

/// Keeps only the newest hit per calendar subscription, capped at 3 feeds.
List<LegacyIcalHit> uniqueLegacyIcalFeeds(List<LegacyIcalHit> hits) {
  final byFeed = <String, LegacyIcalHit>{};
  for (final hit in hits) {
    if (hit.fn.isEmpty) continue;
    final id = legacyIcalHitId(hit);
    final known = byFeed[id];
    if (known == null || hit.lastSeen.isAfter(known.lastSeen)) {
      byFeed[id] = hit;
    }
  }
  return byFeed.values.take(3).toList();
}

/// Filters [uniqueLegacyIcalFeeds] against previously dismissed timestamps.
List<LegacyIcalHit> filterOpenLegacyIcalHits(
  List<LegacyIcalHit> hits,
  Map<String, int> dismissedMs,
) {
  return uniqueLegacyIcalFeeds(hits).where((hit) {
    final id = legacyIcalHitId(hit);
    final dismissedAt = dismissedMs[id];
    if (dismissedAt == null) return true;
    return hit.lastSeen.millisecondsSinceEpoch >=
        dismissedAt + kIcalMigrationReshowAfter.inMilliseconds;
  }).toList();
}

/// Replacement subscription URL pointing to the current Attendix API host.
String legacyIcalReplacementLink(LegacyIcalHit hit, {String? baseUrl}) {
  final root = baseUrl ?? SupabaseConfig.supabaseUrl;
  return '$root/functions/v1/${hit.fn}?${hit.query}';
}

/// Checks once per app session via `my_ical_legacy_hits` whether the signed-in
/// user still uses old `supabase.co` calendar subscriptions and prompts them
/// with the new link (Ionic 4.19.18 / 4.19.22).
class IcalMigrationService {
  IcalMigrationService._();

  static final IcalMigrationService instance = IcalMigrationService._();

  bool _checked = false;

  bool get hasChecked => _checked;

  @visibleForTesting
  void reset() {
    _checked = false;
  }

  Future<void> checkOnce({
    required SupabaseClient supabase,
    required BuildContext? Function() contextResolver,
    SharedPreferences? prefs,
    String? baseUrl,
    Future<void> Function(Uri uri)? openGuide,
  }) async {
    if (_checked) return;
    _checked = true;

    try {
      final raw = await supabase.rpc('my_ical_legacy_hits');
      if (raw is! List || raw.isEmpty) return;

      final hits = raw
          .whereType<Map>()
          .map((e) => LegacyIcalHit.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      if (hits.isEmpty) return;

      final storage = prefs ?? await SharedPreferences.getInstance();
      final dismissed = _readDismissed(storage);
      final open = filterOpenLegacyIcalHits(hits, dismissed);
      if (open.isEmpty) return;

      final context = contextResolver();
      if (context == null || !context.mounted) return;

      await showIcalMigrationDialog(
        context,
        open,
        baseUrl: baseUrl,
        openGuide: openGuide,
        onDismissed: (ids) => _saveDismissed(storage, ids),
      );
    } catch (e) {
      debugPrint('[IcalMigration] check failed: $e');
    }
  }

  static Map<String, int> _readDismissed(SharedPreferences prefs) {
    try {
      final raw = prefs.getString(kIcalMigrationDismissedKey);
      if (raw == null || raw.isEmpty) return const {};
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const {};
      return {
        for (final entry in decoded.entries)
          if (entry.value is num) entry.key.toString(): (entry.value as num).toInt(),
      };
    } catch (_) {
      return const {};
    }
  }

  static Future<void> _saveDismissed(
    SharedPreferences prefs,
    List<String> ids,
  ) async {
    try {
      final all = Map<String, int>.from(_readDismissed(prefs));
      final now = DateTime.now().millisecondsSinceEpoch;
      for (final id in ids) {
        all[id] = now;
      }
      await prefs.setString(kIcalMigrationDismissedKey, jsonEncode(all));
    } catch (_) {}
  }
}

/// Shows the non-dismissible migration notice dialog for affected calendar feeds.
Future<void> showIcalMigrationDialog(
  BuildContext context,
  List<LegacyIcalHit> hits, {
  required Future<void> Function(List<String> ids) onDismissed,
  String? baseUrl,
  Future<void> Function(Uri uri)? openGuide,
}) {
  final links = [
    for (final hit in hits) legacyIcalReplacementLink(hit, baseUrl: baseUrl),
  ];
  final isIos = Theme.of(context).platform == TargetPlatform.iOS;
  final numberedLinks = [
    for (var i = 0; i < links.length; i++) '${i + 1}. ${links[i]}',
  ].join('\n\n');

  return showAppDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      Future<void> copy(String link) async {
        try {
          await Clipboard.setData(ClipboardData(text: link));
        } catch (_) {
          if (ctx.mounted) {
            ToastHelper.showError(ctx, ctx.l10n.settingsFlutterCopyLinkFailed);
          }
          return;
        }
        if (ctx.mounted) {
          ToastHelper.showSuccess(ctx, ctx.l10n.settingsLinkCopied);
        }
      }

      Future<void> launchGuide() async {
        final uri = Uri.parse(
          isIos
              ? 'https://support.apple.com/de-de/102301'
              : 'https://support.google.com/calendar/answer/37100?hl=de&co=GENIE.Platform%3DAndroid',
        );
        try {
          await (openGuide ?? NativeFileService.openLinkInApp)(uri);
        } catch (_) {}
      }

      return AppAlertDialog(
        title: Text(ctx.l10n.icalMigrationHeader),
        content: SingleChildScrollView(
          child: SelectableText(
            links.length == 1
                ? ctx.l10n.icalMigrationMessage(links.first)
                : ctx.l10n.icalMigrationMessageMultiple(numberedLinks),
          ),
        ),
        actions: [
          if (links.length == 1)
            TextButton(
              onPressed: () => copy(links.first),
              child: Text(ctx.l10n.settingsCopyLink),
            )
          else
            for (var i = 0; i < links.length; i++)
              TextButton(
                onPressed: () => copy(links[i]),
                child: Text(ctx.l10n.icalMigrationCopyLinkN(i + 1)),
              ),
          TextButton(
            onPressed: launchGuide,
            child: Text(ctx.l10n.settingsOpenGuide),
          ),
          TextButton(
            onPressed: () async {
              await onDismissed(hits.map(legacyIcalHitId).toList());
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
            child: Text(ctx.l10n.icalMigrationDone),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(ctx.l10n.svcLater),
          ),
        ],
      );
    },
  );
}
