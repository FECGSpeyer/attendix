import 'package:flutter/material.dart';

import '../../../../../core/constants/app_constants.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../data/models/person/person.dart';
import '../../../../../l10n/l10n.dart';
import '../ion/ion_widgets.dart';
import '../../../../../shared/widgets/adaptive/ion_button_label.dart';

/// Accordion section for problem person management.
class ProblemfallAccordion extends StatelessWidget {
  const ProblemfallAccordion({
    super.key,
    required this.person,
    required this.isExpanded,
    required this.onToggle,
    required this.problemSolved,
    required this.onProblemSolvedChanged,
    required this.problemNotes,
    required this.onProblemNotesChanged,
    required this.onResolveProblem,
  });

  final Person person;
  final bool isExpanded;
  final VoidCallback onToggle;
  final bool problemSolved;
  final ValueChanged<bool> onProblemSolvedChanged;
  final String problemNotes;
  final ValueChanged<String> onProblemNotesChanged;
  final VoidCallback onResolveProblem;

  @override
  Widget build(BuildContext context) {
    if (!person.isCritical) return const SizedBox.shrink();

    return IonAccordion(
      title: context.l10n.peopleProblemCase,
      expanded: isExpanded,
      onToggle: onToggle,
      child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimensions.paddingM,
                0,
                AppDimensions.paddingM,
                AppDimensions.paddingM,
              ),
              child: _buildContent(context),
            ),
    );
  }

  Widget _buildContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Reason display
        if (person.criticalReason != null && person.criticalReason!.isNotEmpty) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppDimensions.paddingM),
            decoration: BoxDecoration(
              color: AppColors.danger.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.excuseReason,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.danger,
                  ),
                ),
                const SizedBox(height: AppDimensions.paddingXS),
                Text(
                  person.criticalReason!,
                  style: const TextStyle(color: AppColors.dark),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimensions.paddingM),
        ],

        // Problem solved toggle
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: Text(context.l10n.personTalkedTo),
          subtitle: Text(context.l10n.personFlutterTalkedToHint),
          value: problemSolved,
          onChanged: onProblemSolvedChanged,
          activeColor: AppColors.success,
        ),

        // Notes and resolve button (only when solved)
        if (problemSolved) ...[
          const SizedBox(height: AppDimensions.paddingM),
          TextField(
            decoration: InputDecoration(
              labelText: context.l10n.personRemarks,
              hintText: context.l10n.personFlutterRemarksHint,
              border: const OutlineInputBorder(),
            ),
            maxLines: 3,
            onChanged: onProblemNotesChanged,
          ),
          const SizedBox(height: AppDimensions.paddingM),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onResolveProblem,
              icon: const Icon(Icons.check_circle),
              label: IonButtonLabel(context.l10n.personResetTalked),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.success,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
