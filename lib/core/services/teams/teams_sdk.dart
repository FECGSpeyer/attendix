// TEAMS: platform bridge to the Microsoft Teams JS SDK (@microsoft/teams-js).
//
// The real implementation only exists on the web (Teams embeds the PWA in an
// iframe tab). Everywhere else [createTeamsSdk] returns a no-op bridge, so the
// app never detects Teams and all Teams features stay disabled.
export 'teams_sdk_stub.dart'
    if (dart.library.js_interop) 'teams_sdk_web.dart';
