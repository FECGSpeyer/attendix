import 'dart:math';

import 'package:flutter/material.dart';
import '../../../../shared/widgets/layout/ion_form_items.dart';
import '../../../../shared/widgets/layout/ionic_ios.dart' show ionPlainContentBackground;
import 'package:attendix/core/theme/app_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/legal_providers.dart';
import '../../../../core/providers/redesign_providers.dart';
import '../../../../core/router/redesign_routes.dart';
import '../../../../core/theme/redesign/rd_theme.dart';
import '../../../redesign/presentation/widgets/event/rd_form_widgets.dart';
import '../../../redesign/presentation/widgets/rd_widgets.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/repositories/base_repository.dart';
import '../../../../l10n/l10n.dart';
import '../widgets/strong_html_text.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';
import 'package:attendix/shared/widgets/layout/ios_tab_bar.dart';

/// Characters for the verification code — avoids visually ambiguous chars
/// (0/O, 1/I/L), identical to Ionic.
const String deleteAccountCodeChars = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

/// Generates a random 6-char verification code (Ionic `generateCode`).
String generateDeleteAccountCode([Random? random]) {
  final rng = random ?? Random.secure();
  return List.generate(
    6,
    (_) => deleteAccountCodeChars[rng.nextInt(deleteAccountCodeChars.length)],
  ).join();
}

/// Whether the typed text matches the code (trimmed, case-insensitive).
bool isDeleteAccountCodeValid(String input, String code) =>
    input.trim().toUpperCase() == code;

/// DSGVO account deletion (`/settings/delete-account`).
///
/// Port of Ionic `settings/delete-account/delete-account.page`: the user must
/// re-type a random code, confirm a dialog, then the `delete-account` edge
/// function removes the account and all personal data.
class DeleteAccountPage extends ConsumerStatefulWidget {
  const DeleteAccountPage({super.key});

  @override
  ConsumerState<DeleteAccountPage> createState() => _DeleteAccountPageState();
}

class _DeleteAccountPageState extends ConsumerState<DeleteAccountPage> {
  // Regenerated every time the page opens — prevents muscle-memory confirms.
  final String _verificationCode = generateDeleteAccountCode();
  final _confirmController = TextEditingController();

  @override
  void dispose() {
    _confirmController.dispose();
    super.dispose();
  }

  bool get _canDelete =>
      isDeleteAccountCodeValid(_confirmController.text, _verificationCode);

  Future<void> _deleteAccount() async {
    if (!_canDelete) return;

    final confirmed = await showAppDialog<bool>(
      context: context,
      builder: (context) => AppAlertDialog(
        title: Text(context.l10n.deleteAccountConfirm),
        content: Text(context.l10n.deleteAccountConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: Text(context.l10n.deleteAccountDeleteFinal),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      final notifier = ref.read(accountNotifierProvider.notifier);
      // EIB-19 / EIB-22: Ionic `ion-loading` "Konto wird gelöscht…".
      if (ref.read(redesignEnabledProvider)) {
        await notifier.deleteAccount();
      } else {
        await withIonLoading(context, notifier.deleteAccount,
            message: context.l10n.deleteAccountDeleting);
      }
      if (!mounted) return;
      ToastHelper.showSuccess(context, context.l10n.deleteAccountDeleted);
      context.go('/login');
    } catch (e) {
      if (!mounted) return;
      final message = e is RepositoryException ? e.message : e.toString();
      ToastHelper.showError(
        context,
        context.l10n.deleteAccountFailed(message.isEmpty ? context.l10n.commonUnknown : message),
      );
    }
  }

  /// REDESIGN (E4): subpage of Ich – what is deleted as a list, the
  /// warning as a card, code input, red button. Same code and flow.
  Widget _buildBeta(BuildContext context, bool isDeleting) {
    final p = context.rd;
    final l10n = context.l10n;
    return RdPage(
      children: [
        RdBackLink(
          label: l10n.redesignTabMe,
          onTap: () => context.canPop() ? context.pop() : context.go(RedesignRoutes.me),
        ),
        Semantics(header: true, child: Text(l10n.deleteAccountTitle, style: RdType.largeTitle(p))),
        const SizedBox(height: 8),
        StrongHtmlText(l10n.deleteAccountIntro, style: RdType.meta(p, size: 15)),
        const SizedBox(height: 12),
        RdGroupedList(
          children: [
            for (final (icon, item) in [
              (Icons.person_outline, l10n.deleteAccountProfile),
              (Icons.groups_outlined, l10n.deleteAccountMemberships),
              (Icons.event_available_outlined, l10n.deleteAccountAttendance),
              (Icons.lock_outline, l10n.deleteAccountAccess),
            ])
              RdListRow(
                leading: RdRowIcon(icon, color: p.absent, background: p.absentSoft),
                title: item,
                showChevron: false,
              ),
          ],
        ),
        const SizedBox(height: 16),
        RdCard(
          color: p.absentSoft,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.warning_amber_rounded, color: p.absent),
              const SizedBox(width: 10),
              Expanded(
                child: StrongHtmlText(
                  l10n.deleteAccountCannotUndo,
                  style: TextStyle(fontSize: 15, color: p.text),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(l10n.deleteAccountEnterCode, style: RdType.meta(p, size: 14)),
        const SizedBox(height: 8),
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(color: p.track, borderRadius: BorderRadius.circular(p.buttonRadius)),
            child: SelectableText(
              _verificationCode,
              style: TextStyle(
                fontFamily: 'Courier New',
                fontFamilyFallback: const ['Courier', 'monospace'],
                fontSize: 26,
                fontWeight: FontWeight.w700,
                letterSpacing: 6,
                color: p.text,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        RdGroupedList(
          children: [
            RdFieldRow(
              label: l10n.deleteAccountCode,
              child: TextField(
                controller: _confirmController,
                autocorrect: false,
                enableSuggestions: false,
                textCapitalization: TextCapitalization.characters,
                decoration: rdInputDecoration(p, l10n.deleteAccountCodePlaceholder),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        RdPrimaryButton(
          label: isDeleting ? l10n.deleteAccountDeleting : l10n.deleteAccountDeleteForever,
          icon: Icons.delete_outline,
          color: p.absent,
          loading: isDeleting,
          onPressed: !_canDelete || isDeleting ? null : _deleteAccount,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDeleting = ref.watch(accountNotifierProvider).isLoading;
    if (ref.watch(redesignEnabledProvider)) return _buildBeta(context, isDeleting);
    const white = TextStyle(color: Colors.white);

    // UX_SETTINGS (WAVE 8): delete-account.page.html — arrow-back, danger
    // tint warning box (radius 12), centred code chip, stacked input item.
    return Scaffold(
      // EIB-22: `<ion-content class="ion-padding">` without colour.
      backgroundColor: ionPlainContentBackground(context),
      appBar: AppBar(
        // EIB-12: Ionic custom `arrow-back` ion-button.
        leading: IonArrowBackButton(onPressed: () => Navigator.of(context).maybePop()),
        leadingWidth: IonArrowBackButton.leadingWidth(context),
        title: Text(context.l10n.deleteAccountTitle),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(AppDimensions.paddingM, AppDimensions.paddingM, AppDimensions.paddingM, scrollEndPadding(context, base: AppDimensions.paddingM)),
        children: [
          Container(
            padding: const EdgeInsets.all(AppDimensions.paddingM),
            decoration: BoxDecoration(
              // --ion-color-danger-tint
              color: Color.lerp(AppColors.danger, Colors.white, 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: DefaultTextStyle.merge(
              style: white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(AppIcons.warningAmberRounded,
                      color: Colors.white, size: 32),
                  const SizedBox(height: 8),
                  Text(
                    context.l10n.deleteAccountWarning,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  StrongHtmlText(context.l10n.deleteAccountIntro),
                  const SizedBox(height: 8),
                  for (final item in [
                    context.l10n.deleteAccountProfile,
                    context.l10n.deleteAccountAttendance,
                    context.l10n.deleteAccountMemberships,
                    context.l10n.deleteAccountAccess,
                  ])
                    Padding(
                      padding: const EdgeInsets.only(left: 8, top: 4, bottom: 4),
                      child: Text('•  $item'),
                    ),
                  const SizedBox(height: 8),
                  StrongHtmlText(context.l10n.deleteAccountCannotUndo),
                ],
              ),
            ),
          ),
          // .warning-box margin-bottom 24 / .verification-box margin-top 24
          // (collapsing margins).
          const SizedBox(height: 24),
          Text(
            context.l10n.deleteAccountEnterCode,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.medium),
          ),
          const SizedBox(height: 12),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: theme.brightness == Brightness.dark
                    ? const Color(0xFF222428)
                    : const Color(0xFFF4F5F8),
                borderRadius: BorderRadius.circular(10),
              ),
              child: SelectableText(
                _verificationCode,
                style: TextStyle(
                  fontFamily: 'Courier New',
                  fontFamilyFallback: const ['Courier', 'monospace'],
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 6,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // EIB-15: `ion-item` + stacked label + `ion-input`.
          IonStackedInputItem(
            label: context.l10n.deleteAccountCode,
            placeholder: context.l10n.deleteAccountCodePlaceholder,
            controller: _confirmController,
            textCapitalization: TextCapitalization.characters,
            onChanged: (_) => setState(() {}),
          ),
          // `ion-button expand="block" color="danger" class="ion-margin-top"`
          // with the trash icon; the progress is the loading overlay.
          const SizedBox(height: AppDimensions.paddingM),
          IonButton(
            expand: true,
            color: AppColors.danger,
            icon: AppIcons.deleteOutline,
            label: context.l10n.deleteAccountDeleteForever,
            onPressed: !_canDelete || isDeleting ? null : _deleteAccount,
          ),
        ],
      ),
    );
  }
}
