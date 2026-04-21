import 'dart:convert';
import 'dart:ui' show Rect;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../dev_panel_inspector.dart';
import '../logging/dev_log.dart';
import '../models/captured_http_request.dart';
import 'json_pretty.dart';

/// Optional extra tab (e.g. environment switcher, deep links) after Logs & API.
class DeveloperPanelTab {
  const DeveloperPanelTab({required this.title, required this.builder});

  final String title;
  final WidgetBuilder builder;
}

/// Full-screen developer tools: logs, HTTP capture, and [extraTabs].
class DeveloperPanelScreen extends StatefulWidget {
  const DeveloperPanelScreen({
    super.key,
    required this.title,
    this.extraTabs = const [],
    this.onPop,
  });

  final String title;
  final List<DeveloperPanelTab> extraTabs;

  /// When using [go_router], pass `() => context.pop()` so back matches the
  /// previous manual panel. If null, [Navigator.maybePop] is used.
  final VoidCallback? onPop;

  @override
  State<DeveloperPanelScreen> createState() => _DeveloperPanelScreenState();
}

class _DeveloperPanelScreenState extends State<DeveloperPanelScreen>
    with TickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _logSearchController = TextEditingController();
  final TextEditingController _apiSearchController = TextEditingController();
  final ScrollController _logsScrollController = ScrollController();
  final ScrollController _requestsScrollController = ScrollController();
  final ValueNotifier<Set<DevLogLevel>> _selectedLevels =
      ValueNotifier<Set<DevLogLevel>>({
        DevLogLevel.debug,
        DevLogLevel.info,
        DevLogLevel.warning,
        DevLogLevel.error,
      });

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2 + widget.extraTabs.length,
      vsync: this,
    );
    _logSearchController.addListener(() => setState(() {}));
    _apiSearchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    _logSearchController.dispose();
    _apiSearchController.dispose();
    _logsScrollController.dispose();
    _requestsScrollController.dispose();
    _selectedLevels.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final extra = widget.extraTabs;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (widget.onPop != null) {
              widget.onPop!();
            } else {
              Navigator.of(context).maybePop();
            }
          },
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: [
            const Tab(text: 'Logs'),
            const Tab(text: 'API Inspector'),
            ...extra.map((e) => Tab(text: e.title)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildLogsTab(),
          _buildApiInspectorTab(),
          ...extra.map((e) => e.builder(context)),
        ],
      ),
    );
  }

  Widget _buildLogsTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _logSearchController,
            decoration: InputDecoration(
              hintText: 'Search logs by keyword',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () => _logSearchController.clear(),
              ),
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: ValueListenableBuilder<Set<DevLogLevel>>(
            valueListenable: _selectedLevels,
            builder: (context, selected, _) {
              return Wrap(
                spacing: 8,
                children: DevLogLevel.values.map((level) {
                  return FilterChip(
                    label: Text(level.name),
                    selected: selected.contains(level),
                    onSelected: (enabled) {
                      final next = Set<DevLogLevel>.from(selected);
                      if (enabled) {
                        next.add(level);
                      } else {
                        next.remove(level);
                      }
                      _selectedLevels.value = next;
                    },
                  );
                }).toList(),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        ValueListenableBuilder<Set<DevLogLevel>>(
          valueListenable: _selectedLevels,
          builder: (context, _, __) {
            return Expanded(
              child: ValueListenableBuilder<List<DevLogEntry>>(
                valueListenable: DevLogService.instance.logs,
                builder: (context, logs, _) {
                  final filtered = _filteredLogs(logs);
                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Showing ${filtered.length} logs',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              onPressed: _copyFilteredLogs,
                              icon: const Icon(Icons.copy),
                              tooltip: 'Copy visible logs',
                            ),
                            IconButton(
                              onPressed: _shareFilteredLogs,
                              icon: const Icon(Icons.share),
                              tooltip: 'Share visible logs',
                            ),
                            IconButton(
                              onPressed: () => DevLogService.instance.clear(),
                              icon: const Icon(Icons.delete_outline),
                              tooltip: 'Clear logs',
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: filtered.isEmpty
                            ? const Center(child: Text('No logs'))
                            : ListView.separated(
                                controller: _logsScrollController,
                                reverse: false,
                                padding: const EdgeInsets.all(12),
                                itemCount: filtered.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 8),
                                itemBuilder: (_, index) {
                                  final entry = filtered[index];
                                  return Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: _colorForLevel(
                                        entry.level,
                                      ).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            '[${entry.level.name.toUpperCase()}] ${entry.timestamp.toIso8601String()}\n${entry.message}',
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.copy,
                                            size: 18,
                                          ),
                                          tooltip: 'Copy this log',
                                          onPressed: () =>
                                              _copySingleLog(entry),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildApiInspectorTab() {
    return AnimatedBuilder(
      animation: DevPanelInspector(),
      builder: (context, _) {
        final requests = DevPanelInspector().requestsList;
        final filteredRequests = _filteredRequests(requests);
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: TextField(
                controller: _apiSearchController,
                decoration: InputDecoration(
                  hintText:
                      'Filter API calls (e.g. AddProductsToCart, /graphql, /cart)',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () => _apiSearchController.clear(),
                  ),
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Row(
                children: [
                  Text(
                    'Showing ${filteredRequests.length} / ${requests.length} calls',
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => DevPanelInspector().clearAllRequests(),
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Clear calls',
                  ),
                ],
              ),
            ),
            Expanded(
              child: filteredRequests.isEmpty
                  ? Center(
                      child: Text(
                        _apiSearchController.text.trim().isEmpty
                            ? 'No captured calls'
                            : 'No matching calls',
                      ),
                    )
                  : ListView.builder(
                      controller: _requestsScrollController,
                      itemCount: filteredRequests.length,
                      itemBuilder: (context, index) {
                        final request = filteredRequests[index];
                        final duration =
                            (request.receivedTime != null &&
                                request.sentTime != null)
                            ? request.receivedTime!.difference(
                                request.sentTime!,
                              )
                            : null;
                        return ExpansionTile(
                          title: Text(
                            '${request.requestMethod.name} ${request.url}',
                          ),
                          subtitle: Text(
                            'Status: ${request.statusCode ?? '-'} | Duration: ${duration?.inMilliseconds ?? '-'} ms',
                          ),
                          trailing: PopupMenuButton<String>(
                            onSelected: (value) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (value == 'curl') {
                                  _shareRequestAsCurl(request);
                                } else {
                                  _shareRequestAsJson(request);
                                }
                              });
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: 'curl',
                                child: Text('Share cURL'),
                              ),
                              PopupMenuItem(
                                value: 'json',
                                child: Text('Share JSON'),
                              ),
                            ],
                          ),
                          children: [
                            _jsonSection('Request Headers', request.headers),
                            _jsonSection('Request Body', request.requestBody),
                            _jsonSection('Response Body', request.responseBody),
                            const SizedBox(height: 8),
                          ],
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _jsonSection(String title, dynamic data) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: SelectableText(JsonPretty.format(data)),
          ),
        ],
      ),
    );
  }

  List<DevLogEntry> _filteredLogs(List<DevLogEntry> logs) {
    final keyword = _logSearchController.text.trim().toLowerCase();
    final selectedLevels = _selectedLevels.value;
    return logs.where((entry) {
      if (!selectedLevels.contains(entry.level)) return false;
      if (keyword.isEmpty) return true;
      return entry.message.toLowerCase().contains(keyword);
    }).toList();
  }

  List<CapturedHttpRequest> _filteredRequests(
    List<CapturedHttpRequest> requests,
  ) {
    final query = _apiSearchController.text.trim().toLowerCase();
    if (query.isEmpty) return requests;

    return requests.where((request) {
      final haystack = <String>[
        request.requestMethod.name,
        request.url,
        '${request.statusCode ?? ''}',
        JsonPretty.format(request.headers),
        JsonPretty.format(request.requestBody),
        JsonPretty.format(request.responseBody),
      ].join(' ').toLowerCase();

      return haystack.contains(query);
    }).toList();
  }

  Color _colorForLevel(DevLogLevel level) {
    switch (level) {
      case DevLogLevel.error:
        return Colors.red;
      case DevLogLevel.warning:
        return Colors.orange;
      case DevLogLevel.info:
        return Colors.blue;
      case DevLogLevel.debug:
        return Colors.grey;
    }
  }

  Future<void> _copyFilteredLogs() async {
    final logs = _filteredLogs(DevLogService.instance.logs.value);
    final text = logs
        .map(
          (e) =>
              '[${e.level.name}] ${e.timestamp.toIso8601String()} ${e.message}',
        )
        .join('\n');
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Logs copied')));
    }
  }

  Future<void> _shareFilteredLogs() async {
    final logs = _filteredLogs(DevLogService.instance.logs.value);
    final text = logs
        .map(
          (e) =>
              '[${e.level.name}] ${e.timestamp.toIso8601String()} ${e.message}',
        )
        .join('\n');
    await Share.share(text, sharePositionOrigin: _shareOriginRect());
  }

  Future<void> _copySingleLog(DevLogEntry entry) async {
    final text =
        '[${entry.level.name}] ${entry.timestamp.toIso8601String()} ${entry.message}';
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Log copied')));
    }
  }

  Future<void> _shareRequestAsCurl(CapturedHttpRequest request) async {
    final content = _toCurl(request);
    if (content.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No cURL content to share')),
        );
      }
      return;
    }
    await Share.share(content, sharePositionOrigin: _shareOriginRect());
  }

  Future<void> _shareRequestAsJson(CapturedHttpRequest request) async {
    const encoder = JsonEncoder.withIndent('  ');
    await Share.share(
      encoder.convert(request.toMap()),
      sharePositionOrigin: _shareOriginRect(),
    );
  }

  String _toCurl(CapturedHttpRequest request) {
    final buffer = StringBuffer('curl -X ${request.requestMethod.name} ');
    buffer.write('"${request.url}" ');

    if (request.headers is Map) {
      final headers = request.headers as Map;
      for (final entry in headers.entries) {
        if (entry.key.toString().toLowerCase() == 'content-length') continue;
        buffer.write('-H "${entry.key}: ${entry.value}" ');
      }
    }

    if (request.requestBody != null) {
      final body = request.requestBody;
      final encoded = body is String ? body : jsonEncode(body);
      buffer.write("-d '${encoded.replaceAll("'", "'\"'\"'")}' ");
    }
    return buffer.toString().trim();
  }

  Rect? _shareOriginRect() {
    final renderObject = context.findRenderObject();
    if (renderObject is RenderBox && renderObject.hasSize) {
      final origin = renderObject.localToGlobal(Offset.zero);
      return origin & renderObject.size;
    }
    return null;
  }
}
