import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/providers/feedback_providers.dart';
import '../../../core/router/redesign_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/toast_helper.dart';
import '../../../l10n/l10n.dart';
import '../adaptive/adaptive.dart';
import '../layout/ion_modal_handle.dart';

/// Shows the feedback bottom sheet.
///
/// Ionic: `ion-modal [breakpoints]="[0, 1]" [initialBreakpoint]="1"` – on
/// iOS a full-height sheet (10pt below the safe area) with the grabber over
/// the toolbar and the grouped grey content (IOS_FORMS1).
void showFeedbackSheet(BuildContext context) {
  if (useIosLook(context)) {
    final available =
        MediaQuery.sizeOf(context).height - MediaQuery.paddingOf(context).top;
    final full = available > 100 ? (available - 10) / available : 1.0;
    showModalBottomSheet(
      context: context,
      useRootNavigator: true, // IOS_SHELL2: above the tab bar
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: false,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder: (context) => FractionallySizedBox(
        heightFactor: full,
        child: const IonModalHandleOverlay(child: _FeedbackSheet()),
      ),
    );
    return;
  }
  showModalBottomSheet(
    context: context,
    useRootNavigator: true, // IOS_SHELL2: above the tab bar
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
          // Feedback written in the Beta is marked, so it can be told apart.
          message: RedesignRoutes.active
              ? '[Neues Design] ${_feedbackController.text.trim()}'
              : _feedbackController.text.trim(),
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

  /// IOS_FORMS1: Ionic iOS feedback modal – toolbar title (17pt semibold,
  /// centred, hairline), then ONE scrolling inset list: Telegram item,
  /// "oder", neutral segment and the selected segment's form.
  Widget _buildIos(BuildContext context) {
    final index = _tabController.index;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        IonModalHeader(
          title: Text(context.l10n.settingsHelpFeedback),
          showClose: false,
        ),
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              20,
              16,
              20,
              16 +
                  MediaQuery.paddingOf(context).bottom +
                  MediaQuery.viewInsetsOf(context).bottom,
            ),
            children: [
              _iosGroup([
                ListTile(
                  leading:
                      const Icon(Icons.send_outlined, color: AppColors.primary),
                  title: Text(context.l10n.settingsContactTelegram,
                      style: const TextStyle(color: AppColors.primary)),
                  onTap: () {
                    try {
                      launchUrl(Uri.parse('https://t.me/Eckstaedt'),
                          mode: LaunchMode.externalApplication);
                    } catch (_) {}
                  },
                ),
              ]),
              // ion-text color="medium" > p (centred)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  context.l10n.settingsOr,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.medium),
                ),
              ),
              // ion-segment without colour: neutral iOS segmented control,
              // inside its own (rounded) ion-item-group.
              _iosGroup([
                IonSegment<int>(
                  neutral: true,
                  items: [
                    IonSegmentItem(
                        value: 0,
                        label: Text(context.l10n.settingsHelpQuestion)),
                    IonSegmentItem(
                        value: 1, label: Text(context.l10n.settingsFeedback)),
                  ],
                  value: index,
                  onChanged: (i) {
                    if (i == index) return;
                    _resetForm();
                    _tabController.index = i;
                  },
                ),
              ]),
              ...(index == 0 ? _questionFormIos() : _feedbackFormIos()),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_ios) {
      return AnimatedBuilder(
        animation: _tabController,
        builder: (context, _) => _buildIos(context),
      );
    }
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
                  clipBehavior: Clip.antiAlias,
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
              // Tab bar: Ionic `ion-segment` (md)
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

  bool get _ios => Theme.of(context).platform == TargetPlatform.iOS;

  // UX_SETTINGS (WAVE 8): Ionic feedback modal content on iOS — inset
  // item groups with stacked labels, rating item with end stars, toggle
  // item and a primary "Absenden" item.
  // IOS_R4: only the direct `ion-item-group`s of the inset list (Telegram,
  // segment) get the structured-list corners (28pt); the groups inside
  // `ion-segment-view` (form, "Absenden") are not direct children and stay
  // square blocks of the same width. Groups: --ion-item-background (white /
  // dark #000, settings.page.scss), margin-bottom 16 (global.scss).
  Widget _iosGroup(List<Widget> children, {bool square = false}) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    // IOS27_SWEEP: ion-item lines inside ion-list (step-100).
    final line = dark ? AppColors.iosListLineDark : AppColors.iosListLineLight;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(square ? 0 : 28),
        child: Material(
          color: dark ? Colors.black : Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) Divider(height: 0.5, thickness: 0.5, indent: 16, color: line),
                children[i],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _iosStacked({
    required String label,
    required TextEditingController controller,
    String? hint,
    String? helper,
    int? lines,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 18, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 14)),
          TextField(
            controller: controller,
            minLines: lines,
            maxLines: lines ?? 1,
            keyboardType: keyboardType,
            textCapitalization: TextCapitalization.sentences,
            style: const TextStyle(fontSize: 16),
            decoration: InputDecoration(
              hintText: hint,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
              isDense: true,
              contentPadding: const EdgeInsets.only(top: 8, bottom: 4),
            ),
          ),
          if (helper != null)
            Text(helper, style: const TextStyle(fontSize: 12, color: Color(0xFF737373))),
        ],
      ),
    );
  }

  Widget _iosSubmit(VoidCallback onTap) => ListTile(
        title: Text(
          context.l10n.settingsSubmit,
          style: const TextStyle(color: AppColors.primary),
        ),
        trailing: _isLoading
            ? const SizedBox(width: 20, height: 20, child: AppSpinner(strokeWidth: 2))
            : null,
        onTap: _isLoading ? null : onTap,
      );

  List<Widget> _questionFormIos() {
    return [
        _iosGroup([
          _iosStacked(
            label: context.l10n.settingsYourQuestion,
            controller: _questionController,
            hint: context.l10n.settingsYourQuestionPh,
            lines: 6,
          ),
          _iosStacked(
            label: context.l10n.settingsYourMobileOptional,
            controller: _phoneController,
            hint: context.l10n.settingsPhonePh,
            helper: context.l10n.settingsContactOnly,
            keyboardType: TextInputType.phone,
          ),
        ], square: true),
        _iosGroup([_iosSubmit(_sendQuestion)], square: true),
    ];
  }

  List<Widget> _feedbackFormIos() {
    return [
        _iosGroup([
          ListTile(
            title: Text(context.l10n.settingsYourRating),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var star = 1; star <= 5; star++)
                  Semantics(
                    button: true,
                    selected: star <= _rating,
                    label: context.l10n.a11yRating(star),
                    excludeSemantics: true,
                    onTap: () => setState(() => _rating = star),
                    child: GestureDetector(
                      onTap: () => setState(() => _rating = star),
                      child: Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: Icon(
                          Icons.star,
                          size: 22,
                          color: star <= _rating ? AppColors.warning : AppColors.medium,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          _iosStacked(
            label: context.l10n.settingsYourFeedback,
            controller: _feedbackController,
            hint: context.l10n.settingsFeedbackPh,
            lines: 6,
          ),
          SwitchListTile.adaptive(
            title: Text(context.l10n.settingsAnonymous),
            value: _anonymous,
            onChanged: (value) => setState(() => _anonymous = value),
          ),
          if (!_anonymous)
            _iosStacked(
              label: context.l10n.settingsYourMobileOptional,
              controller: _phoneController,
              hint: context.l10n.settingsPhonePh,
              helper: context.l10n.settingsContactOnly,
              keyboardType: TextInputType.phone,
            ),
        ], square: true),
        _iosGroup([_iosSubmit(_sendFeedback)], square: true),
    ];
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
                    semanticLabel: context.l10n.a11yRating(starValue),
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
