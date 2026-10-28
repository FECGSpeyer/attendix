import 'package:flutter/material.dart';
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

/// Sheet for copying a song to another tenant
class CopyToTenantSheet extends ConsumerStatefulWidget {
  final Song song;
  final List<Tenant> availableTenants;

  const CopyToTenantSheet({
    super.key,
    required this.song,
    required this.availableTenants,
  });

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

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Header
            AppBar(
              title: Text(context.l10n.songsCopySong),
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
              automaticallyImplyLeading: false,
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
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.business),
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
                              const Icon(Icons.info_outline, color: AppColors.info),
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
                                      const Icon(Icons.insert_drive_file,
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
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.copy),
                    label: Text(_isCopying ? context.l10n.shiftsFlutterCopyingShort : context.l10n.songsCopy),
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

  Future<void> _copySong() async {
    if (DemoGuard.blocked()) return; // DEMO_GUARD
    final l10n = context.l10n;
    setState(() {
      _isCopying = true;
      _progressMessage = l10n.songsCopying;
    });

    try {
      // Get source groups for instrument mapping
      final sourceGroupsAsync = ref.read(groupsProvider);
      final sourceGroups = sourceGroupsAsync.valueOrNull ?? [];

      // Get target groups
      setState(() => _progressMessage = l10n.songsFlutterLoadingTargetGroups);
      final supabase = ref.read(supabaseClientProvider);
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
      setState(() => _progressMessage = l10n.songsFlutterCreatingInTarget);

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
        'category_ids': <String>[],
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
        final songFileService = ref.read(songFileServiceProvider);
        final fileCount = files.length;

        for (var i = 0; i < fileCount; i++) {
          final file = files[i];
          setState(() => _progressMessage =
              l10n.songsCopyingFile(i + 1, fileCount));

          // Download file bytes
          final bytes = await songFileService.downloadFileBytes(file.url);
          if (bytes == null) continue;

          // Map instrument ID
          final mappedInstrumentId = file.instrumentId != null
              ? instrumentMapping[file.instrumentId]
              : null;

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

        // Update instrument_ids on the new song based on uploaded files
        final newInstrumentIds = widget.song.files!
            .where((f) => f.instrumentId != null && f.instrumentId! > 2)
            .map((f) => instrumentMapping[f.instrumentId])
            .where((id) => id != null)
            .toSet()
            .toList();

        if (newInstrumentIds.isNotEmpty) {
          await supabase
              .from('songs')
              .update({'instrument_ids': newInstrumentIds})
              .eq('id', newSongId)
              .eq('tenantId', _targetTenantId);
        }
      }

      if (mounted) {
        ToastHelper.showSuccess(context, l10n.songsCopied);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ToastHelper.showError(context, l10n.songsCopyFailed(e));
      }
    } finally {
      if (mounted) {
        setState(() => _isCopying = false);
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
