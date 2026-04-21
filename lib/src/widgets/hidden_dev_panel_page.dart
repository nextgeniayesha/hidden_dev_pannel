import 'package:flutter/material.dart';

import 'developer_panel_screen.dart';

/// Deeplink template shown in the built-in Deeplinks tab.
class DevPanelDeepLinkTemplate {
  const DevPanelDeepLinkTemplate({
    required this.action,
    this.params = const <String>[],
  });

  final String action;
  final List<String> params;
}

/// Environment option shown in the built-in Environment tab.
class DevPanelEnvironmentOption {
  const DevPanelEnvironmentOption({
    required this.id,
    required this.label,
    required this.selected,
  });

  final String id;
  final String label;
  final bool selected;
}

/// App-level wrapper that ships common extra tabs (Deeplinks + Environment).
///
/// Use this to keep app-side code thin while still injecting project-specific
/// deeplink handling and environment switching callbacks.
class HiddenDevPanelPage extends StatelessWidget {
  const HiddenDevPanelPage({
    super.key,
    required this.title,
    this.onPop,
    this.deepLinks = const <DevPanelDeepLinkTemplate>[],
    this.onTriggerDeepLink,
    this.environmentOptions = const <DevPanelEnvironmentOption>[],
    this.environmentDescription,
    this.onSelectEnvironment,
  });

  final String title;
  final VoidCallback? onPop;

  final List<DevPanelDeepLinkTemplate> deepLinks;
  final Future<void> Function(String deeplink)? onTriggerDeepLink;

  final List<DevPanelEnvironmentOption> environmentOptions;
  final String? environmentDescription;
  final Future<void> Function(String environmentId)? onSelectEnvironment;

  @override
  Widget build(BuildContext context) {
    final tabs = <DeveloperPanelTab>[];
    if (deepLinks.isNotEmpty && onTriggerDeepLink != null) {
      tabs.add(
        DeveloperPanelTab(
          title: 'Deeplinks',
          builder: (_) => _DeepLinksTab(
            deepLinks: deepLinks,
            onTriggerDeepLink: onTriggerDeepLink!,
          ),
        ),
      );
    }

    if (environmentOptions.isNotEmpty && onSelectEnvironment != null) {
      tabs.add(
        DeveloperPanelTab(
          title: 'Environment',
          builder: (_) => _EnvironmentTab(
            environmentOptions: environmentOptions,
            environmentDescription: environmentDescription,
            onSelectEnvironment: onSelectEnvironment!,
          ),
        ),
      );
    }

    return DeveloperPanelScreen(title: title, onPop: onPop, extraTabs: tabs);
  }
}

class _DeepLinksTab extends StatelessWidget {
  const _DeepLinksTab({
    required this.deepLinks,
    required this.onTriggerDeepLink,
  });

  final List<DevPanelDeepLinkTemplate> deepLinks;
  final Future<void> Function(String deeplink) onTriggerDeepLink;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: deepLinks.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        return _DeepLinkCard(
          template: deepLinks[index],
          onTriggerDeepLink: onTriggerDeepLink,
        );
      },
    );
  }
}

class _DeepLinkCard extends StatefulWidget {
  const _DeepLinkCard({
    required this.template,
    required this.onTriggerDeepLink,
  });

  final DevPanelDeepLinkTemplate template;
  final Future<void> Function(String deeplink) onTriggerDeepLink;

  @override
  State<_DeepLinkCard> createState() => _DeepLinkCardState();
}

class _DeepLinkCardState extends State<_DeepLinkCard> {
  late final Map<String, TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = {
      for (final p in widget.template.params) p: TextEditingController(),
    };
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.template.action,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            if (widget.template.params.isNotEmpty) ...[
              const SizedBox(height: 8),
              ...widget.template.params.map((param) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: TextField(
                    controller: _controllers[param],
                    decoration: InputDecoration(
                      labelText: param,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                );
              }),
            ],
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: _trigger,
                child: const Text('Trigger'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _trigger() async {
    String? idValue;
    final query = <String, String>{};

    for (final entry in _controllers.entries) {
      final value = entry.value.text.trim();
      if (value.isEmpty) continue;
      if (entry.key == 'id_or_sku' || entry.key == 'id_or_path') {
        idValue = value;
      } else {
        query[entry.key] = value;
      }
    }

    final pathPart = idValue != null && idValue.isNotEmpty ? '/$idValue' : '';
    final queryPart = query.isNotEmpty
        ? '?${query.entries.map((e) => '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}').join('&')}'
        : '';
    final deeplink = 'gsapp://${widget.template.action}$pathPart$queryPart';
    await widget.onTriggerDeepLink(deeplink);
  }
}

class _EnvironmentTab extends StatelessWidget {
  const _EnvironmentTab({
    required this.environmentOptions,
    required this.onSelectEnvironment,
    required this.environmentDescription,
  });

  final List<DevPanelEnvironmentOption> environmentOptions;
  final String? environmentDescription;
  final Future<void> Function(String environmentId) onSelectEnvironment;

  @override
  Widget build(BuildContext context) {
    final selectedId = environmentOptions
        .where((e) => e.selected)
        .map((e) => e.id)
        .cast<String?>()
        .firstWhere((_) => true, orElse: () => null);

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        ...environmentOptions.map((env) {
          return RadioListTile<String>(
            title: Text(env.label),
            value: env.id,
            groupValue: selectedId,
            onChanged: (value) async {
              if (value != null) {
                await onSelectEnvironment(value);
              }
            },
          );
        }),
        if (environmentDescription != null &&
            environmentDescription!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(environmentDescription!),
          ),
      ],
    );
  }
}
