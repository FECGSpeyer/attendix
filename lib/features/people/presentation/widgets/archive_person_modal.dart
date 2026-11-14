import 'package:flutter/material.dart';
import 'package:attendix/core/theme/app_icons.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';
import '../../../../shared/widgets/dialogs/ion_modal.dart' show showIonModal;
import 'ion/ion_widgets.dart';

/// Result of [showArchivePersonModal]: `date` as ISO string like Ionic
/// `dayjs(archiveDate).toISOString()` (local midnight in UTC), `note` as typed.
typedef ArchiveInput = ({String date, String note});

/// Ionic person.page / list.page archive modal: full-screen `ion-modal`
/// (backdropDismiss false) with toolbar "{Name} Archivieren" + X,
/// "Austrittsdatum", "Notiz" and the archive FAB. Returns null when closed.
Future<ArchiveInput?> showArchivePersonModal(BuildContext context, String name) {
  return showIonModal<ArchiveInput>(
    context,
    barrierDismissible: false, // Ionic backdropDismiss false
    builder: (_) => _ArchivePersonModal(name: name),
  );
}

class _ArchivePersonModal extends StatefulWidget {
  const _ArchivePersonModal({required this.name});

  final String name;

  @override
  State<_ArchivePersonModal> createState() => _ArchivePersonModalState();
}

class _ArchivePersonModalState extends State<_ArchivePersonModal> {
  final _noteController = TextEditingController();
  late DateTime _date;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _date = DateTime(now.year, now.month, now.day);
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showAppDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      // md look: Ionic has a native date input here (calendar with buttons).
      overlay: IonDatetimeOverlay.buttons,
    );
    if (picked != null && mounted) {
      setState(() => _date = DateTime(picked.year, picked.month, picked.day));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: ionContentBackground(context),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(l10n.peopleArchiveTitle(widget.name)),
        actions: [
          IconButton(
            tooltip: l10n.commonClose,
            icon: Icon(AppIcons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      floatingActionButton: IonFabButton(
        tooltip: l10n.peopleArchive,
        icon: AppIcons.archiveOutlined,
        onPressed: () => Navigator.pop<ArchiveInput>(context, (
          date: _date.toUtc().toIso8601String(),
          note: _noteController.text,
        )),
      ),
      body: IonFormTheme(
        child: ListView(
          padding: const EdgeInsets.all(AppDimensions.paddingM),
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.peopleLeaveDate),
              subtitle: Text(DateFormat(dateFmt()).format(_date)),
              trailing: Icon(AppIcons.calendarToday),
              onTap: _pickDate,
            ),
            TextField(
              controller: _noteController,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: l10n.peopleNote),
              minLines: 2,
              maxLines: null,
            ),
          ],
        ),
      ),
    );
  }
}
