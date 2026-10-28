import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/team_org/team_org.dart';
import '../../../../l10n/l10n.dart';

/// Protocol settings of an attendance type (Ionic type.page "Protokoll &
/// Tagesordnung"): columns `enable_protocol`, `agenda_default_duration`,
/// `suggest_postponed`.
@immutable
class TypeProtocolSettings {
  const TypeProtocolSettings({
    this.enableProtocol = false,
    this.agendaDefaultDuration,
    this.suggestPostponed = true,
  });

  factory TypeProtocolSettings.fromType(ProtocolType? type) => TypeProtocolSettings(
        enableProtocol: type?.enableProtocol ?? false,
        agendaDefaultDuration: type?.agendaDefaultDuration,
        suggestPostponed: type?.suggestPostponed ?? true,
      );

  final bool enableProtocol;
  final int? agendaDefaultDuration;
  final bool suggestPostponed;

  /// Ionic `onProtocolToggle`: switching on fills the defaults once.
  TypeProtocolSettings toggled(bool enabled) => TypeProtocolSettings(
        enableProtocol: enabled,
        agendaDefaultDuration:
            enabled && (agendaDefaultDuration ?? 0) <= 0 ? 10 : agendaDefaultDuration,
        suggestPostponed: suggestPostponed,
      );

  TypeProtocolSettings copyWith({int? agendaDefaultDuration, bool clearDuration = false, bool? suggestPostponed}) =>
      TypeProtocolSettings(
        enableProtocol: enableProtocol,
        agendaDefaultDuration: clearDuration ? null : (agendaDefaultDuration ?? this.agendaDefaultDuration),
        suggestPostponed: suggestPostponed ?? this.suggestPostponed,
      );

  /// Columns for the `attendance_types` update. The duration column is an
  /// integer NOT NULL (default 10), so an invalid value is left out (Ionic `validate`).
  Map<String, dynamic> toUpdate() => {
        'enable_protocol': enableProtocol,
        'suggest_postponed': suggestPostponed,
        if ((agendaDefaultDuration ?? 0) > 0) 'agenda_default_duration': agendaDefaultDuration,
      };
}

/// True when a plan's field list contains the agenda marker.
bool hasAgendaPlaceholder(List<Map<String, dynamic>> fields) =>
    fields.any((f) => f['id'] == agendaItemsPlaceholderId);

/// Ionic `addAgendaItemsPlaceholder`: the marker takes no time.
Map<String, dynamic> agendaPlaceholderField() =>
    {'id': agendaItemsPlaceholderId, 'name': l10nWithoutContext.typeSettingsAgenda, 'time': '0'};

/// Tiles of the "Protokoll & Tagesordnung" settings (toggle, duration per
/// topic, postponed topics, agenda placeholder hint).
class TypeProtocolSettingsTiles extends StatefulWidget {
  const TypeProtocolSettingsTiles({
    super.key,
    required this.settings,
    required this.onChanged,
    required this.hasPlaceholder,
    required this.onInsertPlaceholder,
    this.showLearnMore = true,
  });

  final TypeProtocolSettings settings;
  final ValueChanged<TypeProtocolSettings> onChanged;
  final bool hasPlaceholder;
  final VoidCallback onInsertPlaceholder;
  final bool showLearnMore;

  @override
  State<TypeProtocolSettingsTiles> createState() => _TypeProtocolSettingsTilesState();
}

class _TypeProtocolSettingsTilesState extends State<TypeProtocolSettingsTiles> {
  late final TextEditingController _duration;

  @override
  void initState() {
    super.initState();
    _duration = TextEditingController(text: widget.settings.agendaDefaultDuration?.toString() ?? '');
  }

  @override
  void didUpdateWidget(TypeProtocolSettingsTiles oldWidget) {
    super.didUpdateWidget(oldWidget);
    final value = widget.settings.agendaDefaultDuration;
    if (value != int.tryParse(_duration.text.trim()) && value != oldWidget.settings.agendaDefaultDuration) {
      _duration.text = value?.toString() ?? '';
    }
  }

  @override
  void dispose() {
    _duration.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.settings;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile.adaptive(
          title: Text(context.l10n.typeSettingsProtocolAgenda),
          subtitle: Text(context.l10n.typeSettingsProtocolHelper),
          value: s.enableProtocol,
          onChanged: (v) => widget.onChanged(s.toggled(v)),
          contentPadding: EdgeInsets.zero,
        ),
        if (widget.showLearnMore)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.help_outline, color: AppColors.primary),
            title: Text(context.l10n.typeSettingsLearnMore, style: const TextStyle(color: AppColors.primary)),
            onTap: () => context.push('/settings/help/article/team-activate'),
          ),
        if (s.enableProtocol) ...[
          Row(
            children: [
              Expanded(child: Text(context.l10n.typeSettingsTopicMinutes)),
              SizedBox(
                width: 80,
                child: TextField(
                  controller: _duration,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.end,
                  decoration: const InputDecoration(hintText: '10', isDense: true),
                  onChanged: (v) {
                    final n = int.tryParse(v.trim());
                    widget.onChanged(n != null && n > 0
                        ? s.copyWith(agendaDefaultDuration: n)
                        : s.copyWith(clearDuration: true));
                  },
                ),
              ),
            ],
          ),
          SwitchListTile.adaptive(
            title: Text(context.l10n.typeSettingsSuggestPostponed),
            subtitle: Text(context.l10n.typeSettingsPostponedHelper),
            value: s.suggestPostponed,
            onChanged: (v) => widget.onChanged(s.copyWith(suggestPostponed: v)),
            contentPadding: EdgeInsets.zero,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            subtitle: Text(context.l10n.typeSettingsPlaceholderHint),
            trailing: widget.hasPlaceholder
                ? null
                : TextButton(
                    onPressed: widget.onInsertPlaceholder,
                    child: Text(context.l10n.typeSettingsInsertPlaceholder),
                  ),
          ),
        ],
      ],
    );
  }
}
