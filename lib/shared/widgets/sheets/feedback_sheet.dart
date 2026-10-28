import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/providers/feedback_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/toast_helper.dart';
import '../../../l10n/l10n.dart';
import '../adaptive/adaptive.dart'; // IOS_LOOK

/// Shows the feedback bottom sheet
void showFeedbackSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => const _FeedbackSheet(),
  );
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
    _tabController = TabController(length: 2, vsync: this);
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
          phone: _phoneController.text.trim().isNotEmpty
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.medium.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Title
              Padding(
                padding: const EdgeInsets.all(AppDimensions.paddingM),
                child: Text(
                  context.l10n.settingsHelpFeedback,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              // UX_SETTINGS: Ionic "Per Telegram kontaktieren" + "oder"
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingM),
                child: Card(
                  margin: EdgeInsets.zero,
                  child: ListTile(
                    leading: const Icon(Icons.send_outlined, color: AppColors.primary),
                    title: Text(context.l10n.settingsContactTelegram,
                        style: const TextStyle(color: AppColors.primary)),
                    onTap: () {
                      try {
                        launchUrl(Uri.parse('https://t.me/Eckstaedt'),
                            mode: LaunchMode.externalApplication);
                      } catch (_) {}
                    },
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppDimensions.paddingS),
                child: Text(context.l10n.settingsOr,
                    style: const TextStyle(color: AppColors.medium)),
              ),
              // Tab bar
              TabBar(
                controller: _tabController,
                onTap: (_) => _resetForm(),
                tabs: [
                  Tab(text: context.l10n.settingsHelpQuestion),
                  Tab(text: context.l10n.settingsFeedback),
                ],
              ),
              // Tab content
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildQuestionTab(scrollController),
                    _buildFeedbackTab(scrollController),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildQuestionTab(ScrollController scrollController) {
    return SingleChildScrollView(
      controller: scrollController,
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.coreFlutterFeedbackQuestionIntro,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: AppDimensions.paddingM),
          TextField(
            controller: _questionController,
            maxLines: 5,
            decoration: InputDecoration(
              labelText: context.l10n.settingsYourQuestion,
              hintText: context.l10n.settingsYourQuestionPh,
              border: const OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: AppDimensions.paddingM),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: context.l10n.settingsYourMobileOptional,
              helperText: context.l10n.settingsContactOnly,
              hintText: context.l10n.settingsPhonePh,
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.phone),
            ),
          ),
          const SizedBox(height: AppDimensions.paddingL),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isLoading ? null : _sendQuestion,
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: AppSpinner(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send),
              label: Text(context.l10n.settingsSubmit),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedbackTab(ScrollController scrollController) {
    return SingleChildScrollView(
      controller: scrollController,
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.coreFlutterFeedbackRatingIntro,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: AppDimensions.paddingM),
          // Star rating
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(5, (index) {
                final starValue = index + 1;
                return IconButton(
                  iconSize: 40,
                  onPressed: () => setState(() => _rating = starValue),
                  icon: Icon(
                    starValue <= _rating ? Icons.star : Icons.star_border,
                    color: AppColors.warning,
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: AppDimensions.paddingM),
          TextField(
            controller: _feedbackController,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: context.l10n.settingsYourFeedback,
              hintText: context.l10n.settingsFeedbackPh,
              border: const OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: AppDimensions.paddingM),
          // Anonymous toggle
          SwitchListTile.adaptive(
            title: Text(context.l10n.settingsAnonymous),
            subtitle: Text(
              context.l10n.coreFlutterFeedbackAnonymousHint,
              style: const TextStyle(fontSize: 12),
            ),
            value: _anonymous,
            onChanged: (value) => setState(() => _anonymous = value),
          ),
          // Phone field (only if not anonymous)
          if (!_anonymous) ...[
            const SizedBox(height: AppDimensions.paddingS),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: context.l10n.settingsYourMobileOptional,
                helperText: context.l10n.settingsContactOnly,
                hintText: context.l10n.settingsPhonePh,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.phone),
              ),
            ),
          ],
          const SizedBox(height: AppDimensions.paddingL),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isLoading ? null : _sendFeedback,
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: AppSpinner(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send),
              label: Text(context.l10n.settingsSubmit),
            ),
          ),
        ],
      ),
    );
  }
}
