import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/redesign_providers.dart' show redesignEnabledProvider;
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/redesign/rd_theme.dart';
import '../../../redesign/presentation/widgets/rd_widgets.dart';
import '../../../../data/models/church/church.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';

/// Label of a `bfecg_church` value (Ionic person.page getChurchLabel).
String churchLabel(dynamic value, List<Church> churches) {
  if (value == null) return l10nWithoutContext.personPleaseChoose;
  if (value == '') return l10nWithoutContext.personNotListed;
  return churches.where((c) => c.id == value).firstOrNull?.name ??
      l10nWithoutContext.personPleaseChoose;
}

/// Searchable church picker with "Nicht gelistet" (Ionic person.page church
/// modal). Returns the church id, '' for "Nicht gelistet", or null when
/// closed.
Future<String?> showChurchPickerSheet(
  BuildContext context, {
  required String title,
  required List<Church> churches,
  String? selectedId,
}) {
  // REDESIGN: in the Beta a Beta sheet with the same choices and result.
  if (ProviderScope.containerOf(context, listen: false).read(redesignEnabledProvider)) {
    return showRdSheet<String>(
      context,
      RdChurchPicker(title: title, churches: churches, selectedId: selectedId),
    );
  }
  return showModalBottomSheet<String>(
    context: context,
    useRootNavigator: true, // IOS_SHELL2: above the tab bar
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.85,
      child: _ChurchPicker(
        title: title,
        churches: churches,
        selectedId: selectedId,
      ),
    ),
  );
}

/// REDESIGN: Beta sheet of [showChurchPickerSheet]: search field on top,
/// "Nicht gelistet" and the churches as a grouped list, a check mark at
/// the chosen one.
class RdChurchPicker extends StatefulWidget {
  const RdChurchPicker({
    super.key,
    required this.title,
    required this.churches,
    this.selectedId,
  });

  final String title;
  final List<Church> churches;
  final String? selectedId;

  @override
  State<RdChurchPicker> createState() => _RdChurchPickerState();
}

class _RdChurchPickerState extends State<RdChurchPicker> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final term = _search.trim().toLowerCase();
    final filtered =
        term.isEmpty ? widget.churches : widget.churches.where((c) => c.name.toLowerCase().contains(term)).toList();
    Widget row(String label, String? id) => RdListRow(
          title: label,
          selected: widget.selectedId == id,
          showChevron: false,
          trailing: RdSheetCheck(widget.selectedId == id),
          onTap: () => Navigator.of(context).pop(id),
        );

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RdSheetTitle(widget.title),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              textInputAction: TextInputAction.search,
              onChanged: (v) => setState(() => _search = v),
              decoration: InputDecoration(
                hintText: l10n.personSearchChurch,
                prefixIcon: Icon(Icons.search, color: p.text2),
                filled: true,
                fillColor: p.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(p.buttonRadius),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                RdGroupedList(
                  children: [
                    row(l10n.personNotListed, ''),
                    for (final church in filtered) row(church.name, church.id),
                  ],
                ),
                if (filtered.isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 12, 4, 0),
                    child: Text(l10n.personNoChurchFound, style: RdType.meta(p, size: 14)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChurchPicker extends StatefulWidget {
  const _ChurchPicker({
    required this.title,
    required this.churches,
    this.selectedId,
  });

  final String title;
  final List<Church> churches;
  final String? selectedId;

  @override
  State<_ChurchPicker> createState() => _ChurchPickerState();
}

class _ChurchPickerState extends State<_ChurchPicker> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final term = _search.trim().toLowerCase();
    final filtered = term.isEmpty
        ? widget.churches
        : widget.churches
            .where((c) => c.name.toLowerCase().contains(term))
            .toList();

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: ionModalToolbarHeight(context),
        title: Text(widget.title),
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: IonButtonLabel(context.l10n.commonClose),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppDimensions.paddingM),
            child: TextField(
              decoration: InputDecoration(
                hintText: context.l10n.personSearchChurch,
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                ListTile(
                  title: Text(context.l10n.personNotListed),
                  trailing: widget.selectedId == ''
                      ? const Icon(Icons.check, color: AppColors.primary)
                      : null,
                  onTap: () => Navigator.of(context).pop(''),
                ),
                for (final church in filtered)
                  ListTile(
                    title: Text(church.name),
                    trailing: widget.selectedId == church.id
                        ? const Icon(Icons.check, color: AppColors.primary)
                        : null,
                    onTap: () => Navigator.of(context).pop(church.id),
                  ),
                if (filtered.isEmpty)
                  ListTile(
                    title: Text(
                      context.l10n.personNoChurchFound,
                      style: const TextStyle(color: AppColors.medium),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
