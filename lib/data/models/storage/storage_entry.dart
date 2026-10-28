import 'package:freezed_annotation/freezed_annotation.dart';

part 'storage_entry.freezed.dart';

/// Eintrag der Dateiablage (Bucket `files`), relativ zum Tenant-Root.
@freezed
class StorageEntry with _$StorageEntry {
  const factory StorageEntry({
    required String name,

    /// Pfad relativ zum Tenant-Root (ohne `<tenantId>/`-Präfix)
    required String path,
    required bool isFolder,
    int? size,
    DateTime? updatedAt,
  }) = _StorageEntry;
}
