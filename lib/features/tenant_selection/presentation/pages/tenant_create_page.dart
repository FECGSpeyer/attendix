import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/repositories/tenant_create_repository.dart';

/// Page for creating a new tenant/group
class TenantCreatePage extends ConsumerStatefulWidget {
  const TenantCreatePage({super.key});

  @override
  ConsumerState<TenantCreatePage> createState() => _TenantCreatePageState();
}

class _TenantCreatePageState extends ConsumerState<TenantCreatePage> {
  final _formKey = GlobalKey<FormState>();
  final _shortNameController = TextEditingController();
  final _longNameController = TextEditingController();
  final _mainGroupNameController = TextEditingController();
  String _selectedType = 'orchestra';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Neue Gruppe erstellen'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppDimensions.paddingM),
          children: [
            // Welcome card
            Card(
              color: AppColors.primary.withValues(alpha: 0.08),
              child: Padding(
                padding: const EdgeInsets.all(AppDimensions.paddingM),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.rocket_launch_outlined, color: AppColors.primary),
                    const SizedBox(width: AppDimensions.paddingM),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Willkommen!',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Eine Instanz ist dein eigener Bereich für dein Orchester, deinen Chor oder deine Gruppe. Hier verwaltest du Mitglieder, Termine und Anwesenheiten.',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppDimensions.paddingS),

            // Hint card
            Card(
              color: AppColors.warning.withValues(alpha: 0.1),
              child: Padding(
                padding: const EdgeInsets.all(AppDimensions.paddingM),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.lightbulb_outline, color: AppColors.warning),
                    const SizedBox(width: AppDimensions.paddingM),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Du möchtest einer bestehenden Instanz beitreten?',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Bitte deinen Verantwortlichen, dich per E-Mail einzuladen. Eine neue Instanz ist nur nötig, wenn du selbst Administrator sein möchtest.',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppDimensions.paddingM),

            // Info card
            Card(
              color: AppColors.info.withValues(alpha: 0.1),
              child: const Padding(
                padding: EdgeInsets.all(AppDimensions.paddingM),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: AppColors.info),
                    SizedBox(width: AppDimensions.paddingM),
                    Expanded(
                      child: Text(
                        'Du wirst automatisch als Administrator der neuen Gruppe eingetragen.',
                        style: TextStyle(color: AppColors.info),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppDimensions.paddingL),

            // Short Name
            TextFormField(
              controller: _shortNameController,
              maxLength: 30,
              decoration: InputDecoration(
                labelText: 'Kurzname *',
                hintText: _shortNameHint,
                helperText: 'Wird in der Navigation angezeigt',
                prefixIcon: const Icon(Icons.short_text),
              ),
              // Ionic register.page: autocapitalize="sentences"
              textCapitalization: TextCapitalization.sentences,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Kurzname ist erforderlich';
                }
                if (value.trim().length < 2) {
                  return 'Mindestens 2 Zeichen';
                }
                return null;
              },
              autofocus: true,
            ),
            const SizedBox(height: AppDimensions.paddingM),

            // Long Name
            TextFormField(
              controller: _longNameController,
              maxLength: 100,
              decoration: InputDecoration(
                labelText: 'Vollständiger Name (optional)',
                hintText: _longNameHint,
                prefixIcon: const Icon(Icons.title),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: AppDimensions.paddingL),

            // Type selection
            Text(
              'Art der Gruppe',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: AppColors.medium,
              ),
            ),
            const SizedBox(height: AppDimensions.paddingS),
            _buildTypeOption(
              value: 'orchestra',
              icon: Icons.music_note,
              label: 'Orchester',
              description: 'Für Orchester mit Instrumentengruppen',
            ),
            _buildTypeOption(
              value: 'choir',
              icon: Icons.mic,
              label: 'Chor',
              description: 'Für Chöre mit Stimmgruppen',
            ),
            _buildTypeOption(
              value: 'general',
              icon: Icons.groups,
              label: 'Allgemein',
              description: 'Für andere Gruppen oder Vereine',
            ),

            const SizedBox(height: AppDimensions.paddingL),

            // Main group name
            TextFormField(
              controller: _mainGroupNameController,
              maxLength: 50,
              decoration: InputDecoration(
                labelText: 'Name der ersten $_groupLabel',
                hintText: _groupHint,
                helperText: 'Die erste $_groupLabel deiner Organisation',
                prefixIcon: const Icon(Icons.group),
              ),
              textCapitalization: TextCapitalization.sentences,
            ),

            const SizedBox(height: AppDimensions.paddingXL),

            // Summary section
            if (_isSummaryComplete) ...[
              Row(
                children: [
                  const Icon(Icons.check_circle, color: AppColors.success, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Zusammenfassung',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.paddingS),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppDimensions.paddingM),
                  child: Column(
                    children: [
                      _summaryRow('Name', _longNameController.text.trim().isNotEmpty
                          ? _longNameController.text.trim()
                          : _shortNameController.text.trim()),
                      _summaryRow('Kurzname', _shortNameController.text.trim()),
                      _summaryRow('Typ', _typeLabel),
                      if (_mainGroupNameController.text.trim().isNotEmpty)
                        _summaryRow('Erste $_groupLabel', _mainGroupNameController.text.trim()),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppDimensions.paddingL),
            ] else ...[
              Card(
                color: AppColors.warning.withValues(alpha: 0.1),
                child: const Padding(
                  padding: EdgeInsets.all(AppDimensions.paddingM),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber, color: AppColors.warning, size: 20),
                      SizedBox(width: 8),
                      Text('Bitte fülle alle Pflichtfelder aus'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppDimensions.paddingL),
            ],

            // Submit button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_isLoading || !_isSummaryComplete) ? null : _createTenant,
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Gruppe erstellen'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get _groupLabel => switch (_selectedType) {
    'orchestra' => 'Instrumentengruppe',
    'choir' => 'Stimmgruppe',
    _ => 'Gruppe',
  };

  String get _groupHint => switch (_selectedType) {
    'orchestra' => 'z.B. Streicher',
    'choir' => 'z.B. Sopran',
    _ => 'z.B. Gruppe 1',
  };

  String get _shortNameHint => switch (_selectedType) {
    'orchestra' => 'z.B. JON, Philharmonie',
    'choir' => 'z.B. Chor St. Peter, Kantorei',
    _ => 'z.B. Jugendgruppe, Verein XY',
  };

  String get _longNameHint => switch (_selectedType) {
    'orchestra' => 'z.B. Jugendorchester Nürnberg',
    'choir' => 'z.B. Kirchenchor St. Peter und Paul',
    _ => 'z.B. Jugendgruppe Nürnberg e.V.',
  };

  String get _typeLabel => switch (_selectedType) {
    'orchestra' => 'Orchester',
    'choir' => 'Chor',
    _ => 'Allgemein',
  };

  bool get _isSummaryComplete => _shortNameController.text.trim().length >= 2;

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(color: AppColors.medium, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeOption({
    required String value,
    required IconData icon,
    required String label,
    required String description,
  }) {
    final isSelected = _selectedType == value;
    return Card(
      margin: const EdgeInsets.only(bottom: AppDimensions.paddingS),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
        side: BorderSide(
          color: isSelected ? AppColors.primary : Colors.transparent,
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: () => setState(() => _selectedType = value),
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.paddingM),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary.withValues(alpha: 0.2)
                      : AppColors.medium.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
                ),
                child: Icon(
                  icon,
                  color: isSelected ? AppColors.primary : AppColors.medium,
                ),
              ),
              const SizedBox(width: AppDimensions.paddingM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: isSelected ? AppColors.primary : null,
                      ),
                    ),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.medium,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                const Icon(Icons.check_circle, color: AppColors.primary),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _createTenant() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final shortName = _shortNameController.text.trim();
      final longName = _longNameController.text.trim().isNotEmpty
          ? _longNameController.text.trim()
          : shortName;

      // Create default instrument/section group
      final defaultGroupName = switch (_selectedType) {
        'orchestra' => 'Streicher',
        'choir' => 'Sopran',
        _ => 'Gruppe 1',
      };

      final groupName = _mainGroupNameController.text.trim().isNotEmpty
          ? _mainGroupNameController.text.trim()
          : defaultGroupName;

      // Ionic createInstance: tenant with register defaults, creator as
      // ADMIN, main group and default attendance types.
      final newTenant =
          await ref.read(tenantCreateRepositoryProvider).createTenant(
                shortName: shortName,
                longName: longName,
                type: _selectedType,
                mainGroupName: groupName,
              );

      // Refresh the tenants list
      ref.invalidate(userTenantsProvider);

      // Set as current tenant
      await ref.read(currentTenantProvider.notifier).setTenant(newTenant);

      if (mounted) {
        ToastHelper.showSuccess(context, 'Instanz wurde erfolgreich erstellt!');
        context.go('/people');
      }
    } catch (e) {
      if (mounted) {
        ToastHelper.showError(context, 'Fehler: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
