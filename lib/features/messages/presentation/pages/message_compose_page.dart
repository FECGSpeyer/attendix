import 'package:flutter/material.dart';

import '../../../redesign/presentation/pages/rd_message_compose_page.dart';

/// Opens the full-screen compose dialog. Returns the new message id when sent.
/// [preset]: fixed recipients and prefilled text.
Future<String?> openMessageCompose(BuildContext context, {MessageComposePreset? preset}) {
  return Navigator.of(context, rootNavigator: true).push<String>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => RdMessageComposePage(preset: preset),
    ),
  );
}

/// Preset mode of the compose dialog: fixed recipients, prefilled text, linked
/// to the Termin so recipients can answer. No draft is saved.
class MessageComposePreset {
  const MessageComposePreset({
    required this.playerIds,
    required this.recipientsLabel,
    required this.title,
    required this.content,
    this.attendanceId,
    this.allowResponses = false,
  });

  final List<int> playerIds;
  final String recipientsLabel;
  final String title;

  /// Tiptap document.
  final Map<String, dynamic> content;
  final int? attendanceId;
  final bool allowResponses;
}
