// Gemeinde App: "unveröffentlicht" hides an ORG plan for viewers.
import 'package:attendix/data/models/plan/plan.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('raw plan JSON', () {
    expect(isPlanPublished(<String, dynamic>{'fields': []}), isTrue);
    expect(isPlanPublished(<String, dynamic>{'unpublished': false}), isTrue);
    expect(isPlanPublished(<String, dynamic>{'unpublished': true}), isFalse);
  });

  test('Plan model keeps the flag from JSON', () {
    final plan = Plan.fromJson(<String, dynamic>{'unpublished': true});
    expect(plan.unpublished, isTrue);
    expect(isPlanPublished(plan), isFalse);
    expect(isPlanPublished(Plan.fromJson(<String, dynamic>{})), isTrue);
  });

  test('no plan is not shown', () {
    expect(isPlanPublished(null), isFalse);
  });
}
