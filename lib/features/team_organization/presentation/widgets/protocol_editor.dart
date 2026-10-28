import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/team_org/team_org.dart';
import '../../tiptap_delta.dart';

/// "📋 Titel · Offen" / "✅ Titel · Erledigt" (Ionic `taskRefText`); [status]
/// is the live status when known.
String taskRefText(String title, String? status) {
  final label = switch (status) {
    'open' => 'Offen',
    'in_progress' => 'In Arbeit',
    'completed' => 'Erledigt',
    _ => status ?? '',
  };
  if (label.isEmpty) return '📋 $title';
  return '${status == 'completed' ? '✅' : '📋'} $title · $label';
}

const _priorityLabels = {'low': 'Niedrig', 'medium': 'Mittel', 'high': 'Hoch'};
const _topicStatusLabels = {'open': 'Offen', 'completed': 'Erledigt', 'dropped': 'Verworfen'};

/// "📋 Titel · Offen · Mittel" (Ionic AgendaItemNode).
String agendaRefText(Map<String, dynamic> attrs) {
  final status = attrs['status']?.toString();
  final priority = attrs['priority']?.toString();
  return [
    '📋 ${attrs['title'] ?? ''}',
    if (status != null) _topicStatusLabels[status] ?? status,
    if (priority != null) _priorityLabels[priority] ?? priority,
  ].join(' · ');
}

/// Inserts a reference node (task / topic) as a block embed on its own line
/// at the cursor (end of the document without a cursor).
void insertRefEmbed(QuillController controller, String type, Map<String, dynamic> attrs) {
  final docLength = controller.document.length; // includes the final newline
  var index = controller.selection.baseOffset;
  if (index < 0 || index > docLength - 1) index = docLength - 1;
  String charAt(int i) {
    final text = controller.document.toPlainText();
    return i >= 0 && i < text.length ? text[i] : '\n';
  }

  if (index > 0 && charAt(index - 1) != '\n') {
    controller.replaceText(index, 0, '\n', null);
    index++;
  }
  controller.replaceText(index, 0, BlockEmbed(type, jsonEncode(attrs)), null);
  if (charAt(index + 1) != '\n') controller.replaceText(index + 1, 0, '\n', null);
  controller.updateSelection(
    TextSelection.collapsed(offset: (index + 2).clamp(0, controller.document.length - 1)),
    ChangeSource.local,
  );
}

Map<String, dynamic> _embedAttrs(Embed node) {
  final data = node.value.data;
  try {
    final decoded = data is String ? jsonDecode(data) : data;
    return decoded is Map ? Map<String, dynamic>.from(decoded) : <String, dynamic>{};
  } catch (_) {
    return <String, dynamic>{};
  }
}

class _RefChip extends StatelessWidget {
  const _RefChip({required this.text, required this.color, this.onTap});
  final String text;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(4),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(4),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(border: Border(left: BorderSide(color: color, width: 3))),
            child: Text(text, style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13)),
          ),
        ),
      ),
    );
  }
}

/// Task reference chip with the live task status (Ionic TaskRefNode).
class TaskRefEmbedBuilder extends EmbedBuilder {
  const TaskRefEmbedBuilder({required this.statuses, this.onOpen});

  /// Live statuses (task id → status).
  final Map<String, String> statuses;
  final void Function(String taskId)? onOpen;

  @override
  String get key => taskRefEmbedType;

  @override
  String toPlainText(Embed node) => taskRefText(_embedAttrs(node)['title']?.toString() ?? '', null);

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    final attrs = _embedAttrs(embedContext.node);
    final id = attrs['id']?.toString();
    final status = (id != null ? statuses[id] : null) ?? attrs['status']?.toString();
    return _RefChip(
      text: taskRefText(attrs['title']?.toString() ?? '', status),
      color: AppColors.primary,
      onTap: id != null && onOpen != null ? () => onOpen!(id) : null,
    );
  }
}

/// Topic reference chip (Ionic AgendaItemNode).
class AgendaRefEmbedBuilder extends EmbedBuilder {
  const AgendaRefEmbedBuilder({this.onOpen});
  final void Function(String agendaItemId)? onOpen;

  @override
  String get key => agendaItemRefEmbedType;

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    final attrs = _embedAttrs(embedContext.node);
    final id = attrs['id']?.toString();
    return _RefChip(
      text: agendaRefText(attrs),
      color: AppColors.secondary,
      onTap: id != null && onOpen != null ? () => onOpen!(id) : null,
    );
  }
}

/// ⌘/Strg ↓ in the wide protocol layout.
class NextPointIntent extends Intent {
  const NextPointIntent();
}

/// ⌘/Strg ↑ in the wide protocol layout.
class PreviousPointIntent extends Intent {
  const PreviousPointIntent();
}

/// One entry of the slash menu.
class SlashCommand {
  const SlashCommand(this.title, this.description, this.icon, this.run);
  final String title;
  final String description;
  final IconData icon;
  final Future<void> Function() run;
}

/// Active "/…" query left of the cursor: start offset of the slash and the
/// typed text, or null.
({int start, String query})? slashQueryAt(String text, int cursor) {
  if (cursor < 1 || cursor > text.length) return null;
  final lineStart = text.lastIndexOf('\n', cursor - 1) + 1;
  final before = text.substring(lineStart, cursor);
  final match = RegExp(r'(?:^|\s)/([^\s/]{0,30})$').firstMatch(before);
  if (match == null) return null;
  final query = match.group(1) ?? '';
  return (start: cursor - query.length - 1, query: query);
}

/// Filters slash commands by the typed text (title contains every word).
List<SlashCommand> filterSlashCommands(List<SlashCommand> commands, String query) {
  final words = query.toLowerCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
  return commands.where((c) {
    final hay = '${c.title} ${c.description}'.toLowerCase();
    return words.every(hay.contains);
  }).toList();
}

/// Notes editor of the protocol (Ionic app-tiptap-editor): toolbar, task and
/// topic chips, and a slash menu (Überschrift 1/2, Aufzählung, Nummerierte
/// Liste, "/aufgabe – Neue Aufgabe", "/tagesordnung – {Thema}").
class ProtocolEditor extends StatefulWidget {
  const ProtocolEditor({
    super.key,
    required this.controller,
    this.editable = true,
    this.taskStatuses = const {},
    this.agendaItems = const [],
    this.onCreateTask,
    this.onOpenTask,
    this.onOpenTopic,
    this.minHeight = 140,
    this.expands = false,
    this.focusNode,
    this.onNextPoint,
    this.onPreviousPoint,
  });

  /// ⌘/Strg ↓ / ↑ (replaces Quill's scroll shortcut while set).
  final VoidCallback? onNextPoint;
  final VoidCallback? onPreviousPoint;

  final QuillController controller;
  final bool editable;
  final Map<String, String> taskStatuses;

  /// Topics offered by "/tagesordnung".
  final List<AgendaItem> agendaItems;

  /// Creates a task (form) and inserts its reference at the cursor.
  final Future<void> Function()? onCreateTask;
  final void Function(String taskId)? onOpenTask;
  final void Function(String agendaItemId)? onOpenTopic;
  final double minHeight;

  /// Fills the available height (wide layout).
  final bool expands;
  final FocusNode? focusNode;

  @override
  State<ProtocolEditor> createState() => _ProtocolEditorState();
}

class _ProtocolEditorState extends State<ProtocolEditor> {
  ({int start, String query})? _slash;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChange);
  }

  @override
  void didUpdateWidget(ProtocolEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onChange);
      widget.controller.addListener(_onChange);
      _slash = null;
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (!widget.editable) return;
    final sel = widget.controller.selection;
    final next = sel.isCollapsed ? slashQueryAt(widget.controller.document.toPlainText(), sel.baseOffset) : null;
    if (next != _slash && mounted) setState(() => _slash = next);
  }

  List<SlashCommand> get _commands {
    final c = widget.controller;
    return [
      SlashCommand('Überschrift 1', 'Große Überschrift', Icons.title, () async => c.formatSelection(Attribute.h1)),
      SlashCommand('Überschrift 2', 'Mittlere Überschrift', Icons.text_fields, () async => c.formatSelection(Attribute.h2)),
      SlashCommand('Aufzählung', 'Ungeordnete Liste', Icons.format_list_bulleted, () async => c.formatSelection(Attribute.ul)),
      SlashCommand('Nummerierte Liste', 'Geordnete Liste', Icons.format_list_numbered,
          () async => c.formatSelection(Attribute.ol)),
      if (widget.onCreateTask != null)
        SlashCommand('/aufgabe – Neue Aufgabe', 'Aufgabe erstellen und verknüpfen', Icons.add_task, widget.onCreateTask!),
      for (final item in widget.agendaItems)
        if (item.id != null)
          SlashCommand('/tagesordnung – ${item.title}', 'Tagesordnungspunkt einfügen', Icons.list_alt, () async {
            insertRefEmbed(c, agendaItemRefEmbedType, {
              'id': item.id,
              'title': item.title,
              'status': item.status,
              'priority': item.priority,
            });
          }),
    ];
  }

  Future<void> _run(SlashCommand command) async {
    final slash = _slash;
    if (slash == null) return;
    final c = widget.controller;
    final length = c.selection.baseOffset - slash.start;
    setState(() => _slash = null);
    if (length > 0) {
      c.replaceText(slash.start, length, '', TextSelection.collapsed(offset: slash.start));
    }
    await command.run();
  }

  @override
  Widget build(BuildContext context) {
    final builders = <EmbedBuilder>[
      TaskRefEmbedBuilder(statuses: widget.taskStatuses, onOpen: widget.onOpenTask),
      AgendaRefEmbedBuilder(onOpen: widget.onOpenTopic),
    ];
    final readOnly = !widget.editable || widget.controller.readOnly;
    if (readOnly) {
      return QuillEditor.basic(
        controller: widget.controller,
        config: QuillEditorConfig(showCursor: false, scrollable: false, embedBuilders: builders),
      );
    }
    final slash = _slash;
    final matches = slash == null ? const <SlashCommand>[] : filterSlashCommands(_commands, slash.query);

    final editor = Container(
      constraints: BoxConstraints(minHeight: widget.minHeight),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
      ),
      child: QuillEditor.basic(
        controller: widget.controller,
        focusNode: widget.focusNode,
        config: QuillEditorConfig(
          scrollable: widget.expands,
          expands: widget.expands,
          placeholder: 'Tippe hier, um Notizen zu schreiben … ( / für Befehle)',
          padding: const EdgeInsets.all(AppDimensions.paddingS),
          embedBuilders: builders,
          customShortcuts: {
            if (widget.onNextPoint != null) ...{
              const SingleActivator(LogicalKeyboardKey.arrowDown, control: true): const NextPointIntent(),
              const SingleActivator(LogicalKeyboardKey.arrowDown, meta: true): const NextPointIntent(),
            },
            if (widget.onPreviousPoint != null) ...{
              const SingleActivator(LogicalKeyboardKey.arrowUp, control: true): const PreviousPointIntent(),
              const SingleActivator(LogicalKeyboardKey.arrowUp, meta: true): const PreviousPointIntent(),
            },
          },
          customActions: {
            if (widget.onNextPoint != null)
              NextPointIntent: CallbackAction<NextPointIntent>(onInvoke: (_) {
                widget.onNextPoint!();
                return null;
              }),
            if (widget.onPreviousPoint != null)
              PreviousPointIntent: CallbackAction<PreviousPointIntent>(onInvoke: (_) {
                widget.onPreviousPoint!();
                return null;
              }),
          },
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: widget.expands ? MainAxisSize.max : MainAxisSize.min,
      children: [
        QuillSimpleToolbar(
          controller: widget.controller,
          config: const QuillSimpleToolbarConfig(
            multiRowsDisplay: false,
            showBoldButton: true,
            showItalicButton: true,
            showUnderLineButton: true,
            showStrikeThrough: true,
            showColorButton: false,
            showBackgroundColorButton: false,
            showInlineCode: false,
            showCodeBlock: false,
            showLink: true,
            showSearchButton: false,
            showSubscript: false,
            showSuperscript: false,
            showFontFamily: false,
            showFontSize: false,
            showHeaderStyle: true,
            showListNumbers: true,
            showListBullets: true,
            showListCheck: true,
            showQuote: true,
            showIndent: true,
            showAlignmentButtons: false,
            showDirection: false,
            showUndo: true,
            showRedo: true,
            showClearFormat: false,
            showDividers: false,
            showSmallButton: false,
            showLineHeightButton: false,
            showClipboardCut: false,
            showClipboardCopy: false,
            showClipboardPaste: false,
          ),
        ),
        if (widget.expands) Expanded(child: editor) else editor,
        if (matches.isNotEmpty)
          Card(
            margin: const EdgeInsets.only(top: 4),
            elevation: 3,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 260),
              child: ListView(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                children: [
                  for (final cmd in matches)
                    ListTile(
                      dense: true,
                      leading: Icon(cmd.icon, color: AppColors.primary),
                      title: Text(cmd.title),
                      subtitle: Text(cmd.description),
                      onTap: () => _run(cmd),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
