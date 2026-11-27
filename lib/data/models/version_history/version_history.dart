// Model classes for version history feature

/// Represents a single version entry in the version history
class VersionEntry {
  final String version;
  final String? date;
  final List<String> changes;

  const VersionEntry({
    required this.version,
    this.date,
    required this.changes,
  });

  factory VersionEntry.fromJson(Map<String, dynamic> json) {
    return VersionEntry(
      version: json['version'] as String,
      date: json['date'] as String?,
      changes: (json['changes'] as List).cast<String>(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      if (date != null) 'date': date,
      'changes': changes,
    };
  }
}

/// Represents the complete version history
class VersionHistory {
  final List<VersionEntry> versions;

  const VersionHistory({required this.versions});

  factory VersionHistory.fromJson(Map<String, dynamic> json) {
    return VersionHistory(
      versions: (json['versions'] as List)
          .map((v) => VersionEntry.fromJson(v as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'versions': versions.map((v) => v.toJson()).toList(),
    };
  }
}
