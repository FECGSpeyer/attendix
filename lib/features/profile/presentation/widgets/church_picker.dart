import 'package:flutter/material.dart';
import 'package:attendix/core/theme/app_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/church/church.dart';
import '../../../../l10n/l10n.dart';
import '../../../auth/presentation/widgets/ion_form_list.dart';
import '../../../../core/theme/redesign/rd_theme.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';
import '../../../../shared/widgets/dialogs/ion_modal.dart';
import '../../../../shared/widgets/layout/ionic_ios.dart' show IonSearchbar;

/// Opens the searchable church picker (Ionic church `ion-modal` of the
/// settings master data and of tenant-register): toolbar with the field name
/// and "Schließen", a searchbar toolbar, then an inset list with
/// "Nicht gelistet" first and a checkmark on the selected church.
///
/// Returns the selected church id, `''` for "Nicht gelistet", or null when
/// closed without a choice.
Future<String?> showChurchPicker(
  BuildContext context, {
  required String title,
  required List<Church> churches,
  String? selectedId,
  required String searchHint,
  required String notListedLabel,
  required String noChurchLabel,
}) {
  final picker = ChurchPicker(
    title: title,
    churches: churches,
    selectedId: selectedId,
    searchHint: searchHint,
    notListedLabel: notListedLabel,
    noChurchLabel: noChurchLabel,
  );
  // SEL-17: Ionic default `ion-modal` (full screen on phones, centred card
  // on wide screens) instead of a bottom sheet; Beta keeps its sheet.
  if (context.rdSkin == null) {
    return showIonModal<String>(context, builder: (_) => picker);
  }
  return showModalBottomSheet<String>(
    context: context,
    useRootNavigator: true, // IOS_SHELL2: above the tab bar
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.95,
      child: ChurchPicker(
        title: title,
        churches: churches,
        selectedId: selectedId,
        searchHint: searchHint,
        notListedLabel: notListedLabel,
        noChurchLabel: noChurchLabel,
      ),
    ),
  );
}

/// Searchable church list (see [showChurchPicker]).
class ChurchPicker extends StatefulWidget {
  const ChurchPicker({
    super.key,
    required this.title,
    required this.churches,
    this.selectedId,
    required this.searchHint,
    required this.notListedLabel,
    required this.noChurchLabel,
  });

  final String title;
  final List<Church> churches;
  final String? selectedId;
  final String searchHint;
  final String notListedLabel;
  final String noChurchLabel;

  @override
  State<ChurchPicker> createState() => _ChurchPickerState();
}

class _ChurchPickerState extends State<ChurchPicker> {
  String _search = '';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final term = _search.trim().toLowerCase();
    final filtered = term.isEmpty
        ? widget.churches
        : widget.churches
            .where((c) => c.name.toLowerCase().contains(term))
            .toList();
    final check = Icon(AppIcons.check, color: AppColors.primary);

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: ionModalToolbarHeight(context),
        title: Text(widget.title),
        automaticallyImplyLeading: false,
        // SEL-13: Ionic `ion-buttons slot="end"` (iOS glass capsule).
        actions: [
          ToolbarButtonGroup(children: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: IonButtonLabel(context.l10n.commonClose),
            ),
          ]),
        ],
        // second toolbar: ion-searchbar
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(context.rdSkin == null ? 58 : 52),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: context.rdSkin == null
                // SEL-17: the shared Ionic searchbar (second toolbar).
                ? IonSearchbar(
                    controller: _searchController,
                    hintText: widget.searchHint,
                    onChanged: (v) => setState(() => _search = v),
                  )
                : SizedBox(
              height: 38,
              child: TextField(
                autofocus: false,
                textAlignVertical: TextAlignVertical.center,
                decoration: InputDecoration(
                  hintText: widget.searchHint,
                  prefixIcon: Icon(AppIcons.search, size: 20),
                  isDense: true,
                  filled: true,
                  fillColor: AppColors.medium.withValues(alpha: 0.12),
                  contentPadding: EdgeInsets.zero,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (v) => setState(() => _search = v),
              ),
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          IonInsetGroup(
            children: [
              IonItem(
                label: widget.notListedLabel,
                end: widget.selectedId == '' ? check : null,
                onTap: () => Navigator.of(context).pop(''),
              ),
              for (final church in filtered)
                IonItem(
                  label: church.name,
                  end: widget.selectedId == church.id ? check : null,
                  onTap: () => Navigator.of(context).pop(church.id),
                ),
              if (filtered.isEmpty)
                IonItem(
                  label: widget.noChurchLabel,
                  labelColor: AppColors.medium,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
