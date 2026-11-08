import 'package:flutter/material.dart';

import '../../../../../core/theme/redesign/rd_palette.dart';
import '../../../../../core/theme/redesign/rd_theme.dart';
import '../../../../../l10n/l10n.dart';
import '../rd_widgets.dart' show RdTextLink;

/// REDESIGN: form parts of "Neuer Termin" and "Termin bearbeiten".

/// Borderless text field inside a [RdFieldRow].
InputDecoration rdInputDecoration(RdPalette p, String hint) => InputDecoration(
      isDense: true,
      filled: false,
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      disabledBorder: InputBorder.none,
      contentPadding: const EdgeInsets.only(top: 4, bottom: 2),
      hintText: hint,
      hintStyle: TextStyle(color: p.text2),
    );

/// Scrolling content of the page (max width on tablets).
class RdFormBody extends StatelessWidget {
  const RdFormBody({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => ListView(
        padding: EdgeInsets.fromLTRB(16, 4, 16, 32 + MediaQuery.paddingOf(context).bottom),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
            ),
          ),
        ],
      );
}

/// Top bar of the Beta edit pages that save right away (Termin, Werk,
/// Gruppe, Person bearbeiten): the title in the middle, "Fertig" on the
/// right, no "Abbrechen" (nothing to discard).
class RdEditTopBar extends StatelessWidget {
  const RdEditTopBar({super.key, required this.title, required this.onDone, this.doneKey, this.leading});

  final String title;
  final VoidCallback onDone;
  final Key? doneKey;

  /// Optional status on the left (e.g. "Gespeichert"), at most 88 wide.
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
      child: Row(
        children: [
          SizedBox(width: 88, child: leading),
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: p.text),
              ),
            ),
          ),
          SizedBox(
            width: 88,
            child: Align(
              alignment: Alignment.centerRight,
              child: RdTextLink(key: doneKey, label: context.l10n.redesignCommonDone, onTap: onDone),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Abbrechen · Neuer Termin · Anlegen".
class RdFormTopBar extends StatelessWidget {
  const RdFormTopBar({
    super.key,
    required this.title,
    required this.cancel,
    required this.submit,
    required this.saving,
    required this.onCancel,
    required this.onSubmit,
    this.submitKey,
  });

  final String title;
  final String cancel;
  final String submit;

  /// Key of the submit link (the only submit of the page).
  final Key? submitKey;
  final bool saving;
  final VoidCallback? onCancel;
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    Widget link(String label, VoidCallback? onTap, {bool bold = false}) => Semantics(
          button: true,
          enabled: onTap != null,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Center(
                  widthFactor: 1,
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
                      color: onTap == null ? p.text2 : p.link,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
      child: Row(
        children: [
          link(cancel, onCancel),
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: p.text),
              ),
            ),
          ),
          if (saving)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: p.primary),
              ),
            )
          else
            KeyedSubtree(key: submitKey, child: link(submit, onSubmit, bold: true)),
        ],
      ),
    );
  }
}

/// A text field row with a small label above ("Titel", "Ort").
class RdFieldRow extends StatelessWidget {
  const RdFieldRow({super.key, required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: RdType.meta(context.rd, size: 12)),
            child,
          ],
        ),
      );
}

/// Grey value box (date, time) like the canvas.
class RdValueBox extends StatelessWidget {
  const RdValueBox(this.text, {super.key, this.onTap, this.semantics});

  final String text;
  final VoidCallback? onTap;
  final String? semantics;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final box = Container(
      constraints: const BoxConstraints(minHeight: 36),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(color: p.track, borderRadius: BorderRadius.circular(8)),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 15, color: p.text, fontFeatures: const [FontFeature.tabularFigures()]),
      ),
    );
    if (onTap == null) return Flexible(child: box);
    return Semantics(
      button: true,
      label: semantics == null ? null : '$semantics $text',
      excludeSemantics: semantics != null,
      child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(8), child: box),
    );
  }
}

/// A place used before ("Gemeindesaal"), fills the Ort field.
class RdPlaceChip extends StatelessWidget {
  const RdPlaceChip(this.place, {super.key, required this.onTap});

  final String place;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    return Semantics(
      button: true,
      child: Material(
        color: p.track,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 32),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Text(place, style: TextStyle(fontSize: 13, color: p.text)),
            ),
          ),
        ),
      ),
    );
  }
}
