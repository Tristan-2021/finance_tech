# finance_tech

[![CI](https://github.com/Tristan-2021/finance_tech/actions/workflows/ci.yml/badge.svg)](https://github.com/Tristan-2021/finance_tech/actions/workflows/ci.yml)
![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-%5E3.9-0175C2?logo=dart&logoColor=white)
![Supabase](https://img.shields.io/badge/Backend-Supabase-3ECF8E?logo=supabase&logoColor=white)

An open-source digital banking app built with **Flutter**, organized as a
monorepo with **Pub Workspaces** and **Melos**. It's a reference for clean,
modular, testable mobile architecture in a fintech setting.

## Features

- **Onboarding**: 3-step sign-up, login and session handling.
- **Accounts**: balance, transaction history and recording a new transaction, against a Supabase backend.
- **Offline mode**: encrypted local cache so the app stays usable without a connection.
- **Personalized home**: Firebase Remote Config decides which blocks each customer segment sees, and in what order. Invalid config falls back to the last valid or the bundled layout.
- **Remittance converter**: EUR → USD using real ECB exchange rates.
- **Push notifications**: FCM permission, token handling and alerts.
- **Privacy-first telemetry**: Analytics, Crashlytics and Performance behind an allow-list filter, so no emails, names, balances or amounts are ever sent.

## Architecture

```
packages/
  app/                      Shell: composes the features and routes between screens
  core/
    core_errors/            Shared Failure type
    core_network/           Supabase client, retries and error mapping
    core_storage/           Encrypted local cache
    core_telemetry/         Analytics, Crashlytics and Performance with privacy filter
    core_ui/                Accessible theme and shared components
  features/
    feature_onboarding/     Sign-up, login and session
    feature_accounts/       Accounts, balance and transactions
    feature_personalization/ Segment-based home (Remote Config) and spending summary
    feature_exchange/       EUR→USD remittance converter (ECB rates)
    feature_notifications/  Push notifications (FCM)
documentacion/              Spec, deployment and AI-usage docs
```

Features depend on `core_*` packages, never on each other; the `app` package is
the only place where they are wired together.

Development follows **Trunk Based Development**: small commits straight to
`main`, with CI on every push.

## Quick start

Requirements: [Flutter](https://docs.flutter.dev/get-started/install),
[Melos](https://melos.invertase.dev) (`dart pub global activate melos 8.9.0`)
and, for a physical Android device, `adb`.

```bash
git clone https://github.com/Tristan-2021/finance_tech.git
cd finance_tech
melos bootstrap
```

### Option A: hosted demo backend

No local setup needed. With an Android device connected:

```bash
cd packages/app
flutter run -d <device-id> --dart-define=TELEMETRY_DEBUG=true \
  --dart-define=SUPABASE_URL=https://pzpolkpedpjtkaplulxc.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<publishable-anon-key>
```

The anon key is publishable and access is restricted by Row Level Security.
**Never use the `service_role` key in a client.**

### Option B: your own local backend

```bash
supabase start
supabase status                    # copy the publishable key
./scripts/create_demo_users.sh     # in the backend repo
```

Demo users (password `demo1234`): `joven@demo.com` and `adulto@demo.com`.

Android device:

```bash
adb reverse tcp:54421 tcp:54421    # repeat after unplugging or rebooting
cd packages/app
flutter run -d <device-id> \
  --dart-define=SUPABASE_URL=http://127.0.0.1:54421 \
  --dart-define=SUPABASE_ANON_KEY=<publishable-key>
```

macOS (no phone needed):

```bash
cd packages/app
flutter run -d macos \
  --dart-define=SUPABASE_URL=http://127.0.0.1:54421 \
  --dart-define=SUPABASE_ANON_KEY=<publishable-key>
```

Without the `--dart-define` values the app shows a "missing configuration"
screen listing the expected names. Per-platform details (Android emulator, iOS
simulator, LAN IP, common problems) are in
[`packages/app/README.md`](packages/app/README.md).

## Telemetry and personalization

**Telemetry** (`core_telemetry`) is off in debug builds. To watch events in
Firebase `DebugView`:

```bash
adb shell setprop debug.firebase.analytics.app com.bancointernacional.banco_app
cd packages/app
flutter run -d <device-id> --dart-define=TELEMETRY_DEBUG=true \
  --dart-define=SUPABASE_URL=http://127.0.0.1:54421 \
  --dart-define=SUPABASE_ANON_KEY=<publishable-key>
```

Events: `app_opened` and `block_viewed` (with `block_id`, `block_type`, `segment`).

**Personalized home** (`feature_personalization`): the `home_layout` Remote
Config parameter (JSON) defines the blocks per segment and their order. Edit it
in the Firebase console, publish, and the app applies it without a restart. An
example JSON and the parser rules are in
[`packages/features/feature_personalization/README.md`](packages/features/feature_personalization/README.md).

## Testing

From the repo root, the same commands CI runs:

```bash
melos exec -- flutter analyze
melos exec --diff=HEAD --include-dependents --dir-exists=test -- flutter test --reporter expanded --exclude-tags integration
```

The second command only tests changed packages and their dependents. To test
everything: `melos run test`.

Two extra suites run manually, outside CI:

```bash
# On-device E2E (fake use cases, no backend)
cd packages/app
flutter test integration_test/login_balance_test.dart -d <device-id>

# Integration against the local backend
melos exec --scope=banco_app -- flutter test --tags integration \
  --dart-define=SUPABASE_URL=http://127.0.0.1:54421 \
  --dart-define=SUPABASE_ANON_KEY=<publishable-key>
```

## Documentation

Most docs are written in Spanish.

- [`documentacion/sdd.md`](documentacion/sdd.md): app spec, requirement → verification traceability, and how spec-driven development was applied.
- [`documentacion/despliegue.md`](documentacion/despliegue.md): environments, secrets, CI, release and rollback.
- [`documentacion/ia/uso-de-ia.md`](documentacion/ia/uso-de-ia.md): how AI was used during development and its impact.
- [`documentacion/ia/prompt-maestro.md`](documentacion/ia/prompt-maestro.md): the master prompt that guided the agents (roles, architecture, contracts, workflow).
- [`packages/app/README.md`](packages/app/README.md): configuration, tests, how to contribute and the demo script.
- Every package has its own README with its API, decisions and telemetry events.

## Contributing

Contributions are welcome. Open an issue to discuss larger changes, keep commits
small, and make sure `flutter analyze` and the tests pass before pushing. See
[`packages/app/README.md`](packages/app/README.md) for the workflow.
