import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:freezed_annotation/freezed_annotation.dart';
import '../../l10n/l10n.dart';

part 'holiday_service.freezed.dart';
part 'holiday_service.g.dart';

/// Holiday data containing public and school holidays
@freezed
class HolidayData with _$HolidayData {
  const factory HolidayData({
    @Default([]) List<Holiday> publicHolidays,
    @Default([]) List<Holiday> schoolHolidays,
  }) = _HolidayData;

  factory HolidayData.fromJson(Map<String, dynamic> json) =>
      _$HolidayDataFromJson(json);
}

/// Single holiday entry
@freezed
class Holiday with _$Holiday {
  const factory Holiday({
    required String id,
    required String name,
    required DateTime startDate,
    required DateTime endDate,
    @Default(false) bool isPast,
  }) = _Holiday;

  factory Holiday.fromJson(Map<String, dynamic> json) =>
      _$HolidayFromJson(json);
}

/// Service to fetch holidays from OpenHolidaysAPI
class HolidayService {
  static const _baseUrl = 'https://openholidaysapi.org';

  /// German region codes for OpenHolidaysAPI
  /// Maps region abbreviations to full subdivision codes
  static const Map<String, String> regionCodes = {
    'BW': 'DE-BW', // Baden-Württemberg
    'BY': 'DE-BY', // Bayern
    'BE': 'DE-BE', // Berlin
    'BB': 'DE-BB', // Brandenburg
    'HB': 'DE-HB', // Bremen
    'HH': 'DE-HH', // Hamburg
    'HE': 'DE-HE', // Hessen
    'MV': 'DE-MV', // Mecklenburg-Vorpommern
    'NI': 'DE-NI', // Niedersachsen
    'NW': 'DE-NW', // Nordrhein-Westfalen
    'RP': 'DE-RP', // Rheinland-Pfalz
    'SL': 'DE-SL', // Saarland
    'SN': 'DE-SN', // Sachsen
    'ST': 'DE-ST', // Sachsen-Anhalt
    'SH': 'DE-SH', // Schleswig-Holstein
    'TH': 'DE-TH', // Thüringen
  };

  final http.Client _client;

  HolidayService({http.Client? client}) : _client = client ?? http.Client();

  /// Fetches public and school holidays for a German region
  /// [region] - German state abbreviation (e.g., 'BY', 'NW', 'HE')
  Future<HolidayData> getHolidays(String region) async {
    final subdivisionCode = regionCodes[region.toUpperCase()] ?? 'DE-BY';
    final now = DateTime.now();
    final startOfYear = DateTime(now.year, 1, 1);
    final endOfNextYear = DateTime(now.year + 1, 12, 31);

    final results = await Future.wait([
      _fetchPublicHolidays(subdivisionCode, startOfYear, endOfNextYear),
      _fetchSchoolHolidays(subdivisionCode, startOfYear, endOfNextYear),
    ]);

    return HolidayData(
      publicHolidays: results[0],
      schoolHolidays: results[1],
    );
  }

  Future<List<Holiday>> _fetchPublicHolidays(
    String subdivisionCode,
    DateTime validFrom,
    DateTime validTo,
  ) async {
    try {
      final uri = Uri.parse('$_baseUrl/PublicHolidays').replace(
        queryParameters: {
          'countryIsoCode': 'DE',
          'subdivisionCode': subdivisionCode,
          'validFrom': _formatDate(validFrom),
          'validTo': _formatDate(validTo),
          'languageIsoCode': 'DE',
        },
      );

      final response = await _client.get(uri);

      if (response.statusCode != 200) {
        return [];
      }

      final List<dynamic> data = json.decode(response.body);
      final now = DateTime.now();

      return data.map((item) {
        final startDate = DateTime.parse(item['startDate'] as String);
        final endDate = DateTime.parse(item['endDate'] as String);
        final names = item['name'] as List<dynamic>;
        // BL-012: Use firstOrNull for clearer null-safety
        final nameEntry = names.cast<Map<String, dynamic>?>().firstOrNull;
        final name = nameEntry?['text'] as String? ?? l10nWithoutContext.coreFlutterHoliday;

        return Holiday(
          id: item['id']?.toString() ?? '${startDate.toIso8601String()}_$name',
          name: name,
          startDate: startDate,
          endDate: endDate,
          isPast: endDate.isBefore(now),
        );
      }).toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<Holiday>> _fetchSchoolHolidays(
    String subdivisionCode,
    DateTime validFrom,
    DateTime validTo,
  ) async {
    try {
      final uri = Uri.parse('$_baseUrl/SchoolHolidays').replace(
        queryParameters: {
          'countryIsoCode': 'DE',
          'subdivisionCode': subdivisionCode,
          'validFrom': _formatDate(validFrom),
          'validTo': _formatDate(validTo),
          'languageIsoCode': 'DE',
        },
      );

      final response = await _client.get(uri);

      if (response.statusCode != 200) {
        return [];
      }

      final List<dynamic> data = json.decode(response.body);
      final now = DateTime.now();

      return data.map((item) {
        final startDate = DateTime.parse(item['startDate'] as String);
        final endDate = DateTime.parse(item['endDate'] as String);
        final names = item['name'] as List<dynamic>;
        // BL-012: Use firstOrNull for clearer null-safety
        final nameEntry = names.cast<Map<String, dynamic>?>().firstOrNull;
        final name = nameEntry?['text'] as String? ?? l10nWithoutContext.coreFlutterSchoolHolidays;

        return Holiday(
          id: item['id']?.toString() ?? '${startDate.toIso8601String()}_$name',
          name: name,
          startDate: startDate,
          endDate: endDate,
          isPast: endDate.isBefore(now),
        );
      }).toList();
    } catch (e) {
      return [];
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
