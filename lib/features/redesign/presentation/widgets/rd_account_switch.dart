import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/supabase_config.dart';
import '../../../../core/providers/account_switch_providers.dart';
import '../../../../core/providers/push_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/services/account_switch/account_switch_service.dart';
import '../../../../core/theme/redesign/rd_theme.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/layout/route_leave_guard.dart';
import '../../../auth/data/auth_flow_service.dart';
import 'rd_widgets.dart';

/// ACCOUNT_SWITCH (Beta): "Konto wechseln" sheet on the Ich page and the
/// saved accounts on the login page.
///
/// A switch keeps the old account's session (no sign-out), removes its push
/// token on this device, opens the new account's session and then lets the
/// group selection open the new account's last group – the same path as
/// after a login.

/// Result of [rdSwitchAccount] / [rdAddAccount].
enum RdAccountChange { switched, needsLogin, failed, cancelled }

/// Switches to the saved [account]. Shows a toast on failure; for an
/// account whose saved session is no longer valid it returns
/// [RdAccountChange.needsLogin] (caller opens the login sheet).
Future<RdAccountChange> rdSwitchAccount(BuildContext context, SavedAccount account) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final router = GoRouter.of(context);
  final l10n = context.l10n;
  final service = container.read(accountSwitchServiceProvider);
  final hadSession = container.read(supabaseAuthProvider).currentSession != null;

  // Like a group switch: a page with unsaved input is asked first.
  final guards = container.read(routeLeaveGuardRegistryProvider);
  if (hadSession && guards.hasGuards && !await guards.canLeave()) {
    return RdAccountChange.cancelled;
  }
  try {
    await service.switchTo(
      account.userId,
      beforeActivate: hadSession ? () => removePushTokenBeforeAccountChange(container.read) : null,
    );
  } on SavedSessionExpired {
    return RdAccountChange.needsLogin;
  } on AccountSwitchUnavailable {
    if (context.mounted) ToastHelper.showError(context, l10n.redesignAccountsOffline);
    return RdAccountChange.failed;
  } catch (_) {
    if (context.mounted) ToastHelper.showError(context, l10n.redesignAccountsFailed);
    return RdAccountChange.failed;
  }
  await _openAfterAccountChange(container, router);
  if (context.mounted) {
    ToastHelper.showSuccess(context, l10n.redesignAccountsSwitched(account.title));
  }
  return RdAccountChange.switched;
}

/// Signs in another account with e-mail and password while keeping the
/// current one saved. Throws [LoginFailure] for wrong credentials etc.
Future<void> rdAddAccount(
  ProviderContainer container,
  GoRouter router, {
  required String email,
  required String password,
}) async {
  final service = container.read(accountSwitchServiceProvider);
  final auth = container.read(supabaseAuthProvider);
  final current = auth.currentSession;
  if (current != null) {
    // Its newest token, so it can be opened again later.
    await service.remember(current);
    await removePushTokenBeforeAccountChange(container.read);
  }
  try {
    await container.read(authFlowServiceProvider).signInWithPassword(email, password);
  } catch (_) {
    // Still the old account: register its push token again.
    if (current != null && auth.currentSession?.user.id == current.user.id) {
      unawaited(container.read(pushServiceProvider).promptAndEnable());
    }
    rethrow;
  }
  final next = auth.currentSession;
  if (next != null) await service.remember(next);
  if (current != null && next?.user.id != current.user.id) {
    await _openAfterAccountChange(container, router);
  } else if (current == null) {
    router.go('/tenants');
  }
}

/// Same path as after a login: no group selected, the group selection opens
/// the account's last group (or shows the list). Push registers the new
/// account's token (TOKEN_REFRESHED does not trigger it like SIGNED_IN).
Future<void> _openAfterAccountChange(ProviderContainer container, GoRouter router) async {
  await container.read(currentTenantProvider.notifier).setTenantLocal(null);
  router.go('/tenants');
  if (isNativePushPlatform) {
    unawaited(container.read(pushServiceProvider).promptAndEnable());
  }
}

/// "Konto wechseln" sheet.
Future<void> showRdAccountSwitchSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: context.rd.bg,
    builder: (_) => const _RdAccountSwitchSheet(),
  );
}

class _RdAccountSwitchSheet extends ConsumerStatefulWidget {
  const _RdAccountSwitchSheet();

  @override
  ConsumerState<_RdAccountSwitchSheet> createState() => _RdAccountSwitchSheetState();
}

class _RdAccountSwitchSheetState extends ConsumerState<_RdAccountSwitchSheet> {
  String? _switchingTo;

  Future<void> _switch(SavedAccount account, String? currentId) async {
    if (_switchingTo != null) return;
    final navigator = Navigator.of(context);
    final sheet = ModalRoute.of(context);
    if (account.userId == currentId) {
      navigator.pop();
      return;
    }
    if (!account.canResume) {
      await _login(account.email);
      return;
    }
    setState(() => _switchingTo = account.userId);
    final result = await rdSwitchAccount(context, account);
    if (!mounted) return;
    switch (result) {
      case RdAccountChange.switched:
        if (sheet != null && sheet.isCurrent) navigator.pop();
      case RdAccountChange.needsLogin:
        setState(() => _switchingTo = null);
        await _login(account.email);
      case RdAccountChange.failed || RdAccountChange.cancelled:
        setState(() => _switchingTo = null);
    }
  }

  Future<void> _login(String? email) async {
    final navigator = Navigator.of(context);
    final sheet = ModalRoute.of(context);
    final done = await showRdAccountLoginSheet(context, email: email);
    if (done == true && sheet != null && sheet.isCurrent) navigator.pop();
  }

  Future<void> _remove(SavedAccount account) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.redesignAccountsRemoveTitle),
        content: Text(l10n.redesignAccountsRemoveBody(account.email)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.redesignCommonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: ctx.rd.absent),
            child: Text(l10n.redesignAccountsRemoveConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(accountSwitchServiceProvider).remove(account.userId);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final accounts = ref.watch(savedAccountsProvider).valueOrNull ?? const <SavedAccount>[];
    final currentId = ref.watch(currentAuthUserIdProvider);
    final busy = _switchingTo != null;

    return PopScope(
      canPop: !busy,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(l10n.redesignAccountsTitle, style: RdType.section(p)),
                    ),
                  ),
                  TextButton(
                    onPressed: busy ? null : () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(foregroundColor: p.link),
                    child: Text(
                      l10n.redesignCommonDone,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Flexible(
                child: SingleChildScrollView(
                  child: RdGroupedList(
                    children: [
                      for (final a in accounts)
                        _AccountRow(
                          account: a,
                          isCurrent: a.userId == currentId,
                          busy: _switchingTo == a.userId,
                          onTap: busy ? null : () => _switch(a, currentId),
                          onRemove: busy || a.userId == currentId ? null : () => _remove(a),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              RdOutlineButton(
                label: l10n.redesignAccountsAdd,
                icon: Icons.person_add_alt_1_outlined,
                onPressed: busy ? null : () => _login(null),
              ),
              const SizedBox(height: 12),
              Text(l10n.redesignAccountsFooter, style: RdType.meta(p, size: 13)),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({
    required this.account,
    required this.isCurrent,
    required this.busy,
    required this.onTap,
    required this.onRemove,
  });

  final SavedAccount account;
  final bool isCurrent;
  final bool busy;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final subtitle = isCurrent
        ? [l10n.redesignAccountsCurrent, if ((account.label ?? '').isNotEmpty) account.label!].join(' · ')
        : !account.canResume
            ? l10n.redesignAccountsNeedsLogin
            : [
                if (account.title != account.email) account.email,
                if ((account.label ?? '').isNotEmpty) account.label!,
              ].join(' · ');
    return RdListRow(
      leading: RdInitials(rdInitialsOf(account.name ?? account.email), size: 40),
      title: account.title,
      subtitle: subtitle.isEmpty ? null : subtitle,
      selected: isCurrent,
      showChevron: false,
      trailing: busy
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : isCurrent
              ? Icon(Icons.check_circle, color: p.primary)
              : onRemove == null
                  ? null
                  : PopupMenuButton<int>(
                      tooltip: l10n.redesignAccountsMore(account.title),
                      icon: Icon(Icons.more_horiz, color: p.text2),
                      onSelected: (_) => onRemove!(),
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: 0,
                          child: Text(l10n.redesignAccountsRemove, style: TextStyle(color: p.absent)),
                        ),
                      ],
                    ),
      onTap: onTap,
    );
  }
}

/// E-mail/password sheet to add an account (or sign one in again whose
/// saved session expired). Returns true after a successful sign-in.
Future<bool?> showRdAccountLoginSheet(BuildContext context, {String? email}) {
  return showModalBottomSheet<bool>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: context.rd.bg,
    builder: (_) => _RdAccountLoginSheet(email: email),
  );
}

class _RdAccountLoginSheet extends ConsumerStatefulWidget {
  const _RdAccountLoginSheet({this.email});

  final String? email;

  @override
  ConsumerState<_RdAccountLoginSheet> createState() => _RdAccountLoginSheetState();
}

class _RdAccountLoginSheetState extends ConsumerState<_RdAccountLoginSheet> {
  late final _email = TextEditingController(text: widget.email ?? '');
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  bool get _canSubmit => isValidEmail(_email.text) && _password.text.isNotEmpty && !_busy;

  Future<void> _submit() async {
    if (!_canSubmit) return;
    final l10n = context.l10n;
    final email = _email.text.trim();
    final container = ProviderScope.containerOf(context, listen: false);
    final router = GoRouter.of(context);
    final navigator = Navigator.of(context);
    final sheet = ModalRoute.of(context);
    final current = container.read(supabaseAuthProvider).currentUser;
    if (current != null && (current.email ?? '').toLowerCase() == email.toLowerCase()) {
      setState(() => _error = l10n.redesignAccountsAlreadyActive);
      return;
    }
    final guards = container.read(routeLeaveGuardRegistryProvider);
    if (current != null && guards.hasGuards && !await guards.canLeave()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await rdAddAccount(container, router, email: email, password: _password.text);
      if (sheet != null && sheet.isCurrent) navigator.pop(true);
    } on LoginFailure catch (f) {
      if (mounted) setState(() => _error = f.message ?? l10n.redesignAccountsFailed);
    } catch (_) {
      if (mounted) setState(() => _error = l10n.redesignAccountsFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  InputDecoration _decoration(BuildContext context, String label) {
    final p = context.rd;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(p.buttonRadius),
      borderSide: BorderSide.none,
    );
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: p.surface,
      border: border,
      enabledBorder: border,
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final relogin = widget.email != null;
    return PopScope(
      canPop: !_busy,
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: AutofillGroup(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      relogin ? l10n.redesignAccountsLoginAgainTitle : l10n.redesignAccountsAddTitle,
                      style: RdType.section(p),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    relogin
                        ? l10n.redesignAccountsLoginAgainHint(widget.email!)
                        : l10n.redesignAccountsAddHint,
                    style: RdType.meta(p),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _email,
                    enabled: !_busy,
                    autofocus: !relogin,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    autofillHints: const [AutofillHints.username, AutofillHints.email],
                    textInputAction: TextInputAction.next,
                    onChanged: (_) => setState(() => _error = null),
                    decoration: _decoration(context, l10n.redesignAccountsEmail),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _password,
                    enabled: !_busy,
                    autofocus: relogin,
                    obscureText: true,
                    autofillHints: const [AutofillHints.password],
                    textInputAction: TextInputAction.done,
                    onChanged: (_) => setState(() => _error = null),
                    onSubmitted: (_) => _submit(),
                    decoration: _decoration(context, l10n.redesignAccountsPassword),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    Text(_error!, style: TextStyle(color: p.absent, fontSize: 14)),
                  ],
                  const SizedBox(height: 16),
                  RdPrimaryButton(
                    label: l10n.redesignAccountsSignIn,
                    icon: _busy ? null : Icons.login,
                    onPressed: _canSubmit ? _submit : null,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Login page (Beta only): the saved accounts above the form, tap to
/// continue without password. Accounts whose session expired fill in the
/// e-mail field instead ([onPickEmail]).
class RdSavedAccountsOnLogin extends ConsumerStatefulWidget {
  const RdSavedAccountsOnLogin({super.key, required this.onPickEmail});

  final ValueChanged<String> onPickEmail;

  @override
  ConsumerState<RdSavedAccountsOnLogin> createState() => _RdSavedAccountsOnLoginState();
}

class _RdSavedAccountsOnLoginState extends ConsumerState<RdSavedAccountsOnLogin> {
  String? _switchingTo;

  Future<void> _open(SavedAccount account) async {
    if (_switchingTo != null) return;
    if (!account.canResume) {
      widget.onPickEmail(account.email);
      return;
    }
    setState(() => _switchingTo = account.userId);
    final result = await rdSwitchAccount(context, account);
    if (!mounted) return;
    setState(() => _switchingTo = null);
    if (result == RdAccountChange.needsLogin) widget.onPickEmail(account.email);
  }

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(savedAccountsProvider).valueOrNull ?? const <SavedAccount>[];
    if (accounts.isEmpty) return const SizedBox.shrink();
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.color ?? theme.colorScheme.onSurfaceVariant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.redesignAccountsLoginSaved, style: theme.textTheme.titleSmall),
        const SizedBox(height: 4),
        for (final a in accounts)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(child: Text(rdInitialsOf(a.name ?? a.email))),
            title: Text(a.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(
              a.canResume ? (a.title != a.email ? a.email : (a.label ?? '')) : l10n.redesignAccountsNeedsLogin,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: _switchingTo == a.userId
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.chevron_right),
            onTap: _switchingTo == null ? () => _open(a) : null,
          ),
        const SizedBox(height: 8),
        Text(
          l10n.redesignAccountsLoginOr,
          textAlign: TextAlign.center,
          style: TextStyle(color: muted, fontSize: 13),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}
