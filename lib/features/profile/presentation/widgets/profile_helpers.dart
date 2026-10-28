import 'package:intl/intl.dart';

import '../../../../core/constants/enums.dart';
import '../../../../data/models/church/church.dart';
import '../../../../data/repositories/profile_repository.dart';

/// Role label as shown in the Ionic settings profile card (getRoleName).
String profileRoleName(Role role) {
  return switch (role) {
    Role.admin => 'Administrator',
    Role.responsible => 'Verantwortlicher',
    Role.helper => 'Helfer',
    Role.voiceLeader => 'Stimmführer',
    Role.voiceLeaderHelper => 'Stimmführer-Helfer',
    Role.player => 'Mitglied',
    Role.viewer => 'Beobachter',
    Role.parent => 'Elternteil',
    Role.applicant => 'Bewerber',
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
  return DateFormat('dd.MM.yyyy').format(parsed);
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
    return boolValue == true ? 'Ja' : 'Nein';
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
