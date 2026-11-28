# Golden images

Pictures of whole pages, subpages, and modals in `goldens/` (24 total),
rendered by widget tests with the app's real fonts and icons. A test fails
when a screen no longer looks like its picture. They catch what behaviour
tests do not see: spacing, colours, a missing button, a widget that moved.

| File | Coverage | Count |
|---|---|---|
| `pages_beta_test.dart` | Main app pages (`beta_*`) | 8 |
| `extended_goldens_test.dart` | Dark Mode (`beta_dark_*`), Desktop Split-Views (`beta_desktop_*`), Subpages & Forms (`beta_page_*`), Sheets & Modals (`beta_sheet_*`) | 16 |

## After an intended change

### Option 1: 1-click GitHub Actions generator (recommended on macOS/Windows)

Run the manual workflow **Update Linux Goldens** (`.github/workflows/update-goldens.yml`)
on your branch via **Actions → Update Linux Goldens → Run workflow**:

- Checks out the selected branch on `ubuntu-latest` with Flutter `3.47.9`.
- Runs `flutter test test/golden --update-goldens`.
- Uploads all `test/golden/goldens/*.png` files as the `updated-linux-goldens` artifact (7 days retention).

Download the artifact, copy the updated PNGs into `test/golden/goldens/`, review
them, and commit them with your change.

### Option 2: Locally on Linux

```bash
flutter test test/golden --update-goldens
```

Look at the changed pictures, then commit them with the change. On the pull
request the workflow **Bildvergleich** posts them as before and after.

The pictures are made and compared **on Linux only** (CI and the cloud
containers), because text is drawn slightly differently on every operating
system. On macOS and Windows the tests run but do not compare. When CI fails
on a picture, the test job uploads an artifact `golden-failures-<n>` with the
expected picture, the actual one and the difference.

## Adding a page

```dart
testWidgets('Mitglieder', (tester) async {
  await pumpGolden(
    tester,
    const RdMembersPage(),
    look: GoldenLook.beta,
    path: '/mitglieder',
    shell: _shell,
    overrides: [...worldOverrides(), playersProvider.overrideWith((ref) async => worldPersons)],
  );
  await expectGolden(tester, GoldenLook.beta, 'mitglieder');
});
```

- `support/golden_world.dart` is the one small made-up group all pages show
  (Stadtorchester, ten people, five Termine). Use it instead of new data.
- Pages get their data through provider overrides. What is not overridden
  talks to an empty backend (`support/golden_backend.dart`) and gets empty
  lists; `tables:` fills single tables.
- **No dates that move.** The app reads the clock directly, so the world's
  Termine lie in 2099 and 2024. If a page prints today's date, swap that text
  with `expectGolden(..., replace: {...})`.
- **Modals & bottom sheets.** Trigger the sheet from inside `MaterialApp` (e.g.
  via a host `Scaffold`) and wait with `settle(tester)` so `find.byType(MaterialApp)`
  captures the modal overlay.
- Keep it few: one picture per page or modal that matters, not one per state. A
  state belongs into a behaviour test.
