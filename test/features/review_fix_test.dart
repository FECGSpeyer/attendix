import 'package:attendix/core/constants/enums.dart';
import 'package:attendix/core/providers/attendance_providers.dart';
import 'package:attendix/core/providers/tenant_providers.dart';
import 'package:attendix/core/utils/date_helper.dart';
import 'package:attendix/features/attendance/presentation/pages/attendance_detail_page.dart';
import 'package:attendix/features/auth/data/auth_flow_service.dart';
import 'package:attendix/features/auth/data/auth_link_listener.dart';
import 'package:attendix/features/auth/data/auth_redirect_path.dart';
import 'package:attendix/features/registration/data/providers/registration_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show OtpType;

/// REVIEW_FIX: unit tests for the review fixes.
void main() {
  group('reactivationPlayerData (HIGH1)', () {
    test('writes the complete new registration data like Ionic (PARITY_A D3)', () {
      final data = reactivationPlayerData({
        'firstName': 'Max',
        'history': <dynamic>[],
        'joined': '2026-01-01',
        'playsSince': '2026-01-01',
        'pending': true,
      });
      expect(data['history'], isEmpty);
      expect(data['joined'], '2026-01-01');
      expect(data['playsSince'], '2026-01-01');
      expect(data['left'], isNull);
      expect(data.containsKey('left'), isTrue);
      expect(data['firstName'], 'Max');
      expect(data['pending'], isTrue);
    });
  });

  group('attendanceListTypeFilterProvider (MED3)', () {
    test('resets when the tenant changes', () {
      final tenant = StateProvider<int?>((ref) => 1);
      final container = ProviderContainer(overrides: [
        currentTenantIdProvider.overrideWith((ref) => ref.watch(tenant)),
      ]);
      addTearDown(container.dispose);

      container.read(attendanceListTypeFilterProvider.notifier).state = 'abc';
      expect(container.read(attendanceListTypeFilterProvider), 'abc');

      container.read(tenant.notifier).state = 2;
      expect(container.read(attendanceListTypeFilterProvider), isNull);
    });
  });

  group('canMutateAttendanceDetail (MED5)', () {
    test('only admin and responsible may mutate', () {
      expect(canMutateAttendanceDetail(Role.admin), isTrue);
      expect(canMutateAttendanceDetail(Role.responsible), isTrue);
      expect(canMutateAttendanceDetail(Role.viewer), isFalse);
      expect(canMutateAttendanceDetail(Role.helper), isFalse);
      expect(canMutateAttendanceDetail(Role.voiceLeaderHelper), isFalse);
      expect(canMutateAttendanceDetail(Role.player), isFalse);
    });
  });

  group('otpTypeForLink (LOW7)', () {
    OtpType typeOf(String type) => otpTypeForLink(AuthLink.parse(
        Uri.parse('https://attendix.de/login?token_hash=abc&type=$type')));

    test('maps the link type', () {
      expect(typeOf('recovery'), OtpType.recovery);
      expect(typeOf('invite'), OtpType.invite);
      expect(typeOf('magiclink'), OtpType.magiclink);
      expect(typeOf('email_change'), OtpType.emailChange);
      expect(typeOf('signup'), OtpType.signup);
    });

    test('legacy reset links without type are recovery', () {
      final link = AuthLink.parse(
          Uri.parse('https://attendix.de/resetPassword?token_hash=abc'));
      expect(otpTypeForLink(link), OtpType.recovery);
    });
  });

  group('appBasePath (LOW8)', () {
    test('strips trailing auth redirect paths', () {
      expect(appBasePath('/resetPassword'), '/');
      expect(appBasePath('/login'), '/');
      expect(appBasePath('/app/login'), '/app/');
      expect(appBasePath('/'), '/');
      expect(appBasePath(''), '/');
    });
  });

  group('authLinkErrorText (conv 11)', () {
    test('maps English Supabase errors to German without decoding twice', () {
      final link = AuthLink.parse(Uri.parse(
          'https://attendix.de/login#error=access_denied&error_code=otp_expired'
          '&error_description=Email+link+is+invalid+or+has+expired%25'));
      expect(authLinkErrorText(link),
          'Der Bestätigungslink ist ungültig oder abgelaufen.');
    });
  });

  group('DateHelper (conv 18)', () {
    test('isoDay and hhmm', () {
      expect(DateHelper.isoDay(DateTime(2026, 3, 7, 23, 59)), '2026-03-07');
      expect(DateHelper.hhmm('19:00:00'), '19:00');
      expect(DateHelper.hhmm('9:00'), '9:00');
    });
  });
}
