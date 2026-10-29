import 'package:attendix/features/settings/presentation/widgets/calendar_subscription_dialog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('md calendar alert: 280 on phones, up to 560 from 768px (Ionic)', () {
    expect(mdCalendarAlertContentWidth(393), 224);
    expect(mdCalendarAlertContentWidth(767), 224);
    expect(mdCalendarAlertContentWidth(768), 560 - 48);
    expect(mdCalendarAlertContentWidth(1440), 560 - 48);
  });
}
