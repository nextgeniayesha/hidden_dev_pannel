# hidden_dev_pannel

In-app **developer panel** for Flutter: browse structured logs, inspect captured **HTTP** traffic (Dio + GraphQL), share requests as cURL or JSON, and attach **custom tabs** (e.g. deep links, environment switcher).

Designed as a replacement for ad-hoc `requests_inspector`–style tooling: traffic is recorded by **your** interceptors and links, with **no** dependency on third-party inspector packages.

---

## Features

| Area | What you get |
|------|----------------|
| **Logs** | In-memory ring (`DevLogService`), levels, search, copy/share/clear |
| **API inspector** | List of calls, filter, expand headers/body/response, cURL + JSON share |
| **Dio** | `DevPanelDioInterceptor` records all requests on the configured `Dio` instances |
| **GraphQL** | `DevGraphqlInspectorLink` wraps `HttpLink` and records each operation |
| **UI** | `DeveloperPanelScreen` with optional `extraTabs` for app-specific screens |
| **Back navigation** | Optional `onPop` (e.g. `() => context.pop()` with `go_router`) |

---

## Requirements

- **Dart SDK:** `^3.8.0` (see `pubspec.yaml`)
- **Flutter** app (this package depends on the Flutter SDK)

---

## Installation

### Option A — Path dependency (local / monorepo)

If this repo sits **next to** your app (e.g. `Documents/magnext_frontend` and `Documents/hidden_dev_pannel`):

```yaml
# your_app/pubspec.yaml
dependencies:
  hidden_dev_pannel:
    path: ../hidden_dev_pannel
```

Then:

```bash
cd /path/to/your_app
flutter pub get
```

Adjust `path:` if your folder layout differs (relative or absolute path to this package root).

### Option B — Published on pub.dev

After you publish (see [Publishing](#publishing)):

```yaml
dependencies:
  hidden_dev_pannel: ^0.1.1
```

```bash
flutter pub get
```

---

## Integration steps

Follow these in order inside **your app**.

### 1. Depend on the package

Use Option A or B above.

### 2. Route logs through `DevLogService` (optional but typical)

Expose the package types so the rest of the app keeps stable imports:

```dart
// lib/core/services/dev_log_service.dart
export 'package:hidden_dev_pannel/hidden_dev_pannel.dart'
    show DevLogService, DevLogEntry, DevLogLevel;
```

Elsewhere: `import '.../dev_log_service.dart'` and use `DevLogService.instance.addLog(...)`.

### 3. Capture Dio traffic

On each `Dio` instance you want in the inspector:

```dart
import 'package:hidden_dev_pannel/hidden_dev_pannel.dart';

dio.interceptors.add(DevPanelDioInterceptor());
```

Add **after** any logging interceptors if order matters for your app.

### 4. Capture GraphQL (`graphql` / `graphql_flutter`)

Wrap your `HttpLink`:

```dart
import 'package:hidden_dev_pannel/hidden_dev_pannel.dart';

final httpLink = HttpLink(uri, defaultHeaders: headers);

GraphQLClient(
  link: Link.split(
    (request) => request.isSubscription,
    WebSocketLink(uri),
    DevGraphqlInspectorLink(httpLink),
  ),
  // ...
);
```

For **isolate** / raw `Dio` GraphQL calls, push rows manually with `CapturedHttpRequest` + `DevPanelInspector().addNewRequest(...)` (same pattern as in a large app’s `GraphQLService`).

### 5. Show the panel UI

Minimal shell with **go_router** back:

```dart
import 'package:go_router/go_router.dart';
import 'package:hidden_dev_pannel/hidden_dev_pannel.dart';

DeveloperPanelScreen(
  title: 'Developer Panel (${yourEnvironmentLabel})',
  onPop: () => context.pop(),
  extraTabs: [
    DeveloperPanelTab(
      title: 'My tab',
      builder: (context) => YourWidget(),
    ),
  ],
)
```

- **`onPop`:** use `() => context.pop()` with `go_router`; if omitted, `Navigator.maybePop` is used.
- **`extraTabs`:** add deep-link testers, environment switcher, feature flags, etc.

### 6. Do **not** initialize third-party inspector singletons

If you previously called `InspectorController(...)` or wrapped the app in a requests-inspector widget, remove that; this package uses `DevPanelInspector` only for the in-app list.

---

## Package layout

| Path | Role |
|------|------|
| `lib/hidden_dev_pannel.dart` | Public exports |
| `lib/src/dev_panel_inspector.dart` | In-memory list of `CapturedHttpRequest` |
| `lib/src/dio/dev_panel_dio_interceptor.dart` | Dio interceptor |
| `lib/src/graphql/dev_graphql_inspector_link.dart` | GraphQL `Link` around `HttpLink` |
| `lib/src/logging/dev_log.dart` | `DevLogService`, `DevLogLevel`, `DevLogEntry` |
| `lib/src/models/` | `CapturedHttpRequest`, `HttpCaptureMethod` |
| `lib/src/widgets/developer_panel_screen.dart` | Full-screen tabs UI |
| `lib/src/widgets/json_pretty.dart` | JSON / GraphQL formatting for the inspector |

---

## Publishing (maintainers)

Run these on your machine (with Flutter/Dart installed and network access).

### 1. Log in to pub.dev (once)

```bash
dart pub login
```

Use the Google account allowed to publish **`hidden_dev_pannel`**.

### 2. Dry run (required before first publish)

From **this package root** (`hidden_dev_pannel`):

```bash
cd /path/to/hidden_dev_pannel
dart pub get
dart pub publish --dry-run
```

Or for Flutter tooling:

```bash
flutter pub publish --dry-run
```

Fix every **warning** and **error** (missing `LICENSE`, invalid `repository`, oversized files, etc.).  
Ensure `repository` / `homepage` in `pubspec.yaml` point at a **real** Git URL if you declare them.

### 3. Publish

```bash
dart pub publish
```

Confirm when prompted, or after you are sure:

```bash
dart pub publish --force
```

### 4. After publish

- Open [pub.dev/packages/hidden_dev_pannel](https://pub.dev/packages/hidden_dev_pannel) and verify the page.
- In consuming apps, switch from `path:` to:

  ```yaml
  hidden_dev_pannel: ^0.1.1
  ```

  then `flutter pub get`.

### 5. Retraction / discontinuation

Published versions follow [pub.dev policy](https://pub.dev/policy): permanent by default; use **retract** (short window) or **discontinue** from the package **Admin** tab if needed.

---

## License

See [`LICENSE`](LICENSE).
