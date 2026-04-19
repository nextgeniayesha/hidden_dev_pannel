import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

enum DevLogLevel { debug, info, warning, error }

class DevLogEntry {
  final DateTime timestamp;
  final DevLogLevel level;
  final String message;

  const DevLogEntry({
    required this.timestamp,
    required this.level,
    required this.message,
  });
}

/// Shared in-memory log ring for debug / internal builds.
final class DevLogService {
  DevLogService._();

  static final DevLogService instance = DevLogService._();
  static const int _maxEntries = 1000;
  final List<DevLogEntry> _pending = <DevLogEntry>[];
  bool _flushScheduled = false;

  final ValueNotifier<List<DevLogEntry>> logs = ValueNotifier<List<DevLogEntry>>(
    const <DevLogEntry>[],
  );

  void capturePrint(String line) {
    final normalized = line.trim();
    if (normalized.isEmpty || _isNoiseOnly(normalized)) {
      return;
    }

    final lower = normalized.toLowerCase();
    final level = lower.contains('error') || lower.contains('exception')
        ? DevLogLevel.error
        : lower.contains('warn')
            ? DevLogLevel.warning
            : lower.contains('info')
                ? DevLogLevel.info
                : DevLogLevel.debug;
    _enqueueLog(
      DevLogEntry(
        timestamp: DateTime.now(),
        level: level,
        message: normalized,
      ),
    );
  }

  void addLog(DevLogLevel level, String message) {
    final normalized = message.trim();
    if (normalized.isEmpty || _isNoiseOnly(normalized)) {
      return;
    }
    final next = List<DevLogEntry>.from(logs.value)
      ..insert(
        0,
        DevLogEntry(
          timestamp: DateTime.now(),
          level: level,
          message: normalized,
        ),
      );
    if (next.length > _maxEntries) {
      next.removeRange(_maxEntries, next.length);
    }
    logs.value = next;
  }

  void clear() {
    logs.value = const <DevLogEntry>[];
  }

  bool _isNoiseOnly(String message) {
    if (!RegExp(r'[A-Za-z0-9\u0600-\u06FF]').hasMatch(message)) {
      return true;
    }
    final withoutDecorators = message.replaceAll(
      RegExp(r'[\s\-\=\_\|\+\*#~`·•:\[\]\(\)\\/─━│┃┄┅┈┉═║]+'),
      '',
    );
    return withoutDecorators.isEmpty;
  }

  void _enqueueLog(DevLogEntry entry) {
    _pending.add(entry);
    if (_flushScheduled) return;
    _flushScheduled = true;

    SchedulerBinding.instance.addPostFrameCallback((_) {
      _flushScheduled = false;
      if (_pending.isEmpty) return;

      final batch = List<DevLogEntry>.from(_pending.reversed);
      _pending.clear();

      final next = List<DevLogEntry>.from(logs.value)..insertAll(0, batch);
      if (next.length > _maxEntries) {
        next.removeRange(_maxEntries, next.length);
      }
      logs.value = next;
    });
  }
}
