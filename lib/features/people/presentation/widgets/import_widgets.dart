import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/import_mapper.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart'; // IOS_LOOK

/// A selectable mapping target. `key == null` means "Ignorieren".
typedef ImportTargetOption = ({String? key, String label});

/// Step 1 of an import: intro text, "Datei auswählen", "Vorlage herunterladen".
class ImportFileStep extends StatelessWidget {
  const ImportFileStep({
    super.key,
    required this.intro,
    required this.onPickFile,
    required this.onDownloadTemplate,
  });

  final String intro;
  final VoidCallback onPickFile;
  final VoidCallback onDownloadTemplate;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      children: [
        Text(intro),
        const SizedBox(height: AppDimensions.paddingM),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.cloud_upload_outlined, color: AppColors.primary),
                title: Text(context.l10n.peopleChooseFile,
                    style: const TextStyle(color: AppColors.primary)),
                onTap: onPickFile,
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.download_outlined),
                title: Text(context.l10n.peopleDownloadTemplate),
                onTap: onDownloadTemplate,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Step 2 of an import: one dropdown per file column.
class ImportMappingStep extends StatelessWidget {
  const ImportMappingStep({
    super.key,
    required this.fileName,
    required this.rowCount,
    required this.intro,
    required this.headers,
    required this.mapping,
    required this.options,
    required this.onChanged,
    required this.missingHint,
    required this.canProceed,
  });

  final String fileName;
  final int rowCount;
  final String intro;
  final List<String> headers;
  final ColumnMapping mapping;
  final List<ImportTargetOption> options;
  final void Function(String header, String? key) onChanged;
  final String missingHint;
  final bool canProceed;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      children: [
        Text.rich(TextSpan(children: [
          TextSpan(text: fileName, style: const TextStyle(fontWeight: FontWeight.bold)),
          TextSpan(text: ' — ${context.l10n.peopleFileRows(rowCount)}'),
        ])),
        const SizedBox(height: AppDimensions.paddingS),
        Text(intro),
        const SizedBox(height: AppDimensions.paddingM),
        for (final header in headers)
          Padding(
            padding: const EdgeInsets.only(bottom: AppDimensions.paddingS),
            child: AppDropdownFormField<String?>(
              // ignore: deprecated_member_use
              value: mapping[header],
              isExpanded: true,
              decoration: InputDecoration(labelText: header),
              hint: Text(context.l10n.peopleChooseFieldPlaceholder),
              items: [
                for (final opt in options)
                  DropdownMenuItem<String?>(value: opt.key, child: Text(opt.label)),
              ],
              onChanged: (value) => onChanged(header, value),
            ),
          ),
        if (!canProceed)
          Padding(
            padding: const EdgeInsets.only(top: AppDimensions.paddingS),
            child: Text(missingHint, style: const TextStyle(color: AppColors.warning)),
          ),
      ],
    );
  }
}

/// Summary chips of the preview step.
class ImportSummaryChips extends StatelessWidget {
  const ImportSummaryChips({
    super.key,
    required this.ready,
    required this.warnings,
    required this.duplicates,
    required this.errors,
  });

  final int ready;
  final int warnings;
  final int duplicates;
  final int errors;

  @override
  Widget build(BuildContext context) {
    Widget chip(String label, Color color) => Chip(
          label: Text(label, style: TextStyle(color: color)),
          side: BorderSide(color: color),
          backgroundColor: Colors.transparent,
        );
    return Wrap(
      spacing: AppDimensions.paddingS,
      runSpacing: AppDimensions.paddingXS,
      children: [
        chip(context.l10n.peopleReady(ready), AppColors.success),
        if (warnings > 0) chip(context.l10n.peopleWithHint(warnings), AppColors.warning),
        if (duplicates > 0)
          chip(context.l10n.peopleDuplicates(duplicates), AppColors.medium),
        if (errors > 0) chip(context.l10n.peopleFaulty(errors), AppColors.danger),
      ],
    );
  }
}

/// Status icon for a preview row ('ok' | 'warning' | 'duplicate' | 'error').
class ImportRowStatusIcon extends StatelessWidget {
  const ImportRowStatusIcon({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    return switch (status) {
      'ok' => const Icon(Icons.check_circle, color: AppColors.success, size: 20),
      'error' => const Icon(Icons.cancel, color: AppColors.danger, size: 20),
      'duplicate' => const Icon(Icons.copy, color: AppColors.medium, size: 20),
      _ => const Icon(Icons.warning_amber, color: AppColors.warning, size: 20),
    };
  }
}

/// Error/warning lines below a preview row.
class ImportRowMessages extends StatelessWidget {
  const ImportRowMessages({super.key, required this.errors, required this.warnings});

  final List<String> errors;
  final List<String> warnings;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final e in errors)
          Text(e, style: const TextStyle(color: AppColors.danger, fontSize: 12)),
        for (final w in warnings)
          Text(w, style: const TextStyle(color: AppColors.warning, fontSize: 12)),
      ],
    );
  }
}

/// Bottom bar with "Zurück" / primary action.
class ImportBottomBar extends StatelessWidget {
  const ImportBottomBar({
    super.key,
    required this.onBack,
    required this.primaryLabel,
    required this.onPrimary,
  });

  final VoidCallback onBack;
  final String primaryLabel;
  final VoidCallback? onPrimary;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.paddingM,
          vertical: AppDimensions.paddingS,
        ),
        child: Row(
          children: [
            TextButton(onPressed: onBack, child: Text(context.l10n.commonBack)),
            const Spacer(),
            FilledButton(onPressed: onPrimary, child: Text(primaryLabel)),
          ],
        ),
      ),
    );
  }
}

/// Shows the first 10 failures (Ionic: "Nicht importierte ...").
Future<void> showImportFailures(
  BuildContext context, {
  required String title,
  required List<String> lines,
}) {
  final shown = lines.take(10).map((l) => '• $l').join('\n');
  final more = lines.length > 10 ? '\n${context.l10n.peopleAndMore(lines.length - 10)}' : '';
  return showAppDialog<void>(
    context: context,
    builder: (context) => AppAlertDialog(
      title: Text(title),
      content: SingleChildScrollView(child: Text('$shown$more')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(context.l10n.commonOk)),
      ],
    ),
  );
}
