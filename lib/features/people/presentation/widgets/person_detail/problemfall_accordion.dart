import 'package:flutter/material.dart';
import 'package:attendix/core/theme/redesign/rd_theme.dart' show RdSkinContext;

import '../../../../../core/constants/app_constants.dart';
import '../../../../../data/models/person/person.dart';
import '../../../../../l10n/l10n.dart';
import '../ion/ion_widgets.dart';

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
  });

  final Person person;
  final bool isExpanded;
  final VoidCallback onToggle;
  final bool problemSolved;
  final ValueChanged<bool> onProblemSolvedChanged;
  final String problemNotes;
  final ValueChanged<String> onProblemNotesChanged;

  @override
  Widget build(BuildContext context) {
    if (!person.isCritical) return const SizedBox.shrink();

    return IonAccordion(
      title: context.l10n.peopleProblemCase,
      expanded: isExpanded,
      onToggle: onToggle,
      // PEO-19: Ionic full-width items (toggle item + stacked textarea).
      child: context.rdSkin == null
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                IonToggleRow(
                  label: context.l10n.personTalkedTo,
                  value: problemSolved,
                  editable: true,
                  onChanged: onProblemSolvedChanged,
                ),
                if (problemSolved)
                  IonInputRow(
                    label: context.l10n.personRemarks,
                    value: problemNotes,
                    textarea: true,
                    onChanged: (v) => onProblemNotesChanged(v),
                  ),
              ],
            )
          : Padding(
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

  /// Ionic person.page: toggle "Mit Person gesprochen" and, when on, the
  /// "Bemerkungen" textarea. The case is solved with the save (FAB).
  Widget _buildContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: Text(context.l10n.personTalkedTo),
          value: problemSolved,
          onChanged: onProblemSolvedChanged,
        ),
        if (problemSolved) ...[
          const SizedBox(height: AppDimensions.paddingS),
          TextField(
            decoration: InputDecoration(
              labelText: context.l10n.personRemarks,
              border: const OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.sentences,
            minLines: 2,
            maxLines: null,
            onChanged: onProblemNotesChanged,
          ),
        ],
      ],
    );
  }
}
