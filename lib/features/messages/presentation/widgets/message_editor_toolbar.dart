import 'package:flutter/material.dart';
import 'package:attendix/core/theme/app_icons.dart';
import 'package:flutter_quill/flutter_quill.dart';

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
        contentPadding: const EdgeInsets.fromLTRB(16, 0, 16, 21),
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
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _url,
            keyboardType: TextInputType.url,
            autofocus: true,
            decoration: const InputDecoration(hintText: urlHint),
          ),
          if (widget.showText)
            TextField(
              controller: _text,
              decoration: InputDecoration(hintText: l10n.editorLinkText),
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
