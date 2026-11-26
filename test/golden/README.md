# Golden images

Pictures of whole pages in `goldens/`, rendered by widget tests with the
app's real fonts and icons. A test fails when a page no longer looks like its
picture. They catch what behaviour tests do not see: spacing, colours, a
missing button, a widget that moved.

| File | Pages |
|---|---|
| `pages_beta_test.dart` | Main app pages (`beta_*`) |

## After an intended change

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
    const RdPeoplePage(),
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
- Keep it few: one picture per page that matters, not one per state. A state
  belongs into a behaviour test.
