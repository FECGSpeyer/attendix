// TEST_TENANT: creates an isolated test tenant "Attendix Test" with one real
// account per role, so every screen can be tested as that role.
//
// Safety:
// * Uses only the public anon key + the normal login of the new test admin
//   account – no service-role key. Every write goes through RLS exactly like
//   the app does, so the script cannot do more than the app itself.
// * Every row written after the tenant insert is scoped to the NEW tenant id.
//   Existing tenants are never read or written. Only exception: one
//   `tenantUsers` row that adds YOUR account (--owner) as admin of the
//   test tenant, so you see it in your own tenant list.
// * Default is a dry run that only prints the plan. Writes need `--apply`.
// * A tenant `ATTX-TEST` left half-created by an aborted run (no groups
//   yet) is resumed; one that already has data stops the script.
// * Existing accounts are detected by a login and not signed up again, so a
//   re-run sends no new confirmation mails.
//
// Usage (repo root, .env with SUPABASE_URL + SUPABASE_ANON_KEY):
//   dart run tool/db/seed_test_tenant.dart --base you@example.com
//   dart run tool/db/seed_test_tenant.dart --base you@example.com \
//       --owner you@example.com --password '<shared password>' --apply
//
// Accounts are plus addresses of --base (you+admin@…, you+spieler@…), so
// all mails land in your inbox. If the project requires e-mail
// confirmation, the script stops after sign-up and asks you to confirm the
// mails; run it again with the same arguments afterwards.
//
// Removal: delete the tenant "Attendix Test" in the app (Verwaltung →
// Gruppe löschen) – the database cascades all rows of that tenant.
import 'dart:convert';
import 'dart:io';
import 'dart:math';

const _shortName = 'ATTX-TEST';
const _longName = 'Attendix Test';

/// Role values (lib/core/constants/enums.dart `Role`).
const _admin = 1,
    _player = 2,
    _viewer = 3,
    _helper = 4,
    _responsible = 5,
    _parent = 6,
    _applicant = 7,
    _voiceLeader = 8,
    _voiceLeaderHelper = 9;

/// AttendanceStatus values.
const _present = 1, _excused = 2, _late = 3, _absent = 4, _neutral = 0;

class _Account {
  const _Account(this.tag, this.role, this.firstName, this.lastName,
      {this.group, this.isPerson = true});
  final String tag;
  final int role;
  final String firstName;
  final String lastName;
  final String? group;

  /// Has an own `player` row (linked by appId).
  final bool isPerson;
}

const _accounts = [
  _Account('admin', _admin, 'Test', 'Dirigent', isPerson: false),
  _Account('verantwortlich', _responsible, 'Test', 'Verantwortlich',
      isPerson: false),
  _Account('beobachter', _viewer, 'Test', 'Beobachter', isPerson: false),
  _Account('helfer', _helper, 'Test', 'Helfer', group: 'Violine'),
  _Account('stimmfuehrer', _voiceLeader, 'Test', 'Stimmführer',
      group: 'Violine'),
  _Account('stimmhelfer', _voiceLeaderHelper, 'Test', 'Stimmhelfer',
      group: 'Cello'),
  _Account('spieler', _player, 'Test', 'Spieler', group: 'Flöte'),
  _Account('eltern', _parent, 'Test', 'Eltern', isPerson: false),
  _Account('bewerber', _applicant, 'Test', 'Bewerber', group: 'Trompete'),
];

const _groups = ['Violine', 'Viola', 'Cello', 'Flöte', 'Trompete'];

const _fakeMembers = [
  ('Anna', 'Becker', 'Violine'),
  ('Ben', 'Hoffmann', 'Violine'),
  ('Clara', 'Wagner', 'Violine'),
  ('David', 'Schulz', 'Viola'),
  ('Emma', 'Koch', 'Viola'),
  ('Felix', 'Richter', 'Cello'),
  ('Greta', 'Klein', 'Cello'),
  ('Hannes', 'Wolf', 'Flöte'),
  ('Ida', 'Neumann', 'Flöte'),
  ('Jonas', 'Schwarz', 'Trompete'),
  ('Klara', 'Zimmermann', 'Trompete'),
  ('Lukas', 'Braun', 'Viola'),
];

late String _url;
late String _anon;
var _token = '';
var _apply = false;

Future<void> main(List<String> args) async {
  final opts = _parseArgs(args);
  final base = opts['base'];
  if (base == null || !base.contains('@')) {
    _die('--base <deine@mail> fehlt');
  }
  _apply = opts.containsKey('apply');
  final owner = opts['owner'];
  final password = opts['password'] ?? _randomPassword();

  final env = _readEnv('.env');
  _url = env['SUPABASE_URL'] ?? _die('SUPABASE_URL fehlt in .env');
  _anon = env['SUPABASE_ANON_KEY'] ?? _die('SUPABASE_ANON_KEY fehlt in .env');

  final emails = {for (final a in _accounts) a.tag: _plus(base, a.tag)};
  _printPlan(emails, owner);
  if (!_apply) {
    stdout.writeln('\nDry run – nichts geschrieben. Mit --apply ausführen.');
    return;
  }

  // 1. Accounts. A password login tells whether an account already exists
  // (confirmed or not); only missing accounts are signed up, so a re-run
  // does not send new confirmation mails.
  final unconfirmed = <String>[];
  for (final a in _accounts) {
    final email = emails[a.tag]!;
    final probe = await _req('POST', '/auth/v1/token?grant_type=password',
        body: {'email': email, 'password': password}, auth: false);
    if (probe.status < 300) {
      stdout.writeln('Konto existiert (bestätigt): $email');
      continue;
    }
    if (probe.body.contains('email_not_confirmed') ||
        probe.body.toLowerCase().contains('not confirmed')) {
      unconfirmed.add(email);
      stdout.writeln('Konto existiert (noch unbestätigt): $email');
      continue;
    }
    final res = await _req('POST', '/auth/v1/signup',
        body: {'email': email, 'password': password}, auth: false);
    if (res.status >= 300) {
      _die('Sign-up $email: ${res.status} ${res.body}');
    }
    final data = res.json;
    final confirmed = data is Map &&
        (data['access_token'] != null ||
            (data['user'] is Map &&
                (data['user'] as Map)['email_confirmed_at'] != null));
    if (!confirmed) unconfirmed.add(email);
    stdout.writeln('Konto angelegt: $email');
  }

  // 2. Log in as the test admin.
  final login = await _req('POST', '/auth/v1/token?grant_type=password',
      body: {'email': emails['admin'], 'password': password}, auth: false);
  if (login.status >= 300) {
    if (unconfirmed.isNotEmpty) {
      stdout.writeln('\nBitte die Bestätigungsmails bestätigen:\n'
          '${unconfirmed.join('\n')}\nDanach das Skript erneut starten.');
      exit(2);
    }
    _die('Login ${emails['admin']}: ${login.status} ${login.body}');
  }
  _token = (login.json as Map)['access_token'] as String;
  final adminUserId = ((login.json as Map)['user'] as Map)['id'] as String;

  // 3. Existing test tenant? A tenant left half-created by an aborted run
  // (no groups yet) is resumed; a seeded one stops the script.
  final existing = (await _rest('GET',
      '/rest/v1/tenants?shortName=eq.$_shortName&select=id') as List);
  int? resumeId;
  if (existing.isNotEmpty) {
    resumeId = existing.first['id'] as int;
    final groups = await _rest('GET',
        '/rest/v1/instruments?tenantId=eq.$resumeId&select=id&limit=1');
    if ((groups as List).isNotEmpty) {
      _die('Testgruppe existiert schon mit Daten (id $resumeId). '
          'Erst in der App löschen.');
    }
    stdout.writeln('Halb angelegte Testgruppe gefunden (id $resumeId), '
        'setze fort.');
  }

  // 4. User ids of all accounts.
  final ids = <String, String>{'admin': adminUserId};
  for (final a in _accounts.skip(1)) {
    ids[a.tag] = await _userId(emails[a.tag]!);
  }
  final ownerId = owner == null ? null : await _userId(owner);

  // 5. Tenant + admins (same payload as TenantCreateRepository).
  final int tid;
  if (resumeId != null) {
    tid = resumeId;
  } else {
    final tenant = (await _rest('POST', '/rest/v1/tenants', {
      'shortName': _shortName,
      'longName': _longName,
      'type': 'orchestra',
      'maintainTeachers': false,
      'withExcuses': true,
      'betaProgram': true,
      'showHolidays': false,
      'timezone': 'Europe/Berlin',
      'parents': true,
      'showMembersList': true,
    }) as List)
        .first as Map;
    tid = tenant['id'] as int;
    stdout.writeln('Testgruppe angelegt: id $tid');
  }

  // Bulk inserts: PostgREST needs the same keys in every row (PGRST102).
  final present = {
    for (final r in (await _rest('GET',
            '/rest/v1/tenantUsers?tenantId=eq.$tid&select=userId') as List)
        .cast<Map>())
      r['userId'] as String,
  };
  final admins = [
    {'userId': ids['admin'], 'email': emails['admin']},
    if (ownerId != null && ownerId != ids['admin'])
      {'userId': ownerId, 'email': owner},
  ].where((r) => !present.contains(r['userId'])).toList();
  if (admins.isNotEmpty) {
    await _rest('POST', '/rest/v1/tenantUsers', [
      for (final r in admins)
        {'userId': r['userId'], 'role': _admin, 'tenantId': tid,
         'email': r['email'], 'parent_id': null},
    ]);
  }

  // 6. Groups + attendance types.
  final groupRows = (await _rest('POST', '/rest/v1/instruments', [
    {'name': 'Dirigent', 'tuning': 'C', 'clefs': ['g'], 'tenantId': tid,
     'maingroup': true, 'sort_order': 0},
    for (final (i, g) in _groups.indexed)
      {'name': g, 'tuning': 'C', 'clefs': ['g'], 'tenantId': tid,
       'maingroup': false, 'sort_order': i + 1},
  ]) as List)
      .cast<Map>();
  final groupId = {for (final g in groupRows) g['name'] as String: g['id']};

  Map<String, dynamic> type(String name, String color, List<int> statuses,
          int def, {bool hide = false, bool highlight = false,
          bool songs = false}) =>
      {
        'name': name, 'planning_title': name, 'color': color,
        'include_in_average': true, 'available_statuses': statuses,
        'default_status': def, 'hide_name': hide, 'highlight': highlight,
        'visible': true, 'manage_songs': songs, 'relevant_groups': <int>[],
        'tenant_id': tid, 'reminders': <int>[],
      };
  final typeRows = (await _rest('POST', '/rest/v1/attendance_types', [
    type('Probe', 'primary', [1, 2, 3, 4], _present, hide: true),
    type('Auftritt', 'secondary', [1, 2, 3, 4, 0], _neutral,
        highlight: true, songs: true),
    type('Sonstiges', 'tertiary', [1, 2, 3, 4, 0], _neutral),
  ]) as List)
      .cast<Map>();
  final probeType = typeRows.firstWhere((t) => t['name'] == 'Probe')['id'];
  final auftrittType =
      typeRows.firstWhere((t) => t['name'] == 'Auftritt')['id'];

  // 7. Parent record (needed before the parent's tenantUsers row).
  final parent = (await _rest('POST', '/rest/v1/parents', {
    'firstName': 'Test', 'lastName': 'Eltern', 'email': emails['eltern'],
    'appId': ids['eltern'], 'tenantId': tid,
  }) as List)
      .first as Map;

  // 8. tenantUsers for every other role.
  await _rest('POST', '/rest/v1/tenantUsers', [
    for (final a in _accounts.skip(1))
      if (!present.contains(ids[a.tag]))
      {
        'userId': ids[a.tag], 'role': a.role, 'tenantId': tid,
        'email': emails[a.tag],
        'parent_id': a.role == _parent ? parent['id'] : null,
      },
  ]);

  // 9. Persons: role accounts, fake members, child of the parent account.
  final joined = DateTime.now().subtract(const Duration(days: 400));
  Map<String, dynamic> person(String first, String last, String group,
          {String? appId, String? email, bool pending = false,
          bool leader = false, int? parentId}) =>
      {
        'firstName': first, 'lastName': last, 'instrument': groupId[group],
        'tenantId': tid, 'joined': _day(joined), 'history': <Object>[],
        'appId': appId, 'email': email, 'pending': pending,
        'isLeader': leader, 'parent_id': parentId, 'paused': false,
      };
  final persons = (await _rest('POST', '/rest/v1/player', [
    for (final a in _accounts.where((a) => a.isPerson))
      person(a.firstName, a.lastName, a.group!,
          appId: ids[a.tag], email: emails[a.tag],
          pending: a.role == _applicant,
          leader: a.role == _voiceLeader || a.role == _voiceLeaderHelper),
    for (final (f, l, g) in _fakeMembers) person(f, l, g),
    person('Mia', 'Eltern', 'Flöte', parentId: parent['id'] as int),
  ]) as List)
      .cast<Map>();
  final activeIds = [
    for (final p in persons)
      if (p['pending'] != true) p['id'] as int,
  ];

  // 10. Werk.
  await _rest('POST', '/rest/v1/songs', {
    'name': 'Testwerk – Ode an die Freude', 'number': 1, 'tenantId': tid,
    'withChoir': false, 'withOrchestra': true, 'withSolo': false,
  });

  // 11. Termine: 4 past with mixed answers, 3 upcoming open.
  final rnd = Random(42);
  final now = DateTime.now();
  final events = [
    for (final d in [-28, -21, -14, -7]) (d, probeType, ''),
    (7, probeType, ''),
    (14, auftrittType, 'Herbstkonzert'),
    (21, probeType, ''),
  ];
  for (final (offset, typeId, info) in events) {
    final day = DateTime(now.year, now.month, now.day + offset, 12);
    final att = (await _rest('POST', '/rest/v1/attendance', {
      'tenantId': tid, 'date': day.toUtc().toIso8601String(),
      'type_id': typeId, 'typeInfo': info, 'start_time': '19:00',
      'end_time': '21:00', 'notes': '', 'duration_days': 1,
      'save_in_history': true, 'is_org_plan': false,
    }) as List)
        .first as Map;
    final past = offset < 0;
    await _rest('POST', '/rest/v1/person_attendances', [
      for (final pid in activeIds)
        {
          'attendance_id': att['id'], 'person_id': pid, 'notes': '',
          'status': past
              ? [_present, _present, _present, _late, _excused, _absent]
                  [rnd.nextInt(6)]
              : (typeId == auftrittType ? _neutral : _present),
        },
    ]);
  }

  stdout.writeln('\nFertig. Testgruppe "$_longName" (id $tid).');
  stdout.writeln('Passwort für alle Testkonten: $password');
  for (final a in _accounts) {
    stdout.writeln('  ${_roleName(a.role).padRight(18)} ${emails[a.tag]}');
  }
}

void _printPlan(Map<String, String> emails, String? owner) {
  stdout.writeln('Plan (${_apply ? 'APPLY' : 'dry run'}):');
  stdout.writeln('- neue Gruppe "$_longName" ($_shortName), Typ Orchester');
  if (owner != null) stdout.writeln('- $owner wird Admin der Testgruppe');
  stdout.writeln('- Stimmgruppen: Dirigent, ${_groups.join(', ')}');
  stdout.writeln('- Termintypen: Probe, Auftritt, Sonstiges');
  stdout.writeln('- ${_fakeMembers.length} Fantasie-Mitglieder + Kind '
      '"Mia Eltern" für das Eltern-Konto');
  stdout.writeln('- 1 Werk, 4 vergangene + 3 kommende Termine');
  stdout.writeln('- Konten:');
  for (final a in _accounts) {
    stdout.writeln('    ${_roleName(a.role).padRight(18)} ${emails[a.tag]}');
  }
}

String _roleName(int r) => switch (r) {
      _admin => 'Admin/Dirigent',
      _responsible => 'Verantwortlicher',
      _viewer => 'Beobachter',
      _helper => 'Helfer',
      _voiceLeader => 'Stimmführer',
      _voiceLeaderHelper => 'Stimmführer-Helfer',
      _player => 'Spieler',
      _parent => 'Elternteil',
      _applicant => 'Bewerber',
      _ => '?',
    };

Future<String> _userId(String email) async {
  final res = await _rest('POST', '/rest/v1/rpc/get_user_id_by_email',
      {'email': email.toLowerCase()});
  if (res is List && res.isNotEmpty) return res.first['id'] as String;
  _die('Kein Konto für $email gefunden');
}

String _plus(String base, String tag) {
  final at = base.indexOf('@');
  return '${base.substring(0, at)}+attx-$tag${base.substring(at)}'
      .toLowerCase();
}

String _day(DateTime d) => d.toIso8601String().substring(0, 10);

String _randomPassword() {
  const chars = 'abcdefghjkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  final r = Random.secure();
  return 'Test-${List.generate(10, (_) => chars[r.nextInt(chars.length)]).join()}';
}

class _Res {
  _Res(this.status, this.body);
  final int status;
  final String body;
  dynamic get json => body.isEmpty ? null : jsonDecode(body);
}

Future<_Res> _req(String method, String path,
    {Object? body, bool auth = true}) async {
  final client = HttpClient();
  try {
    final req = await client.openUrl(method, Uri.parse('$_url$path'));
    req.headers
      ..set('apikey', _anon)
      ..set('Authorization', 'Bearer ${auth ? _token : _anon}')
      ..set('Content-Type', 'application/json')
      ..set('Prefer', 'return=representation');
    if (body != null) req.add(utf8.encode(jsonEncode(body)));
    final res = await req.close();
    return _Res(res.statusCode, await utf8.decodeStream(res));
  } finally {
    client.close();
  }
}

Future<dynamic> _rest(String method, String path, [Object? body]) async {
  final res = await _req(method, path, body: body);
  if (res.status >= 300) _die('$method $path: ${res.status} ${res.body}');
  return res.json;
}

Map<String, String> _readEnv(String path) {
  final f = File(path);
  if (!f.existsSync()) _die('$path fehlt (im Repo-Root ausführen)');
  return {
    for (final line in f.readAsLinesSync())
      if (line.contains('=') && !line.trimLeft().startsWith('#'))
        line.substring(0, line.indexOf('=')).trim():
            line.substring(line.indexOf('=') + 1).trim().replaceAll(
                RegExp(r'''^['"]|['"]$'''), ''),
  };
}

Map<String, String> _parseArgs(List<String> args) {
  final out = <String, String>{};
  for (var i = 0; i < args.length; i++) {
    final a = args[i];
    if (!a.startsWith('--')) continue;
    final key = a.substring(2);
    if (i + 1 < args.length && !args[i + 1].startsWith('--')) {
      out[key] = args[++i];
    } else {
      out[key] = '';
    }
  }
  return out;
}

Never _die(String msg) {
  stderr.writeln('FEHLER: $msg');
  exit(1);
}
