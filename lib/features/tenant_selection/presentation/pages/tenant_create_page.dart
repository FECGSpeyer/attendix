import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/repositories/tenant_create_repository.dart';
import '../../../../l10n/l10n.dart';

/// AUTH: Ionic "Neue Instanz anlegen" (register.page) – 3 steps:
/// 1. Art der Gruppe, 2. Name + Kürzel, 3. Hauptgruppe, then summary.
class TenantCreatePage extends ConsumerStatefulWidget {
  const TenantCreatePage({super.key});

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

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final texts = TenantTypeTexts.of(_selectedType, l10n);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.registerTitle),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _isLoading
              ? null
              : () => context.canPop() ? context.pop() : context.go('/tenants'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppDimensions.paddingM),
        children: [
          // Intro card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.paddingM),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.rocket_launch_outlined,
                          color: AppColors.primary),
                      const SizedBox(width: AppDimensions.paddingS),
                      Text(l10n.registerWelcome,
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: AppDimensions.paddingS),
                  // Ionic register.introHtml (inline <strong>).
                  Text.rich(TextSpan(children: _inlineHtml(l10n.registerIntroHtml))),
                ],
              ),
            ),
          ),

          // Join hint
          Card(
            color: AppColors.warning.withValues(alpha: 0.1),
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.paddingM),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.registerJoinHeading,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(l10n.registerJoinText),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppDimensions.paddingM),

          // Step 1
          _StepHeader(badge: '1', title: l10n.registerStep1),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.paddingM),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    value: _selectedType,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: l10n.registerGroupType,
                      helperText: l10n.registerGroupTypeQuestion,
                    ),
                    items: [
                      for (final entry in TenantTypeTexts.byType(l10n).entries)
                        DropdownMenuItem(
                          value: entry.key,
                          child: Row(
                            children: [
                              Icon(entry.value.icon, size: 20),
                              const SizedBox(width: AppDimensions.paddingS),
                              Text(entry.value.option),
                            ],
                          ),
                        ),
                    ],
                    onChanged: _isLoading
                        ? null
                        : (value) =>
                            setState(() => _selectedType = value ?? 'general'),
                  ),
                  const SizedBox(height: AppDimensions.paddingM),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.check_circle,
                          color: AppColors.success, size: 18),
                      const SizedBox(width: AppDimensions.paddingS),
                      Expanded(child: Text(texts.help)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppDimensions.paddingM),

          // Step 2
          _StepHeader(badge: '2', title: l10n.registerStep2),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.paddingM),
              child: Column(
                children: [
                  TextField(
                    controller: _longNameController,
                    maxLength: 50,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: l10n.registerFullName,
                      hintText: texts.namePlaceholder,
                      helperText: l10n.registerFullNameHelper,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.paddingS),
                  TextField(
                    controller: _shortNameController,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      labelText: l10n.registerShortName,
                      hintText: texts.shortPlaceholder,
                      helperText: l10n.registerShortNameHelper,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppDimensions.paddingM),

          // Step 3
          _StepHeader(
            badge: '3',
            title: l10n.registerStep3,
            trailing: IconButton(
              tooltip: l10n.registerFlutterMainGroupInfo,
              icon: const Icon(Icons.help_outline),
              onPressed: _showMainGroupInfo,
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.paddingM),
              child: TextField(
                controller: _mainGroupNameController,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: l10n.registerMainGroupName,
                  hintText: texts.mainGroupPlaceholder,
                  helperText: l10n.registerMainGroupHelper,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppDimensions.paddingM),

          // Summary
          _StepHeader(badge: '✓', title: l10n.registerSummary),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.paddingM),
              child: _isComplete
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text.rich(TextSpan(children: [
                          TextSpan(
                            text: _longName,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          TextSpan(text: ' ($_shortName)'),
                        ])),
                        const SizedBox(height: 4),
                        Text(l10n.registerSummaryType(texts.label)),
                        const SizedBox(height: 4),
                        Text(l10n.registerSummaryMainGroup(_mainGroupName)),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.error_outline,
                                color: AppColors.medium, size: 18),
                            const SizedBox(width: AppDimensions.paddingS),
                            Expanded(
                              child: Text(l10n.registerFillAll),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        for (final missing in [
                          if (_longName.isEmpty) l10n.registerMissingName,
                          if (_shortName.isEmpty) l10n.registerMissingShortName,
                          if (_mainGroupName.isEmpty) l10n.registerMissingMainGroup,
                        ])
                          Padding(
                            padding: const EdgeInsets.only(left: 26, top: 2),
                            child: Text('• $missing',
                                style: TextStyle(color: AppColors.medium)),
                          ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: AppDimensions.paddingM),

          FilledButton.icon(
            onPressed: (_isLoading || !_isComplete) ? null : _createTenant,
            icon: _isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add_circle_outline),
            label: Text(_isLoading
                ? l10n.registerCreating
                : l10n.registerCreate),
          ),
          const SizedBox(height: AppDimensions.paddingXL),
        ],
      ),
    );
  }

  /// Ionic main-group info popover (register.mainGroupInfoHtml).
  Future<void> _showMainGroupInfo() {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
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
              );

      // Refresh the tenants list
      ref.invalidate(userTenantsProvider);

      // Set as current tenant
      await ref.read(currentTenantProvider.notifier).setTenant(newTenant);

      if (mounted) {
        context.go('/people');
      }
    } catch (e) {
      if (mounted) {
        ToastHelper.showError(context, context.l10n.registerCreateFailed(e));
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

class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.badge, required this.title, this.trailing});

  final String badge;
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
          left: AppDimensions.paddingXS, bottom: AppDimensions.paddingXS),
      child: Row(
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: AppColors.primary,
            child: Text(
              badge,
              style: const TextStyle(
                  color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: AppDimensions.paddingS),
          Expanded(
            child: Text(
              title,
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
