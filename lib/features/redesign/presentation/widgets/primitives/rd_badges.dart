import 'package:flutter/material.dart';

import '../../../../../core/theme/redesign/rd_palette.dart';
import '../../../../../core/theme/redesign/rd_theme.dart';
import '../../../../../l10n/l10n.dart';

/// Design-system badges, pills, avatars, date tiles, and section headers.

/// Tone of a count badge.
enum RdTone { primary, present, late, excused, absent }

extension RdToneColors on RdPalette {
  Color toneColor(RdTone tone) => switch (tone) {
        RdTone.primary => softText,
        RdTone.present => present,
        RdTone.late => late,
        RdTone.excused => excused,
        RdTone.absent => absent,
      };

  Color toneSoft(RdTone tone) => switch (tone) {
        RdTone.primary => soft,
        RdTone.present => presentSoft,
        RdTone.late => lateSoft,
        RdTone.excused => excusedSoft,
        RdTone.absent => absentSoft,
      };
}

/// Square number badge in front of a hint row ("3").
class RdCountBadge extends StatelessWidget {
  const RdCountBadge(this.count, {super.key, this.tone = RdTone.primary});

  final int count;
  final RdTone tone;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: p.toneSoft(tone),
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: Text(
        count > 99 ? '99+' : '$count',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: p.toneColor(tone),
        ),
      ),
    );
  }
}

/// Small rounded label ("in 2 Std.", "Dabei", "Offen").
class RdPill extends StatelessWidget {
  const RdPill(this.label, {super.key, this.tone, this.icon});

  final String label;

  /// null = neutral grey.
  final RdTone? tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final fg = tone == null ? p.text2 : p.toneColor(tone!);
    final bg = tone == null ? p.track : p.toneSoft(tone!);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: fg),
            ),
          ),
        ],
      ),
    );
  }
}

/// Uppercase eyebrow above a card title ("NÄCHSTER TERMIN · HEUTE").
class RdEyebrow extends StatelessWidget {
  const RdEyebrow(this.text, {super.key, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: RdType.eyebrow(color ?? context.rd.softText),
    );
  }
}

/// Section heading with an optional action on the right ("Alle").
class RdSectionHeader extends StatelessWidget {
  const RdSectionHeader(this.title, {super.key, this.action, this.trailing});

  final String title;
  final Widget? action;

  /// Grey text on the right ("Geburtstag: Lea (Sa)").
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(title, style: RdType.section(p)),
            ),
          ),
          if (trailing != null)
            Flexible(
              child: Text(
                trailing!,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: RdType.meta(p, size: 13),
              ),
            ),
          if (action != null) action!,
        ],
      ),
    );
  }
}

/// Uppercase group label above a list ("FARBWELT").
class RdGroupLabel extends StatelessWidget {
  const RdGroupLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
      child: Semantics(
        header: true,
        child: Text(text.toUpperCase(), style: RdType.eyebrow(context.rd.text2)),
      ),
    );
  }
}

/// Date tile of a list row ("SA" over "1").
class RdDateTile extends StatelessWidget {
  const RdDateTile({
    super.key,
    required this.weekday,
    required this.day,
    this.highlight = false,
  });

  final String weekday;
  final String day;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    return Container(
      width: 44,
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: highlight ? p.soft : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            weekday.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: highlight ? p.softText : p.text2,
            ),
          ),
          Text(
            day,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: highlight ? p.softText : p.text,
            ),
          ),
        ],
      ),
    );
  }
}

/// Round initials avatar.
class RdInitials extends StatelessWidget {
  const RdInitials(
    this.initials, {
    super.key,
    this.size = 40,
    this.square = false,
    this.filled = false,
  });

  final String initials;
  final double size;

  /// Rounded square (group logo) instead of a circle.
  final bool square;

  /// Primary background (group chip) instead of the soft tint.
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: filled ? p.primary : p.soft,
        shape: square ? BoxShape.rectangle : BoxShape.circle,
        borderRadius: square ? BorderRadius.circular(size * 0.28) : null,
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          fontSize: size * 0.4,
          fontWeight: FontWeight.w700,
          color: filled ? p.onPrimary : p.softText,
        ),
      ),
    );
  }
}

/// Initials of a name ("Leon Jäger" → "LJ", "Stadtorchester" → "ST").
String rdInitialsOf(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) {
    final w = parts.first;
    return (w.length >= 2 ? w.substring(0, 2) : w).toUpperCase();
  }
  return (parts.first[0] + parts[1][0]).toUpperCase();
}

/// Small "Stimmführung" tag next to a name (Mitglieder, Meine Stimme).
class RdLeaderTag extends StatelessWidget {
  const RdLeaderTag({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: p.soft, borderRadius: BorderRadius.circular(6)),
      child: Text(
        context.l10n.redesignMembersLeader,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: p.softText),
      ),
    );
  }
}
