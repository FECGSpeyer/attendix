import 'package:intl/intl.dart';

import '../../../l10n/languages.dart';
import '../message/message.dart';

/// Automatische Nachrichten (Ionic 4.18, tables `auto_message_rules`,
/// `auto_message_runs`, `attendance_responses`). Plain immutable classes –
/// the rule is edited as a whole in the rule editor and written back with
/// [AutoMessageRule.toRow].

/// Placeholders offered in the rule editor (same names in every language).
const autoMessagePlaceholders = [
  'vorname',
  'name',
  'termin',
  'datum',
  'uhrzeit',
  'instanz',
  'anzahl',
];

/// Quick-start templates (Ionic AUTO_MESSAGE_TEMPLATES).
const autoMessageTemplates = ['absent', 'late', 'noAnswer', 'streak'];

/// Reasons a member can pick when answering (Ionic RESPONSE_REASONS).
const autoMessageResponseReasons = ['sick', 'work', 'family', 'forgot', 'other'];

/// Members can answer this many days after the Termin (same in the
/// attendance-response Edge Function).
const autoMessageResponseDays = 7;

/// Until when members can answer a Termin message for the Termin on
/// [terminDate] (the stored date, with its time); null when unparsable.
DateTime? autoMessageResponseUntil(String? terminDate) {
  final date = DateTime.tryParse(terminDate ?? '');
  return date?.add(const Duration(days: autoMessageResponseDays + 1));
}

/// Wartezeit options in minutes (Ionic DELAY_OPTIONS).
const autoMessageDelayOptions = [0, 30, 60, 120, 180, 360, 720, 1440, 2880];

enum AutoMessageFrequency {
  each,
  streak,
  window;

  static AutoMessageFrequency parse(Object? value) =>
      AutoMessageFrequency.values.where((f) => f.name == value).firstOrNull ??
      AutoMessageFrequency.each;
}

List<T>? _list<T>(Object? value, T? Function(Object? e) map) {
  if (value is! List) return null;
  return value.map(map).whereType<T>().toList();
}

int? _int(Object? v) => v is int ? v : (v is num ? v.toInt() : int.tryParse('$v'));

/// One rule of "Automatische Nachrichten".
class AutoMessageRule {
  const AutoMessageRule({
    this.id,
    required this.tenantId,
    this.name = '',
    this.enabled = false,
    this.enabledAt,
    this.statuses = const [4],
    this.typeIds,
    this.groupIds,
    this.delayMinutes = 120,
    this.frequency = AutoMessageFrequency.each,
    this.frequencyCount = 2,
    this.frequencyDays = 30,
    this.channels = const ['push'],
    this.useTemplate = true,
    this.templateKey = 'absent',
    this.title,
    this.bodyJson,
    this.allowResponses = true,
    this.instantExcuse = false,
    this.copyResponsibles = false,
    this.copyVoiceLeaders = false,
    this.createdBy,
    this.createdAt,
  });

  /// Ionic `defaultAutoMessageRule`.
  factory AutoMessageRule.defaults(int tenantId) => AutoMessageRule(tenantId: tenantId);

  factory AutoMessageRule.fromJson(Map<String, dynamic> json) => AutoMessageRule(
    id: json['id'] as String?,
    tenantId: _int(json['tenantId']) ?? 0,
    name: json['name'] as String? ?? '',
    enabled: json['enabled'] == true,
    enabledAt: DateTime.tryParse('${json['enabled_at'] ?? ''}'),
    statuses: _list<int>(json['statuses'], _int) ?? const [4],
    typeIds: _list<String>(json['type_ids'], (e) => e?.toString()),
    groupIds: _list<int>(json['group_ids'], _int),
    delayMinutes: _int(json['delay_minutes']) ?? 120,
    frequency: AutoMessageFrequency.parse(json['frequency']),
    frequencyCount: _int(json['frequency_count']) ?? 2,
    frequencyDays: _int(json['frequency_days']) ?? 30,
    channels: _list<String>(json['channels'], (e) => e?.toString()) ?? const ['push'],
    useTemplate: json['use_template'] != false,
    templateKey: json['template_key'] as String? ?? 'absent',
    title: json['title'] as String?,
    bodyJson: (json['body_json'] as Map?)?.cast<String, dynamic>(),
    allowResponses: json['allow_responses'] != false,
    instantExcuse: json['instant_excuse'] == true,
    copyResponsibles: json['copy_responsibles'] == true,
    copyVoiceLeaders: json['copy_voice_leaders'] == true,
    createdBy: json['created_by'] as String?,
    createdAt: DateTime.tryParse('${json['created_at'] ?? ''}'),
  );

  final String? id;
  final int tenantId;
  final String name;
  final bool enabled;
  final DateTime? enabledAt;

  /// 4 unexcused, 3 late, 0 no answer.
  final List<int> statuses;

  /// attendance_types.id, null = all.
  final List<String>? typeIds;

  /// player.instrument, null = all.
  final List<int>? groupIds;
  final int delayMinutes;
  final AutoMessageFrequency frequency;
  final int frequencyCount;
  final int frequencyDays;
  final List<String> channels;
  final bool useTemplate;
  final String templateKey;
  final String? title;
  final Map<String, dynamic>? bodyJson;
  final bool allowResponses;
  final bool instantExcuse;
  final bool copyResponsibles;
  final bool copyVoiceLeaders;
  final String? createdBy;
  final DateTime? createdAt;

  bool get isNew => id == null;

  static const _unset = Object();

  AutoMessageRule copyWith({
    String? name,
    bool? enabled,
    List<int>? statuses,
    Object? typeIds = _unset,
    Object? groupIds = _unset,
    int? delayMinutes,
    AutoMessageFrequency? frequency,
    int? frequencyCount,
    int? frequencyDays,
    List<String>? channels,
    bool? useTemplate,
    String? templateKey,
    Object? title = _unset,
    Object? bodyJson = _unset,
    bool? allowResponses,
    bool? instantExcuse,
    bool? copyResponsibles,
    bool? copyVoiceLeaders,
  }) => AutoMessageRule(
    id: id,
    tenantId: tenantId,
    name: name ?? this.name,
    enabled: enabled ?? this.enabled,
    enabledAt: enabledAt,
    statuses: statuses ?? this.statuses,
    typeIds: identical(typeIds, _unset) ? this.typeIds : typeIds as List<String>?,
    groupIds: identical(groupIds, _unset) ? this.groupIds : groupIds as List<int>?,
    delayMinutes: delayMinutes ?? this.delayMinutes,
    frequency: frequency ?? this.frequency,
    frequencyCount: frequencyCount ?? this.frequencyCount,
    frequencyDays: frequencyDays ?? this.frequencyDays,
    channels: channels ?? this.channels,
    useTemplate: useTemplate ?? this.useTemplate,
    templateKey: templateKey ?? this.templateKey,
    title: identical(title, _unset) ? this.title : title as String?,
    bodyJson: identical(bodyJson, _unset) ? this.bodyJson : bodyJson as Map<String, dynamic>?,
    allowResponses: allowResponses ?? this.allowResponses,
    instantExcuse: instantExcuse ?? this.instantExcuse,
    copyResponsibles: copyResponsibles ?? this.copyResponsibles,
    copyVoiceLeaders: copyVoiceLeaders ?? this.copyVoiceLeaders,
    createdBy: createdBy,
    createdAt: createdAt,
  );

  /// Editable columns (no id / tenantId / created_* / enabled_at).
  Map<String, dynamic> toRow() => {
    'name': name,
    'enabled': enabled,
    'statuses': statuses,
    'type_ids': (typeIds?.isEmpty ?? true) ? null : typeIds,
    'group_ids': (groupIds?.isEmpty ?? true) ? null : groupIds,
    'delay_minutes': delayMinutes,
    'frequency': frequency.name,
    'frequency_count': frequencyCount,
    'frequency_days': frequencyDays,
    'channels': channels,
    'use_template': useTemplate,
    'template_key': templateKey,
    'title': title,
    'body_json': bodyJson,
    'allow_responses': allowResponses,
    'instant_excuse': instantExcuse,
    'copy_responsibles': copyResponsibles,
    'copy_voice_leaders': copyVoiceLeaders,
  };

  /// Rule as the send-auto-messages dry run expects it (Ionic sends the
  /// whole rule object).
  Map<String, dynamic> toPreviewJson() => {
    if (id != null) 'id': id,
    'tenantId': tenantId,
    ...toRow(),
    'enabled_at': enabledAt?.toUtc().toIso8601String(),
  };
}

/// One run of a rule for one Termin (dedupe + history).
class AutoMessageRun {
  const AutoMessageRun({
    required this.id,
    required this.ruleId,
    required this.attendanceId,
    required this.status,
    this.messageId,
    this.recipientCount = 0,
    this.createdByName,
    this.createdAt,
  });

  factory AutoMessageRun.fromJson(Map<String, dynamic> json) => AutoMessageRun(
    id: json['id'] as String,
    ruleId: json['rule_id'] as String,
    attendanceId: _int(json['attendance_id']) ?? 0,
    status: json['status'] as String? ?? 'none',
    messageId: json['message_id'] as String?,
    recipientCount: _int(json['recipient_count']) ?? 0,
    createdByName: json['created_by_name'] as String?,
    createdAt: DateTime.tryParse('${json['created_at'] ?? ''}'),
  );

  final String id;
  final String ruleId;
  final int attendanceId;

  /// 'sent' | 'none' | 'not_recorded' | 'suspended'
  final String status;
  final String? messageId;
  final int recipientCount;
  final String? createdByName;
  final DateTime? createdAt;
}

/// Answer of a member to a Termin message.
class AttendanceResponse {
  const AttendanceResponse({
    required this.id,
    required this.attendanceId,
    required this.personAttendanceId,
    required this.kind,
    this.messageId,
    this.reasonCode,
    this.text,
    this.state = 'pending',
    this.decidedByName,
  });

  factory AttendanceResponse.fromJson(Map<String, dynamic> json) => AttendanceResponse(
    id: json['id'] as String,
    attendanceId: _int(json['attendance_id']) ?? 0,
    personAttendanceId: json['person_attendance_id'] as String? ?? '',
    kind: json['kind'] as String? ?? 'reason',
    messageId: json['message_id'] as String?,
    reasonCode: json['reason_code'] as String?,
    text: json['text'] as String?,
    state: json['state'] as String? ?? 'pending',
    decidedByName: json['decided_by_name'] as String?,
  );

  final String id;
  final int attendanceId;
  final String personAttendanceId;

  /// 'reason' | 'was_present'
  final String kind;
  final String? messageId;
  final String? reasonCode;
  final String? text;

  /// 'pending' | 'accepted' | 'rejected'
  final String state;
  final String? decidedByName;

  bool get isPending => state == 'pending';
  bool get wasPresent => kind == 'was_present';

  AttendanceResponse withState(String newState) => AttendanceResponse(
    id: id,
    attendanceId: attendanceId,
    personAttendanceId: personAttendanceId,
    kind: kind,
    messageId: messageId,
    reasonCode: reasonCode,
    text: text,
    state: newState,
    decidedByName: decidedByName,
  );
}

/// One person of a preview Termin.
class AutoMessagePreviewPerson {
  const AutoMessagePreviewPerson({
    required this.id,
    required this.name,
    this.groupId,
    this.email = false,
    this.app = false,
  });

  factory AutoMessagePreviewPerson.fromJson(Map<String, dynamic> json) => AutoMessagePreviewPerson(
    id: _int(json['id']) ?? 0,
    name: json['name'] as String? ?? '',
    groupId: _int(json['groupId']),
    email: json['email'] == true,
    app: json['app'] == true,
  );

  final int id;
  final String name;
  final int? groupId;
  final bool email;
  final bool app;
}

/// Preview of a rule for one past Termin (send-auto-messages dry run).
class AutoMessagePreviewTermin {
  const AutoMessagePreviewTermin({
    required this.attendanceId,
    required this.title,
    required this.date,
    this.startTime,
    this.sendAt,
    this.recorded = true,
    this.people = const [],
    this.excused = 0,
    this.paused = 0,
  });

  factory AutoMessagePreviewTermin.fromJson(Map<String, dynamic> json) => AutoMessagePreviewTermin(
    attendanceId: _int(json['attendanceId']) ?? 0,
    title: json['title'] as String? ?? '',
    date: json['date'] as String? ?? '',
    startTime: json['startTime'] as String?,
    sendAt: DateTime.tryParse('${json['sendAt'] ?? ''}'),
    recorded: json['recorded'] != false,
    people:
        (json['people'] as List? ?? const [])
            .whereType<Map>()
            .map((p) => AutoMessagePreviewPerson.fromJson(p.cast<String, dynamic>()))
            .toList(),
    excused: _int(json['excused']) ?? 0,
    paused: _int(json['paused']) ?? 0,
  );

  final int attendanceId;
  final String title;
  final String date;
  final String? startTime;
  final DateTime? sendAt;
  final bool recorded;
  final List<AutoMessagePreviewPerson> people;
  final int excused;
  final int paused;
}

/// Date, name and type of a Termin (history rows, message Termin card).
class AutoMessageTerminInfo {
  const AutoMessageTerminInfo({required this.id, required this.date, this.typeInfo, this.typeId});

  factory AutoMessageTerminInfo.fromJson(Map<String, dynamic> json) => AutoMessageTerminInfo(
    id: _int(json['id']) ?? 0,
    date: json['date'] as String? ?? '',
    typeInfo: json['typeInfo'] as String?,
    typeId: json['type_id']?.toString(),
  );

  final int id;
  final String date;
  final String? typeInfo;
  final String? typeId;
}

// ---------------------------------------------------------------------------
// Text helpers (Ionic auto-message.service.ts)
// ---------------------------------------------------------------------------

/// Date of a Termin (YYYY-MM-DD) in the app's locale, e.g. "Di., 28.10.2026".
String formatTerminDate(String? date) {
  if (date == null || date.isEmpty) return '';
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(date);
  final d =
      m != null
          ? DateTime(int.parse(m.group(1)!), int.parse(m.group(2)!), int.parse(m.group(3)!))
          : DateTime.tryParse(date)?.toLocal();
  if (d == null) return date;
  return DateFormat('EE, ${dateFmt()}', currentIntlLocale()).format(d);
}

String _escapeHtml(String value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

/// Replaces `{name}` placeholders; unknown ones stay as they are.
String fillPlaceholders(String? text, Map<String, Object?> vars, {bool html = false}) {
  return (text ?? '').replaceAllMapped(RegExp(r'\{(\w+)\}'), (m) {
    final value = vars[m.group(1)];
    if (value == null) return m.group(0)!;
    return html ? _escapeHtml('$value') : '$value';
  });
}

/// Ionic 4.18 columns of `messages` (automatic / Termin messages). Loaded
/// separately from [Message] so old databases without the columns keep
/// working.
class MessageAutoInfo {
  const MessageAutoInfo({
    this.autoRuleId,
    this.attendanceId,
    this.allowResponses = false,
    this.vars,
    this.i18n,
  });

  factory MessageAutoInfo.fromJson(Map<String, dynamic> json) => MessageAutoInfo(
    autoRuleId: json['auto_rule_id'] as String?,
    attendanceId: _int(json['attendance_id']),
    allowResponses: json['allow_responses'] == true,
    vars: (json['vars'] as Map?)?.cast<String, dynamic>(),
    i18n: (json['i18n'] as Map?)?.cast<String, dynamic>(),
  );

  final String? autoRuleId;

  /// Termin the message is about (automatic or "Unentschuldigte anschreiben").
  final int? attendanceId;
  final bool allowResponses;

  /// Shared placeholder values: termin, date (YYYY-MM-DD), uhrzeit, instanz.
  final Map<String, dynamic>? vars;

  /// Template texts per language: {de: {title, html, text}}.
  final Map<String, dynamic>? i18n;
}

/// Ionic 4.18 columns of the own `message_recipients` row.
class RecipientAutoInfo {
  const RecipientAutoInfo({this.personAttendanceId, this.vars, this.lang});

  factory RecipientAutoInfo.fromJson(Map<String, dynamic> json) => RecipientAutoInfo(
    personAttendanceId: json['person_attendance_id'] as String?,
    vars: (json['vars'] as Map?)?.cast<String, dynamic>(),
    lang: json['lang'] as String?,
  );

  final String? personAttendanceId;

  /// Per-person placeholder values: vorname, name, anzahl.
  final Map<String, dynamic>? vars;
  final String? lang;
}

/// Title and HTML of a message as one recipient sees it: the template in the
/// recipient's language (automatic messages) with all placeholders filled.
({String title, String html}) personalizeMessage(
  Message message,
  MessageAutoInfo? info,
  RecipientAutoInfo? recipient, {
  String? language,
}) {
  final lang =
      (recipient?.lang?.isNotEmpty ?? false) ? recipient!.lang! : (language ?? currentLanguage());
  final version = (info?.i18n?[lang] as Map?)?.cast<String, dynamic>();
  final vars = <String, Object?>{
    ...?info?.vars,
    'datum': formatTerminDate(info?.vars?['date']?.toString()),
    ...?recipient?.vars,
  };
  return (
    title: fillPlaceholders(version?['title'] as String? ?? message.title, vars),
    html: fillPlaceholders(version?['html'] as String? ?? message.bodyHtml, vars, html: true),
  );
}

/// Plain template text (paragraphs separated by blank lines) as a Tiptap
/// document (single line breaks become hard breaks, like Ionic).
Map<String, dynamic> textToDoc(String text) {
  return {
    'type': 'doc',
    'content': [
      for (final para in text.split(RegExp(r'\n\n+')))
        {
          'type': 'paragraph',
          'content': [
            for (final (i, line) in para.split('\n').indexed) ...[
              if (i > 0) {'type': 'hardBreak'},
              if (line.isNotEmpty) {'type': 'text', 'text': line},
            ],
          ],
        },
    ],
  };
}
