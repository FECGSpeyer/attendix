import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/providers/feedback_providers.dart';
import '../../../core/theme/redesign/rd_theme.dart';
import '../../../features/attendance/presentation/widgets/event/rd_form_widgets.dart';
import '../redesign/rd_widgets.dart';
import '../../../core/utils/toast_helper.dart';
import '../../../l10n/l10n.dart';
import '../adaptive/adaptive.dart' show IonSwitch;

/// Shows the feedback bottom sheet.
void showFeedbackSheet(BuildContext context) {
  showRdSheet<void>(context, const _FeedbackSheet());
}

class _FeedbackSheet extends ConsumerStatefulWidget {
  const _FeedbackSheet();

  @override
  ConsumerState<_FeedbackSheet> createState() => _FeedbackSheetState();
}

class _FeedbackSheetState extends ConsumerState<_FeedbackSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _questionController = TextEditingController();
  final _feedbackController = TextEditingController();
  final _phoneController = TextEditingController();

  int _rating = 0;
  bool _anonymous = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: 1);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _questionController.dispose();
    _feedbackController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _sendQuestion() async {
    if (_questionController.text.trim().isEmpty) {
      ToastHelper.showWarning(context, context.l10n.coreFlutterFeedbackQuestionRequired);
      return;
    }

    setState(() => _isLoading = true);

    final success = await ref.read(feedbackNotifierProvider.notifier).sendQuestion(
          message: _questionController.text.trim(),
          phone: _phoneController.text.trim().isNotEmpty
              ? _phoneController.text.trim()
              : null,
        );

    if (!mounted) return;

    setState(() => _isLoading = false);

    if (success) {
      ToastHelper.showSuccess(context, context.l10n.settingsQuestionSent);
      Navigator.of(context).pop();
    } else {
      ToastHelper.showError(context, context.l10n.svcSendQuestionFailed);
    }
  }

  Future<void> _sendFeedback() async {
    if (_rating == 0) {
      ToastHelper.showWarning(context, context.l10n.settingsRatingRequired);
      return;
    }

    setState(() => _isLoading = true);

    final success = await ref.read(feedbackNotifierProvider.notifier).sendFeedback(
          message: _feedbackController.text.trim(),
          rating: _rating,
          anonymous: _anonymous,
          phone: !_anonymous && _phoneController.text.trim().isNotEmpty
              ? _phoneController.text.trim()
              : null,
        );

    if (!mounted) return;

    setState(() => _isLoading = false);

    if (success) {
      ToastHelper.showSuccess(context, context.l10n.settingsFeedbackSent);
      Navigator.of(context).pop();
    } else {
      ToastHelper.showError(context, context.l10n.svcSendFeedbackFailed);
    }
  }

  void _resetForm() {
    _questionController.clear();
    _feedbackController.clear();
    _phoneController.clear();
    setState(() {
      _rating = 0;
      _anonymous = false;
    });
  }

  /// REDESIGN (E2): switch Feedback/Frage, stars, text, "Anonym senden",
  /// mobile number (optional) and "Senden"; Telegram as a row below.
  /// Tab 0 = Frage, tab 1 = Feedback (like the old segment).
  Widget _buildBeta(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final feedback = _tabController.index == 1;
    void pick(int index) {
      if (_tabController.index == index) return;
      _resetForm();
      _tabController.index = index;
    }

    Widget field(String label, TextEditingController c, String hint, {int lines = 1, TextInputType? keyboard}) =>
        RdFieldRow(
          label: label,
          child: TextField(
            controller: c,
            minLines: lines,
            maxLines: lines == 1 ? 1 : 8,
            keyboardType: keyboard ?? (lines > 1 ? TextInputType.multiline : null),
            decoration: rdInputDecoration(p, hint),
          ),
        );
    final phone = field(l10n.settingsYourMobileOptional, _phoneController, l10n.settingsPhonePh,
        keyboard: TextInputType.phone);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(header: true, child: Text(l10n.redesignMeFeedbackTitle, style: RdType.section(p))),
            const SizedBox(height: 12),
            Row(
              children: [
                RdChoiceChip(label: l10n.settingsFeedback, selected: feedback, onTap: () => pick(1)),
                const SizedBox(width: 8),
                RdChoiceChip(label: l10n.settingsHelpQuestion, selected: !feedback, onTap: () => pick(0)),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              feedback ? l10n.coreFlutterFeedbackRatingIntro : l10n.coreFlutterFeedbackQuestionIntro,
              style: RdType.meta(p, size: 14),
            ),
            const SizedBox(height: 12),
            if (feedback) ...[
              Semantics(
                label: l10n.settingsYourRating,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var star = 1; star <= 5; star++)
                      IconButton(
                        tooltip: l10n.a11yRating(star),
                        iconSize: 36,
                        onPressed: () => setState(() => _rating = star),
                        icon: Icon(star <= _rating ? Icons.star_rounded : Icons.star_outline_rounded, color: p.late),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              RdGroupedList(
                children: [
                  field(l10n.settingsYourFeedback, _feedbackController, l10n.settingsFeedbackPh, lines: 4),
                  RdListRow(
                    title: l10n.settingsAnonymous,
                    subtitle: l10n.coreFlutterFeedbackAnonymousHint,
                    showChevron: false,
                    trailing: IonSwitch(
                      value: _anonymous,
                      activeTrackColor: p.primary,
                      onChanged: (v) => setState(() => _anonymous = v),
                    ),
                  ),
                  if (!_anonymous) phone,
                ],
              ),
            ] else
              RdGroupedList(
                children: [
                  field(l10n.settingsYourQuestion, _questionController, l10n.settingsYourQuestionPh, lines: 4),
                  phone,
                ],
              ),
            if (!feedback || !_anonymous) ...[
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(l10n.settingsContactOnly, style: RdType.meta(p, size: 12)),
              ),
            ],
            const SizedBox(height: 16),
            RdPrimaryButton(
              label: l10n.redesignMeFeedbackSend,
              loading: _isLoading,
              onPressed: _isLoading ? null : (feedback ? _sendFeedback : _sendQuestion),
            ),
            const SizedBox(height: 20),
            RdGroupedList(
              children: [
                RdListRow(
                  leading: RdRowIcon(Icons.send_outlined, color: p.primary, background: p.soft),
                  title: l10n.settingsContactTelegram,
                  titleColor: p.link,
                  showChevron: false,
                  onTap: () {
                    try {
                      launchUrl(Uri.parse('https://t.me/Eckstaedt'), mode: LaunchMode.externalApplication);
                    } catch (_) {}
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _tabController,
      builder: (context, _) => _buildBeta(context),
    );
  }
}
