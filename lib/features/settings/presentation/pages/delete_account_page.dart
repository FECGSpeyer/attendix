import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/legal_providers.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/design_theme.dart';
import '../../../attendance/presentation/widgets/event/form_widgets.dart';
import '../../../../shared/widgets/components/components.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/repositories/base_repository.dart';
import '../../../../l10n/l10n.dart';
import '../widgets/strong_html_text.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';

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
      await ref.read(accountNotifierProvider.notifier).deleteAccount();
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
              (Icons.groups_outlined, l10n.rdTextDeleteAccountMemberships),
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
    final isDeleting = ref.watch(accountNotifierProvider).isLoading;
    return _buildBeta(context, isDeleting);
  }
}
