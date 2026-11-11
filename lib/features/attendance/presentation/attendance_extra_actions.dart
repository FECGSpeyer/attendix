import 'package:flutter/material.dart';
import 'package:attendix/core/theme/app_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/enums.dart';
import '../../../core/providers/attendance_detail_providers.dart';
import '../../../core/providers/attendance_providers.dart';
import '../../../core/providers/church_providers.dart';
import '../../../core/providers/profile_providers.dart';
import '../../../core/utils/demo_guard.dart';
import '../../../core/utils/error_message.dart';
import '../../../core/utils/toast_helper.dart';
import '../../../data/models/church/church.dart';
import '../../../data/models/person/person.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/widgets/adaptive/app_dialog.dart';
import '../../../shared/widgets/sheets/church_overview_sheet.dart';

/// Termin actions shared by the old Termin page and the Beta Überblick:
/// "Foto hinzufügen" and "Gemeinde-Übersicht".

/// "Foto hinzufügen": camera or gallery, stored as the Termin's `img`.
Future<void> addAttendancePhoto(BuildContext context, WidgetRef ref, int attendanceId) async {
  final repo = ref.read(attendanceRepositoryWithTenantProvider);
  final source = await showAppDialog<ImageSource>(
    context: context,
    builder: (ctx) => AppAlertDialog(
      title: Text(context.l10n.attendanceFlutterAddPhoto),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(AppIcons.cameraAlt),
            title: Text(context.l10n.attendanceFlutterCamera),
            onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
          ),
          ListTile(
            leading: Icon(AppIcons.photoLibrary),
            title: Text(context.l10n.attendanceFlutterGallery),
            onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(context.l10n.commonCancel),
        ),
      ],
    ),
  );

  if (source == null) return;
  if (DemoGuard.blocked()) return; // DEMO_GUARD

  try {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: source,
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 85,
    );

    if (image == null) return;

    if (!context.mounted) return;
    ToastHelper.showInfo(context, context.l10n.attendanceFlutterUploadingPhoto);

    final bytes = await image.readAsBytes();

    if (!repo.hasTenantId) {
      if (context.mounted) {
        ToastHelper.showError(context, context.l10n.historyFlutterNoTenant);
      }
      return;
    }

    // DB_REVIEW_REST (H4): bucket `attendances`, key `<id>`, upsert (Ionic).
    await repo.uploadAttendanceImage(attendanceId, bytes);

    ref.invalidate(attendanceDetailProvider(attendanceId));

    if (context.mounted) {
      ToastHelper.showSuccess(context, context.l10n.attendanceFlutterPhotoUploaded);
    }
  } catch (e) {
    if (context.mounted) {
      ToastHelper.showError(context, context.l10n.attendanceFlutterUploadFailedWith(friendlyErrorMessage(e)));
    }
  }
}


/// Id of the `bfecg_church` extra field, if the tenant has one.
String? attendanceChurchFieldId(WidgetRef ref) {
  final fields = ref.read(personExtraFieldsProvider).valueOrNull ?? const [];
  return fields.where((f) => f.type == 'bfecg_church').firstOrNull?.id;
}

/// "Gemeinde-Übersicht" of the present persons of a Termin.
Future<void> showAttendanceChurchOverview(
  BuildContext context,
  WidgetRef ref, {
  required List<Person> persons,
  required AttendanceStatus? Function(Person) statusOf,
}) async {
  final fieldId = attendanceChurchFieldId(ref);
  if (fieldId == null) return;
  const present = {AttendanceStatus.present, AttendanceStatus.late, AttendanceStatus.lateExcused};
  final churchIds = persons
      .where((p) => present.contains(statusOf(p)))
      .map((p) => churchIdOf(p.additionalFields, fieldId))
      .toList();
  List<Church> churches;
  try {
    churches = await ref.read(churchesProvider.future);
  } catch (_) {
    churches = const [];
  }
  if (!context.mounted) return;
  await showChurchOverviewSheet(
    context,
    churchIds: churchIds,
    churches: churches,
    subtitle: context.l10n.attendancePresentPeople,
  );
}
