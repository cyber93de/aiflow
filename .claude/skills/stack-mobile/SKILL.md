---
name: stack-mobile
description: Architecture, quality and test checklist for mobile apps — cross-platform with Dart/Flutter, and native with Kotlin on Android or Swift/Objective-C on iOS. Covers layering and state management, the platform lifecycle, offline/sync and on-device storage, permissions and secure credential storage, store-release constraints, and the mobile-specific test pyramid. Invoke when the project contains a Flutter/Dart app, an Android module (Gradle, Jetpack Compose, Kotlin), or an iOS target (Xcode, SwiftUI/UIKit), or on explicit request — "mobile", "Flutter", "Android", "iOS", "Kotlin", "Swift", "app".
---

# Mobile — Flutter/Dart · Kotlin/Android · Swift/iOS

Applies `AGENTS.md` §2 (architecture rules) and §3a (quality gates) to a client that runs on
someone else's device, loses the network, gets killed by the OS, and ships through a review queue.

## Layering (§2a, mobile dialect)

```
UI            (Widgets / Composables / SwiftUI Views — no business rules, no I/O)
   ↓
presentation  (ViewModel / Bloc / Cubit / Presenter — state + intent, no framework types leaking up)
   ↓
domain        (use cases, entities — pure, no Flutter/Android/UIKit imports)
   ↑
data          (repositories → remote DTOs + local DAOs; maps DTO ↔ domain)
```

- **The domain must compile without the UI framework.** No `BuildContext`, no `Context`, no
  `UIViewController` below the presentation layer. That is the §2a inward-dependency rule, and it
  is what makes the domain unit-testable without an emulator.
- **DTO ≠ entity** (§2a): the JSON shape the backend returns and the model your UI binds to change
  for different reasons. Map explicitly in the repository. Same for the persistence model
  (Room/Drift/SwiftData/Realm entities are a third shape).
- **Repository is the port**, declared in the domain, implemented in data. Injected —
  `get_it`/`riverpod`, Hilt/Koin, or plain initialiser injection in Swift.

## State management

Pick **one** per app and stay with it: Bloc/Riverpod/Provider (Flutter), ViewModel+StateFlow with
Compose (Android), Observable/`@Observable` or TCA (iOS). Mixing two is how a codebase becomes
unreviewable. State is immutable and unidirectional; UI renders state and emits intents, nothing
else. Every async state has all four cases modelled — loading, data, empty, error — an app that
only models "data" ships a blank screen to real users.

## Platform reality

- **Lifecycle:** the OS kills backgrounded apps. Anything the user typed must survive process
  death (saved state / `onSaveInstanceState` / `SceneStorage`), and in-flight work must be
  cancellable and resumable. Long work belongs in WorkManager / BGTaskScheduler / a foreground
  service — not a coroutine tied to a screen.
- **Offline is a requirement, not a feature.** Decide explicitly: read-through cache, offline-first
  with a sync queue, or online-only with an honest error state. Record the decision. Conflict
  resolution is part of it — "last write wins" is a choice you have to make on purpose.
- **Permissions** are requested in context, with a rationale, and every denial path is implemented
  (including "denied forever"). Never block the whole app on an optional permission.
- **Secrets never live in the bundle.** API keys in the APK/IPA are extractable in minutes. Tokens
  go to Keystore / Keychain (`flutter_secure_storage` on top), never `SharedPreferences`,
  `UserDefaults`, or plain SQLite. Certificate pinning where the threat model asks for it.
- **Accessibility is not optional** — semantic labels, dynamic type / text scaling, contrast, and
  a usable focus order. The `accessibility-checker` audits it; don't wait for it.
- **Store constraints** shape the design: review latency means you cannot hotfix in an hour, so
  feature flags and a forced-update path are architecture, not extras. Privacy manifests, data
  safety declarations and tracking disclosures follow from what the code actually does.

## Toolchain & style (§3)

| | Flutter/Dart | Android/Kotlin | iOS/Swift |
|---|---|---|---|
| Format | `dart format` | `ktfmt`/`ktlint` | `swift-format` |
| Lint | `flutter analyze` + `very_good_analysis` | `detekt` + Android Lint | `SwiftLint` |
| Build | `flutter build` | Gradle (version catalogs, no dynamic versions) | Xcode / SPM |
| DI | `get_it` / `riverpod` | Hilt / Koin | initialiser injection / Factory |

Warnings are errors. Pin dependency versions; a `+`/`latest` range makes a build unreproducible
and is a supply-chain risk (see the **security** skill).

## Testing (§3a, mobile pyramid)

- **Unit** — domain + presentation, no emulator, no network. > 80 % of changed logic, every
  non-static method (§3a). Fake the repository, not the HTTP client.
- **Widget / component** — `flutter test`, Compose UI tests, XCTest view tests. Assert on
  behaviour and semantics, not on pixel layout.
- **Integration** — repository against a real local DB and a stubbed server (mock web server).
- **BDD E2E** (§3a mandatory) — `integration_test` / Espresso / XCUITest, driven as
  Given/When/Then scenarios on a device or emulator, in CI.
- Test the states the happy path hides: airplane mode mid-request, token expiry, backgrounding
  during a payment, a rotated device, a 400 %-scaled font, an empty list, a 10 000-item list.

## Typical findings to raise

Business logic in a Widget/Composable/View · `BuildContext`/`Context` below the presentation layer
· the API DTO used directly as the UI model · tokens in SharedPreferences/UserDefaults · no error
state modelled · network call not cancellable on screen exit · a `setState`/`ObservableObject`
sprawl next to an existing Bloc/ViewModel · hardcoded strings blocking localisation · missing
semantic labels.
