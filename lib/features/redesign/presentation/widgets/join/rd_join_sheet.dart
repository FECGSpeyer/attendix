import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/theme/redesign/rd_theme.dart';
import '../../../../../l10n/l10n.dart';
import '../../../../registration/data/providers/registration_providers.dart';
import '../rd_widgets.dart';
import 'rd_qr_scan_page.dart';

/// Register id of an invitation: the part after ".../register/" of a
/// pasted link, or the bare id; null when it is neither.
String? rdRegisterIdFromLink(String input) {
  final text = input.trim();
  if (text.isEmpty) return null;
  final match = RegExp(r'register/([A-Za-z0-9-]{20,})').firstMatch(text);
  if (match != null) return match.group(1);
  return RegExp(r'^[A-Za-z0-9-]{20,}$').hasMatch(text) ? text : null;
}

/// REDESIGN (UX B1, N1): "Gruppe beitreten": paste or scan the invitation link,
/// see which group it belongs to, continue to the existing sign-up page
/// (`/register/:id`). Writes nothing itself.
Future<void> showRdJoinSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: context.rd.bg,
    builder: (_) => const _JoinSheet(),
  );
}

class _JoinSheet extends ConsumerStatefulWidget {
  const _JoinSheet();

  @override
  ConsumerState<_JoinSheet> createState() => _JoinSheetState();
}

class _JoinSheetState extends ConsumerState<_JoinSheet> {
  final _link = TextEditingController();

  @override
  void dispose() {
    _link.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final text = _link.text.trim();
    final id = rdRegisterIdFromLink(text);
    final lookup = id == null ? null : ref.watch(tenantByRegisterIdProvider(id));
    final tenant = lookup?.valueOrNull;

    Widget? status;
    if (text.isNotEmpty && id == null) {
      status = Text(l10n.redesignJoinInvalid, style: RdType.meta(p, size: 14).copyWith(color: p.absent));
    } else if (lookup != null && lookup.isLoading) {
      status = const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2));
    } else if (lookup != null && (lookup.hasError || tenant == null)) {
      status = Text(l10n.redesignJoinNotFound, style: RdType.meta(p, size: 14).copyWith(color: p.absent));
    } else if (tenant != null) {
      final name = tenant.longName.isNotEmpty ? tenant.longName : tenant.shortName;
      status = Row(
        children: [
          Icon(Icons.check_circle, color: p.present, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n.redesignJoinFound(name),
              style: RdType.body(p).copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      );
    }

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.redesignJoinTitle, style: RdType.cardTitle(p)),
              const SizedBox(height: 4),
              Text(l10n.redesignJoinIntro, style: RdType.body(p).copyWith(color: p.text2)),
              const SizedBox(height: 16),
              TextField(
                controller: _link,
                autofocus: true,
                keyboardType: TextInputType.url,
                autocorrect: false,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: l10n.redesignJoinLabel,
                  hintText: 'attendix.de/register/…',
                  filled: true,
                  fillColor: p.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(p.buttonRadius),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              if (status != null) ...[const SizedBox(height: 12), status],
              const SizedBox(height: 16),
              RdPrimaryButton(
                label: l10n.redesignJoinContinue,
                icon: Icons.arrow_forward,
                onPressed: tenant == null || id == null
                    ? null
                    : () {
                        final router = GoRouter.of(context);
                        Navigator.of(context).pop();
                        router.push('/register/$id');
                      },
              ),
              const SizedBox(height: 8),
              RdOutlineButton(
                label: l10n.redesignJoinScan,
                icon: Icons.qr_code_scanner,
                onPressed: () async {
                  final value = await showRdQrScanPage(context);
                  if (value == null || !mounted) return;
                  setState(() => _link.text = value);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
