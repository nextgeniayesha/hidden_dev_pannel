## 0.1.3

* Add `AppLoggerPlus` wrapper to open logger without route definitions.
* Switch trigger to double-tap gesture.
* Add `navigatorKey` support for apps where wrapper context has no `Navigator`.
* Add `deepLinksBuilder` and `environmentOptionsBuilder` for dynamic tab state.

## 0.1.2

* Add `HiddenDevPanelPage` as a reusable package-level wrapper around `DeveloperPanelScreen`.
* Add configurable built-in Deeplinks and Environment tabs (`DevPanelDeepLinkTemplate`, `DevPanelEnvironmentOption`) to keep app integration thin.
* Export the new wrapper and models from `hidden_dev_pannel.dart`.

## 0.1.1

* Correct `repository` URL in `pubspec.yaml` so pub.dev links to the real GitHub repo.

## 0.1.0

* Initial release: in-app developer panel (logs, API inspector), Dio and GraphQL
  traffic capture, optional extra tabs, no `requests_inspector` dependency.
