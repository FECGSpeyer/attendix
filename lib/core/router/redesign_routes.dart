// REDESIGN: routes of the new design (Beta) and the switch the router and
// the start-page logic read. The Beta flag is stored on the device only
// (redesign_providers.dart); this mirror lets pure functions such as
// `homeRouteFor` pick the new start page without Riverpod.

class RedesignRoutes {
  RedesignRoutes._();

  /// Tab "Heute" (start page of the new design for every role).
  static const String today = '/heute';

  /// Tab "Ich".
  static const String me = '/ich';

  /// Ich › Darstellung (Farbwelt, hell/dunkel).
  static const String appearance = '/ich/darstellung';

  /// True while the new design is switched on (set by
  /// `RedesignSettingsNotifier`).
  static bool active = false;

  /// Routes that only exist in the new design.
  static bool isRedesignRoute(String location) =>
      location == today ||
      location == me ||
      location.startsWith('$today/') ||
      location.startsWith('$me/');
}
