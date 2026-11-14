import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:attendix/shared/widgets/layout/sheet_drag.dart';
import 'package:attendix/core/theme/app_icons.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/models/version_history.dart';
import '../../../core/providers/redesign_providers.dart';
import '../../../core/theme/redesign/rd_theme.dart';
import '../../../features/redesign/presentation/widgets/rd_widgets.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/l10n.dart';
import '../../../core/utils/error_message.dart';
import '../adaptive/adaptive.dart';
import '../../../features/auth/presentation/widgets/ion_form_list.dart';
import '../layout/ion_modal_handle.dart';

/// User-facing version history ("Was ist neu"): the continued Ionic history
/// with the store versions, topmost entry = [AppConstants.displayVersion].
/// The internal 0.x history (`assets/version_history.json`) is not shown.
const versionHistoryUserAsset = 'assets/version_history_user.json';

/// Bottom sheet showing version history (What's New)
class VersionHistorySheet extends StatefulWidget {
  const VersionHistorySheet({super.key, this.beta = false});

  /// Beta look (content of an [showRdSheet] sheet).
  final bool beta;

  @override
  State<VersionHistorySheet> createState() => _VersionHistorySheetState();
}

class _VersionHistorySheetState extends State<VersionHistorySheet> {
  VersionHistory? _versionHistory;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadVersionHistory();
  }

  Future<void> _loadVersionHistory() async {
    try {
      final jsonString = await rootBundle.loadString(versionHistoryUserAsset);
      final jsonData = json.decode(jsonString) as Map<String, dynamic>;
      if (mounted) {
        setState(() {
          _versionHistory = VersionHistory.fromJson(jsonData);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = friendlyErrorMessage(e);
          _isLoading = false;
        });
      }
    }
  }

  // IOS_FORMS1: Ionic "What's New" modal – sheet with breakpoints
  // [0, .5, 1] (initial .5), `ion-content color="light"`, a light toolbar
  // with only the title (centred on iOS, no close button) and an inset list:
  // one grey `ion-list-header` "Version x (date)" + one white item group
  // with a row per change for every version.
  @override
  Widget build(BuildContext context) {
    if (widget.beta) return _buildBeta(context);
    final ios = useIosLook(context);
    return AppDraggableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.25,
      maxChildSize: 1,
      snap: true,
      snapSizes: const [0.5],
      expand: false,
      builder: (context, scrollController) {
        final sheet = Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppDimensions.borderRadiusL),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (ios)
                IonModalHeader(
                  title: Text(context.l10n.settingsWhatsNew),
                  showClose: false,
                )
              else ...[
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: Text(
                    context.l10n.settingsWhatsNew,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                const Divider(height: 1),
              ],
              Expanded(
                child: _buildContent(scrollController),
              ),
            ],
          ),
        );
        return ios ? IonModalHandleOverlay(child: sheet) : sheet;
      },
    );
  }

  /// REDESIGN (E2): "Neu in dieser Version" as a Beta sheet, one group per
  /// version ("5.0.0 · 6.11.2026") with a row per change.
  Widget _buildBeta(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final versions = _versionHistory?.versions ?? const <VersionEntry>[];
    final Widget body;
    if (_isLoading) {
      body = const Padding(padding: EdgeInsets.all(32), child: Center(heightFactor: 1, child: AppSpinner()));
    } else if (_error != null || versions.isEmpty) {
      body = Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          _error != null ? l10n.coreFlutterErrorWith('$_error') : l10n.coreFlutterNoVersionHistory,
          style: RdType.meta(p, size: 15),
          textAlign: TextAlign.center,
        ),
      );
    } else {
      body = ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          for (final v in versions) ...[
            RdGroupLabel(v.date != null ? '${v.version} · ${v.date}' : v.version),
            RdGroupedList(
              children: [
                for (final change in v.changes)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Text(change, style: RdType.body(p)),
                  ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ],
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RdSheetTitle(l10n.redesignMeWhatsNew),
        Flexible(child: body),
      ],
    );
  }

  Widget _buildContent(ScrollController scrollController) {
    if (_isLoading) {
      return const Center(child: AppSpinner());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(AppIcons.errorOutline, size: 48, color: AppColors.danger),
            const SizedBox(height: AppDimensions.paddingM),
            Text(context.l10n.coreFlutterErrorWith('$_error')),
          ],
        ),
      );
    }

    final versions = _versionHistory?.versions ?? [];

    if (versions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(AppIcons.history, size: 48, color: AppColors.medium),
            const SizedBox(height: AppDimensions.paddingM),
            Text(context.l10n.coreFlutterNoVersionHistory),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: scrollController,
      padding: EdgeInsets.only(
        top: 8,
        bottom: 16 + MediaQuery.paddingOf(context).bottom,
      ),
      itemCount: versions.length,
      itemBuilder: (context, index) {
        return _VersionSection(version: versions[index]);
      },
    );
  }
}

/// One version: `ion-list-header` "Version x (date)" and an
/// `ion-item-group` with one `ion-item` per change.
class _VersionSection extends StatelessWidget {
  const _VersionSection({required this.version});

  final VersionEntry version;

  @override
  Widget build(BuildContext context) {
    final header = version.date != null
        ? '${context.l10n.loginVersion(version.version)} (${version.date})'
        : context.l10n.loginVersion(version.version);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        IonListHeader(header),
        IonInsetGroup(
          children: [
            // AUTH_R5: the Ionic app (screenshot audit) shows every change
            // in full, wrapped over several lines – no truncation.
            for (final change in version.changes)
              IonItem(
                title: Text(change, softWrap: true),
              ),
          ],
        ),
      ],
    );
  }
}

/// Shows the version history sheet as a bottom sheet
Future<void> showVersionHistorySheet(BuildContext context) {
  if (ProviderScope.containerOf(context, listen: false).read(redesignEnabledProvider)) {
    return showRdSheet<void>(context, const VersionHistorySheet(beta: true));
  }
  return showModalBottomSheet(
    context: context,
    useRootNavigator: true, // IOS_SHELL2: above the tab bar
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const VersionHistorySheet(),
  );
}
