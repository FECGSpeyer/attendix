/// Song history entry model
class HistoryEntry {
  final int? id;
  final int songId;
  final String? songName;
  final String? songNumber;
  final int? personId;
  final String? conductorName;
  final String? otherConductor;
  final String date;
  final int? attendanceId;
  final int count;

  HistoryEntry({
    this.id,
    required this.songId,
    this.songName,
    this.songNumber,
    this.personId,
    this.conductorName,
    this.otherConductor,
    required this.date,
    this.attendanceId,
    this.count = 0,
  });

  factory HistoryEntry.fromJson(Map<String, dynamic> json) => HistoryEntry(
        id: json['id'] as int?,
        songId: json['songId'] as int,
        songName: json['name'] as String?,
        songNumber: json['number']?.toString(),
        personId: json['person_id'] as int?,
        conductorName: json['conductorName'] as String?,
        otherConductor: json['otherConductor'] as String?,
        date: json['date'] as String? ?? DateTime.now().toIso8601String(),
        attendanceId: json['attendance_id'] as int?,
        count: json['count'] as int? ?? 0,
      );

  String get displayConductor => conductorName ?? otherConductor ?? 'Unbekannt';

  String get formattedDate {
    final dateObj = DateTime.tryParse(date);
    if (dateObj == null) return date;
    return '${dateObj.day.toString().padLeft(2, '0')}.${dateObj.month.toString().padLeft(2, '0')}.${dateObj.year}';
  }
}
