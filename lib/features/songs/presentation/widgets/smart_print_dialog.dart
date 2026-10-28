import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/smart_print_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../l10n/l10n.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart'; // IOS_LOOK

/// Dialog for smart printing with instrument-based copy selection
class SmartPrintDialog extends ConsumerStatefulWidget {
  final String url;
  final String fileName;
  final int? instrumentId;

  const SmartPrintDialog({
    super.key,
    required this.url,
    required this.fileName,
    this.instrumentId,
  });

  @override
  ConsumerState<SmartPrintDialog> createState() => _SmartPrintDialogState();
}

class _SmartPrintDialogState extends ConsumerState<SmartPrintDialog> {
  List<PrintCopyInfo>? _copyInfos;
  bool _isLoading = true;
  bool _isPrinting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCopyInfo();
  }

  Future<void> _loadCopyInfo() async {
    try {
      final smartPrintService = ref.read(smartPrintServiceProvider);
      final infos = await smartPrintService.getPrintCopyInfo(
        instrumentId: widget.instrumentId,
      );

      if (mounted) {
        setState(() {
          _copyInfos = infos;
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

  void _applyPreset(int numerator, int denominator) {
    if (_copyInfos == null) return;
    setState(() {
      for (int i = 0; i < _copyInfos!.length; i++) {
        final count = (_copyInfos![i].playerCount * numerator / denominator).ceil();
        _copyInfos![i] = _copyInfos![i].copyWith(copies: count.clamp(1, 99));
      }
    });
  }

  void _updateCopies(int index, int newCopies) {
    // RT-007: Add bounds check
    final infos = _copyInfos;
    if (infos == null || index < 0 || index >= infos.length) return;
    setState(() {
      _copyInfos![index] = infos[index].copyWith(
        copies: newCopies.clamp(0, 99),
      );
    });
  }

  int get _totalCopies {
    if (_copyInfos == null) return 0;
    return _copyInfos!.fold<int>(0, (sum, info) => sum + info.copies);
  }

  Future<void> _print() async {
    if (_copyInfos == null || _totalCopies == 0) return;

    setState(() => _isPrinting = true);

    try {
      final smartPrintService = ref.read(smartPrintServiceProvider);
      await smartPrintService.printPdf(
        url: widget.url,
        copyInfos: _copyInfos!,
        fileName: widget.fileName,
      );

      if (mounted) {
        Navigator.of(context).pop();
        ToastHelper.showSuccess(context, context.l10n.songsFlutterPrintJobSent);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isPrinting = false);
        ToastHelper.showError(context, context.l10n.songsFlutterPrintFailed(friendlyErrorMessage(e)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppAlertDialog(
      title: Row(
        children: [
          const Icon(Icons.print, color: AppColors.primary),
          const SizedBox(width: AppDimensions.paddingS),
          Expanded(
            child: Text(
              context.l10n.songsPrint,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: _buildContent(),
      ),
      actions: [
        TextButton(
          onPressed: _isPrinting ? null : () => Navigator.of(context).pop(),
          child: Text(context.l10n.commonCancel),
        ),
        ElevatedButton.icon(
          onPressed: _isPrinting || _totalCopies == 0 ? null : _print,
          icon: _isPrinting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: AppSpinner(strokeWidth: 2),
                )
              : const Icon(Icons.print),
          label: Text(_isPrinting ? context.l10n.songsFlutterPrinting : '${context.l10n.songsPrint} ($_totalCopies)'),
        ),
      ],
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(AppDimensions.paddingL),
        child: Center(child: AppSpinner()),
      );
    }

    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.danger),
            const SizedBox(height: AppDimensions.paddingM),
            Text(context.l10n.songsFlutterErrorWith('$_error')),
          ],
        ),
      );
    }

    if (_copyInfos == null || _copyInfos!.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.people_outline, size: 48, color: AppColors.medium),
            const SizedBox(height: AppDimensions.paddingM),
            Text(context.l10n.songsFlutterNoPlayers),
          ],
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.fileName,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            color: AppColors.medium,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: AppDimensions.paddingS),
        const Divider(),
        const SizedBox(height: AppDimensions.paddingS),
        Text(
          context.l10n.songsFlutterCopiesPerInstrument,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: AppDimensions.paddingXS),
        Wrap(
          spacing: AppDimensions.paddingS,
          children: [
            ActionChip(label: const Text('1:1'), onPressed: () => _applyPreset(1, 1)),
            ActionChip(label: const Text('1:2'), onPressed: () => _applyPreset(1, 2)),
            ActionChip(label: const Text('1:3'), onPressed: () => _applyPreset(1, 3)),
            ActionChip(label: Text(context.l10n.songsFlutterOneEach), onPressed: () {
              if (_copyInfos == null) return;
              setState(() {
                for (int i = 0; i < _copyInfos!.length; i++) {
                  _copyInfos![i] = _copyInfos![i].copyWith(copies: 1);
                }
              });
            }),
          ],
        ),
        const SizedBox(height: AppDimensions.paddingS),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 300),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _copyInfos!.length,
            itemBuilder: (context, index) {
              final info = _copyInfos![index];
              return _CopyCountRow(
                groupName: info.group.name,
                playerCount: info.playerCount,
                copies: info.copies,
                onChanged: (value) => _updateCopies(index, value),
              );
            },
          ),
        ),
        const Divider(),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppDimensions.paddingS),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${context.l10n.churchOverviewTotal}:',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                context.l10n.songsFlutterCopiesCount(_totalCopies),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Row widget for copy count adjustment
class _CopyCountRow extends StatelessWidget {
  final String groupName;
  final int playerCount;
  final int copies;
  final ValueChanged<int> onChanged;

  const _CopyCountRow({
    required this.groupName,
    required this.playerCount,
    required this.copies,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  groupName,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  context.l10n.teachersPlayerCount(playerCount),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.medium,
                  ),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: copies > 0 ? () => onChanged(copies - 1) : null,
                visualDensity: VisualDensity.compact,
                iconSize: 20,
              ),
              SizedBox(
                width: 32,
                child: Text(
                  '$copies',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: copies < 99 ? () => onChanged(copies + 1) : null,
                visualDensity: VisualDensity.compact,
                iconSize: 20,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Shows the smart print dialog
Future<void> showSmartPrintDialog(
  BuildContext context, {
  required WidgetRef ref,
  required String url,
  required String fileName,
  int? instrumentId,
}) {
  return showAppDialog(
    context: context,
    builder: (context) => SmartPrintDialog(
      url: url,
      fileName: fileName,
      instrumentId: instrumentId,
    ),
  );
}
