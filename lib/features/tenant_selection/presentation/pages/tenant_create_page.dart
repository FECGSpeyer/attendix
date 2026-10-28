import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/repositories/tenant_create_repository.dart';

/// AUTH: Ionic "Neue Instanz anlegen" (register.page) – 3 steps:
/// 1. Art der Gruppe, 2. Name + Kürzel, 3. Hauptgruppe, then summary.
class TenantCreatePage extends ConsumerStatefulWidget {
  const TenantCreatePage({super.key});

  @override
  ConsumerState<TenantCreatePage> createState() => _TenantCreatePageState();
}

/// Type-specific texts of the wizard (Ionic register.placeholder.* / help*).
class TenantTypeTexts {
  const TenantTypeTexts({
    required this.option,
    required this.label,
    required this.help,
    required this.namePlaceholder,
    required this.shortPlaceholder,
    required this.mainGroupPlaceholder,
    required this.icon,
  });

  final String option;
  final String label;
  final String help;
  final String namePlaceholder;
  final String shortPlaceholder;
  final String mainGroupPlaceholder;
  final IconData icon;

  static const Map<String, TenantTypeTexts> byType = {
    'general': TenantTypeTexts(
      option: 'Allgemeine Gruppe',
      label: 'Allgemeine Gruppe',
      help: 'Ideal für Vereine, Teams oder sonstige Gruppen.',
      namePlaceholder: 'z.B. Sportverein Musterstadt',
      shortPlaceholder: 'z.B. SVM',
      mainGroupPlaceholder: 'z.B. Vorstand',
      icon: Icons.groups_outlined,
    ),
    'choir': TenantTypeTexts(
      option: 'Chor / Gesangsgruppe',
      label: 'Chor',
      help: 'Optimiert für Chöre mit Stimmgruppen (Sopran, Alt, Tenor, Bass).',
      namePlaceholder: 'z.B. Gospelchor Harmonie',
      shortPlaceholder: 'z.B. GCH',
      mainGroupPlaceholder: 'z.B. Chorleitung',
      icon: Icons.mic_none,
    ),
    'orchestra': TenantTypeTexts(
      option: 'Orchester / Musikgruppe',
      label: 'Orchester',
      help: 'Optimiert für Orchester/Musikgruppen mit Instrumentengruppen.',
      namePlaceholder: 'z.B. Stadtorchester Musterstadt',
      shortPlaceholder: 'z.B. SOM',
      mainGroupPlaceholder: 'z.B. Dirigenten',
      icon: Icons.music_note_outlined,
    ),
  };

  static TenantTypeTexts of(String type) => byType[type] ?? byType['general']!;
}

class _TenantCreatePageState extends ConsumerState<TenantCreatePage> {
  final _shortNameController = TextEditingController();
  final _longNameController = TextEditingController();
  final _mainGroupNameController = TextEditingController();
  String _selectedType = 'general';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _shortNameController.addListener(_onFieldChanged);
    _longNameController.addListener(_onFieldChanged);
    _mainGroupNameController.addListener(_onFieldChanged);
  }

  void _onFieldChanged() => setState(() {});

  @override
  void dispose() {
    _shortNameController.removeListener(_onFieldChanged);
    _longNameController.removeListener(_onFieldChanged);
    _mainGroupNameController.removeListener(_onFieldChanged);
    _shortNameController.dispose();
    _longNameController.dispose();
    _mainGroupNameController.dispose();
    super.dispose();
  }

  String get _longName => _longNameController.text.trim();
  String get _shortName => _shortNameController.text.trim();
  String get _mainGroupName => _mainGroupNameController.text.trim();
  bool get _isComplete =>
      _longName.isNotEmpty && _shortName.isNotEmpty && _mainGroupName.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final texts = TenantTypeTexts.of(_selectedType);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Neue Instanz anlegen'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _isLoading
              ? null
              : () => context.canPop() ? context.pop() : context.go('/tenants'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppDimensions.paddingM),
        children: [
          // Intro card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.paddingM),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.rocket_launch_outlined,
                          color: AppColors.primary),
                      const SizedBox(width: AppDimensions.paddingS),
                      Text('Willkommen!',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: AppDimensions.paddingS),
                  Text.rich(
                    TextSpan(children: [
                      const TextSpan(text: 'Eine '),
                      const TextSpan(
                        text: 'Instanz',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const TextSpan(
                        text:
                            ' ist dein eigener Bereich für dein Orchester, deinen Chor oder deine Gruppe. Hier verwaltest du Mitglieder, Termine und Anwesenheiten.',
                      ),
                    ]),
                  ),
                ],
              ),
            ),
          ),

          // Join hint
          Card(
            color: AppColors.warning.withValues(alpha: 0.1),
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.paddingM),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Du möchtest einer bestehenden Instanz beitreten?',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Bitte deinen Verantwortlichen, dich per E-Mail einzuladen. Eine neue Instanz ist nur nötig, wenn du selbst Administrator sein möchtest.',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppDimensions.paddingM),

          // Step 1
          _StepHeader(badge: '1', title: 'Art der Gruppe wählen'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.paddingM),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    value: _selectedType,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Gruppentyp',
                      helperText: 'Was beschreibt deine Gruppe am besten?',
                    ),
                    items: [
                      for (final entry in TenantTypeTexts.byType.entries)
                        DropdownMenuItem(
                          value: entry.key,
                          child: Row(
                            children: [
                              Icon(entry.value.icon, size: 20),
                              const SizedBox(width: AppDimensions.paddingS),
                              Text(entry.value.option),
                            ],
                          ),
                        ),
                    ],
                    onChanged: _isLoading
                        ? null
                        : (value) =>
                            setState(() => _selectedType = value ?? 'general'),
                  ),
                  const SizedBox(height: AppDimensions.paddingM),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.check_circle,
                          color: AppColors.success, size: 18),
                      const SizedBox(width: AppDimensions.paddingS),
                      Expanded(child: Text(texts.help)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppDimensions.paddingM),

          // Step 2
          _StepHeader(badge: '2', title: 'Name deiner Instanz'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.paddingM),
              child: Column(
                children: [
                  TextField(
                    controller: _longNameController,
                    maxLength: 50,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: 'Vollständiger Name',
                      hintText: texts.namePlaceholder,
                      helperText: 'Der Name wird in der App angezeigt',
                    ),
                  ),
                  const SizedBox(height: AppDimensions.paddingS),
                  TextField(
                    controller: _shortNameController,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      labelText: 'Instanz-Kürzel',
                      hintText: texts.shortPlaceholder,
                      helperText: 'Wird für kompakte Darstellungen verwendet',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppDimensions.paddingM),

          // Step 3
          _StepHeader(
            badge: '3',
            title: 'Hauptgruppe festlegen',
            trailing: IconButton(
              tooltip: 'Was ist die Hauptgruppe?',
              icon: const Icon(Icons.help_outline),
              onPressed: _showMainGroupInfo,
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.paddingM),
              child: TextField(
                controller: _mainGroupNameController,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'Name der Hauptgruppe',
                  hintText: texts.mainGroupPlaceholder,
                  helperText: 'z.B. Leitung, Dirigenten, Vorstand',
                ),
              ),
            ),
          ),
          const SizedBox(height: AppDimensions.paddingM),

          // Summary
          _StepHeader(badge: '✓', title: 'Zusammenfassung'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.paddingM),
              child: _isComplete
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text.rich(TextSpan(children: [
                          TextSpan(
                            text: _longName,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          TextSpan(text: ' ($_shortName)'),
                        ])),
                        const SizedBox(height: 4),
                        Text('Typ: ${texts.label}'),
                        const SizedBox(height: 4),
                        Text('Hauptgruppe: $_mainGroupName'),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.error_outline,
                                color: AppColors.medium, size: 18),
                            const SizedBox(width: AppDimensions.paddingS),
                            const Expanded(
                              child: Text(
                                  'Bitte fülle alle Felder aus, um fortzufahren.'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        for (final missing in [
                          if (_longName.isEmpty) 'Name der Instanz fehlt',
                          if (_shortName.isEmpty) 'Instanz-Kürzel fehlt',
                          if (_mainGroupName.isEmpty) 'Name der Hauptgruppe fehlt',
                        ])
                          Padding(
                            padding: const EdgeInsets.only(left: 26, top: 2),
                            child: Text('• $missing',
                                style: TextStyle(color: AppColors.medium)),
                          ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: AppDimensions.paddingM),

          FilledButton.icon(
            onPressed: (_isLoading || !_isComplete) ? null : _createTenant,
            icon: _isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add_circle_outline),
            label: Text(_isLoading
                ? 'Instanz wird erstellt...'
                : 'Instanz jetzt erstellen'),
          ),
          const SizedBox(height: AppDimensions.paddingXL),
        ],
      ),
    );
  }

  /// Ionic main-group info popover (register.mainGroupInfoHtml).
  Future<void> _showMainGroupInfo() {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Was ist die Hauptgruppe?'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Die Hauptgruppe ist eine besondere Gruppe für Personen mit Leitungsfunktion (z.B. Dirigenten, Chorleiter, Vorstand).',
            ),
            SizedBox(height: 12),
            Text('Besonderheiten:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 4),
            Text('• Kann nicht gelöscht werden'),
            Text('• Mitglieder erhalten automatisch erweiterte Rechte'),
            Text('• Ideal für Personen, die die Instanz verwalten'),
            SizedBox(height: 12),
            Text(
              'Du kannst später weitere Gruppen (z.B. Sopran, Geigen) hinzufügen.',
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _createTenant() async {
    if (!_isComplete) {
      ToastHelper.showError(context, 'Bitte füllen Sie alle Felder aus.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Ionic createInstance: tenant with register defaults, creator as
      // ADMIN, main group and default attendance types.
      final newTenant =
          await ref.read(tenantCreateRepositoryProvider).createTenant(
                shortName: _shortName,
                longName: _longName,
                type: _selectedType,
                mainGroupName: _mainGroupName,
              );

      // Refresh the tenants list
      ref.invalidate(userTenantsProvider);

      // Set as current tenant
      await ref.read(currentTenantProvider.notifier).setTenant(newTenant);

      if (mounted) {
        context.go('/people');
      }
    } catch (e) {
      if (mounted) {
        ToastHelper.showError(context, 'Fehler beim Erstellen der Instanz: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}

class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.badge, required this.title, this.trailing});

  final String badge;
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
          left: AppDimensions.paddingXS, bottom: AppDimensions.paddingXS),
      child: Row(
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: AppColors.primary,
            child: Text(
              badge,
              style: const TextStyle(
                  color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: AppDimensions.paddingS),
          Expanded(
            child: Text(
              title,
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
