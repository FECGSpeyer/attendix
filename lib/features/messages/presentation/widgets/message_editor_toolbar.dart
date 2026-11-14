import 'package:flutter/material.dart';
import 'package:attendix/core/theme/app_icons.dart';
import 'package:flutter_quill/flutter_quill.dart';

import '../../../../core/theme/redesign/rd_theme.dart' show RdSkinContext;
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';

/// Toolbar of the message editor (Ionic `app-message-editor`): B I U S,
/// heading, lists, then the link button with Ionic's "Link" alert and the
/// undo button "↶" at the end. Used by "Nachricht verfassen" and the
/// auto-message rule page.
class MessageEditorToolbar extends StatelessWidget {
  const MessageEditorToolbar({super.key, required this.controller});

  final QuillController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // EIB-20: the classic design gets Ionic's own glyph toolbar; the Beta
    // keeps the stock Quill toolbar.
    if (context.rdSkin == null) return _IonEditorToolbar(controller: controller);
    return QuillSimpleToolbar(
      controller: controller,
      config: QuillSimpleToolbarConfig(
        multiRowsDisplay: false,
        showBoldButton: true,
        showItalicButton: true,
        showUnderLineButton: true,
        showStrikeThrough: true,
        showHeaderStyle: true,
        showListBullets: true,
        showListNumbers: true,
        // Link and undo come as custom buttons (Ionic order: … | 🔗 ↶).
        showLink: false,
        showListCheck: false,
        showColorButton: false,
        showBackgroundColorButton: false,
        showClearFormat: false,
        showInlineCode: false,
        showCodeBlock: false,
        showQuote: false,
        showIndent: false,
        showSearchButton: false,
        showSubscript: false,
        showSuperscript: false,
        showFontFamily: false,
        showFontSize: false,
        showAlignmentButtons: false,
        showDirection: false,
        showSmallButton: false,
        showUndo: false,
        showRedo: false,
        customButtons: [
          QuillToolbarCustomButtonOptions(
            icon: Icon(AppIcons.link),
            tooltip: l10n.editorLink,
            onPressed: () => editMessageLink(context, controller),
          ),
          QuillToolbarCustomButtonOptions(
            icon: Icon(AppIcons.undo),
            tooltip: l10n.editorUndo,
            onPressed: () {
              if (controller.hasUndo) controller.undo();
            },
          ),
        ],
      ),
    );
  }
}

/// Ionic `app-message-editor` `.toolbar`: wrapping row of 34 px text-glyph
/// buttons "B I U S | H •≡ 1≡ | 🔗 ↶" (radius 6, 15 px text, gap 2,
/// padding 6), active = primary at 15 % behind primary text, step-50
/// background with a step-150 bottom border. "H" toggles heading 2.
class _IonEditorToolbar extends StatelessWidget {
  const _IonEditorToolbar({required this.controller});

  final QuillController controller;

  static Color _step(BuildContext context, int step) {
    final scheme = Theme.of(context).colorScheme;
    return Color.lerp(scheme.surface, scheme.onSurface, step / 1000)!;
  }

  void _toggle(Attribute attribute, bool active) {
    controller.formatSelection(active ? Attribute.clone(attribute, null) : attribute);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final line = _step(context, 150);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final attrs = controller.getSelectionStyle().attributes;
        bool has(Attribute a) => attrs[a.key]?.value != null;
        final list = attrs[Attribute.list.key]?.value;
        final heading = attrs[Attribute.header.key]?.value != null;
        Widget sep() => Container(
              width: 1,
              height: 22,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              color: line,
            );
        return Semantics(
          container: true,
          label: l10n.editorFormatting,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: _step(context, 50),
              border: Border(bottom: BorderSide(color: line)),
            ),
            child: Wrap(
              spacing: 2,
              runSpacing: 2,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _GlyphButton(
                  label: l10n.editorBold,
                  active: has(Attribute.bold),
                  onPressed: () => _toggle(Attribute.bold, has(Attribute.bold)),
                  child: const Text('B', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                _GlyphButton(
                  label: l10n.editorItalic,
                  active: has(Attribute.italic),
                  onPressed: () => _toggle(Attribute.italic, has(Attribute.italic)),
                  child: const Text('I', style: TextStyle(fontStyle: FontStyle.italic)),
                ),
                _GlyphButton(
                  label: l10n.editorUnderline,
                  active: has(Attribute.underline),
                  onPressed: () => _toggle(Attribute.underline, has(Attribute.underline)),
                  child: const Text('U', style: TextStyle(decoration: TextDecoration.underline)),
                ),
                _GlyphButton(
                  label: l10n.editorStrike,
                  active: has(Attribute.strikeThrough),
                  onPressed: () => _toggle(Attribute.strikeThrough, has(Attribute.strikeThrough)),
                  child: const Text('S', style: TextStyle(decoration: TextDecoration.lineThrough)),
                ),
                sep(),
                _GlyphButton(
                  label: l10n.editorHeading,
                  active: heading,
                  onPressed: () => controller.formatSelection(
                    heading ? Attribute.clone(Attribute.header, null) : Attribute.h2,
                  ),
                  child: const Text('H'),
                ),
                _GlyphButton(
                  label: l10n.editorBulletList,
                  active: list == Attribute.ul.value,
                  onPressed: () => _toggle(Attribute.ul, list == Attribute.ul.value),
                  child: const Text('\u2022\u2261'),
                ),
                _GlyphButton(
                  label: l10n.editorOrderedList,
                  active: list == Attribute.ol.value,
                  onPressed: () => _toggle(Attribute.ol, list == Attribute.ol.value),
                  child: const Text('1\u2261'),
                ),
                sep(),
                _GlyphButton(
                  label: l10n.editorLink,
                  active: has(Attribute.link),
                  onPressed: () => editMessageLink(context, controller),
                  child: const Text('\u{1F517}'),
                ),
                _GlyphButton(
                  label: l10n.editorUndo,
                  active: false,
                  onPressed: () {
                    if (controller.hasUndo) controller.undo();
                  },
                  child: const Text('\u21B6'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _GlyphButton extends StatelessWidget {
  const _GlyphButton({
    required this.label,
    required this.active,
    required this.onPressed,
    required this.child,
  });

  final String label;
  final bool active;
  final VoidCallback onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final color = active ? primary : theme.colorScheme.onSurface;
    return Semantics(
      button: true,
      selected: active,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: active ? primary.withValues(alpha: 0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          // Like Ionic's `mousedown.preventDefault()`: keep the editor focus.
          canRequestFocus: false,
          borderRadius: BorderRadius.circular(6),
          onTap: onPressed,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 34, minHeight: 34, maxHeight: 34),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Center(
                widthFactor: 1,
                child: DefaultTextStyle.merge(
                  style: TextStyle(fontSize: 15, color: color, height: 1),
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Ionic `MessageEditorComponent.editLink()`: alert "Link" with the URL
/// (placeholder "https://…", prefilled with the current link) and – only
/// without a selection and outside a link – "Angezeigter Text (optional)".
/// Buttons "Abbrechen", "Entfernen" (only on an existing link) and
/// "Übernehmen". A URL without scheme gets `https://`.
Future<void> editMessageLink(BuildContext context, QuillController controller) async {
  final current = controller.getSelectionStyle().attributes[Attribute.link.key]?.value as String?;
  final selection = controller.selection;
  final hasSelection = !selection.isCollapsed;
  final hasLink = current != null && current.isNotEmpty;

  final result = await showAppDialog<_LinkResult>(
    context: context,
    builder: (_) => _LinkDialog(
      initialUrl: current ?? '',
      showText: !hasSelection && !hasLink,
      canRemove: hasLink,
    ),
  );
  if (result == null) return;

  // Range of the link under the cursor (Tiptap `extendMarkRange('link')`).
  var index = selection.start;
  var length = selection.end - selection.start;
  if (hasLink) {
    // The selection style already counts the link when the cursor sits
    // right behind it at the end of a line, but the leaf lookup there finds
    // nothing (or the next, unlinked leaf) – take the leaf before the cursor.
    bool isLink(Leaf? l) => l?.style.attributes[Attribute.link.key] != null;
    var leaf = controller.document.querySegmentLeafNode(index).leaf;
    if (!isLink(leaf) && index > 0) {
      leaf = controller.document.querySegmentLeafNode(index - 1).leaf;
    }
    if (leaf != null && isLink(leaf)) {
      final range = getLinkRange(leaf);
      index = range.start;
      length = range.end - range.start;
    }
  }

  if (result.remove) {
    controller.formatText(index, length, const LinkAttribute(null));
    return;
  }
  final url = normalizeMessageLink(result.url);
  if (url == null) return;
  if (hasSelection || hasLink) {
    controller.formatText(index, length, LinkAttribute(url));
  } else {
    final text = result.text.trim().isEmpty ? url : result.text.trim();
    controller
      ..replaceText(index, 0, text, null)
      ..formatText(index, text.length, LinkAttribute(url))
      ..updateSelection(
        TextSelection.collapsed(offset: index + text.length),
        ChangeSource.local,
      );
  }
}

/// Trimmed URL, `https://` prepended when it has no http(s)/mailto/tel
/// scheme (Ionic). Null for an empty input.
String? normalizeMessageLink(String raw) {
  final url = raw.trim();
  if (url.isEmpty) return null;
  if (RegExp(r'^(https?:|mailto:|tel:)', caseSensitive: false).hasMatch(url)) return url;
  return 'https://$url';
}

class _LinkResult {
  const _LinkResult({this.url = '', this.text = '', this.remove = false});
  final String url;
  final String text;
  final bool remove;
}

class _LinkDialog extends StatefulWidget {
  const _LinkDialog({
    required this.initialUrl,
    required this.showText,
    required this.canRemove,
  });

  final String initialUrl;
  final bool showText;
  final bool canRemove;

  @override
  State<_LinkDialog> createState() => _LinkDialogState();
}

class _LinkDialogState extends State<_LinkDialog> {
  late final _url = TextEditingController(text: widget.initialUrl);
  final _text = TextEditingController();

  @override
  void dispose() {
    _url.dispose();
    _text.dispose();
    super.dispose();
  }

  void _apply() => Navigator.of(context).pop(_LinkResult(url: _url.text, text: _text.text));
  void _remove() => Navigator.of(context).pop(const _LinkResult(remove: true));
  void _cancel() => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    const urlHint = 'https://…';
    if (useIosLook(context)) {
      return IosAlertCard(
        title: Text(l10n.editorLink),
        // ios27 `.alert-message:empty { padding: 0 0 12px }` above the inputs
        // (Beta keeps its spacing).
        contentPadding: EdgeInsets.fromLTRB(16, context.rdSkin == null ? 12 : 0, 16, 21),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            IosAlertInput(
              controller: _url,
              placeholder: urlHint,
              keyboardType: TextInputType.url,
              autofocus: true,
              onSubmitted: widget.showText ? null : (_) => _apply(),
            ),
            if (widget.showText)
              IosAlertInput(
                controller: _text,
                placeholder: l10n.editorLinkText,
                onSubmitted: (_) => _apply(),
              ),
          ],
        ),
        actions: [
          IosAlertButton(onPressed: _cancel, child: Text(l10n.commonCancel)),
          if (widget.canRemove)
            IosAlertButton(onPressed: _remove, destructive: true, child: Text(l10n.commonRemove)),
          IosAlertButton(onPressed: _apply, child: Text(l10n.commonApply)),
        ],
      );
    }
    return AppAlertDialog(
      title: Text(l10n.editorLink),
      // md: the shared underlined alert inputs.
      content: AppAlertInputGroup(
        betaCrossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppAlertInput(
            controller: _url,
            keyboardType: TextInputType.url,
            autofocus: true,
            placeholder: urlHint,
          ),
          if (widget.showText)
            AppAlertInput(
              controller: _text,
              placeholder: l10n.editorLinkText,
            ),
        ],
      ),
      actions: [
        TextButton(onPressed: _cancel, child: Text(l10n.commonCancel)),
        if (widget.canRemove)
          TextButton(
            onPressed: _remove,
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            child: Text(l10n.commonRemove),
          ),
        TextButton(onPressed: _apply, child: Text(l10n.commonApply)),
      ],
    );
  }
}
