import 'package:attendix/core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Test for color parsing functionality.
/// These tests verify that all named colors are correctly parsed.
void main() {
  group('Color Parsing', () {
    // This simulates the _parseColor function from attendance_create_page.dart
    Color parseColorCreatePage(String? colorStr) {
      if (colorStr == null || colorStr.isEmpty) return AppColors.primary;

      try {
        if (colorStr.startsWith('#')) {
          return Color(int.parse('FF${colorStr.substring(1)}', radix: 16));
        }
        switch (colorStr.toLowerCase()) {
          case 'primary':
            return AppColors.primary;
          case 'secondary':
            return AppColors.secondary;
          case 'success':
            return AppColors.success;
          case 'warning':
            return AppColors.warning;
          case 'danger':
            return AppColors.danger;
          case 'tertiary':
            return AppColors.tertiary;
          case 'rosa':
            return Colors.pink;
          case 'mint':
            return Colors.teal;
          case 'orange':
            return Colors.orange;
          default:
            return AppColors.primary;
        }
      } catch (_) {
        return AppColors.primary;
      }
    }

    // This simulates the _parseColor function from multi_date_calendar.dart
    Color parseColorCalendar(String? colorStr) {
      if (colorStr == null || colorStr.isEmpty) return AppColors.primary;

      try {
        if (colorStr.startsWith('#')) {
          return Color(int.parse('FF${colorStr.substring(1)}', radix: 16));
        }
        switch (colorStr.toLowerCase()) {
          case 'primary':
            return AppColors.primary;
          case 'secondary':
            return AppColors.secondary;
          case 'success':
            return AppColors.success;
          case 'warning':
            return AppColors.warning;
          case 'danger':
            return AppColors.danger;
          case 'tertiary':
            return AppColors.tertiary;
          case 'rosa':
            return const Color(0xFFE91E63);
          case 'mint':
            return Colors.teal;
          case 'orange':
            return Colors.orange;
          default:
            return AppColors.primary;
        }
      } catch (_) {
        return AppColors.primary;
      }
    }

    test('parseColorCreatePage should parse all named colors correctly', () {
      // These should NOT be primary (blue)
      expect(parseColorCreatePage('rosa'), isNot(AppColors.primary),
          reason: 'rosa should not fall back to primary');
      expect(parseColorCreatePage('mint'), isNot(AppColors.primary),
          reason: 'mint should not fall back to primary');
      expect(parseColorCreatePage('orange'), isNot(AppColors.primary),
          reason: 'orange should not fall back to primary');
      expect(parseColorCreatePage('secondary'), isNot(AppColors.primary),
          reason: 'secondary should not fall back to primary');

      // Verify correct colors
      expect(parseColorCreatePage('rosa'), Colors.pink);
      expect(parseColorCreatePage('mint'), Colors.teal);
      expect(parseColorCreatePage('orange'), Colors.orange);
      expect(parseColorCreatePage('secondary'), AppColors.secondary);
      expect(parseColorCreatePage('primary'), AppColors.primary);
      expect(parseColorCreatePage('success'), AppColors.success);
      expect(parseColorCreatePage('warning'), AppColors.warning);
      expect(parseColorCreatePage('danger'), AppColors.danger);
      expect(parseColorCreatePage('tertiary'), AppColors.tertiary);
    });

    test('parseColorCalendar should parse all named colors correctly', () {
      // These should NOT be primary (blue)
      expect(parseColorCalendar('mint'), isNot(AppColors.primary),
          reason: 'mint should not fall back to primary');
      expect(parseColorCalendar('orange'), isNot(AppColors.primary),
          reason: 'orange should not fall back to primary');
      expect(parseColorCalendar('secondary'), isNot(AppColors.primary),
          reason: 'secondary should not fall back to primary');

      // Verify correct colors
      expect(parseColorCalendar('rosa'), const Color(0xFFE91E63));
      expect(parseColorCalendar('mint'), Colors.teal);
      expect(parseColorCalendar('orange'), Colors.orange);
      expect(parseColorCalendar('secondary'), AppColors.secondary);
    });

    test('parseColor should handle hex colors', () {
      expect(parseColorCreatePage('#FF5733'), const Color(0xFFFF5733));
      expect(parseColorCalendar('#00FF00'), const Color(0xFF00FF00));
    });

    test('parseColor should handle null and empty strings', () {
      expect(parseColorCreatePage(null), AppColors.primary);
      expect(parseColorCreatePage(''), AppColors.primary);
      expect(parseColorCalendar(null), AppColors.primary);
      expect(parseColorCalendar(''), AppColors.primary);
    });

    test('parseColor should handle unknown colors with default', () {
      expect(parseColorCreatePage('unknowncolor'), AppColors.primary);
      expect(parseColorCalendar('unknowncolor'), AppColors.primary);
    });
  });
}
