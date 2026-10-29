import 'package:intl/intl.dart';

import '../../../../core/constants/enums.dart';
import '../../../../data/models/church/church.dart';
import '../../../../data/repositories/profile_repository.dart';
import '../../../../l10n/l10n.dart';

/// Role label as shown in the Ionic settings profile card (getRoleName).
String profileRoleName(Role role) {
  final l10n = l10nWithoutContext;
  return switch (role) {
    Role.admin => l10n.rolesAdministrator,
    Role.responsible => l10n.rolesResponsible,
    Role.helper => l10n.rolesHelper,
    Role.voiceLeader => l10n.rolesVoiceLeader,
    Role.voiceLeaderHelper => l10n.rolesVoiceLeaderHelper,
    Role.player => l10n.rolesMember,
    Role.viewer => l10n.rolesViewer,
    Role.parent => l10n.rolesParent,
    Role.applicant => l10n.rolesApplicant,
    Role.none => '',
  };
}

/// True when [img] is a real, user-provided picture (not empty / placeholder).
bool hasCustomProfileImage(String? img) =>
    img != null && img.isNotEmpty && img != kDefaultProfileImage;

/// Format a birthday string (yyyy-MM-dd or ISO) as dd.MM.yyyy.
String formatProfileDate(String? value) {
  if (value == null || value.isEmpty) return '';
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return value;
  return DateFormat(dateFmt()).format(parsed);
}

/// IOS_FORMS1: value shown by an Ionic `ion-datetime-button`
/// (`presentation="date"`): Intl `{day: 'numeric', month: 'short',
/// year: 'numeric'}` in the app locale, e.g. "16. Feb. 2002" (de) /
/// "16 Feb 2002" (en-GB).
String formatIonDateButton(String? value) {
  if (value == null || value.isEmpty) return '';
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return value;
  return DateFormat.yMMMd(currentIntlLocale()).format(parsed);
}

/// Display value of an extra field (Ionic getExtraFieldDisplayValue).
String extraFieldDisplayValue(
  ProfileExtraField field,
  Map<String, dynamic> values,
  List<Church> churches,
) {
  var value = values[field.id];
  if (field.type == 'boolean') {
    final boolValue = value ?? field.defaultValue;
    return boolValue == true
        ? l10nWithoutContext.commonYes
        : l10nWithoutContext.commonNo;
  }
  if (value == null || value == '') value = field.defaultValue;
  if (value == null || value == '') return '—';
  if (field.type == 'bfecg_church') {
    final church = churches.where((c) => c.id == value).firstOrNull;
    return church?.name ?? value.toString();
  }
  if (field.type == 'date') return formatProfileDate(value.toString());
  return value.toString();
}
