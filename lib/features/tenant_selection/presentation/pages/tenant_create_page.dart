import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/utils/device_timezone.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/repositories/tenant_create_repository.dart';
import '../../../../l10n/l10n.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../core/config/supabase_config.dart';
import '../../../../core/providers/legal_providers.dart';
import '../../../../core/providers/push_providers.dart';
import '../../../../data/repositories/base_repository.dart';
import '../../../auth/presentation/widgets/ion_form_list.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart'; // IOS_LOOK

/// AUTH: Ionic "Neue Instanz anlegen" (register.page) – 3 steps:
/// 1. Art der Gruppe, 2. Name + Kürzel, 3. Hauptgruppe, then summary.
class TenantCreatePage extends ConsumerStatefulWidget {
  const TenantCreatePage({super.key, this.canDismiss = true});

  /// False when the user has no instance yet (Ionic full-page register).
  final bool canDismiss;

  @override
  ConsumerState<TenantCreatePage> createState() => _TenantCreatePageState();
}

/// Type-specific texts of the wizard (Ionic register.placeholder.* / help*).
class TenantTypeTexts {
  const TenantTypeTexts({
    required this.option,
    required this.label,
    required this.help,
    required this.namePlaceholder,
    required this.shortPlaceholder,
    required this.mainGroupPlaceholder,
    required this.icon,
  });

  final String option;
  final String label;
  final String help;
  final String namePlaceholder;
  final String shortPlaceholder;
  final String mainGroupPlaceholder;
  final IconData icon;

  /// Ionic register.type*/help*/placeholder.* texts per tenant type.
  static Map<String, TenantTypeTexts> byType(AppLocalizations l10n) => {
        'general': TenantTypeTexts(
          option: l10n.registerTypeGeneral,
          label: l10n.registerTypeGeneral,
          help: l10n.registerHelpGeneral,
          namePlaceholder: l10n.registerPlaceholderGeneralName,
          shortPlaceholder: l10n.registerPlaceholderGeneralShort,
          mainGroupPlaceholder: l10n.registerPlaceholderGeneralMain,
          icon: Icons.groups_outlined,
        ),
        'choir': TenantTypeTexts(
          option: l10n.registerTypeChoirOption,
          label: l10n.registerTypeChoir,
          help: l10n.registerHelpChoir,
          namePlaceholder: l10n.registerPlaceholderChoirName,
          shortPlaceholder: l10n.registerPlaceholderChoirShort,
          mainGroupPlaceholder: l10n.registerPlaceholderChoirMain,
          icon: Icons.mic_none,
        ),
        'orchestra': TenantTypeTexts(
          option: l10n.registerTypeOrchestraOption,
          label: l10n.registerTypeOrchestra,
          help: l10n.registerHelpOrchestra,
          namePlaceholder: l10n.registerPlaceholderOrchestraName,
          shortPlaceholder: l10n.registerPlaceholderOrchestraShort,
          mainGroupPlaceholder: l10n.registerPlaceholderOrchestraMain,
          icon: Icons.music_note_outlined,
        ),
      };

  static TenantTypeTexts of(String type, AppLocalizations l10n) {
    final all = byType(l10n);
    return all[type] ?? all['general']!;
  }
}

class _TenantCreatePageState extends ConsumerState<TenantCreatePage> {
  final _shortNameController = TextEditingController();
  final _longNameController = TextEditingController();
  final _mainGroupNameController = TextEditingController();
  String _selectedType = 'general';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _shortNameController.addListener(_onFieldChanged);
    _longNameController.addListener(_onFieldChanged);
    _mainGroupNameController.addListener(_onFieldChanged);
  }

  void _onFieldChanged() => setState(() {});

  @override
  void dispose() {
    _shortNameController.removeListener(_onFieldChanged);
    _longNameController.removeListener(_onFieldChanged);
    _mainGroupNameController.removeListener(_onFieldChanged);
    _shortNameController.dispose();
    _longNameController.dispose();
    _mainGroupNameController.dispose();
    super.dispose();
  }

  String get _longName => _longNameController.text.trim();
  String get _shortName => _shortNameController.text.trim();
  String get _mainGroupName => _mainGroupNameController.text.trim();
  bool get _isComplete =>
      _longName.isNotEmpty && _shortName.isNotEmpty && _mainGroupName.isNotEmpty;

  /// Ionic register.page `canDismiss = Boolean(db.tenantUser())`: a user
  /// without any instance cannot leave the page, only log out or delete
  /// the account via the account menu.
  bool get _canDismiss => widget.canDismiss;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final texts = TenantTypeTexts.of(_selectedType, l10n);
    final theme = Theme.of(context);
    final ios = ionIsIos(context);
    final margin = ionInsetMargin(context);
    // register.page.scss: ion-list-header ion-label 1rem / 600
    const headerStyle = TextStyle(fontSize: 16, fontWeight: FontWeight.w600);
    final inputStyle = ionItemInputStyle(context);

    return PopScope(
      canPop: _canDismiss,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.registerTitle),
          automaticallyImplyLeading: false,
          actions: [
            if (_canDismiss)
              IconButton(
                icon: const Icon(Icons.close),
                tooltip: l10n.commonClose,
                onPressed: _isLoading
                    ? null
                    : () => context.canPop()
                        ? context.pop()
                        : context.go('/tenants'),
              )
            else
              // Ionic register-account-menu popover: Abmelden / Konto löschen
              PopupMenuButton<String>(
                key: const ValueKey('register-account-menu'),
                icon: Icon(ios ? Icons.more_horiz : Icons.more_vert),
                position: PopupMenuPosition.under,
                onSelected: (value) =>
                    value == 'logout' ? _logout() : _confirmDeleteAccount(),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'logout',
                    child: Row(children: [
                      const Icon(Icons.logout),
                      const SizedBox(width: 12),
                      Text(l10n.registerLogout),
                    ]),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(children: [
                      const Icon(Icons.delete_outline, color: AppColors.danger),
                      const SizedBox(width: 12),
                      Text(l10n.registerDeleteAccount,
                          style: const TextStyle(color: AppColors.danger)),
                    ]),
                  ),
                ],
              ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.only(top: 8),
          children: [
            // Intro card (ion-card: rocket icon above the centred title)
            _IonCard(
              child: Column(
                children: [
                  const Icon(Icons.rocket_launch_outlined,
                      size: 48, color: AppColors.primary),
                  const SizedBox(height: 8),
                  Text(
                    l10n.registerWelcome,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20.8,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Ionic register.introHtml (inline <strong>).
                  Text.rich(
                    TextSpan(
                      children: _inlineHtml(l10n.registerIntroHtml),
                      style: const TextStyle(
                          fontSize: 14, height: 1.5, color: AppColors.medium),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            // Join hint (.hint-card: 4px primary border on the left)
            _IonCard(
              padding: EdgeInsets.zero,
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(width: 4, color: AppColors.primary),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.registerJoinHeading,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              l10n.registerJoinText,
                              style: const TextStyle(
                                fontSize: 14.4,
                                height: 1.4,
                                color: Color(0xFF808289),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Step 1: Art der Gruppe (ion-select, action-sheet interface)
            IonListHeader(l10n.registerStep1,
                leading: const _StepBadge('1'), style: headerStyle),
            IonInsetGroup(
              margin: EdgeInsets.symmetric(horizontal: margin),
              children: [
                IonItem(
                  key: const ValueKey('tenant-type-select'),
                  onTap: _isLoading ? null : () => _chooseType(context),
                  title: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.registerGroupType,
                          style: TextStyle(fontSize: ios ? 14 : 12)),
                      const SizedBox(height: 4),
                      Text(texts.option, style: inputStyle),
                    ],
                  ),
                  end: const Icon(Icons.arrow_drop_down,
                      color: AppColors.medium),
                ),
              ],
            ),
            // .helper-text below the group
            Padding(
              padding: EdgeInsets.fromLTRB(margin + 16, 8, margin + 16, 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 1),
                    child: Icon(Icons.check_circle,
                        color: AppColors.success, size: 17.6),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      texts.help,
                      style: const TextStyle(
                          fontSize: 13.6, color: AppColors.medium),
                    ),
                  ),
                ],
              ),
            ),

            // Step 2: Name + Kürzel
            IonListHeader(l10n.registerStep2,
                leading: const _StepBadge('2'), style: headerStyle),
            IonInsetGroup(
              margin: EdgeInsets.fromLTRB(margin, 0, margin, 16),
              children: [
                IonInputItem(
                  child: TextField(
                    controller: _longNameController,
                    maxLength: 50,
                    style: inputStyle,
                    textCapitalization: TextCapitalization.words,
                    decoration: ionItemInputDecoration(
                      context,
                      l10n.registerFullName,
                      hint: texts.namePlaceholder,
                      helper: l10n.registerFullNameHelper,
                    ),
                  ),
                ),
                IonInputItem(
                  child: TextField(
                    controller: _shortNameController,
                    style: inputStyle,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: ionItemInputDecoration(
                      context,
                      l10n.registerShortName,
                      hint: texts.shortPlaceholder,
                      helper: l10n.registerShortNameHelper,
                    ),
                  ),
                ),
              ],
            ),

            // Step 3: Hauptgruppe (+ help popover)
            IonListHeader(
              l10n.registerStep3,
              leading: const _StepBadge('3'),
              style: headerStyle,
              trailing: IconButton(
                tooltip: l10n.registerFlutterMainGroupInfo,
                visualDensity: VisualDensity.compact,
                color: AppColors.primary,
                icon: const Icon(Icons.help_outline),
                onPressed: _showMainGroupInfo,
              ),
            ),
            IonInsetGroup(
              margin: EdgeInsets.fromLTRB(margin, 0, margin, 16),
              children: [
                IonInputItem(
                  child: TextField(
                    controller: _mainGroupNameController,
                    style: inputStyle,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: ionItemInputDecoration(
                      context,
                      l10n.registerMainGroupName,
                      hint: texts.mainGroupPlaceholder,
                      helper: l10n.registerMainGroupHelper,
                    ),
                  ),
                ),
              ],
            ),

            // Summary
            IonListHeader(l10n.registerSummary,
                leading: const _StepBadge('✓'), style: headerStyle),
            IonInsetGroup(
              margin: EdgeInsets.symmetric(horizontal: margin),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: DefaultTextStyle.merge(
                    style: const TextStyle(fontSize: 14),
                    child: _isComplete
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text.rich(TextSpan(children: [
                                TextSpan(
                                  text: _longName,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                                TextSpan(text: ' ($_shortName)'),
                              ])),
                              const SizedBox(height: 8),
                              Text(l10n.registerSummaryType(texts.label),
                                  style: const TextStyle(
                                      color: Color(0xFF999999))),
                              const SizedBox(height: 8),
                              Text(
                                  l10n.registerSummaryMainGroup(
                                      _mainGroupName),
                                  style: const TextStyle(
                                      color: Color(0xFF999999))),
                            ],
                          )
                        : DefaultTextStyle.merge(
                            style: const TextStyle(color: AppColors.medium),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.error_outline,
                                        color: AppColors.medium, size: 16),
                                    const SizedBox(width: 4),
                                    Expanded(
                                        child: Text(l10n.registerFillAll)),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                for (final missing in [
                                  if (_longName.isEmpty)
                                    l10n.registerMissingName,
                                  if (_shortName.isEmpty)
                                    l10n.registerMissingShortName,
                                  if (_mainGroupName.isEmpty)
                                    l10n.registerMissingMainGroup,
                                ])
                                  Padding(
                                    padding: const EdgeInsets.only(
                                        left: 8, top: 4, bottom: 4),
                                    child: Text('•  $missing',
                                        style:
                                            const TextStyle(fontSize: 14.4)),
                                  ),
                              ],
                            ),
                          ),
                  ),
                ),
              ],
            ),

            // ion-button expand="block" class="ion-margin"
            Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton.icon(
                onPressed: (_isLoading || !_isComplete) ? null : _createTenant,
                icon: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: AppSpinner(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_circle_outline),
                label: IonButtonLabel(
                    _isLoading ? l10n.registerCreating : l10n.registerCreate),
              ),
            ),
            const SizedBox(height: 40), // .spacer
          ],
        ),
      ),
    );
  }

  /// Ionic ion-select `interface="action-sheet"` with the header
  /// "Was beschreibt deine Gruppe am besten?".
  Future<void> _chooseType(BuildContext context) async {
    final l10n = context.l10n;
    final options = TenantTypeTexts.byType(l10n);
    // IOS_LOOK: Ionic action sheet (adaptive).
    final selected = await showAppActionSheet<String>(
      context,
      title: l10n.registerGroupTypeQuestion,
      actions: [
        for (final entry in options.entries)
          AppActionSheetAction(
            value: entry.key,
            label: entry.value.option,
            icon: entry.value.icon,
            color: entry.key == _selectedType ? AppColors.primary : null,
          ),
      ],
    );
    if (selected != null && mounted) {
      setState(() => _selectedType = selected);
    }
  }

  /// Ionic register.page logout(): sign out and back to the login page.
  Future<void> _logout() async {
    final supabase = ref.read(supabaseClientProvider);
    await ref.read(currentTenantProvider.notifier).clearTenant();
    await removePushTokenBeforeSignOut(ref); // PUSH
    await supabase.auth.signOut();
    if (mounted) context.go('/login');
  }

  /// DB_REVIEW_REST (F4): Ionic register.page confirmDeleteAccount.
  Future<void> _confirmDeleteAccount() async {
    final l10n = context.l10n;
    final confirmed = await showAppDialog<bool>(
      context: context,
      builder: (dialogContext) => AppAlertDialog(
        title: Text(l10n.registerDeleteHeader),
        content: Text(l10n.registerDeleteMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: Text(l10n.registerDeleteConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    ToastHelper.showInfo(context, l10n.registerDeleteRunning);
    try {
      await ref.read(accountNotifierProvider.notifier).deleteAccount();
      if (!mounted) return;
      ToastHelper.showSuccess(context, l10n.registerDeleteDone);
      context.go('/login');
    } catch (e) {
      if (!mounted) return;
      final message = e is RepositoryException ? e.message : e.toString();
      ToastHelper.showError(
        context,
        l10n.registerDeleteFailed(
            message.isEmpty ? l10n.commonUnknown : message),
      );
    }
  }

  /// Ionic main-group info popover (register.mainGroupInfoHtml).
  Future<void> _showMainGroupInfo() {
    return showAppDialog<void>(
      context: context,
      builder: (ctx) => AppAlertDialog(
        // Ionic register.mainGroupInfoHtml (rendered as HTML popover).
        content: SingleChildScrollView(
          child: _HtmlBlocks(html: ctx.l10n.registerMainGroupInfoHtml),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(ctx.l10n.commonOk),
          ),
        ],
      ),
    );
  }

  Future<void> _createTenant() async {
    if (!_isComplete) {
      ToastHelper.showError(context, context.l10n.registerFillAllToast);
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Ionic createInstance: tenant with register defaults, creator as
      // ADMIN, main group and default attendance types.
      final newTenant =
          await ref.read(tenantCreateRepositoryProvider).createTenant(
                shortName: _shortName,
                longName: _longName,
                type: _selectedType,
                mainGroupName: _mainGroupName,
                // Ionic register.page: device timezone
                timezone: deviceTimezone(),
              );

      if (mounted) ToastHelper.showSuccess(context, context.l10n.dbInstanceCreated);

      // Refresh the tenants list
      ref.invalidate(userTenantsProvider);

      // Set as current tenant
      await ref.read(currentTenantProvider.notifier).setTenant(newTenant);
      try {
        await ref.read(currentTenantUserProvider.future);
      } catch (_) {}

      // Ionic: navigateByUrl(Utils.getUrl(Role.ADMIN))
      if (mounted) {
        context.go(Role.admin.defaultRoute);
      }
    } catch (e) {
      if (mounted) {
        ToastHelper.showError(context, context.l10n.registerCreateFailed(friendlyErrorMessage(e)));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}

/// Inline HTML (<strong>, <b>, <em>, <i>) of an Ionic *Html key → spans.
List<InlineSpan> _inlineHtml(String html, {TextStyle? base}) {
  final spans = <InlineSpan>[];
  var bold = false;
  var italic = false;
  final re = RegExp(r'<(/?)(strong|b|em|i)>|<[^>]+>|[^<]+');
  for (final m in re.allMatches(html)) {
    final tag = m.group(2);
    if (tag != null) {
      final open = m.group(1)!.isEmpty;
      if (tag == 'strong' || tag == 'b') bold = open;
      if (tag == 'em' || tag == 'i') italic = open;
      continue;
    }
    final text = m.group(0)!;
    if (text.startsWith('<')) continue;
    spans.add(TextSpan(
      text: text,
      style: (base ?? const TextStyle()).copyWith(
        fontWeight: bold ? FontWeight.bold : null,
        fontStyle: italic ? FontStyle.italic : null,
      ),
    ));
  }
  return spans;
}

/// Minimal block HTML (<h3>, <p>, <li>) of an Ionic *Html key → widgets.
class _HtmlBlocks extends StatelessWidget {
  const _HtmlBlocks({required this.html});

  final String html;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final blocks = RegExp(r'<(h3|p|li)>(.*?)</\1>', dotAll: true)
        .allMatches(html)
        .toList();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final b in blocks)
          Padding(
            padding: EdgeInsets.only(
              bottom: b.group(1) == 'li' ? 2 : 10,
              left: b.group(1) == 'li' ? 4 : 0,
            ),
            child: Text.rich(TextSpan(
              children: [
                if (b.group(1) == 'li') const TextSpan(text: '• '),
                ..._inlineHtml(b.group(2)!),
              ],
              style: b.group(1) == 'h3'
                  ? theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)
                  : null,
            )),
          ),
      ],
    );
  }
}

/// `.step-badge`: 24 px primary circle with the step number.
class _StepBadge extends StatelessWidget {
  const _StepBadge(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppColors.primary,
        shape: BoxShape.circle,
      ),
      child: Text(
        text,
        style: const TextStyle(
            color: Colors.white, fontSize: 13.6, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// `ion-card`: 16 px margin, white rounded card (iOS 26 theme: 24 px
/// corners, soft shadow; MD: 4 px corners, elevation 1).
class _IonCard extends StatelessWidget {
  const _IonCard({required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ios = ionIsIos(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(ios ? 24 : 4),
        boxShadow: [
          BoxShadow(
            color: ios ? const Color(0x1F000000) : const Color(0x33000000),
            blurRadius: ios ? 12 : 2,
            offset: Offset(0, ios ? 4 : 1),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: padding ?? const EdgeInsets.fromLTRB(20, 20, 20, 8),
        child: child,
      ),
    );
  }
}
