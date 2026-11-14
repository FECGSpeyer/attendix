import 'package:attendix/features/messages/presentation/pages/auto_message_rule_page.dart';
import 'package:flutter_test/flutter_test.dart';

/// NACHTEST-A-10 (EINST-60): a numeric id is never a rule – the page leaves
/// like for an unknown id instead of querying (HTTP 400) and showing an
/// empty "Neue Regel" form.
void main() {
  test('only UUIDs count as auto message rule ids', () {
    expect(isAutoMessageRuleId('99999999'), isFalse);
    expect(isAutoMessageRuleId('new'), isFalse);
    expect(isAutoMessageRuleId('00000000-0000-4000-8000-000000000000'), isTrue);
  });
}
