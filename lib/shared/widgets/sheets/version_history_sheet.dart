import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/models/version_history.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/l10n.dart';
import '../../../core/utils/error_message.dart';
import '../adaptive/adaptive.dart'; // IOS_LOOK

/// Bottom sheet showing version history (What's New)
class VersionHistorySheet extends StatefulWidget {
  const VersionHistorySheet({super.key});

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
      final jsonString =
          await rootBundle.loadString('assets/version_history.json');
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

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppDimensions.borderRadiusL),
            ),
          ),
          child: Column(
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
              // Header
              Padding(
                padding: const EdgeInsets.all(AppDimensions.paddingM),
                child: Row(
                  children: [
                    const Icon(Icons.auto_awesome, color: AppColors.warning),
                    const SizedBox(width: AppDimensions.paddingS),
                    Expanded(
                      child: Text(
                        context.l10n.settingsWhatsNew,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Content
              Expanded(
                child: _buildContent(scrollController),
              ),
            ],
          ),
        );
      },
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
            const Icon(Icons.error_outline, size: 48, color: AppColors.danger),
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
            const Icon(Icons.history, size: 48, color: AppColors.medium),
            const SizedBox(height: AppDimensions.paddingM),
            Text(context.l10n.coreFlutterNoVersionHistory),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      itemCount: versions.length,
      itemBuilder: (context, index) {
        final version = versions[index];
        return _VersionSection(version: version, isFirst: index == 0);
      },
    );
  }
}

/// Section showing a single version with its changes
class _VersionSection extends StatelessWidget {
  const _VersionSection({
    required this.version,
    this.isFirst = false,
  });

  final VersionEntry version;
  final bool isFirst;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Version header
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.paddingS,
            vertical: AppDimensions.paddingS,
          ),
          decoration: BoxDecoration(
            color: isFirst
                ? AppColors.primary.withValues(alpha: 0.1)
                : AppColors.medium.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
          ),
          child: Row(
            children: [
              Icon(
                isFirst ? Icons.new_releases : Icons.history,
                size: 16,
                color: isFirst ? AppColors.primary : AppColors.medium,
              ),
              const SizedBox(width: AppDimensions.paddingS),
              Expanded(
                child: Text(
                  version.date != null
                      ? '${context.l10n.loginVersion(version.version)} (${version.date})'
                      : context.l10n.loginVersion(version.version),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: isFirst ? AppColors.primary : null,
                  ),
                ),
              ),
              if (isFirst)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    context.l10n.settingsCurrent,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppDimensions.paddingS),
        // Changes list
        ...version.changes.map((change) => Padding(
              padding: const EdgeInsets.only(
                left: AppDimensions.paddingS,
                bottom: AppDimensions.paddingXS,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('•  ', style: TextStyle(color: AppColors.medium)),
                  Expanded(
                    child: Text(
                      change,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            )),
        const SizedBox(height: AppDimensions.paddingM),
      ],
    );
  }
}

/// Shows the version history sheet as a bottom sheet
Future<void> showVersionHistorySheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const VersionHistorySheet(),
  );
}
