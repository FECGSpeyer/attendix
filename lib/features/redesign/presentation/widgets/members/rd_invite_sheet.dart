import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../../core/providers/tenant_providers.dart';
import '../../../../../core/theme/redesign/rd_theme.dart';
import '../../../../../data/models/tenant/tenant.dart';
import '../../../../../l10n/l10n.dart';
import '../../rd_actions.dart' show rdShareLink;
import '../rd_widgets.dart';

/// Sign-up link of [tenant] (as in Verwaltung › Allgemein), null while
/// registration is off.
String? rdInviteLink(Tenant? tenant) {
  final id = tenant?.registerId;
  if (id == null || id.isEmpty) return null;
  return 'https://attendix.de/register/$id';
}

/// REDESIGN (UX D1): "Mitglieder einladen" right in the Mitglieder tab:
/// the existing sign-up link to share or copy and as QR code to show in
/// the rehearsal. Reads only; switching registration on stays in
/// Verwaltung › Allgemein.
Future<void> showRdInviteSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: context.rd.bg,
    builder: (_) => const _InviteSheet(),
  );
}

class _InviteSheet extends ConsumerWidget {
  const _InviteSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.rd;
    final l10n = context.l10n;
    final tenant = ref.watch(currentTenantProvider);
    final link = rdInviteLink(tenant);
    final group = tenant?.longName.isNotEmpty == true ? tenant!.longName : (tenant?.shortName ?? '');

    final children = <Widget>[
      Text(l10n.redesignInviteTitle, style: RdType.cardTitle(p)),
      const SizedBox(height: 4),
    ];
    if (link == null) {
      children.addAll([
        Text(l10n.redesignInviteOff, style: RdType.body(p).copyWith(color: p.text2)),
        const SizedBox(height: 16),
        RdOutlineButton(
          label: l10n.redesignInviteTurnOn,
          icon: Icons.settings_outlined,
          onPressed: () {
            final router = GoRouter.of(context);
            Navigator.of(context).pop();
            router.push('/settings/general');
          },
        ),
      ]);
    } else {
      children.addAll([
        Text(
          tenant!.autoApproveRegistrations ? l10n.redesignInviteIntroAuto : l10n.redesignInviteIntro,
          style: RdType.body(p).copyWith(color: p.text2),
        ),
        const SizedBox(height: 16),
        RdCard(
          child: Column(
            children: [
              _InviteQr(link: link, group: group, size: 200),
              const SizedBox(height: 12),
              if (group.isNotEmpty) Text(group, style: RdType.body(p).copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      link.replaceFirst('https://', ''),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: RdType.meta(p, size: 13),
                    ),
                  ),
                  RdTextLink(
                    label: l10n.redesignInviteCopy,
                    onTap: () async {
                      await Clipboard.setData(ClipboardData(text: link));
                      if (context.mounted) {
                        ScaffoldMessenger.maybeOf(context)
                            ?.showSnackBar(SnackBar(content: Text(l10n.redesignInviteCopied)));
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Builder(
          builder: (button) => RdPrimaryButton(
            label: l10n.redesignInviteShare,
            icon: Icons.ios_share,
            onPressed: () => rdShareLink(
              button,
              link,
              subject: l10n.redesignInviteShareSubject(group),
              copiedMessage: l10n.redesignInviteCopied,
            ),
          ),
        ),
        const SizedBox(height: 8),
        RdOutlineButton(
          label: l10n.redesignInviteFullscreen,
          icon: Icons.fullscreen,
          onPressed: () => _showFullscreen(context, link, group),
        ),
      ]);
    }

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
      ),
    );
  }

  static Future<void> _showFullscreen(BuildContext context, String link, String group) {
    return Navigator.of(context, rootNavigator: true).push(MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (context) => Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close),
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, c) {
              final size = (c.biggest.shortestSide - 96).clamp(160.0, 520.0);
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _InviteQr(link: link, group: group, size: size),
                    const SizedBox(height: 16),
                    if (group.isNotEmpty)
                      Text(
                        group,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.black),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    ));
  }
}

/// Black on white in every Farbwelt, so every camera reads it.
class _InviteQr extends StatelessWidget {
  const _InviteQr({required this.link, required this.group, required this.size});

  final String link;
  final String group;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: context.l10n.redesignInviteQrLabel(group),
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.all(8),
        child: QrImageView(
          data: link,
          size: size,
          backgroundColor: Colors.white,
          padding: EdgeInsets.zero,
        ),
      ),
    );
  }
}
