import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/branding_providers.dart';
import '../../../../core/providers/player_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/services/pdf_branding.dart';
import '../../../../core/services/register_plan_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/person/person.dart';

/// Show the register plan sheet
Future<void> showRegisterPlanSheet(BuildContext context) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) => const RegisterPlanSheet(),
  );
}

/// Bottom sheet for generating register rehearsal plans
class RegisterPlanSheet extends ConsumerStatefulWidget {
  const RegisterPlanSheet({super.key});

  @override
  ConsumerState<RegisterPlanSheet> createState() => _RegisterPlanSheetState();
}

class _RegisterPlanSheetState extends ConsumerState<RegisterPlanSheet> {
  final Set<int> _selectedConductorIds = {};
  int _totalMinutes = 60;
  RegisterPlan? _generatedPlan;
  final _minutesController = TextEditingController(text: '60');

  @override
  void dispose() {
    _minutesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final playersAsync = ref.watch(playersProvider);
    final tenant = ref.watch(currentTenantProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          ListTile(
            title: const Text(
              'Registerprobenplan',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            subtitle: Text(
              tenant?.type == 'choir'
                  ? 'Sopran, Alt, Tenor, Bass'
                  : tenant?.type == 'orchestra'
                      ? 'Streicher, Holzbläser, Sonstige'
                      : 'Gruppen 1-3',
            ),
            trailing: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          const Divider(),

          Expanded(
            child: _generatedPlan == null
                ? _buildConfigView(playersAsync, tenant?.type ?? 'general', scrollController)
                : _buildResultView(scrollController),
          ),
        ],
      ),
    );
  }

  Widget _buildConfigView(
    AsyncValue<List<Person>> playersAsync,
    String tenantType,
    ScrollController scrollController,
  ) {
    return playersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Fehler: $e')),
      data: (players) {
        // Filter to only show conductors/voice leaders (players with specific roles)
        // Use isLeader or groupName patterns to identify potential conductors
        final conductorCandidates = players.where((p) =>
            p.isLeader == true || // Voice leaders
            (p.groupName?.toLowerCase().contains('stimm') ?? false) ||
            (p.groupName?.toLowerCase().contains('leader') ?? false) ||
            (p.groupName?.toLowerCase().contains('dirigent') ?? false) ||
            _selectedConductorIds.contains(p.id)).toList();

        // If no pre-filtered conductors, show all players
        final displayPlayers = conductorCandidates.isNotEmpty ? conductorCandidates : players;

        return ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(AppDimensions.paddingM),
          children: [
            // Time input
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppDimensions.paddingM),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Gesamtdauer',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _minutesController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              suffixText: 'Minuten',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (value) {
                              final mins = int.tryParse(value);
                              if (mins != null && mins > 0) {
                                setState(() => _totalMinutes = mins);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Quick presets
                        ...[30, 45, 60, 90].map((mins) => Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: ActionChip(
                                label: Text('$mins'),
                                onPressed: () {
                                  setState(() {
                                    _totalMinutes = mins;
                                    _minutesController.text = mins.toString();
                                  });
                                },
                                backgroundColor: _totalMinutes == mins
                                    ? AppColors.primary.withValues(alpha: 0.2)
                                    : null,
                              ),
                            )),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppDimensions.paddingM),

            // Conductor selection
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppDimensions.paddingM),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Dirigenten/Stimmführer auswählen',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${_selectedConductorIds.length} ausgewählt',
                          style: TextStyle(color: AppColors.medium),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_selectedConductorIds.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(AppDimensions.paddingM),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline, color: AppColors.warning),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Bitte mindestens eine Person auswählen',
                                style: TextStyle(color: AppColors.warning),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: displayPlayers
                          .where((person) => person.id != null) // BL-001: Filter out invalid persons
                          .map((person) {
                        final isSelected = _selectedConductorIds.contains(person.id);
                        return FilterChip(
                          label: Text(person.fullName),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedConductorIds.add(person.id!);
                              } else {
                                _selectedConductorIds.remove(person.id);
                              }
                            });
                          },
                          avatar: person.img != null
                              ? CircleAvatar(
                                  backgroundImage: NetworkImage(person.img!),
                                )
                              : CircleAvatar(child: Text(person.initials)),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppDimensions.paddingL),

            // Generate button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _selectedConductorIds.isEmpty
                    ? null
                    : () => _generatePlan(players),
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Plan generieren'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(AppDimensions.paddingM),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildResultView(ScrollController scrollController) {
    final plan = _generatedPlan!;

    return Column(
      children: [
        // Summary
        Card(
          margin: const EdgeInsets.all(AppDimensions.paddingM),
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.paddingM),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatColumn(
                  label: 'Gesamt',
                  value: '${plan.totalMinutes} Min.',
                ),
                _StatColumn(
                  label: 'Pro Einheit',
                  value: '${plan.minutesPerUnit} Min.',
                ),
                _StatColumn(
                  label: 'Dirigenten',
                  value: '${plan.conductors.length}',
                ),
              ],
            ),
          ),
        ),

        // Table header
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.paddingM,
            vertical: AppDimensions.paddingS,
          ),
          color: AppColors.primary.withValues(alpha: 0.1),
          child: Row(
            children: [
              const SizedBox(
                width: 60,
                child: Text(
                  'Zeit',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              ...plan.groups.map((group) => Expanded(
                    child: Text(
                      group,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  )),
            ],
          ),
        ),

        // Table body
        Expanded(
          child: ListView.separated(
            controller: scrollController,
            itemCount: plan.entries.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final entry = plan.entries[index];
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.paddingM,
                  vertical: AppDimensions.paddingS,
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 60,
                      child: Text(
                        entry.time,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    ...plan.groups.map((group) {
                      final conductor = entry.groupAssignments[group];
                      return Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: conductor != null
                                ? AppColors.info.withValues(alpha: 0.1)
                                : null,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            conductor ?? '-',
                            style: TextStyle(
                              fontSize: 11,
                              color: conductor != null ? null : AppColors.medium,
                            ),
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              );
            },
          ),
        ),

        // Action buttons
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.paddingM),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      setState(() => _generatedPlan = null);
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Neu generieren'),
                  ),
                ),
                const SizedBox(width: AppDimensions.paddingM),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _sharePlan,
                    icon: const Icon(Icons.share),
                    label: const Text('Teilen'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _generatePlan(List<Person> allPlayers) {
    final selectedConductors = allPlayers
        .where((p) => _selectedConductorIds.contains(p.id))
        .toList();

    if (selectedConductors.isEmpty) {
      ToastHelper.showWarning(context, 'Bitte mindestens eine Person auswählen');
      return;
    }

    final tenant = ref.read(currentTenantProvider);
    final service = RegisterPlanService();

    try {
      final plan = service.generate(
        conductors: selectedConductors,
        totalMinutes: _totalMinutes,
        tenantType: tenant?.type ?? 'general',
      );

      setState(() => _generatedPlan = plan);
    } catch (e) {
      ToastHelper.showError(context, 'Fehler bei der Generierung: $e');
    }
  }

  Future<void> _sharePlan() async {
    if (_generatedPlan == null) return;

    final format = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Format wählen'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.picture_as_pdf),
              title: const Text('Als PDF'),
              subtitle: const Text('Druckbar, A4 Querformat'),
              onTap: () => Navigator.pop(ctx, 'pdf'),
            ),
            ListTile(
              leading: const Icon(Icons.text_snippet),
              title: const Text('Als Text'),
              subtitle: const Text('Zum Kopieren'),
              onTap: () => Navigator.pop(ctx, 'text'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Abbrechen'),
          ),
        ],
      ),
    );

    if (format == null || !mounted) return;

    if (format == 'pdf') {
      await _exportPdf();
    } else {
      await _showTextDialog();
    }
  }

  Future<void> _exportPdf() async {
    final tenant = ref.read(currentTenantProvider);
    final plan = _generatedPlan!;
    final date = DateFormat('dd.MM.yyyy').format(DateTime.now());
    // MISC2: letterhead with tenant/org branding (Ionic addBrandingHeader)
    final branding = ref.read(includeBrandingProvider) ? await resolvePdfBranding(ref) : null;

    final pdf = pw.Document();

    // Build table data
    final headers = ['Zeit', ...plan.groups];
    final data = plan.entries.map((entry) {
      return [
        entry.time,
        ...plan.groups.map((g) => entry.groupAssignments[g] ?? '-'),
      ];
    }).toList();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(30),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            buildPdfBrandingHeader(
              branding: branding,
              title: '${tenant?.shortName ?? 'Gruppe'} Registerprobenplan',
              subtitle: 'Stand: $date | ${plan.totalMinutes} Min. | ${plan.minutesPerUnit} Min./Einheit',
            ),
            pw.TableHelper.fromTextArray(
              headers: headers,
              data: data,
              cellStyle: const pw.TextStyle(fontSize: 10),
              headerStyle: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColor.fromInt(0xFF005238),
              ),
              cellAlignment: pw.Alignment.center,
              headerAlignment: pw.Alignment.center,
              border: pw.TableBorder.all(color: PdfColors.grey300),
              cellPadding: const pw.EdgeInsets.all(6),
            ),
            pw.SizedBox(height: 16),
            pw.Text(
              'Dirigenten: ${plan.conductors.join(', ')}',
              style: const pw.TextStyle(fontSize: 9),
            ),
          ],
        ),
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: '${tenant?.shortName ?? 'Gruppe'}_Registerprobenplan_$date.pdf',
    );
  }

  Future<void> _showTextDialog() async {
    final service = RegisterPlanService();
    final text = service.formatAsText(_generatedPlan!);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Registerprobenplan'),
        content: SingleChildScrollView(
          child: SelectableText(
            text,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Schließen'),
          ),
        ],
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  final String label;
  final String value;

  const _StatColumn({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.medium,
          ),
        ),
      ],
    );
  }
}
