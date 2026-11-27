part of 'rd_import_page.dart';

/// A question about an unknown part name with its answers as chips, always
/// in the same order: suggestion (✦ from the KI), the own pick, "Neue
/// Gruppe", "Ohne Zuordnung", "Andere …" last. They work like radio
/// buttons: tapping the chosen answer keeps it, and tapping the one the KI
/// filled in takes it as the person's own (the ✦ goes).
/// The head of a group of questions ([rdImportQuestionGroups]): what they
/// most likely mean, how many names and files, what is still open, and
/// "Alle als …" for the ones nobody answered by hand.
class _QuestionGroupCard extends StatelessWidget {
  const _QuestionGroupCard({
    required this.title,
    required this.group,
    required this.decisions,
    required this.aiFilled,
    required this.open,
    required this.onToggle,
    required this.onAll,
  });

  final String title;
  final RdImportQuestionGroup group;
  final RdImportDecisions decisions;
  final Set<String> aiFilled;
  final bool open;
  final VoidCallback onToggle;
  final ValueChanged<Map<String, RdImportCategory>> onAll;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final c = group.category;
    final questions = group.questions;
    final openCount = questions.where((q) => decisions.answers[q.key] == null && q.proposed == null).length;
    // Answers given by hand stay; the KI's and the proposed ones are taken.
    final toTake = <String, RdImportCategory>{
      if (c != null)
        for (final q in questions)
          if (!decisions.answers.containsKey(q.key) || aiFilled.contains(q.key)) q.key: c,
    };
    final names = questions.take(6).map((q) => q.label).join(', ');
    final Widget status;
    if (openCount > 0) {
      status = RdPill(l10n.redesignImportGroupOpen(openCount), tone: RdTone.late);
    } else if (toTake.isEmpty) {
      status = Semantics(
        label: l10n.redesignImportGroupAnswered,
        child: ExcludeSemantics(child: Icon(Icons.check_circle, size: 20, color: p.present)),
      );
    } else {
      status = ExcludeSemantics(child: Icon(Icons.auto_awesome, size: 18, color: p.primary));
    }
    return RdCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            button: true,
            expanded: open,
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: onToggle,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: p.text)),
                        const SizedBox(height: 2),
                        Text(
                          [l10n.redesignImportGroupNames(questions.length), l10n.redesignImportFoundFiles(group.fileCount)].join(' · '),
                          style: RdType.meta(p, size: 13),
                        ),
                      ],
                    ),
                  ),
                  status,
                  const SizedBox(width: 6),
                  ExcludeSemantics(child: Icon(open ? Icons.expand_less : Icons.expand_more, color: p.text2)),
                ],
              ),
            ),
          ),
          if (!open) ...[
            const SizedBox(height: 6),
            Text(
              questions.length > 6 ? '$names …' : names,
              style: RdType.meta(p, size: 13),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (c == null) ...[
            const SizedBox(height: 6),
            Text(l10n.redesignImportGroupUnclearDetail, style: RdType.meta(p, size: 13)),
          ],
          if (toTake.isNotEmpty) ...[
            const SizedBox(height: 10),
            RdOutlineButton(
              label: c?.fromPage == true ? l10n.redesignImportGroupAllFromPage : l10n.redesignImportGroupAllAs(title),
              height: 40,
              onPressed: () => onAll(toTake),
            ),
          ],
        ],
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required this.plan,
    required this.question,
    required this.answer,
    required this.onAnswer,
    this.ai,
    this.filled = false,
    this.proposedOnly = false,
    this.newGroups = const [],
    this.preview,
    this.readPages = false,
  });

  final RdImportPlan plan;
  final RdImportQuestion question;
  final RdImportCategory? answer;
  final ValueChanged<RdImportCategory?> onAnswer;

  /// New groups other answers create, to pick under "Andere …".
  final List<String> newGroups;

  /// The KI's guess (marked ✦).
  final RdImportCategory? ai;

  /// Whether [answer] was filled in by the KI and not taken yet.
  final bool filled;

  /// Whether [answer] is only the new group a known instrument proposes
  /// (nobody answered yet): a tap takes it, the name opens only after.
  final bool proposedOnly;

  /// The first pages of some of its files, shown above the choices.
  final Widget Function()? preview;

  /// "Von Seite 1 lesen" can be answered: the KI reads the first page of
  /// each file.
  final bool readPages;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final suggestion = question.suggestion == null ? null : RdImportCategory(instrumentId: question.suggestion);
    final label = question.label;
    final newName = question.newGroup ?? (label.isEmpty ? label : label[0].toUpperCase() + label.substring(1));
    final ai = this.ai;
    final newGroup = answer?.newGroup != null && answer != ai ? answer! : RdImportCategory(newGroup: newName);
    // A name with two instruments ("Posaune und Tuba") is never one group:
    // each instrument is offered on its own, the group if there is one.
    final parts = question.newGroup == null ? InstrumentMatcher.knownGroups(label, isChoir: plan.isChoir) : const <String>[];
    final split = parts.length > 1;
    // Each with its own number where written apart ("Posaune 1 und Tuba").
    final eachPart = split ? rdImportNamedGroups(label, plan.instruments, isChoir: plan.isChoir).groups : const <RdImportCategory>[];
    // The file goes to every group it names (Leon, 07.11.2026): offered
    // first, then each one alone.
    final both = eachPart.length > 1 ? RdImportCategory.several(eachPart) : null;
    final partChoices = [
      if (both != null) both,
      ...eachPart.where((c) => c != suggestion),
    ];
    // The KI's guess gets its own chip unless one of the fixed ones is it.
    final aiChip = ai != null &&
        ai != suggestion &&
        ai != RdImportCategory.other &&
        (split ? !partChoices.contains(ai) : ai != newGroup);
    const fromPage = RdImportCategory.fromPage();
    final pageChip = readPages && !(aiChip && ai == fromPage);
    final shown = {
      if (suggestion != null) suggestion,
      if (aiChip) ai,
      ...partChoices,
      if (!split && newName.isNotEmpty) newGroup,
      if (pageChip) fromPage,
      RdImportCategory.other,
    };
    final picked = answer != null && !shown.contains(answer) ? answer : null;
    Future<void> pickOther() async {
      final c = await rdPickImportCategory(
        context,
        plan,
        current: answer,
        title: l10n.redesignImportQuestionTitle(label),
        newGroups: newGroups,
        newGroupName: newGroup.newGroup,
        header: preview?.call(),
      );
      if (c != null) onAnswer(c);
    }

    RdChoiceChip chip(RdImportCategory c, String text, {VoidCallback? onTap}) {
      // The ✦ marks the KI's guess until the person has taken it.
      final mark = c == ai && (answer != c || filled);
      return RdChoiceChip(
        label: text,
        icon: mark ? Icons.auto_awesome : null,
        semanticLabel: mark ? l10n.redesignImportAiMark(text) : null,
        selected: answer == c,
        onTap: onTap ??
            () {
              if (answer != c || filled || proposedOnly) onAnswer(c);
            },
      );
    }

    return RdCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // A tap shows the first page of its files, with the choices below.
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: preview == null ? null : pickOther,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.redesignImportQuestionTitle(label), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: p.text)),
                      const SizedBox(height: 2),
                      Text(l10n.redesignImportQuestionWhere(question.fileCount, question.works.join(', ')), style: RdType.meta(p, size: 13)),
                    ],
                  ),
                ),
                if (preview != null) ...[
                  const SizedBox(width: 8),
                  Tooltip(
                    message: l10n.redesignImportQuestionLook,
                    child: Icon(Icons.image_search_outlined, color: p.link, size: 24, semanticLabel: l10n.redesignImportQuestionLook),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (suggestion != null) chip(suggestion, rdImportCategoryLabel(context, plan, suggestion)),
              if (aiChip)
                chip(ai, ai.newGroup != null ? l10n.redesignImportAnswerNewGroup(rdGroupKindOf(context), ai.newGroup!) : rdImportCategoryLabel(context, plan, ai)),
              for (final c in partChoices)
                chip(c, c.newGroup != null ? l10n.redesignImportAnswerNewGroup(rdGroupKindOf(context), c.newGroup!) : rdImportCategoryLabel(context, plan, c)),
              if (picked != null)
                RdChoiceChip(label: rdImportCategoryLabel(context, plan, picked), selected: true, onTap: pickOther),
              // Taken as it is (Leon, 07.11.2026); another name under
              // "Andere …" › "Neue Gruppe anlegen …".
              if (!split && newName.isNotEmpty) chip(newGroup, l10n.redesignImportAnswerNewGroup(rdGroupKindOf(context), newGroup.newGroup!)),
              // Each file as its first page says ("Solo": Tenor here,
              // Sopran there).
              if (pageChip) chip(fromPage, l10n.redesignImportAnswerFromPage),
              chip(RdImportCategory.other, l10n.redesignImportAnswerNone),
              RdChoiceChip(label: l10n.redesignImportAnswerOther, selected: false, onTap: pickOther),
            ],
          ),
        ],
      ),
    );
  }
}
