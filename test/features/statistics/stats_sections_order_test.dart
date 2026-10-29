import 'package:attendix/features/statistics/presentation/pages/statistics_page.dart';
import 'package:flutter_test/flutter_test.dart';

/// ASTRA_TEACH_STATS: Ionic stats.page.html shows the overview, members,
/// demography and organisation independently of Termine in the period.
void main() {
  test('with Termine: all sections in Ionic order', () {
    expect(statsSectionsFor(hasAttendances: true), const [
      StatsSection.overview,
      StatsSection.trend,
      StatsSection.statusDistribution,
      StatsSection.top20,
      StatsSection.perInstrument,
      StatsSection.unexcused,
      StatsSection.members,
      StatsSection.ageDistribution,
      StatsSection.avgAgeInstrument,
      StatsSection.organisation,
    ]);
  });

  test('without Termine: only the attendance charts are replaced', () {
    expect(statsSectionsFor(hasAttendances: false), const [
      StatsSection.overview,
      StatsSection.noData,
      StatsSection.members,
      StatsSection.ageDistribution,
      StatsSection.avgAgeInstrument,
      StatsSection.organisation,
    ]);
  });

  test('while loading: members/demography/organisation stay visible', () {
    final sections = statsSectionsFor(hasAttendances: false, loaded: false);
    expect(sections.first, StatsSection.noData);
    expect(sections, isNot(contains(StatsSection.overview)));
    expect(
        sections,
        containsAllInOrder(const [
          StatsSection.members,
          StatsSection.ageDistribution,
          StatsSection.avgAgeInstrument,
          StatsSection.organisation,
        ]));
  });
}
