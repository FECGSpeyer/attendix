import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/church/church.dart';
import '../../../../l10n/l10n.dart';

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
        title: Text(widget.title),
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.l10n.commonClose),
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
