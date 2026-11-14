import 'package:flutter/material.dart';
import 'package:attendix/shared/widgets/dialogs/ion_sheet.dart';
import 'package:attendix/core/theme/app_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/supabase_config.dart';
import '../../../../core/providers/group_providers.dart';
import '../../../../core/services/song_file_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/instrument/instrument.dart';
import '../../../../data/models/song/song.dart';
import '../../../../data/models/tenant/tenant.dart';
import '../../../../core/utils/demo_guard.dart';
import '../../../../l10n/l10n.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';
import '../../../../core/theme/redesign/rd_theme.dart';
import '../../../redesign/presentation/widgets/manage/rd_settings_sheets.dart';
import '../../../redesign/presentation/widgets/rd_widgets.dart';

/// `instrument_ids` of a copied song (Ionic copySongToTenant): the mapped
/// target instrument ids of the copied files, without null and the reserved
/// ids 1 and 2, de-duplicated in first-seen order.
List<int> copiedSongInstrumentIds(Iterable<int?> mappedIds) => mappedIds
    .whereType<int>()
    .where((id) => id != 1 && id != 2)
    .toSet()
    .toList();

/// Sheet for copying a song to another tenant
class CopyToTenantSheet extends ConsumerStatefulWidget {
  final Song song;
  final List<Tenant> availableTenants;

  const CopyToTenantSheet({
    super.key,
    required this.song,
    required this.availableTenants,
    this.beta = false,
  });

  /// REDESIGN: the Beta look (canvas "Datei-Dialoge im Werk"): target
  /// group as a row, what comes along below, progress in the button.
  /// Same copy as the old sheet.
  final bool beta;

  @override
  ConsumerState<CopyToTenantSheet> createState() => _CopyToTenantSheetState();
}

class _CopyToTenantSheetState extends ConsumerState<CopyToTenantSheet> {
  late int _targetTenantId;
  bool _isCopying = false;
  String _progressMessage = '';

  @override
  void initState() {
    super.initState();
    // BL-001: Safe access to first tenant
    final firstTenant = widget.availableTenants.firstOrNull;
    if (firstTenant?.id == null) {
      // Should not happen as parent validates, but defensive
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
      _targetTenantId = 0;
      return;
    }
    _targetTenantId = firstTenant!.id!;
  }

  // Ionic: the loading overlay covers the modal while copying, so it cannot
  // be closed before the copy is complete.
  @override
  Widget build(BuildContext context) =>
      PopScope(canPop: !_isCopying, child: widget.beta ? _buildBeta(context) : _buildSheet(context));

  Widget _buildBeta(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final target = widget.availableTenants.where((t) => t.id == _targetTenantId).firstOrNull;
    final files = widget.song.files ?? const [];
    const shown = 2;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Decorative grab bar only (the sheet cannot be dragged closed).
          Center(
            child: Container(
              width: 36,
              height: 5,
              margin: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(color: p.line, borderRadius: BorderRadius.circular(3)),
            ),
          ),
          // Like RdSheetHead, but "Abbrechen" is off while copying.
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 96,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      key: const Key('rd-copy-cancel'),
                      onPressed: _isCopying ? null : () => Navigator.of(context).pop(),
                      child: Text(
                        l10n.redesignCommonCancel,
                        style: TextStyle(color: _isCopying ? p.text2 : p.link, fontSize: 16),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      l10n.songsCopySong,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: RdType.section(p),
                    ),
                  ),
                ),
                const SizedBox(width: 96),
              ],
            ),
          ),
          RdGroupedList(
            children: [
              RdListRow(
                key: const Key('rd-copy-target'),
                title: l10n.personTargetGroup,
                value: target?.longName ?? '',
                onTap: _isCopying || widget.availableTenants.length < 2 ? null : _pickTarget,
                showChevron: widget.availableTenants.length > 1,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(l10n.songsCopyInfo(widget.song.name), style: RdType.meta(p, size: 13)),
          ),
          if (files.isNotEmpty) ...[
            const SizedBox(height: 18),
            RdGroupLabel(l10n.songsFlutterFilesWillBeCopied(files.length)),
            RdGroupedList(
              children: [
                for (final f in files.take(shown)) RdListRow(title: f.fileName, showChevron: false),
                if (files.length > shown)
                  RdListRow(title: l10n.filesAndMore(files.length - shown), showChevron: false, titleColor: p.text2),
              ],
            ),
          ],
          const SizedBox(height: 20),
          RdPrimaryButton(
            key: const Key('rd-copy-start'),
            label: _isCopying ? _progressMessage : l10n.songsCopy,
            loading: _isCopying,
            onPressed: _isCopying ? null : _copySong,
          ),
        ],
      ),
    );
  }

  Future<void> _pickTarget() async {
    final picked = await showRdChoiceSheet<int>(
      context,
      title: context.l10n.personTargetGroup,
      selected: _targetTenantId,
      options: [
        for (final t in widget.availableTenants)
          if (t.id != null) (t.id!, t.longName),
      ],
    );
    if (picked == null || !mounted || _isCopying) return;
    setState(() => _targetTenantId = picked);
  }

  Widget _buildSheet(BuildContext context) {
    // Ionic copy modal: [breakpoints]="[0, 0.6, 1]" [initialBreakpoint]="0.6".
    return IonBreakpointSheet(
      breakpoints: const [0, 0.6, 1],
      initialBreakpoint: 0.6,
      // Dragging down to the bottom closes the sheet: not while copying.
      canDismiss: !_isCopying,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Header
            // Ionic: close button in `ion-buttons slot="end"`
            IonSheetHeader(
              title: context.l10n.songsCopySong,
              end: [IonCloseButton(onPressed: _isCopying ? () {} : null)],
            ),

            // Content
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                children: [
                  // Target tenant dropdown
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.l10n.shiftsFlutterTargetTenant,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.medium,
                            ),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<int>(
                            value: _targetTenantId,
                            decoration: InputDecoration(
                              prefixIcon: Icon(AppIcons.business),
                            ),
                            items: widget.availableTenants
                                .map((t) => DropdownMenuItem(
                                      value: t.id,
                                      child: Text(t.longName),
                                    ))
                                .toList(),
                            onChanged: _isCopying
                                ? null
                                : (value) {
                                    if (value != null) {
                                      setState(() => _targetTenantId = value);
                                    }
                                  },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Info card
                  Card(
                    color: AppColors.info.withAlpha(20),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(AppIcons.infoOutline, color: AppColors.info),
                              const SizedBox(width: 8),
                              Text(
                                context.l10n.shiftsFlutterNote,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.info,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            context.l10n.songsCopyInfo(widget.song.name),
                            style: const TextStyle(color: AppColors.medium),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Files preview
                  if (widget.song.files?.isNotEmpty == true) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.l10n.songsFlutterFilesWillBeCopied(widget.song.files!.length),
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppColors.medium,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...widget.song.files!.take(5).map((f) => Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 2),
                                  child: Row(
                                    children: [
                                      Icon(AppIcons.insertDriveFile,
                                          size: 16, color: AppColors.medium),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          f.fileName,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                )),
                            if (widget.song.files!.length > 5)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  '...${context.l10n.filesAndMore(widget.song.files!.length - 5)}',
                                  style: const TextStyle(color: AppColors.medium),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Progress indicator
                  if (_isCopying) ...[
                    const LinearProgressIndicator(),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        _progressMessage,
                        style: const TextStyle(color: AppColors.medium),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Copy button
                  ElevatedButton.icon(
                    onPressed: _isCopying ? null : _copySong,
                    icon: _isCopying
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: AppSpinner(strokeWidth: 2),
                          )
                        : Icon(AppIcons.copy),
                    label: IonButtonLabel(_isCopying ? context.l10n.shiftsFlutterCopyingShort : context.l10n.songsCopy),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  /// setState that is safe when the sheet was closed meanwhile (e.g. dragged
  /// down): the copy then still finishes completely.
  void _set(VoidCallback fn) {
    if (mounted) setState(fn);
  }

  Future<void> _copySong() async {
    if (DemoGuard.blocked()) return; // DEMO_GUARD
    final l10n = context.l10n;
    _set(() {
      _isCopying = true;
      _progressMessage = l10n.songsCopying;
    });

    try {
      // Get source groups for instrument mapping
      final sourceGroupsAsync = ref.read(groupsProvider);
      final sourceGroups = sourceGroupsAsync.valueOrNull ?? [];

      // Get target groups
      _set(() => _progressMessage = l10n.songsFlutterLoadingTargetGroups);
      final supabase = ref.read(supabaseClientProvider);
      // Read before the first await: the copy finishes even if the sheet
      // is gone by then.
      final songFileService = ref.read(songFileServiceProvider);
      final targetGroupsResponse = await supabase
          .from('instruments')
          .select('*')
          .eq('tenantId', _targetTenantId);

      final targetGroups = (targetGroupsResponse as List)
          .map((g) => Group.fromJson(g as Map<String, dynamic>))
          .toList();

      // Build instrument mapping
      final instrumentMapping = <int, int?>{};
      if (widget.song.files?.isNotEmpty == true) {
        for (final file in widget.song.files!) {
          if (file.instrumentId != null &&
              !instrumentMapping.containsKey(file.instrumentId)) {
            instrumentMapping[file.instrumentId!] = _mapInstrumentId(
              file.instrumentId!,
              sourceGroups,
              targetGroups,
            );
          }
        }
      }

      // Create song in target tenant
      _set(() => _progressMessage = l10n.songsFlutterCreatingInTarget);

      final newSongData = {
        'tenantId': _targetTenantId,
        'name': widget.song.name,
        'number': widget.song.number,
        'prefix': widget.song.prefix,
        'withChoir': widget.song.withChoir,
        'withSolo': widget.song.withSolo,
        'link': widget.song.link,
        'difficulty': widget.song.difficulty,
        // Like Ionic: categories are not copied, instrument_ids are set from files
        'instrument_ids': <int>[],
        'category': null,
        // PARITY_B (D15): Ionic db.copySongToTenant does not send category_ids
      };

      final insertResponse = await supabase
          .from('songs')
          .insert(newSongData)
          .select()
          .single();

      final newSongId = insertResponse['id'] as int;

      // Copy files if any
      // RT-008: Extract to local variable for null-safety
      final files = widget.song.files;
      if (files != null && files.isNotEmpty) {
        final fileCount = files.length;
        final mappedInstrumentIds = <int?>[];

        for (var i = 0; i < fileCount; i++) {
          final file = files[i];
          _set(() => _progressMessage =
              l10n.songsCopyingFile(i + 1, fileCount));

          // Download file bytes. Ionic copySongToTenant: a failed download
          // aborts the copy (→ toast songs.copyFailed) instead of silently
          // creating a song with missing files.
          final bytes = await songFileService.downloadFileBytes(file.url);
          if (bytes == null) {
            throw l10n.songsFlutterFileDownloadFailed(file.fileName);
          }

          // Map instrument ID
          final mappedInstrumentId = file.instrumentId != null
              ? instrumentMapping[file.instrumentId]
              : null;
          mappedInstrumentIds.add(mappedInstrumentId);

          // Upload to new song
          await songFileService.uploadFileBytes(
            songId: newSongId,
            tenantId: _targetTenantId,
            fileName: file.fileName,
            fileType: file.fileType,
            bytes: bytes,
            instrumentId: mappedInstrumentId,
            note: file.note,
          );
        }

        // Update instrument_ids on the new song from the mapped target ids
        // of the copied files (Ionic: filter null, 1 and 2; Set order).
        await supabase
            .from('songs')
            .update({'instrument_ids': copiedSongInstrumentIds(mappedInstrumentIds)})
            .eq('id', newSongId)
            .eq('tenantId', _targetTenantId);
      }

      if (mounted) {
        ToastHelper.showSuccess(context, l10n.songsCopied);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ToastHelper.showError(context, l10n.songsCopyFailed(friendlyErrorMessage(e)));
      }
    } finally {
      if (mounted) {
        _set(() => _isCopying = false);
      }
    }
  }

  /// Map instrument ID from source tenant to target tenant by name matching
  int? _mapInstrumentId(
    int sourceInstrumentId,
    List<Group> sourceGroups,
    List<Group> targetGroups,
  ) {
    // Reserved IDs remain unchanged
    if (sourceInstrumentId == 1 || sourceInstrumentId == 2) {
      return sourceInstrumentId;
    }

    final sourceGroup = sourceGroups.firstWhere(
      (g) => g.id == sourceInstrumentId,
      orElse: () => const Group(name: ''),
    );

    if (sourceGroup.name.isEmpty) return null;

    // Try exact name match first (case-insensitive)
    for (final targetGroup in targetGroups) {
      if (targetGroup.name.toLowerCase() == sourceGroup.name.toLowerCase()) {
        return targetGroup.id;
      }
    }

    // Try synonyms if available
    if (sourceGroup.synonyms != null && sourceGroup.synonyms!.isNotEmpty) {
      final synonyms = sourceGroup.synonyms!
          .split(',')
          .map((s) => s.trim().toLowerCase())
          .toList();

      for (final targetGroup in targetGroups) {
        if (synonyms.contains(targetGroup.name.toLowerCase())) {
          return targetGroup.id;
        }

        // Check target synonyms
        if (targetGroup.synonyms != null) {
          final targetSynonyms = targetGroup.synonyms!
              .split(',')
              .map((s) => s.trim().toLowerCase())
              .toList();

          if (targetSynonyms.contains(sourceGroup.name.toLowerCase()) ||
              synonyms.any((s) => targetSynonyms.contains(s))) {
            return targetGroup.id;
          }
        }
      }
    }

    return null;
  }
}
