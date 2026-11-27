import 'package:attendix/core/theme/app_icons.dart';
import 'package:attendix/shared/widgets/layout/sheet_drag.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/utils/quill_utils.dart';
import '../../../l10n/l10n.dart';
import '../layout/ionic_ios.dart' show IonSheetHeader;

/// Shows the description (HTML from the Ionic editor) of a Termin.
///
/// PARITY_SELF: Ionic `#descriptionModal` (signout, overview, parents): sheet
/// with breakpoints [0, 0.6, 1] (initial 0.6), toolbar "Beschreibung" + X and
/// the formatted `quill-view` (bold, lists, tappable links).
Future<void> showEventDescriptionSheet(
  BuildContext context,
  String description,
) {
  return showModalBottomSheet(
    context: context,
    useRootNavigator: true, // IOS_SHELL2: above the tab bar
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (ctx) => AppDraggableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.25,
      maxChildSize: 1,
      snap: true,
      snapSizes: const [0.6],
      expand: false,
      builder: (ctx, scrollController) => Column(
        children: [
          IonSheetHeader(
            title: ctx.l10n.signoutDescription,
            end: [
              IconButton(
                tooltip: ctx.l10n.commonClose,
                icon: Icon(AppIcons.close),
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ],
          ),
          Expanded(
            child: SingleChildScrollView(
              controller: scrollController,
              padding: EdgeInsets.fromLTRB(
                16,
                8,
                16,
                24 + MediaQuery.paddingOf(ctx).bottom,
              ),
              child: EventDescriptionView(html: description),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Read-only rendering of a Quill HTML description (Ionic `quill-view`).
class EventDescriptionView extends StatefulWidget {
  const EventDescriptionView({super.key, required this.html});

  final String html;

  @override
  State<EventDescriptionView> createState() => _EventDescriptionViewState();
}

class _EventDescriptionViewState extends State<EventDescriptionView> {
  late QuillController _controller = _build();

  QuillController _build() => QuillController(
        document: QuillUtils.documentFromNotesString(widget.html),
        selection: const TextSelection.collapsed(offset: 0),
        readOnly: true,
      );

  @override
  void didUpdateWidget(covariant EventDescriptionView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.html != widget.html) {
      _controller.dispose();
      _controller = _build();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _openLink(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    // Ionic quill-view links open in a new tab / the system browser.
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return QuillEditor.basic(
      controller: _controller,
      config: QuillEditorConfig(
        showCursor: false,
        scrollable: false,
        onLaunchUrl: _openLink,
      ),
    );
  }
}
