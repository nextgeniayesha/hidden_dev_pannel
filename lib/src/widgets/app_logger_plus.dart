import 'package:flutter/material.dart';

import 'hidden_dev_panel_page.dart';

/// Configuration for opening developer panel from any app screen.
///
/// Wrap your app root with [AppLoggerPlus] and the panel can be opened without
/// adding route definitions.
class AppLoggerPlus extends StatelessWidget {
  const AppLoggerPlus({
    super.key,
    required this.child,
    this.title = 'Developer Panel',
    this.enableDoubleTapTrigger = true,
    this.deepLinks = const <DevPanelDeepLinkTemplate>[],
    this.deepLinksBuilder,
    this.onTriggerDeepLink,
    this.environmentOptions = const <DevPanelEnvironmentOption>[],
    this.environmentOptionsBuilder,
    this.environmentDescription,
    this.onSelectEnvironment,
    this.onPanelOpened,
    this.navigatorKey,
  });

  final Widget child;
  final String title;
  final bool enableDoubleTapTrigger;

  final List<DevPanelDeepLinkTemplate> deepLinks;
  final List<DevPanelDeepLinkTemplate> Function()? deepLinksBuilder;
  final Future<void> Function(String deeplink)? onTriggerDeepLink;

  final List<DevPanelEnvironmentOption> environmentOptions;
  final List<DevPanelEnvironmentOption> Function()? environmentOptionsBuilder;
  final String? environmentDescription;
  final Future<void> Function(String environmentId)? onSelectEnvironment;

  /// Optional callback whenever the panel is opened.
  final VoidCallback? onPanelOpened;
  final GlobalKey<NavigatorState>? navigatorKey;

  @override
  Widget build(BuildContext context) {
    if (!enableDoubleTapTrigger) {
      return child;
    }

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onDoubleTap: () => _openPanel(context),
      child: child,
    );
  }

  Future<void> _openPanel(BuildContext context) async {
    onPanelOpened?.call();
    final effectiveDeepLinks = deepLinksBuilder?.call() ?? deepLinks;
    final effectiveEnvironmentOptions =
        environmentOptionsBuilder?.call() ?? environmentOptions;
    final navigatorState =
        navigatorKey?.currentState ??
        Navigator.maybeOf(context, rootNavigator: true);
    if (navigatorState == null) return;
    await navigatorState.push(
      MaterialPageRoute<void>(
        builder: (_) => HiddenDevPanelPage(
          title: title,
          deepLinks: effectiveDeepLinks,
          onTriggerDeepLink: onTriggerDeepLink,
          environmentOptions: effectiveEnvironmentOptions,
          environmentDescription: environmentDescription,
          onSelectEnvironment: onSelectEnvironment,
        ),
      ),
    );
  }
}
