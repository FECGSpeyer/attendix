import 'package:attendix/core/providers/account_switch_providers.dart';
import 'package:attendix/core/services/account_switch/saved_account.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const dev = SavedAccount(userId: 'd', email: 'developer@attendix.de');
  const other = SavedAccount(userId: 'o', email: 'someone@example.com');

  test('account switch is unlocked only by the super developer', () {
    expect(isAccountSwitchUnlocked('someone@example.com', const [other]), isFalse);
    expect(isAccountSwitchUnlocked(null, const []), isFalse);
    expect(isAccountSwitchUnlocked('Developer@Attendix.de', const []), isTrue);
    // Stays unlocked for test accounts once the developer is remembered here.
    expect(isAccountSwitchUnlocked('someone@example.com', const [dev, other]), isTrue);
  });
}
